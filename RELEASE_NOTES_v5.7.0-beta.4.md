# VisualGasic 5.7.0 Beta 4

Bug-fix update to Beta 3. This remains a public beta, not stable VG6.
Back up projects, close Godot, and replace the entire `addons/visual_gasic/`
folder when upgrading. These fixes require the new native binaries.

## Runtime and compiler fixes

- **Explicit calls to VG lifecycle procedures work.** A VG script calling
  another VG node's `_Process`, `_Ready`, `_Draw`, or `_PhysicsProcess`
  reaches that procedure instead of being discarded as a duplicate engine
  notification. Normal engine callbacks retain their duplicate-call guard.
  Drawing still belongs inside a valid Godot draw callback.
- **Dictionary values survive optimization and escape correctly.** Returning
  a local dictionary, iterating dictionaries, assigning existing dictionary
  elements to a loop variable, and passing values through nested `Select`,
  `With`, and `Try` blocks no longer leave frame-local optimized storage
  where an ordinary Dictionary is required.
- **Indexed dictionary reads keep their assignments.** Dead-store analysis
  recognizes `d("key")` as a read of `d`, rather than removing the preceding
  assignment because the syntax resembles a function call.
- **Append and packed-loop fast paths distinguish arrays from calls and
  dictionaries.** A function result or string-keyed dictionary read is no
  longer treated as an integer array index by these optimizations.
- **Tier-2 JIT handles mixed integer/float local stores across branches.**
  Values no longer become zero or incorrect numbers because one branch's
  integer bits are decoded as the other branch's floating-point storage.
- **Vector arithmetic keeps its type.** Unknown operands are not assumed
  numeric just because the other operand is a scalar. Accumulations such as
  adding a scaled vector no longer select a floating-point-only operation.
- **Module variables and constants can shadow Godot enum names.** A declared
  value is no longer silently replaced by the engine's enum constant.
- **Null object Variants compare correctly with `Nothing`** on the affected
  AST evaluation paths.
- **Godot geometry constructors preserve vector arguments.**
  `AABB(position, size)` accepts two Vector3 values; Plane supports a normal
  plus distance, normal plus point, or three points without converting
  Vector3 arguments to scalars or reading outside the argument list.

Regression fixtures accompany these changes. CI exercises the runtime suite,
AST/default parity, corpus, malformed-source mutations, editor lifecycle,
reference, packaging and performance gates. CI results are evidence for the
tested configurations, not a claim that every project or platform is certified.

## Downloads

Godot **4.6.1** remains the cross-platform baseline. Additional Linux
Godot 4.7.2 evidence is documented separately.

| Package | Download |
| --- | --- |
| Godot Asset Library addon | [Addon ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.4/VisualGasic_AssetLibrary_v5.7.0-beta.4.zip) |
| Linux x86-64 installer | [AppImage](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.4/VisualGasic-Installer-v5.7.0-beta.4-x86_64.AppImage) |
| Windows x64 installer | [EXE](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.4/VisualGasic-Installer-v5.7.0-beta.4-x86_64.exe) |
| macOS Intel / Apple Silicon setup | [Universal setup ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.4/VisualGasic-Installer-v5.7.0-beta.4-macos-universal.zip) |
| Linux offline setup with Godot | [Offline ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.4/VisualGasic-Installer-Offline-v5.7.0-beta.4-linux-x86_64.zip) |
| Windows offline setup with Godot | [Offline ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.4/VisualGasic-Installer-Offline-v5.7.0-beta.4-windows-x86_64.zip) |
| macOS offline setup with Godot | [Universal offline ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.4/VisualGasic-Installer-Offline-v5.7.0-beta.4-macos-universal.zip) |
| Examples and documentation | [Examples/docs ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.4/VisualGasic-Examples-and-Docs-v5.7.0-beta.4.zip) |

[Platform binaries and all assets](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.4)
include desktop editor, debug-export and release-export builds, plus Web
debug/release binaries. The macOS frameworks contain **both x86_64 and arm64**
and bundled runtime dependencies. [SHA256SUMS](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.4/SHA256SUMS)
and [BUILD_COMMIT.txt](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.4/BUILD_COMMIT.txt)
identify the downloads and source revision.

Mac setup is an unsigned command launcher, **not a notarized DMG**; Python 3
is required. Control-click the launcher and choose Open if prompted. Linux's
graphical setup requires Python 3 and Tkinter. Offline bundles include Godot
and the addon, not optional AI services.

The Asset Library ZIP contains only the addon. Publishing its store listing
requires a separate submission and moderator approval; this GitHub release
does not imply that the store has already updated.

## Scope and known limitations

This update concentrates on engine correctness, not a game feature announcement.
The examples archive includes the current sample sources. Experimental UI Forms
and the legacy IDE remain opt-in. Mac downloads are not Developer ID signed or
notarized. Remaining Godot editor shutdown/cold-import investigations and
the limits of Linux 4.7.2 evidence remain in the
[compatibility report](docs/compatibility/GODOT_4_7_2.md).

## Documentation and reporting

- [Installation and upgrade](docs/guides/INSTALLATION.md)
- [Documentation hub](docs/DOCS.md)
- [Language reference](docs/VisualGasic_Language_Reference.md)
- [Asset Library submission copy](ASSET_LIBRARY_CHANGELOG_5.7.0-beta.4.md)
- [Report a reproducible bug](https://github.com/xgreenrx-star/VisualGasic/issues)
- Website: https://xgreenrx-star.github.io/VisualGasic/

Releases remain occasional. Stable v6.0 is still the goal for early 2027;
this beta does not certify stable-v6 readiness.
