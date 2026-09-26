# VisualGasic 5.5.0-beta3 — Asset Library Changelog

**VisualGasic 5.5.0-beta3** — September 26, 2026  
Godot **4.6+** · New **Linux / Windows / Web** GDExtension binaries (rebuild required vs 5.5.0-beta2.x)

## Summary

Public beta with **retro game showcase**, **classic pixel canvas** (extra screen sizes + docs), **Elite Wire Slice** wireframe sample, vector canvas fixes, and Narcea classic-lane hints.

## Added

- Extended QuickBASIC-style **SCREEN** profiles and split playfields; `ScreenMode` / `Gfx*` queries.
- Samples: **qb_abc_showcase** (`.` mode gallery), **classic_screen_modes**, **elite_wire_slice**.
- Vector: **DrawRawWireMesh** batch path; mouse position builtins fixed for embedded game view.

## Fixed

- Vector canvas batched **DrawLine** no longer connects unrelated segments.
- Module import **Dim** defaults for packed arrays (mesh modules).

## Upgrade

- Replace entire `addons/visual_gasic/` folder — **do not** keep beta2 binaries.

## Links

- Release notes: https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.5.0-beta3.md
- Download: https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.5.0-beta3/VisualGasic_AssetLibrary_v5.5.0-beta3.zip
