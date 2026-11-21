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


@dataclass
class ArrGet:
    """Fixed-size Integer array read at a literal index (C3)."""

    name: str
    index: int
    kind: Literal["arr_get"] = field(default="arr_get", init=False)


@dataclass
class ArrSet:
    """Fixed-size Integer array write at a literal index (C3)."""

    name: str
    index: int
    expr: "Expr"
    kind: Literal["arr_set"] = field(default="arr_set", init=False)


@dataclass
class DictGet:
    """Present-key Dictionary Integer read (C3). Missing keys use DictMissCheck."""

    name: str
    key: str
    kind: Literal["dict_get"] = field(default="dict_get", init=False)


@dataclass
class DictCount:
    """Dictionary.Count() as Integer (C3)."""

    name: str
    kind: Literal["dict_count"] = field(default="dict_count", init=False)


@dataclass
class DictExists:
    """Dictionary.Exists(key) as Integer 1/0 (C3; Boolean coerced for obs)."""

    name: str
    key: str
    kind: Literal["dict_exists"] = field(default="dict_exists", init=False)


@dataclass
class DictSet:
    """Dictionary present-key write / insert of Integer (C3)."""

    name: str
    key: str
    expr: "Expr"
    kind: Literal["dict_set"] = field(default="dict_set", init=False)


@dataclass
class DictMissCheck:
    """Missing-key probe: VarType=1, Is Nothing→1, Err.Number=0 (R12; C3)."""

    name: str
    key: str
    prefix: str
    kind: Literal["dict_miss_check"] = field(default="dict_miss_check", init=False)


@dataclass
class NestedSlotGet:
    """Read Integer slot from an Array stored at a Dictionary key (C3b)."""

    name: str
    key: str
    index: int
    kind: Literal["nested_slot_get"] = field(default="nested_slot_get", init=False)


@dataclass
class NestedSlotSet:
    """Write Integer slot through Dictionary→Array (C3b; shared inner)."""

    name: str
    key: str
    index: int
    expr: "Expr"
    kind: Literal["nested_slot_set"] = field(default="nested_slot_set", init=False)


@dataclass
class UdtFieldGet:
    """Read Integer field from a module UDT variable (C3b)."""

    var: str
    field: str
    kind: Literal["udt_field_get"] = field(default="udt_field_get", init=False)


@dataclass
class UdtFieldSet:
    """Write Integer field on a module UDT variable (C3b)."""

    var: str
    field: str
    expr: "Expr"
    kind: Literal["udt_field_set"] = field(default="udt_field_set", init=False)


@dataclass
class UdtCopy:
    """Value-copy one module UDT variable into another (C3b / VB6)."""

    dest: str
    src: str
    kind: Literal["udt_copy"] = field(default="udt_copy", init=False)


LogicOp = Literal["AndAlso", "OrElse"]


@dataclass
class LogicBin:
    """Short-circuit AndAlso / OrElse over Integer 0/1 operands (C4).

    And/Or (non-short-circuit) are intentionally excluded from the generated
    family while their both-sides evaluation remains a fixture OBSERVED
    contract question.
    """

    op: LogicOp
    left: "Expr"
    right: "Expr"
    kind: Literal["logic_bin"] = field(default="logic_bin", init=False)


@dataclass
class LogicNot:
    """Logical Not over an Integer 0/1 operand (C4)."""

    expr: "Expr"
    kind: Literal["logic_not"] = field(default="logic_not", init=False)


Expr = Union[
    Lit,
    Var,
    Bin,
    Cmp,
    Call,
    ArrGet,
    DictGet,
    DictCount,
    DictExists,
    NestedSlotGet,
    UdtFieldGet,
    LogicBin,
    LogicNot,
]
Stmt = Union[
    Assign,
    IfStmt,
    ForStmt,
    SelectStmt,
    CallStmt,
    Observe,
    ReturnStmt,
    Note,
    ArrSet,
    DictSet,
    DictMissCheck,
    NestedSlotSet,
    UdtFieldSet,
    UdtCopy,
]


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
    # C3 fixed-size Integer arrays: name → slot list (Dim a(UBound) with len = UBound+1).
    module_arrays: dict = field(default_factory=dict)
    # C3 Dictionary present Integer keys only (missing → DictMissCheck / R12).
    # C3b: values may also be list[int] (Array nested under a key).
    module_dicts: dict = field(default_factory=dict)
    # C3b Integer-field UDT variables: name → {field: int}.
    module_udts: dict = field(default_factory=dict)


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
    if k == "arr_get":
        return ArrGet(name=str(d["name"]), index=int(d["index"]))
    if k == "dict_get":
        return DictGet(name=str(d["name"]), key=str(d["key"]))
    if k == "dict_count":
        return DictCount(name=str(d["name"]))
    if k == "dict_exists":
        return DictExists(name=str(d["name"]), key=str(d["key"]))
    if k == "nested_slot_get":
        return NestedSlotGet(
            name=str(d["name"]), key=str(d["key"]), index=int(d["index"])
        )
    if k == "udt_field_get":
        return UdtFieldGet(var=str(d["var"]), field=str(d["field"]))
    if k == "logic_bin":
        return LogicBin(
            op=d["op"],
            left=_expr_from(d["left"]),
            right=_expr_from(d["right"]),
        )
    if k == "logic_not":
        return LogicNot(expr=_expr_from(d["expr"]))
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
    if k == "arr_set":
        return ArrSet(name=str(d["name"]), index=int(d["index"]), expr=_expr_from(d["expr"]))
    if k == "dict_set":
        return DictSet(name=str(d["name"]), key=str(d["key"]), expr=_expr_from(d["expr"]))
    if k == "dict_miss_check":
        return DictMissCheck(
            name=str(d["name"]), key=str(d["key"]), prefix=str(d["prefix"])
        )
    if k == "nested_slot_set":
        return NestedSlotSet(
            name=str(d["name"]),
            key=str(d["key"]),
            index=int(d["index"]),
            expr=_expr_from(d["expr"]),
        )
    if k == "udt_field_set":
        return UdtFieldSet(
            var=str(d["var"]), field=str(d["field"]), expr=_expr_from(d["expr"])
        )
    if k == "udt_copy":
        return UdtCopy(dest=str(d["dest"]), src=str(d["src"]))
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
        module_arrays={
            str(n): [int(x) for x in list(slots)]
            for n, slots in dict(d.get("module_arrays") or {}).items()
        },
        module_dicts={
            str(n): {
                str(k): ([int(x) for x in list(v)] if isinstance(v, list) else int(v))
                for k, v in dict(entries).items()
            }
            for n, entries in dict(d.get("module_dicts") or {}).items()
        },
        module_udts={
            str(n): {str(f): int(v) for f, v in dict(fields).items()}
            for n, fields in dict(d.get("module_udts") or {}).items()
        },
    )
    from .validate import validate_program

    validate_program(prog)
    return prog


def dumps_program(p: Program) -> str:
    return json.dumps(program_to_dict(p), indent=2, sort_keys=True)


def loads_program(text: str) -> Program:
    return program_from_dict(json.loads(text))
