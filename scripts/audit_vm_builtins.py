#!/usr/bin/env python3
"""Audit Visual Gasic expr-builtin coverage across dispatch paths.

Compares METHOD_IS handlers in:
  - call_builtin_expr_evaluated (bytecode VM primary path)
  - call_builtin_expr fallback (legacy AST secondary)
  - dispatch_expr_compat_call (shared Godot integration)

Exit 0 if no gaps; exit 1 and print gaps otherwise.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILTINS = ROOT / "src" / "visual_gasic_builtins.cpp"
COMPAT = ROOT / "src" / "visual_gasic_instance_expr_compat.inc"


def extract_method_is(path: Path, start_marker: str, end_marker: str | None = None) -> set[str]:
    text = path.read_text()
    start = text.find(start_marker)
    if start < 0:
        return set()
    chunk = text[start:]
    if end_marker:
        end = chunk.find(end_marker, len(start_marker))
        if end > 0:
            chunk = chunk[:end]
    return set(re.findall(r'METHOD_IS\("([^"]+)"\)', chunk))


def extract_compat_methods(path: Path) -> set[str]:
    text = path.read_text()
    names: set[str] = set()
    for m in re.finditer(r'if \(method\.nocasecmp_to\("([^"]+)"\)', text):
        names.add(m.group(1).lower())
    for m in re.finditer(r'if \(method == "([^"]+)"', text):
        names.add(m.group(1).lower())
    return names


def main() -> int:
    src = BUILTINS.read_text()
    ev_start = "Variant call_builtin_expr_evaluated("
    ev_end = "\nbool call_builtin_for_base_variable("
    fb_start = "Variant call_builtin_expr("
    fb_end = "\nVariant call_builtin_expr_evaluated("

    evaluated = extract_method_is(BUILTINS, ev_start, ev_end)
    # Also pick up name == / nocasecmp in evaluated chunk
    ev_chunk = src[src.find(ev_start): src.find(ev_end)]
    for m in re.finditer(r'name\.nocasecmp_to\("([^"]+)"\)', ev_chunk):
        evaluated.add(m.group(1).lower())

    fallback = extract_method_is(BUILTINS, fb_start, fb_end)
    compat = extract_compat_methods(COMPAT)

    vm_union = evaluated | compat

    gaps = sorted(fallback - vm_union)
    print(f"call_builtin_expr_evaluated: {len(evaluated)} METHOD_IS names")
    print(f"dispatch_expr_compat_call:    {len(compat)} handler names")
    print(f"call_builtin_expr fallback:     {len(fallback)} METHOD_IS names")
    print()
    if gaps:
        print(f"GAP: {len(gaps)} fallback builtin(s) missing from VM expr path:")
        for g in gaps:
            print(f"  - {g}")
        return 1
    print("OK: all call_builtin_expr fallback names covered by VM expr + compat.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
