# GRAVEN — Narcea prompt sequence

Copy-paste these into **AI Pair → Narcea** in order.  
**Project folder:** `projects/vg_graven_slice/`  
**Design source of truth:** [`BLUEPRINT.md`](BLUEPRINT.md)

---

## Before you start

1. Open Godot with Visual Gasic enabled: **`projects/vg_graven_slice/project.godot`** (standalone project; symlinked addon).
2. Press **F5** once to confirm Room 1 runs before Narcea edits.
3. Narcea: **Agent mode** (or equivalent that writes files), approvals as you prefer.
4. Paste **Prompt 0** once per session (sets context).
5. Run prompts **1 → 8** in order. Prompt 1 is mostly done — start at **Prompt 2** for Room Bend.
6. After each step: press **F5**, play, then paste the next prompt with any fixes noted.

**Art (Kenney):** Do **not** use Micro Roguelike (too cute/chunky for GRAVEN). Prefer packs below. Tiles are **optional skin** — grey blockout is fine until Room 5. Shader + dark palette sell the mood more than tile detail.

**Later vector path:** When switching off Kenney, paste **Prompt V** at the end of a session.

---

## Kenney packs that fit GRAVEN (pick 1–2 tile + 1 ship)

Use **📦 Kenney** in the IDE or download manually. CC0.

| Pack | Use | Why |
|------|-----|-----|
| [**1-Bit Pack**](https://kenney.nl/assets/1-bit-pack) | Cave tiles recolored | Monochrome; modulate to `#1a2530` / `#2a3a4a` — reads dark, not cartoon |
| [**Abstract Platformer**](https://kenney.nl/assets/abstract-platformer) | Walls / backgrounds | Geometric, not character-heavy |
| [**Pattern Pack**](https://kenney.nl/assets/pattern-pack) | Seamless rock fill | Tile Godot TileMap; darken in import |
| [**Space Shooter Redux**](https://kenney.nl/assets/space-shooter-redux) | Pod + skiff sprite | Sci-fi silhouette; rotate for 90° thrust |
| [**Pixel Shmup**](https://kenney.nl/assets/pixel-shmup) | Alt pod / effects | Smaller ships if Redux feels too chunky |
| [**UI Pack: Space Expansion**](https://kenney.nl/assets/ui-pack-space-expansion) | HUD panels (optional) | Heat bar frame |
| [**Sci-Fi Sounds**](https://kenney.nl/assets/sci-fi-sounds) | Pulse, thrust | SFX |
| [**Digital Audio**](https://kenney.nl/assets/digital-audio) | Ambient bleeps | Cave ambience |

**Godot import tip:** set TileMap layer **Modulate** to `(0.1, 0.15, 0.2, 1)` or similar until shader lands. Kenney bright colors are not final art.

**Week 1:** grey `STONE` rectangles in TileMap are OK. Do not block on art.

---

## Prompt 0 — Session bootstrap (paste once)

```
GRAVEN vertical slice — flagship VG6 demo game.

Read the design in the repo:
- projects/vg_graven_slice/BLUEPRINT.md (room maps, mass coords, constants)
- projects/vg_graven_slice/PROPOSAL.md (player fantasy)

RULES FOR ALL GRAVEN WORK:
- Game is a Node2D scene + .vg scripts — NOT a Window form. Forms cannot _Draw.
- NO CharacterBody2D for the player. Manual velocity + circle-vs-tile collision in .vg.
- Gravity pulls toward per-room MASS NODES (inverse-square), NOT global Down.
- Room size: 1280×704 px (40×22 tiles @ 32px). Fixed camera per room, no scroll.
- Controls: W/Up thrust, Q/E rotate 90°, Space Pulse (later), F interact (later).
- Use Const for tuning at top of modules (THRUST=420, G_SCALE=120000, POD_R=12, VMAX=280).
- QueueRedraw only when visuals change (pos, pulse phase, heat, room load).
- Do NOT use Screen.Width at _Ready — use Const GAME_W=1280, GAME_H=704.
- Sqr() in VG is square ROOT — use dx*dx+dy*dy for distance squared.
- Never name the game Exile; title is GRAVEN. End card: "Made in VG6".
- Prefer readable Sub/Function names: GravityAccel, MovePod, CollideTiles, LoadRoom.

Project path: projects/vg_graven_slice/
If the project does not exist yet, scaffold it there with main.tscn + GravenMain.vg.

Confirm you understand, then wait for Prompt 1.
```

---

## Prompt 1 — Project scaffold + Room 1 (Airlock)

**Status:** scaffold exists (`project.godot`, `main.tscn`, `GravenMain.vg` Room 1). Extend/refactor — do not recreate from scratch unless broken.

```
GRAVEN Prompt 1 — verify scaffold + refine Room 1 (Airlock)

Create or extend projects/vg_graven_slice/:

FILES:
- project.godot (input map: thrust, rotate_ccw, rotate_cw, pulse, interact, ui_cancel)
- main.tscn → Node2D root "GravenMain" with child TileMapLayer "Solid" (32px cells)
- GravenMain.vg attached to root
- rooms/R01_airlock.tscn OR embed R01 tile data loadable by room id

ROOM 1 from BLUEPRINT.md:
- 40×22 tile layout (ASCII map in blueprint)
- Spawn pixel ~(272, 560), exit east
- One mass node (640, 780) strength 1.0 — below floor
- No hazards

PHYSICS (implement now):
- Dim podX, podY, podVX, podVY, podAngle As Single
- Thrust along podAngle when thrust held; rotate ±90° on Q/E tap (edge-trigger)
- Function GravityAccel(px, py) → ax, ay from mass table for current room
- Integrate velocity; clamp VMAX; apply DRAG 0.92
- Circle POD_R=12 vs solid tiles (tile lookup from TileMap or hardcoded grid for R01)

DRAW (GravenDraw or _Draw in main):
- Dark void background #0a0e14
- Pod as simple capsule (DrawRect/DrawCircle) color #3dccff until Kenney ship imported
- Gravity needle: line from pod toward accel direction

ROOM TRANSITION: stub only (when pod hits east exit AABB → roomId=2)

Reply with vg-project-spec OR direct file edits. Game must run F5 in R01 with thrust + curved pull toward floor mass.
Do NOT implement rooms 2–8 yet.
```

---

## Prompt 2 — Room 2 (Bend) — fun gate

```
GRAVEN Prompt 2 — Room 2 Bend (CRITICAL fun test)

Add Room 2 from BLUEPRINT.md:
- Mass M0 (640,780) strength 0.6 + M1 (1040,320) strength 1.8
- Ceiling channel geometry from ASCII map — player must curve into upper passage
- Spawn west, exit east (vertical slot)

Wire LoadRoom(2): swap tile data, reset pod spawn, reset velocity optional.

Tune until flying from spawn naturally bends toward M1 without feeling floaty mush:
- THRUST, G_SCALE, G_MAX, DRAG as Const at top — comment suggested ranges

Keep drawing minimal. Success = 2 minutes of intentional curved flight feels good.

Add debug toggle (key G): draw mass node crosses when held.

Do not add crate, pulse, or hazards yet.
```

---

## Prompt 3 — Rooms 3–4 + beacon + crate

```
GRAVEN Prompt 3 — Room 3 Shelf, Room 4 Crate, beacon save

ROOM 3 (Shelf):
- Mass above room (640, -60) strength 2.0 — ceiling walk
- Layout from BLUEPRINT ASCII

ROOM 4 (First crate):
- Crate entity: position, vx, vy; circle CRATE_R=14; push on pod overlap
- Floor plate at tile ~(28,18) — crate overlap opens south exit to Room 5
- Beacon: entering R4 sets checkpoint room=4, respawn coords
- Terminal at T: F key shows one log string (BLUEPRINT text) — Label or _Draw text

DEATH: if spikes not yet, only out-of-bounds or future — respawn at last beacon (R4 once reached)

Room graph: R1→R2→R3→R4→(south)R5 stub closed until plate satisfied

Split into GravenObjects.vg / GravenRooms.vg if main file grows — keep readable VB6 style.
```

---

## Prompt 4 — Kenney art hookup (optional skin)

```
GRAVEN Prompt 4 — Kenney art (optional; skip if still greyboxing)

Art direction: dark sci-fi cave — NOT cute roguelike. Avoid Micro Roguelike pack.

If assets exist under res://assets/art/:
- TileMap: use 1-Bit Pack OR Abstract Platformer OR Pattern Pack tiles for # solid cells only
- Godot: TileSet modulate dark (0.15, 0.18, 0.22, 1) — we will add shader later
- Player: Space Shooter Redux small ship sprite on Sprite2D OR DrawTexture in _Draw; rotate with podAngle
- Do NOT call DataToArray inside _Draw — cache in _Ready

If no assets downloaded yet:
- Keep DrawRect pod but add edge highlight color #2a3a4a on cave tiles in _Draw overlay

Document in a comment at top of GravenMain.vg which Kenney files you referenced.

Do not change physics while retuning art.
```

---

## Prompt 5 — Room 5 Dark pool + Pulse

```
GRAVEN Prompt 5 — Room 5 Dark pool + Pulse (hero room)

ROOM 5 from BLUEPRINT:
- roomDark flag: ambient draw multiplier 0.08 until Pulse active
- Spikes row tx 16–23 ty 19 — touch = death → respawn beacon
- Mass nodes (200,400) and (1080,400)

PULSE (Space, cooldown 4s, duration 2.8s):
- Dim pulseTimer, pulseCooldown in GravenPulse.vg
- While active: full ambient + expanding ring drawn from pod (DrawCircle outline)
- Export shader uniform pulse_phase 0→1 if ColorRect post material exists; else stub uniform for later

Spikes visible during pulse (or always deadly — player must pulse to navigate)

This room must be playable: enter from R4 south, cross spikes, exit east to R6.

Add one-shot SFX hook comment ' PlaySound pulse path when file exists
```

---

## Prompt 6 — Post shader + Room 6 orbit gate

```
GRAVEN Prompt 6 — graven_post.gdshader + Room 6 orbit gate

SHADER shaders/graven_post.gdshader on full-screen ColorRect (CanvasLayer):
- Uniforms: mass_uv vec2, gravity_vec vec2, pulse_phase float, heat_stress float, ambient float
- Effects: vignette, subtle chromatic aberration scaled by |gravity|, pulse radial brighten
- GravenMain sets uniforms each _Process from nearest mass + accel

ROOM 6 (Orbit):
- Central mass (640,352) strength 2.5
- Track cumulative orbit angle while dist to mass in [80,200] — gate opens east after ≥540°
- Beacon save at northwest alcove
- Gate tiles block exit until orbitComplete

Test: R5→R6→gate opens after orbiting.
```

---

## Prompt 7 — Rooms 7–8 + heat + end card

```
GRAVEN Prompt 7 — Room 7 heat run, Room 8 skiff, Made in VG6 end card

ROOM 7:
- Narrow corridor; heat drains faster (×1.8) between tx 10–30
- Dim heat 0–100; thrust drains heat; empty = death respawn
- Draw heat bar top-center (DrawRect)

ROOM 8:
- Skiff goal at ~(1100,400) — win trigger
- End sequence: fade overlay, text "GRAVEN" + "Made in VG6" + subtitle about readable .vg
- Stop gameplay input; show replay prompt

Full path playable: R1 through R8.

Add Const HEAT_* at top. Comment modules for auditor readability.
```

---

## Prompt 8 — Polish pass

```
GRAVEN Prompt 8 — polish (no new rooms)

- Tune R2 mass strengths until curved flight feels crisp
- R5: ensure Pulse readable in screenshot (contrast)
- QueueRedraw audit: no unconditional redraw every frame
- Split long subs; add phase comments in _Process: ' Input, ' Gravity, ' Collide, ' Draw flag
- Fix any ByRef/array slot issues (copy arr(i) to scalar before Sub calls that modify)
- README.md in vg_graven_slice: how to F5, controls, Kenney credits (CC0), link BLUEPRINT

Run scripts/ci_smoke.sh on a test project if Graven is standalone — or document manual test steps.

Do not expand scope beyond 8 rooms.
```

---

## Prompt F — Fix physics feels wrong

```
GRAVEN fix — physics tuning

Room 2 feels [ mushy | too twitchy | nauseating | can't reach exit ].

Current Const: [paste THRUST, G_SCALE, G_MAX, DRAG, VMAX]

Adjust mass node strengths for room 2 only first. Keep G_SCALE formula:
  accel += normalize(node - pos) * (G_SCALE * strength / max(dist*dist, G_MIN_DIST*G_MIN_DIST))
Clamp accel to G_MAX. Do not switch to CharacterBody2D.

Return changed Const lines only + brief why.
```

---

## Prompt F2 — Narcea dumped raw .vg instead of files

```
Your last reply pasted raw .vg in chat instead of writing projects/vg_graven_slice/.

Reply with ONE fenced ```vg-project-spec``` JSON block only that scaffolds:
- projects/vg_graven_slice/project.godot
- main.tscn (Node2D + TileMapLayer)
- GravenMain.vg
- paths under res:// relative to that project

Include the GRAVEN physics rules from Prompt 0. No prose outside the spec block.
```

---

## Prompt V — Migrate visuals to vector (future)

```
GRAVEN visual migration — Kenney tiles → vector/procedural

Keep all Graven*.vg physics and room logic unchanged.

Replace TileMap rendering with ONE of:
A) VGVectorCanvas2D / vector plugin for cave silhouettes + pod outline
B) _Draw only: edge-lit rects from room grid (no PNG tiles)

Collision stays tile grid or same grid array — rendering only changes.

Palette locked: VOID #0a0e14, STONE #1a2530, GLOW #3dccff, HAZARD #ffb020.
Pulse ring and gravity needle stay in _Draw.

Reference: addons/visual_gasic/plugins/vector_graphics/ and Beta Showcase vector demos.

Do not remove graven_post.gdshader — rewire uniforms if needed.
```

---

## Quick reference — mass nodes per room

| Room | Nodes (pixel x, y, strength) |
|------|------------------------------|
| R1 | (640, 780, 1.0) |
| R2 | (640, 780, 0.6), (1040, 320, 1.8) |
| R3 | (640, -60, 2.0) |
| R4 | (640, 780, 1.0) |
| R5 | (200, 400, 1.4), (1080, 400, 1.4) |
| R6 | (640, 352, 2.5) |
| R7 | (640, 780, 1.2) |
| R8 | none |

Full ASCII maps: [`BLUEPRINT.md`](BLUEPRINT.md).

---

## Tips for Narcea sessions

- **One room per prompt** if the model loses context — split Prompt 3 into 3a/3b.
- Attach **`BLUEPRINT.md`** in chat (↗ Cursor handoff or file context) for room geometry.
- If TileMap parsing is hard for Narcea, allow **hardcoded collision grid** `Dim solid(40,22)` per room in `GravenRooms.vg` copied from ASCII — paint tiles in Godot later for visuals only.
- **Week 1 win:** Prompts 0–2 only. Stop and play R2 before continuing.

---

*Version 1.0 · matches BLUEPRINT slice B · Kenney art optional · vector migration via Prompt V*
