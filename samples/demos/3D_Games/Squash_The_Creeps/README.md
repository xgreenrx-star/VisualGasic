# Squash the Creeps 3D (VisualGasic)

Official Godot **"Your First 3D Game"** tutorial demo converted to **VisualGasic**.

Move around the arena and **jump on the creeps** to squash them for points!
If a creep touches you from the side, you lose.

## Controls

| Key | Action |
|-----|--------|
| **W / ↑** | Move forward |
| **S / ↓** | Move back |
| **A / ←** | Move left |
| **D / →** | Move right |
| **Space / Right Click** | Jump |
| **Space / Enter** | Retry (after game over) |

## What This Demonstrates

- **3D CharacterBody3D** physics driven entirely by VisualGasic
- **SetVelocity(Me, vx, vy, vz)** — 3-component velocity for 3D movement
- **IsOnFloor(Me)** — floor detection for jumping
- **GetCollisionCount(Me)** + slide collision iteration for stomp detection
- **Mob spawning** via `Load()` + `.instantiate()` + `Me.add_child()`
- **Cross-VG-script method calls** (player calls mob's `squash()`, score label's `AddScore()`)
- **Signal emission** via `RaiseEvent` (player death → game over)
- **3D node API** through PascalCase → snake_case AST dispatch (`LookAt`, `LookAtFromPosition`, `RotateY`)
- **Math builtins** (`Sin`, `Cos`, `Sqr`, `Rnd`) for mob direction calculation

## Architecture

| Script | Node Type | Role |
|--------|-----------|------|
| `main.vg` | Node | Game controller — spawns mobs, handles game over/retry |
| `player.vg` | CharacterBody3D | Player movement, jumping, stomp detection, death |
| `mob.vg` | CharacterBody3D | Enemy AI — moves toward player, gets squashed |
| `score_label.vg` | Label | Score counter — incremented when mobs are squashed |

## Original

Converted from [godotengine/godot-demo-projects/3d/squash_the_creeps](https://github.com/godotengine/godot-demo-projects/tree/master/3d/squash_the_creeps).

Uses simplified primitive meshes (capsules and boxes) instead of the original's custom 3D models.
