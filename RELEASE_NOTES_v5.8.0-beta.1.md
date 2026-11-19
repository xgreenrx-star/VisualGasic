# VisualGasic 5.8.0 Beta 1

Core performance and correctness beta. This remains a public beta, not stable VG6.
Back up projects, close Godot, and replace the entire `addons/visual_gasic/`
folder when upgrading. These changes require the new native binaries.

## Highlights

- **Major VM speed improvements.** The dated quiet-pair snapshot had every
  `run_gap` case at or under GDScript parity (`vg/gd ≤ 1.00`) with JIT on
  and with `VG_JIT=0`; later runs show variation, not universal parity.
  Largest wins in that snapshot: function calls ~30×,
  Integer globals ~14×, locals ~5× (JIT on). Numbers and reproduction:
  [`BENCHMARK_PUBLISHED_RESULTS.md`](BENCHMARK_PUBLISHED_RESULTS.md) § VM gap
  microbench · gate `scripts/check_vm_gap.sh`.
- **Visual speed demo:** [`samples/apps/vg_speed_race/`](samples/apps/vg_speed_race/)
  races matched particle, arithmetic, array, Dictionary, branching, string,
  and function-call workloads in `.vg` and `.gd` side by side. Both wins and
  remaining gaps are published below. Headless smoke:
  `scripts/run_speed_race.sh`.
- **Core correctness gates for this cut:** GitHub issues #24, #25, and #26.

## Runtime and compiler

- **Tier-2 JIT declines `AndAlso` / `OrElse` expression joins** that need a
  stack phi (issue #25). Those functions keep correct bytecode/interpreter
  results instead of risking a wrong native value. Native phi merge remains
  deferred.
- **AST `Len` matches bytecode:** containers and packed arrays use `.size()`,
  strings use character length, other scalars are `0` (issue #24).
- **AST and bytecode agree on mixed Variant arithmetic:** numeric `String`
  coerces like the VM path; left-hand `Nothing` stays `Nothing` on `+` / `-` /
  `*`; a numeric left plus `Nothing` coerces like `to_double` (issue #24).
- **Missing `Dictionary` keys evaluate to `Nothing`** and do not set
  `Err.Number` (issue #26). Documented language contract shared by AST,
  bytecode, and JIT.
- Unhandled errors in lifecycle callbacks report the procedure and line, skip
  the rest of that callback, and leave later frames running.
- `Try` / `Finally` with no `Catch` runs `Finally` and rethrows (`OP_RETHROW`).

## Performance evidence (quiet pair, 18 Nov 2026)

| Case | GD ns | VG JIT | vg/gd | VG `VG_JIT=0` | vg/gd |
| --- | ---: | ---: | ---: | ---: | ---: |
| t_local | 9.5 | 1.9 | 0.20 | 5.2 | 0.59 |
| t_gint | 9.8 | 0.6 | 0.07 | 6.5 | 0.70 |
| t_call | 61.1 | 1.9 | 0.03 | 5.7 | 0.10 |
| t_call_byref | 159.9 | 7.0 | 0.04 | 60.3 | 0.36 |
| t_dict | 32.5 | 29.0 | 0.89 | 30.8 | 0.95 |
| external_call | 63.5 | 56.7 | 0.89 | 56.4 | 0.99 |

Full table: [`BENCHMARK_PUBLISHED_RESULTS.md`](BENCHMARK_PUBLISHED_RESULTS.md).
Absolute nanoseconds drift across machines; ratios are from the same quiet-pair
run. These microbenchmarks are not a claim that every VG program is faster than
GDScript.

## Live-race verification (18 Nov 2026)

Godot 4.7.2, Linux x86-64, one pinned CPU core, no script debugger, default
runtime, work size 500. Median of seven paired steps after 64 warmups;
execution order alternates and matching step checksums are verified.

| Workload | GD µs/step | VG µs/step | VG/GD time |
| --- | ---: | ---: | ---: |
| Particles, Calls | 3,159 | 1,685 | 0.53 |
| Particles, Inline | 639 | 595 | 0.93 |
| Arithmetic | 450 | 390 | 0.87 |
| Array scan | 379 | 505 | **1.33 — GD faster** |
| Dictionary reads | 367 | 300 | 0.82 |
| Branching | 1,119 | 747 | 0.67 |
| String building | 2,260 | 4,839 | **2.14 — GD faster** |
| Function calls | 1,955 | 748 | 0.38 |
| Function calls, Inline | 362 | 250 | 0.69 |

Lower time ratio is better for VG. These are CPU workload timings, not FPS
or a C++ comparison. Different data types and loop shapes explain why the
older compute suite's larger speedups do not predict these races. Shared
machine load and runtime settings affect results; this is a dated local
snapshot, not a hardware-independent guarantee.

The later VM gate passed its `1.05` tolerance with zero checksum mismatches;
interpreter string comparison was `1.03×` GD time. A passing tolerance gate
does not establish strict parity for every case.
See the [complete methodology and reproduction](https://github.com/xgreenrx-star/VisualGasic/blob/main/BENCHMARK_PUBLISHED_RESULTS.md#live-race-workloads--18-nov-2026-verification).
The tagged archives retain their original benchmark documentation; this
publication update adds the later verification without changing the tagged
runtime binaries.

## Validation

The [tagged release workflow](https://github.com/xgreenrx-star/VisualGasic/actions/runs/44439698792)
passed for source revision `f1ab95f4dcd7aa43bbc1cb6facf09eb72a2602dc`:

- Runtime suite: 284 files, 1,893 assertions passed, zero failures or errors.
- Release hardening: 10 checks passed, including AST/bytecode differential,
  default/AST corpus and mutation runs, and editor lifecycle checks.
- Reference, bytecode-baseline, Crystal Caverns, and Asset Library install gates passed.
- Linux/Windows editor and export builds, universal macOS builds, and Web
  builds/export smoke passed; Windows and macOS bridge smoke jobs passed.
- Final packaged addon load/run smoke passed on Godot 4.6.1.
- Downloaded assets passed SHA-256 verification; every ZIP passed integrity
  checks. The downloaded addon also imported and executed a VG arithmetic
  smoke test on Godot 4.6.1.

Local preflight also included focused correctness fixtures and the VM timing
gate with zero checksum mismatches. Passing tests do not establish that the
runtime is bug-free, and installer GUIs were not manually exercised on every
platform.

## Downloads

Godot **4.6.1** remains the cross-platform baseline.

| Package | Download |
| --- | --- |
| Godot Asset Library addon | [Addon ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.8.0-beta.1/VisualGasic_AssetLibrary_v5.8.0-beta.1.zip) |
| Linux x86-64 installer | [AppImage](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.8.0-beta.1/VisualGasic-Installer-v5.8.0-beta.1-x86_64.AppImage) |
| Windows x64 installer | [EXE](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.8.0-beta.1/VisualGasic-Installer-v5.8.0-beta.1-x86_64.exe) |
| macOS Intel / Apple Silicon setup | [Universal setup ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.8.0-beta.1/VisualGasic-Installer-v5.8.0-beta.1-macos-universal.zip) |
| Linux offline setup with Godot | [Offline ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.8.0-beta.1/VisualGasic-Installer-Offline-v5.8.0-beta.1-linux-x86_64.zip) |
| Windows offline setup with Godot | [Offline ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.8.0-beta.1/VisualGasic-Installer-Offline-v5.8.0-beta.1-windows-x86_64.zip) |
| macOS offline setup with Godot | [Universal offline ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.8.0-beta.1/VisualGasic-Installer-Offline-v5.8.0-beta.1-macos-universal.zip) |
| Examples and documentation | [Examples/docs ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.8.0-beta.1/VisualGasic-Examples-and-Docs-v5.8.0-beta.1.zip) |

[Platform binaries and all assets](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.8.0-beta.1)
include desktop editor, debug-export and release-export builds, plus Web
debug/release binaries. The macOS frameworks contain **both x86_64 and arm64**
and bundled runtime dependencies. [SHA256SUMS](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.8.0-beta.1/SHA256SUMS)
and [BUILD_COMMIT.txt](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.8.0-beta.1/BUILD_COMMIT.txt)
identify the downloads and source revision.

Mac setup is an unsigned command launcher, **not a notarized DMG**; Python 3
is required. Control-click the launcher and choose Open if prompted. Linux's
graphical setup requires Python 3 and Tkinter. Offline bundles include Godot
and the addon, not optional AI services.

The Asset Library ZIP contains only the addon. Publishing its store listing
requires a separate submission and moderator approval; this GitHub release
does not imply that the store has already updated.

## Scope and known limitations

- Tier-2 **phi merge** for short-circuit `AndAlso` / `OrElse` joins is deferred;
  those functions use bytecode until native merge lands.
- Microbenchmark parity is not universal game-frame proof.
- Generic-array scanning and short-string building remain slower than
  GDScript in the live-race snapshot above.
- Experimental UI Forms and the legacy IDE remain opt-in.
- Mac downloads are not Developer ID signed or notarized.
- Remaining Godot editor shutdown/cold-import investigations stay in the
  [compatibility report](docs/compatibility/GODOT_4_7_2.md).

## Documentation and reporting

- [Installation and upgrade](docs/guides/INSTALLATION.md)
- [Documentation hub](docs/DOCS.md)
- [Language reference](docs/VisualGasic_Language_Reference.md)
- [Published benchmarks](BENCHMARK_PUBLISHED_RESULTS.md)
- [VG Speed Race sample](samples/apps/vg_speed_race/README.md)
- [Asset Library submission copy](ASSET_LIBRARY_CHANGELOG_5.8.0-beta.1.md)
- [Report a reproducible bug](https://github.com/xgreenrx-star/VisualGasic/issues)
- Website: https://xgreenrx-star.github.io/VisualGasic/
