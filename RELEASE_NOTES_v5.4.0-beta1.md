# VisualGasic 5.4.0-beta1 Release Notes

**Release Date:** August 30, 2026  
**Status:** Beta (Pre-release)  
**Milestone:** Performance + IDE + Beta Showcase (pre-M5)  
**Previous Release:** [5.3.0-Beta7](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta7) (August 21, 2026)  
**Target Engine:** Godot 4.6.1  
**Platforms:** Linux x86_64, Windows x86_64 (desktop)  
**Website:** [xgreenrx-star.github.io/VisualGasic](https://xgreenrx-star.github.io/VisualGasic/)

---

## Overview

VisualGasic **5.4.0-beta1** is the **full-speed beta**: VG now beats GDScript on every published compute and draw benchmark. Draw grid-loop fusion compiles hot `_Draw` paths to native C++; FunctionCall — previously VG’s weak spot — is fixed via compiler inlining and nested-loop fusion. A **CI benchmark regression gate** blocks speed regressions before they ship.

This cut also ships the **VG Beta Showcase** — a ~6-minute Godot project tour (Backrooms hub, shader reel, About page, Squash tease, Neon Runner, Vector Storm) plus a Movie Maker recording script for frame-perfect promo video.

**Headline:** **12/12 compute** · **9/9 draw** · **891/891** regression assertions · checksums verified on static workloads.

**On the road to VG6:** Public betas stay on the **5.x** train; **v6.0.0** (January 2027 target) is the first stable **VG6** release — same spirit as VB6, production-ready.

Full changelog: [CHANGELOG.md](CHANGELOG.md#540-beta1---2026-08-30) · Canonical numbers: [BENCHMARK_PUBLISHED_RESULTS.md](BENCHMARK_PUBLISHED_RESULTS.md)

---

## Screenshots

### Beta Showcase — title & benchmark tour

![VG Beta Showcase title screen — 5.4.0-BETA1, 12/12 compute](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/Screenshot%20at%202026-08-25%2013-59-02.png)

Open `projects/vg_beta_showcase/` in Godot 4.6.1, press **F5**. **Space** skips segments; **ESC** quits. See [projects/vg_beta_showcase/README.md](projects/vg_beta_showcase/README.md) and [ARCHITECTURE.md](projects/vg_beta_showcase/ARCHITECTURE.md).

### IDE — DataFile sidecar, context rail, AI Pair

![Visual Gasic IDE with DataFile inspector, context rail, and AI Pair panel](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/Screenshot%20at%202026-08-25%2010-50-34.png)

Narcea AI Pair, `.vgd` DataFile preview, sprite Data editor, and multi-platform GDExtension binaries in one workspace.

### Narcea AI Pair (Beta7 carry-forward)

![Narcea End command and menu form scaffold](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/beta6_narcea_menu_form_end_command.png)

![AI provider keys panel](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/beta6_narcea_ai_provider_keys.png)

---

## What's New Since 5.3.0-Beta7

### VG Beta Showcase (`projects/vg_beta_showcase/`)

| Segment | What you see |
|---------|----------------|
| **Speed Bench Tour** | Title splash with live **12/12 compute · 9/9 draw** counters |
| **Backrooms hub** | Liminal hallways, portal zoom transitions, feature screenshots on walls |
| **Shader Showcase** | Synth grid, liquid chrome metaball raymarch, fault cube deconstruction |
| **About VG** | Border scroller, Pac-Man belt, live feature/benchmark panels |
| **Squash tease** | Godot First 3D Game tutorial running in `.vg` with autopilot |
| **Neon Runner** | `dash.vg` side-scroller with neon grid shaders |
| **Vector Storm** | 60s attract mode → playable bullet-hell |
| **End card** | Lucid banner ripple, vignette, replay / play Storm |

**Recording:** frame-perfect capture via Godot Movie Maker:

```bash
scripts/record_vg_beta_showcase.sh
# → projects/vg_beta_showcase/vg_beta_showcase.avi
# → vg_beta_showcase.mp4 (when ffmpeg is installed)
```

Movie mode auto-advances segments, hides skip hints, and quits after the end-card hold.

### Performance — Draw Fusion (9/9 vs GDScript)

- **Grid-loop fusion** — whole `_Draw` loops emit `OP_DRAW_*_GRID_LOOP` opcodes; bypass per-primitive VM dispatch.
- **Draw batch recorder** — batches primitives before native dispatch.
- **F64 draw opcodes + color folding** — tighter numeric paths for rects, lines, circles, sprites.
- **Optimizer ↔ disassembler sync** — draw opcode operand sizes must stay aligned (`visual_gasic_optimizer.cpp` / `visual_gasic_script.cpp`).

### Performance — FunctionCall (12/12 vs GDScript)

- **Trivial helper inlining** — `Function Helper(x As Long) As Long` with body `Helper = x + 1` inlines at expression call sites.
- **Assignment fusion** — `s = Helper(s)` → `OP_INC_LOCAL_I64` / `OP_ADD_LOCAL_I64_CONST`.
- **Nested-loop closed form** — double `For` with inner `s = Helper(s)` → single multiply-add (no 50k `OP_CALL` dispatches).
- **Before/after:** FunctionCall ~294 ms–1.7 s (VG) vs ~6–10 ms (GD) → **~140 µs vs ~8,448 µs** (~60× faster than GDScript).

### Vector canvas (About page + editor)

- Native vector canvas draw-path fixes for text panels and benchmark scroller on the About segment.
- Editor plugin updates in `vector_canvas.gd` / `vg_vector_api.gd`.

### CI & Regression

- **`scripts/benchmark_regression_check.sh`** in CI after editor build (compute + draw; 5% slack).
- **`test_function_call_inline.vg`** — compiler fusion regression test.
- **`scripts/prepare_ci_gdextension.sh`** — materializes `bin/` for fresh clones.
- **891/891** `.vg` regression assertions (was 871 in Beta7).

### IDE (carried from post-Beta7 `main`)

- Context rail sidecar, literal convert panel, sprite Data editor, New Level wizard.
- Track D groundwork — `.vgd` / `DataFile` sidecar, Tiled import hooks.

### Fixed — CInt rounding

- **`CInt(3.7)`** returns **4** (VB6-style round), not truncated 3.

---

## Downloads

All assets for this release: **[github.com/xgreenrx-star/VisualGasic/releases/tag/v5.4.0-beta1](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.4.0-beta1)**

> **Portable platform zips discontinued:** We no longer ship `VisualGasic_v*_linux_x86_64.zip` / `*_windows_x86_64.zip` (they exceeded GitHub’s 2 GB limit and duplicated demos/docs). **Install Godot 4.6.1+**, then add VisualGasic via the **Asset Library** (in-editor), the **Asset Library zip**, the **minimal addon zip**, or a **one-click / offline installer** below.

| Platform | Asset | Direct link |
|----------|-------|-------------|
| **Linux (recommended)** | AppImage installer | [VisualGasic-Installer-v5.4.0-beta1-x86_64.AppImage](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-Installer-v5.4.0-beta1-x86_64.AppImage) |
| **Linux (offline)** | Bundled Godot + addon | [VisualGasic-Installer-Offline-v5.4.0-beta1-linux-x86_64.zip](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-Installer-Offline-v5.4.0-beta1-linux-x86_64.zip) |
| **Windows (recommended)** | NSIS installer | [VisualGasic-Installer-v5.4.0-beta1-x86_64.exe](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-Installer-v5.4.0-beta1-x86_64.exe) |
| **Windows (offline)** | Bundled Godot + addon | [VisualGasic-Installer-Offline-v5.4.0-beta1-windows-x86_64.zip](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-Installer-Offline-v5.4.0-beta1-windows-x86_64.zip) |
| **Godot Asset Library** | Single-addon zip | [VisualGasic_AssetLibrary_v5.4.0-beta1.zip](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic_AssetLibrary_v5.4.0-beta1.zip) |
| **Manual (addon only)** | Minimal zip | [VisualGasic-v5.4.0-beta1.zip](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-v5.4.0-beta1.zip) |

**Godot Asset Library (in-editor):** [store.godotengine.org/asset/visual-gasic/visual-gasic](https://store.godotengine.org/asset/visual-gasic/visual-gasic/)

---

## Installation

### Linux

**Option 1: AppImage (Recommended)**
```bash
wget https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-Installer-v5.4.0-beta1-x86_64.AppImage
chmod +x VisualGasic-Installer-v5.4.0-beta1-x86_64.AppImage
./VisualGasic-Installer-v5.4.0-beta1-x86_64.AppImage
```

**Option 2: Bootstrap Script**
```bash
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/scripts/bootstrap_install.sh | bash
```

**Option 3: Godot Asset Library**

Install **VisualGasic** from the AssetLib tab inside Godot 4.6.1+, or download [`VisualGasic_AssetLibrary_v5.4.0-beta1.zip`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic_AssetLibrary_v5.4.0-beta1.zip).

**Try the showcase:** clone this repo (or use the one-click installer), open `projects/vg_beta_showcase/project.godot`, enable VisualGasic, press **F5**.

### Windows

```powershell
Invoke-WebRequest -Uri "https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-Installer-v5.4.0-beta1-x86_64.exe" -OutFile installer.exe
.\installer.exe
```

### Manual (existing Godot project)

You need **Godot 4.6.1+** installed separately. Then either:

- **Asset Library (in-editor):** AssetLib tab → search **VisualGasic** → Download → Install → enable the plugin, or
- **Release zip:** download [`VisualGasic_AssetLibrary_v5.4.0-beta1.zip`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic_AssetLibrary_v5.4.0-beta1.zip) or [`VisualGasic-v5.4.0-beta1.zip`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-v5.4.0-beta1.zip), extract `addons/visual_gasic/` into your project’s `addons/` folder.

1. Enable **VisualGasic** in Project Settings → Plugins.
2. Restart Godot.

Full steps: [docs/guides/INSTALLATION.md](docs/guides/INSTALLATION.md#-method-4-manual-installation-from-github-release).

---

## Documentation

| Topic | Link |
| --- | --- |
| Published benchmarks | [BENCHMARK_PUBLISHED_RESULTS.md](BENCHMARK_PUBLISHED_RESULTS.md) |
| Performance guide | [docs/manual/performance.md](docs/manual/performance.md) |
| Getting Started | [docs/guides/GET_STARTED.md](docs/guides/GET_STARTED.md) |
| Beta Showcase README | [projects/vg_beta_showcase/README.md](projects/vg_beta_showcase/README.md) |
| Changelog | [CHANGELOG.md](CHANGELOG.md) |
| Version policy | [docs/VERSIONING.md](docs/VERSIONING.md) |

---

## Known Issues

- **MovingFilledRects checksum** — frame-count timing differs slightly from GDScript; speed-only comparison.
- **Non-trivial multi-statement helpers** — general in-VM fast call path not yet implemented; only fusion/inlining patterns covered by tests.
- **Form Designer** — known bugs; UI Forms experimental plugin is the long-term replacement.

See [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md).

---

## Upgrade from 5.3.0-Beta7

1. Back up your project.
2. Replace `addons/visual_gasic/` with the new release (or re-run the installer).
3. Re-enable the plugin in Project Settings.
4. Run your project's `.vg` files — bracket indexing and ByRef fixes from Beta7 are unchanged.

No breaking language changes in this beta; focus is performance, CI hardening, and the showcase project.
