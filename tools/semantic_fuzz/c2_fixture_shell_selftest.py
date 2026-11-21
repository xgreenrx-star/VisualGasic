"""Shell-entry fail-closed probes for run_semantic_c2_fixtures.sh (no real VG)."""

from __future__ import annotations

import hashlib
import os
import stat
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, List, Optional


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "run_semantic_c2_fixtures.sh"


def _write_exec(path: Path, body: str) -> None:
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _clean_primary_log() -> str:
    from .c2_fixture_manifest import PRIMARY_MOD, PRIMARY_PASS_LABELS

    lines = []
    for fn in (
        "StandaloneByRef",
        "ExprByRef",
        "NestedOuter",
        "RecAdd",
        "IdxSide",
        "BumpSlot",
    ):
        lines.append(f'VG_SEM_PATH path=bytecode fn={fn} mod="{PRIMARY_MOD}"')
    for lab in PRIMARY_PASS_LABELS:
        if lab == "nested event order":
            lines.append(f"PASS: {lab} type=String")
        else:
            lines.append(f"PASS: {lab} type=Integer")
    lines.append("C2_SUMMARY passed=16 failed=0")
    lines.append("PASS: sem_c2_calls_byref")
    lines.append("VG_SUITE_COMPLETED")
    return "\n".join(lines) + "\n"


def _good_verdict() -> str:
    return (
        "OK test_sem_c2_calls_byref mode=default exit=0 "
        "pass_lines=17 fail_lines=0 done=1"
    )


def _run_lane(
    tmp: Path,
    *,
    godot: Path,
    judge_py: Optional[str] = None,
    modes: str = "default",
    fixtures: str = "res://test_suite/test_sem_c2_calls_byref.vg",
    env_extra: Optional[Dict[str, str]] = None,
    seed_stale_ok: bool = False,
) -> subprocess.CompletedProcess:
    out = tmp / "out"
    out.mkdir(parents=True, exist_ok=True)
    if seed_stale_ok:
        (out / "gate_status.txt").write_text("ok\n", encoding="utf-8")
        (out / "c2_fixture_summary.txt").write_text("stale ok\n", encoding="utf-8")
    env = os.environ.copy()
    env["GODOT"] = str(godot)
    env["SEM_C2_OUT"] = str(out)
    env["SEM_C2_MODES"] = modes
    env["SEM_C2_FIXTURES"] = fixtures
    if judge_py is not None:
        env["SEM_C2_JUDGE_PY"] = judge_py
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        ["bash", str(SCRIPT)],
        cwd=str(ROOT),
        env=env,
        capture_output=True,
        text=True,
    )


def _root_status(tmp: Path) -> str:
    p = tmp / "out" / "gate_status.txt"
    return p.read_text(encoding="utf-8").strip() if p.is_file() else ""


def run_c2_shell_selftests() -> List[str]:
    fails: List[str] = []
    sentinel = ROOT / "test_proj" / "current_test.txt"
    if not sentinel.is_file():
        fails.append("MISS:current_test_missing_cannot_check_isolation")
        return fails
    before = _sha256(sentinel)

    with tempfile.TemporaryDirectory(prefix="vg-c2-shell-") as td:
        tmp = Path(td)
        log_payload = _clean_primary_log()

        godot_ok = tmp / "fake_godot"
        _write_exec(
            godot_ok,
            "#!/bin/bash\n"
            f"cat <<'EOF'\n{log_payload}EOF\n"
            "exit 0\n",
        )

        r = _run_lane(tmp / "happy", godot=godot_ok)
        if r.returncode != 0:
            fails.append(
                f"MISS:shell_happy_failed:rc={r.returncode} "
                f"out={r.stdout[-500:]} err={r.stderr[-500:]}"
            )

        godot_poison = tmp / "fake_godot_poison"
        _write_exec(
            godot_poison,
            "#!/bin/bash\n"
            "cat <<'EOF'\n"
            "SCRIPT ERROR: Invalid call. Nonexistent function.\n"
            "VG_SUITE_COMPLETED\n"
            "EOF\n"
            "exit 17\n",
        )
        r = _run_lane(tmp / "poison", godot=godot_poison)
        if r.returncode == 0:
            fails.append("MISS:shell_accepts_exit17_script_error")

        judge_crash = tmp / "judge_crash"
        _write_exec(judge_crash, "#!/bin/bash\nexit 2\n")
        r = _run_lane(tmp / "jcrash", godot=godot_ok, judge_py=str(judge_crash))
        if r.returncode == 0:
            fails.append("MISS:shell_accepts_judge_exit2")

        judge_empty = tmp / "judge_empty"
        _write_exec(judge_empty, "#!/bin/bash\nexit 0\n")
        r = _run_lane(tmp / "jempty", godot=godot_ok, judge_py=str(judge_empty))
        if r.returncode == 0:
            fails.append("MISS:shell_accepts_empty_judge_stdout")

        judge_forge = tmp / "judge_forge"
        _write_exec(
            judge_forge,
            "#!/bin/bash\n"
            f"echo '{_good_verdict()}'\n"
            "exit 3\n",
        )
        r = _run_lane(tmp / "jforge", godot=godot_ok, judge_py=str(judge_forge))
        if r.returncode == 0:
            fails.append("MISS:shell_accepts_forged_ok_nonzero_judge")

        # Invalid positive verdicts (judge exits 0)
        for name, verdict in (
            (
                "bad_fields",
                "OK wrong_fixture mode=wrong exit=17 pass_lines=0 fail_lines=99 done=0",
            ),
            (
                "trailing",
                _good_verdict().replace("done=1", "done=1TRAILING_GARBAGE"),
            ),
            (
                "wrong_mode_label",
                "OK test_sem_c2_calls_byref mode=forced_ast exit=0 "
                "pass_lines=17 fail_lines=0 done=1",
            ),
        ):
            jp = tmp / f"judge_{name}"
            _write_exec(jp, f"#!/bin/bash\necho '{verdict}'\nexit 0\n")
            r = _run_lane(tmp / name, godot=godot_ok, judge_py=str(jp))
            if r.returncode == 0:
                fails.append(f"MISS:shell_accepts_invalid_ok_{name}")

        # Hide nonzero child exit behind fake success verdict
        godot_nz = tmp / "fake_godot_nz"
        _write_exec(
            godot_nz,
            "#!/bin/bash\n"
            f"cat <<'EOF'\n{log_payload}EOF\n"
            "exit 17\n",
        )
        judge_hide = tmp / "judge_hide"
        _write_exec(
            judge_hide,
            "#!/bin/bash\n"
            f"echo '{_good_verdict()}'\n"
            "exit 0\n",
        )
        r = _run_lane(tmp / "hide", godot=godot_nz, judge_py=str(judge_hide))
        if r.returncode == 0:
            fails.append("MISS:shell_accepts_hidden_nonzero_child")

        # Unknown / same-basename alternate resource
        r = _run_lane(
            tmp / "badres",
            godot=godot_ok,
            fixtures="res://other_suite/test_sem_c2_calls_byref.vg",
        )
        if r.returncode == 0:
            fails.append("MISS:shell_accepts_same_basename_other_dir")

        # Malformed extra summary via real judge + poisoned log
        godot_mal = tmp / "fake_godot_malsum"
        poisoned = log_payload.replace(
            "C2_SUMMARY passed=16 failed=0\n",
            "C2_SUMMARY passed=16 failed=0\nC2_SUMMARY garbage\n",
        )
        _write_exec(
            godot_mal,
            "#!/bin/bash\n"
            f"cat <<'EOF'\n{poisoned}EOF\n"
            "exit 0\n",
        )
        r = _run_lane(tmp / "malsum", godot=godot_mal)
        if r.returncode == 0:
            fails.append("MISS:shell_accepts_malformed_extra_summary")

        # Empty modes after a prior stale ok must leave fail status
        r = _run_lane(
            tmp / "stale",
            godot=godot_ok,
            modes="",
            seed_stale_ok=True,
        )
        if r.returncode == 0:
            fails.append("MISS:shell_accepts_empty_modes")
        if _root_status(tmp / "stale") != "fail":
            fails.append(
                f"MISS:stale_ok_survives_empty_modes:status={_root_status(tmp / 'stale')!r}"
            )

        # Invalid GODOT after prior ok must leave fail (setup order)
        out_bad = tmp / "badgodot" / "out"
        out_bad.mkdir(parents=True, exist_ok=True)
        (out_bad / "gate_status.txt").write_text("ok\n", encoding="utf-8")
        env = os.environ.copy()
        env["GODOT"] = str(tmp / "does_not_exist_godot")
        env["SEM_C2_OUT"] = str(out_bad)
        env["SEM_C2_MODES"] = "default"
        env["SEM_C2_FIXTURES"] = "res://test_suite/test_sem_c2_calls_byref.vg"
        r = subprocess.run(
            ["bash", str(SCRIPT)],
            cwd=str(ROOT),
            env=env,
            capture_output=True,
            text=True,
        )
        if r.returncode == 0:
            fails.append("MISS:shell_accepts_missing_godot")
        st = (out_bad / "gate_status.txt").read_text(encoding="utf-8").strip()
        if st != "fail":
            fails.append(f"MISS:missing_godot_left_stale_ok:status={st!r}")

    after = _sha256(sentinel)
    if after != before:
        fails.append("MISS:current_test_txt_mutated_by_shell_selftest")

    return fails
