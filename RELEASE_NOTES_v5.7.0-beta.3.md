# VisualGasic 5.7.0 Beta 3

This is a public beta on the road to **VG6**. It is not stable v6.
Back up your projects and replace the whole addon when you upgrade.
New native binaries are required.

## Release pace

Visual Gasic releases will keep slowing down from here. Funds are exhausted
and other projects take priority. We will still ship the occasional release
and bug fix.

**Stable v6.0 remains the goal for early 2027.** Specific bugs and feature
requests are welcome and will be reviewed:
[open an issue](https://github.com/xgreenrx-star/VisualGasic/issues).

A gameplay video of the Ash Meridian sample is planned for YouTube. It is
not in this release. When it is up, the notes and Facebook copy will get
the link.

## Downloads

Use **Godot 4.6.1** as the baseline. Godot 4.7.2 has additional Linux evidence.
That does not certify every platform, renderer, or export.

| What you need | Download |
| --- | --- |
| Add VisualGasic to an existing Godot project | [Asset Library addon ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.3/VisualGasic_AssetLibrary_v5.7.0-beta.3.zip) |
| Linux x86-64 setup | [AppImage installer](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.3/VisualGasic-Installer-v5.7.0-beta.3-x86_64.AppImage) |
| Windows x64 setup | [Windows installer](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.3/VisualGasic-Installer-v5.7.0-beta.3-x86_64.exe) |
| Mac setup, Intel and Apple Silicon | [macOS setup ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.3/VisualGasic-Installer-v5.7.0-beta.3-macos-universal.zip) |
| Linux setup with Godot included | [Linux offline bundle](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.3/VisualGasic-Installer-Offline-v5.7.0-beta.3-linux-x86_64.zip) |
| Windows setup with Godot included | [Windows offline bundle](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.3/VisualGasic-Installer-Offline-v5.7.0-beta.3-windows-x86_64.zip) |
| Mac setup with Godot included | [macOS offline bundle](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.3/VisualGasic-Installer-Offline-v5.7.0-beta.3-macos-universal.zip) |
| Games, teaching examples, and documentation | [Examples and docs ZIP](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.3/VisualGasic-Examples-and-Docs-v5.7.0-beta.3.zip) |

[All downloads and platform binaries](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.3)
include editor, debug-export, and release-export builds for Linux, Windows,
and universal macOS, plus debug/release Web binaries.
[SHA256 checksums](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.3/SHA256SUMS)
ship with the downloads.

The Mac setup is an **unsigned command launcher**, not a notarized DMG.
It needs Python 3. Control-click the launcher and choose Open if macOS prompts.
Linux setup needs Python 3 and Tkinter for the graphical wizard. An offline
bundle includes Godot and Visual Gasic, not optional AI services.

The Asset Library ZIP is the addon only. Updating the store listing still
needs a separate submission and moderator approval. If the store is behind,
install this ZIP.

## Runtime and compiler

These need the new native binaries. The AST walker, bytecode VM, and JIT
paths were kept together.

- **`On Error Resume Next`** no longer falls through the handler. The
  statement after a raised error runs.
- **`NodePath`, `StringName`, and `RID`** construct instead of compiling as
  ordinary calls. A variable named `task` is no longer consumed as the
  `Task` keyword.
- **Godot constants and enums** fold on every evaluator path:
  `HORIZONTAL_ALIGNMENT_CENTER`, `Vector2.UP`, `Key.KEY_ESCAPE`,
  `Projection()`, `Color.html`, scientific literals, and class sentinels
  such as `FileAccess`. Assigning `FileAccess` no longer creates an empty
  local that later raises error 91.
- **`ClassDB` static calls** such as `FileAccess.open` compile as
  `OP_CLASS_STATIC_CALL` instead of a method on a null variable.
- **Dictionary parameters** index as dictionaries, not packed arrays.
  In-place CowData size writes no longer corrupt mesh buffers.
- **Packed arrays:** index, append, and ribbon `For` loops compile as
  in-place ops / a fused native expand instead of `OP_CALL` per element.
- **Select Case jump tables** keep every case after dead-code removal and
  stay aligned so Windows release and MSVC builds can finish.

## Ash Meridian Part 1

The sample is in the examples download, not the Asset Library ZIP.

- Backlight Yard mesh, campaign save, landing, and Orac speech run in VG.
- **Black Channel** is a developer-destination flight encounter with original
  scenery, Kokoro-baked crew lines, and a persistent TTS worker.
- **Trace Cycle / vault** art kit and an isolated VG stage/save contract are
  in-tree. Play still uses campaign save version 1. The new vault route is
  not selected by Play until a later dest and save version 2.
- Boot splash uses the user-selected Lucid sketch with the credit
  **Music by Lucid nod**.
- Yard escape state uses `Me.failed` so an unset controller cannot alias
  the campaign failure flag.

Play F5: `samples/games/ash_meridian_part1/`. Black Channel is the
developer-terminal flight test, not the first-visit campaign.

## Still true from Beta 1 and Beta 2

Crystal Caverns, DATA sprite editing, Fix Indentation on folded code,
ambiguous procedure names (error 328), `color.r` on a Color variable, and
custom Narcea endpoints remain in this beta.

- [5.7.0 Beta 1](RELEASE_NOTES_v5.7.0-beta.1.md)
- [5.7.0 Beta 2](RELEASE_NOTES_v5.7.0-beta.2.md)

## Known limits

- This is a public beta. It is not a claim that VG matches GDScript speed
  or that every sample is certified.
- Experimental UI Forms and the legacy IDE stay opt-in.
- Mac packages are unsigned.
- Trace Cycle gameplay (turns, trails, chase) is not in Play.
- Godot editor shutdown and some cold-import crashes are still tracked in
  the [compatibility report](docs/compatibility/GODOT_4_7_2.md).

## Documentation

- [Installation](docs/guides/INSTALLATION.md)
- [Documentation hub](docs/DOCS.md)
- [Language reference](docs/VisualGasic_Language_Reference.md)
- [Asset Library blurb](ASSET_LIBRARY_CHANGELOG_5.7.0-beta.3.md)
- Website: https://xgreenrx-star.github.io/VisualGasic/
