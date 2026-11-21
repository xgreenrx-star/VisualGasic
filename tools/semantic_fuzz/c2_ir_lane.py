"""Explicit GODOT-backed CP3 IR example lane (not part of pure oracle selftest)."""

from __future__ import annotations

import json
import os
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional

from .compare import CompareError, compare_observations
from .phase2_c2_ir_examples import ALL_EXAMPLES
from .reference import evaluate_program
from .runner import MODES, check_required_path, find_godot, find_repo_root, run_program


@dataclass
class IrLaneReport:
    ok: bool
    cases: int = 0
    runs: int = 0
    matches: int = 0
    known_defects: int = 0
    failures: List[str] = field(default_factory=list)
    known_defect_details: List[dict] = field(default_factory=list)
    out_dir: Optional[str] = None


def run_c2_ir_lane(
    *,
    out_dir: Optional[Path] = None,
    godot: Optional[Path] = None,
    modes: Optional[list[str]] = None,
) -> IrLaneReport:
    report = IrLaneReport(ok=True)
    root = find_repo_root()
    try:
        godot = godot or find_godot(root)
    except FileNotFoundError as exc:
        report.ok = False
        report.failures.append(f"missing_GODOT:{exc}")
        return report
    if not godot.is_file() or not os.access(godot, os.X_OK):
        report.ok = False
        report.failures.append(f"invalid_GODOT:{godot}")
        return report

    mode_list = list(modes) if modes else list(MODES.keys())
    work = Path(out_dir) if out_dir else Path(tempfile.mkdtemp(prefix="vg-c2-ir-lane-"))
    work.mkdir(parents=True, exist_ok=True)
    report.out_dir = str(work)
    report.cases = len(ALL_EXAMPLES)

    for factory in ALL_EXAMPLES:
        prog, expected = factory()
        # Confirm oracle still independent.
        oracle = [o.to_dict() for o in evaluate_program(prog).observations]
        try:
            compare_observations(expected, oracle)
        except CompareError as exc:
            report.ok = False
            report.failures.append(f"oracle_drift:{prog.case_id}:{exc}")
            continue

        for mode in mode_list:
            report.runs += 1
            rr = run_program(
                prog, mode=mode, work_root=work, timeout_secs=45, godot=godot
            )
            if not rr.ok:
                report.ok = False
                report.failures.append(
                    f"run_failed:{prog.case_id}:{mode}:{rr.failure_code}:{rr.message}"
                )
                continue

            path_err = check_required_path(prog, mode, rr)
            if path_err:
                report.ok = False
                report.failures.append(f"path:{prog.case_id}:{mode}:{path_err}")

            # c2_byval_once: forced_ast ByVal double-eval fixed (checkpoint 002).
            # Oracle hits=1 is now a strict regression in all modes.
            try:
                compare_observations(expected, rr.observations)
                report.matches += 1
            except CompareError as exc:
                report.ok = False
                report.failures.append(
                    f"obs:{prog.case_id}:{mode}:{exc}:log={rr.log_path}"
                )

    (work / "ir_lane_report.json").write_text(
        json.dumps(
            {
                "ok": report.ok,
                "cases": report.cases,
                "runs": report.runs,
                "matches": report.matches,
                "known_defects": report.known_defects,
                "failures": report.failures,
                "known_defect_details": report.known_defect_details,
                "modes": mode_list,
                "godot": str(godot),
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    if not report.ok:
        status = "fail"
    elif report.known_defects:
        status = "ok_with_known_defects"
    else:
        status = "ok"
    (work / "gate_status.txt").write_text(status + "\n", encoding="utf-8")
    return report


def main(argv: Optional[list] = None) -> int:
    import argparse

    p = argparse.ArgumentParser(description="CP3 IR example GODOT lane")
    p.add_argument("--out", type=Path, default=None)
    args = p.parse_args(argv)
    rep = run_c2_ir_lane(out_dir=args.out)
    print(
        f"C2_IR_LANE ok={rep.ok} cases={rep.cases} runs={rep.runs} "
        f"matches={rep.matches} known_defects={rep.known_defects} "
        f"failures={len(rep.failures)} out={rep.out_dir}"
    )
    for f in rep.failures[:20]:
        print(" FAIL", f)
    for kd in rep.known_defect_details:
        print(
            f" KNOWN_DEFECT {kd['case_id']} mode={kd['mode']} class={kd.get('class')}"
        )
    return 0 if rep.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
