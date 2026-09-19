# VisualGasic 5.5.0-beta2.1 — Editor hotfix

**Release Date:** September 19, 2026  
**Status:** Public beta patch  
**Previous Release:** [5.5.0-beta2](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.5.0-beta2)  
**Requires:** Godot **4.6.1+**  
**Binaries:** Unchanged from 5.5.0-beta2 (Linux + Windows GDExtension in zip)

---

## Overview

Small **addon-only** update: fixes **VG Help** for user-declared symbols and restores **in-file Find/Replace** in the VG Code Editor. No C++ / VM changes.

### Fixes

- **VG Help** — `Dim` / Const / Sub / Function under the caret show type, scope, definition line, and clickable **Go to Definition** in the floating assist panel.
- **Find / Replace** — **Ctrl+F**, **Ctrl+H**, **F3**, context menu; find bar works in the floating VG Code Editor workspace.
- **Go To Definition** — Shared Import/module resolution in the addon.

### Install

1. Download **`VisualGasic_AssetLibrary_v5.5.0-beta2.1.zip`** from this release.
2. Replace your project’s `addons/visual_gasic/` (or import via AssetLib when listed).
3. Re-enable the plugin if Godot prompts you.

Changelog: [CHANGELOG.md](CHANGELOG.md#550-beta21---2026-09-19)
