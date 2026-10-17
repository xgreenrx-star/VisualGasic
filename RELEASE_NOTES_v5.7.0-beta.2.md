# VisualGasic 5.7.0 Beta 2

This is a bug-fix release on the 5.7.0 public beta. It is not stable v6.
Back up your projects and replace the whole addon when you upgrade.

## Release pace

Visual Gasic releases will slow down. We are out of funds and will concentrate
on other projects. We will still issue the occasional release and bug fix.

We still hope to have a stable v6.0 by the end of 2026 or early 2027.
Specific bugs and feature requests are welcome and will be reviewed:
[open an issue](https://github.com/xgreenrx-star/VisualGasic/issues).

## Downloads

Use **Godot 4.6.1** as the baseline. Godot 4.7.2 has additional Linux evidence.
That does not certify every platform, renderer, or export.

| What you need | Download |
| --- | --- |
| Add VisualGasic to an existing Godot project | [Asset Library addon ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.2/VisualGasic_AssetLibrary_v5.7.0-beta.2.zip) |
| Linux x86-64 setup | [AppImage installer](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.2/VisualGasic-Installer-v5.7.0-beta.2-x86_64.AppImage) |
| Windows x64 setup | [Windows installer](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.2/VisualGasic-Installer-v5.7.0-beta.2-x86_64.exe) |
| Mac setup, Intel and Apple Silicon | [macOS setup ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.2/VisualGasic-Installer-v5.7.0-beta.2-macos-universal.zip) |
| Linux setup with Godot included | [Linux offline bundle](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.2/VisualGasic-Installer-Offline-v5.7.0-beta.2-linux-x86_64.zip) |
| Windows setup with Godot included | [Windows offline bundle](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.2/VisualGasic-Installer-Offline-v5.7.0-beta.2-windows-x86_64.zip) |
| Mac setup with Godot included | [macOS offline bundle](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.2/VisualGasic-Installer-Offline-v5.7.0-beta.2-macos-universal.zip) |
| Games, teaching examples, and documentation | [Examples and docs ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.2/VisualGasic-Examples-and-Docs-v5.7.0-beta.2.zip) |

[All downloads and platform binaries](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.2)
include editor, debug-export, and release-export builds for Linux, Windows,
and universal macOS, plus debug/release Web binaries.
[SHA256 checksums](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.2/SHA256SUMS)
ship with the downloads.

The Mac setup is an **unsigned command launcher**, not a notarized DMG.
It needs Python 3. Control-click the launcher and choose Open if macOS prompts.
Linux setup needs Python 3 and Tkinter for the graphical wizard. An offline
bundle includes Godot and Visual Gasic, not optional AI services.

The Asset Library ZIP is the addon only. Updating the store listing still
needs a separate submission and moderator approval. If the store is behind,
install this ZIP.

## Bug fixes

New native binaries are required.

- **A local that hides a procedure.** `Dim ink As Color` in a Sub that also
  has `Function Ink` used to compile `Ink(...)` as an array read and raise
  error 91, "Object variable not set". That call is now error **328**,
  "Ambiguous name detected". The function's own name is still a recursive
  call. `Color(...)` still constructs when a local is merely named `color`.
- **`color.r` on a Color variable.** A parameter or local named `color` was
  folded as the named-color constant `Color.r`, which is not a color name.
  Component reads now stay on the variable. `Color.Red` still folds.
- **Typed Array returns** and a Backlight City warp that stalled for many
  seconds are fixed in the VM.
- **Re-entrant Whenever** callbacks run after the callback already on the
  stack, instead of overlapping it.
- **Save formatting** keeps DATA padding, quoted spaces, and compound
  comparisons. Inline palette clicks select the brush.

The AST walker, the bytecode VM, and the default JIT path were checked
together on the new name-resolution test.

## What else landed since Beta 1

These are included because they are already on this beta line. They are not
a new feature release.

- **Ash Meridian Part 1** runs its cities in Visual Gasic, including a
  separate Backlight Yard district with depot doors, distance fog, and a
  procedural sky shader.
- **VM speed.** Inline call frames, packed-array append fusion, and cheaper
  numeric stack ops cut the Backlight City build from about 5× GDScript's
  instruction count to about **2.7×**. Microbenchmark wins from older tables
  are still microbenchmarks. A full city build is not faster than GDScript yet.
- **Behavior evidence** in the Code Navigator: an opt-in ring, protected
  expectations, a change card, and rollback. Narcea cannot edit the
  expectation file.

## Still true from Beta 1

Crystal Caverns, DATA sprite editing, Fix Indentation on folded code, and
the custom Narcea endpoints remain in this beta. Notes for that release:
[5.7.0 Beta 1](RELEASE_NOTES_v5.7.0-beta.1.md).

## Known limits

- This is a public beta. It is not a claim that VG matches GDScript speed
  or that every sample is certified.
- Experimental UI Forms and the legacy IDE stay opt-in.
- Mac packages are unsigned.
- Godot editor shutdown and some cold-import crashes are still tracked in
  the [compatibility report](docs/compatibility/GODOT_4_7_2.md).

## Documentation

- [Installation](docs/guides/INSTALLATION.md)
- [Documentation hub](docs/DOCS.md)
- [Language reference](docs/VisualGasic_Language_Reference.md)
- [Asset Library blurb](ASSET_LIBRARY_CHANGELOG_5.7.0-beta.2.md)
