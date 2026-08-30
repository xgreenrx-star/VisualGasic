# VG Beta Showcase — Narcea Handoff

> **Internal dev notes — superseded by `README.md` and `ARCHITECTURE.md` for release.**  
> Kept for historical context (pre-backrooms chain, Narcea task checklist). Do not treat durations or scene flow here as current.

**Project:** `projects/vg_beta_showcase/`  
**Release:** Visual Gasic **5.4.0-beta1** (Aug 30, 2026)  
**Goal:** ~3-minute release video demo — **5s Title** → **42s Shader Showcase** → **20s Squash tease** → **30s Neon Runner** → **60s Vector Storm attract**  
**No custom art.** Shapes, lines, `VGVectorCanvas2D`, fused grid draw paths only.

---

## What already exists (do not rewrite from scratch)

| File | Status |
|------|--------|
| `shader_showcase_manager.gd` | **42s** — Synth Grid (14s + solar dive) → Liquid Chrome (14s) → Fault Cube (14s) |
| `demoscene_burst.vg` | *(retired from chain)* reference only |
| `squash_tease.vg` + `squash_tease/` | **20s** — Godot Squash the Creeps autopilot |
| `dash.vg` | Neon Runner GD-style auto demo |
| `tour.vg` | **Bootable** — plasma, tunnel, rect storm, HUD, scene change |
| `storm.vg` | **Full copy** of `projects/vector_storm/vector_storm.vg` (~1700 lines) |
| `tour_main.tscn` / `storm_main.tscn` | Scenes wired |
| `project.godot` | 1280×720, entry = tour |

**Reference sources (copy subs, do not link across projects):**

- `projects/demoscene_intro/demo.vg` — `_DrawPlasma`, `_DrawTunnel`, `_HsvToRgb`, `_DrawVectorText*`
- `BENCHMARK_PUBLISHED_RESULTS.md` — marketing numbers for HUD text
- `projects/vector_storm/vector_storm.vg` — gameplay already in `storm.vg`

---

## User flow

```
Launch project
    → tour_main.tscn (5s title) → shader_showcase_main.tscn (42s)
    → squash_tease_main.tscn (20s) — Squash the Creeps autopilot
    → dash_main.tscn (30s)
    → storm_main.tscn (60s attract, then playable)
    Space skips to next segment; ESC quits
```

---

## 3-day task breakdown

### Day 1 — Tour polish (`tour.vg`)

- [ ] Replace `_DrawTunnel` stub with full `_DrawTunnel` from `demoscene_intro/demo.vg` (lines ~1438–1517) or tuned 24-ring version.
- [ ] Optional: paste `_DrawVectorText` / `_DrawGlyph` if title card needs demoscene font quality.
- [ ] Tune `_DrawRectStorm`: target **120–200** rects; verify smooth motion at 60 FPS.
- [ ] Cross-fade between segments (0.5s overlap) — copy `T_OVERLAP` pattern from demoscene `_Process`.
- [ ] Headless: `DisplayServer.get_name() = "headless"` already quits at 30s (CI smoke).

**Acceptance:** Tour runs 30s, no crash, FPS HUD updates, Space skips, auto `ChangeScene("res://storm_main.tscn")`.

### Day 2 — Storm attract mode (`storm.vg`)

Add globals near top:

```vb
Dim showcase_attract As Boolean
Dim attract_timer As Single
Const AttractDuration As Single = 60.0
```

In `_Ready()` after existing init:

```vb
showcase_attract = True
attract_timer = AttractDuration
```

In `_Process()` **before** player input:

```vb
If showcase_attract Then
    attract_timer = attract_timer - delta
    ' Auto-move: gentle orbit toward nearest enemy OR TwinStickLeft from simple AI
    Call _AttractAutoPilot(delta)
    If cached_move.x <> 0 Or cached_move.y <> 0 Or cached_fire Or cached_joy_connected Then
        showcase_attract = False   ' player took over
    End If
    If attract_timer <= 0.0 Then
        attract_timer = AttractDuration   ' loop attract
        Call _ResetForAttract()           ' reset score/lives/enemies lightly
    End If
End If
```

Implement `_AttractAutoPilot`:

- Set `cached_move` toward screen center drift + sine wobble.
- Set `cached_aim` toward nearest live enemy (reuse enemy_pos loop).
- Set `cached_fire = True` when aim length > 0.2.

Tune spawn for **spectacle**:

- `SpawnIntervalStart = 0.8`, `SpawnIntervalMin = 0.25`
- `EnemyMaxAlive = 32` during attract (was 24)

HUD (`_DrawHud`): add centered tagline when `showcase_attract`:

```vb
"5.4.0-beta1 · 12/12 compute · 9/9 draw · Press WASD to play"
```

**Acceptance:** Storm runs 60s+ without input; taking WASD/fire exits attract; density feels “Geometry Dash energy” not empty space.

### Day 3 — Capture + docs

- [ ] Record **90s** 1080p60 (OBS): full tour → 60s storm.
- [ ] Add `projects/vg_beta_showcase/README.md` screenshot path note.
- [ ] Optional: `test_proj/test_suite/test_beta_showcase_tour.vg` — headless 35 frames, `PASS: tour_boot`.

---

## VG rules (must follow)

- **No `New` in `_Process` hot loops** — use pools (storm already does).
- **Properties:** `Caption`, `Left`, `Top`, `Width`, `Height` — not raw Godot names on controls.
- **Canvas:** `CreateNode("VGVectorCanvas2D")`, then `DrawRect` / `DrawPolyline` / `DrawPlasmaCells` / `ExecuteQueuedCommands` if using `_Draw` hook (tour uses direct canvas API like demoscene).
- **Do not work around engine bugs** — if something fails, report exact error line.
- **Entry:** `Sub _Ready()` not `Form_Load` for Node2D scripts.

---

## Narcea prompt (paste into AI Pair)

```
Build the VG 5.4.0-beta1 release showcase in projects/vg_beta_showcase/.

Read NARCEA_HANDOFF.md in that folder first.

Part 1 tour.vg: Replace tunnel stub with demoscene _DrawTunnel from projects/demoscene_intro/demo.vg. Polish rect storm and HUD.

Part 2 storm.vg: Add 60-second attract mode (_AttractAutoPilot, showcase_attract flag, higher spawn rate). Keep twin-stick when user moves.

No bitmap sprites. VGVectorCanvas2D only. Match VB6 style in existing files.

When done, list what you changed and how to run: open project in Godot, F5 from tour_main.
```

---

## If Narcea falters (Cursor continuation checklist)

1. Run project: Godot 4.6.1 → Import `projects/vg_beta_showcase` → F5.
2. Fix parse errors first (`ReadLints` / Godot output panel).
3. Paste real `_DrawTunnel` from demoscene if tour looks weak.
4. Wire attract mode in `storm.vg` per Day 2 spec above.
5. `./run_test_suite.sh` if smoke test added.

---

## Run locally

```bash
# Godot 4.6.1, open projects/vg_beta_showcase/project.godot, press F5

# First-time / CI: bootstrap .godot extension cache (required before game headless)
./Godot_v4.6.1-stable_linux.x86_64 --headless --quit --editor --path projects/vg_beta_showcase

# Headless tour smoke (should exit 0 after ~30s)
./Godot_v4.6.1-stable_linux.x86_64 --headless --path projects/vg_beta_showcase
```

---

## Release packaging

- Link from `RELEASE_NOTES_v5.4.0-beta1.md`: “Try the showcase: `projects/vg_beta_showcase/`”
- GitHub release video: 90s capture + benchmark table slide from `BENCHMARK_PUBLISHED_RESULTS.md`
