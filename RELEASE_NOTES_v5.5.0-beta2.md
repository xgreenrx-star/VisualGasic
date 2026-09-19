# VisualGasic 5.5.0-beta2 Release Notes

**Release Date:** September 2026  
**Status:** Beta (Pre-release)  
**Milestone:** M7 — Narcea Live Debug Capture, `samples/` layout, Godot-game wiring  
**Previous Release:** [5.5.0-beta1](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.5.0-beta1)  
**Target Engine:** Godot 4.6.1  
**Platforms:** Linux x86_64, Windows x86_64 (desktop)

---

## Overview

VisualGasic **5.5.0-beta2** is the **Narcea + packaging** beta: opt-in **Live Debug Capture** gives AI Pair local viewport snapshots and debugger context while you pause, the repository moves user Godot projects under **`samples/`**, and the language/runtime picks up **Connect**, **lambda handlers**, **RemoveAt**, and **autoload** patterns games need on Godot 4.6.

This cut also lands **`samples/games/brotato3d/`** — a 3D Brotato-style arena port — and documents the **Godot-first** editor story (VGasic floating workspace, experimental legacy Form Designer under [VG IDE Alpha](docs/manual/VG_IDE_ALPHA.md)).

Full changelog: [CHANGELOG.md](CHANGELOG.md#550-beta2---2026-09-19)

---

## Screenshots

### VGasic workspace — Code Navigator, floating panels, `.vg` modules

![VGasic workspace with Project Explorer, Toolbox, Properties, and HexEditor.vg](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/beta2_vgasic_workspace.png)

Open any sample under `samples/` → **VGasic** toolbar → tile **VG Help**, **Code Editor**, **Project Explorer**, **Toolbox**, **Properties**. See [docs/manual/VG_IDE_ALPHA.md](docs/manual/VG_IDE_ALPHA.md).

### Hex-style app — Form Designer + custom `_Draw` canvas (local dev preview)

![VG Hex Editor running with compare, hash, bookmarks, and search](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/beta2_hex_editor_running.png)

Shows a full VB6-style form app with modular `.vg` ops — useful reference for Form + canvas patterns (hex editor sample may ship in a follow-up commit).

### VG TwinPane — dual-pane file manager sample

![VG TwinPane dual-pane file manager](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/beta2_vg_twinpane.png)

`samples/apps/vg_twinpane/` — Form Designer file manager with VB6 Classic theme.

### Brotato3D — `samples/games/brotato3d/`

![Brotato3D character select — eight archetypes](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/beta2_brotato3d_character_select.png)

![Brotato3D wave combat in the arena](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/beta2_brotato3d_combat.png)

![Brotato3D — Player3D.vg in the VGasic code editor](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/beta2_brotato3d_vg_code.png)

![Brotato Mini — 20-wave victory screen](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/beta2_brotato_victory.png)

```text
Open samples/games/brotato3d/project.godot → F5
```

---

## What shipped

### Narcea Live Debug Capture (Phases A–D baseline)

- **Opt-in per run** — Project Settings → **Vg → Narcea** (`live_debug_capture`), then **Live debug capture (this run)** in AI Pair.
- **Local-only ring buffer** — viewport PNG (downscaled), flat UI tree, stack/locals JSON; purged on **Stop** or **Clear capture** (Immediate tab).
- **Explain screen**, **Refresh snapshot**, optional **Drive mode** (paused input inject), MCP tools `narcea_live_list_snapshots` / `narcea_live_get_snapshot`.
- **Narcea system prompt** teaches capture semantics; vision gated by provider support.
- Spec + QA: [docs/development/NARCEA_LIVE_DEBUG_CAPTURE.md](docs/development/NARCEA_LIVE_DEBUG_CAPTURE.md), `tests/test_vg_narcea_live_session.gd`.

### Repository layout (`samples/` + `engine_lab/`)

- User-facing Godot projects live under **`samples/{games,apps,demos,showcases,internal}/`**; legacy `projects/` and top-level `demos/` are compatibility symlinks.
- Developer harness moved to **`engine_lab/`** (symlink `demo` → `engine_lab`).
- Showcase **AVI/MP4** outputs are **gitignored** — watch [Beta Showcase on YouTube](https://youtu.be/FUw8zgbn_tU) or run `scripts/record_*.sh` locally.
- Map: [docs/REPO_LAYOUT.md](docs/REPO_LAYOUT.md), [samples/README.md](samples/README.md).

### Language & runtime (since 5.5.0-beta1)

- **Bound `Connect`**, **lambda signal handlers**, **`RemoveAt`**, **autoload globals** — standard VG for Godot-native games (`test_connect_bound.vg`, `test_connect_lambda.vg`, `test_autoload_global.vg`, `test_remove_at.vg`).
- **Module `Dim` namespace shadowing** — e.g. `Dim camera` shadows `Camera.*` so `LookAt` dispatches correctly (`test_camera_namespace_shadow.vg`).
- **Packed entity scan fusion** and gameplay benchmark refresh (see [docs/manual/performance.md](docs/manual/performance.md)).
- **Optional native JIT (`VG_JIT`)** documented — default-off bytecode VM, opt-in Tier 2/3.

### Samples & docs

- **`samples/games/brotato3d/`** — 3D arena roguelite port with Kenney assets and modular `.vg` scripts.
- **Documentation sync** — Godot-first [introduction](docs/getting_started/introduction.md), [CODE_EDITOR.md](docs/manual/CODE_EDITOR.md), [debugging.md](docs/manual/debugging.md#narcea-live-debug-capture-opt-in), Narcea live capture index entries.

---

## Validation

- `./run_test_suite.sh --vg-only` — **171** files, **1010/1020** assertions passed on the release runner (see Known notes).
- `tests/test_vg_narcea_live_session.gd` — headless live-session unit test.
- GDExtension release build — **fresh Linux** editor/template `.so` (Sep 19); **Windows** `.dll` from last green cross-compile (bundled in Asset Library zip until local C++ WIP rebuilds Windows).
- Asset Library zip — `release/v5.5.0-beta2/VisualGasic_AssetLibrary_v5.5.0-beta2.zip` (~25 MB, Linux + Windows binaries).

---

## Install

1. Install **Godot 4.6.1** (Mono not required for VG).
2. Download **`VisualGasic_AssetLibrary_v5.5.0-beta2.zip`** from GitHub Releases.
3. In Godot: **AssetLib → Import** or unzip into your project’s `addons/visual_gasic/`.
4. Enable **Project → Project Settings → Plugins → VisualGasic**.
5. Optional: `bash install.sh` for the `vg` CLI.

---

## Release checklist

- [x] Bump `VERSION` to `5.5.0-beta2`
- [x] `RELEASE_NOTES_v5.5.0-beta2.md` + CHANGELOG section
- [x] Screenshots under `docs/screenshots/beta2_*.png`
- [x] Build Linux/Windows GDExtension + Asset Library zip
- [ ] Git tag `v5.5.0-beta2` + GitHub Pre-release (Latest)

---

## Known notes

- **Test suite:** `test_for_each.vg`, `test_ipc.vg`, and `test_type_conversion.vg` may fail on some hosts (environment/platform); core game and Narcea regressions remain green.
- **GRAVEN slice** (from beta1) is still a developer preview — not showcase-ready.
- **Legacy Form Designer / VG IDE shell** remains experimental Alpha — not v6.0 critical path.
- **Hex editor** screenshots reflect in-progress app work; ship path is `samples/apps/vg_hex_editor/` when ready.
