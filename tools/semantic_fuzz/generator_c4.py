"""Bounded C4 short-circuit generator (AndAlso / OrElse / Not).

Independent reference computes both the Integer 0/1 result and the exact
ordered event list from side-effecting leaf helpers. Non-short-circuit
And/Or remain fixture-only (OBSERVED contract question) and are excluded.
"""

from __future__ import annotations

from random import Random
from typing import List, Tuple

from .generator import case_id_for, shape_fingerprint, structural_fingerprint
from .ir import (
    Call,
    Expr,
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

C4_FAMILIES = ("c4_shortcircuit",)

UNSUPPORTED_PAIRS = (
    "non_shortcircuit_and_or",  # fixture OBSERVED; excluded from generator
    "error_boundary_random",  # errors stay deterministic fixtures only
)

_LEAF_LETTERS = ("A", "B", "C", "D")


def _req_path() -> dict:
    return {
        "forced_ast": "ast",
        "interpreter": "bytecode",
        "default": "bytecode",
        "tier3": "bytecode",
    }


def _leaf_helper(letter: str, value: int) -> Helper:
    return Helper(
        name=f"Hit{letter}",
        params=[],
        body=[Note(letter), ReturnStmt(Lit(value))],
        returns=True,
    )


def _gen_tree(rng: Random, depth: int) -> Tuple[Expr, set[str]]:
    """Random tree depth <= ``depth`` of AndAlso/OrElse/Not over Hit* leaves."""
    used: set[str] = set()

    def rec(d: int) -> Expr:
        # Prefer leaves near the budget; always leaf at d==0.
        if d <= 0 or (d < 3 and rng.random() < 0.35):
            letter = rng.choice(_LEAF_LETTERS)
            used.add(letter)
            return Call(f"Hit{letter}", [])
        kind = rng.choice(("AndAlso", "OrElse", "Not", "AndAlso", "OrElse"))
        if kind == "Not":
            return LogicNot(rec(d - 1))
        return LogicBin(op=kind, left=rec(d - 1), right=rec(d - 1))

    return rec(depth), used


def gen_c4_shortcircuit(rng: Random, seed: int, index: int) -> Program:
    family = "c4_shortcircuit"
    depth = rng.randint(1, 3)
    tree, used = _gen_tree(rng, depth)
    # Ensure at least one leaf even for degenerate Not(leaf).
    if not used:
        used.add("A")
        tree = Call("HitA", [])
    leaf_vals = {L: rng.choice((0, 1)) for L in used}
    helpers = [_leaf_helper(L, leaf_vals[L]) for L in sorted(used)]
    main = [Observe("r", tree)]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c4", "shortcircuit"],
        helpers=helpers,
        main=main,
        required_path=_req_path(),
        path_target="SemMain",
        notes=f"c4 sc depth={depth} leaves={leaf_vals}",
    )


_GENERATORS = {
    "c4_shortcircuit": gen_c4_shortcircuit,
}


def generate_c4_case(seed: int, index: int) -> Program:
    rng = Random((seed << 16) ^ (index * 0x9E3779B9) ^ 0xC40001)
    family = C4_FAMILIES[index % len(C4_FAMILIES)]
    prog = _GENERATORS[family](rng, seed, index)
    evaluate_program(prog)
    return prog


def generate_c4_batch(seed: int, count: int) -> List[Program]:
    if count < 1:
        raise ValueError("empty batch refused")
    out: List[Program] = []
    seen = set()
    i = 0
    attempts = 0
    while len(out) < count and attempts < count * 80:
        attempts += 1
        prog = generate_c4_case(seed, i)
        i += 1
        fp = structural_fingerprint(prog)
        if fp in seen:
            continue
        seen.add(fp)
        out.append(prog)
    if len(out) < count:
        raise RuntimeError(f"c4 batch under-generated: {len(out)}/{count}")
    return out


def covered_pairs(programs: List[Program]) -> list[str]:
    pairs = set()
    for p in programs:
        if p.family == "c4_shortcircuit":
            pairs.add("c4_shortcircuit_andalso_orelse_not")
    return sorted(pairs)
