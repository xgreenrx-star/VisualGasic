"""Strict IR validation before any int()/bool() coercion."""

from __future__ import annotations

from typing import Iterable, Optional, Set

from .ir import (
    Assign,
    Bin,
    Call,
    CallStmt,
    Cmp,
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
from . import SAFE_ABS_MAX


class ValidationError(Exception):
    """Invalid IR rejected before evaluation or emission."""


def require_plain_int(value, ctx: str) -> int:
    """Accept only non-bool integers; reject float/str/bool before coercion."""
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValidationError(f"{ctx}: expected plain Integer, got {type(value).__name__}={value!r}")
    if abs(value) > SAFE_ABS_MAX:
        raise ValidationError(f"{ctx}: Integer outside safe range: {value}")
    return value


def require_bool(value, ctx: str) -> bool:
    """Accept only real bool; reject bool('false')-style string sanitization."""
    if not isinstance(value, bool):
        raise ValidationError(f"{ctx}: expected bool, got {type(value).__name__}={value!r}")
    return value


def _validate_expr(expr: Expr, ctx: str) -> None:
    if isinstance(expr, Lit):
        require_plain_int(expr.value, f"{ctx}:lit")
        return
    if isinstance(expr, Var):
        if not expr.name or not isinstance(expr.name, str):
            raise ValidationError(f"{ctx}: bad var name")
        return
    if isinstance(expr, Bin):
        _validate_expr(expr.left, f"{ctx}:bin.left")
        _validate_expr(expr.right, f"{ctx}:bin.right")
        return
    if isinstance(expr, Cmp):
        _validate_expr(expr.left, f"{ctx}:cmp.left")
        _validate_expr(expr.right, f"{ctx}:cmp.right")
        return
    if isinstance(expr, Call):
        for i, a in enumerate(expr.args):
            _validate_expr(a, f"{ctx}:call_arg[{i}]")
        return
    raise ValidationError(f"{ctx}: unsupported expr {type(expr).__name__}")


def _validate_stmts(
    body: Iterable[Stmt],
    *,
    ctx: str,
    helper_returns: Optional[bool],
) -> None:
    for i, st in enumerate(body):
        c = f"{ctx}[{i}]"
        if isinstance(st, Assign):
            _validate_expr(st.expr, f"{c}:assign")
        elif isinstance(st, IfStmt):
            _validate_expr(st.cond, f"{c}:if.cond")
            _validate_stmts(st.then_body, ctx=f"{c}:then", helper_returns=helper_returns)
            _validate_stmts(st.else_body, ctx=f"{c}:else", helper_returns=helper_returns)
        elif isinstance(st, ForStmt):
            _validate_expr(st.lo, f"{c}:for.lo")
            _validate_expr(st.hi, f"{c}:for.hi")
            _validate_stmts(st.body, ctx=f"{c}:for.body", helper_returns=helper_returns)
        elif isinstance(st, SelectStmt):
            _validate_expr(st.selector, f"{c}:select")
            for j, case in enumerate(st.cases):
                for v in case.values:
                    require_plain_int(v, f"{c}:case[{j}].value")
                _validate_stmts(
                    case.body, ctx=f"{c}:case[{j}]", helper_returns=helper_returns
                )
            _validate_stmts(
                st.else_body, ctx=f"{c}:select.else", helper_returns=helper_returns
            )
        elif isinstance(st, CallStmt):
            for j, a in enumerate(st.args):
                _validate_expr(a, f"{c}:callstmt_arg[{j}]")
        elif isinstance(st, Observe):
            _validate_expr(st.expr, f"{c}:observe")
        elif isinstance(st, Note):
            if not st.label or any(ch.isspace() for ch in st.label):
                raise ValidationError(f"{c}: Note label must be non-empty without whitespace")
        elif isinstance(st, ReturnStmt):
            _validate_expr(st.expr, f"{c}:return")
            if helper_returns is False:
                # Sub early-exit: only Lit(0) allowed (emitted as Exit Sub).
                if not isinstance(st.expr, Lit) or int(st.expr.value) != 0:
                    raise ValidationError(
                        f"{c}: Sub ReturnStmt must be Lit(0) (Exit Sub); got {st.expr!r}"
                    )
        else:
            raise ValidationError(f"{c}: unsupported stmt {type(st).__name__}")


def _validate_params(specs: list[ParamSpec], ctx: str) -> None:
    seen: Set[str] = set()
    seen_default = False
    for i, p in enumerate(specs):
        if not isinstance(p, ParamSpec):
            raise ValidationError(f"{ctx}:param[{i}]: not ParamSpec")
        if p.name in seen:
            raise ValidationError(f"{ctx}: duplicate param {p.name}")
        seen.add(p.name)
        if p.mode not in ("byval", "byref"):
            raise ValidationError(f"{ctx}:param[{i}]: invalid mode {p.mode!r}")
        if p.default is not None:
            require_plain_int(p.default, f"{ctx}:param[{i}].default")
            if p.mode == "byref":
                raise ValidationError(f"{ctx}:param[{i}]: Optional ByRef not supported")
            seen_default = True
        elif seen_default:
            raise ValidationError(
                f"{ctx}:param[{i}]: required parameter after Optional default"
            )


def validate_helper(h: Helper, *, helper_names: Set[str]) -> None:
    if h.name in helper_names:
        raise ValidationError(f"duplicate helper name {h.name}")
    helper_names.add(h.name)
    require_bool(h.returns, f"helper {h.name}.returns")
    specs = normalize_helper_params(list(h.params))
    _validate_params(specs, ctx=f"helper {h.name}")
    local_vars = getattr(h, "local_vars", None) or {}
    if not isinstance(local_vars, dict):
        raise ValidationError(f"helper {h.name}: local_vars must be dict")
    param_names = {p.name for p in specs}
    for name, init in local_vars.items():
        if name in param_names:
            raise ValidationError(f"helper {h.name}: local {name} collides with param")
        require_plain_int(init, f"helper {h.name}: local {name}")
    _validate_stmts(h.body, ctx=f"helper {h.name}.body", helper_returns=h.returns)


def _validate_rel_path(rel: str, ctx: str) -> None:
    from .bundle_integrity import validate_rel_path_name

    bad = validate_rel_path_name(rel)
    if bad:
        raise ValidationError(f"{ctx}: {bad}")


def validate_program(prog: Program) -> None:
    for name, val in prog.module_vars.items():
        require_plain_int(val, f"module_vars[{name}]")
    seen_rels: Set[str] = set()
    seen_lower: Set[str] = set()
    for i, mod in enumerate(getattr(prog, "source_modules", None) or []):
        if not isinstance(mod, dict):
            raise ValidationError(f"source_modules[{i}]: expected dict")
        rel = str(mod.get("rel_path", ""))
        content = mod.get("content")
        _validate_rel_path(rel, f"source_modules[{i}]")
        if rel.lower() in seen_lower:
            raise ValidationError(f"duplicate source_modules rel_path (case-insensitive) {rel}")
        seen_lower.add(rel.lower())
        seen_rels.add(rel)
        if not isinstance(content, str):
            raise ValidationError(f"source_modules[{i}]: content must be str")
    for mk, store in (getattr(prog, "module_stores", None) or {}).items():
        if mk not in ("",) and mk not in seen_rels:
            raise ValidationError(f"module_stores key {mk!r} not in source_modules")
        if not isinstance(store, dict):
            raise ValidationError(f"module_stores[{mk}] must be dict")
        for n, v in store.items():
            require_plain_int(v, f"module_stores[{mk}][{n}]")
    helper_names: Set[str] = set()
    helpers = {h.name: h for h in prog.helpers}
    for h in prog.helpers:
        validate_helper(h, helper_names=helper_names)
    for hn, rel in (getattr(prog, "helper_defining_module", None) or {}).items():
        if hn not in helpers:
            raise ValidationError(f"helper_defining_module unknown helper {hn}")
        _validate_rel_path(rel, f"helper_defining_module[{hn}]")
        if rel not in seen_rels:
            raise ValidationError(
                f"helper_defining_module[{hn}]: {rel} not in source_modules"
            )
    # Every declared source module must define at least one typed helper.
    if seen_rels:
        defining = getattr(prog, "helper_defining_module", None) or {}
        covered = set(defining.values())
        for rel in seen_rels:
            if rel not in covered:
                raise ValidationError(f"source_modules {rel} has no typed helper")

    # Call-site checks that need helper metadata (Sub-as-expr, ByRef lvalues).
    def check_call(name: str, args: list, *, as_expr: bool, ctx: str) -> None:
        if name not in helpers:
            raise ValidationError(f"{ctx}: unknown helper {name}")
        h = helpers[name]
        if as_expr and not h.returns:
            raise ValidationError(f"{ctx}: Sub {name} cannot be used as an expression")
        specs = normalize_helper_params(list(h.params))
        ai = 0
        for spec in specs:
            if ai >= len(args):
                if spec.default is None:
                    raise ValidationError(f"{ctx}: missing arg {spec.name}")
                continue
            arg = args[ai]
            ai += 1
            if spec.mode == "byref" and not isinstance(arg, Var):
                raise ValidationError(
                    f"{ctx}: ByRef arg {spec.name} must be a variable, got {type(arg).__name__}"
                )
            _validate_expr(arg, f"{ctx}:arg")
        if ai != len(args):
            raise ValidationError(f"{ctx}: arity mismatch for {name}")

    def walk_expr(expr: Expr, ctx: str) -> None:
        _validate_expr(expr, ctx)
        if isinstance(expr, Call):
            check_call(expr.name, expr.args, as_expr=True, ctx=f"{ctx}:Call")
            for a in expr.args:
                walk_expr(a, ctx)
        elif isinstance(expr, Bin):
            walk_expr(expr.left, ctx)
            walk_expr(expr.right, ctx)
        elif isinstance(expr, Cmp):
            walk_expr(expr.left, ctx)
            walk_expr(expr.right, ctx)

    def walk_stmts(body: Iterable[Stmt], ctx: str) -> None:
        for i, st in enumerate(body):
            c = f"{ctx}[{i}]"
            if isinstance(st, Assign):
                walk_expr(st.expr, c)
            elif isinstance(st, IfStmt):
                walk_expr(st.cond, c)
                walk_stmts(st.then_body, f"{c}:then")
                walk_stmts(st.else_body, f"{c}:else")
            elif isinstance(st, ForStmt):
                walk_expr(st.lo, c)
                walk_expr(st.hi, c)
                walk_stmts(st.body, f"{c}:for")
            elif isinstance(st, SelectStmt):
                walk_expr(st.selector, c)
                for j, case in enumerate(st.cases):
                    walk_stmts(case.body, f"{c}:case{j}")
                walk_stmts(st.else_body, f"{c}:else")
            elif isinstance(st, CallStmt):
                check_call(st.name, st.args, as_expr=False, ctx=f"{c}:CallStmt")
                for a in st.args:
                    walk_expr(a, c)
            elif isinstance(st, Observe):
                walk_expr(st.expr, c)
            elif isinstance(st, ReturnStmt):
                walk_expr(st.expr, c)
            elif isinstance(st, Note):
                pass

    for h in prog.helpers:
        walk_stmts(h.body, f"helper {h.name}")
    walk_stmts(prog.main, "main")
    _validate_stmts(prog.main, ctx="main", helper_returns=None)
