"""Typed intermediate representation for Phase 1 semantic programs."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Literal, Optional, Union
import json

BinOp = Literal["+", "-", "*", "\\", "Mod"]
CmpOp = Literal["=", "<>", "<", "<=", ">", ">="]


@dataclass
class Lit:
    value: int = 0
    type: Literal["Integer"] = "Integer"
    kind: Literal["lit"] = field(default="lit", init=False)


@dataclass
class Var:
    name: str
    kind: Literal["var"] = field(default="var", init=False)


@dataclass
class Bin:
    op: BinOp
    left: "Expr"
    right: "Expr"
    kind: Literal["bin"] = field(default="bin", init=False)


@dataclass
class Cmp:
    op: CmpOp
    left: "Expr"
    right: "Expr"
    kind: Literal["cmp"] = field(default="cmp", init=False)


@dataclass
class Call:
    name: str
    args: list["Expr"] = field(default_factory=list)
    kind: Literal["call"] = field(default="call", init=False)


Expr = Union[Lit, Var, Bin, Cmp, Call]


@dataclass
class Assign:
    name: str
    expr: Expr
    kind: Literal["assign"] = field(default="assign", init=False)


@dataclass
class IfStmt:
    cond: Expr
    then_body: list["Stmt"] = field(default_factory=list)
    else_body: list["Stmt"] = field(default_factory=list)
    kind: Literal["if"] = field(default="if", init=False)


@dataclass
class ForStmt:
    var: str
    lo: Expr
    hi: Expr
    body: list["Stmt"] = field(default_factory=list)
    kind: Literal["for"] = field(default="for", init=False)


@dataclass
class SelectCase:
    values: list[int] = field(default_factory=list)
    body: list["Stmt"] = field(default_factory=list)


@dataclass
class SelectStmt:
    selector: Expr
    cases: list[SelectCase] = field(default_factory=list)
    else_body: list["Stmt"] = field(default_factory=list)
    kind: Literal["select"] = field(default="select", init=False)


@dataclass
class CallStmt:
    name: str
    args: list[Expr] = field(default_factory=list)
    kind: Literal["call"] = field(default="call", init=False)


@dataclass
class Observe:
    name: str
    expr: Expr
    kind: Literal["observe"] = field(default="observe", init=False)


@dataclass
class ReturnStmt:
    expr: Expr
    kind: Literal["return"] = field(default="return", init=False)


@dataclass
class Note:
    """Ordered event observation (String), for nested call order contracts."""

    label: str
    kind: Literal["note"] = field(default="note", init=False)


Stmt = Union[Assign, IfStmt, ForStmt, SelectStmt, CallStmt, Observe, ReturnStmt, Note]


@dataclass(frozen=True)
class ParamSpec:
    """Integer parameter. Phase 1 string params deserialize as ByVal."""

    name: str
    mode: Literal["byval", "byref"] = "byval"
    default: Optional[int] = None


@dataclass
class Helper:
    name: str
    # Compat: list[str] or list[ParamSpec]; normalize via normalize_helper_params.
    params: list = field(default_factory=list)
    body: list[Stmt] = field(default_factory=list)
    returns: bool = True
    side_effect_global: Optional[str] = None
    # Frame-local Integer slots (Dim inside Sub/Function), distinct from module_vars.
    local_vars: dict[str, int] = field(default_factory=dict)


def normalize_helper_params(params: list) -> list[ParamSpec]:
    out: list[ParamSpec] = []
    for p in params:
        if isinstance(p, ParamSpec):
            out.append(p)
        elif isinstance(p, str):
            out.append(ParamSpec(name=p, mode="byval"))
        elif isinstance(p, dict):
            out.append(
                ParamSpec(
                    name=str(p["name"]),
                    mode=p.get("mode", "byval"),
                    default=p.get("default"),
                )
            )
        else:
            raise ValueError(f"bad param {p!r}")
    return out


@dataclass
class Program:
    """One generated semantic case."""

    case_id: str
    seed: int
    index: int
    family: str
    tags: list[str] = field(default_factory=list)
    module_vars: dict[str, int] = field(default_factory=dict)
    helpers: list[Helper] = field(default_factory=list)
    main: list[Stmt] = field(default_factory=list)
    required_path: dict[str, str] = field(default_factory=dict)
    # Function whose execution path must match required_path[mode].
    # Never accept a sibling function's path as coverage for this target.
    path_target: str = "SemMain"
    # Additional callee/caller names that must share path_module coverage.
    path_targets: list[str] = field(default_factory=list)
    # Logical stable module key (source-relative), e.g. sem_fuzz_ir/<case>/<mode>.
    # Compared across runs/replay; independent of physical staging root.
    path_module_key: Optional[str] = None
    # Physical res://… module for THIS bound run only (set on a Program copy).
    # VG_SEM_PATH mod= must match this exact string when set.
    path_module: Optional[str] = None
    fallback_contract: Optional[str] = None
    notes: str = ""
    # Extra UTF-8 sources staged beside the primary emit (Import "rel").
    # Each entry: {"rel_path": "lib.vg", "content": "..."}.
    source_modules: list = field(default_factory=list)
    # helper name -> defining source rel_path (omit/None => primary case.vg).
    helper_defining_module: dict[str, str] = field(default_factory=dict)
    # Module-owned Integer namespaces: "" = primary; else imported rel_path.
    module_stores: dict = field(default_factory=dict)


def _expr_from(d: Any) -> Expr:
    if not isinstance(d, dict):
        raise ValueError(f"bad expr: {d!r}")
    k = d.get("kind")
    if k == "lit":
        # Do not coerce via int(); validate_program rejects non-plain Integers.
        return Lit(value=d["value"])
    if k == "var":
        return Var(name=str(d["name"]))
    if k == "bin":
        return Bin(op=d["op"], left=_expr_from(d["left"]), right=_expr_from(d["right"]))
    if k == "cmp":
        return Cmp(op=d["op"], left=_expr_from(d["left"]), right=_expr_from(d["right"]))
    if k == "call":
        return Call(name=str(d["name"]), args=[_expr_from(a) for a in d.get("args", [])])
    raise ValueError(f"unknown expr kind {k}")


def _stmt_from(d: Any) -> Stmt:
    if not isinstance(d, dict):
        raise ValueError(f"bad stmt: {d!r}")
    if d.get("kind") == "note":
        return Note(label=str(d["label"]))
    # fall through — existing handlers below expect kind checks
    return _stmt_from_legacy(d)


def _stmt_from_legacy(d: Any) -> Stmt:
    k = d.get("kind")
    if k == "assign":
        return Assign(name=str(d["name"]), expr=_expr_from(d["expr"]))
    if k == "if":
        return IfStmt(
            cond=_expr_from(d["cond"]),
            then_body=[_stmt_from(s) for s in d.get("then_body", [])],
            else_body=[_stmt_from(s) for s in d.get("else_body", [])],
        )
    if k == "for":
        return ForStmt(
            var=str(d["var"]),
            lo=_expr_from(d["lo"]),
            hi=_expr_from(d["hi"]),
            body=[_stmt_from(s) for s in d.get("body", [])],
        )
    if k == "select":
        cases = [
            SelectCase(values=[int(v) for v in c["values"]], body=[_stmt_from(s) for s in c.get("body", [])])
            for c in d.get("cases", [])
        ]
        return SelectStmt(
            selector=_expr_from(d["selector"]),
            cases=cases,
            else_body=[_stmt_from(s) for s in d.get("else_body", [])],
        )
    if k == "call":
        return CallStmt(name=str(d["name"]), args=[_expr_from(a) for a in d.get("args", [])])
    if k == "observe":
        return Observe(name=str(d["name"]), expr=_expr_from(d["expr"]))
    if k == "return":
        return ReturnStmt(expr=_expr_from(d["expr"]))
    raise ValueError(f"unknown stmt kind {k}")


def program_to_dict(p: Program) -> dict[str, Any]:
    return asdict(p)


def program_from_dict(d: dict[str, Any]) -> Program:
    helpers = []
    for h in d.get("helpers", []):
        loc_raw = h.get("local_vars") or {}
        local_vars = {str(k): v for k, v in dict(loc_raw).items()}
        from .validate import require_bool

        if "returns" not in h:
            returns = True
        else:
            returns = require_bool(h["returns"], f"helper {h['name']}.returns")
        helpers.append(
            Helper(
                name=h["name"],
                params=normalize_helper_params(list(h.get("params", []))),
                body=[_stmt_from(s) for s in h.get("body", [])],
                returns=returns,
                side_effect_global=h.get("side_effect_global"),
                local_vars=local_vars,
            )
        )
    prog = Program(
        case_id=str(d["case_id"]),
        seed=int(d["seed"]),
        index=int(d["index"]),
        family=str(d["family"]),
        tags=list(d.get("tags", [])),
        module_vars={str(k): v for k, v in d.get("module_vars", {}).items()},
        helpers=helpers,
        main=[_stmt_from(s) for s in d.get("main", [])],
        required_path=dict(d.get("required_path", {})),
        path_target=str(d.get("path_target", "SemMain")),
        path_targets=list(d.get("path_targets", [])),
        path_module_key=d.get("path_module_key"),
        path_module=d.get("path_module"),
        fallback_contract=d.get("fallback_contract"),
        notes=str(d.get("notes", "")),
        source_modules=list(d.get("source_modules", [])),
        helper_defining_module={
            str(k): str(v) for k, v in dict(d.get("helper_defining_module") or {}).items()
        },
        module_stores={
            str(mk): {str(n): v for n, v in dict(mv).items()}
            for mk, mv in dict(d.get("module_stores") or {}).items()
        },
    )
    from .validate import validate_program

    validate_program(prog)
    return prog


def dumps_program(p: Program) -> str:
    return json.dumps(program_to_dict(p), indent=2, sort_keys=True)


def loads_program(text: str) -> Program:
    return program_from_dict(json.loads(text))
