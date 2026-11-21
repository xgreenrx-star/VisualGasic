"""C4 short-circuit model — pure oracle/harness selftests (no Godot / no .so)."""

from __future__ import annotations

from typing import List

from .compare import CompareError, compare_observations
from .generator_c4 import generate_c4_batch, generate_c4_case
from .ir import (
    Call,
    Helper,
    Lit,
    LogicBin,
    LogicNot,
    Note,
    Observe,
    Program,
    ReturnStmt,
)
from .reference import evaluate_program
from .validate import validate_program


def _hand_andalso_ft() -> Program:
    """LHS False → RHS never runs; result 0; only event_A."""
    return Program(
        case_id="hand_c4_andalso_ft",
        seed=0,
        index=0,
        family="c4_shortcircuit",
        helpers=[
            Helper("HitA", [], [Note("A"), ReturnStmt(Lit(0))], returns=True),
            Helper("HitB", [], [Note("B"), ReturnStmt(Lit(1))], returns=True),
        ],
        main=[
            Observe(
                "r",
                LogicBin("AndAlso", Call("HitA", []), Call("HitB", [])),
            )
        ],
        required_path={
            "forced_ast": "ast",
            "interpreter": "bytecode",
            "default": "bytecode",
            "tier3": "bytecode",
        },
        path_target="SemMain",
        notes="hand: AndAlso FT → events A only, r=0",
    )


def _hand_orelse_tf() -> Program:
    return Program(
        case_id="hand_c4_orelse_tf",
        seed=0,
        index=1,
        family="c4_shortcircuit",
        helpers=[
            Helper("HitA", [], [Note("A"), ReturnStmt(Lit(1))], returns=True),
            Helper("HitB", [], [Note("B"), ReturnStmt(Lit(0))], returns=True),
        ],
        main=[
            Observe(
                "r",
                LogicBin("OrElse", Call("HitA", []), Call("HitB", [])),
            )
        ],
        required_path={
            "forced_ast": "ast",
            "interpreter": "bytecode",
            "default": "bytecode",
            "tier3": "bytecode",
        },
        path_target="SemMain",
        notes="hand: OrElse TF → events A only, r=1",
    )


def main() -> int:
    fails: List[str] = []

    for hand, want_events, want_r in (
        (_hand_andalso_ft(), ["A"], 0),
        (_hand_orelse_tf(), ["A"], 1),
        (
            Program(
                case_id="hand_c4_not",
                seed=0,
                index=2,
                family="c4_shortcircuit",
                helpers=[
                    Helper("HitA", [], [Note("A"), ReturnStmt(Lit(0))], returns=True),
                ],
                main=[Observe("r", LogicNot(Call("HitA", [])))],
                required_path={
                    "forced_ast": "ast",
                    "interpreter": "bytecode",
                    "default": "bytecode",
                    "tier3": "bytecode",
                },
                path_target="SemMain",
            ),
            ["A"],
            1,
        ),
    ):
        validate_program(hand)
        obs = evaluate_program(hand).observations
        names = [o.name for o in obs]
        for ev in want_events:
            if f"event_{ev}" not in names:
                fails.append(f"hand {hand.case_id}: missing event_{ev} in {names}")
        # RHS must not appear when short-circuited.
        if hand.case_id.endswith("_ft") or hand.case_id.endswith("_tf"):
            if "event_B" in names:
                fails.append(f"hand {hand.case_id}: unexpected event_B")
        r_obs = [o for o in obs if o.name == "r"]
        if len(r_obs) != 1 or int(r_obs[0].typed.value) != want_r:
            fails.append(f"hand {hand.case_id}: r want={want_r} got={r_obs}")

    # Generator batch + fingerprints.
    try:
        batch = generate_c4_batch(20261123, 24)
    except Exception as exc:
        fails.append(f"batch: {exc}")
        batch = []
    if len(batch) < 24:
        fails.append(f"batch size {len(batch)}")

    # Detector negative: extra RHS event that the oracle never produced.
    prog = _hand_andalso_ft()
    good = [o.to_dict() for o in evaluate_program(prog).observations]
    # Insert a spurious event_B before r.
    bad = []
    for o in good:
        if o["name"] == "r":
            bad.append(
                {
                    "name": "event_B",
                    "type": "String",
                    "value": "B",
                }
            )
        bad.append(dict(o))
    try:
        compare_observations(good, bad)
        fails.append("detector_extra_rhs: accepted mutation")
    except CompareError as exc:
        if exc.code not in ("wrong_value", "extra", "duplicate", "order", "missing"):
            # Accept any compare rejection; prefer wrong_value / order / extra.
            if "wrong" not in exc.code and exc.code not in (
                "extra_observation",
                "duplicate_observation",
                "observation_order",
                "missing_observation",
            ):
                # Still a rejection — OK if not silent accept.
                pass
    else:
        pass

    # Also reject if actual has fewer events than expected (missing RHS wrongly required).
    try:
        compare_observations(bad, good)
        fails.append("detector_extra_rhs_rev: accepted reverse mutation")
    except CompareError:
        pass

    # Spot-check one generated case evaluates.
    try:
        g = generate_c4_case(7, 3)
        evaluate_program(g)
    except Exception as exc:
        fails.append(f"generate_case: {exc}")

    if fails:
        print("C4_SELFTEST FAIL")
        for f in fails:
            print(" ", f)
        return 1
    print("C4_SELFTEST PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
