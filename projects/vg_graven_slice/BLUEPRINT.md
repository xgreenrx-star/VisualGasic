# GRAVEN — Vertical Slice Blueprint (8 rooms)

**Codename:** GRAVEN · **Slice B** · **Target:** 15–20 minutes playable  
**Purpose:** Prove mass-gravity fun + shader mood before expanding to full demo.  
**Pitch end card:** `Made in VG6 — game logic in readable BASIC`

**External collaborators:** see [`PROPOSAL.md`](PROPOSAL.md) for the human-readable handoff brief (VB6 background, art ownership, timeline).  
**Narcea / AI Pair:** phased prompts in [`NARCEA_PROMPTS.md`](NARCEA_PROMPTS.md).

Inspired by mass-gravity cavern explorers of the 1980s (not a remake).  
**Status:** Blueprint — implementation follows Week 1–4 order below.

---

## Locked decisions

| Decision | Choice | Notes |
|----------|--------|-------|
| **Tile size** | 32×32 px | Godot TileMap `cell_size = (32, 32)` |
| **Room size** | 40×22 tiles (1280×704 px) | Fits 720p with letterbox margin |
| **Room art (slice)** | TileMap blockout | One solid tile type; skin optional later |
| **Gameplay logic** | Pure `.vg` on `Node2D` | Not `CharacterBody2D` physics |
| **Rotation** | **Tap 90°** | `Q` / `E` or bumper LB/RB — no smooth spin in slice |
| **Collision** | Circle (pod) vs tile grid | Radius 12 px; sample 4 corners or grid lookup |
| **Mass model** | Inverse-square toward nodes | Clamped force; see constants |
| **Camera** | Room-fixed (no scroll) | One screen = one room; instant cut on exit |
| **Death** | Respawn last beacon | R1–R3: no hazards; R4+ beacon after R4 |

---

## Palette (hex)

| ID | Color | Use |
|----|-------|-----|
| `VOID` | `#0a0e14` | Background / letterbox |
| `STONE` | `#1a2530` | TileMap solid (blockout) |
| `STONE_EDGE` | `#2a3a4a` | Rim-lit edge (shader) |
| `GLOW` | `#3dccff` | Pod window, beacon, sonar |
| `HAZARD` | `#ffb020` | Heat warning, spikes (R5+) |
| `ARTIFACT` | `#e8f4ff` | Terminal text, exit skiff |

Shader drives most “stunning”; tiles stay dark matte until Pulse.

---

## Input map (Godot project settings)

| Action | Keys | Gamepad |
|--------|------|---------|
| `thrust` | W, Up | A / RT |
| `rotate_ccw` | Q | LB |
| `rotate_cw` | E | RB |
| `pulse` | Space | X |
| `interact` | F | Y |
| `pause` | Escape | Start |

---

## Physics constants (tuning targets — Week 1)

All distances in **pixels**, time in **seconds**, angles in **degrees**.

| Constant | Symbol | Initial | Notes |
|----------|--------|---------|-------|
| Thrust accel | `THRUST` | 420 | While hold; scales with pod facing |
| Max speed | `VMAX` | 280 | Clamp velocity magnitude |
| Linear drag | `DRAG` | 0.92 | Per frame: `v *= DRAG` |
| Mass G scale | `G_SCALE` | 120000 | `accel += dir * (G_SCALE * strength / dist²)` |
| Min dist clamp | `G_MIN_DIST` | 48 | Avoid singularity at node |
| Max accel / frame | `G_MAX` | 600 | Clamp resultant gravity |
| Pod radius | `POD_R` | 12 | Collision circle |
| Crate radius | `CRATE_R` | 14 | Heavier feel: lower `VMAX` when pushing |
| Rotate step | — | 90° | Instant on tap |
| Heat max | `HEAT_MAX` | 100 | Abstract “ suit stress ” |
| Heat idle drain | `HEAT_IDLE` | 1.5 /s | |
| Heat thrust drain | `HEAT_THRUST` | 8 /s | |
| Thrust heat threshold | — | R7 only ramps to 12 /s | |
| Pulse duration | `PULSE_TIME` | 2.8 s | Reveal + shader wave |
| Pulse cooldown | `PULSE_CD` | 4.0 s | |
| Beacon save | — | Room enter R4, R6 | Slice has 2 beacons |

**World Y:** +Y is down (Godot 2D default).

---

## Coordinate systems

### Tile space

- Origin top-left of room `(0, 0)`.
- Tile `(tx, ty)` → pixel center `(tx * 32 + 16, ty * 32 + 16)`.
- Solid tile: `#` in maps below.

### Mass nodes

Per room: up to **4** entries in `GravenRooms.vg`:

```
' Format: nodeX, nodeY, strength (0 = unused slot)
Room2Mass(1) = 960, 200, 1.2   ' pixel X, pixel Y, strength multiplier
```

Strength multiplier × `G_SCALE / dist²` at runtime.

### Entity spawn

Spawn / exit rectangles in **pixel AABB** (top-left x, y, width, height).

---

## Room graph

```
R1 ──east──► R2 ──east──► R3 ──east──► R4 ══ BEACON
                         │
                         south
                         ▼
                        R5 ──east──► R6 ══ BEACON ──east──► R7 ──east──► R8 END
```

| From | Dir | To | Door type |
|------|-----|-----|-----------|
| R1 | E | R2 | open |
| R2 | E | R3 | open |
| R3 | E | R4 | open |
| R4 | S | R5 | open (after terminal optional) |
| R5 | E | R6 | open |
| R6 | E | R7 | **orbit gate** (opens when orbit flag set) |
| R7 | E | R8 | open |

---

## Legend (ASCII maps)

```
#  solid rock (TileMap layer 0)
.  empty air
P  player spawn (marker only — not a tile)
E  exit trigger volume (empty tile + trigger rect)
B  beacon (R4, R6 — visual + save)
C  crate spawn
M  mass node marker (position in table, not tile)
T  terminal interact
S  spike hazard (R5 — kill on touch)
G  orbit gate (closed until flag)
```

Rows = 22 (`ty` 0–21), columns = 40 (`tx` 0–39).

---

## Room 1 — Airlock

**Teaches:** thrust, rotate, gentle downward pull.  
**Hazards:** none.  
**Mass nodes:**

| ID | Pixel (x, y) | Strength |
|----|--------------|----------|
| M0 | 640, 780 | 1.0 |

*(Below floor — pulls “down” toward planet core.)*

**Spawn:** tile (8, 17) → pixel (272, 560)  
**Exit E:** tile (38, 17) → trigger 1216×64 at floor level  
**Terminal:** none

```
########################################
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#........P.............................#
#....................................E.#
########################################
```

---

## Room 2 — Bend

**Teaches:** gravity curves trajectory — “wrong way” fall.  
**Mass nodes:**

| ID | Pixel (x, y) | Strength |
|----|--------------|----------|
| M0 | 640, 780 | 0.6 |
| M1 | 1040, 320 | **1.8** |

Strong M1 upper-right pulls path into ceiling channel.

**Spawn:** (48, 560) west side  
**Exit E:** east wall mid-height (948, 280) 64×128 vertical slot

```
########################################
#......................................#
#...............................####...#
#............................E..#......#
#...............................#......#
#..............................##......#
#.............................##.......#
#............................##........#
#...........................##.........#
#..........................##..........#
#.........................##...........#
#........................##............#
#.......................##.............#
#......................##..............#
#.....................##...............#
#....................##................#
#...P...............##.................#
#..................##..................#
#.................##...................#
#................##....................#
#...............##.....................#
########################################
```

---

## Room 3 — Shelf

**Teaches:** land on **ceiling**; needle inversion.  
**Mass nodes:**

| ID | Pixel (x, y) | Strength |
|----|--------------|----------|
| M0 | 640, -60 | **2.0** |

Mass **above** room — “up” is toward ceiling walk surface.

**Spawn:** floor alcove left  
**Exit:** right ceiling shelf at (1200, 80)

```
########################################
#...E..................................#
#..##..................................#
#.##...................................#
P.#....................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
########################################
```

Player spawns floor left, thrusts to ceiling shelf, exits right along ceiling.

---

## Room 4 — First crate

**Teaches:** push crate; **beacon**; terminal log #1.  
**Mass nodes:**

| ID | Pixel (x, y) | Strength |
|----|--------------|----------|
| M0 | 640, 780 | 1.0 |

**Crate C:** tile (12, 16) → pixel (400, 528)  
**Plate:** tile (28, 18) — crate must overlap ±16 px  
**Beacon B:** tile (6, 10)  
**Terminal T:** tile (4, 12)

**Exit S:** to R5 — floor center pit door (640, 650) 96×48

```
########################################
#......................................#
#......................................#
#......................................#
#......................................#
#..T..................................#
#..B..................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#............C.........................#
#...P..........................[plate]..#
#......................................#
#..................S...................#
########################################
```

**Terminal text:**

> MASSWELL SURVEY — LOG 7  
> Don’t trust the floor. Trust the needle.  
> — Chen

---

## Room 5 — Dark pool

**Teaches:** **Pulse** (sonar); hero visual beat.  
**Flags:** `roomDark = true` until pulse active.  
**Mass nodes:**

| ID | Pixel (x, y) | Strength |
|----|--------------|----------|
| M0 | 200, 400 | 1.4 |
| M1 | 1080, 400 | 1.4 |

**Spikes S:** row of tiles ty=19, tx=16..23 (hidden until pulse or always deadly if touched)

**Spawn:** west platform  
**Exit E:** east after spike field

```
########################################
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#P................SSSSSSSS...........E..#
#................SSSSSSSS..............#
#................SSSSSSSS..............#
#......................................#
########################################
```

Without Pulse: ambient light 0.08; with Pulse: 1.0 fade over 2.8 s + shader ring.

---

## Room 6 — Orbit

**Teaches:** circle mass node to charge **orbit flag**; gate opens.  
**Mass nodes:**

| ID | Pixel (x, y) | Strength |
|----|--------------|----------|
| M0 | 640, 352 | **2.5** |

Central strong attractor.  
**Gate G:** blocks east exit until `orbitComplete` (≥ 540° cumulative angle around M0 within r=80..200).  
**Beacon B:** northwest alcove

```
########################################
#......................................#
#..B...................................#
#..##..................................#
#...#..................................#
#...#..............M...................#
#...#.............( )..................#
#...#.............( )..................#
#...#.............( )..................#
#...#..............P...................#
#...#..................................#
#...#..................................#
#...#..................................#
#...#..................................#
#...#..................................#
#...#..................................#
#...#..................................#
#...#..............................G.E.#
#...#..............................#.#.#
#...#..............................#.#.#
########################################
```

`( )` = open chamber around mass; player thrusts tangentially.

---

## Room 7 — Heat run

**Teaches:** heat pressure; faster drain in corridor.  
**Mass nodes:**

| ID | Pixel (x, y) | Strength |
|----|--------------|----------|
| M0 | 640, 780 | 1.2 |

**Heat zone:** tx 10..30 — multiply drain ×1.8  
**Spawn:** west  
**Exit E:** east — narrow throat

```
########################################
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#P..............#######................#
#...............#.....#................#
#...............#.....#................#
#...............#.....#................#
#...............#.....#................#
#...............#.....#................#
#...............#.....#................#
#...............#.....E.#................#
#...............#######................#
#......................................#
########################################
```

---

## Room 8 — Skiff (END)

**Teaches:** payoff; **Made in VG6** card.  
**Mass nodes:** none (near-zero G drift optional)  
**Spawn:** west ledge  
**Goal:** reach skiff sprite at (1100, 400) — triggers end sequence

```
########################################
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#P..............................[SKIFF].#
#......................................#
#......................................#
#......................................#
#......................................#
########################################
```

**End sequence:** fade → title **GRAVEN** → `Made in VG6` → link buttons (GitHub / docs).

---

## Godot scene tree (slice)

```
GravenMain (Node2D)                    ← GravenMain.vg attached
├── ParallaxBackground
│   ├── LayerFar (ColorRect gradient)
│   └── LayerNear (GPUParticles2D dust — optional Week 3)
├── RoomRoot (Node2D)
│   ├── TileMapSolid (TileMapLayer)    ← swapped per room
│   └── Triggers (Node2D)              ← Area2D children or VG AABB tests
├── Entities (Node2D)                  ← crate, gate, terminal markers
├── GameDraw (Node2D)                  ← GravenDraw.vg — pod, HUD, FX
└── PostFX (CanvasLayer)
    └── ColorRect (full-screen shader) ← graven_post.gdshader
```

**Alternative:** single `TileMap` per room as separate `.tscn` under `rooms/R01_airlock.tscn` … `R08_skiff.tscn`; loader changes scene child.

**Slice recommendation:** `rooms/R0N.tscn` prefabs + `GravenMain.vg` loads by room ID.

---

## VG module split

| File | Responsibility |
|------|----------------|
| `GravenMain.vg` | `_Ready`, room load, transitions, game state, end card |
| `GravenPlayer.vg` | `#Include` or merged — thrust, rotate, velocity, heat, death |
| `GravenGravity.vg` | `Function GravityAccel(px, py)` → `{x, y}` |
| `GravenRooms.vg` | Room ID, mass tables, flags, spawn/exit rects |
| `GravenObjects.vg` | Crate push, plate detect, gate, terminal, orbit counter |
| `GravenPulse.vg` | Cooldown, reveal timer, shader uniform exports |
| `GravenDraw.vg` | `_Draw` pod, crate, needle HUD, sonar ring |
| `GravenCollide.vg` | Circle vs tile grid, spike kill |

Week 1 may merge into `GravenMain.vg` + `GravenPhysics.vg` until split is warranted.

---

## Shader uniforms (`shaders/graven_post.gdshader`)

| Uniform | Type | Driven by |
|---------|------|-----------|
| `mass_uv` | `vec2` | Nearest mass node normalized 0–1 |
| `gravity_vec` | `vec2` | Current accel direction |
| `pulse_phase` | `float` | 0–1 during sonar |
| `heat_stress` | `float` | 0–1 from heat bar |
| `ambient` | `float` | R5 dark = 0.08, else 0.35 |
| `vignette` | `float` | constant 0.6 slice |

VG sets via material uniform API each `_Process` (see Command Help `ShaderMaterial`).

---

## Graphics pipeline checklist

| Week | Layer | Deliverable |
|------|-------|-------------|
| 1 | L2 | R1–R2 TileMap `.tscn`, grey `#1a2530` tile |
| 1 | L3 | White rect pod, debug mass crosshair |
| 2 | L2 | R3–R6 tilemaps |
| 2 | L3 | Pod capsule draw, crate rect |
| 3 | L4 | `graven_post.gdshader` + Pulse hook |
| 3 | L1 | Parallax gradient |
| 4 | L3 | HUD needle, heat bar, beacon FX |
| 4 | — | End card UI |

**Optional skin:** Kenney “Micro Roguelike” or similar 16×16 → recolor to STONE palette.

---

## Implementation weeks (recap)

### Week 1 — Grey fun (R1–R2 only)

- [ ] `project.godot` + input map
- [ ] `rooms/R01.tscn`, `rooms/R02.tscn`
- [ ] `GravenMain.vg`: load room, spawn, exit trigger
- [ ] Gravity + thrust + tile collision
- [ ] **Gate:** 2 minutes of R2 feels fun

### Week 2 — Content (R3–R4)

- [ ] Ceiling room, crate, beacon save, terminal
- [ ] Branch to R5 south exit

### Week 3 — Hero beat (R5–R6)

- [ ] Dark + Pulse + shader
- [ ] Orbit gate logic + beacon 2

### Week 4 — Finish (R7–R8)

- [ ] Heat corridor, skiff, end card
- [ ] 30 s capture; go/no-go on full 31-room demo

---

## Go / no-go criteria

| Result | Action |
|--------|--------|
| R2 gravity fun by Week 1 end | Continue |
| R2 mushy after 2 days tuning | Revisit `G_SCALE`, `THRUST`, mass placement |
| R5 Pulse doesn’t impress | Fix shader before more rooms |
| Whole slice bland | Redesign R2/R5 geometry, not art budget |
| Slice fun | Plan 31-room `BLUEPRINT_FULL.md` |

---

## Open items (confirm before Week 1 code)

- [ ] **Project path:** `projects/vg_graven_slice/` (this doc)
- [ ] **Main scene:** `main.tscn` → `GravenMain.vg`
- [ ] **Symlink addon:** `addons/visual_gasic` → repo addon (same as other projects)
- [ ] **Rotate keys:** Q/E OK or prefer Z/X?
- [ ] **Kenney skin in Week 1?** Default: **no** — grey blockout only

---

## Files to create (Week 1)

```
projects/vg_graven_slice/
├── BLUEPRINT.md          ← this file
├── project.godot
├── main.tscn
├── GravenMain.vg
├── rooms/
│   ├── R01_airlock.tscn
│   └── R02_bend.tscn
├── tiles/
│   └── cave_blockout.tres   # single 32×32 solid
└── shaders/
    └── graven_post.gdshader   # Week 3 stub with ambient only
```

---

*Next step after blueprint sign-off: scaffold `project.godot` + R01/R02 TileMaps + minimal `GravenMain.vg` (Week 1).*
