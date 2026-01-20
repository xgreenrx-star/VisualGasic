# Visual Gasic Test Results

**Date:** January 19, 2026
**Tests Run:** 41
**Passed:** 35
**Failed:** 6

## Overview
We executed the full test suite in `examples/` using the Godot 4.5.1 headless engine. Most core language features (Keywords, Arrays, Loops, Math, Logic) are fully functional.

## Fixed Issues
During testing, we identified and fixed path resolution errors in:
- `run_angle_test.gd`: Fixed incorrect path `res://examples/pong/pong.bas` -> `res://pong/pong.bas`.
- `run_test_integer.gd`: Fixed incorrect path `res://examples/test_integer.bas` -> `res://test_integer.bas`.

## Remaining Issues

The following tests failed or showed errors that require attention:

1.  **`run_features.gd`** (Engine Error)
    - Error: `Window 0 spawned at invalid position: (-268, -168)`.
    - Impact: Likely cosmetic in headless mode, but indicates window spawning logic needs bounds checking.

2.  **`run_full.gd`** (Runtime Error)
    - Error: `annot convert argument 1 from Nil to StringName`.
    - Context: Occurs during `Call set_name(Name)`. It seems the variable `Name` was not correctly passed or initialized in the test context.

3.  **`run_import_job.gd`** (Memory Leak)
    - Error: `RID allocations ... leaked at exit`.
    - Impact: Indicates resources (Fonts/TextServers) are not being freed properly during the import process.

4.  **`run_instance.gd`** (Memory Leak)
    - Error: Similar RID leaks as above.
    - Impact: Object instantiation/destruction cycle might be leaking engine resources.

5.  **`run_input_check.gd`** (Crash)
    - Error: Exit Code 134 (SIGABRT).
    - Context: `Parameter "data.tree" is null`. This suggests a null pointer dereference in the underlying C++ extension when checking input on a non-existent tree or node.

6.  **`run_timer.gd`** (Hang)
    - Behavior: The test hangs indefinitely and had to be manually terminated.
    - Impact: Timer logic might rely on `await` or signals that never fire in the headless test environment.

## Conclusion
The core "Visual Gasic" interpreter is stable. The failures are primarily related to:
1.  Advanced object lifecycle (leaks).
2.  Headless environment constraints (Window position, Timer hangs).
3.  Specific edge cases in interop (nil->StringName conversion).

You can run the full suite again using:
`./examples/run_all_tests.sh`
