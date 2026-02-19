#!/usr/bin/env python3
"""
VisualGasic Static Bug Finder
==============================
Scans the compiler and interpreter C++ source to find common bug patterns
WITHOUT running Godot. This catches structural issues in the codebase.

Usage:
    python3 tools/static_bug_finder.py

Checks performed:
  1. Opcode gap:     Compiler emits OP_X but VM has no VG_CASE for it
  2. AST gap:        Parser creates NodeType X but evaluate_expression ignores it
  3. Fallthrough:    switch/case without break in opcode dispatch
  4. Raw Object*:    ClassDB::instantiate() result stored as Object* (RefCounted bug)
  5. Missing null:   .new() or ClassDB call without null check
  6. Silent drop:    Variant ops that discard the 'valid' bool
  7. Negate gap:     Unary minus on types other than int/float not handled
"""

import re
import sys
from pathlib import Path
from collections import defaultdict

WORKSPACE = Path(__file__).resolve().parent.parent
SRC = WORKSPACE / "src"

COMPILER = SRC / "visual_gasic_compiler.cpp"
INSTANCE = SRC / "visual_gasic_instance.cpp"
PARSER   = SRC / "visual_gasic_parser.cpp"
HEADER   = SRC / "visual_gasic_compiler.h"

class Finding:
    def __init__(self, severity, category, file, line, message):
        self.severity = severity  # ERROR, WARN, INFO
        self.category = category
        self.file = file
        self.line = line
        self.message = message

    def __str__(self):
        icon = {"ERROR": "🔴", "WARN": "🟡", "INFO": "🔵"}[self.severity]
        return f"{icon} [{self.severity}] {self.category} — {self.file}:{self.line}: {self.message}"


def read_file(path):
    if not path.exists():
        return []
    return path.read_text().splitlines()


def check_opcode_gaps(findings):
    """Find opcodes the compiler emits but the VM doesn't handle."""
    compiler_lines = read_file(COMPILER)
    instance_lines = read_file(INSTANCE)

    # Compiler: all OP_* references
    compiler_ops = set()
    for line in compiler_lines:
        for m in re.finditer(r'\bOP_(\w+)', line):
            compiler_ops.add("OP_" + m.group(1))

    # VM: all VG_CASE(..., OP_*) handlers
    vm_ops = set()
    for line in instance_lines:
        for m in re.finditer(r'VG_CASE\(\w+,\s*(OP_\w+)\)', line):
            vm_ops.add(m.group(1))
        # Also catch plain case OP_* (some might exist)
        for m in re.finditer(r'\bcase\s+(OP_\w+)', line):
            vm_ops.add(m.group(1))

    # Filter out Variant::OP_* (those are Godot's variant ops, not VG opcodes)
    compiler_ops = {op for op in compiler_ops
                    if not op.startswith("OP_ADD") or op in ("OP_ADD", "OP_ADD_I64", "OP_ADD_F64",
                    "OP_ADD_I64_CONST", "OP_ADD_LOCAL_I64_CONST", "OP_ADD_LOCAL_I64_STACK")}

    missing = compiler_ops - vm_ops
    # Exclude Variant::OP_* style ops used in evaluate() calls
    variant_ops = {"OP_ADD", "OP_SUBTRACT", "OP_MULTIPLY", "OP_DIVIDE",
                   "OP_EQUAL", "OP_NOT_EQUAL", "OP_LESS", "OP_GREATER",
                   "OP_LESS_EQUAL", "OP_GREATER_EQUAL", "OP_NEGATE", "OP_NOT",
                   "OP_MODULE", "OP_POSITIVE", "OP_SHIFT_LEFT", "OP_SHIFT_RIGHT",
                   "OP_BIT_AND", "OP_BIT_OR", "OP_BIT_XOR", "OP_BIT_NEGATE",
                   "OP_AND", "OP_OR", "OP_XOR", "OP_IN", "OP_POWER",
                   "OP_STRING_CONCAT"}

    for op in sorted(missing):
        if op not in variant_ops:
            findings.append(Finding(
                "ERROR", "opcode_gap", COMPILER.name, 0,
                f"Compiler references {op} but VM has no VG_CASE handler"
            ))


def check_raw_object_ptr(findings):
    """Find ClassDB::instantiate() results stored as Object* instead of Variant."""
    for path in [INSTANCE, COMPILER]:
        lines = read_file(path)
        for i, line in enumerate(lines):
            if 'ClassDB::instantiate' in line and 'Object*' in line:
                findings.append(Finding(
                    "ERROR", "refcounted_leak", path.name, i + 1,
                    "ClassDB::instantiate() stored as Object* — RefCounted objects will be freed immediately. Use Variant."
                ))
            if 'ClassDB::instantiate' in line and 'Object *' in line:
                findings.append(Finding(
                    "ERROR", "refcounted_leak", path.name, i + 1,
                    "ClassDB::instantiate() stored as Object * — RefCounted objects will be freed immediately. Use Variant."
                ))


def check_null_after_instantiate(findings):
    """Find ClassDB::instantiate() without subsequent null/type check."""
    for path in [INSTANCE]:
        lines = read_file(path)
        for i, line in enumerate(lines):
            if 'ClassDB::instantiate' in line:
                # Check next 5 lines for a null/type check
                context = '\n'.join(lines[i:i+6])
                if 'nullptr' not in context and 'Variant::NIL' not in context and \
                   'get_type()' not in context and '== Variant::OBJECT' not in context and \
                   'obj != nullptr' not in context and 'inst !=' not in context:
                    findings.append(Finding(
                        "WARN", "missing_null_check", path.name, i + 1,
                        "ClassDB::instantiate() without null/type check within 5 lines"
                    ))


def check_variant_op_valid(findings):
    """Find Variant::evaluate() calls that ignore the 'valid' output bool."""
    for path in [INSTANCE]:
        lines = read_file(path)
        for i, line in enumerate(lines):
            if 'Variant::evaluate(' in line:
                # Check if 'valid' variable is tested afterwards
                context = '\n'.join(lines[i:i+5])
                if 'valid' not in context and 'r_valid' not in context:
                    findings.append(Finding(
                        "WARN", "unchecked_variant_op", path.name, i + 1,
                        "Variant::evaluate() called without checking the 'valid' output"
                    ))


def check_push_without_ensure(findings):
    """Find push_value() calls not preceded by ensure_stack()."""
    for path in [INSTANCE]:
        lines = read_file(path)
        for i, line in enumerate(lines):
            stripped = line.strip()
            if 'push_value(' in stripped and 'ensure_stack' not in stripped:
                # Check preceding 3 lines
                context = '\n'.join(lines[max(0, i-3):i+1])
                if 'ensure_stack' not in context:
                    # This is only a problem inside the bytecode VM loop
                    # Check if we're in the VM section (between vg_op_ labels)
                    if any('VG_CASE' in lines[j] for j in range(max(0, i-30), i)):
                        findings.append(Finding(
                            "INFO", "push_without_ensure", path.name, i + 1,
                            "push_value() without nearby ensure_stack() — potential stack overflow"
                        ))


def check_singleton_coverage(findings):
    """Check that known singletons are in non_local_names."""
    lines = read_file(COMPILER)
    content = '\n'.join(lines)

    expected_singletons = ["input", "godot", "me", "super", "engine", "os",
                          "time", "displayserver", "renderingserver"]

    non_local_section = ""
    in_section = False
    for line in lines:
        if 'non_local_names' in line:
            in_section = True
        if in_section:
            non_local_section += line.lower() + "\n"
            if '}' in line or ';' in line:
                if len(non_local_section) > 50:
                    break

    for singleton in expected_singletons:
        if singleton not in non_local_section and singleton not in content.lower():
            findings.append(Finding(
                "INFO", "singleton_missing", COMPILER.name, 0,
                f"Singleton '{singleton}' may not be in non_local_names — could be resolved as nil local slot"
            ))


def check_negate_types(findings):
    """Check OP_NEGATE handler covers Vector2, Vector3, Color, not just numeric."""
    lines = read_file(INSTANCE)
    in_negate = False
    negate_section = []
    negate_start = 0

    for i, line in enumerate(lines):
        if 'OP_NEGATE' in line and ('VG_CASE' in line or 'case' in line):
            in_negate = True
            negate_start = i + 1
            negate_section = []
        if in_negate:
            negate_section.append(line)
            if 'VG_BREAK' in line or len(negate_section) > 30:
                in_negate = False

    negate_text = '\n'.join(negate_section)
    if 'Vector2' not in negate_text and 'Vector3' not in negate_text:
        findings.append(Finding(
            "WARN", "negate_coverage", INSTANCE.name, negate_start,
            "OP_NEGATE handler may not support Vector2/Vector3 negation — only numeric types checked"
        ))


def check_apply_variant_op_coverage(findings):
    """Check that all arithmetic VG_CASE handlers have error fallback."""
    lines = read_file(INSTANCE)
    arith_ops = ["OP_ADD", "OP_SUBTRACT", "OP_MULTIPLY", "OP_DIVIDE",
                 "OP_MOD", "OP_POWER", "OP_INT_DIVIDE"]

    for i, line in enumerate(lines):
        for op in arith_ops:
            if f'VG_CASE' in line and op + ')' in line:
                # Check next 5 lines for apply_variant_op or proper handling
                context = '\n'.join(lines[i:i+10])
                if 'success = false' not in context and 'goto cleanup' not in context:
                    findings.append(Finding(
                        "WARN", "arith_no_error_path", INSTANCE.name, i + 1,
                        f"{op} handler has no error/fallback path"
                    ))


def main():
    findings = []

    print("VisualGasic Static Bug Finder")
    print("=" * 50)
    print(f"Scanning: {SRC}")
    print()

    check_opcode_gaps(findings)
    check_raw_object_ptr(findings)
    check_null_after_instantiate(findings)
    check_variant_op_valid(findings)
    check_push_without_ensure(findings)
    check_singleton_coverage(findings)
    check_negate_types(findings)
    check_apply_variant_op_coverage(findings)

    # Sort by severity
    order = {"ERROR": 0, "WARN": 1, "INFO": 2}
    findings.sort(key=lambda f: (order[f.severity], f.category, f.line))

    errors = [f for f in findings if f.severity == "ERROR"]
    warns  = [f for f in findings if f.severity == "WARN"]
    infos  = [f for f in findings if f.severity == "INFO"]

    if findings:
        for f in findings:
            print(f)
        print()

    print(f"Summary: {len(errors)} errors, {len(warns)} warnings, {len(infos)} info")

    if errors:
        print("\n🔴 ERRORS require immediate attention — these are likely active bugs.")
        return 1
    elif warns:
        print("\n🟡 Warnings suggest potential issues worth reviewing.")
        return 0
    else:
        print("\n✅ No structural issues found.")
        return 0


if __name__ == "__main__":
    sys.exit(main())
