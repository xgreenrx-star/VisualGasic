"""Execute emitted VG in an isolated temp project and parse observations."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

from . import COMPLETION_MARKER, OBS_PREFIX, PATH_PREFIX, SCHEMA_VERSION
from .emitter import emit_program
from .ir import Program
from .reference import evaluate_program

# Integer or String observations (C2 event notes use type=String).
OBS_RE = re.compile(
    rf"^{re.escape(OBS_PREFIX)} kind=value name=(?P<name>\S+) type=(?P<type>\S+) "
    rf"value=(?P<value>\S+)\s*$"
)
# Prefix that must be a well-formed OBS_RE or it is a parse error.
OBS_PREFIX_RE = re.compile(rf"^{re.escape(OBS_PREFIX)}\b")
# Optional mod="<res://…>" (quoted; spaces allowed). Untagged lines remain valid.
PATH_RE = re.compile(
    rf'^{re.escape(PATH_PREFIX)} path=(?P<path>\S+) fn=(?P<fn>\S+)'
    rf'(?: mod="(?P<mod>[^"]*)")?\s*$'
)
PATH_PREFIX_RE = re.compile(rf"^{re.escape(PATH_PREFIX)}\b")
DONE_RE = re.compile(rf"^{re.escape(COMPLETION_MARKER)} case=(?P<case>\S+)\s*$")
DONE_PREFIX_RE = re.compile(rf"^{re.escape(COMPLETION_MARKER)}\b")

MODES = {
    "forced_ast": {"VG_FORCE_AST": "1", "VG_JIT": None},
    "interpreter": {"VG_FORCE_AST": None, "VG_JIT": "0"},
    "default": {"VG_FORCE_AST": None, "VG_JIT": None},
    "tier3": {"VG_FORCE_AST": None, "VG_JIT": "3"},
}


@dataclass
class ParseLogResult:
    observations: list[dict[str, str]] = field(default_factory=list)
    path_events: list[dict[str, str]] = field(default_factory=list)
    completed: bool = False
    case: Optional[str] = None
    error: Optional[str] = None  # malformed / duplicate markers


@dataclass
class RunResult:
    ok: bool
    failure_code: Optional[str] = None
    message: str = ""
    observations: list[dict[str, str]] = field(default_factory=list)
    path_events: list[dict[str, str]] = field(default_factory=list)
    path_counts: dict[str, dict[str, int]] = field(default_factory=dict)
    exit_code: int = 0
    timed_out: bool = False
    completed: bool = False
    log_path: Optional[str] = None
    elapsed_ms: int = 0
    mode: str = ""
    env: dict[str, str] = field(default_factory=dict)
    source_path: Optional[str] = None
    binary_hash: Optional[str] = None
    engine_hash: Optional[str] = None  # Godot binary sha256
    engine_path: Optional[str] = None
    # Bound for THIS run (physical + logical); do not reuse saved physical across runs.
    bound_path_module: Optional[str] = None
    bound_path_module_key: Optional[str] = None
    bound_fn_path_modules: dict[str, str] = field(default_factory=dict)


def find_repo_root() -> Path:
    here = Path(__file__).resolve()
    for p in [here.parent, *here.parents]:
        if (p / "addons" / "visual_gasic").is_dir() and (p / "SConstruct").exists():
            return p
    raise FileNotFoundError("VisualGasic repo root not found")


def find_godot(root: Path) -> Path:
    env = os.environ.get("GODOT", "")
    candidates = []
    if env:
        p = Path(env)
        candidates.append(p if p.is_absolute() else (root / p).resolve())
        candidates.append((Path.cwd() / p).resolve())
    candidates.extend(
        [
            root / "Godot_v4.6.1-stable_linux.x86_64",
            root / "Godot_v4.6.1-stable_mono_linux.x86_64",
        ]
    )
    for c in candidates:
        try:
            c = c.resolve()
        except Exception:
            continue
        if c.is_file() and os.access(c, os.X_OK):
            return c
    raise FileNotFoundError("Godot binary not found; set GODOT")


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _as_text(chunk: Any) -> str:
    if chunk is None:
        return ""
    if isinstance(chunk, bytes):
        return chunk.decode("utf-8", errors="replace")
    return str(chunk)


def parse_log(text: str) -> ParseLogResult:
    """Strict log parse: malformed OBS/PATH/DONE lines and duplicate DONE fail."""
    out = ParseLogResult()
    done_count = 0
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if OBS_PREFIX_RE.match(line):
            m = OBS_RE.match(line)
            if not m:
                out.error = f"malformed observation line: {line}"
                return out
            out.observations.append(
                {"name": m.group("name"), "type": m.group("type"), "value": m.group("value")}
            )
            continue
        if PATH_PREFIX_RE.match(line):
            m = PATH_RE.match(line)
            if not m:
                out.error = f"malformed path line: {line}"
                return out
            from .path_contract import decode_mod

            ev = {"path": m.group("path"), "fn": m.group("fn")}
            if m.group("mod") is not None:
                try:
                    ev["mod"] = decode_mod(m.group("mod"))
                except ValueError as exc:
                    out.error = f"malformed path mod encoding: {exc}"
                    return out
            out.path_events.append(ev)
            continue
        if DONE_PREFIX_RE.match(line):
            m = DONE_RE.match(line)
            if not m:
                out.error = f"malformed completion line: {line}"
                return out
            done_count += 1
            if done_count > 1:
                out.error = "duplicate completion marker"
                return out
            out.completed = True
            out.case = m.group("case")
            continue
    return out


def path_counts(events: list[dict[str, str]]) -> dict[str, dict[str, int]]:
    # Phase 1 aggregates by fn only (mod is additive / optional).
    from .path_contract import path_counts as _pc

    return _pc(events)


def case_dir_slug(case_id: str) -> str:
    """Stable unique directory slug (avoids truncation collisions)."""
    slug = "".join(ch if ch.isalnum() or ch in "-_" else "_" for ch in case_id)[:32] or "case"
    digest = hashlib.sha256(case_id.encode("utf-8")).hexdigest()[:10]
    return f"{slug}_{digest}"


def logical_module_key(case_id: str, mode: str) -> str:
    """Source-relative module identity independent of physical staging root."""
    return f"sem_fuzz_ir/{case_dir_slug(case_id)}/{mode}"


def ir_case_res_path(case_id: str, mode: str) -> str:
    """Legacy helper: logical key only (not a physical res:// path)."""
    return logical_module_key(case_id, mode)


def _stage_case_in_test_proj(
    root: Path,
    source: str,
    case_id: str,
    mode: str,
    *,
    run_token: str,
) -> tuple[Path, str]:
    """Per-run owned staging; never deletes another run's files."""
    slug = case_dir_slug(case_id)
    staging = root / "test_proj" / "sem_fuzz_runs" / run_token / slug / mode
    staging.mkdir(parents=True, exist_ok=False)
    (staging / "case.vg").write_text(source, encoding="utf-8")
    rel = staging.relative_to(root / "test_proj").as_posix()
    return staging, f"res://{rel}/case.vg"


def bind_run_program(prog: Program, mode: str, *, run_token: str) -> Program:
    """Return a deep copy with logical key for this mode.

    Physical path_module is assigned after staging. A stored path_module_key for a
    different mode/case is refused (not silently repaired).
    """
    import copy

    bound = copy.deepcopy(prog)
    key = logical_module_key(bound.case_id, mode)
    if bound.path_module_key is None:
        bound.path_module_key = key
    elif bound.path_module_key != key:
        raise ValueError(
            f"path_module_key mismatch: stored={bound.path_module_key!r} expected={key!r}"
        )
    if bound.path_module is not None:
        raise ValueError(
            f"refusing bound run with pre-set path_module={bound.path_module!r}; "
            "physical module is assigned after staging"
        )
    _ = run_token  # reserved for physical prefix checks after staging
    return bound


def classify_timeout_output(exc: BaseException) -> tuple[str, int, bool]:
    """Normalize TimeoutExpired (and similar) into text without TypeError."""
    stdout = getattr(exc, "stdout", None)
    stderr = getattr(exc, "stderr", None)
    return _as_text(stdout) + "\n" + _as_text(stderr), 124, True


def run_program(
    prog: Program,
    *,
    mode: str,
    work_root: Path,
    timeout_secs: float = 20.0,
    warmup_calls: int = 0,
    godot: Optional[Path] = None,
    keep: bool = True,
) -> RunResult:
    if mode not in MODES:
        raise ValueError(f"unknown mode {mode}")
    root = find_repo_root()
    godot = godot or find_godot(root)
    so = root / "addons" / "visual_gasic" / "bin" / "libvisualgasic.linux.editor.x86_64.so"
    alt = root / "addons" / "visual_gasic" / "libvisualgasic.linux.editor.x86_64.so"
    binary = so if so.is_file() else alt
    binary_hash = file_sha256(binary) if binary.is_file() else None
    engine_hash = file_sha256(Path(godot)) if Path(godot).is_file() else None

    run_token = f"{os.getpid()}_{int(time.time() * 1000)}_{hashlib.sha1(os.urandom(8)).hexdigest()[:8]}"
    # Bind on a copy — never mutate the caller's Program across modes.
    # Production/unbound runs must not carry a physical path_module. Replay must
    # explicitly strip it at the reconstruct boundary (not here silently).
    import copy

    unbound = copy.deepcopy(prog)
    if unbound.path_module is not None:
        raise ValueError(
            "run_program refused pre-set path_module; "
            "only replay reconstruct may rebind after clearing physical module"
        )
    if unbound.path_module_key is None:
        unbound.path_module_key = logical_module_key(unbound.case_id, mode)
    bound = bind_run_program(unbound, mode, run_token=run_token)

    # Per-run owned output dir — never rmtree another invocation's evidence.
    case_dir = work_root / "runs" / run_token / bound.case_id / mode
    if case_dir.exists():
        raise ValueError(f"refusing overwrite of existing owned case_dir {case_dir}")
    case_dir.mkdir(parents=True, exist_ok=False)

    warm = warmup_calls
    if warm == 0 and "native_eligible" in bound.tags and mode in ("default", "tier3"):
        warm = 4
    source = emit_program(bound, warmup_calls=warm)
    primary_raw = source.encode("utf-8")
    (case_dir / "case.vg").write_text(source, encoding="utf-8")

    staging, res_path = _stage_case_in_test_proj(
        root, source, bound.case_id, mode, run_token=run_token
    )
    # Stage imported modules beside primary; record per-fn physical mods.
    # Also persist copies in the owned case_dir for offline integrity.
    fn_mods: dict[str, str] = {}
    for mod in getattr(bound, "source_modules", None) or []:
        rel = mod["rel_path"]
        content = mod["content"]
        (staging / rel).write_text(content, encoding="utf-8")
        (case_dir / rel).write_text(content, encoding="utf-8")
        mod_res = f"{res_path.rsplit('/', 1)[0]}/{rel}"
        for hn, href in (getattr(bound, "helper_defining_module", None) or {}).items():
            if href == rel:
                fn_mods[hn] = mod_res
    bound.path_module = res_path
    # Primary-file helpers default to primary res_path.
    for h in bound.helpers:
        if h.name not in fn_mods:
            if h.name not in (getattr(bound, "helper_defining_module", None) or {}):
                fn_mods[h.name] = res_path
    bound._fn_path_modules = fn_mods  # type: ignore[attr-defined]
    if not list(bound.path_targets or []):
        bound.path_targets = [bound.path_target] if bound.path_target else ["SemMain"]
    if bound.path_target and bound.path_target not in bound.path_targets:
        bound.path_targets = [bound.path_target, *list(bound.path_targets)]

    from .provenance import bundle_version_fields
    from .ir import dumps_program

    src_manifest = []
    for mod in getattr(bound, "source_modules", None) or []:
        raw = mod["content"].encode("utf-8")
        src_manifest.append(
            {
                "rel_path": mod["rel_path"],
                "sha256": hashlib.sha256(raw).hexdigest(),
                "bytes": len(raw),
            }
        )
    meta = {
        **bundle_version_fields(),
        "case_id": bound.case_id,
        "mode": mode,
        "path_target": bound.path_target,
        "path_targets": list(bound.path_targets or []),
        "path_module_key": bound.path_module_key,
        "path_module": bound.path_module,
        "required_path": dict(bound.required_path or {}),
        "fallback_contract": bound.fallback_contract,
        "run_token": run_token,
        "primary_source": {
            "sha256": hashlib.sha256(primary_raw).hexdigest(),
            "bytes": len(primary_raw),
            "warmup_calls": int(warm),
        },
        "source_modules_manifest": src_manifest,
        "helper_defining_module": dict(
            getattr(bound, "helper_defining_module", None) or {}
        ),
        "fn_path_modules": dict(getattr(bound, "_fn_path_modules", {}) or {}),
        "binary_hash": binary_hash,
        "engine_hash": engine_hash,
        "engine_path": str(godot),
    }
    (case_dir / "program.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    (case_dir / "ir.json").write_text(dumps_program(bound), encoding="utf-8")
    expected = evaluate_program(bound)
    (case_dir / "expected.json").write_text(
        json.dumps([o.to_dict() for o in expected.observations], indent=2),
        encoding="utf-8",
    )

    # Use bound program for path checks below.
    prog = bound
    env = os.environ.copy()
    for k in ("VG_FORCE_AST", "VG_JIT", "VG_JIT_LOG"):
        env.pop(k, None)
    spec = MODES[mode]
    for k, v in spec.items():
        if v is None:
            env.pop(k, None)
        else:
            env[k] = v
    env["VG_SEM_PATH"] = "1"

    user_dir = case_dir / "user"
    user_dir.mkdir(exist_ok=True)
    log_path = case_dir / "run.log"
    cmd = [
        str(godot),
        "--headless",
        "--path",
        str(root / "test_proj"),
        "--user-data-dir",
        str(user_dir),
        "-s",
        "run_suite.gd",
        "--",
        res_path,
    ]
    t0 = time.time()
    timed_out = False
    exit_code = 1
    output = ""
    try:
        try:
            proc = subprocess.run(
                cmd,
                cwd=str(root),
                env=env,
                capture_output=True,
                text=True,
                timeout=timeout_secs,
            )
            exit_code = proc.returncode
            output = _as_text(proc.stdout) + "\n" + _as_text(proc.stderr)
        except subprocess.TimeoutExpired as exc:
            output, exit_code, timed_out = classify_timeout_output(exc)
    finally:
        shutil.rmtree(staging, ignore_errors=True)
    elapsed_ms = int((time.time() - t0) * 1000)
    log_path.write_text(output, encoding="utf-8")
    vg_path = case_dir / "case.vg"

    parsed = parse_log(output)
    counts = path_counts(parsed.path_events)

    result = RunResult(
        ok=False,
        observations=parsed.observations,
        path_events=parsed.path_events,
        path_counts=counts,
        exit_code=exit_code,
        timed_out=timed_out,
        completed=parsed.completed,
        log_path=str(log_path),
        elapsed_ms=elapsed_ms,
        mode=mode,
        env={k: env[k] for k in ("VG_FORCE_AST", "VG_JIT", "VG_SEM_PATH") if k in env},
        source_path=str(vg_path),
        binary_hash=binary_hash,
        engine_hash=engine_hash,
        engine_path=str(godot),
        bound_path_module=bound.path_module,
        bound_path_module_key=bound.path_module_key,
    )
    result.bound_fn_path_modules = dict(getattr(bound, "_fn_path_modules", {}) or {})

    crash_markers = ("handle_crash:", "SCRIPT ERROR", "Parser Error", "VG Runtime Error")
    if timed_out:
        result.failure_code = "timeout"
        result.message = "subprocess timed out"
        return result
    if parsed.error:
        result.failure_code = "malformed"
        result.message = parsed.error
        return result
    if exit_code != 0:
        result.failure_code = "nonzero_exit"
        result.message = f"exit {exit_code}"
        return result
    if any(m in output for m in crash_markers):
        result.failure_code = "runtime_or_crash"
        result.message = "runtime/parser/crash marker in log"
        return result
    if not parsed.completed:
        result.failure_code = "incomplete"
        result.message = "missing completion marker"
        return result
    if parsed.case and parsed.case != prog.case_id:
        result.failure_code = "malformed"
        result.message = f"completion case mismatch {parsed.case}"
        return result
    if not parsed.observations:
        result.failure_code = "missing_result"
        result.message = "no observations"
        return result

    result.ok = True
    result.message = "ok"
    return result


def check_required_path(prog: Program, mode: str, result: RunResult) -> Optional[str]:
    """Require the named path_target function to take the expected path.

    Sibling function path events must not satisfy the requirement.
    Fallback-contract cases still validate: forced_ast/interpreter as usual;
    default/tier3 require bytecode on the target (native decline), not a skip.

    Conflicting-path checks (e.g. mixed native+AST) run *before* any native
    success return. Bytecode warmup followed by native entry is allowed.
    When prog.path_module is set, only matching mod= events count.
    """
    from .path_contract import check_required_path_events

    want = prog.required_path.get(mode)
    if not want:
        if prog.fallback_contract and mode in ("default", "tier3"):
            want = "bytecode"
        else:
            return None

    targets = []
    if prog.path_target:
        targets.append(prog.path_target)
    for t in getattr(prog, "path_targets", None) or []:
        if t not in targets:
            targets.append(t)
    if not targets:
        targets = ["SemMain"]
    # Prefer this-run physical module from RunResult; refuse to use a stale
    # saved path_module from a prior staging root as the live contract.
    required_mod = result.bound_path_module or prog.path_module
    if prog.path_module_key and result.bound_path_module_key:
        if prog.path_module_key != result.bound_path_module_key:
            return (
                f"path_module_key mismatch: prog={prog.path_module_key} "
                f"run={result.bound_path_module_key}"
            )
    fn_mods = getattr(result, "bound_fn_path_modules", None) or {}
    errs = []
    for target in targets:
        mod = fn_mods.get(target, required_mod)
        err = check_required_path_events(
            mode=mode,
            target=target,
            want=want,
            events=result.path_events,
            required_mod=mod,
            fallback_contract=prog.fallback_contract,
        )
        if err:
            errs.append(f"{target}:{err}")
    if errs:
        return "; ".join(errs)
    return None
