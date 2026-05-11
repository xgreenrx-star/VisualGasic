#!/usr/bin/env python3
"""Generate a Visual Basic 5 *Super Bible*-style command reference for
VisualGasic by extracting every entry from
`addons/visual_gasic/vg_command_help.gd` and emitting a per-command page
in alphabetical order.

The output replaces `docs/VisualGasic_Language_Reference.md`. The previous
manual is preserved as `docs/VisualGasic_Language_Reference_legacy.md`.

Layout (per command, in classic Super Bible voice):

    ## <Keyword>
    **Purpose**   — one-line headline (first sentence of `desc`)
    **Syntax**    — fenced code block from `syntax`
    **Parameters**— bullet list extracted from `syntax`
    **Description**— full prose from `desc`
    **Example**   — fenced code block from `code`
    **See Also**  — comma-separated cross-links to other commands

Tutorial chapters (Part I) are pulled verbatim from the legacy file at
known line ranges so users keep the language overview, IDE tour, OOP
chapter, etc. Version-numbered "enhancement" chapters and the old
keyword index are dropped because Part II supersedes them.
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GD = ROOT / "addons/visual_gasic/vg_command_help.gd"
LEGACY = ROOT / "docs/VisualGasic_Language_Reference_legacy.md"
NEW = ROOT / "docs/VisualGasic_Language_Reference.md"


# --- Tutorial chapters to carry over from the legacy file. ---------------
# Tuple of (heading_text, kept_in_new_part_i).
# The script looks up each heading in the legacy file by exact line match,
# then carries everything from that line up to (but not including) the
# next top-level `## ` chapter heading. This keeps content intact while
# letting us drop chapters we don't want (Built-in Functions, Alphabetical
# Index, version-numbered enhancement chapters).
PART_I_CHAPTERS = [
    "## Getting Started",
    "## The VisualGasic IDE",
    "## Language Basics",
    "## Control Flow",
    "## Procedures and Functions",
    "## Object-Oriented Features",
    "## VB6 Global Objects",
    "## COM-Style Objects",
    "## System Integration",
    "## System-Level Programming",
    "## Modern Language Features",
    "## Godot Integration",
]


# --- Parse vg_command_help.gd -------------------------------------------
def parse_help_db(text: str) -> list[dict]:
    """Return list of entries with keys: keyword, syntax, desc, code, ref_line."""
    entries: list[dict] = []
    # Match _add("kw", "syntax", "desc", "code"[, ref_line])  or
    # _add_godot("kw", "syntax", "desc", "code", "class", "method"[, ref_line])
    # Multi-line, with escaped quotes inside strings.
    pat = re.compile(
        r'\b_add(?:_godot)?\(\s*'
        r'"((?:[^"\\]|\\.)*)"\s*,\s*'
        r'"((?:[^"\\]|\\.)*)"\s*,\s*'
        r'"((?:[^"\\]|\\.)*)"\s*,\s*'
        r'"((?:[^"\\]|\\.)*)"'
        r'(?:\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)")?'
        r'(?:\s*,\s*(\d+))?\s*\)',
        re.S,
    )
    for m in pat.finditer(text):
        entries.append({
            "keyword": unescape(m.group(1)),
            "syntax": unescape(m.group(2)),
            "desc": unescape(m.group(3)),
            "code": unescape(m.group(4)),
            "godot_class": unescape(m.group(5)) if m.group(5) else "",
            "godot_method": unescape(m.group(6)) if m.group(6) else "",
            "ref_line": int(m.group(7)) if m.group(7) else 0,
        })
    return entries


def unescape(s: str) -> str:
    return (
        s.replace(r"\n", "\n")
         .replace(r"\t", "\t")
         .replace(r"\"", '"')
         .replace(r"\\", "\\")
    )


def parse_see_also(text: str) -> dict[str, list[str]]:
    """Parse `_build_see_also`'s `groups` array."""
    # Find the `groups` array literal.
    m = re.search(r"var groups[^\[]*\[(.*?)\n\t\]", text, re.S)
    if not m:
        return {}
    body = m.group(1)
    # Each group is `["a", "b", ...]` possibly spanning multiple lines.
    group_pat = re.compile(r"\[([^\]]+)\]", re.S)
    see: dict[str, list[str]] = {}
    for gm in group_pat.finditer(body):
        members = re.findall(r'"((?:[^"\\]|\\.)*)"', gm.group(1))
        for kw in members:
            for other in members:
                if other == kw:
                    continue
                see.setdefault(kw, []).append(other)
    # Dedupe while preserving order
    for k, v in see.items():
        seen = set()
        deduped = []
        for x in v:
            if x not in seen:
                deduped.append(x)
                seen.add(x)
        see[k] = deduped
    return see


# --- Markdown page rendering --------------------------------------------
def indent_code(code: str) -> str:
    """Render `code` as a 4-space-indented Markdown code block.

    Indented blocks are the most-portable code-block form: they render
    correctly in every Markdown engine, including basic ones that don't
    have the `fenced_code` extension enabled (e.g. Calibre's MD
    converter and some E-Book viewers). Fenced ```vb blocks render fine
    on GitHub but degrade to literal backticks elsewhere.
    """
    return "\n".join("    " + line if line else "" for line in code.splitlines())


def anchor_for(keyword: str) -> str:
    """GitHub-style anchor: lowercase, spaces->dashes, drop punctuation
    except dashes and dots (GitHub drops dots too)."""
    a = keyword.strip().lower()
    a = re.sub(r"[^a-z0-9 \-]+", "", a)
    a = re.sub(r"\s+", "-", a)
    return a


def split_syntax_params(syntax: str) -> list[str]:
    """Best-effort parameter extraction from a syntax string like
    `Camera.Shake intensity, duration [, cam]` or `Foo(arg1, arg2)`.
    Returns list of parameter names (no types)."""
    # Multi-line syntax means this is a block construct (If/For/Sub/Class
    # /etc.), not a function call — there are no callable parameters to
    # enumerate. Skip the Parameters section entirely in that case.
    if "\n" in syntax:
        return []
    s = syntax
    # If the syntax uses parentheses, take inside.
    pm = re.search(r"\(([^)]*)\)", s)
    if pm:
        inner = pm.group(1)
    else:
        # Otherwise, drop the leading keyword/identifier.
        # e.g. "Camera.Shake intensity, duration [, cam]"
        parts = s.split(None, 1)
        inner = parts[1] if len(parts) > 1 else ""
    # Strip [optional] brackets, then split on commas
    inner = inner.replace("[", "").replace("]", "")
    raw = [p.strip() for p in inner.split(",") if p.strip()]
    # Heuristic: drop trailing return-type suffix `As Foo`
    cleaned = []
    for p in raw:
        cleaned.append(re.sub(r"\s+As\s+\w+.*$", "", p, flags=re.IGNORECASE))
    return cleaned


def render_entry(entry: dict, see_also: list[str]) -> str:
    kw = entry["keyword"]
    out = [f"## {kw}\n"]

    # Purpose: first sentence of desc.
    desc = entry["desc"].strip()
    purpose = desc.split(". ", 1)[0].rstrip(".")
    if purpose:
        out.append(f"**Purpose** — {purpose}.\n")

    # Syntax
    syntax = entry["syntax"].strip()
    if syntax:
        out.append("**Syntax**\n")
        out.append(indent_code(syntax))
        out.append("")

    # Parameters (best effort)
    params = split_syntax_params(syntax)
    if params:
        out.append("**Parameters**\n")
        for p in params:
            out.append(f"- `{p}`")
        out.append("")

    # Description
    if desc:
        out.append("**Description**\n")
        out.append(desc + "\n")

    # Example
    code = entry["code"].strip()
    if code:
        out.append("**Example**\n")
        out.append(indent_code(code))
        out.append("")

    # Godot mapping
    gc = entry["godot_class"]
    if gc:
        gm = entry["godot_method"]
        target = f"{gc}.{gm}()" if gm else gc
        url = f"https://docs.godotengine.org/en/stable/classes/class_{gc.lower()}.html"
        if gm:
            url += f"#class-{gc.lower()}-method-{gm.lower()}"
        out.append(f"**Godot Mapping** — [`{target}`]({url})\n")

    # See Also
    if see_also:
        links = ", ".join(f"[{x}](#{anchor_for(x)})" for x in see_also)
        out.append(f"**See Also** — {links}\n")

    out.append("---\n")
    return "\n".join(out)


# --- Part I extraction ---------------------------------------------------
def extract_part_i(legacy_text: str) -> str:
    """Pull each kept chapter verbatim from the legacy manual."""
    lines = legacy_text.splitlines()
    idx_by_heading: dict[str, int] = {}
    for i, line in enumerate(lines):
        if line.startswith("## "):
            idx_by_heading[line.strip()] = i

    pieces: list[str] = []
    # Build the new ToC for Part I
    pieces.append("## Part I — Language Tutorials\n")
    pieces.append("These chapters explain the language and IDE end-to-end. ")
    pieces.append("For a per-command alphabetical reference, see ")
    pieces.append("[Part II — Command Reference](#part-ii--command-reference-az).\n")

    for heading in PART_I_CHAPTERS:
        if heading not in idx_by_heading:
            sys.stderr.write(f"WARN: chapter not found in legacy: {heading}\n")
            continue
        start = idx_by_heading[heading]
        # End at next top-level chapter (`## `) heading.
        end = len(lines)
        for j in range(start + 1, len(lines)):
            if lines[j].startswith("## "):
                end = j
                break
        chunk = "\n".join(lines[start:end])
        pieces.append(chunk)
    return "\n\n".join(pieces)


# --- Main ----------------------------------------------------------------
def main() -> int:
    if not LEGACY.exists():
        # First run: rename current manual to legacy.
        NEW.rename(LEGACY)
    legacy_text = LEGACY.read_text(encoding="utf-8")
    gd_text = GD.read_text(encoding="utf-8")
    entries = parse_help_db(gd_text)
    see_also_map = parse_see_also(gd_text)
    sys.stderr.write(f"Parsed {len(entries)} entries, {len(see_also_map)} see-also keys.\n")

    # Sort alphabetically (case-insensitive). Punctuation in `Foo.Bar`
    # sorts naturally with `.` < `A`.
    entries.sort(key=lambda e: e["keyword"].lower())

    # ----- Build new manual -----
    out: list[str] = []
    out.append("# VisualGasic Programmer's Reference\n")
    out.append(
        "*The classic Super Bible-style command reference for the "
        "VisualGasic BASIC language.*\n"
    )
    out.append(
        "This manual has two parts:\n\n"
        "* **Part I — Language Tutorials** explains the language, the IDE, "
        "and the major subsystems in a tutorial voice.\n"
        "* **Part II — Command Reference (A–Z)** has one dedicated page "
        "for every built-in keyword, function, and namespace verb in "
        "alphabetical order.\n"
    )

    # Part I
    part_i = extract_part_i(legacy_text)
    out.append(part_i)

    # Part II
    out.append("\n---\n")
    out.append("## Part II — Command Reference (A–Z)\n")
    out.append(
        f"Every one of the {len(entries)} built-in keywords, statements, "
        "functions, and namespace verbs documented by the Command Help "
        "panel gets a dedicated page below. Pages follow the classic "
        "*Visual Basic 5 Super Bible* layout: **Purpose**, **Syntax**, "
        "**Parameters**, **Description**, **Example**, and **See Also**.\n"
    )

    # Alpha section dividers (#, A, B, ...)
    current_letter = ""
    for entry in entries:
        kw = entry["keyword"]
        first = kw[0].upper()
        letter = first if first.isalpha() else "Symbols"
        if letter != current_letter:
            out.append(f"\n### {letter}\n")
            current_letter = letter
        sa = see_also_map.get(kw, [])
        out.append(render_entry(entry, sa))

    new_text = "\n".join(out) + "\n"
    NEW.write_text(new_text, encoding="utf-8")
    sys.stderr.write(f"Wrote {NEW} ({len(new_text):,} bytes, "
                     f"{new_text.count(chr(10)):,} lines)\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
