"""Bounded C2 scalar-call IR generator (supported domain only)."""

from __future__ import annotations

import hashlib
from random import Random
from typing import List

from .ir import (
    Assign,
    Bin,
    Call,
    CallStmt,
    Cmp,
    Helper,
    IfStmt,
    Lit,
    Note,
    Observe,
    ParamSpec,
    Program,
    ReturnStmt,
    Var,
)
from .reference import evaluate_program


C2_FAMILIES = (
    "c2_byval_standalone",
    "c2_byval_expr",
    "c2_byref_standalone",
    "c2_byref_expr",
    "c2_two_distinct",
    "c2_nested_effects",
    "c2_module_local_shadow",
    "c2_local_caller",
    "c2_recursion_optional",
    "c2_early_exit",
    "c2_import_byref",
    "c2_import_byval_expr",
    "c2_import_local_caller",
    "c2_import_nested",
)

UNSUPPORTED_PAIRS = [
    "alias_repeated_byref_args",
    "impure_index_byref",
    "nested_byval_call_arg_side_effect",
    "multi_file_import_same_name",
    # VG Import currently shares Dim namespace; reference Env separates them.
    "multi_file_same_name_module_scalar",
]


def case_id_for(seed: int, index: int, family: str) -> str:
    digest = hashlib.sha1(f"c2:{seed}:{index}:{family}".encode()).hexdigest()[:10]
    return f"c2_s{seed}_i{index}_{family}_{digest}"


def _safe(rng: Random, lo: int = 0, hi: int = 20) -> int:
    return rng.randint(lo, hi)


def _req_paths() -> dict:
    return {
        "forced_ast": "ast",
        "interpreter": "bytecode",
        "default": "bytecode_or_native",
        "tier3": "bytecode_or_native",
    }


def gen_byval_standalone(rng: Random, seed: int, index: int) -> Program:
    x0 = _safe(rng, 1, 15)
    family = "c2_byval_standalone"
    helpers = [
        Helper(
            "BumpVal",
            [ParamSpec("n", "byval")],
            [Assign("n", Bin("+", Var("n"), Lit(1))), ReturnStmt(Lit(0))],
            returns=False,
        )
    ]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "byval"],
        module_vars={"x": 0},
        helpers=helpers,
        main=[
            Assign("x", Lit(x0)),
            CallStmt("BumpVal", [Var("x")]),
            Observe("x_after", Var("x")),
        ],
        required_path=_req_paths(),
        path_target="BumpVal",
        path_targets=["BumpVal"],
    )


def gen_byval_expr(rng: Random, seed: int, index: int) -> Program:
    v0 = _safe(rng, 1, 12)
    family = "c2_byval_expr"
    helpers = [
        Helper(
            "TakeVal",
            [ParamSpec("v", "byval")],
            [ReturnStmt(Bin("+", Var("v"), Lit(1)))],
        )
    ]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "byval", "expr"],
        module_vars={"r": 0},
        helpers=helpers,
        main=[
            Assign("r", Call("TakeVal", [Lit(v0)])),
            Observe("r", Var("r")),
        ],
        required_path=_req_paths(),
        path_target="TakeVal",
        path_targets=["TakeVal"],
    )


def gen_byref_standalone(rng: Random, seed: int, index: int) -> Program:
    x0 = _safe(rng, 1, 15)
    family = "c2_byref_standalone"
    helpers = [
        Helper(
            "BumpRef",
            [ParamSpec("n", "byref")],
            [Assign("n", Bin("+", Var("n"), Lit(1))), ReturnStmt(Lit(0))],
            returns=False,
        )
    ]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "byref"],
        module_vars={"x": 0},
        helpers=helpers,
        main=[
            Assign("x", Lit(x0)),
            CallStmt("BumpRef", [Var("x")]),
            Observe("x_after", Var("x")),
        ],
        required_path=_req_paths(),
        path_target="BumpRef",
        path_targets=["BumpRef"],
    )


def gen_byref_expr(rng: Random, seed: int, index: int) -> Program:
    x0 = _safe(rng, 1, 12)
    add = _safe(rng, 1, 5)
    family = "c2_byref_expr"
    helpers = [
        Helper(
            "ExprByRef",
            [ParamSpec("x", "byref")],
            [
                Assign("x", Bin("+", Var("x"), Lit(add))),
                ReturnStmt(Bin("*", Var("x"), Lit(2))),
            ],
        )
    ]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "byref", "expr"],
        module_vars={"x": 0, "r": 0},
        helpers=helpers,
        main=[
            Assign("x", Lit(x0)),
            Assign("r", Call("ExprByRef", [Var("x")])),
            Observe("r", Var("r")),
            Observe("x", Var("x")),
        ],
        required_path=_req_paths(),
        path_target="ExprByRef",
        path_targets=["ExprByRef"],
    )


def gen_two_distinct(rng: Random, seed: int, index: int) -> Program:
    a0 = _safe(rng, 1, 10)
    b0 = _safe(rng, 1, 10)
    if rng.random() < 0.4:
        b0 = a0
    family = "c2_two_distinct"
    helpers = [
        Helper(
            "Two",
            [ParamSpec("a", "byref"), ParamSpec("b", "byref")],
            [
                Assign("a", Bin("+", Var("a"), Lit(1))),
                Assign("b", Bin("+", Var("b"), Lit(10))),
                ReturnStmt(Lit(0)),
            ],
            returns=False,
        )
    ]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "two_loc", f"equal_init={a0 == b0}"],
        module_vars={"x": 0, "y": 0},
        helpers=helpers,
        main=[
            Assign("x", Lit(a0)),
            Assign("y", Lit(b0)),
            CallStmt("Two", [Var("x"), Var("y")]),
            Observe("x", Var("x")),
            Observe("y", Var("y")),
        ],
        required_path=_req_paths(),
        path_target="Two",
        path_targets=["Two"],
    )


def gen_nested_effects(rng: Random, seed: int, index: int) -> Program:
    family = "c2_nested_effects"
    helpers = [
        Helper(
            "Inner",
            [ParamSpec("y", "byref")],
            [Note("inner"), Assign("y", Bin("+", Var("y"), Lit(100))), ReturnStmt(Lit(0))],
            returns=False,
        ),
        Helper(
            "Outer",
            [ParamSpec("x", "byref")],
            [
                Note("outer_enter"),
                Assign("x", Bin("+", Var("x"), Lit(1))),
                CallStmt("Inner", [Var("x")]),
                Assign("x", Bin("+", Var("x"), Lit(10))),
                Note("outer_exit"),
                ReturnStmt(Lit(0)),
            ],
            returns=False,
        ),
    ]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "nested", "events"],
        module_vars={"x": 0},
        helpers=helpers,
        main=[
            Assign("x", Lit(0)),
            CallStmt("Outer", [Var("x")]),
            Observe("x", Var("x")),
        ],
        required_path=_req_paths(),
        path_target="Outer",
        path_targets=["Outer", "Inner"],
    )


def gen_module_local_shadow(rng: Random, seed: int, index: int) -> Program:
    mod0 = _safe(rng, 1, 9)
    loc = _safe(rng, 20, 40)
    family = "c2_module_local_shadow"
    helpers = [
        Helper(
            "Shadow",
            [],
            [Assign("x", Lit(loc)), ReturnStmt(Var("x"))],
            local_vars={"x": 0},
        ),
        Helper(
            "BumpMod",
            [],
            [Assign("x", Bin("+", Var("x"), Lit(1))), ReturnStmt(Lit(0))],
            returns=False,
        ),
    ]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "shadow"],
        module_vars={"x": 0, "r": 0},
        helpers=helpers,
        main=[
            Assign("x", Lit(mod0)),
            Assign("r", Call("Shadow", [])),
            Observe("r", Var("r")),
            Observe("mod_x", Var("x")),
            CallStmt("BumpMod", []),
            Observe("mod_after", Var("x")),
        ],
        required_path=_req_paths(),
        path_target="Shadow",
        path_targets=["Shadow", "BumpMod"],
    )


def gen_local_caller(rng: Random, seed: int, index: int) -> Program:
    x0 = _safe(rng, 2, 15)
    family = "c2_local_caller"
    helpers = [
        Helper(
            "BumpRef",
            [ParamSpec("n", "byref")],
            [Assign("n", Bin("+", Var("n"), Lit(1))), ReturnStmt(Lit(0))],
            returns=False,
        )
    ]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "local_caller"],
        module_vars={},
        helpers=helpers,
        main=[
            Assign("x", Lit(x0)),
            CallStmt("BumpRef", [Var("x")]),
            Observe("x", Var("x")),
        ],
        required_path=_req_paths(),
        path_target="BumpRef",
        path_targets=["BumpRef"],
    )


def gen_recursion_optional(rng: Random, seed: int, index: int) -> Program:
    depth = rng.choice([0, 1, 2])
    family = "c2_recursion_optional"
    helpers = [
        Helper(
            "RecAdd",
            [ParamSpec("n", "byref"), ParamSpec("depth", "byval", default=2)],
            [
                Assign("frame_depth", Var("depth")),
                # Record per-level local into module slots for observation.
                IfStmt(
                    Cmp("=", Var("depth"), Lit(0)),
                    [Assign("seen_d0", Var("frame_depth"))],
                    [],
                ),
                IfStmt(
                    Cmp("=", Var("depth"), Lit(1)),
                    [Assign("seen_d1", Var("frame_depth"))],
                    [],
                ),
                IfStmt(
                    Cmp("=", Var("depth"), Lit(2)),
                    [Assign("seen_d2", Var("frame_depth"))],
                    [],
                ),
                IfStmt(
                    Cmp("<=", Var("depth"), Lit(0)),
                    [ReturnStmt(Var("n"))],
                    [
                        Assign("n", Bin("+", Var("n"), Lit(1))),
                        ReturnStmt(
                            Bin(
                                "+",
                                Call(
                                    "RecAdd",
                                    [Var("n"), Bin("-", Var("depth"), Lit(1))],
                                ),
                                Var("n"),
                            )
                        ),
                    ],
                ),
            ],
            local_vars={"frame_depth": -1},
        )
    ]
    if depth == 2 and rng.random() < 0.5:
        call_args = [Var("x")]
    else:
        call_args = [Var("x"), Lit(depth)]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "recursion", f"depth={depth}"],
        module_vars={"x": 0, "r": 0, "seen_d0": -9, "seen_d1": -9, "seen_d2": -9},
        helpers=helpers,
        main=[
            Assign("x", Lit(0)),
            Assign("r", Call("RecAdd", call_args)),
            Observe("r", Var("r")),
            Observe("x", Var("x")),
            Observe("seen_d0", Var("seen_d0")),
            Observe("seen_d1", Var("seen_d1")),
            Observe("seen_d2", Var("seen_d2")),
        ],
        required_path=_req_paths(),
        path_target="RecAdd",
        path_targets=["RecAdd"],
    )


def gen_early_exit(rng: Random, seed: int, index: int) -> Program:
    family = "c2_early_exit"
    ret = _safe(rng, 1, 20)
    helpers = [
        Helper(
            "Early",
            [ParamSpec("n", "byref")],
            [ReturnStmt(Lit(ret)), Assign("n", Lit(999)), Note("nope")],
        ),
        Helper(
            "EarlySub",
            [],
            [
                IfStmt(
                    Cmp("=", Lit(1), Lit(1)),
                    [ReturnStmt(Lit(0)), Note("sub_nope")],
                    [],
                ),
                Note("after"),
            ],
            returns=False,
        ),
    ]
    return Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "early"],
        module_vars={"n": 0, "r": 0},
        helpers=helpers,
        main=[
            Assign("n", Lit(1)),
            Assign("r", Call("Early", [Var("n")])),
            Observe("r", Var("r")),
            Observe("n", Var("n")),
            CallStmt("EarlySub", []),
        ],
        required_path=_req_paths(),
        path_target="Early",
        path_targets=["Early", "EarlySub"],
    )


def gen_import_byref(rng: Random, seed: int, index: int) -> Program:
    """Imported module: ByRef mutation+return; distinct lib scalar ``lx``.

    Same-name caller/library cells are modeled in the reference Env and proven
    in selftest (``hand_same_name_module_ns``); VG Import currently shares one
    Dim namespace, so campaign cases use distinct names until engine namespaces
    land.
    """
    from .bundle_integrity import sync_source_modules_from_ir

    x0 = _safe(rng, 1, 10)
    lib_x0 = 7
    family = "c2_import_byref"
    helpers = [
        Helper(
            "LibBump",
            [ParamSpec("n", "byref")],
            [
                Assign("lx", Bin("+", Var("lx"), Lit(1))),
                Assign("n", Bin("+", Var("n"), Lit(2))),
                ReturnStmt(Bin("*", Var("n"), Lit(2))),
            ],
        ),
        Helper("LibPeekX", [], [ReturnStmt(Var("lx"))]),
    ]
    prog = Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "import"],
        module_vars={"x": 0, "r": 0, "lib_x": 0},
        helpers=helpers,
        main=[
            Assign("x", Lit(x0)),
            Assign("r", Call("LibBump", [Var("x")])),
            Assign("lib_x", Call("LibPeekX", [])),
            Observe("r", Var("r")),
            Observe("x", Var("x")),
            Observe("lib_x", Var("lib_x")),
        ],
        required_path=_req_paths(),
        path_target="LibBump",
        path_targets=["LibBump", "LibPeekX"],
        helper_defining_module={
            "LibBump": "c2_lib_bump.vg",
            "LibPeekX": "c2_lib_bump.vg",
        },
        module_stores={"c2_lib_bump.vg": {"lx": lib_x0}},
    )
    sync_source_modules_from_ir(prog)
    return prog


def hand_same_name_module_ns() -> Program:
    """Reference-only: caller ``x`` and library ``x`` are distinct cells."""
    from .bundle_integrity import sync_source_modules_from_ir

    helpers = [
        Helper(
            "LibBump",
            [ParamSpec("n", "byref")],
            [
                Assign("x", Bin("+", Var("x"), Lit(1))),
                Assign("n", Bin("+", Var("n"), Lit(2))),
                ReturnStmt(Bin("*", Var("n"), Lit(2))),
            ],
        ),
        Helper("LibPeekX", [], [ReturnStmt(Var("x"))]),
    ]
    prog = Program(
        case_id="c2_hand_same_name_module_ns",
        seed=0,
        index=0,
        family="c2_hand_same_name_module_ns",
        tags=["c2", "import", "reference_only"],
        module_vars={"x": 0, "r": 0, "lib_x": 0},
        helpers=helpers,
        main=[
            Assign("x", Lit(3)),
            Assign("r", Call("LibBump", [Var("x")])),
            Assign("lib_x", Call("LibPeekX", [])),
            Observe("r", Var("r")),
            Observe("x", Var("x")),
            Observe("lib_x", Var("lib_x")),
        ],
        required_path=_req_paths(),
        path_target="LibBump",
        path_targets=["LibBump", "LibPeekX"],
        helper_defining_module={
            "LibBump": "c2_lib_bump.vg",
            "LibPeekX": "c2_lib_bump.vg",
        },
        module_stores={"c2_lib_bump.vg": {"x": 7}},
    )
    sync_source_modules_from_ir(prog)
    return prog


def gen_import_byval_expr(rng: Random, seed: int, index: int) -> Program:
    """Imported ByVal pure expr; caller scalar unchanged."""
    from .bundle_integrity import sync_source_modules_from_ir

    x0 = _safe(rng, 2, 12)
    family = "c2_import_byval_expr"
    helpers = [
        Helper(
            "LibAddOne",
            [ParamSpec("n", "byval")],
            [ReturnStmt(Bin("+", Var("n"), Lit(1)))],
        )
    ]
    prog = Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "import", "byval"],
        module_vars={"x": 0, "r": 0},
        helpers=helpers,
        main=[
            Assign("x", Lit(x0)),
            Assign("r", Call("LibAddOne", [Var("x")])),
            Observe("r", Var("r")),
            Observe("x", Var("x")),
        ],
        required_path=_req_paths(),
        path_target="LibAddOne",
        path_targets=["LibAddOne"],
        helper_defining_module={"LibAddOne": "c2_lib_add.vg"},
        module_stores={"c2_lib_add.vg": {}},
    )
    sync_source_modules_from_ir(prog)
    return prog


def gen_import_local_caller(rng: Random, seed: int, index: int) -> Program:
    """Local caller location passed into imported ByRef library."""
    from .bundle_integrity import sync_source_modules_from_ir

    x0 = _safe(rng, 3, 14)
    family = "c2_import_local_caller"
    helpers = [
        Helper(
            "LibInc",
            [ParamSpec("n", "byref")],
            [Assign("n", Bin("+", Var("n"), Lit(3))), ReturnStmt(Lit(0))],
            returns=False,
        )
    ]
    prog = Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "import", "local_caller"],
        module_vars={},
        helpers=helpers,
        main=[
            Assign("x", Lit(x0)),
            CallStmt("LibInc", [Var("x")]),
            Observe("x", Var("x")),
        ],
        required_path=_req_paths(),
        path_target="LibInc",
        path_targets=["LibInc"],
        helper_defining_module={"LibInc": "c2_lib_inc.vg"},
        module_stores={"c2_lib_inc.vg": {}},
    )
    sync_source_modules_from_ir(prog)
    return prog


def gen_import_nested(rng: Random, seed: int, index: int) -> Program:
    """Nested distinct-name imports: outer lib calls inner lib."""
    from .bundle_integrity import sync_source_modules_from_ir

    x0 = _safe(rng, 1, 9)
    family = "c2_import_nested"
    helpers = [
        Helper(
            "LibInner",
            [ParamSpec("n", "byval")],
            [ReturnStmt(Bin("*", Var("n"), Lit(2)))],
        ),
        Helper(
            "LibOuter",
            [ParamSpec("n", "byref")],
            [
                Assign("n", Call("LibInner", [Var("n")])),
                ReturnStmt(Var("n")),
            ],
        ),
    ]
    prog = Program(
        case_id=case_id_for(seed, index, family),
        seed=seed,
        index=index,
        family=family,
        tags=["c2", "import", "nested"],
        module_vars={"x": 0, "r": 0},
        helpers=helpers,
        main=[
            Assign("x", Lit(x0)),
            Assign("r", Call("LibOuter", [Var("x")])),
            Observe("r", Var("r")),
            Observe("x", Var("x")),
        ],
        required_path=_req_paths(),
        path_target="LibOuter",
        path_targets=["LibOuter", "LibInner"],
        helper_defining_module={
            "LibOuter": "c2_lib_outer.vg",
            "LibInner": "c2_lib_inner.vg",
        },
        module_stores={"c2_lib_outer.vg": {}, "c2_lib_inner.vg": {}},
    )
    sync_source_modules_from_ir(prog)
    return prog


_GENERATORS = {
    "c2_byval_standalone": gen_byval_standalone,
    "c2_byval_expr": gen_byval_expr,
    "c2_byref_standalone": gen_byref_standalone,
    "c2_byref_expr": gen_byref_expr,
    "c2_two_distinct": gen_two_distinct,
    "c2_nested_effects": gen_nested_effects,
    "c2_module_local_shadow": gen_module_local_shadow,
    "c2_local_caller": gen_local_caller,
    "c2_recursion_optional": gen_recursion_optional,
    "c2_early_exit": gen_early_exit,
    "c2_import_byref": gen_import_byref,
    "c2_import_byval_expr": gen_import_byval_expr,
    "c2_import_local_caller": gen_import_local_caller,
    "c2_import_nested": gen_import_nested,
}


def generate_c2_case(seed: int, index: int, family: str | None = None) -> Program:
    rng = Random((seed << 16) ^ (index * 2654435761) ^ 0xC2C2)
    fam = family or C2_FAMILIES[index % len(C2_FAMILIES)]
    if family is None:
        order = list(C2_FAMILIES)
        rng.shuffle(order)
        fam = order[index % len(order)]
    prog = _GENERATORS[fam](rng, seed, index)
    if getattr(prog, "helper_defining_module", None):
        from .bundle_integrity import sync_source_modules_from_ir

        sync_source_modules_from_ir(prog)
    evaluate_program(prog)
    return prog


def generate_c2_batch(seed: int, count: int) -> List[Program]:
    if count < 1:
        raise ValueError("empty c2 batch refused")
    out: List[Program] = []
    seen = set()
    from .generator import structural_fingerprint

    i = 0
    for fam in C2_FAMILIES:
        if len(out) >= count:
            break
        prog = generate_c2_case(seed, i, family=fam)
        i += 1
        fp = structural_fingerprint(prog)
        if fp not in seen:
            seen.add(fp)
            out.append(prog)
    guard = 0
    while len(out) < count and guard < count * 20:
        guard += 1
        prog = generate_c2_case(seed, i)
        i += 1
        fp = structural_fingerprint(prog)
        if fp in seen:
            continue
        seen.add(fp)
        out.append(prog)
    if len(out) < count:
        raise RuntimeError(f"c2 generator could not produce {count} distinct cases")
    return out


def feature_pairs(prog: Program) -> List[str]:
    """Pairs tied to the same executed call edge (not independent flags)."""
    pairs: set[str] = set()
    from .ir import Call, CallStmt, Assign, IfStmt, ReturnStmt, normalize_helper_params

    helpers = {h.name: h for h in prog.helpers}
    has_import = bool(getattr(prog, "source_modules", None))
    has_local_helper = any(h.local_vars for h in prog.helpers)
    has_module_caller = bool(prog.module_vars)
    has_recursion = False
    has_optional = any(
        p.default is not None
        for h in prog.helpers
        for p in normalize_helper_params(list(h.params))
    )

    def edge(name: str, *, as_expr: bool) -> None:
        nonlocal has_recursion
        h = helpers.get(name)
        if not h:
            return
        specs = normalize_helper_params(list(h.params))
        modes = {s.mode for s in specs}
        form = "expression" if as_expr else "statement"
        if "byref" in modes:
            pairs.add(f"byref×{form}")
        if "byval" in modes or (not specs and as_expr):
            if specs and any(s.mode == "byval" for s in specs):
                pairs.add(f"byval×{form}")
        if name == "RecAdd" or (
            as_expr
            and any(
                isinstance(st, ReturnStmt)
                and isinstance(getattr(st, "expr", None), Call)
                and st.expr.name == name
                for st in h.body
            )
        ):
            has_recursion = True
        if getattr(prog, "helper_defining_module", {}).get(name):
            pairs.add("module×imported")
        else:
            pairs.add("module×same_file")

    def walk(body, *, nested: bool):
        for st in body:
            if isinstance(st, CallStmt):
                edge(st.name, as_expr=False)
                if nested:
                    pairs.add("call×nested")
                else:
                    pairs.add("call×direct")
            elif isinstance(st, Assign) and isinstance(st.expr, Call):
                edge(st.expr.name, as_expr=True)
                pairs.add("call×direct" if not nested else "call×nested")
            elif isinstance(st, ReturnStmt) and isinstance(st.expr, Call):
                edge(st.expr.name, as_expr=True)
                pairs.add("call×nested")
            elif isinstance(st, IfStmt):
                walk(st.then_body, nested=nested)
                walk(st.else_body, nested=nested)

    for h in prog.helpers:
        walk(h.body, nested=True)
    walk(prog.main, nested=False)

    if has_module_caller:
        pairs.add("storage×module")
    if has_local_helper or any(
        isinstance(st, Assign) and st.name not in prog.module_vars for st in prog.main
    ):
        # local caller: assigns before call without module_vars entry
        if not prog.module_vars or has_local_helper:
            pairs.add("storage×local")
    if has_optional:
        pairs.add("param×optional_default")
    if has_recursion:
        pairs.add("control×recursion")
    if has_import:
        pairs.add("module×imported")
    else:
        pairs.add("module×same_file")
    return sorted(pairs)


def covered_pairs(programs: List[Program]) -> List[str]:
    pairs: set[str] = set()
    for p in programs:
        pairs.update(feature_pairs(p))
    return sorted(pairs)
