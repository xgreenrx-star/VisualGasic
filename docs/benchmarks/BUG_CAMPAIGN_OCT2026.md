# Bug campaign close-out and benchmark results

Date: October 6, 2026. Tested revision: `ad84892f`.

The reproduced defects from the Cursor follow-up campaign are resolved. The
final correctness gate ran after the fixes were pushed; performance collection
started only after that gate passed. This is not an exhaustive certification
that VisualGasic contains no remaining bugs.

The [Facebook draft](../community/FACEBOOK_BUG_FIXES_OCT2026.md) is ready to copy.
The [testing plan](../BUG_TESTING_PLAN.md) contains the chronological triage.

## Fixes delivered

| Area | Correction |
|---|---|
| Test harness | Preserve child exit status; reject incomplete, empty, failing and unexpected-error runs; validate exact expected error locations; avoid shared selectors; explicitly classify exclusions. |
| Error handling | Restore Resume Next recovery, preserve handlers across Err.Clear, keep resumable error paths in the optimizer, and declare Catch variables under Option Explicit. |
| Dispatch | Prevent ClassDB aliases hijacking instance calls; share enum method dispatch and compile keyword members; implement AST Tween with single target evaluation. |
| Collections/control flow | Auto-instantiate typed collections consistently; enforce element constraints; repair AST loop/property behavior and string For Each bytecode support. |
| ByRef | Repair imported and expression-call write-back, including nested/multidimensional arrays; preserve temporary-argument semantics. |
| Native integration | Fix optimized canvas command counts, GetDelta dispatch and physical-only key input fallback; improve test ownership and sample import correctness. |
| File operations | Use one wildcard Kill helper across dispatch surfaces; test hidden matches, directory rejection and live/dangling symlinks without deleting symlink targets. |
| Replay safety | Avoid falling back to AST after partially executing Nothing/vector arithmetic, preventing duplicated output and side effects. |
| Await | Implement explicit AST continuations and exact VM continuation state, ID-bound callbacks, task completion signals and recoverable invalid/failed/cancelled waits. Preserve live globals, local scopes, With contexts and handlers. |
| Socket connect | Add optional bounded connection polling; restore blocking transfer mode; verify refused loopback connections and a real 25 ms saturated-listener timeout. |
| Native recursion | Move an inlined stack reporter out of the VM frame, reducing the optimized frame from approximately 23 KB to 4.6 KB; verify recursion with a 4 MiB native stack. |
| Parser crash | Reject nested procedure declarations at their source line and discard malformed procedure bodies while retaining healthy siblings. Replay the previously crashing mutation seed. |
| Native JIT | Consume the actual operand/literal stack pair for constant arithmetic instead of loading a local slot using a constant index. Reserve scratch registers, protect live floating inputs and keep spills clear of saved registers/host temporaries. |
| Benchmark validity | Isolate the benchmark host from demo music autoloads, free created interop nodes, force real VG reload, and require matching moving-draw checksums and frame counts. |

Campaign commits, oldest first:

`dbcf99d8`, `290427f7`, `e66b60be`, `1e7a35d6`, `140364ed`, `22640d5f`,
`4f5ed9e3`, `8f0fa915`, `987d5bff`, `ad84892f`.

## Final correctness gate

| Gate | Verified result |
|---|---|
| Full AST/default differential run | 210 matched passing fixtures; zero matched failures, divergences, assertionless runs or execution failures. |
| Explicit generic-run exclusions | 8; not counted as passing. Two imported helpers, two data-only fixtures, two debugger fixtures, one heavyweight benchmark fixture, one Windows DLL fixture. |
| Data/context suites | 170 assertions: 37 sprite, 50 vector, 16 analyzer, 11 caret, 14 datafile, 7 Narcea knowledge, 35 literal checks. |
| Parser/reload regression runner | 5 checks passed, including healthy-sibling execution after rejecting a malformed procedure. |
| Debugger runner | 3 checks passed: exact source-line stepping, one pause per loop iteration and shallow value previews. |
| Socket runner | 2 checks passed. Requested timeout 25 ms; observed 24 ms against a saturated local listener. |
| Draw-result validator | 6 checks passed, including rejection of unequal checksums, extra/missing frames, missing checksums and negative timings. |
| Small-native-stack stress | 18 assertions passed in each execution mode with a 4 MiB native stack. |
| Mutation stress | 40 default-path cases at seed 15 and 40 forced-AST cases at seed 16; zero crashes and zero timeouts. |
| Benchmark collection | 12 successful runs: three each of compute, gameplay, draw and forced reload. No warning/error/mismatch output in the collected benchmark logs. |

The differential default path uses bytecode when compilation succeeds, with
existing fallback behavior; it is not proof that every fixture runs entirely in
native code. The new JIT regression separately logged native compilation and
passed ten assertions, including the exact `298300000` arithmetic checksum,
changing bounds, empty bounds and spill/host-call safety.

Mutation stress accepts clean parse/runtime rejection as a non-crash outcome;
it does not establish semantic correctness of mutated programs.

## Measurement environment and method

- CPU: Intel Core i7-1255U, 12 logical CPUs.
- OS: Linux; kernel `6.12.7-2-liquorix-amd64`.
- Engine: official Godot `4.6.1.stable.14d19694e`.
- Extension: ordinary optimized Linux editor library; default JIT setting.
  Linux editor and debug-export libraries were rebuilt and pushed.
- Host: temporary minimal benchmark project referencing the existing workload
  resources. No music/experimental editor autoloads.
- Sampling: three complete process runs per suite, performed sequentially,
  without a concurrently running build or test campaign.
- Tables: median elapsed microseconds for each implementation, then
  **speedup = GDScript median / VG median**. Above 1 favors VG; below 1 favors
  GDScript. This is a ratio of medians, not the median of three ratios.
- Runtime rows: matching checksums were required for every collected sample.
  Moving draw additionally required exactly 120 measured frames per lane.
- No combined "game speed" or "faster than C++" claim is derived from these
  unrelated workloads. CPU scheduling, clock changes and filesystem caching
  still affect short measurements; three samples are not a statistical study.

## Compute

Elapsed times are microseconds. A dash indicates no C++ lane in that workload.

| Workload | VG us | GDScript us | C++ us | GD/VG speedup |
|---|---:|---:|---:|---:|
| Arithmetic | 83 | 5322 | 59 | 64.12x |
| ArraySum | 258 | 4376 | 37 | 16.96x |
| StringConcat | 220 | 5146 | 528 | 23.39x |
| Branching | 182 | 7016 | 60 | 38.55x |
| FunctionCall | 190 | 5364 | - | 28.23x |
| ArrayDict | 5506 | 11582 | 3488 | 2.10x |
| DictFastGet | 3841 | 29631 | - | 7.71x |
| DictFastSet | 4064 | 19166 | - | 4.72x |
| Interop | 355 | 8261 | 6869 | 23.27x |
| Allocations | 272 | 6757 | 496 | 24.84x |
| AllocationsFast | 1930 | 9213 | 380 | 4.77x |
| FileIO | 676 | 1121 | 411 | 1.66x |

Arithmetic includes a closed-form loop-fusion optimization. Specialized array,
string, call and interop paths can also perform less interpreter work than a
literal loop. Faster-than-baseline rows do not establish general language or
native-code superiority. FileIO is a small, cache-sensitive workload.

## Gameplay-shaped workloads

These are scripting workloads, not complete games or measured game FPS.

| Workload | VG us | GDScript us | GD/VG speedup |
|---|---:|---:|---:|
| IntegerLoop | 77 | 1339 | 17.39x |
| FloatLoop | 178 | 859 | 4.83x |
| LocalCalls | 167 | 10437 | 62.50x |
| CallChain | 32069 | 28639 | 0.89x |
| NodePropertyChurn | 330 | 41240 | 124.97x |
| ArrayIterate | 283 | 1080 | 3.82x |
| DictionaryScan | 762 | 3102 | 4.07x |
| EntityThink | 746 | 2860 | 3.83x |
| BatchNearest | 1586 | 3028 | 1.91x |
| FrameSlice | 797 | 3594 | 4.51x |

CallChain is 1.12x slower in VG. NodePropertyChurn and LocalCalls are especially
optimization-sensitive; do not use their ratios as whole-game multipliers.

## Headless draw-command work

Static rows time CPU-side work inside `_draw`. MovingFilledRects reports the
per-run average over 120 measured draws; the table is the median of those
three averages. These are not GPU rendering times or FPS results.

| Workload | VG us | GDScript us | C++ us | GD/VG speedup |
|---|---:|---:|---:|---:|
| FilledRects | 276 | 558 | 64 | 2.02x |
| OutlineRects | 877 | 749 | 244 | 0.85x |
| Lines | 522 | 453 | 60 | 0.87x |
| Circles | 1618 | 1195 | 1716 | 0.74x |
| Sprites | 287 | 678 | 64 | 2.36x |
| Polylines | 772 | 1085 | 525 | 1.41x |
| Mixed | 3215 | 3477 | 1609 | 1.08x |
| VectorCanvasUniformRects | 57 | 741 | 136 | 13.00x |
| MovingFilledRects | 7476 | 163 | 47 | 0.022x |

VG is slower on OutlineRects, Lines, Circles and MovingFilledRects. Moving
rectangles are **45.87x slower** in this corrected workload and remain a
performance investigation target, not a failing correctness result.

The moving workload uses identical integer-tenths motion in all implementations:
500 objects, 10 warmup frames and 120 measured frames. All lanes produced final
checksum `257901`. Each simulation step waits for its measured draw, and
duplicate/final redraws are ignored. Earlier floating-motion runs bypassed
checksum comparisons and included different sample counts; their timings are
not valid comparisons with this revised workload.

Uniform vector-canvas rectangles benefit from specialized batching; that result
does not predict the moving-rectangle result.

## Forced script reload

Each process performs three warmups and 15 measured reloads per row and reports
its internal median. The table below is the median of three process medians.

VG calls `reload(true)` to avoid the unchanged-resource early return. It
includes tokenization/parsing and associated reload work, **not lazy bytecode
compilation/JIT**. GDScript reload includes its analyzer and compilation.
The medium sources are different; generated large sources have similar shapes
but different syntax/line counts. These are reload measurements, not
like-for-like compiler-throughput comparisons.

| Workload | Approx. VG/GD nonempty lines | VG us | GDScript us | GD/VG ratio |
|---|---:|---:|---:|---:|
| HelloWorld | 4 / 3 | 39 | 35 | 0.90x |
| BenchCompute | 461 / 302 | 9129 | 2677 | 0.29x |
| SyntheticLarge | 1805 / 1576 | 23659 | 15392 | 0.65x |

VG reload was slower in all three rows: approximately 1.11x, 3.41x and 1.54x,
respectively.

## Evidence and reproduction

Raw performance logs, including checksums and all three samples:

- Compute: [1](oct2026/compute-1.log), [2](oct2026/compute-2.log), [3](oct2026/compute-3.log).
- Gameplay: [1](oct2026/gameplay-1.log), [2](oct2026/gameplay-2.log), [3](oct2026/gameplay-3.log).
- Draw: [1](oct2026/draw-1.log), [2](oct2026/draw-2.log), [3](oct2026/draw-3.log).
- Reload: [1](oct2026/compile-1.log), [2](oct2026/compile-2.log), [3](oct2026/compile-3.log).

Correctness summaries: [differential](oct2026/differential.log),
[specialized runners](oct2026/specialized.log),
[default mutation](oct2026/mutation-default.log),
[AST mutation](oct2026/mutation-ast.log).
Mutation crash artifacts and original backtraces are retained in the campaign
session evidence; temporary paths printed in logs are not repository files.

From the repository root:

```sh
scripts/run_ast_bytecode_diff.sh --all
scripts/run_sprite_data_tests.sh
./Godot_v4.6.1-stable_linux.x86_64 --headless --path test_proj -s tools/run_parser_procedure_regressions.gd
./Godot_v4.6.1-stable_linux.x86_64 --headless --path test_proj -s tools/run_socket_timeout.gd
./Godot_v4.6.1-stable_linux.x86_64 --headless --path test_proj -s tools/run_step_trace.gd
./Godot_v4.6.1-stable_linux.x86_64 --headless --path test_proj -s "$PWD/tests/test_draw_benchmark_results.gd"
scripts/run_parser_mutation_stress.sh 40 15
VG_FORCE_AST=1 scripts/run_parser_mutation_stress.sh 40 16
```

Run the mutation commands serially; they share a temporary fixture. Run speed
commands only after correctness gates and builds finish, also serially:

```sh
for suite in compute gameplay draw compile; do
    for sample in 1 2 3; do
        bash "scripts/run_${suite}_benchmarks.sh"
    done
done
```

## Remaining validation and scope limits

- ASan library compilation succeeded, but official Godot 4.6.1 rejects its
  loading because `RTLD_DEEPBIND` is incompatible with ASan. Runtime sanitizer
  execution remains blocked pending a compatible engine build; it did not pass.
- Windows/macOS runtime and networking behavior were not validated here. The
  Windows DLL fixture is an exclusion, not a Linux pass.
- Ordinary-procedure Await is tested. Unmanaged AST special-loop/worker/native
  class-method waits remain explicitly unsupported; full async expression/
  generic-task semantics are not claimed.
- Socket timeouts bound connection polling, not operating-system DNS lookup.
- Native recursion remains stack-dependent; the Linux 4 MiB result does not
  certify every worker-thread/platform stack.
- Slower benchmark rows remain performance work. Highest-priority follow-up:
  profile the corrected moving-draw workload; then investigate nested call
  chains and reload cost without weakening checksum/frame-count validation.
