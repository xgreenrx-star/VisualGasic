"""Independent Phase 1 / C2 scalar reference model (not a port of the VG evaluator)."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional

from . import REFERENCE_VERSION, SAFE_ABS_MAX
from .ir import (
    ArrGet,
    ArrSet,
    Assign,
    Bin,
    Call,
    CallStmt,
    Cmp,
    DictCount,
    DictExists,
    DictGet,
    DictMissCheck,
    DictSet,
    NestedSlotGet,
    NestedSlotSet,
    LogicBin,
    LogicNot,
    UdtCopy,
    UdtFieldGet,
    UdtFieldSet,
    Expr,
    ForStmt,
    Helper,
    IfStmt,
    Lit,
    Note,
    Observe,
    ParamSpec,
    Program,
    ReturnStmt,
    SelectStmt,
    Stmt,
    Var,
    normalize_helper_params,
)


class ReferenceError(Exception):
    """Domain or contract violation in the reference model."""


@dataclass
class TypedValue:
    type: str  # "Integer" | "Boolean" | "String"
    value: Any

    def as_obs(self) -> dict[str, str]:
        if self.type == "String":
            return {"type": "String", "value": str(self.value)}
        return {"type": self.type, "value": str(int(self.value))}


@dataclass
class Observation:
    name: str
    typed: TypedValue

    def to_dict(self) -> dict[str, Any]:
        d = self.typed.as_obs()
        d["name"] = self.name
        d["kind"] = "value"
        return d


@dataclass
class RefResult:
    observations: list[Observation] = field(default_factory=list)
    module_vars: dict[str, int] = field(default_factory=dict)
    reference_version: int = REFERENCE_VERSION


def _check_safe(n: int, ctx: str) -> int:
    if not isinstance(n, int) or isinstance(n, bool):
        raise ReferenceError(f"non-Integer in {ctx}: {n!r}")
    if abs(n) > SAFE_ABS_MAX:
        raise ReferenceError(f"overflow outside safe range in {ctx}: {n}")
    return n


def idiv(a: int, b: int) -> int:
    if b == 0:
        raise ReferenceError("division by zero")
    q = int(a / b)
    return _check_safe(q, "\\")


def imod(a: int, b: int) -> int:
    if b == 0:
        raise ReferenceError("mod by zero")
    return _check_safe(a - idiv(a, b) * b, "Mod")


def ibin(op: str, left: int, right: int) -> int:
    if op == "+":
        return _check_safe(left + right, "+")
    if op == "-":
        return _check_safe(left - right, "-")
    if op == "*":
        return _check_safe(left * right, "*")
    if op == "\\":
        return idiv(left, right)
    if op == "Mod":
        return imod(left, right)
    raise ReferenceError(f"unsupported binop {op}")


def icmp(op: str, left: int, right: int) -> bool:
    if op == "=":
        return left == right
    if op == "<>":
        return left != right
    if op == "<":
        return left < right
    if op == "<=":
        return left <= right
    if op == ">":
        return left > right
    if op == ">=":
        return left >= right
    raise ReferenceError(f"unsupported cmp {op}")


@dataclass
class Env:
    module_stores: dict[str, dict[str, int]]
    current_module: str = ""
    locals: dict[str, int] = field(default_factory=dict)
    helpers: dict[str, Helper] = field(default_factory=dict)
    helper_defining_module: dict[str, str] = field(default_factory=dict)
    observations: list[Observation] = field(default_factory=list)
    depth: int = 0
    steps: int = 0
    # ByRef writebacks for the current frame: (local_name, caller_env, caller_name)
    writebacks: list[tuple[str, "Env", str]] = field(default_factory=list)
    # C3 collection stores (shared across frames; primary module only in this slice).
    arrays: dict[str, list[int]] = field(default_factory=dict)
    # Values: int or list[int] (nested Array under a Dictionary key).
    dicts: dict[str, dict[str, Any]] = field(default_factory=dict)
    udts: dict[str, dict[str, int]] = field(default_factory=dict)

    @property
    def module(self) -> dict[str, int]:
        return self.module_stores.setdefault(self.current_module, {})

    def get(self, name: str) -> int:
        if name in self.locals:
            return self.locals[name]
        store = self.module
        if name in store:
            return store[name]
        raise ReferenceError(f"undefined variable {name} in module {self.current_module!r}")

    def set(self, name: str, value: int) -> None:
        value = _check_safe(value, f"store {name}")
        store = self.module
        if name in self.locals or (name not in store and self.depth > 0):
            self.locals[name] = value
        elif name in store:
            store[name] = value
        else:
            self.locals[name] = value

    def bump_step(self) -> None:
        self.steps += 1
        if self.steps > 10_000:
            raise ReferenceError("step budget exceeded")


def eval_expr(expr: Expr, env: Env) -> TypedValue:
    from .validate import require_plain_int

    env.bump_step()
    if isinstance(expr, Lit):
        return TypedValue("Integer", require_plain_int(expr.value, "lit"))
    if isinstance(expr, Var):
        return TypedValue("Integer", env.get(expr.name))
    if isinstance(expr, Bin):
        l = eval_expr(expr.left, env)
        r = eval_expr(expr.right, env)
        if l.type != "Integer" or r.type != "Integer":
            raise ReferenceError("binop requires Integer")
        return TypedValue("Integer", ibin(expr.op, int(l.value), int(r.value)))
    if isinstance(expr, Cmp):
        l = eval_expr(expr.left, env)
        r = eval_expr(expr.right, env)
        return TypedValue("Boolean", 1 if icmp(expr.op, int(l.value), int(r.value)) else 0)
    if isinstance(expr, Call):
        return call_helper(expr.name, expr.args, env, as_expr=True)
    if isinstance(expr, ArrGet):
        if expr.name not in env.arrays:
            raise ReferenceError(f"undefined array {expr.name}")
        slots = env.arrays[expr.name]
        if expr.index < 0 or expr.index >= len(slots):
            raise ReferenceError(f"array index out of range {expr.name}({expr.index})")
        return TypedValue("Integer", slots[expr.index])
    if isinstance(expr, DictGet):
        if expr.name not in env.dicts:
            raise ReferenceError(f"undefined dict {expr.name}")
        store = env.dicts[expr.name]
        if expr.key not in store:
            raise ReferenceError(
                f"DictGet on missing key {expr.name}({expr.key!r}); use DictMissCheck"
            )
        return TypedValue("Integer", store[expr.key])
    if isinstance(expr, DictCount):
        if expr.name not in env.dicts:
            raise ReferenceError(f"undefined dict {expr.name}")
        return TypedValue("Integer", len(env.dicts[expr.name]))
    if isinstance(expr, DictExists):
        if expr.name not in env.dicts:
            raise ReferenceError(f"undefined dict {expr.name}")
        return TypedValue("Integer", 1 if expr.key in env.dicts[expr.name] else 0)
    if isinstance(expr, NestedSlotGet):
        if expr.name not in env.dicts:
            raise ReferenceError(f"undefined dict {expr.name}")
        store = env.dicts[expr.name]
        if expr.key not in store or not isinstance(store[expr.key], list):
            raise ReferenceError(f"NestedSlotGet missing nested array {expr.name}({expr.key!r})")
        slots = store[expr.key]
        if expr.index < 0 or expr.index >= len(slots):
            raise ReferenceError(f"nested index out of range {expr.name}({expr.key})({expr.index})")
        return TypedValue("Integer", slots[expr.index])
    if isinstance(expr, UdtFieldGet):
        if expr.var not in env.udts:
            raise ReferenceError(f"undefined udt {expr.var}")
        fields = env.udts[expr.var]
        if expr.field not in fields:
            raise ReferenceError(f"undefined udt field {expr.var}.{expr.field}")
        return TypedValue("Integer", fields[expr.field])
    if isinstance(expr, LogicBin):
        left = eval_expr(expr.left, env)
        lv = int(left.value)
        if expr.op == "AndAlso":
            if lv == 0:
                return TypedValue("Integer", 0)
            right = eval_expr(expr.right, env)
            return TypedValue("Integer", 0 if int(right.value) == 0 else 1)
        if expr.op == "OrElse":
            if lv != 0:
                return TypedValue("Integer", 1)
            right = eval_expr(expr.right, env)
            return TypedValue("Integer", 0 if int(right.value) == 0 else 1)
        raise ReferenceError(f"unsupported logic op {expr.op}")
    if isinstance(expr, LogicNot):
        v = eval_expr(expr.expr, env)
        return TypedValue("Integer", 1 if int(v.value) == 0 else 0)
    raise ReferenceError(f"bad expr {expr}")


def call_helper(
    name: str, args: list[Expr], env: Env, *, as_expr: bool = False
) -> TypedValue:
    from .validate import require_plain_int

    if name not in env.helpers:
        raise ReferenceError(f"unknown helper {name}")
    helper = env.helpers[name]
    if as_expr and not helper.returns:
        raise ReferenceError(f"Sub {name} cannot be used as an expression")
    specs = normalize_helper_params(list(helper.params))
    if env.depth > 32:
        raise ReferenceError("recursion depth")

    # Bind args left-to-right once; ByRef requires Var l-value.
    child_locals: dict[str, int] = {}
    writebacks: list[tuple[str, Env, str]] = []
    ai = 0
    for spec in specs:
        if spec.mode not in ("byval", "byref"):
            raise ReferenceError(f"unknown param mode {spec.mode}")
        if ai >= len(args):
            if spec.default is None:
                raise ReferenceError(f"missing arg {spec.name} for {name}")
            child_locals[spec.name] = require_plain_int(spec.default, "default")
            continue
        arg = args[ai]
        ai += 1
        if spec.mode == "byval":
            tv = eval_expr(arg, env)
            if tv.type != "Integer":
                raise ReferenceError(f"ByVal arg for {spec.name} requires Integer")
            child_locals[spec.name] = require_plain_int(tv.value, f"byval {spec.name}")
        elif spec.mode == "byref":
            if not isinstance(arg, Var):
                raise ReferenceError(f"ByRef arg for {spec.name} must be a variable")
            # Copy-in; write back on return (ordered).
            child_locals[spec.name] = env.get(arg.name)
            writebacks.append((spec.name, env, arg.name))
    if ai != len(args):
        raise ReferenceError(f"arity mismatch for {name}")

    for loc_name, init in (helper.local_vars or {}).items():
        if loc_name in child_locals:
            raise ReferenceError(f"local {loc_name} collides with param")
        child_locals[loc_name] = require_plain_int(init, f"local {loc_name}")

    def_mod = env.helper_defining_module.get(name, env.current_module)
    child = Env(
        module_stores=env.module_stores,
        current_module=def_mod,
        locals=child_locals,
        helpers=env.helpers,
        helper_defining_module=env.helper_defining_module,
        observations=env.observations,
        depth=env.depth + 1,
        steps=env.steps,
        writebacks=writebacks,
        arrays=env.arrays,
        dicts=env.dicts,
    )
    ret: Optional[TypedValue] = None
    try:
        for st in helper.body:
            r = exec_stmt(st, child)
            if r is not None:
                ret = r
                break  # early return stops subsequent statements
        if helper.returns:
            if ret is None:
                raise ReferenceError(f"helper {name} missing return")
            result = ret
        else:
            result = TypedValue("Integer", 0)
    except Exception:
        # Do not apply speculative writebacks on model error.
        env.steps = child.steps
        raise
    else:
        # Ordered write-backs (last wins on alias).
        for local_name, caller_env, caller_name in child.writebacks:
            caller_env.set(caller_name, child.locals[local_name])
        env.steps = child.steps
        return result


def exec_stmt(st: Stmt, env: Env) -> Optional[TypedValue]:
    env.bump_step()
    if isinstance(st, Assign):
        v = eval_expr(st.expr, env)
        if v.type != "Integer":
            raise ReferenceError("assign requires Integer")
        env.set(st.name, int(v.value))
        return None
    if isinstance(st, IfStmt):
        c = eval_expr(st.cond, env)
        body = st.then_body if c.value else st.else_body
        for s in body:
            r = exec_stmt(s, env)
            if r is not None:
                return r
        return None
    if isinstance(st, ForStmt):
        lo = int(eval_expr(st.lo, env).value)
        hi = int(eval_expr(st.hi, env).value)
        if hi - lo + 1 > 200:
            raise ReferenceError("for loop too large")
        i = lo
        while i <= hi:
            env.set(st.var, i)
            for s in st.body:
                r = exec_stmt(s, env)
                if r is not None:
                    return r
            i = _check_safe(i + 1, "for-next")
        return None
    if isinstance(st, SelectStmt):
        sel = int(eval_expr(st.selector, env).value)
        matched = False
        for case in st.cases:
            if sel in case.values:
                matched = True
                for s in case.body:
                    r = exec_stmt(s, env)
                    if r is not None:
                        return r
                break
        if not matched:
            for s in st.else_body:
                r = exec_stmt(s, env)
                if r is not None:
                    return r
        return None
    if isinstance(st, CallStmt):
        call_helper(st.name, st.args, env, as_expr=False)
        return None
    if isinstance(st, Observe):
        v = eval_expr(st.expr, env)
        env.observations.append(Observation(st.name, v))
        return None
    if isinstance(st, Note):
        env.observations.append(
            Observation(f"event_{st.label}", TypedValue("String", st.label))
        )
        return None
    if isinstance(st, ReturnStmt):
        return eval_expr(st.expr, env)
    if isinstance(st, ArrSet):
        if st.name not in env.arrays:
            raise ReferenceError(f"undefined array {st.name}")
        slots = env.arrays[st.name]
        if st.index < 0 or st.index >= len(slots):
            raise ReferenceError(f"array index out of range {st.name}({st.index})")
        v = eval_expr(st.expr, env)
        if v.type != "Integer":
            raise ReferenceError("ArrSet requires Integer")
        slots[st.index] = _check_safe(int(v.value), f"arr_set {st.name}")
        return None
    if isinstance(st, DictSet):
        if st.name not in env.dicts:
            raise ReferenceError(f"undefined dict {st.name}")
        v = eval_expr(st.expr, env)
        if v.type != "Integer":
            raise ReferenceError("DictSet requires Integer")
        env.dicts[st.name][st.key] = _check_safe(int(v.value), f"dict_set {st.name}")
        return None
    if isinstance(st, DictMissCheck):
        # R12: missing → Nothing (VarType 1); Err.Number stays 0.
        # Observation order matches emitter: err_before, vt, is_nothing, err, err_type.
        if st.name not in env.dicts:
            raise ReferenceError(f"undefined dict {st.name}")
        if st.key in env.dicts[st.name]:
            raise ReferenceError(
                f"DictMissCheck key {st.key!r} is present in {st.name}"
            )
        env.observations.append(
            Observation(f"{st.prefix}_err_before", TypedValue("Integer", 0))
        )
        env.observations.append(
            Observation(f"{st.prefix}_vt", TypedValue("Integer", 1))
        )
        env.observations.append(
            Observation(f"{st.prefix}_is_nothing", TypedValue("Integer", 1))
        )
        env.observations.append(
            Observation(f"{st.prefix}_err", TypedValue("Integer", 0))
        )
        env.observations.append(
            Observation(f"{st.prefix}_err_type", TypedValue("String", "Integer"))
        )
        return None
    if isinstance(st, NestedSlotSet):
        if st.name not in env.dicts:
            raise ReferenceError(f"undefined dict {st.name}")
        store = env.dicts[st.name]
        if st.key not in store or not isinstance(store[st.key], list):
            raise ReferenceError(f"NestedSlotSet missing nested array {st.name}({st.key!r})")
        slots = store[st.key]
        if st.index < 0 or st.index >= len(slots):
            raise ReferenceError(f"nested index out of range {st.name}({st.key})({st.index})")
        v = eval_expr(st.expr, env)
        if v.type != "Integer":
            raise ReferenceError("NestedSlotSet requires Integer")
        slots[st.index] = _check_safe(int(v.value), f"nested_set {st.name}")
        return None
    if isinstance(st, UdtFieldSet):
        if st.var not in env.udts:
            raise ReferenceError(f"undefined udt {st.var}")
        if st.field not in env.udts[st.var]:
            raise ReferenceError(f"undefined udt field {st.var}.{st.field}")
        v = eval_expr(st.expr, env)
        if v.type != "Integer":
            raise ReferenceError("UdtFieldSet requires Integer")
        env.udts[st.var][st.field] = _check_safe(int(v.value), f"udt_set {st.var}")
        return None
    if isinstance(st, UdtCopy):
        if st.src not in env.udts:
            raise ReferenceError(f"undefined udt {st.src}")
        if st.dest not in env.udts:
            raise ReferenceError(f"undefined udt {st.dest}")
        env.udts[st.dest] = dict(env.udts[st.src])
        return None
    raise ReferenceError(f"bad stmt {st}")


def evaluate_program(prog: Program) -> RefResult:
    from .validate import ValidationError, validate_program

    try:
        validate_program(prog)
    except ValidationError as exc:
        raise ReferenceError(str(exc)) from exc

    # Normalize helpers once so Phase 1 string params remain ByVal.
    helpers = {
        h.name: Helper(
            name=h.name,
            params=normalize_helper_params(list(h.params)),
            body=h.body,
            returns=h.returns,
            side_effect_global=h.side_effect_global,
            local_vars=dict(getattr(h, "local_vars", {}) or {}),
        )
        for h in prog.helpers
    }
    stores: dict[str, dict[str, int]] = {"": dict(prog.module_vars)}
    for mk, mv in (getattr(prog, "module_stores", None) or {}).items():
        if mk == "":
            stores[""].update(dict(mv))
        else:
            stores[str(mk)] = dict(mv)
    arrays = {
        str(n): [int(x) for x in list(slots)]
        for n, slots in dict(getattr(prog, "module_arrays", None) or {}).items()
    }
    dicts: dict[str, dict[str, Any]] = {}
    for n, entries in dict(getattr(prog, "module_dicts", None) or {}).items():
        dstore: dict[str, Any] = {}
        for k, v in dict(entries).items():
            if isinstance(v, list):
                dstore[str(k)] = [int(x) for x in v]
            else:
                dstore[str(k)] = int(v)
        dicts[str(n)] = dstore
    udts = {
        str(n): {str(f): int(v) for f, v in dict(fields).items()}
        for n, fields in dict(getattr(prog, "module_udts", None) or {}).items()
    }
    env = Env(
        module_stores=stores,
        current_module="",
        helpers=helpers,
        helper_defining_module=dict(
            getattr(prog, "helper_defining_module", None) or {}
        ),
        arrays=arrays,
        dicts=dicts,
        udts=udts,
    )
    try:
        for st in prog.main:
            r = exec_stmt(st, env)
            if r is not None:
                break
    except ReferenceError:
        raise
    return RefResult(
        observations=list(env.observations),
        module_vars=dict(env.module_stores.get("", {})),
    )
