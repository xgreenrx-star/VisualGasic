# Elite Wire Slice

Playable **C64 Elite** slice in Visual Gasic: wireframe flight, a rotating Coriolis, a 20-tonne hold, and a station market. Drawn with **`DrawRawWireMesh`**.

## Status for reviewers

This demo is **incomplete by design** — a solid starting point, not a finished game.

- **Drawing:** You may see line artifacts, smearing, or chunky HUD elements on **OpenGL compatibility** (especially Intel Mesa). Stars intentionally avoid batched line segments for that reason. The cockpit is placeholder filled geometry, not final art.
- **Gameplay:** Simplified market (8 goods), eight hand-placed systems, no galactic chart, fuel, equipment, legal status, or full Elite AI/economy.
- **Docking:** Roll-matched Coriolis slot is approximated; tuning and visuals will need more work.

**Likely next steps:** shaded or filled **polygon faces** on ships/stations/rocks for depth; better scanner stalks; cockpit panels with consistent fill (no hollow vector font on instruments); engine fixes for `DrawLinesColored` / batch line dispatch where still needed; optional post-FX once the base pass is stable.

Code comments in `elite_wire_slice.vg` mark major sections and known limitations.

## What this follows

| Source | How we use it |
|--------|----------------|
| **Elite (C64, Firebird, 1985)** | The game this slice is aiming at. Ian Bell’s conversion of the BBC original: same Coriolis docking, same tonne-based trade, same Cobra-style hold. Presentation here is VG wireframe, not the C64 bitmap. |
| **Ian Bell’s Elite docs** (`elite.bbcelite.com`) | Shared design (market goods, docking, galaxy ideas). The C64 and BBC builds use that model. |
| **Elite: The New Kind** | Algorithm reference only. Do not ship its meshes or text. |
| **Oolite, Pioneer, Alite** | Not ports. No GPL assets. |

Still **not** in this demo: galactic chart, fuel in light years, equipment shop, legal status, the full 17-good price formula, or witchspace. Eight hand-placed systems stand in for the generated galaxy.

## Run

Open this folder in Godot 4.6 with Visual Gasic enabled, press **F5**.

Embedded play often ignores fullscreen. **O** saves the choice; a separate game window or export applies it.

```bash
./Godot_v4.6.1-stable_linux.x86_64 --path samples/games/elite_wire_slice
```

## Controls

| Key | Action |
|-----|--------|
| Space / Enter | Leave the title |
| H | Help |
| O | Options (fullscreen, saved) |
| W / S | Thrust / brake |
| Arrows | Yaw / pitch |
| Q / E | Roll (holds; match the station slot) |
| Space | Laser (rocks scoop **minerals** into the hold) |
| M | Missile |
| J | Hyperspace (4 credits). Hostiles wait before they appear. |
| Docked: Up / Down | Select a good |
| Docked: B / S | Buy / sell one tonne at this system’s price |
| Docked: L | Launch |

You start with **100 credits** and an empty **20t** hold (Cobra-sized, not the old single cargo counter). Prices move with the system number, so a good bought cheap can sell higher after **J**. Mining a rock down adds one tonne of minerals if the hold has room.

## Cockpit

Flight uses a **front view** over a console, in the spirit of Archimedes Elite (1991): open window, elliptical scanner with height, shield, speed, and four energy banks. The art is original vector work. Archimedes and C64 screens are copyrighted, so this is not a trace of those pictures.

Mouse aim uses a small dead zone around the crosshair and ignores the console. **O** → **STICK** toggles flight-sim pitch (C64: forward / up dives) and camera pitch (up climbs). The choice is saved.

The station **and** the letterbox spin together about the axis facing you (C64 Coriolis). Come in slow, keep the station near the crosshair, and roll with **Q / E** until your wings match the slot. The HUD says why a pass failed (`TOO FAST`, `LINE UP ON THE SLOT`, `MATCH ROLL`).

## Field

Six rocks, placed well ahead. A pirate arrives after a delay; a heavier ship later. They are not waiting on the title launch the way an earlier build did.

## Files

| File | Role |
|------|------|
| `elite_wire_slice.vg` | Flight, market, save; file header + section comments (see **Status for reviewers**) |
| `scripts/EliteMeshes.vg` | Original wire meshes (not TNK / Oolite); edges only until filled-face pass |

Saves and options live under `user://`. An older three-line save loads credits, system, and minerals only.
