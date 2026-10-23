# VisualGasic 5.7.0 Beta 3 — Asset Library submission copy

**Title:** VisualGasic
**Version:** 5.7.0-beta.3
**Godot:** 4.6.1 baseline
**License:** GPLv3
**Download:** https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.3/VisualGasic_AssetLibrary_v5.7.0-beta.3.zip
**Repository:** https://github.com/xgreenrx-star/VisualGasic
**Issues:** https://github.com/xgreenrx-star/VisualGasic/issues

## Changelog

Copy the block below into **Version Changelog** on store.godotengine.org. Same rules as 5.5.0-beta2.1: Markdown preview, no BBCode, no `•` bullets, no `#` headings. Blank line before each list. Each line starts with `-` and a space. Use `**bold**` and backticks for code.

```markdown
**VisualGasic 5.7.0-beta.3** — October 23, 2026  
Public beta on 5.7.0-beta.2 · Godot 4.6+ · Linux / Windows / macOS / Web binaries in this zip

**Summary**

Releases keep slowing down. Funds are exhausted and other projects come first. Occasional bug fixes will continue. Stable v6.0 is still the goal for early 2027. Bug reports and feature requests are welcome.

**Fixed**

- `On Error Resume Next` continues after the handler. `NodePath`, `StringName`, and `RID` construct. A variable named `task` is not the `Task` keyword
- Godot constants and enums fold: `Vector2.UP`, `FileAccess`, `Key.KEY_ESCAPE`, `HORIZONTAL_ALIGNMENT_CENTER`, `Projection()`, `Color.html`
- `FileAccess.open` and other ClassDB static calls compile. Dictionary parameters index as dictionaries. Packed mesh size writes no longer corrupt buffers
- Packed index/append and ribbon `For` loops compile in-place. Select Case jump tables keep every case on Windows release/MSVC builds

**Changed**

- Ash Meridian Part 1 (yard, campaign, Black Channel dest, Trace Cycle kit) is in the separate examples download. This ZIP installs only the addon. Play still uses campaign save version 1
- Native binaries changed. Replace the whole `addons/visual_gasic/` folder

**Upgrade**

- Godot **4.6.1** is the baseline. Mac builds are unsigned

**Links**

- Release notes: https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.3
- Download: https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.3/VisualGasic_AssetLibrary_v5.7.0-beta.3.zip
```

## Short description

Write Godot game logic in VB6-style BASIC. VisualGasic adds .vg scripts,
autocomplete, debugging, an Immediate window, and reactive Whenever statements.
Edit DATA sprites as a grid of numbers or paint them in the integrated Sprite
Editor. Includes a JIT compiler and optional Narcea AI assistance.
Public beta 5.7.0-beta.3. Experimental UI Forms and the legacy IDE are opt-in.

## Description / update text

VisualGasic brings familiar BASIC syntax to Godot's scenes and nodes: Sub,
Function, Dim, For/Next, and readable event handlers.

5.7.0 Beta 3 is a compiler and sample update on the 5.7 beta:

- On Error Resume Next continues after the handler. NodePath, StringName,
  and RID construct.
- Godot constants and enums such as Vector2.UP, FileAccess, and
  Key.KEY_ESCAPE fold instead of coming back null.
- ClassDB static calls, dictionary keys, packed mesh loops, and Select Case
  jump tables are fixed. Packed index/append compiles in-place.
- Ash Meridian Part 1 is in the examples download. The Asset Library ZIP
  installs only the addon. Play still uses campaign save version 1.

Releases keep slowing down. We are out of funds and will concentrate on
other projects, and we will still ship the occasional bug fix. Stable v6.0
is still the goal for early 2027. Bug reports and feature requests are
welcome.

Native editor, debug, and release builds are included for Linux x86-64,
Windows x64, and universal macOS, plus Web debug/release binaries. Back up
projects and replace the whole addon folder when upgrading. This is a beta,
not stable v6. Mac packages are unsigned. Store publication needs a separate
listing update and moderator approval.

Docs: https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.3/docs/DOCS.md
Release notes: https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.3
Issues: https://github.com/xgreenrx-star/VisualGasic/issues
