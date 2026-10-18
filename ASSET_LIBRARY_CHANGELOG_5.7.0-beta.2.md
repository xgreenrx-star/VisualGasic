# VisualGasic 5.7.0 Beta 2 — Asset Library submission copy

**Title:** VisualGasic
**Version:** 5.7.0-beta.2
**Godot:** 4.6.1 baseline
**License:** GPLv3
**Download:** https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.2/VisualGasic_AssetLibrary_v5.7.0-beta.2.zip
**Repository:** https://github.com/xgreenrx-star/VisualGasic
**Issues:** https://github.com/xgreenrx-star/VisualGasic/issues

## Changelog

Paste this into the version changelog. Same Markdown shape as the 5.6.0-beta1 submission.

**VisualGasic 5.7.0-beta.2** — October 17, 2026
Godot **4.6+** · Bug-fix beta (not stable v6)

## Summary

Bug-fix update on the 5.7.0 beta. Releases will slow down: funds are exhausted, other projects come first, and occasional bug fixes continue. Stable v6.0 is still the goal for the end of 2026 or early 2027. Bug reports and feature requests are welcome.

## Fixed

- A local or parameter that hides a Sub or Function reports error **328**, Ambiguous name detected, instead of error 91. Recursion through the function's own name still works. `Color(...)` still constructs when a local is only named `color`.
- `color.r` on a Color variable reads the component. `Color.Red` is still the named constant.
- Dense integer Select Case keeps every case. A jump-table body is no longer deleted or left as an invalid opcode.
- Typed Array returns, a long Backlight City warp stall, re-entrant Whenever callbacks, save formatting, and inline palette clicks.

## Changed

- A full city build uses about **2.7×** GDScript's instruction count, down from about 5×. It is not faster than GDScript yet.
- Ash Meridian Part 1, including Backlight Yard, is in the separate examples download. This ZIP installs only the addon.

## Upgrade

- Replace the whole `addons/visual_gasic/` folder. Godot **4.6.1** is the baseline. Mac builds are unsigned.

## Links

- Release notes: https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.2
- Download: https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.2/VisualGasic_AssetLibrary_v5.7.0-beta.2.zip

## Short description

Write Godot game logic in VB6-style BASIC. VisualGasic adds .vg scripts,
autocomplete, debugging, an Immediate window, and reactive Whenever statements.
Edit DATA sprites as a grid of numbers or paint them in the integrated Sprite
Editor. Includes a JIT compiler and optional Narcea AI assistance.
Public beta 5.7.0-beta.2. Experimental UI Forms and the legacy IDE are opt-in.

## Description / update text

VisualGasic brings familiar BASIC syntax to Godot's scenes and nodes: Sub,
Function, Dim, For/Next, and readable event handlers.

5.7.0 Beta 2 is a bug-fix update on the 5.7.0 beta:

- A local or parameter that shares a procedure's name no longer turns the
  call into an array read (error 91). The call reports error 328, Ambiguous
  name detected. Recursion through the function's own name still works.
- `color.r` on a Color variable is a component read. `Color.Red` is still
  the named constant.
- Dense integer Select Case keeps every case. A jump-table body is no
  longer deleted or left as an invalid opcode.
- Typed Array returns, a long Backlight City warp stall, re-entrant Whenever
  callbacks, save formatting, and inline palette clicks are fixed.
- VM work reduced a full city build from about 5× GDScript's instruction
  count to about 2.7×. That build is not faster than GDScript yet.
- Ash Meridian Part 1's cities, including Backlight Yard, are in the examples
  download. The Asset Library ZIP installs only the addon.

Releases will slow down. We are out of funds and will concentrate on other
projects, and we will still ship the occasional bug fix. Stable v6.0 is still
the goal for the end of 2026 or early 2027. Bug reports and feature requests
are welcome.

Native editor, debug, and release builds are included for Linux x86-64,
Windows x64, and universal macOS, plus Web debug/release binaries. Back up
projects and replace the whole addon folder when upgrading. This is a beta,
not stable v6. Mac packages are unsigned. Store publication needs a separate
listing update and moderator approval.

Docs: https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.2/docs/DOCS.md
Release notes: https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.2
Issues: https://github.com/xgreenrx-star/VisualGasic/issues
