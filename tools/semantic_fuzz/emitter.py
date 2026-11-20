"""Emit valid VisualGasic source from Phase 1 IR."""

from __future__ import annotations

from . import COMPLETION_MARKER, OBS_PREFIX
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
    Program,
    ReturnStmt,
    SelectStmt,
    Stmt,
    Var,
)


def emit_expr(e: Expr) -> str:
    if isinstance(e, Lit):
        return str(int(e.value))
    if isinstance(e, Var):
        return e.name
    if isinstance(e, Bin):
        return f"({emit_expr(e.left)} {e.op} {emit_expr(e.right)})"
    if isinstance(e, Cmp):
        return f"({emit_expr(e.left)} {e.op} {emit_expr(e.right)})"
    if isinstance(e, Call):
        args = ", ".join(emit_expr(a) for a in e.args)
        return f"{e.name}({args})"
    raise ValueError(f"bad expr {e}")


def emit_stmt(st: Stmt, indent: int = 1, *, in_sub: bool = False) -> list[str]:
    pad = "\t" * indent
    lines: list[str] = []
    if isinstance(st, Assign):
        lines.append(f"{pad}{st.name} = {emit_expr(st.expr)}")
    elif isinstance(st, IfStmt):
        lines.append(f"{pad}If {emit_expr(st.cond)} Then")
        for s in st.then_body:
            lines.extend(emit_stmt(s, indent + 1, in_sub=in_sub))
        if st.else_body:
            lines.append(f"{pad}Else")
            for s in st.else_body:
                lines.extend(emit_stmt(s, indent + 1, in_sub=in_sub))
        lines.append(f"{pad}End If")
    elif isinstance(st, ForStmt):
        lines.append(f"{pad}For {st.var} = {emit_expr(st.lo)} To {emit_expr(st.hi)}")
        for s in st.body:
            lines.extend(emit_stmt(s, indent + 1, in_sub=in_sub))
        lines.append(f"{pad}Next {st.var}")
    elif isinstance(st, SelectStmt):
        lines.append(f"{pad}Select Case {emit_expr(st.selector)}")
        for case in st.cases:
            vals = ", ".join(str(v) for v in case.values)
            lines.append(f"{pad}\tCase {vals}")
            for s in case.body:
                lines.extend(emit_stmt(s, indent + 2, in_sub=in_sub))
        lines.append(f"{pad}\tCase Else")
        for s in st.else_body:
            lines.extend(emit_stmt(s, indent + 2, in_sub=in_sub))
        lines.append(f"{pad}End Select")
    elif isinstance(st, CallStmt):
        args = ", ".join(emit_expr(a) for a in st.args)
        if args:
            lines.append(f"{pad}Call {st.name}({args})")
        else:
            lines.append(f"{pad}Call {st.name}")
    elif isinstance(st, Observe):
        # Measure runtime type via TypeName; do not hardcode the expected type.
        # Evaluate once into the shared SemMain scratch slot `_sem_obs`.
        expr = emit_expr(st.expr)
        lines.append(f"{pad}_sem_obs = {expr}")
        lines.append(
            f'{pad}Print "{OBS_PREFIX} kind=value name={st.name} type=" & TypeName(_sem_obs)'
            f' & " value=" & CStr(_sem_obs)'
        )
    elif isinstance(st, ReturnStmt):
        if in_sub:
            # Early exit from Sub — never drop; never emit valued Return in Sub.
            lines.append(f"{pad}Exit Sub")
        else:
            lines.append(f"{pad}Return {emit_expr(st.expr)}")
    elif isinstance(st, Note):
        # Ordered event as String observation (deterministic label).
        lines.append(
            f'{pad}Print "{OBS_PREFIX} kind=value name=event_{st.label} type=String'
            f' value={st.label}"'
        )
    else:
        raise ValueError(f"bad stmt {st}")
    return lines


def _emit_param_list(h: Helper) -> str:
    from .ir import ParamSpec, normalize_helper_params

    specs = normalize_helper_params(list(h.params))
    parts = []
    for p in specs:
        mode = "ByRef" if p.mode == "byref" else "ByVal"
        if p.default is not None:
            parts.append(f"Optional {mode} {p.name} As Integer = {int(p.default)}")
        else:
            parts.append(f"{mode} {p.name} As Integer")
    return ", ".join(parts)


def emit_helper(h: Helper, *, andalso_join: bool = False) -> list[str]:
    from .ir import normalize_helper_params

    specs = normalize_helper_params(list(h.params))
    params = _emit_param_list(h)
    lines: list[str] = []
    if andalso_join and h.name == "ShortJoin" and len(specs) == 2:
        # Emit short-circuit join source; reference IR uses equivalent nested If.
        a, b = specs[0].name, specs[1].name
        lines.append(f"Function {h.name}({params}) As Integer")
        lines.append("\tDim ok As Boolean")
        lines.append(f"\tok = ({a} > 0) AndAlso ({b} > 0)")
        lines.append("\tIf ok Then")
        lines.append(f"\t\tReturn {a} + {b}")
        lines.append("\tElse")
        lines.append("\t\tReturn 0")
        lines.append("\tEnd If")
        lines.append("End Function")
        lines.append("")
        return lines
    if h.returns:
        lines.append(f"Function {h.name}({params}) As Integer")
    else:
        lines.append(f"Sub {h.name}({params})")
    needs_obs = any(_stmt_has_observe(s) for s in h.body)
    if needs_obs:
        lines.append("\tDim _sem_obs As Variant")
    for loc_name, init in sorted((h.local_vars or {}).items()):
        lines.append(f"\tDim {loc_name} As Integer")
        if int(init) != 0:
            lines.append(f"\t{loc_name} = {int(init)}")
    in_sub = not h.returns
    for st in h.body:
        lines.extend(emit_stmt(st, 1, in_sub=in_sub))
    lines.append(f"End {'Function' if h.returns else 'Sub'}")
    lines.append("")
    return lines


def _stmt_has_observe(st: Stmt) -> bool:
    if isinstance(st, Observe):
        return True
    if isinstance(st, IfStmt):
        return any(_stmt_has_observe(s) for s in st.then_body + st.else_body)
    if isinstance(st, ForStmt):
        return any(_stmt_has_observe(s) for s in st.body)
    if isinstance(st, SelectStmt):
        bodies = list(st.else_body)
        for c in st.cases:
            bodies.extend(c.body)
        return any(_stmt_has_observe(s) for s in bodies)
    return False


def emit_program(prog: Program, *, warmup_calls: int = 0) -> str:
    """Emit a Node-based .vg that runs Main once (optionally after warmup)."""
    from .validate import validate_program

    validate_program(prog)
    lines: list[str] = [
        f"' SEMANTIC_FUZZ case={prog.case_id} family={prog.family}",
        "' MAX_FRAMES: 8",
        "Attribute VB_Name = \"SemFuzzCase\"",
        "",
    ]
    for mod in getattr(prog, "source_modules", None) or []:
        rel = mod["rel_path"] if isinstance(mod, dict) else mod.rel_path
        # VG Import of a sibling file in the staged directory.
        lines.append(f'Import "{rel}"')
    if getattr(prog, "source_modules", None):
        lines.append("")
    for name, val in sorted(prog.module_vars.items()):
        lines.append(f"Dim {name} As Integer")
    if prog.module_vars:
        lines.append("")

    andalso = "EMIT_ANDALSO_JOIN" in (prog.notes or "")
    imported = set((getattr(prog, "helper_defining_module", None) or {}).keys())
    for h in prog.helpers:
        if h.name in imported:
            continue  # body lives in source_modules content
        lines.extend(emit_helper(h, andalso_join=andalso))

    # Optional pure Integer kernel used for native-path proof after warmup.
    # Present only when tagged; generator adds KernelNative when needed.
    lines.append("Sub SemMain()")
    lines.append("\tDim _sem_obs As Variant")
    for name, val in sorted(prog.module_vars.items()):
        lines.append(f"\t{name} = {int(val)}")
    # Discover locals assigned in main (simple scan).
    assigned: set[str] = set()

    def walk(sts):
        for st in sts:
            if isinstance(st, Assign):
                assigned.add(st.name)
            elif isinstance(st, IfStmt):
                walk(st.then_body)
                walk(st.else_body)
            elif isinstance(st, ForStmt):
                assigned.add(st.var)
                walk(st.body)
            elif isinstance(st, SelectStmt):
                for c in st.cases:
                    walk(c.body)
                walk(st.else_body)
            elif isinstance(st, Observe):
                pass

    walk(prog.main)
    # Also Dim locals assigned inside helpers' observe paths? Helpers use their own scope.
    # Observe inside helpers needs a scratch too — emit_helper adds it when needed.
    module = set(prog.module_vars)
    for name in sorted(assigned - module):
        lines.append(f"\tDim {name} As Integer")

    for st in prog.main:
        lines.extend(emit_stmt(st, 1))
    lines.append("End Sub")
    lines.append("")
    lines.append("Sub _Ready()")
    if warmup_calls > 0 and any(h.name == "KernelNative" for h in prog.helpers):
        lines.append("\tDim Dummy As Integer")
        for _ in range(warmup_calls):
            lines.append("\tDummy = KernelNative(1)")
    lines.append("\tSemMain")
    lines.append(f'\tPrint "{COMPLETION_MARKER} case={prog.case_id}"')
    lines.append("End Sub")
    lines.append("")
    return "\n".join(lines)
