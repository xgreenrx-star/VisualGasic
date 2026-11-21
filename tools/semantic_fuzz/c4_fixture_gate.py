"""Fail-closed C4 short-circuit/error fixture gate.

Runs the focused sem_c4 fixtures serially under four requested modes and
rejects silent false passes. Path requirements record verified execution
tiers; they are not a language contract. Native Tier 3 is never required.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

from .path_contract import (
    PathRequirement,
    check_required_path_events,
    parse_path_event_line,
)

MODES = ("forced_ast", "interpreter", "default", "tier3")


SC_MOD = "res://test_suite/test_sem_c4_shortcircuit.vg"
ERR_MOD = "res://test_suite/test_sem_c4_errors.vg"
FX_MOD = "res://test_suite/test_sem_c4_finally_exit.vg"
CL_MOD = "res://test_suite/test_sem_c4_const_logic.vg"

_AST = {"forced_ast": "ast", "interpreter": "ast", "default": "ast", "tier3": "ast"}
_AST_BC = {
    "forced_ast": "ast",
    "interpreter": "bytecode",
    "default": "bytecode",
    "tier3": "bytecode",
}


def _req(fn: str, mod: str, mode_paths: dict) -> PathRequirement:
    return PathRequirement(fn=fn, mod=mod, mode_paths=mode_paths)


def _sc_pass_labels() -> tuple:
    labels = [
        "c4_andalso_ft_r",
        "c4_andalso_ft_log",
        "c4_andalso_ft_a",
        "c4_andalso_ft_b",
        "c4_andalso_ft_a_vt",
        "c4_andalso_tt_r",
        "c4_andalso_tt_log",
        "c4_andalso_tt_a",
        "c4_andalso_tt_b",
        "c4_andalso_tt_a_vt",
        "c4_orelse_tf_r",
        "c4_orelse_tf_log",
        "c4_orelse_tf_a",
        "c4_orelse_tf_b",
        "c4_orelse_tf_a_vt",
        "c4_orelse_ft_r",
        "c4_orelse_ft_log",
        "c4_orelse_ft_a",
        "c4_orelse_ft_b",
        "c4_orelse_ft_a_vt",
        "c4_and_ft_r",
        "c4_and_ft_log",
        "c4_and_ft_a",
        "c4_and_ft_b",
        "c4_and_ft_a_vt",
        "c4_or_tf_r",
        "c4_or_tf_log",
        "c4_or_tf_a",
        "c4_or_tf_b",
        "c4_or_tf_a_vt",
        "c4_assign_andalso_r",
        "c4_assign_andalso_log",
        "c4_assign_andalso_a",
        "c4_assign_andalso_b",
        "c4_assign_andalso_a_vt",
        "c4_elseif_r",
        "c4_elseif_log",
        "c4_elseif_a",
        "c4_elseif_b",
        "c4_dowhile_n",
        "c4_dowhile_log",
        "c4_arg_r",
        "c4_arg_log",
        "c4_arg_a",
        "c4_arg_b",
        "c4_arg_c",
    ]
    for i in range(16):
        labels.append(f"c4_nest_{i}_r")
        labels.append(f"c4_nest_{i}_log")
    labels.append("sem_c4_shortcircuit")
    return tuple(labels)


SC_PASS_LABELS = _sc_pass_labels()

ERR_PASS_LABELS = (
    "c4_err_resume_log",
    "c4_err_resume_num",
    "c4_err_resume_num_type",
    "c4_err_resume_num_vt",
    "c4_err_goto_log",
    "c4_err_try_log",
    "c4_err_try_num",
    "c4_err_try_ok_log",
    "c4_err_nested_log",
    "c4_err_nested_num",
    "sem_c4_errors",
)

FX_PASS_LABELS = (
    "c4_fx_sub_log",
    "c4_fx_fn_log",
    "c4_fx_fn_n",
    "c4_fx_fn_vt",
    "c4_fx_for_log",
    "c4_fx_do_log",
    "c4_fx_nest_log",
    "c4_fx_catch_log",
    "c4_fx_ret_log",
    "c4_fx_ret_n",
    "c4_fx_ret_vt",
    "c4_fx_cont_log",
    "sem_c4_finally_exit",
)

_CL_TAGS = (
    "aa_tt",
    "aa_tf",
    "aa_ft",
    "aa_ff",
    "oe_tt",
    "oe_tf",
    "oe_ft",
    "oe_ff",
    "cmp_aa_tt",
    "cmp_aa_tf",
    "cmp_aa_ft",
    "cmp_oe_ft",
    "cmp_oe_tf",
    "mix_vv",
    "mix_lv",
    "mix_vl",
    "and_tt",
    "not_t",
    "not_f",
)


def _cl_pass_labels() -> tuple:
    labels = []
    for tag in _CL_TAGS:
        labels.append(f"c4_cl_{tag}_tn")
        labels.append(f"c4_cl_{tag}_vt")
        labels.append(f"c4_cl_{tag}_v")
    labels.append("c4_cl_if_r")
    labels.append("c4_cl_arg_r")
    labels.append("sem_c4_const_logic")
    return tuple(labels)


CL_PASS_LABELS = _cl_pass_labels()

FIXTURES = {
    "test_sem_c4_shortcircuit.vg": {
        "summary_passed": len(SC_PASS_LABELS) - 1,
        "pass_labels": SC_PASS_LABELS,
        "path_requirements": (
            _req("_Ready", SC_MOD, _AST_BC),
            _req("RunBasics", SC_MOD, _AST_BC),
            _req("RunNestTable", SC_MOD, _AST_BC),
            _req("HitA", SC_MOD, _AST_BC),
            _req("HitB", SC_MOD, _AST_BC),
            _req("HitC", SC_MOD, _AST_BC),
            _req("HitD", SC_MOD, _AST_BC),
            _req("NestCombo", SC_MOD, _AST_BC),
        ),
        "unverified_helpers": ("AssertObs", "ResetHits", "CheckPair", "Mark"),
    },
    "test_sem_c4_errors.vg": {
        "summary_passed": len(ERR_PASS_LABELS) - 1,
        "pass_labels": ERR_PASS_LABELS,
        "path_requirements": (
            _req("_Ready", ERR_MOD, _AST_BC),
            _req("RunResumeNext", ERR_MOD, _AST_BC),
            _req("RunGotoHandler", ERR_MOD, _AST_BC),
            _req("RunTryCatchFinally", ERR_MOD, _AST_BC),
            _req("OuterGotoHandler", ERR_MOD, _AST_BC),
            _req("InnerNoHandler", ERR_MOD, _AST_BC),
            _req("Mark", ERR_MOD, _AST_BC),
        ),
        "unverified_helpers": ("AssertObs",),
    },
    "test_sem_c4_finally_exit.vg": {
        "summary_passed": len(FX_PASS_LABELS) - 1,
        "pass_labels": FX_PASS_LABELS,
        "path_requirements": (
            _req("_Ready", FX_MOD, _AST_BC),
            _req("ExitSubBody", FX_MOD, _AST_BC),
            _req("ExitFnBody", FX_MOD, _AST_BC),
            _req("ExitForBody", FX_MOD, _AST_BC),
            _req("ExitDoBody", FX_MOD, _AST_BC),
            _req("NestedExit", FX_MOD, _AST_BC),
            _req("ExitCatchBody", FX_MOD, _AST_BC),
            _req("RetBody", FX_MOD, _AST_BC),
            _req("ContinueForBody", FX_MOD, _AST_BC),
            _req("Mark", FX_MOD, _AST_BC),
        ),
        "unverified_helpers": ("AssertObs",),
    },
    "test_sem_c4_const_logic.vg": {
        "summary_passed": len(CL_PASS_LABELS) - 1,
        "pass_labels": CL_PASS_LABELS,
        "path_requirements": (
            _req("_Ready", CL_MOD, _AST_BC),
            _req("CheckB", CL_MOD, _AST_BC),
            _req("Take", CL_MOD, _AST_BC),
        ),
        "unverified_helpers": ("AssertObs",),
    },
}


PASS_RE = re.compile(r"^PASS:\s*(.+?)\s*$")
FAIL_RE = re.compile(r"^FAIL:\s*(.+?)\s*$")
SUMMARY_RE = re.compile(r"^C4_SUMMARY passed=(\d+) failed=(\d+)\s*$")
# Recognized markers; leading whitespace before these is fail-closed.
_MARKER_HEAD = re.compile(
    r"^(?:"
    r"PASS:|FAIL:|C4_SUMMARY|VG_SUITE_COMPLETED|VG_SEM_PATH|"
    r"ERROR:|SCRIPT ERROR|Parser Error|VG Runtime Error|"
    r"Unhandled runtime error|handle_crash:)"
)
RUNTIME_MARKERS = (
    "SCRIPT ERROR",
    "Parser Error",
    "VG Runtime Error",
    "Unhandled runtime error",
    "handle_crash:",
)

REPORT_JSON = "c4_fixture_gate.json"
REPORT_SUMMARY = "c4_fixture_summary.txt"
OWNED_MARKER = ".c4_fixture_gate_owned"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _binary_path(project: Path) -> Path:
    return (project / "addons/visual_gasic/bin/libvisualgasic.linux.editor.x86_64.so").resolve()


def _gate_owned_names() -> set:
    names = {REPORT_JSON, REPORT_SUMMARY, OWNED_MARKER}
    for fixture in FIXTURES:
        for mode in MODES:
            names.add(f"{mode}_{fixture}.log")
            names.add(f"user_{mode}_{fixture}")
    return names


def _is_under(child: Path, parent: Path) -> bool:
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except (ValueError, OSError):
        return False


def _snapshot_tree(root: Path) -> Dict[str, bytes]:
    """Relative path → file bytes for every regular file under root."""
    snap: Dict[str, bytes] = {}
    if not root.is_dir():
        return snap
    for p in sorted(root.rglob("*")):
        if p.is_symlink() or not p.is_file():
            continue
        rel = str(p.relative_to(root))
        snap[rel] = p.read_bytes()
    return snap


def _diff_snapshot(root: Path, before: Dict[str, bytes]) -> List[str]:
    after = _snapshot_tree(root)
    errs: List[str] = []
    for rel, data in before.items():
        if rel not in after:
            errs.append(f"sentinel_removed:{rel}")
        elif after[rel] != data:
            errs.append(f"sentinel_modified:{rel}")
    for rel in after:
        if rel not in before:
            errs.append(f"sentinel_parent_new_file:{rel}")
    return errs


def _claim_out_dir(out: Path) -> Optional[str]:
    """Authorize ``out`` for gate writes.

    Contract:
    - Refuse if ``out`` is a symlink (do not follow into foreign trees).
    - Create a new empty directory when missing.
    - Reuse only when empty, or when previously claimed (owned marker present)
      and every child name is in the gate-owned set.
    - Never delete foreign paths; refuse instead.
    Returns an error string on refusal, else None.
    """
    if out.exists() and out.is_symlink():
        return f"out_is_symlink:{out}"
    if not out.exists():
        out.mkdir(parents=True, exist_ok=False)
        (out / OWNED_MARKER).write_text("c4_fixture_gate\n", encoding="utf-8")
        return None
    if not out.is_dir():
        return f"out_not_directory:{out}"
    owned = _gate_owned_names()
    children = list(out.iterdir())
    marker = out / OWNED_MARKER
    if not children:
        marker.write_text("c4_fixture_gate\n", encoding="utf-8")
        return None
    if not marker.is_file():
        return f"out_not_owned_foreign_contents:{out}"
    for child in children:
        if child.name not in owned:
            return f"out_foreign_entry:{child.name}"
        if child.is_symlink():
            return f"out_symlink_child:{child.name}"
    return None


def _safe_write_text(path: Path, text: str, *, out_root: Path) -> Optional[str]:
    """Write only into an authorized path under out_root; refuse symlinks."""
    if not _is_under(path if path.exists() else path.parent, out_root) and not _is_under(
        path.parent, out_root
    ):
        # path may not exist yet; parent must be under out_root
        if not _is_under(path.parent, out_root):
            return f"write_outside_out:{path}"
    if path.exists() and path.is_symlink():
        return f"refusing_symlink_write:{path}"
    if path.parent.exists() and path.parent.is_symlink():
        return f"refusing_symlink_parent:{path.parent}"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", errors="replace")
    return None


def _write_report(
    out: Path,
    *,
    ok: bool,
    problems: List[str],
    binary: str,
    binary_hash: str,
    elapsed_sec: float,
    runs: List[dict],
    startup: str = "",
) -> Optional[str]:
    """Write gate JSON + summary into an already-claimed out directory."""
    report = {
        "ok": ok,
        "problems": problems,
        "binary": binary,
        "binary_hash": binary_hash,
        "elapsed_sec": elapsed_sec,
        "runs": runs,
    }
    if startup:
        report["startup"] = startup
    err = _safe_write_text(
        out / REPORT_JSON, json.dumps(report, indent=2) + "\n", out_root=out
    )
    if err:
        return err
    summary_lines = [
        f"C4_FIXTURE_GATE ok={ok} problems={len(problems)} "
        f"runs={len(runs)} elapsed_sec={elapsed_sec} binary_hash={binary_hash}"
    ]
    if startup:
        summary_lines.append(f"startup={startup}")
    for run in runs:
        tag = "OK" if not run.get("problems") else "FAIL"
        summary_lines.append(
            f"{tag} {run.get('fixture')} mode={run.get('mode')} "
            f"exit={run.get('returncode')} problems={len(run.get('problems') or [])}"
        )
    return _safe_write_text(
        out / REPORT_SUMMARY, "\n".join(summary_lines) + "\n", out_root=out
    )


def _invalidate_success(out: Path, reason: str) -> Optional[str]:
    """Replace any prior success report before attempting new runs."""
    return _write_report(
        out,
        ok=False,
        problems=[f"invalidated:{reason}"],
        binary="",
        binary_hash="",
        elapsed_sec=0.0,
        runs=[],
        startup=reason,
    )


def judge_c4_log(
    text: str,
    fixture: str,
    mode: str,
    returncode: int,
) -> List[str]:
    """Judge one Godot log. Empty list means accept."""
    spec = FIXTURES[fixture]
    errs: List[str] = []
    if returncode != 0:
        errs.append(f"child_exit={returncode}")

    lines = [ln.rstrip("\r\n") for ln in text.splitlines()]

    for ln in lines:
        if not ln:
            continue
        # Leading whitespace before a recognized marker → fail closed.
        if ln[0].isspace():
            stripped = ln.lstrip()
            if _MARKER_HEAD.match(stripped) or any(m in stripped for m in RUNTIME_MARKERS):
                errs.append(f"malformed_leading_ws:{stripped[:160]}")
                continue
        if any(m in ln for m in RUNTIME_MARKERS):
            errs.append(f"runtime_error:{ln.strip()[:180]}")
            continue
        if ln.startswith("ERROR:"):
            errs.append(f"runtime_error:{ln.strip()[:180]}")
            continue

    done = [ln for ln in lines if ln == "VG_SUITE_COMPLETED"]
    if not done:
        errs.append("missing_completion")
    elif len(done) > 1:
        errs.append(f"duplicate_completion:{len(done)}")
    for ln in lines:
        if "VG_SUITE_COMPLETED" in ln and ln != "VG_SUITE_COMPLETED":
            # Includes leading-ws variants already flagged; also mid-line noise.
            if not (ln and ln[0].isspace()):
                errs.append(f"malformed_completion:{ln.strip()[:120]}")
            break

    summaries = []
    for ln in lines:
        if ln.startswith("C4_SUMMARY") or (
            ln[:1].isspace() and ln.lstrip().startswith("C4_SUMMARY")
        ):
            if ln[0:1].isspace():
                continue  # already malformed_leading_ws
            m = SUMMARY_RE.match(ln)
            if m is None:
                errs.append(f"malformed_summary:{ln.strip()[:160]}")
            else:
                summaries.append(m)
    if not summaries and not any(e.startswith("malformed_summary") for e in errs):
        errs.append("missing_summary")
    elif len(summaries) > 1:
        errs.append(f"duplicate_summary:{len(summaries)}")
    elif len(summaries) == 1:
        passed, failed = int(summaries[0].group(1)), int(summaries[0].group(2))
        if failed != 0 or passed != spec["summary_passed"]:
            errs.append(
                f"summary passed={passed} failed={failed} "
                f"want passed={spec['summary_passed']} failed=0"
            )

    fail_labels: List[str] = []
    for ln in lines:
        if ln and ln[0].isspace() and ln.lstrip().startswith("FAIL:"):
            continue  # malformed_leading_ws
        m = FAIL_RE.match(ln)
        if m:
            fail_labels.append(m.group(1))
        elif ln.startswith("FAIL:"):
            errs.append(f"malformed_fail:{ln.strip()[:160]}")
    if fail_labels:
        errs.append(f"fail_labels:{fail_labels[:6]}")

    got_pass: List[str] = []
    for ln in lines:
        if ln and ln[0].isspace() and ln.lstrip().startswith("PASS:"):
            continue
        m = PASS_RE.match(ln)
        if m:
            got_pass.append(m.group(1))
        elif ln.startswith("PASS:"):
            errs.append(f"malformed_pass:{ln.strip()[:160]}")

    want = list(spec["pass_labels"])
    if got_pass != want:
        missing = [x for x in want if x not in got_pass]
        extra = [x for x in got_pass if x not in want]
        if len(got_pass) != len(set(got_pass)):
            errs.append("duplicate_pass_labels")
        if missing:
            errs.append(f"missing_pass_labels:{missing[:8]}")
        if extra:
            errs.append(f"unknown_pass_labels:{extra[:8]}")
        if not missing and not extra and got_pass != want:
            errs.append("pass_label_order_mismatch")

    events: List[dict] = []
    for ln in lines:
        if ln and ln[0].isspace() and ln.lstrip().startswith("VG_SEM_PATH"):
            continue
        if not ln.startswith("VG_SEM_PATH"):
            continue
        try:
            ev = parse_path_event_line(ln)
        except ValueError as exc:
            errs.append(f"malformed_path:{exc}")
            continue
        if ev is not None:
            events.append(ev)

    want_mod = f"res://test_suite/{fixture}"
    required_fns = {req.fn for req in spec["path_requirements"]}
    for req in spec["path_requirements"]:
        err = check_required_path_events(
            mode=mode,
            target=req.fn,
            want=req.mode_paths.get(mode),
            events=events,
            required_mod=req.mod,
        )
        if err:
            errs.append(f"path:{req.fn}:{err}")
        for ev in events:
            if ev.get("fn") != req.fn:
                continue
            mod = ev.get("mod")
            if not mod:
                # Also surfaced by path_contract; keep an explicit C3 tag.
                if not any(e.startswith(f"path:{req.fn}:unqualified") for e in errs):
                    errs.append(f"path:{req.fn}:unqualified_or_ambiguous")
            elif mod != want_mod:
                errs.append(
                    f"wrong_module fn={req.fn} got={mod!r} want={want_mod!r}"
                )
                break

    # Any event naming a required target must be attributed; do not ignore extras.
    for ev in events:
        fn = ev.get("fn")
        if fn not in required_fns:
            continue
        if not ev.get("mod"):
            tag = f"path:{fn}:unqualified_or_ambiguous"
            if tag not in errs and not any(
                e.startswith(f"path:{fn}:unqualified") for e in errs
            ):
                errs.append(tag)

    return errs


def _mode_env(mode: str) -> Dict[str, str]:
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
    return env


def _run_one(
    godot: Path,
    project: Path,
    fixture: str,
    mode: str,
    log_path: Path,
    user_dir: Path,
    timeout: float = 70.0,
) -> Tuple[str, int]:
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
    try:
        proc = subprocess.run(
            cmd,
            env=_mode_env(mode),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        out = exc.stdout or ""
        if isinstance(out, bytes):
            out = out.decode("utf-8", errors="replace")
        log_path.write_text(out, encoding="utf-8", errors="replace")
        return out, -124
    log_path.write_text(proc.stdout, encoding="utf-8", errors="replace")
    return proc.stdout, proc.returncode


def _passing_log(fixture: str, mode: str) -> str:
    """Synthetic log that judge_c4_log accepts at exit 0 for this fixture/mode."""
    spec = FIXTURES[fixture]
    mod = f"res://test_suite/{fixture}"
    lines: List[str] = []
    for req in spec["path_requirements"]:
        want = req.mode_paths[mode]
        if want == "bytecode_or_native":
            tier = "bytecode"
        else:
            tier = want
        lines.append(f'VG_SEM_PATH path={tier} fn={req.fn} mod="{mod}"')
    for label in spec["pass_labels"]:
        # Final suite banner is emitted once below (sem_c4_*).
        if label.startswith("sem_c4"):
            continue
        lines.append(f"PASS: {label}")
    lines.append(f"C4_SUMMARY passed={spec['summary_passed']} failed=0")
    lines.append(f"PASS: {spec['pass_labels'][-1]}")
    lines.append("VG_SUITE_COMPLETED")
    return "\n".join(lines) + "\n"


def _make_mock_project(work: Path) -> Path:
    """Mock project under an owned work tree (never under a caller ``dest``)."""
    project = Path(tempfile.mkdtemp(prefix="vg-c4-gate-entry-proj-", dir=str(work)))
    suite = project / "test_suite"
    suite.mkdir(parents=True, exist_ok=True)
    for name in FIXTURES:
        (suite / name).write_text("' c4 gate entry probe\n", encoding="utf-8")
    so = project / "addons/visual_gasic/bin/libvisualgasic.linux.editor.x86_64.so"
    so.parent.mkdir(parents=True, exist_ok=True)
    so.write_bytes(b"c4-gate-entry-probe-not-a-binary")
    (project / "run_suite.gd").write_text("' mock\n", encoding="utf-8")
    return project


def _plant_legacy_sentinels(parent: Path) -> Dict[str, bytes]:
    """Pre-existing files at paths the old selftest used to clobber."""
    planted: Dict[str, bytes] = {}

    def put(rel: str, data: bytes) -> None:
        path = parent / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        planted[rel] = data

    put(
        "project/addons/visual_gasic/bin/libvisualgasic.linux.editor.x86_64.so",
        b"SENTINEL_LEGACY_SO_bytes_v1",
    )
    put("stub_godot.sh", b"SENTINEL_STUB_GODOT_v1\n")
    put("exit17/c4_fixture_gate.json", b'{"ok":true,"SENTINEL":"exit17"}\n')
    put("positive_control/c4_fixture_summary.txt", b"SENTINEL_POS_SUMMARY\n")
    put("hang.log", b"SENTINEL_HANG_LOG\n")
    put("fail_gate/c4_fixture_gate.json", b'{"ok":true,"SENTINEL":"fail"}\n')
    put("stale_success/c4_fixture_gate.json", b'{"ok":true,"SENTINEL":"stale"}\n')
    return planted


def _c4_entry_probes_body(work: Path) -> List[str]:
    """All entry probes; every path is under uniquely owned ``work``."""
    fails: List[str] = []
    project = _make_mock_project(work)
    stub_godot = work / "stub_godot.sh"
    stub_godot.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    stub_godot.chmod(0o755)
    original = globals()["_run_one"]

    def check(label: str, kind: str, want: str) -> None:
        def fake_run_one(godot, project, fixture, mode, log_path, user_dir, timeout=70.0):
            del godot, project, user_dir, timeout
            text = _passing_log(fixture, mode)
            rc = 0
            if kind == "exit17":
                rc = 17
            elif kind == "timeout":
                rc = -124
            elif kind == "fail_label" and fixture == "test_sem_c4_shortcircuit.vg":
                text = text.replace(
                    "PASS: c4_andalso_ft_r\n",
                    "FAIL: c4_andalso_ft_r value got=1 want=0\n",
                    1,
                )
            elif kind == "leading_fail" and fixture == "test_sem_c4_shortcircuit.vg":
                text = text + " FAIL: extra failure\n"
            elif kind == "leading_error" and fixture == "test_sem_c4_shortcircuit.vg":
                text = text + " ERROR: extra error\n"
            elif kind == "unqualified_path" and fixture == "test_sem_c4_shortcircuit.vg":
                text = text + "VG_SEM_PATH path=ast fn=HitA\n"
            elif kind == "mixed_qualified" and fixture == "test_sem_c4_shortcircuit.vg":
                text = (
                    text
                    + f'VG_SEM_PATH path=ast fn=HitA mod="{SC_MOD}"\n'
                    + f'VG_SEM_PATH path=bytecode fn=HitA mod="{SC_MOD}"\n'
                )
            elif kind == "unknown_pass" and fixture == "test_sem_c4_shortcircuit.vg":
                text = text.replace(
                    "PASS: sem_c4_shortcircuit\n",
                    "PASS: sem_c4_shortcircuit\nPASS: not_a_real_label\n",
                    1,
                )
            elif kind == "script_error" and fixture == "test_sem_c4_shortcircuit.vg":
                text = text + "SCRIPT ERROR: boom\n"
            elif kind == "malformed_path" and fixture == "test_sem_c4_shortcircuit.vg":
                text = text + "VG_SEM_PATH path=bytecode fn=\n"
            elif kind == "missing_label" and fixture == "test_sem_c4_shortcircuit.vg":
                text = text.replace("PASS: c4_andalso_tt_r\n", "", 1)
            elif kind == "duplicate_label" and fixture == "test_sem_c4_errors.vg":
                text = text.replace(
                    "PASS: c4_err_resume_log\n",
                    "PASS: c4_err_resume_log\nPASS: c4_err_resume_log\n",
                    1,
                )
            elif kind == "wrong_summary":
                text = re.sub(r"passed=\d+", "passed=0", text, count=1)
            elif kind == "malformed_summary":
                text = text.replace(
                    f"C4_SUMMARY passed={FIXTURES[fixture]['summary_passed']} failed=0",
                    "C4_SUMMARY passed=15",
                    1,
                )
            elif kind == "duplicate_summary":
                text = text.replace(
                    f"C4_SUMMARY passed={FIXTURES[fixture]['summary_passed']} failed=0\n",
                    f"C4_SUMMARY passed={FIXTURES[fixture]['summary_passed']} failed=0\n"
                    f"C4_SUMMARY passed={FIXTURES[fixture]['summary_passed']} failed=0\n",
                    1,
                )
            elif kind == "missing_completion":
                text = text.replace("VG_SUITE_COMPLETED\n", "")
            elif kind == "duplicate_completion":
                text = text.replace(
                    "VG_SUITE_COMPLETED\n",
                    "VG_SUITE_COMPLETED\nVG_SUITE_COMPLETED\n",
                )
            elif kind == "wrong_module" and fixture == "test_sem_c4_shortcircuit.vg":
                text = text.replace(
                    f'mod="{SC_MOD}"',
                    'mod="res://test_suite/other.vg"',
                    1,
                )
            elif kind == "missing_path" and fixture == "test_sem_c4_shortcircuit.vg":
                text = "\n".join(
                    ln for ln in text.splitlines() if "fn=HitA " not in ln
                ) + "\n"
            elif kind == "mixed_path" and fixture == "test_sem_c4_shortcircuit.vg":
                if mode == "forced_ast":
                    text = text.replace(
                        f'VG_SEM_PATH path=ast fn=HitA mod="{SC_MOD}"',
                        f'VG_SEM_PATH path=bytecode fn=HitA mod="{SC_MOD}"',
                        1,
                    )
                else:
                    text = text.replace(
                        f'VG_SEM_PATH path=bytecode fn=HitA mod="{SC_MOD}"',
                        f'VG_SEM_PATH path=ast fn=HitA mod="{SC_MOD}"',
                        1,
                    )
            log_path.parent.mkdir(parents=True, exist_ok=True)
            if log_path.exists() and log_path.is_symlink():
                raise RuntimeError(f"refusing_symlink_log:{log_path}")
            log_path.write_text(text, encoding="utf-8")
            return text, rc

        globals()["_run_one"] = fake_run_one
        out = work / "probes" / label
        try:
            rc = run_gate(project, stub_godot, out)
        finally:
            globals()["_run_one"] = original
        report_path = out / REPORT_JSON
        if not report_path.is_file():
            fails.append(f"{label}: missing report")
            return
        report = json.loads(report_path.read_text(encoding="utf-8"))
        blob = " ".join(report.get("problems") or [])
        if rc == 0 or report.get("ok"):
            fails.append(f"{label}: gate accepted rc={rc} ok={report.get('ok')}")
        elif want not in blob:
            fails.append(f"{label}: expected {want} in {report.get('problems')}")

    try:
        check("exit17", "exit17", "child_exit=17")
        check("timeout", "timeout", "child_exit=-124")
        check("fail_label", "fail_label", "fail_labels:")
        check("leading_fail", "leading_fail", "malformed_leading_ws")
        check("leading_error", "leading_error", "malformed_leading_ws")
        check("unqualified_path", "unqualified_path", "unqualified")
        check("mixed_qualified", "mixed_qualified", "path:HitA:")
        check("unknown_pass", "unknown_pass", "unknown_pass_labels:")
        check("script_error", "script_error", "runtime_error:")
        check("malformed_path", "malformed_path", "malformed_path:")
        check("missing_label", "missing_label", "missing_pass_labels:")
        check("duplicate_label", "duplicate_label", "duplicate_pass_labels")
        check("wrong_summary", "wrong_summary", "want passed=")
        check("malformed_summary", "malformed_summary", "malformed_summary")
        check("duplicate_summary", "duplicate_summary", "duplicate_summary")
        check("missing_completion", "missing_completion", "missing_completion")
        check("duplicate_completion", "duplicate_completion", "duplicate_completion")
        check("wrong_module", "wrong_module", "wrong module")
        check("missing_path", "missing_path", "path:HitA:")
        check("mixed_path", "mixed_path", "path:HitA:")

        def good_run_one(godot, project, fixture, mode, log_path, user_dir, timeout=70.0):
            del godot, project, user_dir, timeout
            text = _passing_log(fixture, mode)
            log_path.parent.mkdir(parents=True, exist_ok=True)
            log_path.write_text(text, encoding="utf-8")
            return text, 0

        globals()["_run_one"] = good_run_one
        pos_out = work / "probes" / "positive_control"
        try:
            rc = run_gate(project, stub_godot, pos_out)
        finally:
            globals()["_run_one"] = original
        pos_report = json.loads((pos_out / REPORT_JSON).read_text(encoding="utf-8"))
        want_runs = len(FIXTURES) * len(MODES)
        if (
            rc != 0
            or not pos_report.get("ok")
            or len(pos_report.get("runs") or []) != want_runs
        ):
            fails.append(
                f"positive_control: rc={rc} ok={pos_report.get('ok')} "
                f"runs={len(pos_report.get('runs') or [])} want={want_runs} "
                f"problems={pos_report.get('problems')}"
            )

        base = _passing_log("test_sem_c4_shortcircuit.vg", "interpreter")
        for tag, extra, needle in (
            ("judge_leading_fail", " FAIL: extra failure\n", "malformed_leading_ws"),
            ("judge_leading_error", " ERROR: extra error\n", "malformed_leading_ws"),
            ("judge_unqualified", "VG_SEM_PATH path=ast fn=HitA\n", "unqualified"),
        ):
            jerrs = judge_c4_log(
                base + extra, "test_sem_c4_shortcircuit.vg", "interpreter", 0
            )
            blob = " ".join(jerrs)
            if not jerrs or needle not in blob:
                fails.append(f"{tag}: expected {needle} in {jerrs}")

        # Stale success on an authorized owned output directory.
        stale_out = work / "probes" / "stale_success"
        globals()["_run_one"] = good_run_one
        try:
            rc_ok = run_gate(project, stub_godot, stale_out)
        finally:
            globals()["_run_one"] = original
        if rc_ok != 0:
            fails.append(f"stale_setup: expected success rc got {rc_ok}")
        else:
            rc_bad = run_gate(
                project,
                Path("/tmp/vg-c4-gate-definitely-missing-godot-bin"),
                stale_out,
            )
            bad_report = json.loads((stale_out / REPORT_JSON).read_text(encoding="utf-8"))
            if rc_bad == 0 or bad_report.get("ok"):
                fails.append(
                    f"stale_success: still ok after bad godot "
                    f"rc={rc_bad} report={bad_report}"
                )
            elif "missing_godot" not in " ".join(bad_report.get("problems") or []):
                fails.append(
                    f"stale_success: expected missing_godot in {bad_report.get('problems')}"
                )

        nonexec = work / "nonexecutable_godot"
        nonexec.write_text("not executable\n", encoding="utf-8")
        nonexec.chmod(0o600)
        globals()["_run_one"] = good_run_one
        try:
            rc_ok = run_gate(project, stub_godot, stale_out)
        finally:
            globals()["_run_one"] = original
        if rc_ok != 0:
            fails.append(f"nonexec_setup: expected success rc got {rc_ok}")
        else:
            rc_bad = run_gate(project, nonexec, stale_out)
            bad_report = json.loads((stale_out / REPORT_JSON).read_text(encoding="utf-8"))
            if rc_bad == 0 or bad_report.get("ok"):
                fails.append(f"nonexec_godot: gate accepted rc={rc_bad}")
            elif "child_start_failed" not in " ".join(bad_report.get("problems") or []):
                fails.append(f"nonexec_godot: missing failure detail in {bad_report}")

        hang = work / "hang_godot.sh"
        hang.write_text("#!/bin/sh\nexec sleep 30\n", encoding="utf-8")
        hang.chmod(0o755)

        def hang_run_one(godot, project, fixture, mode, log_path, user_dir, timeout=70.0):
            del mode
            user_dir.mkdir(parents=True, exist_ok=True)
            cmd = [str(hang), "--headless", "--path", str(project)]
            try:
                proc = subprocess.run(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    timeout=0.3,
                    check=False,
                )
                log_path.write_text(proc.stdout or "", encoding="utf-8")
                return proc.stdout or "", proc.returncode
            except subprocess.TimeoutExpired as exc:
                out = exc.stdout or ""
                if isinstance(out, bytes):
                    out = out.decode("utf-8", errors="replace")
                log_path.write_text(out, encoding="utf-8", errors="replace")
                return out, -124

        _text_h, rc_h = hang_run_one(
            hang,
            project,
            "test_sem_c4_shortcircuit.vg",
            "interpreter",
            work / "hang.log",
            work / "hang_user",
            timeout=0.3,
        )
        if rc_h != -124:
            fails.append(f"real_subprocess_timeout: rc={rc_h} (want -124)")
        else:

            def hang_via_gate(godot, project, fixture, mode, log_path, user_dir, timeout=70.0):
                del godot, timeout
                return hang_run_one(
                    hang, project, fixture, mode, log_path, user_dir, timeout=0.3
                )

            globals()["_run_one"] = hang_via_gate
            try:
                rc_g = run_gate(project, hang, work / "probes" / "hang_gate")
            finally:
                globals()["_run_one"] = original
            hang_report = json.loads(
                (work / "probes" / "hang_gate" / REPORT_JSON).read_text(encoding="utf-8")
            )
            if rc_g == 0 or hang_report.get("ok"):
                fails.append(f"hang_gate: accepted rc={rc_g}")
            elif "child_exit=-124" not in " ".join(hang_report.get("problems") or []):
                fails.append(
                    f"hang_gate: expected timeout in {hang_report.get('problems')}"
                )

        fail_sh = work / "fail_godot.sh"
        fail_sh.write_text("#!/bin/sh\necho FAIL_HELPER\nexit 17\n", encoding="utf-8")
        fail_sh.chmod(0o755)

        def fail_via_gate(godot, project, fixture, mode, log_path, user_dir, timeout=70.0):
            del godot, mode, timeout
            user_dir.mkdir(parents=True, exist_ok=True)
            proc = subprocess.run(
                [str(fail_sh)],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                check=False,
            )
            log_path.write_text(proc.stdout or "", encoding="utf-8")
            return proc.stdout or "", proc.returncode

        globals()["_run_one"] = fail_via_gate
        try:
            rc_f = run_gate(project, fail_sh, work / "probes" / "fail_gate")
        finally:
            globals()["_run_one"] = original
        fail_report = json.loads(
            (work / "probes" / "fail_gate" / REPORT_JSON).read_text(encoding="utf-8")
        )
        if rc_f == 0 or fail_report.get("ok"):
            fails.append(f"fail_gate: accepted rc={rc_f}")
        elif "child_exit=17" not in " ".join(fail_report.get("problems") or []):
            fails.append(
                f"fail_gate: expected child_exit=17 in {fail_report.get('problems')}"
            )

        # Refuse foreign pre-existing out contents (no delete / no overwrite).
        foreign = Path(tempfile.mkdtemp(prefix="vg-c4-gate-foreign-", dir=str(work)))
        (foreign / "unrelated.txt").write_text("keep-me\n", encoding="utf-8")
        rc_fgn = run_gate(project, stub_godot, foreign)
        if rc_fgn == 0:
            fails.append("foreign_out: gate accepted non-owned directory")
        elif (foreign / "unrelated.txt").read_text(encoding="utf-8") != "keep-me\n":
            fails.append("foreign_out: unrelated.txt was modified")
        elif (foreign / REPORT_JSON).exists():
            fails.append("foreign_out: wrote report into foreign directory")

        # Symlink out refused.
        link_target = Path(tempfile.mkdtemp(prefix="vg-c4-gate-linktgt-", dir=str(work)))
        (link_target / "secret.txt").write_text("secret\n", encoding="utf-8")
        link_out = work / "out_symlink"
        link_out.symlink_to(link_target, target_is_directory=True)
        rc_link = run_gate(project, stub_godot, link_out)
        if rc_link == 0:
            fails.append("symlink_out: gate accepted symlink out")
        elif (link_target / "secret.txt").read_text(encoding="utf-8") != "secret\n":
            fails.append("symlink_out: followed symlink and mutated target")
        elif (link_target / REPORT_JSON).exists():
            fails.append("symlink_out: wrote report through symlink")

    finally:
        globals()["_run_one"] = original
    return fails


def run_c4_gate_entry_probes(
    dest: Optional[Path] = None,
    *,
    _safety_proof: bool = True,
) -> List[str]:
    """Entry negatives / positives with fail-closed output ownership.

    ``dest`` is unused; the safety proof checks a separately created sentinel
    parent. All projects, helpers, and probe outputs live under a uniquely
    created temporary directory owned by this invocation; only that tree is
    deleted on cleanup.
    """
    fails: List[str] = []
    work = Path(tempfile.mkdtemp(prefix="vg-c4-gate-entry-work-"))
    try:
        fails.extend(_c4_entry_probes_body(work))
    finally:
        shutil.rmtree(work, ignore_errors=True)

    if _safety_proof:
        parent = Path(tempfile.mkdtemp(prefix="vg-c4-gate-sentinel-parent-"))
        try:
            _plant_legacy_sentinels(parent)
            before = _snapshot_tree(parent)
            nested = run_c4_gate_entry_probes(parent, _safety_proof=False)
            fails.extend(nested)
            after_errs = _diff_snapshot(parent, before)
            if after_errs:
                fails.extend(f"legacy_sentinel:{e}" for e in after_errs)
        finally:
            # Only delete the unique parent we created for this proof.
            shutil.rmtree(parent, ignore_errors=True)

    return fails


def run_gate(project: Path, godot: Path, out: Path) -> int:
    """Run fixtures into an authorized owned ``out`` directory.

    Ownership: see ``_claim_out_dir``. Symlinked ``out`` or foreign contents
    are refused with a nonzero exit and no writes into that path. On an owned
    directory, success reports are invalidated before runs; startup failures
    leave an explicit failing report (never a leftover success).
    """
    t0 = time.perf_counter()
    claim_err = _claim_out_dir(out)
    if claim_err:
        print(f"C4_FIXTURE_GATE ok=False problems=1 startup=out_refused")
        print(f"  {claim_err}")
        return 1

    inv_err = _invalidate_success(out, "starting")
    if inv_err:
        print(f"C4_FIXTURE_GATE ok=False problems=1 startup=write_refused")
        print(f"  {inv_err}")
        return 1

    problems: List[str] = []
    so = _binary_path(project)
    binary_hash = _sha256(so) if so.is_file() else ""
    if not godot.is_file():
        problems.append(f"missing_godot:{godot}")
        _write_report(
            out,
            ok=False,
            problems=problems,
            binary=str(so),
            binary_hash=binary_hash,
            elapsed_sec=round(time.perf_counter() - t0, 3),
            runs=[],
            startup="missing_godot",
        )
        print(f"C4_FIXTURE_GATE ok=False problems={len(problems)} startup=missing_godot")
        for p in problems:
            print(" ", p)
        return 1
    if not binary_hash:
        problems.append(f"missing binary {so}")
        _write_report(
            out,
            ok=False,
            problems=problems,
            binary=str(so),
            binary_hash="",
            elapsed_sec=round(time.perf_counter() - t0, 3),
            runs=[],
            startup="missing_binary",
        )
        print(f"C4_FIXTURE_GATE ok=False problems={len(problems)} startup=missing_binary")
        for p in problems:
            print(" ", p)
        return 1

    runs = []
    for fixture, spec in FIXTURES.items():
        for mode in MODES:
            log_path = out / f"{mode}_{fixture}.log"
            user_dir = out / f"user_{mode}_{fixture}"
            if log_path.exists() and log_path.is_symlink():
                problems.append(f"refusing_symlink_log:{log_path.name}")
                continue
            if user_dir.exists() and user_dir.is_symlink():
                problems.append(f"refusing_symlink_user_dir:{user_dir.name}")
                continue
            try:
                text, returncode = _run_one(godot, project, fixture, mode, log_path, user_dir)
            except OSError as exc:
                problem = f"child_start_failed {mode} {fixture}: {exc}"
                problems.append(problem)
                write_err = _write_report(
                    out,
                    ok=False,
                    problems=problems,
                    binary=str(so),
                    binary_hash=binary_hash,
                    elapsed_sec=round(time.perf_counter() - t0, 3),
                    runs=runs,
                    startup="child_start_failed",
                )
                print(f"C4_FIXTURE_GATE ok=False startup=child_start_failed\n  {problem}")
                if write_err:
                    print(f"  {write_err}")
                return 1
            if returncode == -124:
                problems.append(f"timeout {mode} {fixture}")
            errs = judge_c4_log(text, fixture, mode, returncode)
            if errs:
                problems.extend(f"{mode} {fixture} {e}" for e in errs)
            runs.append(
                {
                    "fixture": fixture,
                    "mode": mode,
                    "returncode": returncode,
                    "problems": errs,
                    "unverified_helpers": list(spec.get("unverified_helpers") or ()),
                }
            )
    elapsed = round(time.perf_counter() - t0, 3)
    write_err = _write_report(
        out,
        ok=not problems,
        problems=problems,
        binary=str(so),
        binary_hash=binary_hash,
        elapsed_sec=elapsed,
        runs=runs,
    )
    if write_err:
        problems.append(write_err)
        print(f"C4_FIXTURE_GATE ok=False problems={len(problems)} startup=write_refused")
        print(f"  {write_err}")
        return 1
    print(
        f"C4_FIXTURE_GATE ok={not problems} problems={len(problems)} "
        f"runs={len(runs)} elapsed_sec={elapsed} binary_hash={binary_hash}"
    )
    for p in problems:
        print(" ", p)
    return 0 if not problems else 1


def main(argv: Optional[Sequence[str]] = None) -> int:
    p = argparse.ArgumentParser(description="C4 short-circuit/error fixture gate")
    p.add_argument("--project", required=True, help="test_proj directory")
    p.add_argument("--godot", default=os.environ.get("GODOT", ""))
    p.add_argument(
        "--out",
        required=True,
        help=(
            "Gate output directory (must be new, empty, or previously owned). "
            "For --selftest-entry: unused."
        ),
    )
    p.add_argument(
        "--selftest-entry",
        action="store_true",
        help="Run patched-child entry negatives only (no production Godot)",
    )
    args = p.parse_args(argv)
    if args.selftest_entry:
        # --out is not a write root; probes use a private mkdtemp.
        fails = run_c4_gate_entry_probes(Path(args.out))
        if fails:
            print("C4_GATE_ENTRY_SELFTEST FAIL")
            for f in fails:
                print(" ", f)
            return 1
        print("C4_GATE_ENTRY_SELFTEST PASS")
        return 0
    if not args.godot:
        print("C4_FIXTURE_GATE missing GODOT")
        out = Path(args.out)
        claim = _claim_out_dir(out)
        if claim:
            print(f"  {claim}")
            return 2
        _write_report(
            out,
            ok=False,
            problems=["missing_GODOT_arg"],
            binary="",
            binary_hash="",
            elapsed_sec=0.0,
            runs=[],
            startup="missing_GODOT_arg",
        )
        return 2
    return run_gate(Path(args.project), Path(args.godot), Path(args.out))


if __name__ == "__main__":
    raise SystemExit(main())
