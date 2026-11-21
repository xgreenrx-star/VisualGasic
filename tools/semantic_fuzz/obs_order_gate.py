"""Mode-aware observational order gate.

The suite fixtures do not read a caller-supplied tier env. They print
OBSERVED_UNSETTLED lines. This gate runs the fixtures, reads VG_SEM_PATH
events inside each marked window, and accepts an order only when it matches
the tier those events actually recorded.

BAN vs ABN, and the first Left(s:=, n:=) split, are unsettled observations
of the AST walker versus the compiler rewriting the live AST. They are not
a language contract. A bytecode-class window that shows the AST order fails,
and an AST-class window that shows the compiler order fails. The requested
mode must match the recorded class; a path that disagrees is wrong_path
even when the order string happens to look right for the request.

left_named_after_bail is the same order on both classes: compilation bails
at the bad name and does not rewrite the later call node.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Dict, List, Optional, Sequence

from .path_contract import parse_path_event_line

MODES = ("forced_ast", "interpreter", "default", "tier3")

# Measured path shapes. fn/tier pairs inside the window, in order.
# named_order under interpreter records only TakeNamed. SideA and SideB still
# run (the order string is ABN) but emit no path event in that mode. default
# and tier3 record SideA, SideB, then TakeNamed. forced_ast records source
# order, all ast. These are observations, not a language contract.
NAMED_FNS = frozenset({"SideA", "SideB", "TakeNamed"})
LEFT_FNS = frozenset({"SA", "SN"})
_BC_NAMED = (("SideA", "bytecode"), ("SideB", "bytecode"), ("TakeNamed", "bytecode"))
_BC_NA = (("SN", "bytecode"), ("SA", "bytecode"))
_BC_AN = (("SA", "bytecode"), ("SN", "bytecode"))
_AST_AN = (("SA", "ast"), ("SN", "ast"))

EXPECT = {
    ("named_order", "forced_ast"): {
        "fns": NAMED_FNS,
        "shape": (("SideB", "ast"), ("SideA", "ast"), ("TakeNamed", "ast")),
        "order": "BAN",
        "result": "1020",
    },
    ("named_order", "interpreter"): {
        "fns": NAMED_FNS,
        "shape": (("TakeNamed", "bytecode"),),
        "order": "ABN",
        "result": "1020",
    },
    ("named_order", "default"): {
        "fns": NAMED_FNS,
        "shape": _BC_NAMED,
        "order": "ABN",
        "result": "1020",
    },
    ("named_order", "tier3"): {
        "fns": NAMED_FNS,
        "shape": _BC_NAMED,
        "order": "ABN",
        "result": "1020",
    },
    ("left_named_first", "forced_ast"): {
        "fns": LEFT_FNS,
        "shape": _AST_AN,
        "order": "AN",
        "result": "a",
    },
    ("left_named_after_bail", "forced_ast"): {
        "fns": LEFT_FNS,
        "shape": _AST_AN,
        "order": "AN",
        "result": "a",
    },
}
for _mode in ("interpreter", "default", "tier3"):
    EXPECT[("left_named_first", _mode)] = {
        "fns": LEFT_FNS,
        "shape": _BC_NA,
        "order": "NA",
        "result": "",
    }
    EXPECT[("left_named_after_bail", _mode)] = {
        "fns": LEFT_FNS,
        "shape": _BC_AN,
        "order": "AN",
        "result": "a",
    }

FIXTURES = {
    "test_ast_byval_arg_once.vg": {
        "summary_kind": "c2",
        "passed": 15,
        "windows": ("named_order",),
    },
    "test_ast_byval_dispatch_probe.vg": {
        "summary_kind": "dispatch",
        "passed": 12,
        "windows": ("left_named_first", "left_named_after_bail"),
    },
    "test_named_byref_writeback.vg": {
        "summary_kind": "c2",
        "passed": 22,
        "windows": (),
    },
}

BEGIN_RE = re.compile(r"^OBS_WINDOW_BEGIN kind=(\S+)\s*$")
OBS_RE = re.compile(
    r'^OBSERVED_UNSETTLED kind=(\S+) result="([^"]*)" order=(\S+)\s*$'
)
C2_RE = re.compile(r"^C2_SUMMARY passed=(\d+) failed=(\d+)\s*$")
DISPATCH_RE = re.compile(r"^DISPATCH_SUMMARY ok=(\d+) bad=(\d+)\s*$")


def _shape(events: Sequence[dict], fns: frozenset) -> tuple:
    return tuple((e.get("fn"), e.get("path")) for e in events if e.get("fn") in fns)


def judge_window(
    kind: str,
    mode: str,
    order: str,
    result: str,
    events: Sequence[dict],
) -> List[str]:
    """Return error tags. Empty means this mode's measured path shape and order."""
    spec = EXPECT.get((kind, mode))
    if spec is None:
        return [f"unknown_window:{kind} mode={mode}"]
    got = _shape(events, spec["fns"])
    errs: List[str] = []
    if got != spec["shape"]:
        errs.append(f"wrong_path kind={kind} mode={mode} got={got} want={spec['shape']}")
    if order != spec["order"]:
        errs.append(
            f"wrong_order kind={kind} mode={mode} want={spec['order']} order={order}"
        )
    if result != spec["result"]:
        errs.append(
            f"wrong_result kind={kind} mode={mode} want={spec['result']!r} got={result!r}"
        )
    return errs


def parse_windows(text: str) -> tuple[Dict[str, dict], List[str]]:
    """Split a Godot log into closed observation windows."""
    windows: Dict[str, dict] = {}
    errs: List[str] = []
    current: Optional[str] = None
    events: List[dict] = []
    for raw in text.splitlines():
        line = raw.rstrip("\r\n")
        begin = BEGIN_RE.match(line)
        if begin:
            if current is not None:
                errs.append(f"unclosed_window:{current}")
            current = begin.group(1)
            events = []
            continue
        obs = OBS_RE.match(line)
        if obs:
            kind, result, order = obs.group(1), obs.group(2), obs.group(3)
            if current != kind:
                errs.append(f"window_mismatch begin={current} obs={kind}")
            if kind in windows:
                errs.append(f"duplicate_window:{kind}")
            windows[kind] = {"order": order, "result": result, "events": list(events)}
            current = None
            events = []
            continue
        if line.startswith("VG_SEM_PATH"):
            try:
                ev = parse_path_event_line(line)
            except ValueError as exc:
                errs.append(f"malformed_path:{exc}")
                continue
            if ev is not None and current is not None:
                events.append(ev)
    if current is not None:
        errs.append(f"unclosed_window:{current}")
    return windows, errs


def run_obs_order_selftests() -> List[str]:
    """Injected wrong order and wrong path. No Godot."""
    fails: List[str] = []

    def check(label: str, errs: List[str], want_substr: Optional[str]) -> None:
        blob = " ".join(errs)
        if want_substr is None:
            if errs:
                fails.append(f"{label}: expected accept got {errs}")
        elif want_substr not in blob:
            fails.append(f"{label}: expected {want_substr} in {errs}")

    ast_named = [
        {"path": "ast", "fn": "SideB"},
        {"path": "ast", "fn": "SideA"},
        {"path": "ast", "fn": "TakeNamed"},
    ]
    bc_named = [
        {"path": "bytecode", "fn": "SideA"},
        {"path": "bytecode", "fn": "SideB"},
        {"path": "bytecode", "fn": "TakeNamed"},
    ]
    interp_named = [{"path": "bytecode", "fn": "TakeNamed"}]
    check(
        "accept_ast_ban",
        judge_window("named_order", "forced_ast", "BAN", "1020", ast_named),
        None,
    )
    check(
        "accept_interpreter_abn",
        judge_window("named_order", "interpreter", "ABN", "1020", interp_named),
        None,
    )
    check(
        "accept_default_abn",
        judge_window("named_order", "default", "ABN", "1020", bc_named),
        None,
    )
    check(
        "accept_tier3_abn",
        judge_window("named_order", "tier3", "ABN", "1020", bc_named),
        None,
    )
    check(
        "wrong_order_ast_got_abn",
        judge_window("named_order", "forced_ast", "ABN", "1020", ast_named),
        "wrong_order",
    )
    check(
        "wrong_order_interpreter_got_ban",
        judge_window("named_order", "interpreter", "BAN", "1020", interp_named),
        "wrong_order",
    )
    check(
        "wrong_path_forced_ast_saw_bytecode",
        judge_window("named_order", "forced_ast", "BAN", "1020", bc_named),
        "wrong_path",
    )
    check(
        "wrong_path_interpreter_saw_ast",
        judge_window("named_order", "interpreter", "ABN", "1020", ast_named),
        "wrong_path",
    )
    check(
        "wrong_path_default_saw_interpreter_shape",
        judge_window("named_order", "default", "ABN", "1020", interp_named),
        "wrong_path",
    )
    check(
        "wrong_path_native_not_measured",
        judge_window(
            "named_order",
            "tier3",
            "ABN",
            "1020",
            [
                {"path": "native_t2", "fn": "SideA"},
                {"path": "native_t2", "fn": "SideB"},
                {"path": "native_t2", "fn": "TakeNamed"},
            ],
        ),
        "wrong_path",
    )

    ast_an = [{"path": "ast", "fn": "SA"}, {"path": "ast", "fn": "SN"}]
    bc_na = [{"path": "bytecode", "fn": "SN"}, {"path": "bytecode", "fn": "SA"}]
    bc_an = [{"path": "bytecode", "fn": "SA"}, {"path": "bytecode", "fn": "SN"}]
    check(
        "accept_left_first_ast",
        judge_window("left_named_first", "forced_ast", "AN", "a", ast_an),
        None,
    )
    check(
        "accept_left_first_bytecode",
        judge_window("left_named_first", "default", "NA", "", bc_na),
        None,
    )
    check(
        "wrong_order_left_first_bytecode_source",
        judge_window("left_named_first", "interpreter", "AN", "a", bc_an),
        "wrong_order",
    )
    check(
        "wrong_path_left_first_bytecode_source",
        judge_window("left_named_first", "interpreter", "AN", "a", bc_an),
        "wrong_path",
    )
    check(
        "accept_after_bail_bytecode_source",
        judge_window("left_named_after_bail", "tier3", "AN", "a", bc_an),
        None,
    )
    check(
        "wrong_order_after_bail_na",
        judge_window("left_named_after_bail", "interpreter", "NA", "", bc_na),
        "wrong_order",
    )
    check(
        "wrong_path_after_bail_ast_under_default",
        judge_window("left_named_after_bail", "default", "AN", "a", ast_an),
        "wrong_path",
    )

    # Negatives go through judge_obs_run, the same entry run_gate uses.
    spec = FIXTURES["test_ast_byval_arg_once.vg"]
    good = _synthetic_named_log()
    check(
        "accept_gate_synthetic",
        judge_obs_run(good, spec, "test_ast_byval_arg_once.vg", "forced_ast", 0),
        None,
    )
    check(
        "child_exit_17",
        judge_obs_run(good, spec, "test_ast_byval_arg_once.vg", "forced_ast", 17),
        "child_exit=17",
    )
    check(
        "script_error",
        judge_obs_run(
            good + "SCRIPT ERROR: Parse Error: boom\n",
            spec,
            "test_ast_byval_arg_once.vg",
            "forced_ast",
            0,
        ),
        "runtime_error",
    )
    check(
        "missing_completion",
        judge_obs_run(
            good.replace("VG_SUITE_COMPLETED\n", ""),
            spec,
            "test_ast_byval_arg_once.vg",
            "forced_ast",
            0,
        ),
        "missing_completion",
    )
    check(
        "duplicate_summary",
        judge_obs_run(
            good.replace(
                "C2_SUMMARY passed=15 failed=0\n",
                "C2_SUMMARY passed=15 failed=0\nC2_SUMMARY passed=15 failed=0\n",
            ),
            spec,
            "test_ast_byval_arg_once.vg",
            "forced_ast",
            0,
        ),
        "duplicate_summary",
    )
    check(
        "malformed_summary",
        judge_obs_run(
            good.replace("C2_SUMMARY passed=15 failed=0", "C2_SUMMARY passed=15"),
            spec,
            "test_ast_byval_arg_once.vg",
            "forced_ast",
            0,
        ),
        "malformed_summary",
    )
    wrong_mod = good.replace(
        'fn=SideB mod="res://test_suite/test_ast_byval_arg_once.vg"',
        'fn=SideB mod="res://test_suite/other.vg"',
        1,
    )
    check(
        "wrong_module",
        judge_obs_run(wrong_mod, spec, "test_ast_byval_arg_once.vg", "forced_ast", 0),
        "wrong_module",
    )
    return fails


def _synthetic_named_log() -> str:
    mod = "res://test_suite/test_ast_byval_arg_once.vg"
    lines = [
        "OBS_WINDOW_BEGIN kind=named_order",
        f'VG_SEM_PATH path=ast fn=SideB mod="{mod}"',
        f'VG_SEM_PATH path=ast fn=SideA mod="{mod}"',
        f'VG_SEM_PATH path=ast fn=TakeNamed mod="{mod}"',
        'OBSERVED_UNSETTLED kind=named_order result="1020" order=BAN',
        "C2_SUMMARY passed=15 failed=0",
        "VG_SUITE_COMPLETED",
    ]
    return "\n".join(lines) + "\n"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _run_one(
    godot: Path,
    project: Path,
    fixture: str,
    mode: str,
    log_path: Path,
    user_dir: Path,
) -> tuple:
    env = os.environ.copy()
    for key in ("VG_FORCE_AST", "VG_JIT", "VG_JIT_LOG", "VG_OBS_TIER"):
        env.pop(key, None)
    env["VG_SEM_PATH"] = "1"
    if mode == "forced_ast":
        env["VG_FORCE_AST"] = "1"
    elif mode == "interpreter":
        env["VG_JIT"] = "0"
    elif mode == "tier3":
        env["VG_JIT"] = "3"
    elif mode != "default":
        raise ValueError(mode)
    user_dir.mkdir(parents=True, exist_ok=True)
    cmd = [
        str(godot),
        "--headless",
        "--path",
        str(project),
        "--user-data-dir",
        str(user_dir),
        "-s",
        "run_suite.gd",
        "--",
        f"res://test_suite/{fixture}",
    ]
    proc = subprocess.run(
        cmd,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=70,
        check=False,
    )
    log_path.write_text(proc.stdout, encoding="utf-8", errors="replace")
    return proc.stdout, proc.returncode


_RUNTIME_MARKERS = (
    "SCRIPT ERROR",
    "Parser Error",
    "VG Runtime Error",
    "Unhandled runtime error",
)


def judge_obs_run(
    text: str,
    spec: dict,
    fixture: str,
    mode: str,
    returncode: int,
) -> List[str]:
    """Fail closed for the process that produced this log.

    Observational order stays an observation. A plausible summary does not
    hide a nonzero exit, a runtime error, a missing or repeated completion,
    a bad summary, or a path event from the wrong module.
    """
    errs: List[str] = []
    if returncode != 0:
        errs.append(f"child_exit={returncode}")
    for ln in text.splitlines():
        if any(marker in ln for marker in _RUNTIME_MARKERS):
            errs.append(f"runtime_error:{ln.strip()[:180]}")
            break
    done = [ln for ln in text.splitlines() if ln.strip() == "VG_SUITE_COMPLETED"]
    if not done:
        errs.append("missing_completion")
    elif len(done) > 1:
        errs.append(f"duplicate_completion:{len(done)}")
    prefix = "C2_SUMMARY" if spec["summary_kind"] == "c2" else "DISPATCH_SUMMARY"
    pat = C2_RE if spec["summary_kind"] == "c2" else DISPATCH_RE
    other = "DISPATCH_SUMMARY" if prefix == "C2_SUMMARY" else "C2_SUMMARY"
    summaries = []
    for ln in text.splitlines():
        if ln.startswith(prefix) or ln.startswith(other):
            matched = pat.match(ln)
            if matched is None:
                errs.append(f"malformed_summary:{ln.strip()[:180]}")
            else:
                summaries.append(matched)
    if not summaries and not any(e.startswith("malformed_summary") for e in errs):
        errs.append(f"missing_summary:{prefix}")
    elif len(summaries) > 1:
        errs.append(f"duplicate_summary:{len(summaries)}")
    elif len(summaries) == 1:
        passed, failed = int(summaries[0].group(1)), int(summaries[0].group(2))
        if failed != 0 or passed != spec["passed"]:
            errs.append(
                f"summary passed={passed} failed={failed} want passed={spec['passed']} failed=0"
            )
    fail_lines = [ln for ln in text.splitlines() if ln.startswith("FAIL:")]
    if fail_lines:
        errs.append(f"fail_lines={fail_lines[:4]}")
    windows, perr = parse_windows(text)
    errs.extend(perr)
    want_mod = f"res://test_suite/{fixture}"
    for kind in spec["windows"]:
        if kind not in windows:
            errs.append(f"missing window {kind}")
            continue
        window = windows[kind]
        fns = EXPECT[(kind, mode)]["fns"]
        for ev in window["events"]:
            if ev.get("fn") not in fns:
                continue
            if ev.get("mod") != want_mod:
                errs.append(
                    f"wrong_module fn={ev.get('fn')} got={ev.get('mod')!r} want={want_mod!r}"
                )
        errs.extend(
            judge_window(kind, mode, window["order"], window["result"], window["events"])
        )
    return errs


def _passing_log(fixture: str, mode: str) -> str:
    """A log judge_obs_run accepts for this fixture and mode at exit 0."""
    spec = FIXTURES[fixture]
    mod = f"res://test_suite/{fixture}"
    lines: List[str] = []
    for kind in spec["windows"]:
        exp = EXPECT[(kind, mode)]
        lines.append(f"OBS_WINDOW_BEGIN kind={kind}")
        for fn, tier in exp["shape"]:
            lines.append(f'VG_SEM_PATH path={tier} fn={fn} mod="{mod}"')
        lines.append(
            f'OBSERVED_UNSETTLED kind={kind} result="{exp["result"]}" order={exp["order"]}'
        )
    if spec["summary_kind"] == "c2":
        lines.append(f"C2_SUMMARY passed={spec['passed']} failed=0")
    else:
        lines.append(f"DISPATCH_SUMMARY ok={spec['passed']} bad=0")
    lines.append("VG_SUITE_COMPLETED")
    return "\n".join(lines) + "\n"


def run_obs_gate_entry_probes(dest: Optional[Path] = None) -> List[str]:
    """Call run_gate with a patched child. The production binary is not used.

    Each probe writes obs_order_gate.json. A plausible log plus exit 17, a
    wrong module, a wrong summary count, a malformed completion line, and a
    duplicate completion must all make run_gate return nonzero.
    """
    fails: List[str] = []
    root = dest or Path(tempfile.mkdtemp(prefix="vg-obs-gate-entry-"))
    project = root / "project"
    suite = project / "test_suite"
    suite.mkdir(parents=True, exist_ok=True)
    for name in FIXTURES:
        (suite / name).write_text("' gate entry probe\n", encoding="utf-8")
    so = project / "addons/visual_gasic/bin/libvisualgasic.linux.editor.x86_64.so"
    so.parent.mkdir(parents=True, exist_ok=True)
    so.write_bytes(b"gate-entry-probe-not-a-binary")
    original = globals()["_run_one"]

    def check(label: str, kind: str, want: str) -> None:
        def fake_run_one(godot, project, fixture, mode, log_path, user_dir):
            del godot, project, user_dir
            text = _passing_log(fixture, mode)
            rc = 0
            if kind == "exit17":
                rc = 17
            elif kind == "wrong_module" and fixture == "test_ast_byval_arg_once.vg":
                text = text.replace(
                    'mod="res://test_suite/test_ast_byval_arg_once.vg"',
                    'mod="res://test_suite/other.vg"',
                    1,
                )
            elif kind == "wrong_count":
                text = re.sub(r"passed=\d+", "passed=0", text, count=1)
                text = re.sub(r"ok=\d+", "ok=0", text, count=1)
            elif kind == "malformed_completion":
                text = text.replace(
                    "VG_SUITE_COMPLETED\n", "VG_SUITE_COMPLETED EXTRA\n"
                )
            elif kind == "duplicate_completion":
                text = text.replace(
                    "VG_SUITE_COMPLETED\n",
                    "VG_SUITE_COMPLETED\nVG_SUITE_COMPLETED\n",
                )
            log_path.parent.mkdir(parents=True, exist_ok=True)
            log_path.write_text(text, encoding="utf-8")
            return text, rc

        globals()["_run_one"] = fake_run_one
        out = root / label
        try:
            rc = run_gate(project, Path("/tmp/vg-obs-gate-entry-no-godot"), out)
        finally:
            globals()["_run_one"] = original
        report_path = out / "obs_order_gate.json"
        if not report_path.is_file():
            fails.append(f"{label}: missing {report_path}")
            return
        report = json.loads(report_path.read_text(encoding="utf-8"))
        blob = " ".join(report.get("problems") or [])
        if rc == 0 or report.get("ok"):
            fails.append(f"{label}: gate accepted rc={rc} ok={report.get('ok')}")
        elif want not in blob:
            fails.append(f"{label}: expected {want} in {report.get('problems')}")
        if kind == "exit17":
            problems = report.get("problems") or []
            if len(problems) != len(FIXTURES) * len(MODES):
                fails.append(f"{label}: problem count {len(problems)}")
            extra = [p for p in problems if "child_exit=17" not in p]
            if extra:
                fails.append(f"{label}: extra problems {extra[:4]}")

    try:
        check("exit17", "exit17", "child_exit=17")
        check("wrong_module", "wrong_module", "wrong_module")
        check("wrong_count", "wrong_count", "want passed=")
        check("malformed_completion", "malformed_completion", "missing_completion")
        check("duplicate_completion", "duplicate_completion", "duplicate_completion")
    finally:
        globals()["_run_one"] = original
    return fails


def run_gate(project: Path, godot: Path, out: Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    t0 = time.perf_counter()
    problems: List[str] = []
    suite_dir = project / "test_suite"
    for name in FIXTURES:
        text = (suite_dir / name).read_text(encoding="utf-8")
        if "VG_OBS_TIER" in text:
            problems.append(f"{name} still reads VG_OBS_TIER")
    so = (project / "addons/visual_gasic/bin/libvisualgasic.linux.editor.x86_64.so").resolve()
    binary_hash = _sha256(so) if so.is_file() else ""
    if not binary_hash:
        problems.append(f"missing binary {so}")
    runs = []
    for fixture, spec in FIXTURES.items():
        for mode in MODES:
            log_path = out / f"{mode}_{fixture}.log"
            user_dir = out / f"user_{mode}_{fixture}"
            try:
                text, returncode = _run_one(godot, project, fixture, mode, log_path, user_dir)
            except subprocess.TimeoutExpired:
                problems.append(f"timeout {mode} {fixture}")
                continue
            errs = judge_obs_run(text, spec, fixture, mode, returncode)
            if errs:
                problems.extend(f"{mode} {fixture} {e}" for e in errs)
            windows, _perr = parse_windows(text)
            judged = []
            for kind in spec["windows"]:
                if kind not in windows:
                    continue
                w = windows[kind]
                judged.append(
                    {
                        "kind": kind,
                        "order": w["order"],
                        "result": w["result"],
                        "errs": [
                            e
                            for e in errs
                            if kind in e or e.startswith("wrong_") or e.startswith("missing window")
                        ],
                    }
                )
            runs.append(
                {
                    "fixture": fixture,
                    "mode": mode,
                    "returncode": returncode,
                    "windows": judged,
                    "problems": errs,
                }
            )
    elapsed = round(time.perf_counter() - t0, 3)
    report = {
        "ok": not problems,
        "problems": problems,
        "binary": str(so),
        "binary_hash": binary_hash,
        "elapsed_sec": elapsed,
        "runs": runs,
    }
    (out / "obs_order_gate.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        f"OBS_ORDER_GATE ok={not problems} problems={len(problems)} "
        f"runs={len(runs)} elapsed_sec={elapsed} binary_hash={binary_hash}"
    )
    for p in problems:
        print(" ", p)
    return 0 if not problems else 1


def main(argv: Optional[Sequence[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Observational order gate")
    p.add_argument("--project", required=True, help="test_proj directory")
    p.add_argument("--godot", default=os.environ.get("GODOT", ""))
    p.add_argument("--out", required=True)
    args = p.parse_args(argv)
    if not args.godot:
        print("OBS_ORDER_GATE missing GODOT")
        return 2
    return run_gate(Path(args.project), Path(args.godot), Path(args.out))
