"""CLI: generate/run, replay, reduce, selftest."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .campaign import format_summary, replay_case_dir, run_campaign
from .generator import generate_batch, generate_case
from .harness_selftest import run_harness_selftests
from .ir import dumps_program, loads_program
from .oracle_selftest import run_oracle_selftests
from .reducer import reduce_failure
from .reference import evaluate_program
from .runner import run_program
from .compare import compare_observations


def cmd_selftest(_args: argparse.Namespace) -> int:
    import os

    fails = run_harness_selftests()
    # Nested injection probes set VG_SEM_SKIP_CI_GATE_SELFTEST=1 to avoid recursion.
    if os.environ.get("VG_SEM_SKIP_CI_GATE_SELFTEST") != "1":
        from .ci_gate_selftest import run_ci_gate_selftests

        fails.extend(run_ci_gate_selftests())
    if fails:
        print("SELFTEST FAIL")
        for f in fails:
            print(" ", f)
        return 1
    print("SELFTEST PASS: oracle + harness + CI gate negative tests")
    return 0


def cmd_oracle(_args: argparse.Namespace) -> int:
    fails = run_oracle_selftests()
    if fails:
        print("ORACLE FAIL")
        for f in fails:
            print(" ", f)
        return 1
    print("ORACLE PASS")
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    modes = [m.strip() for m in args.modes.split(",") if m.strip()]
    out = Path(args.out) if args.out else None
    report = run_campaign(
        args.seed,
        args.count,
        modes=modes,
        out_dir=out,
        timeout_secs=args.timeout,
        domain=getattr(args, "domain", "phase1") or "phase1",
    )
    print(format_summary(report))
    if report.distinct < report.generated:
        print(
            f"FAIL: distinct={report.distinct} < generated={report.generated}",
            file=sys.stderr,
        )
        return 1
    min_shapes = min(8, report.generated)
    if report.distinct_shapes < min_shapes:
        print(
            f"FAIL: distinct_shapes={report.distinct_shapes} < {min_shapes} "
            f"(salt-style uniqueness is not structural diversity)",
            file=sys.stderr,
        )
        return 1
    if report.generated < args.count:
        print("FAIL: generated fewer than requested", file=sys.stderr)
        return 1
    return 0 if report.ok else 1


def cmd_replay(args: argparse.Namespace) -> int:
    crep = replay_case_dir(Path(args.case_dir))
    print(json.dumps(crep.__dict__, indent=2))
    return 0 if crep.status == "pass" else 1


def cmd_reduce(args: argparse.Namespace) -> int:
    case_dir = Path(args.case_dir)
    from .campaign import _resolve_saved_mode
    from .identity import make_reduce_predicate
    from .provenance import check_bundle_provenance
    from .runner import find_godot, find_repo_root, file_sha256

    # Same schema/model gate as replay — refuse before mutating anything.
    pre = check_bundle_provenance(case_dir, compare_runtime=False)
    if pre.refuse:
        print(f"reduce refused: {pre.refuse}", file=sys.stderr)
        return 2
    from .bundle_integrity import validate_bundle_integrity

    integ = validate_bundle_integrity(case_dir)
    if integ:
        print(f"reduce refused: {integ}", file=sys.stderr)
        return 2

    prog = loads_program((case_dir / "ir.json").read_text(encoding="utf-8"))
    if getattr(prog, "source_modules", None):
        print(
            "reduce refused: multi-file source_modules not reducible yet; "
            "retain the original bound failure bundle",
            file=sys.stderr,
        )
        return 2
    fail_meta = {}
    if (case_dir / "failure.json").is_file():
        fail_meta = json.loads((case_dir / "failure.json").read_text(encoding="utf-8"))

    try:
        mode = _resolve_saved_mode(case_dir)
    except ValueError:
        mode = fail_meta.get("mode")
        if mode not in ("forced_ast", "interpreter", "default", "tier3"):
            raise
    failure_code = fail_meta.get("failure_code")
    if not failure_code:
        raise SystemExit("reduce requires failure.json with exact failure_code")
    if failure_code == "path_mismatch":
        print("path_mismatch is non-reducible; retaining original bundle")
        out = case_dir / "reduced"
        out.mkdir(exist_ok=True)
        (out / "ir.json").write_text(dumps_program(prog), encoding="utf-8")
        (out / "reduce_meta.json").write_text(
            json.dumps(
                {
                    "shrunk": False,
                    "attempts": 0,
                    "message": "path_mismatch non-reducible; retained original",
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        return 0

    # Label changed-environment before reduction (library + engine hashes).
    root = find_repo_root()
    godot = find_godot(root)
    so = root / "addons" / "visual_gasic" / "bin" / "libvisualgasic.linux.editor.x86_64.so"
    binary_hash = file_sha256(so) if so.is_file() else None
    engine_hash = file_sha256(godot) if Path(godot).is_file() else None
    env_verdict = check_bundle_provenance(
        case_dir,
        binary_hash=binary_hash,
        engine_hash=engine_hash,
        engine_path=str(godot),
        compare_runtime=True,
    )
    env_label = env_verdict.environment_label
    if env_label:
        print(env_label)

    still_fails = make_reduce_predicate(
        original=prog,
        mode=mode,
        failure_code=failure_code,
        work_root=case_dir / "_reduce_work",
        timeout_secs=args.timeout,
    )

    result = reduce_failure(
        prog,
        still_fails=still_fails,
        max_attempts=args.max_attempts,
        time_limit_secs=args.time_limit,
    )
    out = case_dir / "reduced"
    out.mkdir(exist_ok=True)
    (out / "ir.json").write_text(dumps_program(result.minimized), encoding="utf-8")
    msg = result.message
    if env_label:
        msg = f"{msg}; {env_label}"
    (out / "reduce_meta.json").write_text(
        json.dumps(
            {
                "shrunk": result.shrunk,
                "attempts": result.attempts,
                "message": msg,
                "environment": env_label or None,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(msg, f"attempts={result.attempts}")
    return 0


def cmd_emit(args: argparse.Namespace) -> int:
    prog = generate_case(args.seed, args.index)
    print(dumps_program(prog))
    from .emitter import emit_program

    print("---VG---")
    print(emit_program(prog, warmup_calls=args.warmup))
    print("---EXPECTED---")
    print(json.dumps([o.to_dict() for o in evaluate_program(prog).observations], indent=2))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="semantic_fuzz")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("selftest", help="oracle + harness negative tests")
    p.set_defaults(func=cmd_selftest)

    p = sub.add_parser("oracle", help="hand-worked oracle boundaries only")
    p.set_defaults(func=cmd_oracle)

    p = sub.add_parser("run", help="generate and run a seeded campaign")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--count", type=int, default=100)
    p.add_argument("--modes", default="forced_ast,interpreter,default")
    p.add_argument("--out", default="")
    p.add_argument("--timeout", type=float, default=20.0)
    p.add_argument(
        "--domain",
        default="phase1",
        choices=("phase1", "c2"),
        help="phase1=arith/select smoke domain; c2=scalar call domain",
    )
    p.set_defaults(func=cmd_run)

    p = sub.add_parser("replay", help="replay a saved case directory")
    p.add_argument("case_dir")
    p.set_defaults(func=cmd_replay)

    p = sub.add_parser("reduce", help="IR-aware reduce a saved failure")
    p.add_argument("case_dir")
    p.add_argument("--max-attempts", type=int, default=40)
    p.add_argument("--time-limit", type=float, default=90.0)
    p.add_argument("--timeout", type=float, default=20.0)
    p.set_defaults(func=cmd_reduce)

    p = sub.add_parser("emit", help="emit one case IR/VG/expected")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--index", type=int, default=0)
    p.add_argument("--warmup", type=int, default=0)
    p.set_defaults(func=cmd_emit)

    def cmd_c2_ir_lane(a: argparse.Namespace) -> int:
        from .c2_ir_lane import main as ir_main

        return ir_main(["--out", a.out] if a.out else [])

    p = sub.add_parser(
        "c2-ir-lane",
        help="GODOT-backed CP3 IR hand-example matrix (explicit; not in selftest)",
    )
    p.add_argument("--out", default="")
    p.set_defaults(func=cmd_c2_ir_lane)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
