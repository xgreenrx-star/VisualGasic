# VisualGasic 5.3.0-Beta7 Release Notes

**Release Date:** August 21, 2026  
**Status:** Beta (Feature Complete, Early Adopter Testing)  
**Previous Release:** [5.3.0-Beta6](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta6) (August 18, 2026)  
**Target Engine:** Godot 4.6.1  
**Platforms:** Linux x86_64, Windows x86_64 (desktop)

---

## Overview

VisualGasic 5.3.0-Beta7 is a **language correctness and CI hardening** release. Bracket array indexing (`arr[i]`) now works — fixing a silent parser bug that broke 3D mob chase code using `GetNodesInGroup("player")` then `players[0]`. The full **`.vg` regression suite** runs in CI on every PR, and **Narcea** gains reference offers, web-assisted clone scaffolds, and Cursor SDK reliability fixes.

**Key numbers:** 871/871 regression assertions · 117 test files · 332/332 reference examples parse-clean.

---

## What's New Since 5.3.0-Beta6

### Fixed — Bracket Array Indexing (Critical)

- **`arr[i]` subscript** — postfix `[index]` now parses in expressions and lvalues. Previously `players[0]` silently evaluated to the whole `Array`, so `.GlobalPosition` returned Nothing and Vector3 math failed with `'dir' is Nothing`.
- **VB6 `arr(i)` unchanged** — both forms work; use whichever matches your style.

### Fixed — ByRef Array Slots

- **Bytecode write-back** — `Func arr(i)` ByRef parameters now persist writes back into array slots (regression: `test_byref_array_slot.vg`).

### Added — Regression Gates & Tests

- **CI test suite** — `.github/workflows/ci.yml` runs `./run_test_suite.sh --vg-only` after editor build.
- **`run_test_suite.sh --vg-only`** — skips GDScript/Narcea golden phases for fast PR gating.
- **New tests** — `test_array_bracket_index.vg`, `test_syntax_parity.vg`, `test_vector3_subtract.vg`, `test_vector3_global_position.vg`, `test_vector3_getnodesingroup.vg`.

### Added — Narcea & IDE

- **Reference offer on Send** — Narcea can attach Programmer's Reference entries to replies.
- **User-assisted web references** — Phase 0+2 game-clone scaffolding with auditable sources.
- **Canvas platformer / 3D prompts** — improved AI Pair scaffold templates.
- **Cursor SDK** — cross-platform venv bootstrap (Windows, PEP 668 Linux, macOS Python discovery).
- **Visual AI audit** — agent run graphs via Working Nodes plugin.
- **Windows AI Pair** — OS-aware paths and dashboard builds.

Full changelog: [CHANGELOG.md](CHANGELOG.md#530-beta7---2026-08-21)

---

## Documentation

| Topic | Link |
| --- | --- |
| Documentation Hub | [docs/DOCS.md](docs/DOCS.md) |
| Getting Started | [docs/guides/GET_STARTED.md](docs/guides/GET_STARTED.md) |
| Installation | [docs/guides/INSTALLATION.md](docs/guides/INSTALLATION.md) |
| Language Reference | [docs/VisualGasic_Language_Reference.md](docs/VisualGasic_Language_Reference.md) |
| Known Issues | [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) |
| Changelog | [CHANGELOG.md](CHANGELOG.md) |
| Asset Library submission | [docs/development/ASSET_LIBRARY_SUBMISSION.md](docs/development/ASSET_LIBRARY_SUBMISSION.md) |

---

## Installation

### Linux

**Option 1: AppImage (Recommended)**
```bash
wget https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-Beta7/VisualGasic-Installer-v5.3.0-Beta7-x86_64.AppImage
chmod +x VisualGasic-Installer-v5.3.0-Beta7-x86_64.AppImage
./VisualGasic-Installer-v5.3.0-Beta7-x86_64.AppImage
```

**Option 2: Bootstrap Script**
```bash
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/scripts/bootstrap_install.sh | bash
```

**Option 3: Godot Asset Library**

Install **VisualGasic** from the AssetLib tab inside Godot 4.6.1+, or download [`VisualGasic_AssetLibrary_v5.3.0-Beta7.zip`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-Beta7/VisualGasic_AssetLibrary_v5.3.0-Beta7.zip).

### Windows

```powershell
Invoke-WebRequest -Uri "https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.3.0-Beta7/VisualGasic-Installer-v5.3.0-Beta7-x86_64.exe" -OutFile installer.exe
.\installer.exe
```

### Manual (any platform)

1. Extract `VisualGasic_v5.3.0-Beta7_<platform>_x86_64.zip` into your project's `addons/` folder  
2. **Project → Project Settings → Plugins → VisualGasic** → Enable  
3. Restart Godot  

Download: [v5.3.0-Beta7 release page](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta7)
