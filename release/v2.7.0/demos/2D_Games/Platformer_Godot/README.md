# 🎮 Platformer 2D — Godot Level Designer Edition (VisualGasic)

> **Official Godot 2D Platformer demo converted from GDScript to VisualGasic**

This demo proves that VisualGasic can drive **real Godot games** — not just
`_Draw()`-based rendering or DATA-statement levels. Every scene, sprite, TileMap,
animation, and physics body comes directly from Godot's official demo project. The
only change: all GDScript (`.gd`) has been replaced with VisualGasic (`.vg`).

## What This Demonstrates

| Feature | VG Approach |
|---|---|
| **CharacterBody2D physics** | `SetVelocity Me, vx, vy` + `MoveAndSlide Me` |
| **Floor detection** | `IsOnFloor(Me)` builtin |
| **Analog input** | `GetAxis("move_left", "move_right")` |
| **_PhysicsProcess** | `Sub _PhysicsProcess(delta As Single)` at 120 Hz |
| **Node references** | `GetNode("Path")` replaces GDScript `@onready $Path` |
| **AnimationPlayer** | `animPlayer.Play("run")` via callv dispatch |
| **Scene instantiation** | `Load("res://player/bullet.tscn").Instantiate()` |
| **Signal handling** | .tscn signal connections → VG Subs (case-insensitive) |
| **Group-based type checks** | `body.IsInGroup("enemies")` replaces `body is Enemy` |
| **Property access** | `Me.velocity.x`, `sprite.scale`, `cam.limit_left` |
| **Godot method calls** | PascalCase auto-converts to snake_case via callv |

## Controls

| Action | Key |
|---|---|
| Move left/right | **A/D** or **Arrow Keys** |
| Jump | **W** or **Up Arrow** |
| Double jump | Jump again in mid-air |
| Shoot | **Space**, **Z**, or **Left Click** |
| Pause | **Escape** |
| Fullscreen | **F11** or **Alt+Enter** |

## Project Structure

```
Platformer_Godot/
├── player/
│   ├── player.vg          ← CharacterBody2D: movement, jumping, shooting
│   ├── gun.vg             ← Marker2D: bullet spawning with cooldown
│   ├── bullet.vg          ← RigidBody2D: collision with enemies
│   ├── player.tscn        ← Player scene (robot spritesheet, animations)
│   ├── bullet.tscn        ← Bullet scene (particles, destroy animation)
│   └── robot.webp         ← 8x8 spritesheet with all animations
├── enemy/
│   ├── enemy.vg           ← CharacterBody2D: patrol AI, destroy()
│   ├── enemy.tscn         ← Enemy scene (bug sprite, particles, sounds)
│   └── enemy.webp         ← Bug enemy spritesheet
├── level/
│   ├── level.vg           ← Node2D: camera limit setup
│   ├── coin.vg            ← Area2D: collectible pickup
│   ├── level.tscn         ← TileMap level (designed in Godot's editor!)
│   ├── coin.tscn          ← Coin scene (spinning animation)
│   ├── tileset.tres       ← TileSet resource with collision shapes
│   ├── background/        ← Parallax scrolling background
│   ├── platforms/         ← Moving platform scenes
│   └── props/             ← Decorative sprites (grass, trees, flowers)
├── gui/
│   ├── pause_menu.vg      ← Control: pause overlay with tween fade
│   ├── coins_counter.vg   ← Panel: coin collection HUD
│   └── theme.tres         ← UI theme
├── game.vg                ← Node: pause/fullscreen via _UnhandledInput
├── game_singleplayer.tscn ← Main game scene
├── music.tscn             ← Background music autoload
├── project.godot          ← Godot project with VG plugin enabled
└── addons/ → symlink      ← Points to VisualGasic plugin
```

## GDScript → VisualGasic Conversion Patterns

### Physics Movement (player.vg)
```vb
' GDScript: velocity.y += gravity * delta
'           velocity.x = move_toward(velocity.x, dir, ACCEL * delta)
'           move_and_slide()

' VisualGasic: Read-Modify-Write pattern
vx = Me.velocity.x
vy = Me.velocity.y
vy = vy + GRAVITY * delta
If vy > TERMINAL_VELOCITY Then vy = TERMINAL_VELOCITY
SetVelocity Me, vx, vy
MoveAndSlide Me
```

### Node References (replacing @onready)
```vb
' GDScript: @onready var anim := $AnimationPlayer as AnimationPlayer
' VisualGasic:
Dim animPlayer As Object
Sub _Ready()
    animPlayer = GetNode("AnimationPlayer")
End Sub
```

### Scene Instantiation (replacing preload)
```vb
' GDScript: const BULLET = preload("res://player/bullet.tscn")
' VisualGasic:
Dim bulletScene As Object
Sub _Ready()
    bulletScene = Load("res://player/bullet.tscn")
End Sub
```

### Type Checking (replacing class_name + `is`)
```vb
' GDScript: if body is Enemy: (body as Enemy).destroy()
' VisualGasic (using Godot groups):
If body.IsInGroup("enemies") Then
    body.destroy()
End If
```

## How It Works

1. **Godot's scene editor** created the level layout — TileMap, enemy placement,
   coin positions, parallax backgrounds, and moving platforms. **No DATA statements.**

2. **VisualGasic scripts** replace GDScript on every node. The `.tscn` files
   reference `.vg` scripts instead of `.gd` files.

3. **CharacterBody2D** physics work via VG builtins: `SetVelocity` writes velocity,
   `MoveAndSlide` performs collision response, `IsOnFloor` checks ground contact.

4. **Signal connections** from `.tscn` files work unchanged — VG uses case-insensitive
   method dispatch, so `_on_body_entered` in the scene finds the matching VG Sub.

5. **Godot methods** called via PascalCase → snake_case auto-conversion.
   `animPlayer.Play("run")` becomes `play("run")` at the engine level.

## Credits

- **Original game**: [Godot 2D Platformer Demo](https://github.com/godotengine/godot-demo-projects/tree/master/2d/platformer) (MIT License)
- **Art & Sound**: Official Godot demo assets by the Godot community
- **VisualGasic conversion**: Demonstrates VB6-style scripting on Godot 4.5+

## See Also

- [**Platformer (DATA-based)**](../Platformer/) — VB6-style platformer using DATA statements
- [**Godot Programming Manual**](../../../docs/GODOT_PROGRAMMING_MANUAL.md) — Full VG ↔ Godot reference
