#!/usr/bin/env python3
"""Cross-check vg_command_help.gd entries against parser/compiler/builtins.

Reports commands documented in the Programmer's Reference that appear
missing or only partially implemented (interpreter-only, no bytecode, etc.).

Known gaps still tracked in ROADMAP.md (v6.1): Interface...End Interface, Using...End Using.

Usage:
  python3 scripts/audit_command_implementation.py
  python3 scripts/audit_command_implementation.py --json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GD = ROOT / "addons/visual_gasic/vg_command_help.gd"
SRC = ROOT / "src"

# Map help keywords to parser evidence (token / parse_* / STMT_*)
KEYWORD_PARSER_HINTS: dict[str, list[str]] = {
    "if": ['parse_if', '"If"'],
    "else": ['"Else"'],
    "elseif": ['"ElseIf"'],
    "end if": ['"End If"'],
    "for": ['parse_for', '"For"'],
    "for each": ['"For Each"', 'STMT_FOR_EACH', 'parse_for'],
    "next": ['"Next"'],
    "while": ['parse_while'],
    "wend": ['"Wend"'],
    "do": ['parse_do'],
    "loop": ['"Loop"'],
    "until": ['"Until"'],
    "select": ['parse_select', '"Select"'],
    "select case": ['parse_select', '"Select Case"', 'STMT_SELECT'],
    "case": ['"Case"'],
    "end select": ['"End Select"'],
    "dim": ['parse_dim', 'STMT_DIM'],
    "global": ['"Global"'],
    "public": ['"Public"'],
    "private": ['"Private"'],
    "static": ['"Static"'],
    "const": ['parse_const', 'STMT_CONST'],
    "redim": ['parse_redim', 'STMT_REDIM'],
    "set": ['"Set"'],
    "sub": ['parse_sub'],
    "end sub": ['"End Sub"'],
    "function": ['parse_function', '"Function"'],
    "end function": ['"End Function"'],
    "call": ['"Call"'],
    "return": ['STMT_RETURN'],
    "byval": ['"ByVal"'],
    "byref": ['"ByRef"'],
    "optional": ['"Optional"'],
    "on error": ['parse_on_error', 'STMT_ON_ERROR'],
    "try": ['parse_try', 'STMT_TRY'],
    "catch": ['"Catch"'],
    "finally": ['"Finally"'],
    "throw": ['parse_raise', 'STMT_RAISE', '"Throw"'],
    "goto": ['parse_goto', 'STMT_GOTO'],
    "gosub": ['STMT_GOSUB'],
    "class": ['parse_class'],
    "end class": ['"End Class"'],
    "inherits": ['"Inherits"'],
    "interface": ['parse_interface', '"Interface"'],
    "implements": ['STMT_IMPLEMENTS', '"Implements"'],
    "property": ['parse_property'],
    "new": ['"New"'],
    "me": ['"Me"'],
    "with": ['parse_with', 'STMT_WITH'],
    "end with": ['"End With"'],
    "enum": ['parse_enum'],
    "type": ['parse_type'],
    "event": ['parse_event'],
    "raiseevent": ['parse_raise_event', 'STMT_RAISE_EVENT'],
    "withevents": ['"WithEvents"'],
    "print": ['parse_print', 'STMT_PRINT'],
    "line input": ['parse_input', '"Line Input"'],
    "data": ['parse_data', 'STMT_DATA'],
    "read": ['parse_read', 'STMT_READ'],
    "restore": ['STMT_RESTORE'],
    "using": ['parse_using', 'STMT_USING', '"Using"'],
    "doevents": ['DoEventsStatement', 'STMT_DO_EVENTS', '"DoEvents"'],
    "kill": ['parse_kill', 'STMT_KILL', '"Kill"'],
    "name": ['parse_name', 'STMT_NAME', '"Name"'],
    "end": ['"End"'],
    "async": ['STMT_ASYNC_FUNCTION', '"Async"'],
    "await": ['STMT_AWAIT', '"Await"'],
    "pass": ['STMT_PASS', '"Pass"'],
    "exit": ['STMT_EXIT', '"Exit"'],
    "continue": ['STMT_CONTINUE', '"Continue"'],
    "lambda": ['parse_lambda', 'LambdaNode', '"Lambda"'],
    "option explicit": ['"Option Explicit"', 'option_explicit'],
    "then": ['"Then"'],
}

# Statement keywords that must compile to bytecode (not interpreter-only)
STMT_COMPILER_MAP: dict[str, str] = {
    "doevents": "STMT_DO_EVENTS",
    "kill": "STMT_KILL",
    "name": "STMT_NAME",
}

# Bare call builtins that must exist in call_builtin (statement context / OP_CALL)
CALL_BUILTIN_REQUIRED = {
    "end", "msgbox", "inputbox", "addchild", "printform",
    "changescene", "loadform", "doevents", "cls", "clearscreen",
}

# Known namespace roots (detect_namespace_call)
NAMESPACE_ROOTS = {
    "camera", "sound", "speaker", "bus", "animation", "physics", "ray",
    "cell", "nav", "screen", "joypad", "touch", "sensor", "permission",
    "gps", "steps", "crypto", "theme", "js", "shader", "material",
    "skeleton", "bone", "video", "soundgen", "music", "tracker",
}

# Aliases documented but not wired in compiler
DOCUMENTED_ALIASES = {
    "speaker.bus": "speaker",  # nested namespace alias
    "physics.gravityv2": "physics_gravity",
    "physics.gravityv3": "physics_gravity",
}


@dataclass
class Entry:
    keyword: str
    syntax: str
    kind: str
    status: str  # ok | gap | partial | doc_only
    detail: str
    evidence: list[str]


def read_sources() -> dict[str, str]:
    texts: dict[str, str] = {}
    for path in SRC.rglob("*"):
        if path.suffix in (".cpp", ".h", ".inc") and path.is_file():
            texts[str(path.relative_to(ROOT))] = path.read_text(encoding="utf-8", errors="replace")
    return texts


def extract_help_entries(text: str) -> list[tuple[str, str, str]]:
    """Return (keyword, syntax, source_kind) for _add and _add_godot."""
    entries: list[tuple[str, str, str]] = []
    for m in re.finditer(r"_(add|add_godot)\(\s*\"([^\"]+)\"", text):
        kind = m.group(1)
        kw = m.group(2)
        # Grab syntax string (second string literal)
        rest = text[m.end():]
        sm = re.match(r'\s*,\s*\"((?:[^\"\\]|\\.)*)\"', rest, re.DOTALL)
        syntax = sm.group(1).replace("\\n", "\n") if sm else ""
        entries.append((kw, syntax, kind))
    return entries


def any_in_sources(texts: dict[str, str], needles: list[str]) -> list[str]:
    hits: list[str] = []
    for needle in needles:
        for fname, body in texts.items():
            if needle in body:
                hits.append(f"{fname}: {needle}")
                break
    return hits


def _builtin_needles(name: str) -> list[str]:
    lo = name.lower()
    title = name[:1].upper() + name[1:] if name else name
    return [
        f'METHOD_IS("{lo}")',
        f'name == "{name}"',
        f'name == "{title}"',
        f'method.nocasecmp_to("{name}")',
        f'method.nocasecmp_to("{title}")',
        f'->method_name.nocasecmp_to("{name}")',
        f'->method_name.nocasecmp_to("{title}")',
    ]


def check_builtin(name: str, texts: dict[str, str]) -> tuple[str, str, list[str]]:
    needles = _builtin_needles(name)
    impl_files = {
        k: v for k, v in texts.items()
        if any(x in k for x in ("builtins.cpp", "visual_gasic_instance.cpp", "instance_evaluate.inc", "bytecode_vm.cpp"))
    }
    hits = any_in_sources(impl_files, needles)
    if hits:
        return "ok", "runtime handler found", hits

    exec_files = {k: v for k, v in texts.items() if "execute.inc" in k}
    exec_hits = any_in_sources(exec_files, needles)
    if exec_hits:
        return "partial", "interpreter STMT_CALL only (not in dispatch_builtin_call / expr eval)", exec_hits

    return "gap", "no runtime handler found", []


def check_namespace(full: str, texts: dict[str, str]) -> tuple[str, str, list[str]]:
    parts = full.split(".")
    if len(parts) != 2:
        return "gap", "unexpected namespace shape", []

    root, method = parts[0].lower(), parts[1].lower()

    # Speaker.Bus alias — special nested form
    if root == "speaker" and method == "bus":
        compiler = texts.get("src/visual_gasic_compiler.cpp", "")
        if "speaker" in compiler and 'member_name.to_lower() == "bus"' in compiler:
            return "ok", "Speaker.Bus namespace alias", []
        return "partial", "Bus alias exists but Speaker.Bus nested access not rewritten", []

    if root == "bus":
        root = "speaker"

    if root not in NAMESPACE_ROOTS:
        return "gap", f"unknown namespace root '{root}'", []

    fn = f"{root}_{method}"
    needles = [f'METHOD_IS("{fn}")', f'"{fn}"']
    hits = any_in_sources({k: v for k, v in texts.items() if "builtins.cpp" in k}, needles)
    if hits:
        return "ok", f"namespace builtin {fn}", hits

    # GravityV2/V3 compile to physics_gravityv2 but handler may be physics_gravity only
    if fn in ("physics_gravityv2", "physics_gravityv3"):
        alt = any_in_sources({k: v for k, v in texts.items() if "builtins.cpp" in k}, ['METHOD_IS("physics_gravity")'])
        if alt:
            return "partial", f"compiles to {fn} but only physics_gravity handler exists", alt

    return "gap", f"missing namespace handler {fn}", []


def check_keyword(kw: str, texts: dict[str, str]) -> tuple[str, str, list[str]]:
    key = kw.lower()
    hints = KEYWORD_PARSER_HINTS.get(key, [f'"{kw}"', f'parse_{key.replace(" ", "_")}'])
    hits = any_in_sources(texts, hints)
    if not hits:
        return "gap", "no parser evidence", []

    # Compiler coverage for statements
    if key in STMT_COMPILER_MAP:
        stmt = STMT_COMPILER_MAP[key]
        comp = texts.get("src/visual_gasic_compiler.cpp", "")
        if f"case {stmt}:" not in comp:
            exec_hits = any_in_sources({k: v for k, v in texts.items() if "execute.inc" in k}, [stmt])
            if exec_hits:
                return "partial", f"parsed + interpreter ({stmt}) but no compiler case (bytecode falls back)", hits + exec_hits

    if (key == "throw"):
        parser = texts.get("src/visual_gasic_parser.cpp", "")
        if 'val == "throw"' not in parser and '"Throw"' not in parser:
            if "parse_raise" in parser or "STMT_RAISE" in parser:
                return "partial", "documented as Throw but parser only accepts Raise", hits

    if key == "interface":
        if "parse_interface" not in texts.get("src/visual_gasic_parser.cpp", ""):
            return "gap", "Interface...End Interface not parsed (Implements works)", hits

    if key == "using":
        if "parse_using" not in texts.get("src/visual_gasic_parser.cpp", ""):
            return "gap", "Using...End Using not parsed or executed", hits

    return "ok", "parser (+ compiler where required)", hits


def classify_entry(kw: str, syntax: str, source_kind: str) -> str:
    if source_kind == "add_godot":
        return "doc_only"
    if "." in kw:
        return "namespace"
    # Types / operators documented as keywords
    type_keywords = {
        "integer", "long", "single", "double", "string", "boolean", "bool",
        "variant", "object", "nothing", "true", "false", "and", "or", "not",
        "xor", "mod", "is", "like", "addressof", "typeof", "paramarray", "then",
    }
    if kw.lower() in type_keywords:
        return "type_or_op"
    control = {
        "if", "else", "elseif", "end if", "for", "for each", "next", "while", "wend",
        "do", "loop", "until", "select", "select case", "case", "end select", "dim", "global",
        "public", "private", "static", "const", "redim", "set", "sub", "end sub",
        "function", "end function", "call", "return", "byval", "byref", "optional",
        "on error", "try", "catch", "finally", "throw", "goto", "gosub", "class",
        "end class", "inherits", "interface", "implements", "property", "new", "me",
        "with", "end with", "enum", "type", "event", "raiseevent", "withevents",
        "print", "line input", "data", "read", "restore", "using", "doevents",
        "kill", "name", "end", "async", "await", "pass", "exit", "continue",
        "option explicit", "open", "close", "write", "input", "get", "put",
        "seek", "stop", "resume", "swap", "erase", "lock", "unlock", "module",
        "end module", "declare", "import", "export", "extends", "mustinherit",
        "mustoverride", "overrides", "shadows", "shared", "readonly", "operator",
        "synclock", "end synclock", "parallel", "end parallel", "task", "end task",
        "whenever", "end whenever", "pattern", "end pattern", "oscillate", "repeat",
        "end repeat", "cycle", "end cycle", "every", "end every", "tween", "lambda",
    }
    if kw.lower() in control:
        return "keyword"
    return "builtin"


def audit() -> list[Entry]:
    help_text = GD.read_text(encoding="utf-8")
    raw_entries = extract_help_entries(help_text)
    texts = read_sources()
    results: list[Entry] = []

    for kw, syntax, source_kind in raw_entries:
        kind = classify_entry(kw, syntax, source_kind)
        if kind == "doc_only":
            results.append(Entry(kw, syntax, kind, "doc_only", "Godot API cross-reference (not a VG builtin)", []))
            continue

        if kind == "namespace":
            status, detail, evidence = check_namespace(kw, texts)
        elif kind == "keyword":
            status, detail, evidence = check_keyword(kw, texts)
        elif kind == "type_or_op":
            if kw.lower() == "then":
                status, detail, evidence = "ok", "If-Then syntax token (not a standalone command)", any_in_sources(texts, ['"Then"'])
            else:
                status, detail, evidence = "ok", "language type/operator (parser)", any_in_sources(texts, [f'"{kw}"'])
        else:
            status, detail, evidence = check_builtin(kw, texts)

        results.append(Entry(kw, syntax, kind, status, detail, evidence))

    return results


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    results = audit()
    gaps = [r for r in results if r.status in ("gap", "partial")]
    ok = [r for r in results if r.status == "ok"]
    doc = [r for r in results if r.status == "doc_only"]

    if args.json:
        print(json.dumps([asdict(r) for r in results], indent=2))
        return 0

    print(f"Programmer's Reference audit — {len(results)} entries")
    print(f"  OK:        {len(ok)}")
    print(f"  Partial:   {len([r for r in gaps if r.status == 'partial'])}")
    print(f"  Missing:   {len([r for r in gaps if r.status == 'gap'])}")
    print(f"  Doc-only:  {len(doc)} (_add_godot Godot API links)")
    print()

    if gaps:
        print("=== GAPS & PARTIAL IMPLEMENTATIONS ===")
        for r in sorted(gaps, key=lambda x: (x.status, x.keyword.lower())):
            print(f"\n[{r.status.upper():7}] {r.keyword}")
            print(f"         {r.detail}")
            if r.evidence:
                for e in r.evidence[:3]:
                    print(f"         · {e}")
    else:
        print("All documented commands appear implemented.")

    return 1 if any(r.status == "gap" for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
