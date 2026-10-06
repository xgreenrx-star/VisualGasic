VisualGasic bug-testing update - October 6, 2026

I have finished this round of the bug-testing work that started in Cursor. The reproduced defects from this campaign are fixed, committed and pushed. After the final fixes, I reran correctness tests and then the speed tests.

This was not just a matter of getting a green test summary. The original differential test harness could mistake aborted or incomplete runs for success. That has been corrected: crashes, timeouts, missing assertions, unexpected runtime errors and incomplete benchmark output now fail the checks.

MAIN FIXES

- Interpreter/compiler consistency: Tween now executes in the AST interpreter; enum static methods work in bytecode; typed collections auto-instantiate consistently and enforce their element types.

- Error handling and control flow: repaired Resume Next recovery, Err.Clear handling, error-path optimization, loop exits and runtime property aliases.

- ByRef and imports: fixed write-back through multidimensional arrays, imported procedures and expression-level calls.

- Godot integration: corrected native property/input handling, canvas command counts and GetDelta dispatch.

- Real Await continuations: ordinary procedures can suspend and resume without replaying statements, blocking the main thread or overwriting live globals. Tests cover interleaved calls, signals, local variables, loops, With contexts and error handlers.

- File and networking behavior: unified wildcard Kill handling, verified symlink behavior, and added bounded socket connection timeouts with deterministic local tests.

- Native crashes: reduced the VM recursion stack footprint and stopped malformed nested procedure declarations from becoming recursive executable bodies. One of those crashes was found by the mutation fuzzer after an earlier test pass.

- JIT correctness: the speed-test checksum gate caught arithmetic returning a negative result instead of 298,300,000. Fixed constant-operand lowering, scratch-register allocation and spill safety; hot-call regressions now pass.

- Moving-rectangle performance: the deterministic motion change stopped matching VG's native offset-draw optimization. The compiler now recognizes scaled integer coordinates while preserving checksums, loop variables and array errors.

FINAL CORRECTNESS RESULTS

- 210 differential fixtures passed in both execution modes.
- Zero divergences, matched failures, assertionless runs or execution failures.
- 170 data/context assertions passed, plus 5 parser checks, 3 debugger checks, 2 socket checks and 6 benchmark-validation checks.
- 18 recursion/frame assertions passed in each mode with a 4 MiB native stack.
- 80 mutation cases: zero native crashes and zero timeouts, including the seed that previously crashed.
- Moving-draw follow-up: 25 additional checks passed in each execution mode, and the full 210-fixture differential suite passed again.
- Eight helper, data-only, debugger, heavyweight or Windows-only fixtures were explicitly excluded from the generic passing total, not silently counted.

LATEST SPEED RESULTS

These are medians from three sequential runs on an Intel Core i7-1255U using Godot 4.6.1 on Linux. Draw results were rerun after the moving-rectangle optimization fix; compute and gameplay figures are from the original campaign. Each runtime benchmark compared matching checksums. All times below are in microseconds.

Arithmetic: 64.12x faster
VG: 83 | GDScript: 5,322

Array sum: 16.96x faster
VG: 258 | GDScript: 4,376

Local calls: 62.50x faster
VG: 167 | GDScript: 10,437

Entity thinking: 3.83x faster
VG: 746 | GDScript: 2,860

Frame-slice workload: 4.51x faster
VG: 797 | GDScript: 3,594

Sprite draw-command workload: 6.88x faster
VG: 288 | GDScript: 1,981

Uniform vector-canvas rectangles: 3.31x faster
VG: 132 | GDScript: 437

Corrected moving-rectangle workload: 2.42x faster
VG: 88 | GDScript: 213
All implementations produced checksum 257901 over exactly 120 measured frames.

SLOWER RESULTS - INCLUDED FOR TRANSPARENCY

Nested call chain: 1.12x slower
VG: 32,069 | GDScript: 28,639

Medium forced script reload: 3.41x slower
VG: 9,129 | GDScript: 2,677
The sources and reload phases differ, so this is not a like-for-like compiler-throughput comparison.

The moving-draw benchmark previously accepted different checksums and different frame counts. It now requires identical output and exactly 120 measured frames in every implementation. The older unchecked timings are not valid comparisons.

The later 45.87x slowdown was a real result on the corrected workload, but it exposed a missing optimization: integer-tenths coordinates bypassed VG's existing native draw-loop fast path. That is now fixed without changing the workload or weakening the checks. Fresh VG samples were 100, 83 and 88 microseconds; GDScript samples were 191, 213 and 244 microseconds. The previous result remains in the technical report as historical evidence.

WHAT THESE RESULTS MEAN

These are workload measurements, not whole-game FPS promises. Some VG cases benefit from loop fusion or specialized batching. Headless draw timings measure CPU-side command work, not GPU rendering performance.

Short draw timings varied between runs, including unchanged workloads. The results are measurements on this machine, not guaranteed performance ratios.

This is a completed, passing bug-testing campaign, not a claim that every possible bug is gone. Windows/macOS validation and sanitizer execution still need follow-up; the official Linux Godot binary blocks ASan loading because of its extension-loader flags. Advanced async contexts outside the documented ordinary-procedure support also remain out of scope.

Full results, including every slower row, C++ baselines where available, and raw benchmark logs:
https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/benchmarks/BUG_CAMPAIGN_OCT2026.md
