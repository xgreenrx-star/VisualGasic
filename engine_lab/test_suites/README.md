# Test Suites

Comprehensive test runner and test case collection.

## Overview

Automated test framework for validating VisualGasic language features across syntax categories: control flow, string operations, arrays, dictionaries, classes, file I/O, math, state machines, and Godot integration.

## Organization

Tests are organized in subdirectories by category. Each category contains 5–10 test cases validating positive and negative scenarios.

## Running All Tests

```bash
cd demo/test_suites
# Use VG CLI test runner (if available)
vg-test --suite .
```

## Running Individual Tests

Open any `.vg` file in Godot's VisualGasic script editor and press F5 (Run).

## Test Naming Convention

- `test_*.vg` — Standard test cases
- `test_error_*.vg` — Error handling and edge cases
- `test_modern_*.vg` — Modern language features (Phase 3+)

## Notes

- All tests should complete without runtime exceptions
- Output is displayed in Godot's Output panel
- See `corpus/` directory for official test suite (53 validated examples)
