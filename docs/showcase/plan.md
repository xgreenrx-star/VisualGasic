# Plan: Vector Showcase (3 projects)

## TL;DR
Three flagship pure-vector projects that play to VG's strengths (VectorCanvas, SoundGen, Tweak Overlay) and avoid the sprite-asset bottleneck that hurt BLUE SCREEN.

- **Phase A — Vector Storm** (twin-stick): ~2 weeks. Marketing quick-win, viral-tweet bait, web-deployable.
- **Phase B — Demoscene Intro + Screencast** (~1 week, after Phase A). 3-minute bundled demo that doubles as the launch trailer for Phase A.
- **Phase C — Vector Elite** (wireframe space sim): ~3 months, phased into 5 independently-playable sprints. Prestige showcase for v6.0.

Each phase is independently shippable. Phase A's TwinStick helper feeds Phase C. Phase B's SoundGen synth feeds both A and C.

## Inventory (verified before planning)
Confirmed available in canonical addon:
- VectorCanvas 2D verbs: `DrawLine`, `DrawRect`, `DrawRoundedRect`, `DrawEllipse`, `DrawArc`, `DrawPolygon`, `DrawPolyline`, `DrawPath`, `DrawCircle`, `DrawText`/Centered/RightAligned, `DrawVectorText`/Centered/Right
- VectorCanvas 3D verbs: `Draw3DLine`, `Draw3DPolyline`, `Draw3DCube`, `Draw3DVectorText`
- Transform stack: `PushTransform`/`PopTransform`, `Push3DTransform`/`Pop3DTransform`
- `SoundGen.Open / Available / PushMono / PushStereo / Close` — real-time PCM ready
- `Joypad_Axis(device, axis_enum)`, `Joypad_Button(device, button_enum)` — raw; no twin-stick wrapper yet
- Reference templates: `game_projects/asteroids/asteroids.vg` (365 lines), `game_projects/defender/defender.vg` (332 lines), `game_projects/vector_dashboard/vector_dashboard.vg` (115 lines)
- Web export: no preset yet; Tweak Overlay must be stripped per `docs/guides/TWEAK_OVERLAY.md`

Gaps to fill in Phase A (also useful elsewhere):
- TwinStick input helper (gamepad + WASD/arrows fallback)
- Reusable web export preset
- Reusable warping-grid background module
- Reusable particle-bloom module

---

## Phase A — VECTOR STORM (twin-stick shooter)
**Goal**: 60 fps in browser, single tweet of gameplay sells the engine.

### A1. Scaffold (½ day)
Create `game_projects/vector_storm/`:
- `project.godot` — name "Vector Storm", main scene `main.tscn`, headless audio disabled, mobile-friendly viewport
- `main.tscn` — root `Node2D` + `VectorCanvas` child + script `vector_storm.vg`
- `addons/visual_gasic/` symlink to canonical `../../../addons/visual_gasic`
- `vector_storm.vg` — empty `Sub _Ready` / `Sub _Process(delta)` skeleton
- `vector_storm_smoke.vg` in `test_proj/` — headless boot + 3-frame tick + score asserts

### A2. TwinStick input helper (½ day, *unblocks A4 and Phase C*)
`addons/visual_gasic/plugins/vector_helpers/twin_stick.vg` — reusable module:
- `TwinStick.Left() As Vector2` — gamepad LX/LY with deadzone 0.15, fallback to WASD
- `TwinStick.Right() As Vector2` — gamepad RX/RY, fallback to arrow keys
- `TwinStick.Fire() As Bool` — right trigger / left mouse / space
- `TwinStick.Boost() As Bool` — left trigger / shift
- One-line `TwinStick.Init()` in `_Ready` registers fallback InputMap actions if missing

### A3. Player ship (1 day) — *depends on A2*
- Triangle ship rendered via `DrawPolyline` (5 vertices, closed loop)
- Position + velocity vectors; friction 0.92/frame
- Thrust = `TwinStick.Left() * accel`, capped at max_speed
- Aim angle = `TwinStick.Right().angle()`; ship rotates to face that vector
- Drawn at world position with `PushTransform` rotation

### A4. Player firing (½ day) — *depends on A3*
- Bullets as 2-vertex lines, lifetime 0.8s
- Fire-rate cap 8/sec while `TwinStick.Fire()`
- Spawned at ship-tip in aim direction, velocity = 700 px/s + ship velocity
- Pool of 256 pre-allocated bullets (avoid `New` in hot loop)

### A5. Enemy types — 4 archetypes (2 days) — *parallel with A4*
Each as its own sub in `vector_storm.vg` (or split into `enemies.vg` if growing): `_DrawAndUpdate<Type>(e, delta)`:
1. **Drifter** (square): straight-line at low speed, dies in 1 hit, worth 10
2. **Homing Diamond**: steers toward player at half player-speed, dies in 1 hit, worth 25
3. **Pinwheel** (4-arm rotating cross): orbits nearest player position at radius 200, fires single bullet every 2s, dies in 2 hits, worth 50
4. **Snake** (5-segment chain of small circles): follows head; head accelerates toward player; only head is killable, kill releases segments as drifters, worth 100
- Spawned from screen edges on a rising difficulty curve (more/faster every 30s)

### A6. Collision + death (½ day) — *depends on A3-A5*
- Bullet→enemy: circle-circle distance check, broadphase = bucket by 128-px grid
- Enemy→player: same; player hit triggers Game Over + 2s respawn delay
- Kill triggers: particle bloom (A8) + grid ripple (A7) + audio pulse (A9) + score++

### A7. Warping grid background (1 day, *reusable module*)
`addons/visual_gasic/plugins/vector_helpers/warp_grid.vg`:
- 32×18 vertex grid covering viewport
- Each vertex has rest position + displacement vector + velocity
- On `WarpGrid.Ripple(world_pos, strength)`: push outward, decay over 0.8s with damped-spring
- Draw as 2-pass: horizontal polylines + vertical polylines, color faded toward edges

### A8. Particle blooms (½ day) — *parallel with A7*
`addons/visual_gasic/plugins/vector_helpers/particle_bloom.vg`:
- Pool of 1024 particles; each = position + velocity + lifetime + color
- On `Bloom.Spawn(pos, color, count)`: radial scatter, random speeds 100-400 px/s
- Draw as short 2-vertex lines (head + tail offset by velocity*0.04)
- Alpha = lifetime/max_lifetime

### A9. Audio-reactive bass pulse (1 day) — *depends on A6*
- `SoundGen.Open(22050, 0.1)` in `_Ready`
- `_Process`: keep buffer fed; mix three voices:
  1. Chip arpeggio loop (looping 8-note pattern, square wave)
  2. Bass drum (triggered on player fire — short sine envelope 80 Hz → 40 Hz over 0.05s)
  3. Kill burst (triggered on enemy kill — pink noise envelope 0.15s, pitch = score multiplier)
- On every kill, also: tint warp grid red for 0.15s + scale pulse 1.05×

### A10. Screen shake (¼ day)
Camera offset = random unit vector × decaying magnitude; shake added on player hit (0.6 mag, 0.3s decay) and big-kill (0.2 mag, 0.15s decay).

### A11. Score / multiplier / lives / Game Over (½ day)
- Score top-left via `DrawVectorTextRightAligned`
- Multiplier increases by 0.1 per kill within 1.5s of last kill; decays toward 1.0× otherwise
- 3 lives; player ghost visible during 2s respawn invuln (blinking)
- Game Over overlay: centered vector text + "Press SPACE / South Pad" to restart

### A12. Web export build + Tweak Overlay strip (1 day) — *depends on A1-A11*
- Create `bench/web_export_preset.cfg` (reusable for future projects)
- `scripts/strip_tweak_overlay.py` — removes `addons/visual_gasic/vg_tweak_overlay.gd` + `vg_debug_handler.gd` plugin loading line before web export
- `vg-make-web-export` shell wrapper — runs strip → export → spits HTML5 bundle to `build/web/vector_storm/`
- Smoke: `python -m http.server` + open in headless Chromium, screenshot frame 60, assert non-empty pixels

**Relevant files (Phase A)**
- `game_projects/vector_storm/project.godot`, `main.tscn`, `vector_storm.vg` — game
- `addons/visual_gasic/plugins/vector_helpers/twin_stick.vg`, `warp_grid.vg`, `particle_bloom.vg` — reusable modules
- `test_proj/vector_storm_smoke.vg` — headless verification
- `bench/web_export_preset.cfg` — reusable preset
- `scripts/strip_tweak_overlay.py`, `vg-make-web-export` — export pipeline
- Reference (read-only): `game_projects/asteroids/asteroids.vg`, `game_projects/defender/defender.vg`

**Verification (Phase A)**
1. `vector_storm_smoke.vg` runs headless, asserts: VectorCanvas instanced, TwinStick.Left() returns Vector2, ≥1 enemy spawned within 60 frames
2. Manual: editor Play, 60 fps stable at 1920×1080 with 50 enemies on screen
3. `vg-make-web-export` produces `build/web/vector_storm/index.html` < 20 MB
4. Web build runs in Firefox + Chromium; gameplay video 15s recordable via ffmpeg headless

---

## Phase B — DEMOSCENE INTRO (3-minute bundled screencast)
**Goal**: Single browser-runnable URL that demos VG aesthetically *and* shows the IDE workflow (Tweak Overlay live-edit) as the killer differentiator.

### B1. Scaffold (¼ day)
`game_projects/demoscene_intro/`:
- `project.godot`, `main.tscn`, `demo.vg`, `addons/visual_gasic/` symlink
- Scene-clock module: `_Process` ticks a `t` float; each effect picks itself based on `t` ranges

### B2. Effect: 3D star tunnel (½ day) — 0:00-0:30
- 800 stars at random `(x,y,z)` with z marching toward camera
- `Draw3DLine` from `(x,y,z)` to `(x*0.95,y*0.95,z+1)` so each star is a small streak
- Camera tilt sinusoidally over the 30s for parallax feel

### B3. Effect: rotating wireframe torus (½ day) — 0:30-1:00
- Generate torus as 16 × 24 ring vertices, connect adjacent rings with `Draw3DPolyline`
- Two rotation axes simultaneously; color pulses with audio bass envelope

### B4. Effect: plasma grid (½ day) — 1:00-1:30
- 64 × 36 grid of small `DrawRect` cells filled with HSV color `(sin(x*0.1+t)+sin(y*0.1+t)+sin((x+y)*0.05+t*1.3))`
- 30 seconds of color flow; resolution drop for low-end web

### B5. Effect: rotating greet scroll (½ day) — 1:30-2:15
- `Draw3DVectorText` rotating Y-axis with text "VISUALGASIC PRESENTS / WRITTEN IN BASIC / 100% PROCEDURAL / NO ASSETS HARMED"
- Big scrolltext at bottom listing greets/credits at 80 px/s

### B6. Effect: VG logo + final card (¼ day) — 2:15-2:45
- Logo drawn as a single `DrawPolyline` outline (designed as path)
- Subtitle "Try it: visualgasic.io" — vector text
- Closing fade

### B7. Chiptune soundtrack (1 day, *parallel with B2-B6*)
- 4-voice synth in `demo.vg` using `SoundGen.PushStereo`
- Voices: pulse-wave lead, triangle bass, square arpeggio, noise hi-hat
- 8-bar looping pattern in a 2D array; tempo 132 bpm
- Bass envelope exported so visual effects can pulse-react

### B8. Tweak Overlay live-edit opening segment (½ day) — *separate IDE recording*
- Open IDE side-by-side with the demo running
- 15s clip: Open Tweak Overlay → pick torus group → drag color slider → demo torus changes color in real-time → caption "live edit, no restart"
- Stitched as the first 15s of the final video

### B9. Recording + delivery (½ day)
- `scripts/record_screencast.sh`:
  - Linux: `ffmpeg -f x11grab -f pulse -ac 2 -i default -framerate 60 ...`
  - Headless: `xvfb-run` + framebuffer capture for CI reproducibility
- Output: `build/showcase/vg_intro.mp4` (H.264, 1080p60, ~150 MB)
- Web export: `build/web/demoscene_intro/index.html` (also playable live)
- Upload to YouTube + embed in README + post on HN/Reddit per existing community drafts

**Relevant files (Phase B)**
- `game_projects/demoscene_intro/project.godot`, `main.tscn`, `demo.vg`
- `scripts/record_screencast.sh`
- Reuses Phase A's `bench/web_export_preset.cfg` + `vg-make-web-export`

**Verification (Phase B)**
1. Demo loops back to t=0 cleanly without audio glitch
2. ffmpeg recording produces playable mp4 between 2:45-3:15
3. Web build runs in Firefox + Chromium at 60 fps (sub-100 ms scene transitions)
4. Tweak Overlay segment shows real-time color change with no perceptible lag

---

## Phase C — VECTOR ELITE (wireframe space sim, prestige)
**Goal**: cover-piece for v6.0 release. Pure 3D wireframe, no models, no textures, no sprites — modern ELITE.

Phased into 5 sprints, each independently playable.

### Sprint C1 — Flight + asteroid field (~2 weeks)
1. **C1a Cockpit HUD** — vector frame around viewport, radar disk bottom-center (dots for nearby objects), compass-tape top, energy/shield bars left/right
2. **C1b Camera + flight model** — 6-DoF: pitch (mouse Y / right-stick Y), yaw (mouse X / right-stick X), roll (Q/E / left/right shoulders), thrust (W/S / left trigger). Quaternion-based, no gimbal lock
3. **C1c Star skybox** — 2000 distant points rendered via small `Draw3DLine` segments, rotated with camera (parallax)
4. **C1d Asteroid field** — 200 asteroids as `Draw3DPolyline` icosahedrons with random vertex perturbation, spread over 50,000-unit cube
5. **C1e Asteroid LOD** — only render within 5000 units; broadphase grid for collision and visibility
6. **C1f Mining laser** — `Draw3DLine` from ship to targeted asteroid; 3 hits → asteroid splits into 3 smaller pieces; smallest tier yields cargo

### Sprint C2 — Coriolis station + docking (~2 weeks)
1. **C2a Station model** — Coriolis class: octahedron-like wireframe with rotating central torus, ~80 vertices
2. **C2b Rotation + docking bay** — station rotates 5°/sec on its main axis; docking bay is a wireframe rect on one face that must line up with player attitude
3. **C2c Docking sequence** — when within 200 units + aligned within 15° + speed < 50: cinematic auto-dock, fade to station interior
4. **C2d Station interior screens** — text + line UI: Commodities Market / Equipment / Mission Board / Launch
5. **C2e Launch** — eject ship, give player 5km clearance from station before AI engagement

### Sprint C3 — Trading economy + save (~2 weeks)
1. **C3a Commodity table** — 17 commodities (Food, Textiles, Radioactives, Slaves, Liquor, Luxuries, Narcotics, Computers, Machinery, Alloys, Firearms, Furs, Minerals, Gold, Platinum, Gem-Stones, Alien Items) — same as original
2. **C3b Per-station economy** — each station has tech-level + government type that biases prices; computed deterministically from system seed
3. **C3c Cargo hold** — 20 ton limit; buy/sell UI; mass-affects acceleration
4. **C3d Persistence** — `user://elite_save.json`: credits, cargo, current system, ship state. Auto-save on dock + manual save in station menu

### Sprint C4 — Combat + pirates (~3 weeks)
1. **C4a Pirate AI** — 4 states: hunt (close to range), strafe (orbit at 800 units while firing), retreat (low hull), regroup. Steering via target-relative velocity
2. **C4b Lasers** — `Draw3DLine` beams with 0.1s flicker; damage applied per frame while overlap with target volume
3. **C4c Missiles** — `Draw3DLine` trail + small wireframe cube head; lock-on requires 2s steady target retention
4. **C4d Shields + hull** — shields regen out of combat; hull damage permanent until refit; explosion = expanding wireframe sphere (60 vertices, 1.5s scale-up + fade)
5. **C4e Bounty system** — kills earn credits; rating progression (Harmless → Mostly Harmless → Poor → Average → ... → Elite, same as original)

### Sprint C5 — Galaxy + hyperjump (~2 weeks)
1. **C5a Procedural galaxy** — 256 systems × 8 galaxies, generated from a fibonacci-LFSR seed (same algorithm as 1984 ELITE so the system names match): Tibedied, Lave, Diso, Riedquat, Leesti, Zaonce, ...
2. **C5b Galactic map UI** — full-screen vector chart, scrollable, hover for system info, click to plot route
3. **C5c Hyperjump animation** — witch-space transition: 4s of tunnel effect (rainbow lines radiating, audio swell) → arrival at random in-system position
4. **C5d Witchspace encounters** — 10% chance of being pulled into an empty grey-fog system with 2-3 Thargoid wireframe diamonds attacking; survive to escape

**Relevant files (Phase C)**
- `game_projects/vector_elite/project.godot`, `main.tscn`, `elite.vg`
- Per-sprint additional .vg modules: `flight.vg`, `station.vg`, `economy.vg`, `combat.vg`, `galaxy.vg`
- Reuses Phase A: TwinStick helper, SoundGen wrappers
- Reuses Phase B: web export pipeline

**Verification (Phase C)**
Per sprint:
- C1: 60 fps cruising through 200-asteroid field; mining yields cargo
- C2: full docking cycle completes without manual intervention
- C3: save → quit → reopen restores credits/cargo/position exactly; trading round-trip is profitable
- C4: pirate kills player in ≤60s of engagement without shields (proves AI works)
- C5: full 256-system galaxy is navigable; system names match canonical ELITE seed output

---

## Cross-cutting deliverables
1. `bench/web_export_preset.cfg` — reusable export template (Phase A)
2. `addons/visual_gasic/plugins/vector_helpers/` — TwinStick, WarpGrid, ParticleBloom modules (Phase A)
3. `scripts/strip_tweak_overlay.py`, `vg-make-web-export` — export pipeline (Phase A)
4. `scripts/record_screencast.sh` — headless screencast recorder (Phase B)
5. `docs/showcase/` — screenshots, gif loops, video embeds, release notes blurbs
6. v6.0 release notes section: "Vector Showcase" highlighting all three projects

## Decisions
- **Pure vector, zero external assets** across all three. Audio is SoundGen-synth.
- **TwinStick helper lives in `addons/visual_gasic/plugins/vector_helpers/`** so it propagates via the symlink network — no duplication.
- **Web export is a first-class deliverable in Phase A** so Phase B and C inherit a tested pipeline.
- **Phase B screencast incorporates the Tweak Overlay live-edit segment** rather than a separate Narcea-builds-it demo — fewer moving pieces, sharper message ("look at the workflow").
- **Phase C is sprint-phased and each sprint is releasable** as a tech-preview so we get feedback well before the v6.0 cover-piece is "done".

## Out of scope
- Multiplayer / networking (any phase)
- Mobile touch controls (web/desktop first; mobile can come later via existing Sensor/Joypad layer)
- Narcea-builds-the-game live demo (deferred; Tweak Overlay segment in Phase B serves the same marketing role)
- Photorealistic / textured 3D (the whole point is pure vector)
- Custom font work (DrawVectorText is sufficient)

## Further considerations (decide before starting)
1. **Phase A genre lock**: pure twin-stick *Geometry Wars*-style, or hybrid like *Resogun* (constrained cylinder play-field)? Recommend: classic flat plane, faster to ship and easier to web-export. Open to override.
2. **Phase B intended length**: target 2:45-3:15, but is there an upper bound for the HN/Reddit attention span? Recommend: 2:30 hard cap; cut B4 scroll greets to 30s if needed.
3. **Phase C distribution model**: ship in-development sprints as separate downloads under `game_projects/vector_elite/`, or hide behind a feature flag until C5 done? Recommend: ship sprints publicly tagged "Tech Preview" — momentum + feedback worth more than polish.
