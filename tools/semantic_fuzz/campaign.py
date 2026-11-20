"""Seeded semantic campaign orchestration."""

from __future__ import annotations

import json
import os
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

from . import GENERATOR_VERSION, REFERENCE_VERSION, SCHEMA_VERSION
from .compare import CompareError, compare_observations
from .generator import generate_batch, shape_fingerprint, structural_fingerprint
from .ir import dumps_program, loads_program
from .reference import evaluate_program
from .runner import (
    MODES,
    check_required_path,
    file_sha256,
    find_godot,
    find_repo_root,
    run_program,
)


@dataclass
class CaseReport:
    case_id: str
    family: str
    mode: str
    status: str
    failure_code: Optional[str] = None
    message: str = ""
    path_counts: dict = field(default_factory=dict)
    elapsed_ms: int = 0
    work_dir: str = ""


@dataclass
class CampaignReport:
    seed: int
    count: int
    modes: list[str]
    generated: int = 0
    distinct: int = 0
    distinct_shapes: int = 0
    families: dict[str, int] = field(default_factory=dict)
    path_totals: dict[str, dict[str, int]] = field(default_factory=dict)
    path_by_mode: dict[str, dict[str, dict[str, int]]] = field(default_factory=dict)
    # path → count aggregated only from successful case runs
    path_by_module: dict[str, dict[str, dict[str, int]]] = field(default_factory=dict)
    # Structural feature pairs of programs that passed (NOT proven executed edges).
    structural_pair_counts_on_success: dict[str, int] = field(default_factory=dict)
    # mode → module → fn → path → count (from VG_SEM_PATH events on success only)
    path_by_mode_module: dict[str, dict[str, dict[str, dict[str, int]]]] = field(
        default_factory=dict
    )
    native_tier_hits: dict[str, int] = field(default_factory=dict)
    cases: list[CaseReport] = field(default_factory=list)
    failures: list[CaseReport] = field(default_factory=list)
    exclusions: list[str] = field(default_factory=list)
    elapsed_ms: int = 0
    provenance: dict[str, Any] = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return not self.failures and self.generated > 0


def _git_rev(root: Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=str(root), text=True
        ).strip()
    except Exception:
        return "unknown"


def _worktree_dirty(root: Path) -> bool:
    try:
        out = subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=str(root), text=True
        )
        return bool(out.strip())
    except Exception:
        return True


def run_campaign(
    seed: int,
    count: int,
    *,
    modes: Optional[list[str]] = None,
    out_dir: Optional[Path] = None,
    timeout_secs: float = 20.0,
    domain: str = "phase1",
) -> CampaignReport:
    if count < 1:
        raise ValueError("empty campaign refused")
    modes = modes or ["forced_ast", "interpreter", "default"]
    for m in modes:
        if m not in MODES:
            raise ValueError(f"unknown mode {m}")
    if domain not in ("phase1", "c2"):
        raise ValueError(f"unknown domain {domain}")

    root = find_repo_root()
    godot = find_godot(root)
    binary = root / "addons" / "visual_gasic" / "bin" / "libvisualgasic.linux.editor.x86_64.so"
    out_dir = Path(out_dir or os.environ.get("SEM_FUZZ_OUT") or f"/tmp/vg-sem-fuzz-{os.getpid()}")
    out_dir.mkdir(parents=True, exist_ok=True)

    if domain == "c2":
        from .generator_c2 import UNSUPPORTED_PAIRS, covered_pairs, generate_c2_batch

        programs = generate_c2_batch(seed, count)
        c2_pairs = covered_pairs(programs)
        c2_unsupported = list(UNSUPPORTED_PAIRS)
    else:
        programs = generate_batch(seed, count)
        c2_pairs = []
        c2_unsupported = []
    fps = {structural_fingerprint(p) for p in programs}
    shapes = {shape_fingerprint(p) for p in programs}
    report = CampaignReport(
        seed=seed,
        count=count,
        modes=list(modes),
        generated=len(programs),
        distinct=len(fps),
        distinct_shapes=len(shapes),
        provenance={
            "schema_version": SCHEMA_VERSION,
            "generator_version": GENERATOR_VERSION,
            "reference_version": REFERENCE_VERSION,
            "domain": domain,
            "c2_covered_pairs": c2_pairs,
            "c2_unsupported_pairs": c2_unsupported,
            "git_rev": _git_rev(root),
            "worktree_dirty": _worktree_dirty(root),
            "godot": str(godot),
            "godot_sha256": file_sha256(godot) if Path(godot).is_file() else None,
            "binary": str(binary),
            "binary_sha256": file_sha256(binary) if binary.is_file() else None,
            "modes_requested": list(modes),
            "out_dir": str(out_dir),
        },
        exclusions=[
            (
                "C2 excludes: alias f(x,x), impure index, nested ByVal call-arg side effects, "
                "multi-file same-name imports"
                if domain == "c2"
                else "Phase1 excludes: div0, overflow, float, Variant/Nothing, ByRef, arrays/UDT, random AndAlso"
            ),
            "Platform: native path required only on VG_JIT_NATIVE x86-64 Linux builds",
        ],
    )
    for p in programs:
        report.families[p.family] = report.families.get(p.family, 0) + 1

    t0 = time.time()
    for prog in programs:
        expected = [o.to_dict() for o in evaluate_program(prog).observations]
        for mode in modes:
            rr = run_program(prog, mode=mode, work_root=out_dir, timeout_secs=timeout_secs)
            # Owned evidence lives under work_root/runs/<token>/...
            case_out = Path(rr.log_path).parent if rr.log_path else out_dir / prog.case_id / mode
            report.path_by_mode.setdefault(mode, {})
            for fn, pc in rr.path_counts.items():
                report.path_totals.setdefault(fn, {})
                report.path_by_mode[mode].setdefault(fn, {})
                for path, n in pc.items():
                    report.path_totals[fn][path] = report.path_totals[fn].get(path, 0) + n
                    report.path_by_mode[mode][fn][path] = (
                        report.path_by_mode[mode][fn].get(path, 0) + n
                    )

            crep = CaseReport(
                case_id=prog.case_id,
                family=prog.family,
                mode=mode,
                status="pass",
                path_counts=rr.path_counts,
                elapsed_ms=rr.elapsed_ms,
                work_dir=str(case_out),
            )
            if not rr.ok:
                crep.status = "fail"
                crep.failure_code = rr.failure_code
                crep.message = rr.message
                report.failures.append(crep)
                report.cases.append(crep)
                _write_failure_bundle(case_out, prog, expected, rr, failure_code=rr.failure_code)
                continue
            try:
                compare_observations(expected, rr.observations)
            except CompareError as exc:
                crep.status = "fail"
                crep.failure_code = exc.code
                crep.message = str(exc)
                report.failures.append(crep)
                report.cases.append(crep)
                _write_failure_bundle(
                    case_out,
                    prog,
                    expected,
                    rr,
                    failure_code=exc.code,
                    compare_error=str(exc),
                )
                continue

            path_err = check_required_path(prog, mode, rr)
            if path_err:
                if "native" in (prog.required_path.get(mode) or "") and not _native_supported():
                    report.exclusions.append(
                        f"{prog.case_id}/{mode}: native required but VG_JIT_NATIVE unsupported on this build"
                    )
                else:
                    crep.status = "fail"
                    crep.failure_code = "path_mismatch"
                    crep.message = path_err
                    report.failures.append(crep)
                    report.cases.append(crep)
                    _write_failure_bundle(
                        case_out,
                        prog,
                        expected,
                        rr,
                        failure_code="path_mismatch",
                        compare_error=path_err,
                    )
                    continue
            if prog.fallback_contract and mode in ("default", "tier3"):
                crep.message = f"fallback_contract={prog.fallback_contract}"
            # Success-only path events (executed). Structural pairs are NOT edge proofs.
            for ev in rr.path_events or []:
                path = ev.get("path") or ""
                fn = ev.get("fn") or ""
                mod = ev.get("mod") or "(primary)"
                if path.startswith("native"):
                    report.native_tier_hits[path] = report.native_tier_hits.get(path, 0) + 1
                if fn:
                    report.path_by_module.setdefault(mod, {}).setdefault(fn, {})
                    bucket = report.path_by_module[mod][fn]
                    bucket[path] = bucket.get(path, 0) + 1
                    mm = report.path_by_mode_module.setdefault(mode, {})
                    mm.setdefault(mod, {}).setdefault(fn, {})
                    mm[mod][fn][path] = mm[mod][fn].get(path, 0) + 1
            if domain == "c2":
                from .generator_c2 import feature_pairs

                for pair in feature_pairs(prog):
                    report.structural_pair_counts_on_success[pair] = (
                        report.structural_pair_counts_on_success.get(pair, 0) + 1
                    )
            report.cases.append(crep)

    report.elapsed_ms = int((time.time() - t0) * 1000)
    (out_dir / "campaign_report.json").write_text(
        json.dumps(_report_dict(report), indent=2), encoding="utf-8"
    )
    (out_dir / "campaign_summary.txt").write_text(format_summary(report), encoding="utf-8")
    return report


def _native_supported() -> bool:
    import platform

    return platform.system() == "Linux" and platform.machine() in ("x86_64", "AMD64")


def _write_failure_bundle(
    case_out: Path,
    prog,
    expected,
    rr,
    *,
    failure_code: Optional[str] = None,
    compare_error: str = "",
) -> None:
    case_out.mkdir(parents=True, exist_ok=True)
    # Preserve run_program's already-bound ir.json; never overwrite with unbound IR.
    import copy

    ir_path = case_out / "ir.json"
    path_key = rr.bound_path_module_key or getattr(prog, "path_module_key", None)
    path_mod = rr.bound_path_module
    if not path_key:
        path_key = f"sem_fuzz_ir/{prog.case_id}/test"
    if not path_mod:
        path_mod = f"res://sem_fuzz_runs/test/{prog.case_id}/case.vg"
    if ir_path.is_file():
        bound_ir = json.loads(ir_path.read_text(encoding="utf-8"))
    else:
        # Harness/monkeypatch path: synthesize bound snapshot (never unbound-only).
        snap = copy.deepcopy(prog)
        snap.path_module = path_mod
        snap.path_module_key = path_key
        ir_path.write_text(dumps_program(snap), encoding="utf-8")
        bound_ir = json.loads(ir_path.read_text(encoding="utf-8"))
    (case_out / "expected.json").write_text(json.dumps(expected, indent=2), encoding="utf-8")
    (case_out / "actual.json").write_text(json.dumps(rr.observations, indent=2), encoding="utf-8")
    from .provenance import bundle_version_fields

    code = failure_code if failure_code is not None else rr.failure_code
    versions = bundle_version_fields()
    path_key = path_key or bound_ir.get("path_module_key")
    path_mod = path_mod or bound_ir.get("path_module")
    # Consistency: failure metadata must agree with bound ir.json.
    if bound_ir.get("path_module_key") not in (None, path_key):
        raise ValueError(
            f"bound ir path_module_key {bound_ir.get('path_module_key')!r} "
            f"!= run {path_key!r}"
        )
    if bound_ir.get("path_module") not in (None, path_mod):
        raise ValueError(
            f"bound ir path_module {bound_ir.get('path_module')!r} != run {path_mod!r}"
        )
    meta = {
        **versions,
        "failure_code": code,
        "message": rr.message,
        "compare_error": compare_error,
        "mode": rr.mode,
        "env": rr.env,
        "exit_code": rr.exit_code,
        "timed_out": rr.timed_out,
        "path_counts": rr.path_counts,
        "path_target": bound_ir.get("path_target", prog.path_target),
        "path_targets": list(
            bound_ir.get("path_targets")
            or getattr(prog, "path_targets", None)
            or []
        ),
        "path_module_key": path_key,
        "path_module": path_mod,
        "required_path": dict(
            bound_ir.get("required_path") or prog.required_path or {}
        ),
        "fallback_contract": bound_ir.get("fallback_contract", prog.fallback_contract),
        "binary_hash": rr.binary_hash,
        "engine_hash": rr.engine_hash,
        "engine_path": rr.engine_path,
        "replay": f"python3 -m tools.semantic_fuzz replay {case_out}",
    }
    (case_out / "failure.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    # Keep program.json mode authoritative; preserve primary_source / manifests.
    prev = {}
    prog_json = case_out / "program.json"
    if prog_json.is_file():
        try:
            prev = json.loads(prog_json.read_text(encoding="utf-8"))
        except Exception:
            prev = {}
    merged = {
        **prev,
        **versions,
        "case_id": prog.case_id,
        "mode": rr.mode,
        "path_target": meta["path_target"],
        "path_targets": meta["path_targets"],
        "path_module_key": path_key,
        "path_module": path_mod,
        "required_path": meta["required_path"],
        "fallback_contract": meta["fallback_contract"],
        "binary_hash": rr.binary_hash,
        "engine_hash": rr.engine_hash,
        "engine_path": rr.engine_path,
    }
    if "helper_defining_module" not in merged and getattr(
        prog, "helper_defining_module", None
    ):
        merged["helper_defining_module"] = dict(prog.helper_defining_module)
    prog_json.write_text(json.dumps(merged, indent=2), encoding="utf-8")


def _report_dict(report: CampaignReport) -> dict:
    return {
        "seed": report.seed,
        "count": report.count,
        "modes": report.modes,
        "generated": report.generated,
        "distinct": report.distinct,
        "distinct_shapes": report.distinct_shapes,
        "families": report.families,
        "path_totals": report.path_totals,
        "path_by_mode": report.path_by_mode,
        "path_by_module": report.path_by_module,
        "path_by_mode_module": report.path_by_mode_module,
        "structural_pair_counts_on_success": report.structural_pair_counts_on_success,
        "structural_pairs_note": (
            "feature_pairs() is static IR structure of programs that passed; "
            "not proven executed call-edge evidence"
        ),
        "native_tier_hits": report.native_tier_hits,
        "native_tier_hits_total": sum(report.native_tier_hits.values()),
        "failure_count": len(report.failures),
        "failures": [c.__dict__ for c in report.failures],
        "exclusions": report.exclusions,
        "elapsed_ms": report.elapsed_ms,
        "provenance": report.provenance,
        "ok": report.ok,
    }


def format_summary(report: CampaignReport) -> str:
    native_total = sum(report.native_tier_hits.values())
    lines = [
        f"semantic_fuzz campaign seed={report.seed} count={report.count}",
        f"generated={report.generated} distinct={report.distinct} "
        f"distinct_shapes={report.distinct_shapes} modes={','.join(report.modes)}",
        f"elapsed_ms={report.elapsed_ms} failures={len(report.failures)}",
        f"families={report.families}",
        f"path_totals={report.path_totals}",
        f"path_by_mode={report.path_by_mode}",
        f"native_tier_hits={report.native_tier_hits} native_total={native_total}",
        f"structural_pair_counts_on_success={report.structural_pair_counts_on_success}",
        "NOTE: structural pairs ≠ proven executed edges (see path_by_mode_module)",
        f"exclusions={report.exclusions}",
        f"provenance={report.provenance}",
    ]
    if native_total == 0:
        lines.append(
            "NOTE: zero native-tier path hits observed "
            "(requested modes are not evidence of native execution)"
        )
    if report.failures:
        lines.append("FAILURES:")
        for f in report.failures[:20]:
            lines.append(f"  {f.case_id} mode={f.mode} code={f.failure_code} {f.message}")
    return "\n".join(lines) + "\n"


def _resolve_saved_mode(case_dir: Path) -> str:
    """Mode must come from saved provenance; never default to interpreter."""
    prog_meta = case_dir / "program.json"
    if prog_meta.is_file():
        mode = json.loads(prog_meta.read_text(encoding="utf-8")).get("mode")
        if mode in MODES:
            return mode
    fail_meta = case_dir / "failure.json"
    if fail_meta.is_file():
        mode = json.loads(fail_meta.read_text(encoding="utf-8")).get("mode")
        if mode in MODES:
            return mode
    # Directory layout …/<case_id>/<mode>/
    if case_dir.name in MODES:
        return case_dir.name
    raise ValueError(f"cannot determine execution mode for replay of {case_dir}")


def _check_replay_provenance(case_dir: Path) -> Optional[str]:
    """Schema/model hard-refuse (shared with reduction). Runtime hashes are soft labels."""
    from .provenance import check_bundle_provenance

    return check_bundle_provenance(case_dir, compare_runtime=False).refuse


def replay_case_dir(case_dir: Path) -> CaseReport:
    from .provenance import check_bundle_provenance

    case_dir = Path(case_dir)
    ir_path = case_dir / "ir.json"
    if not ir_path.is_file():
        raise FileNotFoundError(f"no ir.json in {case_dir}")
    # Schema/model first (before running Godot).
    pre = check_bundle_provenance(case_dir, compare_runtime=False)
    if pre.refuse:
        raise ValueError(f"replay refused: {pre.refuse}")
    from .bundle_integrity import validate_bundle_integrity

    integ = validate_bundle_integrity(case_dir)
    if integ:
        raise ValueError(f"replay refused: {integ}")
    prog = loads_program(ir_path.read_text(encoding="utf-8"))
    # Replay reconstruct boundary: validate metadata agreement, then clear physical.
    prog_meta_path = case_dir / "program.json"
    if prog_meta_path.is_file():
        pmeta = json.loads(prog_meta_path.read_text(encoding="utf-8"))
        if pmeta.get("path_module_key") not in (None, prog.path_module_key):
            raise ValueError(
                f"replay refused: ir/program path_module_key mismatch "
                f"ir={prog.path_module_key!r} program={pmeta.get('path_module_key')!r}"
            )
        if prog.path_module and pmeta.get("path_module") not in (None, prog.path_module):
            raise ValueError(
                f"replay refused: ir/program path_module mismatch "
                f"ir={prog.path_module!r} program={pmeta.get('path_module')!r}"
            )
        for key in ("path_target", "path_targets", "required_path", "fallback_contract"):
            if key in pmeta and pmeta[key] not in (None, [], {}):
                ir_val = getattr(prog, key, None)
                if key == "path_targets":
                    ir_val = list(ir_val or [])
                    if list(pmeta[key]) != ir_val:
                        raise ValueError(f"replay refused: ir/program {key} mismatch")
                elif key == "required_path":
                    if dict(pmeta[key]) != dict(ir_val or {}):
                        raise ValueError(f"replay refused: ir/program {key} mismatch")
                elif pmeta[key] != ir_val:
                    raise ValueError(f"replay refused: ir/program {key} mismatch")
    fail_meta_path = case_dir / "failure.json"
    if fail_meta_path.is_file():
        fmeta = json.loads(fail_meta_path.read_text(encoding="utf-8"))
        if fmeta.get("path_module_key") not in (None, prog.path_module_key):
            raise ValueError(
                f"replay refused: ir/failure path_module_key mismatch "
                f"ir={prog.path_module_key!r} failure={fmeta.get('path_module_key')!r}"
            )
    saved_key = prog.path_module_key
    # Only this reconstruct boundary may clear a saved physical mapping.
    prog.path_module = None
    mode = _resolve_saved_mode(case_dir)
    expected = [o.to_dict() for o in evaluate_program(prog).observations]
    saved_expected_path = case_dir / "expected.json"
    if saved_expected_path.is_file():
        saved = json.loads(saved_expected_path.read_text(encoding="utf-8"))
        compare_observations(expected, saved)
    work_root = case_dir.parent.parent if case_dir.parent.name == prog.case_id else case_dir.parent
    rr = run_program(prog, mode=mode, work_root=work_root / "_replay", timeout_secs=20.0)
    post = check_bundle_provenance(
        case_dir,
        binary_hash=rr.binary_hash,
        engine_hash=rr.engine_hash,
        engine_path=rr.engine_path,
        compare_runtime=True,
    )
    env_note = post.environment_label
    crep = CaseReport(
        case_id=prog.case_id,
        family=prog.family,
        mode=mode,
        status="pass",
        path_counts=rr.path_counts,
        elapsed_ms=rr.elapsed_ms,
        work_dir=str(case_dir),
        message=env_note,
    )
    if not rr.ok:
        crep.status = "fail"
        crep.failure_code = rr.failure_code
        crep.message = (rr.message + ("; " + env_note if env_note else "")).strip("; ")
        return crep
    try:
        compare_observations(expected, rr.observations)
    except CompareError as exc:
        crep.status = "fail"
        crep.failure_code = exc.code
        crep.message = str(exc) + ("; " + env_note if env_note else "")
        return crep
    if saved_key and rr.bound_path_module_key and saved_key != rr.bound_path_module_key:
        crep.status = "fail"
        crep.failure_code = "path_mismatch"
        crep.message = (
            f"path_module_key drift: saved={saved_key} run={rr.bound_path_module_key}"
            + ("; " + env_note if env_note else "")
        )
        return crep
    path_err = check_required_path(prog, mode, rr)
    if path_err:
        crep.status = "fail"
        crep.failure_code = "path_mismatch"
        crep.message = path_err + ("; " + env_note if env_note else "")
        return crep
    return crep
