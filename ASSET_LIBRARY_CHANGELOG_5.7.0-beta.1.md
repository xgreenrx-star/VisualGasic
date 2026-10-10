# VisualGasic 5.7.0 Beta 1 — Asset Library submission copy

**Title:** VisualGasic
**Version:** 5.7.0-beta.1
**Godot:** 4.6.1 baseline
**License:** GPLv3
**Download:** https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.7.0-beta.1/VisualGasic_AssetLibrary_v5.7.0-beta.1.zip
**Repository:** https://github.com/xgreenrx-star/VisualGasic
**Issues:** https://github.com/xgreenrx-star/VisualGasic/issues

## Short description

Write Godot game logic in VB6-style BASIC. VisualGasic adds .vg scripts,
autocomplete, debugging, an Immediate window and reactive Whenever statements.
Edit DATA sprites as a grid of numbers or paint them in the integrated Sprite
Editor. Includes a JIT compiler and optional Narcea AI assistance.
Public beta; experimental UI Forms and the legacy IDE are opt-in.

## Description / update text

VisualGasic brings familiar BASIC syntax to Godot's scenes and nodes: Sub,
Function, Dim, For/Next, and readable event handlers.

5.7.0 Beta 1 is a substantial correctness and editor update:

- Runtime fixes for Tween, enums, typed collections, ByRef, Await, dictionaries,
  error handling, loops, DATA loading, arithmetic/JIT behavior, and recursion.
- More usable DATA sprite previews, sprite navigation, grid alignment, header
  help, folding, and visual editing that writes back to the source.
- UI contrast fixes, bounded dialogs, improved cleanup, and nonmodal handling
  when the native Script editor and VG editor contain different buffers.
- More reliable Windows Python worker pipes and native platform builds.
- Custom Narcea provider endpoints and model IDs.
- 80 audited teaching examples and stronger differential, mutation, lifecycle,
  and benchmark checks.

Crystal Caverns is included in the separate examples download: three caves,
twelve DATA sprites, Whenever reactions, VG-controlled shaders, DATA-generated
sound, and beginner-friendly comments. The Asset Library package itself installs
only the addon.

Native editor/debug/release builds are supplied for Linux x86-64, Windows x64,
and universal macOS; Web debug/release binaries are included. Back up projects
and replace the whole addon folder when upgrading.

This is a beta, not stable v6. Known engine shutdown/import issues and remaining
runtime differences are documented in the release notes. Store publication
requires a separate listing update and moderator approval.

Docs: https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.1/docs/DOCS.md
Release notes/downloads: https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.1
Crystal Caverns: https://github.com/xgreenrx-star/VisualGasic/tree/v5.7.0-beta.1/samples/showcases/crystal_caverns
Feature tour video: https://youtu.be/FUw8zgbn_tU
Vector Crypt video: https://youtu.be/ntpOTNflE_M
