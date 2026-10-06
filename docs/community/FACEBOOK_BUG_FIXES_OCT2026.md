# Facebook post: bug-testing results and measured performance

Copy the text below for Facebook. The complete tables and methodology are in
[the technical report](../benchmarks/BUG_CAMPAIGN_OCT2026.md).

---

VisualGasic bug-testing update - October 6, 2026

I have finished this round of the bug-testing work that started in Cursor. The
reproduced defects from this campaign are fixed, committed and pushed. After
the final fixes, I reran correctness tests and then the speed tests.

This was not just a matter of getting a green test summary. The original
differential test harness could mistake aborted or incomplete runs for success.
That has been corrected: crashes, timeouts, missing assertions, unexpected
runtime errors and incomplete benchmark output now fail the checks.

Here are the main fixes:

- **Interpreter/compiler consistency:** Tween now executes in the AST
  interpreter; enum static methods work in bytecode; typed collections
  auto-instantiate consistently and enforce their element types.
- **Error handling and control flow:** repaired Resume Next recovery,
  Err.Clear handling, error-path optimization, loop exits and runtime property
  aliases.
- **ByRef and imports:** fixed write-back through multidimensional arrays,
  imported procedures and expression-level calls.
- **Godot integration:** corrected native property/input handling, canvas
  command counts and GetDelta dispatch.
- **Real Await continuations:** ordinary procedures can suspend and resume
  without replaying statements, blocking the main thread or overwriting live
  globals. Tests cover interleaved calls, signals, local variables, loops,
  With contexts and error handlers.
- **File and networking behavior:** unified wildcard Kill handling, verified
  symlink behavior, and added bounded socket connection timeouts with
  deterministic local tests.
- **Native crashes:** reduced the VM recursion stack footprint and stopped
  malformed nested procedure declarations from becoming recursive executable
  bodies. One of those crashes was found by the mutation fuzzer after an
  earlier test pass.
- **JIT correctness:** the speed-test checksum gate caught arithmetic returning
  a negative result instead of 298,300,000. Fixed constant-operand lowering,
  scratch-register allocation and spill safety; hot-call regressions now pass.

Final correctness results:

- **210 differential fixtures passed in both execution modes.**
- **Zero divergences, matched failures, assertionless runs or execution failures.**
- **170 data/context assertions passed**, plus 5 parser checks, 3 debugger
  checks, 2 socket checks and 6 benchmark-validation checks.
- **18 recursion/frame assertions passed in each mode with a 4 MiB native stack.**
- **80 mutation cases: zero native crashes and zero timeouts**, including the
  seed that previously crashed.
- Eight helper, data-only, debugger, heavyweight or Windows-only fixtures were
  explicitly excluded from the generic passing total, not silently counted.

Latest speed results

These are medians from three sequential runs on an Intel Core i7-1255U using
Godot 4.6.1 on Linux. Each runtime benchmark compared matching checksums.
Numbers below are GDScript time divided by VisualGasic time; above 1 means VG
was faster for that specific workload:

- Arithmetic: **64.12x** - VG 83 us; GDScript 5,322 us.
- Array sum: **16.96x** - VG 258 us; GDScript 4,376 us.
- Local calls: **62.50x** - VG 167 us; GDScript 10,437 us.
- Entity thinking: **3.83x** - VG 746 us; GDScript 2,860 us.
- Frame-slice workload: **4.51x** - VG 797 us; GDScript 3,594 us.
- Sprite draw-command workload: **2.36x** - VG 287 us; GDScript 678 us.
- Uniform vector-canvas rectangles: **13.00x** - VG 57 us; GDScript 741 us.

There are also slower results, and I am including them:

- Nested call chain: VG 32,069 us vs GDScript 28,639 us - **1.12x slower**.
- Circle draw commands: VG 1,618 us vs GDScript 1,195 us - **1.35x slower**.
- Corrected moving-rectangle workload: VG 7,476 us vs GDScript 163 us -
  **45.87x slower**, an important performance gap to investigate next.
- Medium forced script reload: VG 9,129 us vs GDScript 2,677 us -
  **3.41x slower**. The sources and reload phases differ, so this is not a
  like-for-like compiler-throughput comparison.

The moving-draw benchmark previously accepted different checksums and different
frame counts. It now requires identical output and exactly 120 measured frames
in every implementation. The older unchecked timings are not valid comparisons.

These are workload measurements, not whole-game FPS promises. Some VG cases
benefit from loop fusion or specialized batching. Headless draw timings measure
CPU-side command work, not GPU rendering performance.

This is a completed, passing bug-testing campaign, not a claim that every
possible bug is gone. Windows/macOS validation and sanitizer execution still
need follow-up; the official Linux Godot binary blocks ASan loading because of
its extension-loader flags. Advanced async contexts outside the documented
ordinary-procedure support also remain out of scope.

Full results, including every slower row, C++ baselines where available, and raw
benchmark logs:
https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/benchmarks/BUG_CAMPAIGN_OCT2026.md
