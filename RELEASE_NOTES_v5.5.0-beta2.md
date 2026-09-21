# VisualGasic 5.5.0-beta2 Release Notes

**Release Date:** September 19, 2026  
**Status:** Public beta  
**Previous Release:** [5.5.0-beta1](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.5.0-beta1)  
**Requires:** Godot **4.6.1+** (Mono not required)  
**Platforms:** Linux and Windows GDExtension binaries in the Asset Library zip

---

## Overview

**VisualGasic** is a VB6-style language (`.vg`) and Godot editor addon: readable event handlers, a debugger, and an in-editor AI assistant (**Narcea**). This beta is for anyone already on Godot who wants clearer game logic and better tooling without leaving the engine.

### Highlights in 5.5.0-beta2

- **Narcea Live Debug Capture (opt-in)** — While you debug, Narcea can use **local** screenshots and variable context to explain what’s on screen. Nothing is uploaded unless you send chat to a cloud AI provider. Data is cleared when you stop the game.
- **Real Godot games in VG** — `Connect`, lambda handlers, `RemoveAt`, and autoload globals work the way modern Godot projects expect. New sample: **`samples/games/brotato3d/`** (3D arena roguelite).
- **Cleaner repo layout** — Sample projects live under **`samples/`** (`games`, `apps`, `demos`, `showcases`). Old `projects/` paths are symlinks for now; see [REPO_LAYOUT.md](docs/REPO_LAYOUT.md).
- **Speed** — Still **12/12** compute and **9/9** draw benchmarks ahead of GDScript, plus new **gameplay-style** numbers (e.g. tight loops and entity updates up to **~65×** on published Linux tests). Tables: [BENCHMARK_PUBLISHED_RESULTS.md](BENCHMARK_PUBLISHED_RESULTS.md).

### Install (60 seconds)

1. Download **`VisualGasic_AssetLibrary_v5.5.0-beta2.zip`** below (or from Asset Library when approved).
2. Unzip into your project’s `addons/visual_gasic/` (or import via Godot AssetLib).
3. **Project → Project Settings → Plugins** → enable **VisualGasic**.

Try a sample: open `samples/games/brotato3d/project.godot` or `samples/showcases/vg_beta_showcase/project.godot` → **F5**.

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

- **Opt-in per run** — Project Settings → **Vg → Narcea** (`live_debug_capture`), then **Live debug capture (this run)** in Vibe Code.
- **Local-only ring buffer** — viewport PNG (downscaled), flat UI tree, stack/locals JSON; purged on **Stop** or **Clear capture** (Immediate tab).
- **Explain screen**, **Refresh snapshot**, optional **Drive mode** (paused input inject), MCP tools `narcea_live_list_snapshots` / `narcea_live_get_snapshot`.
- **Narcea system prompt** teaches capture semantics; vision gated by provider support.
- Spec + QA: [docs/development/NARCEA_LIVE_DEBUG_CAPTURE.md](docs/development/NARCEA_LIVE_DEBUG_CAPTURE.md), `tests/test_vg_narcea_live_session.gd`.

### Repository reorganization (`samples/` + `engine_lab/`)

If you bookmarked old paths, update your clones:

| Old path | New canonical path |
|----------|-------------------|
| `projects/<game\|app>` | `samples/games/<name>` or `samples/apps/<name>` |
| `demos/...` | `samples/demos/...` |
| `demo/` (harness) | `engine_lab/` (symlink `demo` → `engine_lab` kept for one cycle) |

- **Showcases:** `samples/showcases/vg_beta_showcase/` — [YouTube tour](https://youtu.be/FUw8zgbn_tU); large **AVI/MP4** are **gitignored** (record with `scripts/record_*.sh` or keep copies under `scratch/showcase-videos/`).
- **Map:** [docs/REPO_LAYOUT.md](docs/REPO_LAYOUT.md) · [samples/README.md](samples/README.md).

### Performance & benchmarks (published numbers)

Canonical table: **[BENCHMARK_PUBLISHED_RESULTS.md](BENCHMARK_PUBLISHED_RESULTS.md)** (Sept 14, 2026 gameplay refresh · Aug 25, 2026 compute/draw baseline).

| Suite | Headline |
|-------|----------|
| **Compute (Tier A)** | VG faster than GDScript on **12/12** microbenchmarks (**1.8×–139×**, checksums verified) |
| **Draw (Tier C)** | VG faster on **9/9** `_draw` workloads (**1.3×–6.7×** static; moving rects **~5.8×**) |
| **Gameplay realism (Tier B/C)** | **IntegerLoop ~65×** · **NodePropertyChurn ~170×** · **FloatLoop ~7×** · entity ticks / `For Each` scans **~3–8×** · local calls ≈ GDScript parity |

Reproduce: `scripts/run_compute_benchmarks.sh`, `run_draw_benchmarks.sh`, `run_gameplay_benchmarks.sh` · CI gate: `scripts/benchmark_regression_check.sh` (Tier A only).

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
- GDExtension release build — **fresh Linux + Windows** editor/template binaries (Sep 19; Windows cross-compile fixed — MinGW `pascal` macro rename).
- Asset Library zip — `VisualGasic_AssetLibrary_v5.5.0-beta2.zip` (~25 MB, Linux + Windows).

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
- [x] Git tag `v5.5.0-beta2` + GitHub Pre-release (**Latest**)

---

## Known notes

- **Test suite:** `test_for_each.vg`, `test_ipc.vg`, and `test_type_conversion.vg` may fail on some hosts (environment/platform); core game and Narcea regressions remain green.
- **GRAVEN slice** (from beta1) is still a developer preview — not showcase-ready.
- **Legacy Form Designer / VG IDE shell** remains experimental Alpha — not v6.0 critical path.
- **Hex editor** screenshots reflect in-progress app work; ship path is `samples/apps/vg_hex_editor/` when ready.
