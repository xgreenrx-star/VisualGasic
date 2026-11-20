"""Fail-closed judge for the dual-import Twin known-defect lane."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Tuple

from .c2_fixture_gate import (
    ERROR_LINE_RE,
    ERROR_MARKERS,
    FAIL_LINE_RE,
    POST_DONE_RESULT_RE,
    _split_pre_post_done,
)
from .path_contract import parse_path_event_line


DONE_LINE = "VG_SUITE_COMPLETED"
DEFECT_BANNER = "C2_KNOWN_DEFECT dual_import_same_name_twin"
STILL_RE = re.compile(
    r"^C2_KNOWN_DEFECT_STILL dual_import_same_name_twin via_qual=(\d+)\s*$"
)
CLEARED_RE = re.compile(r"(?m)^C2_KNOWN_DEFECT_CLEARED\b")
EXPECTED_LINE = "EXPECTED_CORRECT via_qual=22 mod=res://test_suite/c2_path_mod_b.vg"
OBS_QUAL = "OBSERVED via_qual=11"
OBS_BARE = "OBSERVED bare_Twin=11"
PROBE_PASS = "PASS: dual_import_known_defect_probe_ran"
MOD_A = "res://test_suite/c2_path_mod_a.vg"
MOD_B = "res://test_suite/c2_path_mod_b.vg"

# Exact semantic record sequence (ignoring unrelated engine chatter).
EXPECTED_SEMANTIC_SEQ = [
    DEFECT_BANNER,
    EXPECTED_LINE,
    OBS_QUAL,
    OBS_BARE,
    "C2_KNOWN_DEFECT_STILL dual_import_same_name_twin via_qual=11",
    PROBE_PASS,
]


@dataclass
class KnownDefectVerdict:
    ok: bool
    reasons: List[str] = field(default_factory=list)


def _is_semantic_line(s: str) -> bool:
    return (
        s.startswith("C2_KNOWN_DEFECT")
        or s.startswith("EXPECTED_CORRECT")
        or s.startswith("OBSERVED ")
        or s.startswith("PASS:")
        or s.startswith("FAIL:")
        or s.startswith("C2_SUMMARY")
        or s.startswith("C2_KNOWN_FAIL")
    )


def _collect_twin_paths(pre: str, v: KnownDefectVerdict) -> List[dict]:
    twins = []
    for ln in pre.splitlines():
        s = ln.strip()
        if not s.startswith("VG_SEM_PATH"):
            continue
        try:
            ev = parse_path_event_line(s)
        except ValueError as exc:
            v.reasons.append(f"malformed_path_line:{exc}")
            continue
        if ev is None:
            continue
        if ev.get("fn") == "Twin":
            twins.append(ev)
    return twins


def judge_dual_import_twin_log(text: str, *, exit_code: int = 0) -> KnownDefectVerdict:
    """Accept only the exact documented defect signature + ordered records."""
    v = KnownDefectVerdict(ok=True)
    if exit_code != 0:
        v.ok = False
        v.reasons.append(f"nonzero_exit:{exit_code}")

    for marker in ERROR_MARKERS:
        if marker in text:
            v.ok = False
            v.reasons.append(f"runtime_or_script_error:{marker.strip()}")
    if ERROR_LINE_RE.search(text):
        v.ok = False
        v.reasons.append("runtime_or_script_error:ERROR:")

    pre, post, done_count, struct = _split_pre_post_done(text)
    v.reasons.extend(struct)
    if done_count == 0:
        v.ok = False
        v.reasons.append("missing_completion")
    elif done_count > 1:
        v.ok = False
        if not any(r.startswith("duplicate_completion") for r in v.reasons):
            v.reasons.append(f"duplicate_completion:{done_count}")

    if post.strip() and POST_DONE_RESULT_RE.search(post):
        v.ok = False
        v.reasons.append("records_after_completion")
    # Also reject FAIL:/PASS: style junk after DONE even if regex misses variants.
    for ln in post.splitlines():
        s = ln.strip()
        if s.startswith("FAIL:") or s.startswith("PASS:") or s.startswith("OBSERVED "):
            v.ok = False
            v.reasons.append(f"post_done_result:{s[:80]}")

    if CLEARED_RE.search(pre):
        v.ok = False
        v.reasons.append("defect_unexpectedly_cleared_update_contracts")

    # Exact ordered semantic records in pre (before DONE).
    semantic = [ln.strip() for ln in pre.splitlines() if _is_semantic_line(ln.strip())]
    if semantic != EXPECTED_SEMANTIC_SEQ:
        v.ok = False
        v.reasons.append(f"semantic_seq_mismatch:got={semantic}")

    # Any FAIL: in pre is fatal.
    for ln in pre.splitlines():
        s = ln.strip()
        if s.startswith("FAIL:"):
            v.ok = False
            v.reasons.append(f"fail_assertion:{s}")
            if FAIL_LINE_RE.match(s) is None:
                v.reasons.append(f"malformed_fail:{s!r}")

    twins = _collect_twin_paths(pre, v)
    if len(twins) != 2:
        v.ok = False
        v.reasons.append(f"twin_path_count:{len(twins)}")
    else:
        for i, ev in enumerate(twins):
            if ev.get("path") != "bytecode":
                v.ok = False
                v.reasons.append(f"twin_path_tier[{i}]={ev.get('path')}")
            if ev.get("mod") != MOD_A:
                v.ok = False
                v.reasons.append(f"twin_path_mod[{i}]={ev.get('mod')}")
        if any(ev.get("mod") == MOD_B for ev in twins):
            v.ok = False
            v.reasons.append("twin_attributed_to_mod_b_unexpected_fix")

    # Reject Twin events after DONE.
    post_twins = _collect_twin_paths(post, v)
    if post_twins:
        v.ok = False
        v.reasons.append(f"twin_paths_after_done:{len(post_twins)}")

    if v.reasons:
        v.ok = False
    return v


def run_known_defect_gate_selftests() -> List[str]:
    fails: List[str] = []

    def clean() -> str:
        return (
            f"{DEFECT_BANNER}\n"
            f"{EXPECTED_LINE}\n"
            f'VG_SEM_PATH path=bytecode fn=Twin mod="{MOD_A}"\n'
            f"{OBS_QUAL}\n"
            f'VG_SEM_PATH path=bytecode fn=Twin mod="{MOD_A}"\n'
            f"{OBS_BARE}\n"
            "C2_KNOWN_DEFECT_STILL dual_import_same_name_twin via_qual=11\n"
            f"{PROBE_PASS}\n"
            f"{DONE_LINE}\n"
        )

    v = judge_dual_import_twin_log(clean(), exit_code=0)
    if not v.ok:
        fails.append(f"MISS:known_defect_rejects_clean:{v.reasons}")

    poisoned = (
        f"{DEFECT_BANNER}\n"
        "C2_KNOWN_DEFECT_STILL dual_import_same_name_twin via_qual=999\n"
        f"{PROBE_PASS}\n"
        "SCRIPT ERROR: unrelated crash\n"
    )
    v = judge_dual_import_twin_log(poisoned, exit_code=17)
    if v.ok:
        fails.append("MISS:known_defect_accepts_fake_godot_poison")

    fixed = (
        f"{DEFECT_BANNER}\n"
        f"{EXPECTED_LINE}\n"
        f'VG_SEM_PATH path=bytecode fn=Twin mod="{MOD_B}"\n'
        "OBSERVED via_qual=22\n"
        f'VG_SEM_PATH path=bytecode fn=Twin mod="{MOD_B}"\n'
        "OBSERVED bare_Twin=22\n"
        "C2_KNOWN_DEFECT_CLEARED dual_import_same_name_twin via_qual=22\n"
        f"{PROBE_PASS}\n"
        f"{DONE_LINE}\n"
    )
    v = judge_dual_import_twin_log(fixed, exit_code=0)
    if v.ok:
        fails.append("MISS:known_defect_accepts_cleared_bug")
    if "defect_unexpectedly_cleared_update_contracts" not in v.reasons:
        fails.append(f"MISS:cleared_not_actionable:{v.reasons}")

    # FAIL after DONE
    after_fail = clean() + "FAIL: unrelated\n"
    v = judge_dual_import_twin_log(after_fail, exit_code=0)
    if v.ok:
        fails.append("MISS:known_defect_accepts_fail_after_done")

    # DONE before observations
    early_done = (
        f"{DEFECT_BANNER}\n"
        f"{EXPECTED_LINE}\n"
        f"{DONE_LINE}\n"
        f'VG_SEM_PATH path=bytecode fn=Twin mod="{MOD_A}"\n'
        f"{OBS_QUAL}\n"
        f'VG_SEM_PATH path=bytecode fn=Twin mod="{MOD_A}"\n'
        f"{OBS_BARE}\n"
        "C2_KNOWN_DEFECT_STILL dual_import_same_name_twin via_qual=11\n"
        f"{PROBE_PASS}\n"
    )
    v = judge_dual_import_twin_log(early_done, exit_code=0)
    if v.ok:
        fails.append("MISS:known_defect_accepts_done_before_obs")

    # garbage path tier
    garbage = clean().replace("path=bytecode", "path=garbage")
    v = judge_dual_import_twin_log(garbage, exit_code=0)
    if v.ok:
        fails.append("MISS:known_defect_accepts_garbage_path")

    # Third unexpected Twin event
    third = clean().replace(
        f"{OBS_BARE}\n",
        f"{OBS_BARE}\n"
        f'VG_SEM_PATH path=bytecode fn=Twin mod="{MOD_A}"\n',
    )
    v = judge_dual_import_twin_log(third, exit_code=0)
    if v.ok:
        fails.append("MISS:known_defect_accepts_third_twin")

    # Wrong via_qual
    wrong = clean().replace("via_qual=11", "via_qual=99").replace(
        "OBSERVED via_qual=11", "OBSERVED via_qual=99"
    ).replace("bare_Twin=11", "bare_Twin=99")
    # still line also replaced by first replace
    v = judge_dual_import_twin_log(wrong, exit_code=0)
    if v.ok:
        fails.append("MISS:known_defect_accepts_wrong_via_qual")

    # Missing DONE
    v = judge_dual_import_twin_log(clean().replace(f"{DONE_LINE}\n", ""), exit_code=0)
    if v.ok:
        fails.append("MISS:known_defect_accepts_missing_done")

    return fails


def main(argv: Optional[list] = None) -> int:
    import argparse

    p = argparse.ArgumentParser()
    p.add_argument("--log", type=Path, required=True)
    p.add_argument("--exit-code", type=int, default=0)
    args = p.parse_args(argv)
    text = args.log.read_text(encoding="utf-8", errors="replace")
    v = judge_dual_import_twin_log(text, exit_code=args.exit_code)
    status = "OK" if v.ok else "FAIL"
    print(f"{status} dual_import_twin exit={args.exit_code} reasons={v.reasons}")
    return 0 if v.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
