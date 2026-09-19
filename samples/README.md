# Visual Gasic Samples

Godot projects you can open and run to learn VG or play finished work.

## Layout

| Folder | What lives here |
|--------|-----------------|
| [`games/`](games/) | Playable games (combat, arcade, adventure) |
| [`apps/`](apps/) | Tools and utilities (file manager, dashboards) |
| [`showcases/`](showcases/) | Marketing tours, movie demos, intro reels |
| [`demos/`](demos/) | Small feature demos by topic (language, UI, audio, …) |
| [`internal/`](internal/) | CI / Narcea / plugin QA — not end-user samples |

**Engine developer harness:** [`../engine_lab/`](../engine_lab/) — benchmarks, fuzz tests, form lab (not user samples).

**Canonical addon:** [`../addons/visual_gasic/`](../addons/visual_gasic/). Sample projects should symlink to it:

```bash
scripts/sync_addons.sh convert   # once after clone
scripts/sync_addons.sh check     # CI drift guard
```

## Quick start

```bash
# Open any sample in Godot 4.6.1+ with Visual Gasic enabled, then F5.
scripts/ci_smoke.sh samples/games/brotato3d
scripts/ci_smoke.sh samples/apps/vg_twinpane
scripts/ci_smoke.sh samples/apps/vg_hex_editor
```

## Games

| Project | Description |
|---------|-------------|
| [brotato_vg](games/brotato_vg/) | 2D Brotato-style survivor (OG port, frozen v1.0) |
| [brotato3d](games/brotato3d/) | 3D continuation (Kenney characters) |
| [asteroids](games/asteroids/) | Classic asteroids |
| [defender](games/defender/) | Side-scrolling shooter |
| [platformer_2d](games/platformer_2d/) | Jump-and-run platformer |
| [pong_ultimate](games/pong_ultimate/) | Pong variant |
| [racing_3d](games/racing_3d/) | Simple 3D racing |
| [vector_storm](games/vector_storm/) | Vector graphics shooter |
| [zork](games/zork/) | Text adventure |
| [vg_graven_slice](games/vg_graven_slice/) | GRAVEN action preview |

## Apps

| Project | Description |
|---------|-------------|
| [vg_twinpane](apps/vg_twinpane/) | Dual-pane file manager (Form Designer sample) |
| [vg_hex_editor](apps/vg_hex_editor/) | Binary hex editor (Form + custom `_Draw` canvas) |
| [vector_dashboard](apps/vector_dashboard/) | Vector dashboard UI |
| [VG_UI_TOOLS](demos/UI/VG_UI_TOOLS/) | VB6-style control gallery |

## Showcases

| Project | Description |
|---------|-------------|
| [vg_beta_showcase](showcases/vg_beta_showcase/) | Beta feature tour (~6 min) — [YouTube](https://youtu.be/FUw8zgbn_tU); run F5 in-editor or `scripts/record_beta_showcase.sh` for local AVI |
| [demoscene_intro](showcases/demoscene_intro/) | Demoscene-style intro |
| [vg_narcea_movie_demo](showcases/vg_narcea_movie_demo/) | Narcea-generated movie reel — record with `scripts/record_narcea_movie_demo.sh` |

Large **`.avi` / `.mp4`** showcase outputs are **gitignored**; clone the repo and record locally, or use the linked YouTube tours.

## Feature demos

See [`demos/README.md`](demos/README.md) for the full catalog (Pong, Calculator, Language samples, etc.).

## Legacy paths

`projects/<name>` and top-level `demos/` are **compatibility symlinks** to this tree. Prefer `samples/…` in new docs and scripts.
