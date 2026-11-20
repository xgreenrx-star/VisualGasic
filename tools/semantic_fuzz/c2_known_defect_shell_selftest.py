"""Shell-entry fail-closed probes for run_semantic_c2_known_defects.sh (no real VG)."""

from __future__ import annotations

import hashlib
import os
import stat
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, List, Optional

from .c2_known_defect_gate import MOD_A, MOD_B


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "run_semantic_c2_known_defects.sh"


def _write_exec(path: Path, body: str) -> None:
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _clean_defect_log() -> str:
    return (
        "C2_KNOWN_DEFECT dual_import_same_name_twin\n"
        "EXPECTED_CORRECT via_qual=22 mod=res://test_suite/c2_path_mod_b.vg\n"
        f'VG_SEM_PATH path=bytecode fn=Twin mod="{MOD_A}"\n'
        "OBSERVED via_qual=11\n"
        f'VG_SEM_PATH path=bytecode fn=Twin mod="{MOD_A}"\n'
        "OBSERVED bare_Twin=11\n"
        "C2_KNOWN_DEFECT_STILL dual_import_same_name_twin via_qual=11\n"
        "PASS: dual_import_known_defect_probe_ran\n"
        "VG_SUITE_COMPLETED\n"
    )


def _run_lane(
    tmp: Path,
    *,
    godot: Path,
    env_extra: Optional[Dict[str, str]] = None,
) -> subprocess.CompletedProcess:
    out = tmp / "out"
    out.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["GODOT"] = str(godot)
    env["SEM_C2_KNOWN_OUT"] = str(out)
    # Poison inherited mode flags — shell must clear before applying intended mode.
    env["VG_FORCE_AST"] = "1"
    env["VG_JIT"] = "9"
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        ["bash", str(SCRIPT)],
        cwd=str(ROOT),
        env=env,
        capture_output=True,
        text=True,
    )


def _status(tmp: Path) -> str:
    p = tmp / "out" / "gate_status.txt"
    return p.read_text(encoding="utf-8").strip() if p.is_file() else ""


def run_c2_known_defect_shell_selftests() -> List[str]:
    fails: List[str] = []
    sentinel = ROOT / "test_proj" / "current_test.txt"
    if not sentinel.is_file():
        fails.append("MISS:current_test_missing_cannot_check_isolation")
        return fails
    before = _sha256(sentinel)

    with tempfile.TemporaryDirectory(prefix="vg-c2-kd-shell-") as td:
        tmp = Path(td)
        clean = _clean_defect_log()

        godot_ok = tmp / "fake_godot_ok"
        _write_exec(
            godot_ok,
            "#!/bin/bash\n"
            # Shell must clear inherited VG_FORCE_AST before applying intended VG_JIT=0.
            "if [[ -n \"${VG_FORCE_AST:-}\" ]]; then\n"
            "  echo 'SCRIPT ERROR: inherited_VG_FORCE_AST_not_cleared' >&2\n"
            "  exit 17\n"
            "fi\n"
            "if [[ \"${VG_JIT:-}\" != \"0\" ]]; then\n"
            "  echo \"SCRIPT ERROR: expected_VG_JIT=0 got=${VG_JIT-}\" >&2\n"
            "  exit 17\n"
            "fi\n"
            f"cat <<'EOF'\n{clean}EOF\n"
            "exit 0\n",
        )
        r = _run_lane(tmp / "happy", godot=godot_ok)
        if r.returncode != 0 or _status(tmp / "happy") != "ok_known_defects_visible":
            fails.append(
                f"MISS:kd_shell_happy:rc={r.returncode} status={_status(tmp / 'happy')!r} "
                f"err={r.stderr[-400:]} out={r.stdout[-400:]}"
            )

        # Fake GODOT with wrong via_qual + SCRIPT ERROR + exit 17 (independent probe).
        poison = (
            "C2_KNOWN_DEFECT dual_import_same_name_twin\n"
            "C2_KNOWN_DEFECT_STILL dual_import_same_name_twin via_qual=999\n"
            "PASS: dual_import_known_defect_probe_ran\n"
            "SCRIPT ERROR: unrelated crash\n"
        )
        godot_poison = tmp / "fake_godot_poison"
        _write_exec(
            godot_poison,
            "#!/bin/bash\n"
            f"cat <<'EOF'\n{poison}EOF\n"
            "exit 17\n",
        )
        r = _run_lane(tmp / "poison", godot=godot_poison)
        if r.returncode == 0 or _status(tmp / "poison") == "ok_known_defects_visible":
            fails.append(
                f"MISS:kd_shell_accepts_poison:rc={r.returncode} status={_status(tmp / 'poison')!r}"
            )

        # Wrong value only (exit 0, DONE present) — must still fail.
        wrong = clean.replace("via_qual=11", "via_qual=12").replace(
            "OBSERVED via_qual=11", "OBSERVED via_qual=12"
        ).replace("bare_Twin=11", "bare_Twin=12")
        # still line also needs replace — already covered by via_qual=11 global replace
        godot_wrong = tmp / "fake_godot_wrong"
        _write_exec(
            godot_wrong,
            "#!/bin/bash\n"
            f"cat <<'EOF'\n{wrong}EOF\n"
            "exit 0\n",
        )
        r = _run_lane(tmp / "wrong", godot=godot_wrong)
        if r.returncode == 0:
            fails.append("MISS:kd_shell_accepts_wrong_via_qual")

        # Missing DONE
        no_done = "\n".join(
            ln for ln in clean.splitlines() if not ln.startswith("VG_SUITE_COMPLETED")
        ) + "\n"
        godot_nodone = tmp / "fake_godot_nodone"
        _write_exec(
            godot_nodone,
            "#!/bin/bash\n"
            f"cat <<'EOF'\n{no_done}EOF\n"
            "exit 0\n",
        )
        r = _run_lane(tmp / "nodone", godot=godot_nodone)
        if r.returncode == 0:
            fails.append("MISS:kd_shell_accepts_missing_done")

        # Unexpectedly cleared (correct Twin@B)
        cleared = (
            "C2_KNOWN_DEFECT dual_import_same_name_twin\n"
            "EXPECTED_CORRECT via_qual=22 mod=res://test_suite/c2_path_mod_b.vg\n"
            f'VG_SEM_PATH path=bytecode fn=Twin mod="{MOD_B}"\n'
            "OBSERVED via_qual=22\n"
            f'VG_SEM_PATH path=bytecode fn=Twin mod="{MOD_B}"\n'
            "OBSERVED bare_Twin=22\n"
            "C2_KNOWN_DEFECT_CLEARED dual_import_same_name_twin via_qual=22\n"
            "PASS: dual_import_known_defect_probe_ran\n"
            "VG_SUITE_COMPLETED\n"
        )
        godot_cleared = tmp / "fake_godot_cleared"
        _write_exec(
            godot_cleared,
            "#!/bin/bash\n"
            f"cat <<'EOF'\n{cleared}EOF\n"
            "exit 0\n",
        )
        r = _run_lane(tmp / "cleared", godot=godot_cleared)
        if r.returncode == 0:
            fails.append("MISS:kd_shell_accepts_cleared_as_ok")
        else:
            summary = ""
            sp = tmp / "cleared" / "out" / "summary.txt"
            if sp.is_file():
                summary = sp.read_text(errors="replace")
            blob = summary + r.stdout + r.stderr
            if "defect_unexpectedly_cleared" not in blob:
                fails.append(f"MISS:kd_shell_cleared_not_actionable:{blob[-500:]}")

        # FAIL after DONE
        after_fail = clean + "FAIL: unrelated\n"
        godot_af = tmp / "fake_godot_after_fail"
        _write_exec(
            godot_af,
            "#!/bin/bash\n"
            f"cat <<'EOF'\n{after_fail}EOF\n"
            "exit 0\n",
        )
        r = _run_lane(tmp / "after_fail", godot=godot_af)
        if r.returncode == 0:
            fails.append("MISS:kd_shell_accepts_fail_after_done")

        # garbage Twin path tier
        garbage = clean.replace("path=bytecode", "path=garbage")
        godot_g = tmp / "fake_godot_garbage"
        _write_exec(
            godot_g,
            "#!/bin/bash\n"
            f"cat <<'EOF'\n{garbage}EOF\n"
            "exit 0\n",
        )
        r = _run_lane(tmp / "garbage", godot=godot_g)
        if r.returncode == 0:
            fails.append("MISS:kd_shell_accepts_garbage_path")

        # Third Twin path event
        third = clean.replace(
            "OBSERVED bare_Twin=11\n",
            "OBSERVED bare_Twin=11\n"
            f'VG_SEM_PATH path=bytecode fn=Twin mod="{MOD_A}"\n',
        )
        godot_t = tmp / "fake_godot_third"
        _write_exec(
            godot_t,
            "#!/bin/bash\n"
            f"cat <<'EOF'\n{third}EOF\n"
            "exit 0\n",
        )
        r = _run_lane(tmp / "third", godot=godot_t)
        if r.returncode == 0:
            fails.append("MISS:kd_shell_accepts_third_twin")

    after = _sha256(sentinel)
    if before != after:
        fails.append("MISS:current_test_txt_mutated_by_kd_shell_selftest")
    return fails
