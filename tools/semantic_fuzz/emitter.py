"""Emit valid VisualGasic source from Phase 1 IR."""

from __future__ import annotations

from . import COMPLETION_MARKER, OBS_PREFIX
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
    if isinstance(e, ArrGet):
        return f"{e.name}({int(e.index)})"
    if isinstance(e, DictGet):
        return f'{e.name}("{e.key}")'
    if isinstance(e, DictCount):
        return f"{e.name}.Count()"
    if isinstance(e, DictExists):
        # Exists is Boolean at runtime; Observe path coerces to Integer 1/0.
        return f'{e.name}.Exists("{e.key}")'
    if isinstance(e, NestedSlotGet):
        return f'{e.name}("{e.key}")({int(e.index)})'
    if isinstance(e, UdtFieldGet):
        return f"{e.var}.{e.field}"
    if isinstance(e, LogicBin):
        return f"({emit_expr(e.left)} {e.op} {emit_expr(e.right)})"
    if isinstance(e, LogicNot):
        return f"(Not {emit_expr(e.expr)})"
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
        if isinstance(st.expr, DictExists):
            # Coerce Boolean Exists → Integer 1/0 (matches reference / miss flags).
            lines.append(f"{pad}_c3_flag = 0")
            lines.append(
                f'{pad}If {st.expr.name}.Exists("{st.expr.key}") Then'
            )
            lines.append(f"{pad}\t_c3_flag = 1")
            lines.append(f"{pad}End If")
            lines.append(f"{pad}_sem_obs = _c3_flag")
        elif isinstance(st.expr, (LogicBin, LogicNot)):
            # Nested AndAlso/OrElse and Not TypeName as Boolean; simple AndAlso
            # of Integers TypeName as Integer. Coerce to Integer 1/0 for obs.
            lines.append(f"{pad}_c3_flag = 0")
            lines.append(f"{pad}If {emit_expr(st.expr)} Then")
            lines.append(f"{pad}\t_c3_flag = 1")
            lines.append(f"{pad}End If")
            lines.append(f"{pad}_sem_obs = _c3_flag")
        else:
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
    elif isinstance(st, ArrSet):
        lines.append(f"{pad}{st.name}({int(st.index)}) = {emit_expr(st.expr)}")
    elif isinstance(st, DictSet):
        lines.append(f'{pad}{st.name}("{st.key}") = {emit_expr(st.expr)}')
    elif isinstance(st, NestedSlotSet):
        lines.append(
            f'{pad}{st.name}("{st.key}")({int(st.index)}) = {emit_expr(st.expr)}'
        )
    elif isinstance(st, UdtFieldSet):
        lines.append(f"{pad}{st.var}.{st.field} = {emit_expr(st.expr)}")
    elif isinstance(st, UdtCopy):
        lines.append(f"{pad}{st.dest} = {st.src}")
    elif isinstance(st, DictMissCheck):
        # R12: Err before read; miss read; capture Err into Variant immediately;
        # then VarType / IsNothing; finally report saved err value + TypeName.
        lines.append(f"{pad}_c3_err_before = Err.Number")
        lines.append(f"{pad}_sem_obs = _c3_err_before")
        lines.append(
            f'{pad}Print "{OBS_PREFIX} kind=value name={st.prefix}_err_before type=" '
            f'& TypeName(_sem_obs) & " value=" & CStr(_sem_obs)'
        )
        lines.append(f'{pad}_c3_miss = {st.name}("{st.key}")')
        lines.append(f"{pad}_c3_err = Err.Number")
        lines.append(f"{pad}_sem_obs = VarType(_c3_miss)")
        lines.append(
            f'{pad}Print "{OBS_PREFIX} kind=value name={st.prefix}_vt type=" '
            f'& TypeName(_sem_obs) & " value=" & CStr(_sem_obs)'
        )
        lines.append(f"{pad}If _c3_miss Is Nothing Then")
        lines.append(f"{pad}\t_c3_flag = 1")
        lines.append(f"{pad}Else")
        lines.append(f"{pad}\t_c3_flag = 0")
        lines.append(f"{pad}End If")
        lines.append(f"{pad}_sem_obs = _c3_flag")
        lines.append(
            f'{pad}Print "{OBS_PREFIX} kind=value name={st.prefix}_is_nothing type=" '
            f'& TypeName(_sem_obs) & " value=" & CStr(_sem_obs)'
        )
        lines.append(f"{pad}_sem_obs = _c3_err")
        lines.append(
            f'{pad}Print "{OBS_PREFIX} kind=value name={st.prefix}_err type=" '
            f'& TypeName(_sem_obs) & " value=" & CStr(_sem_obs)'
        )
        lines.append(f"{pad}_sem_obs = TypeName(_c3_err)")
        lines.append(
            f'{pad}Print "{OBS_PREFIX} kind=value name={st.prefix}_err_type type=" '
            f'& TypeName(_sem_obs) & " value=" & CStr(_sem_obs)'
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
    for name, slots in sorted(dict(getattr(prog, "module_arrays", None) or {}).items()):
        ubound = len(slots) - 1
        lines.append(f"Dim {name}({ubound}) As Integer")
    for name in sorted(dict(getattr(prog, "module_dicts", None) or {}).keys()):
        lines.append(f"Dim {name} As New Dictionary")
    udts = dict(getattr(prog, "module_udts", None) or {})
    if udts:
        # Single shared Integer-field Type for generated C3b UDT cases.
        field_names = sorted({f for fields in udts.values() for f in fields})
        lines.append("Type C3bP")
        for f in field_names:
            lines.append(f"\t{f} As Integer")
        lines.append("End Type")
        for name in sorted(udts.keys()):
            lines.append(f"Dim {name} As C3bP")
    if (
        prog.module_vars
        or getattr(prog, "module_arrays", None)
        or getattr(prog, "module_dicts", None)
        or udts
    ):
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

    def _has_miss(sts) -> bool:
        for st in sts:
            if isinstance(st, DictMissCheck):
                return True
            if isinstance(st, IfStmt) and (
                _has_miss(st.then_body) or _has_miss(st.else_body)
            ):
                return True
            if isinstance(st, ForStmt) and _has_miss(st.body):
                return True
            if isinstance(st, SelectStmt):
                bodies = list(st.else_body)
                for c in st.cases:
                    bodies.extend(c.body)
                if _has_miss(bodies):
                    return True
        return False

    def _has_exists_obs(sts) -> bool:
        for st in sts:
            if isinstance(st, Observe) and isinstance(st.expr, DictExists):
                return True
            if isinstance(st, IfStmt) and (
                _has_exists_obs(st.then_body) or _has_exists_obs(st.else_body)
            ):
                return True
            if isinstance(st, ForStmt) and _has_exists_obs(st.body):
                return True
            if isinstance(st, SelectStmt):
                bodies = list(st.else_body)
                for c in st.cases:
                    bodies.extend(c.body)
                if _has_exists_obs(bodies):
                    return True
        return False

    def _has_logic_obs(sts) -> bool:
        for st in sts:
            if isinstance(st, Observe) and isinstance(st.expr, (LogicBin, LogicNot)):
                return True
            if isinstance(st, IfStmt) and (
                _has_logic_obs(st.then_body) or _has_logic_obs(st.else_body)
            ):
                return True
            if isinstance(st, ForStmt) and _has_logic_obs(st.body):
                return True
            if isinstance(st, SelectStmt):
                bodies = list(st.else_body)
                for c in st.cases:
                    bodies.extend(c.body)
                if _has_logic_obs(bodies):
                    return True
        return False

    needs_miss = _has_miss(prog.main)
    needs_flag = needs_miss or _has_exists_obs(prog.main) or _has_logic_obs(prog.main)
    if needs_miss:
        lines.append("\tDim _c3_miss As Variant")
        lines.append("\tDim _c3_err_before As Variant")
        lines.append("\tDim _c3_err As Variant")
    if needs_flag:
        lines.append("\tDim _c3_flag As Integer")
    for name, val in sorted(prog.module_vars.items()):
        lines.append(f"\t{name} = {int(val)}")
    for name, slots in sorted(dict(getattr(prog, "module_arrays", None) or {}).items()):
        for i, v in enumerate(slots):
            lines.append(f"\t{name}({i}) = {int(v)}")
    for name, entries in sorted(dict(getattr(prog, "module_dicts", None) or {}).items()):
        for k, v in sorted(entries.items()):
            if isinstance(v, list):
                lines.append(f'\t{name}("{k}") = Array({", ".join(str(int(x)) for x in v)})')
            else:
                lines.append(f'\t{name}("{k}") = {int(v)}')
    for name, fields in sorted(dict(getattr(prog, "module_udts", None) or {}).items()):
        for f, v in sorted(fields.items()):
            lines.append(f"\t{name}.{f} = {int(v)}")
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
    module = set(prog.module_vars) | set(getattr(prog, "module_arrays", None) or {}) | set(
        getattr(prog, "module_dicts", None) or {}
    )
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
