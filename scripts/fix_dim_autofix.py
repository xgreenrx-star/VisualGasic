#!/usr/bin/env python3
"""Conservative autofix for untyped Dim declarations.

This tool will scan all .bas files and replace untyped `Dim` statements
with typed equivalents using conservative heuristics. It supports a dry-run
mode (default) and an `--apply` flag to write changes.

Usage:
  ./scripts/fix_dim_autofix.py [--apply] [--backup]

Be cautious: this is an automated pass. Review changes before committing.
"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]

def infer_type_from_init(init):
    if init is None:
        return None
    s = init.strip()
    # String literal
    if re.match(r'^".*"$', s):
        return 'String'
    # Array constructor
    if re.match(r'^Array\s*\(', s, re.IGNORECASE):
        return 'Array'
    # CreateNode / CreateObject heuristics
    if re.search(r'CreateNode\(|CreateObject\(|Create\w+\(', s, re.IGNORECASE):
        return 'Object'
    if re.search(r'GetRect\(|Get[A-Za-z]+\(|\.Get[A-Za-z]+\(', s):
        return 'Object'
    # Numeric
    if re.match(r'^[+-]?\d+\.\d+$', s):
        return 'Double'
    if re.match(r'^[+-]?\d+$', s):
        return 'Integer'
    # Default conservative
    return 'Variant'

dim_re = re.compile(r'^(?P<prefix>\s*)(?P<body>Dim\s+(?P<vars>.+?))(\s*\'(?P<comment>.*))?$', re.IGNORECASE)

def process_line(line):
    m = dim_re.match(line)
    if not m:
        return None
    body = m.group('body')
    vars_part = m.group('vars')
    comment = m.group('comment')
    prefix = m.group('prefix') or ''

    # If 'As' present, skip
    if re.search(r'\bAs\b', vars_part, re.IGNORECASE):
        return None

    # Split by commas unless inside parentheses
    parts = []
    cur = ''
    depth = 0
    for ch in vars_part[len('Dim '):]:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ',' and depth == 0:
            parts.append(cur.strip())
            cur = ''
        else:
            cur += ch
    if cur.strip():
        parts.append(cur.strip())

    new_lines = []
    for part in parts:
        # part may include initializer: "name = expr" or array parentheses
        # Separate initializer
        if '=' in part:
            name, init = part.split('=', 1)
            name = name.strip()
            init = init.strip()
        else:
            name = part.strip()
            init = None

        # Detect array like name(3) or name(1,1)
        arr_match = re.match(r'(?P<n>[A-Za-z_][A-Za-z0-9_]*)\s*\(.*\)$', name)
        if arr_match:
            varname = arr_match.group('n')
            vartype = 'Array'
            # preserve parentheses
            parens = name[name.find('('):]
            new_lines.append(f"{prefix}Dim {varname}{parens} As {vartype}")
            continue

        # Plain name
        varname = name
        vartype = infer_type_from_init(init)
        if not vartype:
            vartype = 'Variant'
        new_lines.append(f"{prefix}Dim {varname} As {vartype}")

    # Reattach trailing comment to the last line if present
    if comment and new_lines:
        new_lines[-1] = new_lines[-1] + " '" + comment

    return '\n'.join(new_lines) + '\n'

def process_file(path, apply=False, backup=False):
    try:
        text = path.read_text(encoding='utf-8')
    except Exception:
        return False, None
    changed = False
    out_lines = []
    for line in text.splitlines(True):
        new = process_line(line)
        if new is None:
            out_lines.append(line)
        else:
            out_lines.append(new)
            changed = True
    if changed and apply:
        if backup:
            path.with_suffix(path.suffix + '.bak').write_text(text, encoding='utf-8')
        path.write_text(''.join(out_lines), encoding='utf-8')
    return changed, ''.join(out_lines)

def main():
    apply = '--apply' in sys.argv
    backup = '--backup' in sys.argv
    files = list(root.rglob('*.bas'))
    modified = []
    for f in files:
        changed, new_text = process_file(f, apply=False)
        if changed:
            modified.append(f.relative_to(root))
            if apply:
                process_file(f, apply=True, backup=backup)
    print(f"Files with changes: {len(modified)}")
    for m in modified[:200]:
        print(' -', m)
    if not modified:
        print('No changes detected.')

if __name__ == '__main__':
    main()
