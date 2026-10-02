# VisualGasic 5.6.0-beta1 — Asset Library Changelog

**VisualGasic 5.6.0-beta1** — October 2, 2026  
Godot **4.6+** · New **Linux / Windows / Web** GDExtension binaries (rebuild required vs 5.5.0-beta3)

## Summary

**Windows x64 native JIT ships for the first time** (Tier 2 / Tier 3 — same path as Linux). Feedback on real Windows machines requested. **C++ GDExtension core** also adds vector canvas **depth mesh** APIs (`BuildDepthMesh` / `AddWireTri3D`) for depth-tested procedural 3D, plus QB/classic draw speedups, Interface/Implements, Vector Crypt sample, IDE step-into and tooltip fixes.

## Added

- Windows x64 JIT (Tier 2 + Tier 3); `VG_JIT=0` to disable.
- **Engine (C++):** vector canvas `AddWireTri3D`, `BuildDepthMesh` + depth cache (SubViewport / MeshInstance3D).
- `Interface` / `Implements` (same-file checks).
- Sample: **vector_crypt** (procedural neon facility; uses depth mesh).

## Changed

- Faster QB 32-bit screen drawing; LINE/PAINT fidelity.
- Faster debugger step-into; Go to Definition across imports.

## Fixed

- JIT float slots with mixed ByRef/ByVal parameters.
- Plugin load (param popup typing).
- Tier 3 “platform not supported” on Windows.

## Upgrade

- Replace entire `addons/visual_gasic/` folder — **do not** keep beta3 binaries.

## Links

- Release notes: https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.6.0-beta1.md
- Download: https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.6.0-beta1/VisualGasic_AssetLibrary_v5.6.0-beta1.zip
- Performance / JIT: https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/manual/performance.md
