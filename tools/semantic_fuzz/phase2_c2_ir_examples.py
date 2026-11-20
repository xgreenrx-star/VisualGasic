"""Hand-derived C2 scalar call IR examples + independent expected observations."""

from __future__ import annotations

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
def _prog(case_id: str, helpers, main, module_vars=None, **kw) -> Program:
    # path_module_key/path_module bound per mode on a Program copy inside run_program.
    return Program(
        case_id=case_id,
        seed=0,
        index=0,
        family="c2_hand",
        tags=["c2_hand", "integer_calls"],
        module_vars=module_vars or {},
        helpers=helpers,
        main=main,
        required_path={
            "forced_ast": "ast",
            "interpreter": "bytecode",
            "default": "bytecode_or_native",
            "tier3": "bytecode_or_native",
        },
        path_target=kw.get("path_target", "SemMain"),
        path_targets=list(kw.get("path_targets", [])),
        path_module_key=kw.get("path_module_key"),
        path_module=None,
        notes=kw.get("notes", ""),
    )


def example_byval_byref() -> tuple[Program, list[dict]]:
    """1. ByVal unchanged caller; ByRef mutates."""
    helpers = [
        Helper(
            "BumpVal",
            [ParamSpec("n", "byval")],
            [Assign("n", Bin("+", Var("n"), Lit(1))), ReturnStmt(Lit(0))],
            returns=False,
        ),
        Helper(
            "BumpRef",
            [ParamSpec("n", "byref")],
            [Assign("n", Bin("+", Var("n"), Lit(1))), ReturnStmt(Lit(0))],
            returns=False,
        ),
    ]
    main = [
        Assign("x", Lit(3)),
        CallStmt("BumpVal", [Var("x")]),
        Observe("after_byval", Var("x")),
        CallStmt("BumpRef", [Var("x")]),
        Observe("after_byref", Var("x")),
    ]
    expected = [
        {"name": "after_byval", "type": "Integer", "value": "3", "kind": "value"},
        {"name": "after_byref", "type": "Integer", "value": "4", "kind": "value"},
    ]
    return (
        _prog(
            "c2_byval_byref",
            helpers,
            main,
            {"x": 0},
            path_target="BumpRef",
            path_targets=["BumpVal", "BumpRef"],
        ),
        expected,
    )


def example_expr_byref() -> tuple[Program, list[dict]]:
    """2. Expression return AND writeback: 3 → r=10, x=5."""
    helpers = [
        Helper(
            "ExprByRef",
            [ParamSpec("x", "byref")],
            [
                Assign("x", Bin("+", Var("x"), Lit(2))),
                ReturnStmt(Bin("*", Var("x"), Lit(2))),
            ],
        ),
    ]
    main = [
        Assign("x", Lit(3)),
        Assign("r", Call("ExprByRef", [Var("x")])),
        Observe("expr_r", Var("r")),
        Observe("expr_x", Var("x")),
    ]
    expected = [
        {"name": "expr_r", "type": "Integer", "value": "10", "kind": "value"},
        {"name": "expr_x", "type": "Integer", "value": "5", "kind": "value"},
    ]
    return _prog("c2_expr_byref", helpers, main, {"x": 0, "r": 0}, path_target="ExprByRef"), expected


def example_two_distinct() -> tuple[Program, list[dict]]:
    """3. Distinct two-arg writes; equal values in different locations."""
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
        ),
    ]
    main = [
        Assign("x", Lit(5)),
        Assign("y", Lit(3)),
        CallStmt("Two", [Var("x"), Var("y")]),
        Observe("two_x", Var("x")),
        Observe("two_y", Var("y")),
        Assign("p", Lit(7)),
        Assign("q", Lit(7)),
        CallStmt("Two", [Var("p"), Var("q")]),
        Observe("eq_p", Var("p")),
        Observe("eq_q", Var("q")),
    ]
    expected = [
        {"name": "two_x", "type": "Integer", "value": "6", "kind": "value"},
        {"name": "two_y", "type": "Integer", "value": "13", "kind": "value"},
        {"name": "eq_p", "type": "Integer", "value": "8", "kind": "value"},
        {"name": "eq_q", "type": "Integer", "value": "17", "kind": "value"},
    ]
    return _prog("c2_two_distinct", helpers, main, {"x": 0, "y": 0, "p": 0, "q": 0}, path_target="Two"), expected


def example_nested_events() -> tuple[Program, list[dict]]:
    """4. Nested ordered effects + frame-local shadowing of module name."""
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
    main = [
        Assign("x", Lit(0)),
        CallStmt("Outer", [Var("x")]),
        Observe("nested_x", Var("x")),
    ]
    expected = [
        {"name": "event_outer_enter", "type": "String", "value": "outer_enter", "kind": "value"},
        {"name": "event_inner", "type": "String", "value": "inner", "kind": "value"},
        {"name": "event_outer_exit", "type": "String", "value": "outer_exit", "kind": "value"},
        {"name": "nested_x", "type": "Integer", "value": "111", "kind": "value"},
    ]
    return (
        _prog(
            "c2_nested",
            helpers,
            main,
            {"x": 0},
            path_target="Outer",
            path_targets=["Outer", "Inner"],
        ),
        expected,
    )


def example_recursion() -> tuple[Program, list[dict]]:
    """5. Recursion depth 0/1/2 with Optional default + per-level local."""
    helpers = [
        Helper(
            "RecAdd",
            [ParamSpec("n", "byref"), ParamSpec("depth", "byval", default=2)],
            [
                # Per-level local: records depth at this frame; restored on return.
                Assign("frame_depth", Var("depth")),
                IfStmt(
                    Cmp("<=", Var("depth"), Lit(0)),
                    [ReturnStmt(Var("n"))],
                    [
                        Assign("n", Bin("+", Var("n"), Lit(1))),
                        ReturnStmt(
                            Bin(
                                "+",
                                Call("RecAdd", [Var("n"), Bin("-", Var("depth"), Lit(1))]),
                                Var("n"),
                            )
                        ),
                    ],
                ),
            ],
            local_vars={"frame_depth": -1},
        )
    ]
    main = [
        Assign("x0", Lit(0)),
        Assign("r0", Call("RecAdd", [Var("x0"), Lit(0)])),
        Observe("rec0_r", Var("r0")),
        Observe("rec0_x", Var("x0")),
        Assign("x1", Lit(0)),
        Assign("r1", Call("RecAdd", [Var("x1"), Lit(1)])),
        Observe("rec1_r", Var("r1")),
        Observe("rec1_x", Var("x1")),
        Assign("x2", Lit(0)),
        Assign("r2", Call("RecAdd", [Var("x2")])),
        Observe("rec2_r", Var("r2")),
        Observe("rec2_x", Var("x2")),
    ]
    expected = [
        {"name": "rec0_r", "type": "Integer", "value": "0", "kind": "value"},
        {"name": "rec0_x", "type": "Integer", "value": "0", "kind": "value"},
        {"name": "rec1_r", "type": "Integer", "value": "2", "kind": "value"},
        {"name": "rec1_x", "type": "Integer", "value": "1", "kind": "value"},
        {"name": "rec2_r", "type": "Integer", "value": "6", "kind": "value"},
        {"name": "rec2_x", "type": "Integer", "value": "2", "kind": "value"},
    ]
    return (
        _prog(
            "c2_rec",
            helpers,
            main,
            {"x0": 0, "r0": 0, "x1": 0, "r1": 0, "x2": 0, "r2": 0},
            path_target="RecAdd",
        ),
        expected,
    )


def example_module_vs_local() -> tuple[Program, list[dict]]:
    """6. Real local shadowing same identifier as module scalar."""
    helpers = [
        Helper(
            "Shadow",
            [],
            [
                # local_vars provides Dim x — assigns hit the local, not module.
                Assign("x", Lit(100)),
                ReturnStmt(Var("x")),
            ],
            returns=True,
            local_vars={"x": 0},
        ),
        Helper(
            "TouchMod",
            [],
            [
                # No local x → Assign resolves to module x.
                Assign("x", Bin("+", Var("x"), Lit(10))),
                ReturnStmt(Lit(0)),
            ],
            returns=False,
        ),
    ]
    main = [
        Assign("x", Lit(1)),
        Assign("r", Call("Shadow", [])),
        Observe("shadow_r", Var("r")),
        Observe("shadow_mod_x", Var("x")),
        CallStmt("TouchMod", []),
        Observe("after_touch_mod", Var("x")),
    ]
    expected = [
        {"name": "shadow_r", "type": "Integer", "value": "100", "kind": "value"},
        {"name": "shadow_mod_x", "type": "Integer", "value": "1", "kind": "value"},
        {"name": "after_touch_mod", "type": "Integer", "value": "11", "kind": "value"},
    ]
    return (
        _prog(
            "c2_mod_local",
            helpers,
            main,
            {"x": 0, "r": 0},
            path_target="Shadow",
            path_targets=["Shadow", "TouchMod"],
        ),
        expected,
    )


def example_early_return() -> tuple[Program, list[dict]]:
    """7. Early Function return + early Exit Sub (nested If) before sentinels."""
    helpers = [
        Helper(
            "Early",
            [ParamSpec("n", "byref")],
            [
                ReturnStmt(Lit(7)),
                Assign("n", Lit(999)),
                Note("should_not_fire"),
            ],
        ),
        Helper(
            "EarlySub",
            [ParamSpec("flag", "byref")],
            [
                IfStmt(
                    Cmp("=", Var("flag"), Lit(1)),
                    [ReturnStmt(Lit(0)), Note("sub_should_not_fire")],
                    [Note("sub_else")],
                ),
                Note("sub_after_if"),
            ],
            returns=False,
        ),
    ]
    main = [
        Assign("n", Lit(1)),
        Assign("r", Call("Early", [Var("n")])),
        Observe("early_r", Var("r")),
        Observe("early_n", Var("n")),
        Assign("flag", Lit(1)),
        CallStmt("EarlySub", [Var("flag")]),
        Observe("flag_after", Var("flag")),
    ]
    expected = [
        {"name": "early_r", "type": "Integer", "value": "7", "kind": "value"},
        {"name": "early_n", "type": "Integer", "value": "1", "kind": "value"},
        {"name": "flag_after", "type": "Integer", "value": "1", "kind": "value"},
    ]
    return (
        _prog(
            "c2_early",
            helpers,
            main,
            {"n": 0, "r": 0, "flag": 0},
            path_target="Early",
            path_targets=["Early", "EarlySub"],
        ),
        expected,
    )


def example_byval_once() -> tuple[Program, list[dict]]:
    """8. Once-only ByVal argument evaluation (oracle hits=1)."""
    helpers = [
        Helper(
            "Side",
            [],
            [
                Assign("hits", Bin("+", Var("hits"), Lit(1))),
                ReturnStmt(Lit(3)),
            ],
        ),
        Helper(
            "TakeVal",
            [ParamSpec("v", "byval")],
            [ReturnStmt(Bin("+", Var("v"), Lit(1)))],
        ),
    ]
    main = [
        Assign("hits", Lit(0)),
        Assign("r", Call("TakeVal", [Call("Side", [])])),
        Observe("byval_r", Var("r")),
        Observe("byval_hits", Var("hits")),
    ]
    expected = [
        {"name": "byval_r", "type": "Integer", "value": "4", "kind": "value"},
        {"name": "byval_hits", "type": "Integer", "value": "1", "kind": "value"},
    ]
    return (
        _prog(
            "c2_byval_once",
            helpers,
            main,
            {"hits": 0, "r": 0},
            path_target="TakeVal",
            path_targets=["TakeVal", "Side"],
            notes="forced_ast known defect: hits=2; see known_defects/",
        ),
        expected,
    )


ALL_EXAMPLES = [
    example_byval_byref,
    example_expr_byref,
    example_two_distinct,
    example_nested_events,
    example_recursion,
    example_module_vs_local,
    example_early_return,
    example_byval_once,
]

# Documented forced_ast known-actual for c2_byval_once (oracle remains hits=1).
BYVAL_ONCE_AST_KNOWN_ACTUAL = [
    {"name": "byval_r", "type": "Integer", "value": "4", "kind": "value"},
    {"name": "byval_hits", "type": "Integer", "value": "2", "kind": "value"},
]
