#!/usr/bin/env python3
"""Tier 0: cross-check Programmer's Reference docs against engine dispatch.

Sources audited:
  - docs/VisualGasic_Language_Reference.md  (Part II commands with **Syntax**)
  - docs/reference/GODOT_FUNCTIONS_REFERENCE.md
  - addons/visual_gasic/vg_command_help.gd

Dispatch index built from all src/*.cpp, src/*.inc, src/**/*.cpp.

Usage:
  python3 scripts/audit_reference_dispatch.py
  python3 scripts/audit_reference_dispatch.py --json
  python3 scripts/audit_reference_dispatch.py --write-report
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, asdict, field
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANG_REF = ROOT / "docs" / "VisualGasic_Language_Reference.md"
GODOT_REF = ROOT / "docs" / "reference" / "GODOT_FUNCTIONS_REFERENCE.md"
COMMAND_HELP = ROOT / "addons" / "visual_gasic" / "vg_command_help.gd"
SRC = ROOT / "src"
REPORT_PATH = ROOT / "docs" / "audit" / "reference_dispatch_report.md"

# Documented symbols intentionally missing runtime or not global builtins.
KNOWN_GAPS: dict[str, str] = {
    "interface": "Interface...End Interface not parsed (Implements works)",
    "using": "Using...End Using not parsed or executed",
    "datafile": "Parse-time DATA statement — not a runtime call_builtin",
    "loaddata": "Runtime statement (STMT_LOAD_DATA) — not a global call_builtin",
    "spritedata": "Sprite Data asset docs — IDE/context rail feature; not a global builtin",
    "shutdown": "PyBridgeFacade.shutdown() instance method — not a global builtin",
    "speakerbus": "Speaker.Bus is compile-time alias for Speaker namespace",
    "connectsignal": "Deprecated name; runtime uses Connect()",
    "disconnectsignal": "Deprecated name; runtime uses Disconnect()",
    "emitsignal": "Use emit_signal() on owner or RaiseEvent for VB events",
}

# Class / facade methods documented as globals but live on a Godot class.
CLASS_METHOD_SYMBOLS: dict[str, str] = {
    "pybridgefacade": "PyBridgeFacade GDExtension class (ClassDB methods)",
    "pyimport": "PyBridgeFacade.PyImport",
    "pycall": "PyBridgeFacade.PyCall",
    "pycallasync": "PyBridgeFacade.PyCallAsync",
    "initializebridge": "PyBridgeFacade.InitializeBridge",
    "shutdown": "PyBridgeFacade.shutdown (instance method, not a global builtin)",
}

TYPE_AND_OP = {
    "integer", "long", "single", "double", "string", "boolean", "bool", "variant",
    "object", "nothing", "true", "false", "and", "or", "not", "xor", "mod", "is",
    "like", "addressof", "typeof", "paramarray", "then", "me", "new",
    "<<(shiftleft)", ">>(shiftright)",
}

LIFECYCLE = {"_draw", "_ready", "_process", "_physics_process", "_input"}

NAMESPACE_ROOTS = {
    "camera", "sound", "speaker", "bus", "animation", "physics", "ray", "cell",
    "nav", "screen", "joypad", "touch", "sensor", "permission", "gps", "steps",
    "crypto", "theme", "js", "shader", "material", "skeleton", "bone", "video",
    "soundgen", "music", "tracker",
}

KEYWORD_PARSER_HINTS: dict[str, list[str]] = {
    "if": ['parse_if', '"If"'],
    "else": ['"Else"'],
    "elseif": ['"ElseIf"'],
    "end if": ['"End If"'],
    "for": ['parse_for', '"For"'],
    "for each": ['"For Each"', "STMT_FOR_EACH"],
    "next": ['"Next"'],
    "while": ['parse_while'],
    "wend": ['"Wend"'],
    "do": ['parse_do'],
    "loop": ['"Loop"'],
    "until": ['"Until"'],
    "select": ['parse_select'],
    "select case": ['parse_select', '"Select Case"'],
    "case": ['"Case"'],
    "end select": ['"End Select"'],
    "dim": ['parse_dim', "STMT_DIM"],
    "let": ['val == "let"', 'is_block_scoped'],
    "global": ['"Global"'],
    "public": ['"Public"'],
    "private": ['"Private"'],
    "static": ['"Static"'],
    "const": ['parse_const', "STMT_CONST"],
    "redim": ['parse_redim', "STMT_REDIM"],
    "set": ['"Set"'],
    "sub": ['parse_sub'],
    "end sub": ['"End Sub"'],
    "function": ['parse_function', '"Function"'],
    "end function": ['"End Function"'],
    "call": ['"Call"'],
    "return": ["STMT_RETURN"],
    "byval": ['"ByVal"'],
    "byref": ['"ByRef"'],
    "optional": ['"Optional"'],
    "on error": ['parse_on_error', "STMT_ON_ERROR"],
    "try": ['parse_try', "STMT_TRY"],
    "catch": ['"Catch"'],
    "finally": ['"Finally"'],
    "throw": ['parse_raise', "STMT_RAISE", '"Throw"'],
    "goto": ['parse_goto', "STMT_GOTO"],
    "gosub": ["STMT_GOSUB"],
    "class": ['parse_class'],
    "end class": ['"End Class"'],
    "inherits": ['"Inherits"'],
    "implements": ["STMT_IMPLEMENTS", '"Implements"'],
    "property": ['parse_property'],
    "with": ['parse_with', "STMT_WITH"],
    "end with": ['"End With"'],
    "enum": ['parse_enum'],
    "type": ['parse_type'],
    "event": ['parse_event'],
    "raiseevent": ['parse_raise_event', "STMT_RAISE_EVENT"],
    "withevents": ['"WithEvents"'],
    "print": ['parse_print', "STMT_PRINT"],
    "line input": ['parse_input', '"Line Input"'],
    "data": ['parse_data', "STMT_DATA"],
    "read": ['parse_read', "STMT_READ"],
    "restore": ["STMT_RESTORE"],
    "doevents": ["STMT_DO_EVENTS", '"DoEvents"'],
    "kill": ['parse_kill', "STMT_KILL"],
    "name": ['parse_name', "STMT_NAME"],
    "end": ['"End"'],
    "async": ["STMT_ASYNC_FUNCTION", '"Async"'],
    "await": ["STMT_AWAIT", '"Await"'],
    "pass": ["STMT_PASS", '"Pass"'],
    "exit": ["STMT_EXIT", '"Exit"'],
    "continue": ["STMT_CONTINUE", '"Continue"'],
    "lambda": ['parse_lambda', '"Lambda"'],
    "option explicit": ['"Option Explicit"', 'option_explicit'],
    "open": ['parse_open'],
    "close": ['"Close"'],
    "write": ['"Write"'],
    "input": ['parse_input'],
    "get": ['"Get"'],
    "put": ['"Put"'],
    "seek": ['"Seek"'],
    "stop": ['"Stop"'],
    "resume": ['"Resume"'],
    "swap": ['"Swap"'],
    "erase": ['"Erase"'],
    "lock": ['"Lock"'],
    "unlock": ['"Unlock"'],
    "module": ['"Module"'],
    "end module": ['"End Module"'],
    "declare": ['"Declare"'],
    "import": ['"Import"'],
    "export": ['"Export"'],
    "extends": ['"Extends"'],
    "parallel": ['"Parallel"'],
    "end parallel": ['"End Parallel"'],
    "task": ['"Task"'],
    "end task": ['"End Task"'],
    "whenever": ['"Whenever"'],
    "end whenever": ['"End Whenever"'],
    "pattern": ['"Pattern"'],
    "end pattern": ['"End Pattern"'],
    "oscillate": ['"Oscillate"'],
    "repeat": ['"Repeat"'],
    "end repeat": ['"End Repeat"'],
    "cycle": ['"Cycle"'],
    "end cycle": ['"End Cycle"'],
    "every": ['"Every"'],
    "end every": ['"End Every"'],
    "tween": ['"Tween"'],
    "synclock": ['"SyncLock"'],
    "end synclock": ['"End SyncLock"'],
}


def norm(name: str) -> str:
    return re.sub(r"[_\s.]", "", name.lower())


@dataclass
class DocEntry:
    name: str
    source: str
    line: int
    kind: str


@dataclass
class Finding:
    name: str
    status: str  # missing | partial | mismatch | ok | known | skip
    detail: str
    sources: list[str] = field(default_factory=list)
    evidence: list[str] = field(default_factory=list)


def read_sources() -> dict[str, str]:
    texts: dict[str, str] = {}
    for path in SRC.rglob("*"):
        if path.suffix in (".cpp", ".h", ".inc") and path.is_file():
            texts[str(path.relative_to(ROOT))] = path.read_text(encoding="utf-8", errors="replace")
    return texts


def build_dispatch_index(texts: dict[str, str]) -> tuple[set[str], dict[str, list[str]]]:
    """Return normalized dispatch names and where they were found."""
    patterns = [
        (r'if \(method == "([^"]+)"', "expr_compat"),
        (r'method\.nocasecmp_to\("([^"]+)"\)', "method_call"),
        (r'METHOD_IS\("([^"]+)"\)', "METHOD_IS"),
        (r'name == "([^"]+)"', "name_eq"),
        (r'name\.nocasecmp_to\("([^"]+)"\)', "name_nocase"),
        (r'->method_name\.nocasecmp_to\("([^"]+)"\)', "method_name"),
        (r'keywords\.push_back\("([^"]+)"\)', "keyword"),
    ]
    names: set[str] = set()
    locs: dict[str, list[str]] = defaultdict(list)

    for fname, body in texts.items():
        for pat, tag in patterns:
            for m in re.finditer(pat, body):
                key = norm(m.group(1))
                names.add(key)
                locs[key].append(f"{fname}:{tag}:{m.group(1)}")
        if "vg_godot_owner_builtins.cpp" in fname:
            for m in re.finditer(r'\bM\("([a-z0-9_]+)"\)', body):
                raw = m.group(1)
                key = norm(raw)
                names.add(key)
                locs[key].append(f"{fname}:owner_builtin:{raw}")

    # Bytecode VM fast-path special call names (lowercase literals)
    vm = texts.get("src/visual_gasic_instance_bytecode_vm.cpp", "")
    for m in re.finditer(r'"([a-z][a-z0-9_]*)"', vm[vm.find("_vg_special_call_names"): vm.find("_vg_special_call_names") + 2500] if "_vg_special_call_names" in vm else ""):
        key = norm(m.group(1))
        if len(key) > 2:
            names.add(key)
            locs[key].append(f"bytecode_vm:special:{m.group(1)}")

    return names, locs


def snake_to_pascal(name: str) -> str:
    return "".join(p[:1].upper() + p[1:] for p in name.split("_") if p)


def syntax_kind(section: str) -> str:
    m = re.search(r"\*\*Syntax\*\*\s*\n+\s*(.+)", section)
    if not m:
        return "unknown"
    line = m.group(1).strip()
    if re.search(r"\bAs\s+(Single|Double|Integer|String|Boolean|Variant|Object)\s*$", line, re.I):
        return "parameter_doc"
    if "(" in line:
        return "callable"
    return "unknown"


def parse_lang_ref(path: Path) -> list[DocEntry]:
    text = path.read_text(encoding="utf-8")
    start = text.find("## Part II — Command Reference")
    chunk = text[start:] if start >= 0 else text
    base_line = text[:start].count("\n") + 1 if start >= 0 else 1
    entries: list[DocEntry] = []

    for m in re.finditer(r"^## ([^\n]+)\n", chunk, re.MULTILINE):
        name = m.group(1).strip()
        if name.startswith("Part ") or name in {"Table of Contents", "Symbols"}:
            continue
        sec_start = m.end()
        nxt = re.search(r"^## ", chunk[sec_start:], re.MULTILINE)
        section = chunk[sec_start: sec_start + nxt.start()] if nxt else chunk[sec_start:]
        if "**Syntax**" not in section:
            continue
        sk = syntax_kind(section)
        if sk == "parameter_doc":
            kind = "parameter_doc"
        else:
            kind = classify_symbol(name)
        line = base_line + chunk[: m.start()].count("\n")
        entries.append(DocEntry(name, "language_reference", line, kind))
    return entries


def parse_godot_ref(path: Path) -> list[DocEntry]:
    if not path.is_file():
        return []
    text = path.read_text(encoding="utf-8")
    entries: list[DocEntry] = []
    for m in re.finditer(r"^### ([^\n]+)\n", text, re.MULTILINE):
        raw = m.group(1).strip()
        if re.match(r"^[A-Z] \{#index", raw) or raw.lower().startswith("example "):
            continue
        name = re.sub(r"\(.*", "", raw).strip()
        if name in {"Engine", "DisplayServer", "AudioServer"}:
            kind = "godot_singleton_doc"
        else:
            kind = classify_symbol(name)
        line = text[: m.start()].count("\n") + 1
        entries.append(DocEntry(name, "godot_functions_reference", line, kind))
    return entries


def parse_command_help(path: Path) -> list[DocEntry]:
    text = path.read_text(encoding="utf-8")
    entries: list[DocEntry] = []
    for m in re.finditer(r'_add(?:_godot)?\(\s*"([^"]+)"', text):
        name = m.group(1).strip()
        kind = "godot_doc_link" if m.group(0).startswith("_add_godot") else classify_symbol(name)
        line = text[: m.start()].count("\n") + 1
        entries.append(DocEntry(name, "command_help", line, kind))
    return entries


def classify_symbol(name: str) -> str:
    key = name.lower()
    if key in LIFECYCLE:
        return "lifecycle"
    if key in TYPE_AND_OP or norm(name) in TYPE_AND_OP:
        return "type_or_op"
    if "<<" in name or ">>" in name or "shift" in key:
        return "type_or_op"
    if "." in name:
        return "namespace"
    if key in KEYWORD_PARSER_HINTS:
        return "keyword"
    if re.match(r"^[a-z][a-z0-9_]*$", name):
        return "snake_callable"
    return "builtin"


def any_in_sources(texts: dict[str, str], needles: list[str]) -> list[str]:
    hits: list[str] = []
    for needle in needles:
        for fname, body in texts.items():
            if needle in body:
                hits.append(f"{fname}: {needle}")
                break
    return hits


def builtin_needles(name: str) -> list[str]:
    lo = name.lower()
    title = name[:1].upper() + name[1:] if name else name
    pascal = "".join(p[:1].upper() + p[1:] for p in re.split(r"[\s_]+", name) if p)
    return list({
        f'METHOD_IS("{lo}")',
        f'method == "{name}"',
        f'method == "{title}"',
        f'method == "{pascal}"',
        f'method.nocasecmp_to("{name}")',
        f'method.nocasecmp_to("{title}")',
        f'method.nocasecmp_to("{pascal}")',
        f'name == "{name}"',
        f'name == "{title}"',
    })


def check_entry(entry: DocEntry, dispatch: set[str], locs: dict[str, list[str]], texts: dict[str, str]) -> Finding:
    key = norm(entry.name)
    sources = [f"{entry.source}:{entry.line}"]

    if entry.kind == "godot_doc_link":
        return Finding(entry.name, "skip", "command_help _add_godot cross-link (not a VG builtin)", sources)

    if entry.kind in ("type_or_op", "lifecycle", "parameter_doc", "godot_singleton_doc"):
        return Finding(entry.name, "skip", f"{entry.kind} (not a dispatch builtin)", sources)

    if key in KNOWN_GAPS:
        return Finding(entry.name, "known", KNOWN_GAPS[key], sources)

    if key in CLASS_METHOD_SYMBOLS:
        return Finding(entry.name, "skip", CLASS_METHOD_SYMBOLS[key], sources)

    if entry.kind == "snake_callable":
        pascal = snake_to_pascal(entry.name)
        for alias in (entry.name, pascal, pascal + "()"):
            if norm(alias) in dispatch:
                ev = locs.get(norm(alias), [])[:3]
                return Finding(entry.name, "ok", f"snake_case doc → dispatch as {pascal}", sources, ev)
        hits = any_in_sources(texts, builtin_needles(pascal))
        if hits:
            return Finding(entry.name, "ok", f"snake_case doc → handler as {pascal}", sources, hits[:3])
        return Finding(
            entry.name,
            "missing",
            f"snake_case API documented; no dispatch for {entry.name} or {pascal}",
            sources,
        )

    if entry.kind == "keyword":
        hints = KEYWORD_PARSER_HINTS.get(entry.name.lower(), [f'"{entry.name}"'])
        hits = any_in_sources(texts, hints)
        if hits:
            return Finding(entry.name, "ok", "parser/statement evidence", sources, hits[:3])
        return Finding(entry.name, "missing", "documented keyword — no parser evidence", sources)

    if entry.kind == "namespace":
        root, method = entry.name.split(".", 1)
        root_key = "speaker" if root.lower() == "bus" else root.lower()
        if root_key not in NAMESPACE_ROOTS:
            return Finding(entry.name, "missing", f"unknown namespace root '{root}'", sources)
        fn = f"{root_key}_{method.lower()}"
        if norm(fn) in dispatch or norm(method) in dispatch:
            ev = locs.get(norm(fn), locs.get(norm(method), []))[:3]
            return Finding(entry.name, "ok", f"namespace handler {fn}", sources, ev)
        return Finding(entry.name, "missing", f"no namespace handler for {fn}", sources)

    # Builtin / Input method
    if key in dispatch:
        ev = locs.get(key, [])[:3]
        return Finding(entry.name, "ok", "runtime dispatch found", sources, ev)

    hits = any_in_sources(texts, builtin_needles(entry.name))
    if hits:
        return Finding(entry.name, "ok", "runtime handler (needle match)", sources, hits[:3])

    return Finding(entry.name, "missing", "documented but no dispatch site in src/", sources)


def doc_source_mismatches(all_entries: dict[str, list[DocEntry]]) -> list[Finding]:
    """Symbols in one authoritative doc but absent from others."""
    lr = {norm(e.name): e for e in all_entries.get("language_reference", [])}
    ch = {norm(e.name): e for e in all_entries.get("command_help", [])}
    gr = {norm(e.name): e for e in all_entries.get("godot_functions_reference", [])}

    findings: list[Finding] = []
    for key, entry in gr.items():
        if entry.kind in ("type_or_op", "lifecycle"):
            continue
        if key not in lr and key not in ch:
            findings.append(Finding(
                entry.name,
                "mismatch",
                "in GODOT_FUNCTIONS_REFERENCE but not Language Reference or command_help",
                [f"godot_functions_reference:{entry.line}"],
            ))
    return findings


def audit() -> tuple[list[Finding], dict[str, list[DocEntry]]]:
    texts = read_sources()
    dispatch, locs = build_dispatch_index(texts)

    all_entries = {
        "language_reference": parse_lang_ref(LANG_REF),
        "godot_functions_reference": parse_godot_ref(GODOT_REF),
        "command_help": parse_command_help(COMMAND_HELP),
    }

    findings: list[Finding] = []
    seen: set[str] = set()

    for source, entries in all_entries.items():
        for entry in entries:
            nkey = norm(entry.name)
            if (source, nkey) in seen:
                continue
            seen.add((source, nkey))
            findings.append(check_entry(entry, dispatch, locs, texts))

    findings.extend(doc_source_mismatches(all_entries))
    return findings, all_entries


def write_report(findings: list[Finding], all_entries: dict[str, list[DocEntry]]) -> None:
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    today = date.today().isoformat()
    missing = [f for f in findings if f.status == "missing"]
    mismatch = [f for f in findings if f.status == "mismatch"]
    known = [f for f in findings if f.status == "known"]
    ok = [f for f in findings if f.status == "ok"]

    lines = [
        "# Reference dispatch audit report",
        "",
        f"Generated: {today} by `scripts/audit_reference_dispatch.py`",
        "",
        "## Summary",
        "",
        f"| Metric | Count |",
        f"|--------|------:|",
        f"| Language Reference commands (Part II) | {len(all_entries.get('language_reference', []))} |",
        f"| GODOT_FUNCTIONS_REFERENCE entries | {len(all_entries.get('godot_functions_reference', []))} |",
        f"| command_help entries | {len(all_entries.get('command_help', []))} |",
        f"| OK / dispatch found | {len(ok)} |",
        f"| Known gaps (allowlisted) | {len(known)} |",
        f"| **Missing dispatch** | **{len(missing)}** |",
        f"| Doc source mismatch | {len(mismatch)} |",
        "",
    ]

    if missing:
        lines += ["## Missing dispatch (action required)", ""]
        for f in sorted(missing, key=lambda x: x.name.lower()):
            lines.append(f"- **{f.name}** — {f.detail}")
            for s in f.sources:
                lines.append(f"  - {s}")
        lines.append("")

    if mismatch:
        lines += ["## Doc source mismatches", ""]
        for f in sorted(mismatch, key=lambda x: x.name.lower()):
            lines.append(f"- **{f.name}** — {f.detail}")
        lines.append("")

    if known:
        lines += ["## Known gaps (allowlisted)", ""]
        for f in sorted(known, key=lambda x: x.name.lower()):
            lines.append(f"- **{f.name}** — {f.detail}")
        lines.append("")

    lines += [
        "## How to run",
        "",
        "```bash",
        "python3 scripts/audit_reference_dispatch.py",
        "python3 scripts/audit_reference_dispatch.py --write-report",
        "```",
        "",
    ]
    REPORT_PATH.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--write-report", action="store_true")
    ap.add_argument(
        "--warn-only",
        action="store_true",
        help="Exit 0 even when missing dispatch (report only; use until baseline is clean)",
    )
    args = ap.parse_args()

    findings, all_entries = audit()
    missing = [f for f in findings if f.status == "missing"]
    mismatch = [f for f in findings if f.status == "mismatch"]
    ok = [f for f in findings if f.status == "ok"]
    known = [f for f in findings if f.status == "known"]

    if args.json:
        print(json.dumps([asdict(f) for f in findings], indent=2))
        return 0 if args.warn_only else (1 if missing else 0)

    print("Reference dispatch audit (Tier 0)")
    print(f"  Language Reference (Part II):  {len(all_entries.get('language_reference', []))}")
    print(f"  GODOT_FUNCTIONS_REFERENCE:     {len(all_entries.get('godot_functions_reference', []))}")
    print(f"  command_help:                  {len(all_entries.get('command_help', []))}")
    print(f"  OK:                            {len(ok)}")
    print(f"  Known gaps:                    {len(known)}")
    print(f"  Missing dispatch:              {len(missing)}")
    print(f"  Doc source mismatch:           {len(mismatch)}")
    print()

    if missing:
        print("=== MISSING DISPATCH ===")
        for f in sorted(missing, key=lambda x: x.name.lower()):
            print(f"  {f.name}")
            print(f"    {f.detail}")
            for s in f.sources[:2]:
                print(f"    · {s}")
        print()

    if mismatch:
        print("=== DOC SOURCE MISMATCH (sample, first 20) ===")
        for f in sorted(mismatch, key=lambda x: x.name.lower())[:20]:
            print(f"  {f.name} — {f.detail}")
        if len(mismatch) > 20:
            print(f"  ... and {len(mismatch) - 20} more")
        print()

    if args.write_report:
        write_report(findings, all_entries)
        print(f"Report written: {REPORT_PATH.relative_to(ROOT)}")

    return 0 if args.warn_only else (1 if missing else 0)


if __name__ == "__main__":
    sys.exit(main())
