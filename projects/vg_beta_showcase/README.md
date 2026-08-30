# VG Beta Showcase (5.4.0-beta1)

~6-minute full tour (~3 min with Space skips): **Title** → **Backrooms transitions** → **Shader Showcase** → **About VG** → **Squash tease** → **Neon Runner** → **Vector Storm attract**.

**Watch:** [Beta Showcase on YouTube](https://youtu.be/FUw8zgbn_tU)

## Quick start

1. Open `project.godot` in Godot 4.6.1 with Visual Gasic enabled.
2. Press **F5** (main scene: `tour_main.tscn`).
3. **Space** skips to next segment; **ESC** quits.

See **[ARCHITECTURE.md](ARCHITECTURE.md)** for code layout, portal embed contract, and phase machine.

## Flow

| Scene | File | Duration |
|-------|------|----------|
| Speed Bench Tour | `tour.vg` | 5s title splash → Backrooms wrapper |
| Backrooms transitions | `backrooms_transition_manager.gd` | Walk hall → door/window portal → zoom in/out between demos |
| Shader Showcase | `shader_showcase_manager.gd` | 44.5s portal total — Synth Grid (14s) → Liquid Chrome (16s) → Fault Cube (14.5s) |
| About VG | `about_vg_manager.gd` | ~42s in portal — border scroller + Pac-Man |
| Squash the Creeps | `squash_tease/` + `squash_tease.vg` | 20s — Godot tutorial game in `.vg` |
| Neon Runner | `dash.vg` + `shaders/dash_*.gdshader` | 30s |
| Vector Storm | `storm.vg` | 60s attract, then playable |

**End screen:** **P** — play Vector Storm · **R** / **Enter** — replay tour · **ESC** — quit

Hallways include feature screenshots, graffiti, fluorescent hum, portal glow, and camera pauses on wall frames (shorter on repeat walks).

## Hooks

- **Shader Showcase:** 3-scene cycle — synth grid, chrome metaball raymarch, deconstructing fault cube; procedural sky + synth audio + Lorenz (grid only)
- **Squash tease:** official [Godot First 3D Game](https://docs.godotengine.org/en/stable/getting_started/first_3d_game/index.html) with autopilot
- **Benchmarks:** 12/12 compute, 9/9 draw vs GDScript ([results](../../BENCHMARK_PUBLISHED_RESULTS.md))

## Shaders

- `shaders/procedural_sky_day.gdshader` / `_space.gdshader` / `_fault.gdshader` — procedural skies (no HDR)
- `shaders/synth_grid.gdshader` — retro-wave displaced grid mesh
- `shaders/chrome_metaball.gdshader` — liquid mercury metaball raymarch
- `shaders/fault_cube.gdshader` — unwelded facet vertex explosion
- `shaders/dash_bg.gdshader` — neon grid (Neon Runner)
- `shaders/dash_post.gdshader` — chromatic aberration overlay
- `shaders/backrooms_wall.gdshader` — procedural fallback wallpaper
- `shaders/backrooms_carpet.gdshader` — procedural fallback carpet
- `assets/backrooms/` — CC0 wall + carpet textures ([amini-allight/backrooms-textures](https://github.com/amini-allight/backrooms-textures))

## Direct test

Open and run `shader_showcase_main.tscn` to preview the 42s segment without the tour.

### Optional: Showcase Carrier

Sky Fox-style primitive carrier frame (`showcase_carrier_main.tscn`, ~32s). **Not** part of the main **F5** flow — open that scene directly if you want the alternate city-flyby intro. **Space** skips beats inside the carrier only.
