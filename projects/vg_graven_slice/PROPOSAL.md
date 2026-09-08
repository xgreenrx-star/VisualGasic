# GRAVEN — Developer Proposal (Vertical Slice)

**A mass-gravity cave explorer for Visual Gasic 6**  
**Scope:** 8 rooms · ~15–20 minutes · proof-of-concept before **v6.0 stable** (target Jan 2027)  
**Audience:** VB6-era developer comfortable with readable BASIC-style code; Godot experience not required to start  

**Recruiting:** Facebook collab post copy in [`FACEBOOK_COLLAB_POST.md`](FACEBOOK_COLLAB_POST.md).  
**Narcea build prompts:** [`NARCEA_PROMPTS.md`](NARCEA_PROMPTS.md) (phased copy-paste for AI Pair).

---

## The pitch in one paragraph

We want to build a small game that feels like the BBC Micro classic **Exile** — side-view caverns where gravity pulls toward **mass** instead of always pulling down — but with modern lighting, a sonar pulse that reveals hidden caves, and a polished “one more try” feel. The hook for the wider project is not just the game: when you finish the slice, the screen flashes **“Made in VG6”**, because every rule (movement, gravity, puzzles, heat) lives in **Visual Gasic** — a VB6-flavoured language that runs inside **Godot 4.6**. If the slice is fun and looks good, it becomes the flagship demo for a language aimed at people who want to **read** game logic the way they read VB6, not dig through nested callbacks.

You would help bring this to life. Your VB6 background maps directly to the work. Your graphics skills are the piece we were missing in the original plan.

---

## Why this might interest you

| If you liked… | This project gives you… |
|---------------|-------------------------|
| VB6 forms, modules, `Sub`/`Function` | Same mental model in `.vg` files — `Dim`, `If…Then`, `For…Next`, event-style subs |
| Reading someone else’s code at a glance | The whole game loop is meant to stay readable on purpose |
| Pixel art or tile work | Cave tiles, pod, crates, UI, shader-friendly palette — **you own the look** |
| Physics puzzles without AAA scope | Eight rooms, not eighty — each teaches one idea |
| A portfolio piece with a story | “I built the art and co-dev on the VG6 flagship demo” |

You do **not** need to be a Godot expert on day one. You need to be willing to use Godot as a **level editor and renderer** (place tiles, attach a script, press F5). The game rules themselves are written in Visual Gasic, which will feel familiar within an hour if you ever typed `Dim x As Integer` for a living.

---

## What the player experiences (the fantasy)

You are in a prospector’s pod inside **Masswell**, a hollow asteroid with wrong physics. A **gravity needle** on the HUD shows which way you’re being pulled — toward invisible **mass nodes**, not toward the floor. You thrust, rotate in 90° snaps, and navigate caverns. In dark rooms you fire a **Pulse** (sonar): a ring expands, the shader briefly reveals walls and hazards, and you memorize the path. You push crates, orbit a heavy mass to open a gate, race a **heat** meter through a tight tunnel, and reach a surface **skiff**. End card: **GRAVEN — Made in VG6**.

First “wow” target: **Room 2**, where gravity curves your flight path when you expected to fall straight. Second wow: **Room 5**, dark until Pulse — that’s where your art and the lighting shader sell the project.

---

## Scope: what we are and are not building

### In scope (Vertical Slice B)

- **8 connected rooms** (~15–20 minutes first time)
- Mass-based gravity (2–4 attractor points per room)
- Thrust + 90° rotation controls
- One pushable crate, one orbit-gate puzzle, one dark sonar room
- Heat meter (pressure in the last corridor)
- Two save **beacons**
- One fullscreen post-process shader (mood + pulse + heat stress)
- End screen with **Made in VG6** branding

### Out of scope (save for later)

- Full 31-room campaign
- Enemies and combat
- Multiple biomes, save files, speedrun seeds
- 3D, multiplayer, mobile ports
- A faithful “Exile remake” (this is a **spiritual successor** — new name, new fiction, same core idea)

---

## Legal / naming note

Do **not** use the name Exile, Acorn, or any original assets in marketing or in-game text. In docs we say *“inspired by 1980s mass-gravity cave games.”* The working title is **GRAVEN**.

---

## How the work splits (you vs engine vs coordinator)

Think of three layers:

```
┌─────────────────────────────────────────┐
│  YOU: tiles, sprites, palette, juice    │  ← visual identity
├─────────────────────────────────────────┤
│  VISUAL GASIC (.vg): rules, physics,    │  ← VB6-like game logic
│  puzzles, HUD draw calls                │
├─────────────────────────────────────────┤
│  GODOT: window, input, TileMap, shader  │  ← editor + runtime host
│  file, audio playback                   │
└─────────────────────────────────────────┘
```

| You likely own | Shared / coordinator | Engine handles |
|----------------|----------------------|----------------|
| Tileset (16×16 or 32×32 cave) | Room layout from blueprint maps | Window, framerate, input polling |
| Pod / crate / skiff sprites (or approve procedural shapes) | Mass node placement tuning | TileMap collision layer |
| Palette, UI look, terminal typography | `.vg` module structure | Shader host (`.gdshader` file — can be provided as template) |
| Background mood (parallax art optional) | Week-by-week playtesting | Audio playback |
| Marketing screenshots | Git / project scaffolding | GDExtension load (Visual Gasic plugin) |

**Important:** Game logic should live in **`.vg`**, not GDScript, so the “Made in VG6” claim is honest. Godot scenes hold level geometry and hook the VG script to a `Node2D`.

If you prefer to **paint tiles in Aseprite** and **block rooms in Godot’s 2D editor**, that is exactly the workflow we want. You are not expected to implement inverse-square gravity in C++.

---

## Visual direction (your brief)

**Art pillar:** *silhouette + volume light* — dark caves, bright rim edges, glowing interactables.

Suggested palette (adjust if you have a better eye):

| Role | Hex | Use |
|------|-----|-----|
| Void | `#0a0e14` | Background |
| Stone | `#1a2530` | Rock fill |
| Stone edge | `#2a3a4a` | Highlights / tile edge detail |
| Glow | `#3dccff` | Pod window, beacon, sonar, terminals |
| Hazard | `#ffb020` | Spikes, heat warning |
| Highlight | `#e8f4ff` | Skiff, artifact, title text |

**Slice art deliverables (minimum):**

1. **One tileset** — solid rock + optional edge variant + spike tile (Room 5)
2. **Pod** — small sprite or 16×16 sheet (4 rotations if sprite; otherwise we draw a capsule in VG)
3. **Crate** — one tile or 16×16 sprite
4. **Beacon / terminal / skiff** — simple icons
5. **Optional:** parallax background layer (cave depth), grain overlay texture for shader

**Week 1 can be grey boxes.** We only need final art before Room 5 (dark sonar) for the hero shot — roughly Week 3 in the schedule below.

A coordinator can supply a **shader template** that adds rim light and pulse wave; your tiles should read well in **low ambient light** (Room 5 drops to ~8% brightness until Pulse).

---

## Controls (fixed for slice)

| Action | Keyboard | Notes |
|--------|----------|-------|
| Thrust | W or Up | Hold to accelerate along pod facing |
| Rotate left | Q | 90° snap |
| Rotate right | E | 90° snap |
| Pulse (sonar) | Space | Cooldown ~4 s; reveals dark room |
| Interact | F | Terminal in Room 4 |
| Pause | Escape | |

Gamepad mapping can come later.

---

## Room guide (all eight)

Each room fits one screen: **40×22 tiles** at **32×32 px** (1280×704). Connections are instant cuts (no scrolling camera in the slice).

```
R1 ──► R2 ──► R3 ──► R4 ══ beacon
                    │
                    ▼
                   R5 ──► R6 ══ beacon ──► R7 ──► R8 END
```

### Room 1 — Airlock
**Teaches:** thrust and rotate; gentle pull toward mass below the floor.  
**Hazards:** none. Safe sandbox.

### Room 2 — Bend
**Teaches:** gravity **curves** flight — strong mass upper-right pulls you into a ceiling channel.  
**This is the Week 1 fun test.** If this room isn’t interesting, we stop and retune before building more.

### Room 3 — Shelf
**Teaches:** land on the **ceiling**; mass above the room inverts “down.”

### Room 4 — First crate
**Teaches:** push crate onto a floor plate; **beacon save**; readable terminal log:

> MASSWELL SURVEY — LOG 7  
> Don’t trust the floor. Trust the needle.  
> — Chen

### Room 5 — Dark pool
**Teaches:** **Pulse** required — spikes in the floor, almost no light until sonar.  
**Hero visual room** — art + shader must sell the project here.

### Room 6 — Orbit
**Teaches:** circle a central mass (~one full orbit) to open the east **gate**; second beacon.

### Room 7 — Heat run
**Teaches:** narrow corridor; heat drains faster — reach the exit before the bar empties (forgiving tuning).

### Room 8 — Skiff
**Payout:** surface ledge, skiff, fade to **GRAVEN** title + **Made in VG6**.

---

## Detailed room maps (for building TileMaps)

Legend: `#` = solid rock · `.` = air · `P` = player start · `E` = exit · `B` = beacon · `C` = crate · `S` = spikes · `T` = terminal · `G` = gate (closed until puzzle solved)

Full ASCII grids and exact **mass node pixel coordinates** are in [`BLUEPRINT.md`](BLUEPRINT.md) (companion doc, same folder). Copy tile layouts from there into Godot’s TileMap painter.

**Mass nodes** are invisible in-game (revealed briefly on Pulse). Each room lists 1–4 attractor points as `(x, y, strength)` in pixels. Coordinator or VG script holds the table; you place a marker layer in editor if that helps you visualize pull direction while playtesting.

---

## Visual Gasic for a VB6 developer (30-second orientation)

Visual Gasic (`.vg`) files look like VB6 modules:

```vb
Sub _Ready()
    Dim heat As Single
    heat = 100.0
End Sub

Sub _Process(delta As Single)
    ' thrust, gravity, collision — same rhythm as VB6 game loop
End Sub

Sub _Draw()
    DrawRect 100, 100, 24, 16, RGB(61, 204, 255)
End Sub
```

- **`Sub _Ready()`** ≈ Form_Load  
- **`Sub _Process(delta)`** ≈ Timer tick with delta time  
- **`Sub _Draw()`** ≈ Paint on a canvas (for pod/HUD if not sprite-based)  
- **`Dim x As Single`**, **`If…Then…End If`**, **`Function…End Function`** — as you remember them  

Godot attaches the `.vg` file to a node; the Visual Gasic plugin compiles and runs it. You edit `.vg` in the Godot IDE with Visual Gasic enabled — or in any text editor.

**Your comfort zone:** puzzle flags, crate state, terminal text, tuning numbers at the top of a module (`Const THRUST = 420`). **Less familiar at first:** Godot scene tree — we provide a starter project and one-page “click here to run.”

---

## Suggested timeline (part-time, ~10–15 hrs/week)

| Week | Focus | Art role | Logic role |
|------|-------|----------|------------|
| **1** | Rooms 1–2 playable | Grey tile OR first tileset draft | Gravity + thrust + collision |
| **2** | Rooms 3–4 | Crate, terminal, beacon look | Crate push, save beacon |
| **3** | Rooms 5–6 | **Final mood for dark room** | Pulse + shader hookup, orbit gate |
| **4** | Rooms 7–8, polish | Skiff, title/end card | Heat corridor, end sequence, capture trailer |

**Go / no-go at end of Week 1:** play Room 2 for two minutes. Is curved gravity fun? If yes, continue. If no, retune numbers before art polish.

---

## Deliverables checklist

### Must ship (slice complete)

- [ ] Godot 4.6 project under `projects/vg_graven_slice/`
- [ ] 8 room TileMaps (from blueprint layouts)
- [ ] Tileset (+ optional character/prop sprites)
- [ ] `.vg` files implementing movement, gravity, rooms, pulse, puzzles
- [ ] Post-process shader integrated (template OK to start)
- [ ] 1 ambient loop + pulse SFX (royalty-free)
- [ ] End card: **Made in VG6** + link to Visual Gasic repo
- [ ] 30–60 s gameplay clip for marketing

### Nice to have

- [ ] Parallax background
- [ ] Gamepad support
- [ ] Short README: “How to open and press F5”

---

## Physics numbers (starting point — expect tuning)

These are not sacred; they are where Week 1 begins:

| Setting | Value | Feels like |
|---------|-------|------------|
| Thrust | 420 | Snappy but controllable |
| Max speed | 280 | No infinite acceleration |
| Gravity scale | 120000 × strength / dist² | Strong pull near mass nodes |
| Pod collision radius | 12 px | Forgiving cavern flight |
| Heat drain | 1.5/s idle, 8/s thrusting | R7 cranks this up |
| Pulse duration | 2.8 s | Enough to cross dark room |
| Pulse cooldown | 4 s | Can’t spam |

Full table in [`BLUEPRINT.md`](BLUEPRINT.md).

---

## Tooling you need

| Tool | Purpose |
|------|---------|
| **Godot 4.6.1** | Editor, TileMap, run game (F5) |
| **Visual Gasic** | Plugin + GDExtension from main repo; install via Asset Library or project addon copy |
| **Aseprite / LibreSprite / GIMP** | Tiles and sprites (your choice) |
| **Git** | Share work; branch `graven-slice` or similar |

Coordinator provides: repo access, addon symlink, empty `project.godot`, shader stub, [`BLUEPRINT.md`](BLUEPRINT.md), answer questions on VG syntax.

---

## What success looks like

1. **A stranger plays 5 minutes** without reading a manual and understands thrust + needle + pulse.  
2. **Room 5 screenshot** looks like a real indie game, not a tech demo.  
3. **Opening `GravenMain.vg`** (or equivalent) shows readable game logic — a VB6 developer nods.  
4. **End card** makes someone ask “what is VG6?” — that is the whole point for the parent project.

---

## Compensation / credit (fill in before handoff)

*Coordinator to complete:*

- [ ] Paid: $________ / rev share / volunteer credit  
- [ ] Credit line: “Art & development — [Name]” on end card and repo README  
- [ ] IP: GPL-3.0 consistent with Visual Gasic repo (confirm contributor agreement)

---

## How to respond if you’re interested

Reply with:

1. **Comfort level** — VB6 yes; Godot 0–10; pixel art 0–10  
2. **Weekly hours** available for ~4 weeks  
3. **Art sample** (optional) — one 16×16 tile or palette mockup in the brief above  
4. **Questions** — anything in this doc that feels vague or scary  

We can schedule a 30-minute walkthrough: install Visual Gasic, open an existing `.vg` platformer demo, press F5, then map Room 1 tiles together.

---

## Companion documents

| File | Contents |
|------|----------|
| [`BLUEPRINT.md`](BLUEPRINT.md) | ASCII maps for all 8 rooms, mass coordinates, scene tree, `.vg` module list, shader uniforms, week checklists |
| [Visual Gasic README](../../README.md) | Language & project context |
| [Getting Started](../../docs/guides/GET_STARTED.md) | Install Godot + addon |

---

## Closing thought

This is a **small, finishable** game with a **big story** behind it: prove that a VB6-minded language can ship something that looks modern and plays addictively. Exile proved mass gravity could carry a whole world on 1980s hardware; we only need to prove it carries **eight rooms** and one great screenshot on Visual Gasic 6.

If you’ve ever wanted someone to care about readable game code as much as readable UI code — this is that project. And if you’ve been looking for a scoped gig where **your art is the difference between “tech demo” and “I’d play that”** — Room 5 is waiting.

---

*Proposal version: 1.0 · September 2026 · Visual Gasic / GRAVEN vertical slice B*
