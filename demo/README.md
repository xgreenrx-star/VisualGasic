# Demo Folder Structure

This folder contains organized demos, benchmarks, tests, and prototypes for Visual Gasic.

## Directories

### `ui_demos/`
Standalone UI component demonstrations. These showcase individual widgets and UI patterns:
- Ammo counters, chat boxes, compasses, confirmation dialogs
- Damage numbers, pop-ups, item slots, loading screens
- Minimaps, quest trackers, radial menus, settings panels
- Skill trees, tab panels, tooltips, XP bars

Useful as references for building game UIs with Visual Gasic.

### `games_and_physics/`
Playable game examples and physics demonstrations:
- `pong.vg`, `pong_angle.vg` — Pong game variants
- `VGPaint.vg` — Simple paint application
- Debug/test versions of games

### `benchmarks/`
Performance testing and optimization benchmarks:
- `bench.vg`, `bench_data_vs_array.vg`, `bench_dict_simple.vg` — Core benchmarks
- `jit_*.vg` — JIT compilation test cases
- `loop_shapes.vg`, `parallel.vg` — Algorithmic benchmarks
- `bench_output.txt` — Results log

### `test_suites/`
Comprehensive test coverage organized by feature:
- `test_*.vg` — Visual Gasic language feature tests
- `run_*.vg` — Test runner scripts
- `test_*.gd`, `run_*.gd` — Godot integration tests
- Tests cover: arrays, classes, control flow, operators, functions, I/O, threading, signals, etc.

### `prototypes/`
Experimental code, debug scripts, and non-standard examples:
- AutoIndent prototype, debugging scripts, reproduction cases
- Miscellaneous utility scripts and one-off experiments

### Other Directories

- `builtin_tests/`, `custom_controls/`, `custom_widgets/` — Additional test/widget collections
- `mixed/`, `resources/`, `start_forms/`, `fuzz_generated/` — Supporting test data and generated files
- `bin/`, `addons/` — Build artifacts and plugin dependencies
- `.godot/` — Godot editor cache

## Root-Level Files

- `test.vg`, `v330_features.vg` — Miscellaneous test scripts
- `project.godot`, `icon.svg` — Godot project files
- `.vg_breakpoints.json` — Debug breakpoint state

## Notes

- All `.uid` files (Godot metadata) have been removed for cleanliness
- Use `ui_demos/` for UI component references
- Use `test_suites/` for language compliance validation
- Use `benchmarks/` for performance tuning
- Consult `games_and_physics/` for gameplay examples
