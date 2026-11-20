"""Deterministic typed IR generator for Phase 1 semantic campaigns."""

from __future__ import annotations

import hashlib
from random import Random
from typing import Iterator

from .ir import (
    Assign,
    Bin,
    Call,
    CallStmt,
    Cmp,
    ForStmt,
    Helper,
    IfStmt,
    Lit,
    Observe,
    Program,
    ReturnStmt,
    SelectCase,
    SelectStmt,
    Var,
)
from .reference import ReferenceError, evaluate_program


FAMILIES = (
    "arith_lit_left",
    "arith_lit_right",
    "arith_noncomm",
    "select_sparse",
    "nested_cond_loop",
    "helper_side_effect",
    "module_local_warmup",
    "metamorphic_pure_extract",
)


def case_id_for(seed: int, index: int, family: str) -> str:
    digest = hashlib.sha1(f"{seed}:{index}:{family}".encode()).hexdigest()[:10]
    return f"s{seed}_i{index}_{family}_{digest}"


def _safe_int(rng: Random, lo: int = -40, hi: int = 40) -> int:
    return rng.randint(lo, hi)


def _nonzero(rng: Random, lo: int = -20, hi: int = 20) -> int:
    v = 0
    while v == 0:
        v = rng.randint(lo, hi)
    return v


def gen_arith_lit_left(rng: Random, seed: int, index: int) -> Program:
    a = _safe_int(rng)
    b = _safe_int(rng)
    op = rng.choice(["+", "-", "*", "\\", "Mod"])
    if op in ("\\", "Mod"):
        b = _nonzero(rng)
        a = rng.randint(-80, 80)
    family = "arith_lit_left"
    # literal left, variable right
    prog = Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["arith", "lit_left", f"op:{op}"],
        module_vars={},
        main=[
            Assign("x", Lit(value=b)),
            Assign("r", Bin(op=op, left=Lit(value=a), right=Var("x"))),
            Observe("r", Var("r")),
        ],
        required_path={"forced_ast": "ast", "interpreter": "bytecode"},
        path_target="SemMain",
    )
    return prog


def gen_arith_lit_right(rng: Random, seed: int, index: int) -> Program:
    a = _safe_int(rng)
    b = _safe_int(rng)
    op = rng.choice(["+", "-", "*", "\\", "Mod"])
    if op in ("\\", "Mod"):
        b = _nonzero(rng)
        a = rng.randint(-80, 80)
    family = "arith_lit_right"
    prog = Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["arith", "lit_right", f"op:{op}"],
        main=[
            Assign("x", Lit(value=a)),
            Assign("r", Bin(op=op, left=Var("x"), right=Lit(value=b))),
            Observe("r", Var("r")),
        ],
        required_path={"forced_ast": "ast", "interpreter": "bytecode"},
        path_target="SemMain",
    )
    return prog


def gen_arith_noncomm(rng: Random, seed: int, index: int) -> Program:
    a = rng.randint(5, 40)
    b = rng.randint(1, 9)
    if rng.random() < 0.5:
        a = -a
    op = rng.choice(["-", "\\"])
    family = "arith_noncomm"
    prog = Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["arith", "noncomm", f"op:{op}"],
        main=[
            Assign("x", Lit(value=a)),
            Assign("y", Lit(value=b)),
            Observe("fwd", Bin(op=op, left=Var("x"), right=Var("y"))),
            Observe("rev", Bin(op=op, left=Var("y"), right=Var("x"))),
        ],
        required_path={"forced_ast": "ast", "interpreter": "bytecode"},
        path_target="SemMain",
        notes="noncommutative pair must differ when a!=b",
    )
    return prog


def gen_select_sparse(rng: Random, seed: int, index: int) -> Program:
    # Widely separated cases including negatives (parser accepts Case -N).
    pool = [-1000, -50, 0, 1, 7, 50, 99, 1000, 5000, 9000 + (index % 17)]
    cases_vals = sorted({rng.choice(pool) for _ in range(4)})
    while len(cases_vals) < 3:
        cases_vals = sorted(set(cases_vals) | {rng.choice(pool)})
    mode = index % 4
    if mode == 0:
        sel = cases_vals[0]  # min
    elif mode == 1:
        sel = cases_vals[-1]  # max
    elif mode == 2:
        # hole between first two if possible
        lo, hi = cases_vals[0], cases_vals[1]
        sel = lo + 1 if hi > lo + 1 else lo - 3
        if sel in cases_vals:
            sel = hi + 3
    else:
        sel = cases_vals[rng.randrange(len(cases_vals))]
    family = "select_sparse"
    cases = [
        SelectCase(values=[v], body=[Assign("r", Lit(value=v)), Observe("hit", Var("r"))])
        for v in cases_vals
    ]
    prog = Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["select", "sparse"],
        main=[
            Assign("r", Lit(value=-1)),
            SelectStmt(
                selector=Lit(value=sel),
                cases=cases,
                else_body=[Assign("r", Lit(value=0)), Observe("hit", Var("r"))],
            ),
        ],
        required_path={"forced_ast": "ast", "interpreter": "bytecode"},
        path_target="SemMain",
    )
    return prog


def gen_nested_cond_loop(rng: Random, seed: int, index: int) -> Program:
    lo = rng.randint(1, 3)
    hi = lo + rng.randint(0, 4)
    thresh = rng.randint(lo, hi + 1)
    family = "nested_cond_loop"
    prog = Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["nested", "loop", "if"],
        main=[
            Assign("acc", Lit(value=0)),
            ForStmt(
                var="i",
                lo=Lit(value=lo),
                hi=Lit(value=hi),
                body=[
                    IfStmt(
                        cond=Cmp(op=">", left=Var("i"), right=Lit(value=thresh)),
                        then_body=[Assign("acc", Bin(op="+", left=Var("acc"), right=Var("i")))],
                        else_body=[Assign("acc", Bin(op="+", left=Var("acc"), right=Lit(value=1)))],
                    )
                ],
            ),
            Observe("acc", Var("acc")),
        ],
        required_path={"forced_ast": "ast", "interpreter": "bytecode"},
        path_target="SemMain",
    )
    return prog


def gen_helper_side_effect(rng: Random, seed: int, index: int) -> Program:
    n = rng.randint(1, 5)
    add = rng.randint(1, 9)
    family = "helper_side_effect"
    bump = Helper(
        name="Bump",
        params=["d"],
        returns=False,
        side_effect_global="G",
        body=[
            Assign("G", Bin(op="+", left=Var("G"), right=Var("d"))),
            Observe("g_step", Var("G")),
        ],
    )
    prog = Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["helper", "side_effect"],
        module_vars={"G": 0},
        helpers=[bump],
        main=[
            ForStmt(
                var="i",
                lo=Lit(value=1),
                hi=Lit(value=n),
                body=[CallStmt(name="Bump", args=[Lit(value=add)])],
            ),
            Observe("g_final", Var("G")),
        ],
        required_path={"forced_ast": "ast", "interpreter": "bytecode"},
        # Bump is the helper whose body must run on the requested path.
        path_target="Bump",
    )
    return prog


def gen_module_local_warmup(rng: Random, seed: int, index: int) -> Program:
    """Module + local + repeated KernelNative for warmup / path proof."""
    base = rng.randint(1, 20)
    family = "module_local_warmup"
    kernel = Helper(
        name="KernelNative",
        params=["x"],
        returns=True,
        body=[
            ReturnStmt(
                expr=Bin(
                    op="+",
                    left=Bin(op="*", left=Var("x"), right=Lit(value=3)),
                    right=Lit(value=base),
                )
            )
        ],
    )
    prog = Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["module", "local", "warmup", "native_eligible"],
        module_vars={"M": base},
        helpers=[kernel],
        main=[
            Assign("loc", Lit(value=index % 17 + 1)),
            Assign("r", Call(name="KernelNative", args=[Var("loc")])),
            Observe("r", Var("r")),
            Observe("m", Var("M")),
        ],
        required_path={
            "forced_ast": "ast",
            "interpreter": "bytecode",
            # After warmup in default/tier3, KernelNative should enter native when supported.
            "default": "native_t2",
            "tier3": "native_t3_or_native_t2",
        },
        path_target="KernelNative",
    )
    return prog


def gen_metamorphic_pure_extract(rng: Random, seed: int, index: int) -> Program:
    """Same observations after extracting a pure expression into a helper."""
    a = _safe_int(rng, 1, 30)
    b = _safe_int(rng, 1, 30)
    family = "metamorphic_pure_extract"
    helper = Helper(
        name="PureAdd",
        params=["p", "q"],
        returns=True,
        body=[ReturnStmt(expr=Bin(op="+", left=Var("p"), right=Var("q")))],
    )
    prog = Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["metamorphic", "pure_extract"],
        helpers=[helper],
        main=[
            Assign("r", Call(name="PureAdd", args=[Lit(value=a), Lit(value=b)])),
            Observe("r", Var("r")),
        ],
        required_path={"forced_ast": "ast", "interpreter": "bytecode"},
        path_target="PureAdd",
        notes="metamorphic: renaming PureAdd params must not change obs",
    )
    return prog


def gen_fallback_andalso(seed: int, index: int = -1) -> Program:
    """Fixed fallback-contract: AndAlso join must decline native safely."""
    family = "fallback_andalso"
    idx = index if index >= 0 else 0
    # Vary inputs by index so cases are not identical templates.
    a = 2 + (idx % 5)
    b = 3 + ((idx // 5) % 4)
    prog = Program(
        case_id=case_id_for(seed, idx, family),
        seed=seed,
        index=idx,
        family=family,
        tags=["fallback", "andalso", "jit_decline"],
        helpers=[
            Helper(
                name="ShortJoin",
                params=["a", "b"],
                returns=True,
                # Reference uses nested If (same truth table as AndAlso here).
                body=[
                    IfStmt(
                        cond=Cmp(op=">", left=Var("a"), right=Lit(value=0)),
                        then_body=[
                            IfStmt(
                                cond=Cmp(op=">", left=Var("b"), right=Lit(value=0)),
                                then_body=[
                                    ReturnStmt(
                                        expr=Bin(op="+", left=Var("a"), right=Var("b"))
                                    )
                                ],
                                else_body=[ReturnStmt(expr=Lit(value=0))],
                            )
                        ],
                        else_body=[ReturnStmt(expr=Lit(value=0))],
                    )
                ],
            )
        ],
        main=[
            Assign("r", Call(name="ShortJoin", args=[Lit(value=a), Lit(value=b)])),
            Observe("r", Var("r")),
        ],
        required_path={"forced_ast": "ast", "interpreter": "bytecode"},
        path_target="ShortJoin",
        fallback_contract="tier2_decline_andalso_phi",
        notes="EMIT_ANDALSO_JOIN",
    )
    return prog


GENERATORS = {
    "arith_lit_left": gen_arith_lit_left,
    "arith_lit_right": gen_arith_lit_right,
    "arith_noncomm": gen_arith_noncomm,
    "select_sparse": gen_select_sparse,
    "nested_cond_loop": gen_nested_cond_loop,
    "helper_side_effect": gen_helper_side_effect,
    "module_local_warmup": gen_module_local_warmup,
    "metamorphic_pure_extract": gen_metamorphic_pure_extract,
}


def generate_case(seed: int, index: int) -> Program:
    rng = Random((seed << 16) ^ (index * 0x9E3779B9))
    # Reserve every 17th slot for the fixed AndAlso fallback fixture.
    if index % 17 == 16:
        prog = gen_fallback_andalso(seed, index)
    else:
        family = FAMILIES[index % len(FAMILIES)]
        prog = GENERATORS[family](rng, seed, index)
    try:
        evaluate_program(prog)
    except ReferenceError as exc:
        raise ReferenceError(f"generator produced unsafe case {prog.case_id}: {exc}") from exc
    return prog


def generate_batch(seed: int, count: int) -> list[Program]:
    if count < 1:
        raise ValueError("count must be positive")
    # Draw until `count` distinct full fingerprints; refuse salt-style padding.
    out: list[Program] = []
    seen: set[str] = set()
    i = 0
    attempts = 0
    max_attempts = count * 20
    while len(out) < count and attempts < max_attempts:
        prog = generate_case(seed, i)
        i += 1
        attempts += 1
        fp = structural_fingerprint(prog)
        if fp in seen:
            continue
        seen.add(fp)
        out.append(prog)
    if len(out) < count:
        raise RuntimeError(
            f"could only produce {len(out)} distinct programs of {count} requested "
            f"(no salt padding; improve generator diversity)"
        )
    return out


def iter_cases(seed: int, count: int) -> Iterator[Program]:
    for p in generate_batch(seed, count):
        yield p


def structural_fingerprint(prog: Program) -> str:
    """Full IR fingerprint (literals included). Ignores case_id/index only."""
    from .ir import program_to_dict
    import json

    d = program_to_dict(prog)
    d.pop("case_id", None)
    d.pop("index", None)
    return hashlib.sha1(json.dumps(d, sort_keys=True, default=str).encode()).hexdigest()


_SHAPE_DROP_KEYS = frozenset(
    {
        "case_id",
        "index",
        "seed",
        "path_module",
        "path_module_key",
        "notes",
        "tags",  # nonsemantic / salt-style; shape from IR structure only
    }
)


def _strip_literals(obj):
    """Replace integer literals/defaults/inits with '_' for shape-only comparison."""
    if isinstance(obj, dict):
        if obj.get("kind") == "lit":
            return {"kind": "lit", "type": obj.get("type"), "value": "_"}
        out = {}
        for k, v in obj.items():
            if k in _SHAPE_DROP_KEYS:
                continue
            if k == "default" and isinstance(v, int) and not isinstance(v, bool):
                out[k] = "_"
                continue
            if k == "local_vars" and isinstance(v, dict):
                out[k] = {name: "_" for name in v}
                continue
            if k == "module_vars" and isinstance(v, dict):
                out[k] = {name: "_" for name in v}
                continue
            out[k] = _strip_literals(v)
        return out
    if isinstance(obj, list):
        return [_strip_literals(x) for x in obj]
    return obj


def shape_fingerprint(prog: Program) -> str:
    """Family/control-flow/op shape without literal values (honest diversity)."""
    from .ir import program_to_dict
    import json

    d = _strip_literals(program_to_dict(prog))
    return hashlib.sha1(json.dumps(d, sort_keys=True, default=str).encode()).hexdigest()
