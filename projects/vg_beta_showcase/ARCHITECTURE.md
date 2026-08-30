# VG Beta Showcase — Architecture

Visual Gasic **5.4.0-beta1** release demo. Godot **4.6.1** + Visual Gasic GDExtension. Main scene: `tour_main.tscn`.

## End-to-end flow

```
tour_main.tscn (tour.vg, 5s title)
    └─> backrooms_showcase_main.tscn (backrooms_transition_manager.gd)
            ├─ walk hub hall → portal (door or window)
            ├─ zoom into SubViewport demo
            ├─ PLAY segment (timed or wait-for-input)
            ├─ zoom out, walk back to hub, turn to next hall
            └─ repeat for DEMOS[] → FINISHED end screen
                    ├─ P → storm_main.tscn (playable Vector Storm)
                    ├─ R/Enter → replay tour
                    └─ ESC → quit
```

**Full passive watch:** ~6 minutes (includes backrooms walks and wall-frame pauses).  
**With Space skips:** ~3 minutes (skip hall walks between segments).

## File roles

| File | Role |
|------|------|
| `tour.vg` | Title splash; vector text on `VGVectorCanvas2D`; hands off to backrooms |
| `backrooms_transition_manager.gd` | 3D hub, halls, portal zoom, demo playlist, HUD, input, end screen |
| `backrooms_screen.gd` | Loads/unloads demo scenes into portal `SubViewport` |
| `backrooms_hall_audio.gd` | Procedural fluorescent hum + portal bleed (no audio files) |
| `shader_showcase_manager.gd` | Three-scene shader cycle; `set_portal_segment(0..2)` for backrooms splits |
| `about_vg_manager.gd` | Border scroller + Pac-Man belt; `wait_input` in backrooms |
| `squash_tease.vg` | 20s autopilot of Godot Squash tutorial in `.vg` |
| `dash.vg` | 30s Neon Runner auto-run with shader background |
| `storm.vg` | Twin-stick shooter; attract in portal, playable when launched from end screen |

## Portal embedding contract

When `backrooms_screen.gd` loads a demo it sets meta `vg_portal_embedded = true` on the scene root.

**GDScript managers** (`shader_showcase_manager.gd`, `about_vg_manager.gd`):

- `set_showcase_frozen(bool)` — pause sim while visible in portal frame
- `reset_for_portal()` — rewind to segment start (shader) or belt start (about)
- `begin_portal_play()` / `freeze_showcase_frame()` / `resume_portal_preview()` — zoom lifecycle

**VG scripts** check `GetViewport().GetClass() = "SubViewport"` (`carrier_embedded`) to avoid calling `ChangeScene` when embedded.

**Storm** (`storm.vg`):

- `set_showcase_frozen` — hold first attract frame until zoom-in
- `reset_for_portal` — fresh attract state when portal loads / when zoom-in starts
- `showcase_play_storm` root meta — skip attract when launched from end screen **P**

## Backrooms phase machine

```
WALK (to portal) → OPEN → ZOOM_IN → PLAY → ZOOM_OUT → CLOSE
    → WALK (to center) → demo_index++ → TURN_AT_HUB → next demo
```

- `_stage_demo_behind_portal()` loads demo into SubViewport during final hall approach
- `_set_phase(Phase.ZOOM_IN)` calls `_reset_storm_for_zoom_in()` for Vector Storm
- About VG uses `wait_input: true` in `DEMOS[]`; Space/click advances via `_advance_play_on_input()`

## Hall gallery (wall screenshots)

- 12 PNGs in `assets/wall_frames/`, 8 mount slots (2 per hall × 4 halls)
- `_advance_hall_gallery(hall)` runs only when walking that hall — pairs rotate globally
- Each frame gets its own material (no shared cache — runtime `ImageTexture`s)

## Headless / automated capture

Several scenes check `DisplayServer.get_name() == "headless"`:

- Auto-advance or `get_tree().quit()` for CI smoke (`scripts/ci_smoke.sh`)
- Skips audio/HUD where noted

### Movie Maker (recommended for release video)

Same method as `projects/demoscene_intro/` — Godot **Movie Maker** (`--write-movie`):

```bash
scripts/record_vg_beta_showcase.sh
```

Project settings: `movie_writer/movie_file="res://vg_beta_showcase.avi"`, 1280×720 @ 60fps.
`movie_mode` (`OS.has_feature("movie")`) auto-plays the full tour, hides HUD/skip hints,
advances wait-for-input segments on timer, holds the end card 10s, then quits.

Optional manual run:

```bash
./Godot_v4.6.1-stable_linux.x86_64 --path projects/vg_beta_showcase \
  --write-movie res://vg_beta_showcase.avi --resolution 1280x720 --fixed-fps 60
```

### OBS (manual polish / highlight reel)

For edited cuts with Space-skip, see `scratch/RECORD_VG_BETA_SHOWCASE_WITH_OBS.md`.

## Optional / not in F5 flow

| Path | Notes |
|------|-------|
| `showcase_carrier_main.tscn` | Alternate Sky Fox carrier intro (~32s beats) |
| `demoscene_burst_*` | Retired burst intro; reference only |
| `thrust_*` | Standalone game; wall frame screenshot only |

## Shaders & assets

Runtime skies: `procedural_sky_day.gdshader`, `_space`, `_fault`.  
Backrooms textures: CC0 pack in `assets/backrooms/` (see `concrete-wall-ATTRIBUTION.txt`).
