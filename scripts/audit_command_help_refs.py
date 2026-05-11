#!/usr/bin/env python3
"""Audit and update `ref_line` values in addons/visual_gasic/vg_command_help.gd
so each Command Help entry points to a real, relevant line in
docs/VisualGasic_Language_Reference.md.

Strategy (in priority order, per keyword):
  1. Table row `| `Keyword`` or `| `Keyword(` (most precise)
  2. Heading `### Keyword` / `#### Keyword`
  3. Namespace heading `### Foo namespace` (for `Foo.Bar` keywords)
  4. Inline backtick mention `` `Keyword` ``

If no good anchor is found, ref_line is set to 0 (no link in UI).

Run with --dry-run to preview, or --write to patch the .gd file in place.
"""
from __future__ import annotations
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GD = ROOT / "addons/visual_gasic/vg_command_help.gd"
MANUAL = ROOT / "docs/VisualGasic_Language_Reference.md"


def load_manual_index() -> list[str]:
    return MANUAL.read_text(encoding="utf-8").splitlines()


def find_ref_line(keyword: str, lines: list[str], index_start: int) -> int:
    """Return the best 1-based line number in the manual for `keyword`, or 0.

    Only emits a non-zero line when a strong anchor exists:
      1. Table row `| `Keyword`` (or `Keyword(`) — definition table entry.
      2. Heading `### Keyword` exactly (or `### Keyword Function`, etc.).
      3. For `Foo.Bar` keys, fall back to `### Foo namespace` heading.

    Inline mentions inside paragraph text or keyword-list dumps are ignored
    because they give bogus "page numbers" that aren't real definitions.
    """
    kw = keyword
    kw_re = re.escape(kw)

    # HIGHEST PRIORITY: a dedicated Part II command-reference page header
    # `## Keyword` — exact match on the heading line. This is what we
    # always want to land on if the per-command page exists.
    page_pat = re.compile(rf"^##\s+{kw_re}\s*$")
    for i, line in enumerate(lines, 1):
        if i >= index_start:
            break
        if page_pat.match(line):
            return i

    # Table row: starts with `|` then optional space, then `Keyword` in
    # backticks. Allow trailing `(` for callable rows.
    pat_table = re.compile(rf"^\|\s*`{kw_re}(?:\(|`)", re.IGNORECASE)

    # Heading whose title IS the keyword (possibly followed by a parenthetical
    # qualifier like " — Description" or " Function" / " Statement").
    pat_head = re.compile(
        rf"^#{{2,6}}\s+\*{{0,2}}`?{kw_re}`?\*{{0,2}}(\s*(\(|—|-|—)|\s+(Function|Statement|Keyword|Object|Loop|Type|Block|Operator|Clause|Constant|Constants|Functions|Operators|Statements|namespace)\b|\s*$)",
        re.IGNORECASE,
    )

    # Namespace heading for `Foo.Bar`
    ns_head = None
    if "." in kw:
        ns = kw.split(".")[0]
        ns_head = re.compile(rf"^#{{2,6}}\s+{re.escape(ns)}\s+namespace", re.IGNORECASE)

    tbl: list[int] = []
    hd: list[int] = []
    nsh: list[int] = []
    for i, line in enumerate(lines, 1):
        if i >= index_start:
            break  # ignore the alphabetical index region
        if pat_table.search(line):
            tbl.append(i)
        if pat_head.search(line):
            hd.append(i)
        if ns_head and ns_head.search(line):
            nsh.append(i)

    # Prefer the FIRST table row (definition table). Headings: prefer
    # last (most recent version chapter often supersedes older entry).
    if tbl:
        return tbl[0]
    if hd:
        return hd[-1]
    if nsh:
        return nsh[0]

    # Fallback: find the FIRST occurrence of `Keyword` (in code fence or
    # parenthetical) anywhere in the body, and return the line number of
    # the *enclosing section heading* — i.e. the last `### / ####` heading
    # before that mention. This avoids landing in mid-paragraph.
    mention = re.compile(rf"`{kw_re}\b")
    last_head = 0
    head_pat = re.compile(r"^#{2,6}\s+")
    for i, line in enumerate(lines, 1):
        if i >= index_start:
            break
        if head_pat.match(line):
            last_head = i
            continue
        if mention.search(line) and last_head:
            return last_head
    return 0


# Some keywords are too generic for a useful manual link; force 0 to suppress.
SUPPRESS = {
    "True", "False", "Nothing", "And", "Or", "Not", "Xor", "Mod",
    "End", "Option Explicit",
    # graphics primitives have no dedicated section in the manual
}

# Curated overrides for well-known VB6 keywords whose canonical manual
# section uses a different word (e.g. `Sub` is documented under
# `### Subroutines`). These point at section *headings* (1-based line
# numbers) in docs/VisualGasic_Language_Reference.md.
CURATED: dict[str, str] = {
    # Procedures & Functions
    "Sub": "### Subroutines",
    "End Sub": "### Subroutines",
    "Function": "### Functions",
    "End Function": "### Functions",
    "Call": "### Subroutines",
    "Return": "#### GoSub / Return",
    "ByVal": "### Parameters",
    "ByRef": "### Parameters",
    "Optional": "### Optional Parameters",
    # Variables & Types
    "Dim": "#### Variable Declaration",
    "Public": "#### Variable Declaration",
    "Private": "#### Variable Declaration",
    "Const": "#### Variable Declaration",
    "ReDim": "#### Variable Declaration",
    "Static": "### Static Local Variables",
    "Set": "#### Variable Declaration",
    # Control Flow
    "Else": "#### If-Then-Else",
    "ElseIf": "#### If-Then-Else",
    "Then": "#### If-Then-Else",
    "End If": "#### If-Then-Else",
    "Case": "### Select Case",
    "End Select": "### Select Case",
    "Select": "### Select Case",
    "For Each": "#### For-Each Loop",
    "Next": "#### For-Next Loop",
    "Wend": "#### While-Wend Loop",
    "Loop": "#### Do-Loop",
    "Until": "#### Do-Loop",
    "Exit": "### Subroutines",
    # Error handling
    "On Error": "#### On Error Resume Next",
    "Try": "### Error Handling",
    "Catch": "### Error Handling",
    "Finally": "### Error Handling",
    "Throw": "### Error Handling",
    "GoTo": "### Error Handling",
    "GoSub": "#### GoSub / Return",
    # OOP
    "Class": "### Classes and Types",
    "End Class": "### Classes and Types",
    "Inherits": "### Inheritance",
    "Interface": "### Interfaces",
    "Property": "### Properties and Methods",
    "Me": "### Properties and Methods",
    "New": "### Parameterized Constructors",
    "With": "## COM-Style Objects",
    "End With": "## COM-Style Objects",
    "Enum": "#### Variable Declaration",
    "Type": "### Classes and Types",
    "Event": "### Events (WithEvents / RaiseEvent)",
    "RaiseEvent": "### Events (WithEvents / RaiseEvent)",
    "WithEvents": "### Events (WithEvents / RaiseEvent)",
    # I/O
    "Print": "### Print Semicolons (Multiple Expressions)",
    "MsgBox": "#### **I/O Operations**",
    "InputBox": "#### **I/O Operations**",
    "Line Input": "#### File I/O Statements",
    # Data statements
    "Data": "### Classic DATA Statements",
    "Read": "### Classic DATA Statements",
    "Restore": "#### RESTORE Statement",
    # Arrays
    "UBound": "### Array Functions",
    "LBound": "### Array Functions",
    # Async/Modern
    "DoEvents": "### Multitasking and Concurrency",
}


def resolve_curated(lines: list[str]) -> dict[str, int]:
    """Resolve each curated heading title to an actual line number."""
    resolved: dict[str, int] = {}
    for kw, heading in CURATED.items():
        for i, line in enumerate(lines, 1):
            if line.strip() == heading.strip():
                resolved[kw] = i
                break
    return resolved


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="patch the .gd file")
    ap.add_argument("--dry-run", action="store_true", help="show changes only")
    args = ap.parse_args()
    if not args.write and not args.dry_run:
        args.dry_run = True

    lines = load_manual_index()
    # Find Alphabetical Index start to cap candidates
    index_start = len(lines) + 1
    for i, line in enumerate(lines, 1):
        if line.startswith("## Alphabetical Index"):
            index_start = i
            break
    curated = resolve_curated(lines)
    # Report any unresolved curated entries so the table stays honest.
    missing = [kw for kw in CURATED if kw not in curated]
    if missing:
        sys.stderr.write("WARN: curated headings not found for: " + ", ".join(missing) + "\n")
    src = GD.read_text(encoding="utf-8")

    # Match _add("Keyword", "syntax", "desc", "code"[, ref_line])
    # The block can span multiple lines; capture greedy until balanced ")".
    out_chunks: list[str] = []
    pos = 0
    changes = 0
    examined = 0
    pat_call = re.compile(r"_add\(\s*\"([^\"]+)\"")
    while True:
        m = pat_call.search(src, pos)
        if not m:
            out_chunks.append(src[pos:])
            break
        # Find end of this _add(...) call by tracking parens
        start = m.start()
        depth = 0
        i = start
        while i < len(src):
            ch = src[i]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        if depth != 0:
            sys.stderr.write(f"unbalanced _add at offset {start}\n")
            return 1
        end = i + 1
        block = src[start:end]
        kw = m.group(1)
        examined += 1

        # Extract current trailing ref_line (last integer before final ")")
        # Replace the entire block's ref param tail.
        if kw in SUPPRESS:
            new_ref = 0
        else:
            new_ref = find_ref_line(kw, lines, index_start)
            # Curated headings are only a fallback when find_ref_line can't
            # locate the keyword (rare, since every entry now has a Part II
            # `## Keyword` page).
            if new_ref == 0 and kw in curated:
                new_ref = curated[kw]

        # Check current ref
        m_cur = re.search(r",\s*(\d+)\s*\)\s*$", block)
        if m_cur:
            cur_ref = int(m_cur.group(1))
        else:
            cur_ref = 0

        if cur_ref != new_ref:
            changes += 1
            # Modify block: either replace existing trailing ref, or add one.
            if m_cur:
                new_block = block[: m_cur.start()] + ("," if new_ref > 0 else "") + (f" {new_ref})" if new_ref > 0 else ")")
                # ↑ if new_ref==0, drop the parameter entirely
                # rebuild cleanly:
                head = block[: m_cur.start()].rstrip()
                if new_ref > 0:
                    new_block = head + f", {new_ref})"
                else:
                    new_block = head + ")"
            else:
                # No trailing ref_line — append before final ")"
                if new_ref > 0:
                    inner = block[:-1].rstrip()
                    new_block = inner + f", {new_ref})"
                else:
                    new_block = block
            if args.dry_run:
                print(f"  {kw:32s}  {cur_ref:>5} -> {new_ref}")
        else:
            new_block = block

        out_chunks.append(src[pos:start])
        out_chunks.append(new_block)
        pos = end

    new_src = "".join(out_chunks)
    print(f"\nExamined {examined} entries, {changes} changes.")
    if args.write:
        GD.write_text(new_src, encoding="utf-8")
        print(f"Wrote {GD}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
