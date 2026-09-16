# Brotato 3D — Visual Gasic

First **full 3D** VG game port. Builds on the completed 2D OG port in [`samples/games/brotato_vg`](../brotato_vg/) using **Plan A**: true 3D arena, `CharacterBody3D`, Kenney **Blocky Characters** (CC0).

## Goals

1. Ship a playable 3D survivor loop (movement → waves → shop → win).
2. Stress-test VG **3D** APIs (`Vector3`, `SetVelocity`, `MoveAndSlide`, `Animation.Play`, GLTF scenes).
3. File engine bugs / missing features found during the port — fix in `src/`, not workarounds.

## Run

```bash
scripts/prepare_ci_gdextension.sh   # once per clone / after rebuild
scripts/ci_smoke.sh samples/games/brotato3d
```

Open `samples/games/brotato3d` in Godot 4.6 with Visual Gasic enabled (legacy symlink: `projects/brotato3d`).

## Controls

See **[CONTROLS.txt](CONTROLS.txt)** for the full list. Summary:

| Keys | Action |
|------|--------|
| **WASD** / arrows | Move on the arena floor |
| *(auto)* | Fire at nearest enemy in range |
| **Q** / **E** | Camera yaw (free look) |
| **R** / **F** | Camera pitch (free look) |
| **C** | Toggle chase camera (follows movement) |
| **Esc** | Pause |

**Phase 0–4 (done):** full loop — title → fight → shop → 20 waves, HUD bars, game over/win.

**Phase 5 (next):** sfx pack, polish, performance profiling with many mobs.

## Assets

See [ASSETS.md](ASSETS.md) for Kenney Blocky Characters download and import steps.

## Status

See [PORT_STATUS.md](PORT_STATUS.md).
