# VisualGasic 5.5.0-beta1 Release Notes

**Release Date:** September 2026  
**Status:** Beta (Pre-release)  
**Milestone:** M6–M7 — GRAVEN v6 slice preview, Include/Restore fixes, IDE vector DATA editor  
**Previous Release:** [5.4.0-beta2](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.4.0-beta2)  
**Target Engine:** Godot 4.6.1  
**Platforms:** Linux x86_64, Windows x86_64

---

## Overview

VisualGasic 5.5.0-beta1 ships the first playable **GRAVEN (VG6 slice)** scaffold — a Thrust-style gravity explorer with pulse rings, tow mechanics, and 17 interconnected rooms — alongside engine fixes that unblock multi-module games and Restore-driven level data.

This is an **early preview**, not a showcase release: room layout is still grid-based (legacy from the pixel prototype) and core gameplay loops are WIP. The slice exists to stress-test vector canvas, Restore tables, Shader post-FX, and Narcea-assisted multi-file VG projects on the road to v6.0.

---

## What shipped

### GRAVEN v6 slice (developer preview)

- **`projects/vg_graven_slice/`** — modular `.vg` project: `GravenMain`, `GravenRooms`, `GravenPulse`, `GravenTow`, `GravenVector`, and dev terminal (`GravenDev`, **F1** in-game).
- **17 rooms** with pulse, tow, mass wells, sockets, and hub navigation — graph topology, not a linear hallway.
- **Restore tables** for per-room spawn, mass, caption, and hint metadata (`LoadRoomMasses()` pattern documented for Narcea).
- **Vector canvas + Shader post-FX** — plasma backgrounds, warp distortion, palette cycling on the fast draw path.

### Engine & runtime fixes

- **`Restore "R" + CStr(n) + "Mass"`** — AST interpreter now evaluates `label_expr` (bytecode VM already did); fixes missing gravity wells when mass data loaded via helper `Sub`.
- **`Shader.Param` / builtin namespace dispatch** — AST fallback paths resolve `Shader` as a builtin namespace; moving the pod no longer crashes with “Method call base is not an Object”.
- **Relative `Include` resolution** — multi-file modules resolve includes relative to the including file, not the project root.
- **Owner-relative Godot builtins** — `position`, `GlobalPosition`, and related members resolve against the control/node owner in cross-module helpers.
- **Include error mapping** — parse/compile errors in included modules report the source `.vg` file and line.

### IDE improvements

- **Context Rail vector DATA editor** — inline editing of `Data`/`Restore` blocks and `.vgv` sidecar panels from the editor rail.
- **Reference audit gate** — command help and builtin catalog stay in sync with the compiler surface.

### Tracks B/C (carried forward)

- **Python bridge C2** — typed msgpack wire protocol (`vg_msgpack.cpp`, `test_py_msgpack_typed.vg`).
- **Causal-graph API** — `VisualGasicLanguage.vg_analyze_causal_graph()` exposed to GDScript; `vg_causal_chain.gd` prefers C++ when available.

---

## Validation

- `./run_test_suite.sh --vg-only` — green including `test_graven_mass_restore.vg`
- GDExtension smoke load — green after materializing addon `bin/`
- Graven slice — headless parse + manual play-test of pulse, tow, mass restore, and room warp

---

## Try GRAVEN

```text
Open projects/vg_graven_slice/project.godot → F5
F1 — dev terminal (warp rooms 1–17)
```

See also: [GRAVEN v6 proposal](docs/proposals/GRAVEN_V6_FLAGSHIP.md) (design doc; gameplay will be reworked for a future release).

---

## Release checklist

- [x] Bump `VERSION` to `5.5.0-beta1`
- [x] Move changelog items into `[5.5.0-beta1]`
- [x] Add release notes + GitHub release body with screenshots
- [x] Build Linux/Windows GDExtension + installers
- [ ] Git tag `v5.5.0-beta1` + GitHub Pre-release (Latest)

---

## Known notes

- **GRAVEN is not showcase-ready** — grid-based room maps remain; vector-only layout and gameplay polish are planned for a later v6 cut.
- Python bridge outgoing-arg typing still partial on some return paths (see changelog).
- Causal chain **visual panel** deferred to v6.1; text-mode analysis available in Code Navigator.
