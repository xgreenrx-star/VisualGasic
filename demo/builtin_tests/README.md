# Builtin Tests

Unit tests for VisualGasic built-in functions and language features.

## Overview

Quick validation suite for core language constructs: control flow, string operations, array/dictionary manipulation, math functions, and Godot API bindings.

## Files

| File | Purpose |
|------|---------|
| `test_godot_integration.vg` | Godot class instantiation, signal emissions, node tree manipulation |
| `test_*.vg` | Individual feature tests |

## Running Tests

```bash
# From Godot editor Script Debugger, or:
vg-cli demo/builtin_tests/test_godot_integration.vg
```

## Notes

- These are not exhaustive; see `corpus/` for comprehensive test coverage
- Focus is on fast feedback for regression detection
