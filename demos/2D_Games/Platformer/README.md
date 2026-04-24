# Pixel Platformer — VisualGasic Demo

A complete 2D platformer written entirely in **VisualGasic** (.vg), the VB6-style
scripting language for Godot 4.6.1+.

Based on the concepts from the
[official Godot 2D Platformer demo](https://github.com/godotengine/godot-demo-projects/tree/master/2d/platformer),
this project demonstrates how to build a real game using VisualGasic's VB6-inspired
syntax with full Godot engine integration.

## Screenshot

![Pixel Platformer](../../docs/screenshots/platformer_preview.png)

## Features

- **Manual physics** — gravity, jumping, double jump, coyote time, and jump buffering,
  all implemented with VB6-style `Single` variables and `_Process(delta)`.
- **Tile-based levels** loaded from `DATA` statements — the classic BASIC approach to
  level design using ASCII art maps embedded directly in the source code.
- **Patrolling enemies** with stomp-to-kill mechanic (jump on their head to defeat them).
- **Collectible coins** with animated bobbing and sparkle particle effects.
- **Scrolling camera** that smoothly follows the player with look-ahead.
- **HUD overlay** showing score, coins, lives, level number, and elapsed time.
- **3 progressively harder levels** — Green Hills, Underground Cavern, Sky Fortress.
- **Particle effects** for jumps, stomps, deaths, and coin collection.
- **Title screen, game over, and victory screens** with animated transitions.
- **All rendering via `_Draw()`** — no imported sprites; everything is drawn with
  `DrawRect`, `DrawCircle`, and `DrawString` primitives.

## Controls

| Action       | Keys                      |
|-------------|---------------------------|
| Move Left   | `A` or `←`                |
| Move Right  | `D` or `→`                |
| Jump        | `Space`, `W`, or `↑`     |

- **Double jump**: Press jump again while airborne for a second, weaker jump.
- **Variable jump height**: Release jump early for a shorter hop.
- **Coyote time**: You can still jump briefly after walking off an edge.
- **Stomp enemies**: Land on an enemy from above to defeat them and bounce.

## VisualGasic Features Demonstrated

| Feature | Usage in This Demo |
|---------|-------------------|
| `Const` declarations | Physics constants (gravity, speed, etc.) |
| `Dim` arrays | Entity pools for coins, enemies, particles |
| `Sub` / `Function` | Modular game code split into update/draw routines |
| `Select Case` | Level selection, tile rendering, game state machine |
| `DATA` / `Read` / `Restore` | Level maps defined as inline ASCII art |
| `_Ready()` | Game initialization |
| `_Process(delta)` | Frame update loop with delta timing |
| `_Draw()` | Full-screen rendering with Godot's CanvasItem API |
| `Input.IsActionPressed()` | Player movement and jumping |
| `For` / `Next` loops | Entity iteration, tile rendering |
| `String` functions | `Mid()`, `Len()`, `Str()`, `Right()`, `Chr()` |
| `Rnd()` | Randomized clouds, particles, enemy timers |
| `Sin()` / `Abs()` | Animation, oscillation, direction checking |
| VB6 naming conventions | `playerX`, `enemyVX`, `coinActive`, etc. |

## How to Run

1. Make sure the `addons/visual_gasic/` folder is present (symlink or copy from the
   main VisualGasic project).
2. Open this folder as a Godot 4.6.1+ project.
3. Press **F5** (or the Play button) to run.

## Level Design

Levels are defined in the `.vg` file using `DATA` statements — one string per row:

```basic
Level1Data:
Data 60, 18
Data ".......................................................#####"
Data "..............C..C..C...............######.................."
Data "P.........C....######...=====......................................"
Data "###############SSS#########SSS######SSS######SS#########SS##"
```

### Tile Legend

| Character | Meaning |
|-----------|---------|
| `.` | Empty air |
| `#` | Solid ground / wall |
| `=` | Brick platform |
| `^` | One-way platform |
| `S` | Spikes (instant kill) |
| `P` | Player start position |
| `C` | Coin |
| `E` | Enemy patrol |
| `F` | Finish flag (level exit) |
| `M` | Moving platform |

## Architecture

The entire game is a **single `.vg` file** attached to a `Node2D` in the scene tree.
This mirrors how classic VB6 games were built: one Form with all the drawing and logic
in a single module. The Godot engine provides the window, input, and frame timing;
VisualGasic handles everything else.

```
platformer.vg          ← All game logic, physics, rendering, and level data
main.tscn              ← Scene with a single Node2D referencing the .vg script
project.godot          ← Godot project settings (window size, input map)
addons/visual_gasic/   ← VisualGasic runtime (symlink)
```

## Credits

- Inspired by the [Godot 2D Platformer Demo](https://github.com/godotengine/godot-demo-projects/tree/master/2d/platformer) (MIT License)
- Written in [VisualGasic](https://github.com/xgreenrx-star/VisualGasic) for Godot 4.6.1+
- Renderer: Forward Plus
