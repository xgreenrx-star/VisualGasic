#!/usr/bin/env python3
"""Simple linter: fail if any 'Dim' declarations lack an 'As' type.

Scans all .bas files under the repository and prints offending lines.
Exit code 0 if clean, 2 if violations found.
"""
import sys
import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1]
pattern = re.compile(r'^\s*Dim\b', re.IGNORECASE)

# Default target: only check demo/builtin_tests and top-level test_*.bas files to avoid
# failing on a large body of historical example code. Use --all to scan the entire repo.
targets = []
if len(sys.argv) > 1 and sys.argv[1] == '--all':
    targets = list(root.rglob('*.bas'))
else:
    # Specific demo/test files we care about for enforcement
    targets = []
    demo_dir = root / 'demo' / 'builtin_tests'
    if demo_dir.exists():
        targets.extend(demo_dir.rglob('*.bas'))
    for name in ['test_builtins.bas', 'demo/test_builtins.bas']:
        p = root / name
        if p.exists():
            targets.append(p)

violations = []
for p in targets:
    try:
        text = p.read_text(encoding='utf-8')
    except Exception:
        continue
    for i, line in enumerate(text.splitlines(), start=1):
        if pattern.search(line):
            # If 'As' present later on the same line, it's fine.
            if re.search(r'\bAs\b', line, re.IGNORECASE):
                continue
            # Skip lines that are comments only
            stripped = line.strip()
            if stripped.startswith("'") or stripped.upper().startswith('REM '):
                continue
            violations.append(f"{p.relative_to(root)}:{i}: {line.strip()}")

if violations:
    print("Untyped 'Dim' declarations found:")
    for v in violations:
        print(' -', v)
    sys.exit(2)
else:
    print("No untyped 'Dim' declarations found.")
    sys.exit(0)
