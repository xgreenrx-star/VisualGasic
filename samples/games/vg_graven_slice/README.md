# GRAVEN — Visual Gasic 6 flagship slice

Mass-gravity cave explorer (8-room vertical slice). Full design spec: [`BLUEPRINT.md`](BLUEPRINT.md).

## Quick start

1. Open **`project.godot`** in this folder (`vg_graven_slice/`) in Godot **4.6.1+** with the VisualGasic addon enabled.
2. Press **F5** (or Project → Run Project). Main scene: `res://ai_projects/graven_slice/main.tscn`.
3. Play Room 1 → Room 8; end card shows **Made in VG6** — press **R** to replay.

## Controls

| Action | Keys |
|--------|------|
| Thrust | W / Up |
| Rotate 90° | Q (CCW) / E (CW) |
| Pulse sonar | Space (Room 5 dark pool) |
| Interact | F (Room 4 terminal; replay on end card) |
| Mass debug | Hold G |

## Manual test path (R1→R8)

1. **R1** — thrust east to exit.
2. **R2** — curve into ceiling channel (M1 pull should feel crisp, not mushy).
3. **R3** — ceiling shelf to east exit.
4. **R4** — push crate onto floor plate; south pit opens; beacon saves here.
5. **R5** — Space Pulse reveals spikes; cross to east (screenshot-friendly contrast).
6. **R6** — orbit central mass 540° in 80–200 px band; east gate opens.
7. **R7** — manage heat bar (hot zone cols 10–30 drains ×1.8).
8. **R8** — touch skiff at ~(1100, 400) for win + fade end card.

## CI smoke (optional)

From the repo root, headless parse check on this standalone project:

```bash
scripts/ci_smoke.sh projects/vg_graven_slice
```

## Project layout

```
vg_graven_slice/
├── project.godot          ← open this project (not repo root)
├── BLUEPRINT.md           ← room maps, constants, shader spec
├── ai_projects/graven_slice/
│   ├── main.tscn
│   ├── GravenMain.vg      ← _Ready / _Process / _Draw
│   ├── GravenRooms.vg     ← tile maps R1–R8
│   ├── GravenObjects.vg   ← puzzles, heat, skiff, end card
│   ├── GravenPulse.vg     ← sonar + post shader uniforms
│   └── shaders/graven_post.gdshader
└── addons/visual_gasic/   ← symlink to repo addon
```

## Art credits (optional Kenney CC0)

When skinning beyond greybox tiles, Kenney assets referenced in code comments:

- [1-Bit Pack](https://kenney.nl/assets/1-bit-pack) or Abstract Platformer / Pattern Pack — cave `#` tiles
- [Space Shooter Redux](https://kenney.nl/assets/space-shooter-redux) — pod sprite (`playerShip1_blue.png`)

Kenney assets are **CC0** — no attribution required; credit appreciated.

## Related docs

| File | Purpose |
|------|---------|
| [`BLUEPRINT.md`](BLUEPRINT.md) | Room maps, physics constants, scene tree |
| [`PROPOSAL.md`](PROPOSAL.md) | Collaborator handoff |
| [`NARCEA_PROMPTS.md`](NARCEA_PROMPTS.md) | Narcea build prompts |

## Addon symlink

If the plugin is missing:

```bash
ln -sf ../../../addons/visual_gasic addons/visual_gasic
```

GDExtension binaries must be built in the main VisualGasic repo.
