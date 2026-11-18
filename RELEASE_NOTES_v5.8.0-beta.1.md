# VisualGasic 5.8.0 Beta 1

Core performance and correctness beta. This remains a public beta, not stable VG6.
Back up projects, close Godot, and replace the entire `addons/visual_gasic/`
folder when upgrading. These changes require the new native binaries.

## Highlights

- **VM gap closed on the quiet-pair microbench.** Every published
  `run_gap` case is at or under GDScript parity (`vg/gd ≤ 1.00`) with JIT on
  and with `VG_JIT=0`. Largest wins on that machine: function calls ~30×,
  Integer globals ~14×, locals ~5× (JIT on). Numbers and reproduction:
  [`BENCHMARK_PUBLISHED_RESULTS.md`](BENCHMARK_PUBLISHED_RESULTS.md) § VM gap
  microbench · gate `scripts/check_vm_gap.sh`.
- **Visual speed demo:** [`samples/apps/vg_speed_race/`](samples/apps/vg_speed_race/)
  races the same particle integrate workload in `.vg` and `.gd` side by side
  (budget race so VG can pull ahead). Headless smoke:
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
  coerces like the VM path; `+` / `-` / `*` with `Nothing` on either side stay
  `Nothing` (issue #24).
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

## Validation

Release packaging runs the reusable CI suite (runtime, hardening, corpus,
mutations, editor lifecycle, reference, Crystal Caverns, packaging smoke) plus
native Linux/Windows/macOS/Web builds and installers. Local preflight for this
candidate included focused correctness fixtures, AST/bytecode agreement on the
parity cases, corpus checks, and `check_vm_gap.sh` with `mismatches=0`.

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
