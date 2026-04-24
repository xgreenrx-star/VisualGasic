# Building a 2D Platformer in VisualGasic

This tutorial walks you through the architecture of the **Pixel Platformer** demo —
a complete 2D platformer with gravity, jumping, enemies, coins, and tile-based levels,
all written in VisualGasic for Godot 4.6.1+.

> **Prerequisites:** You should be familiar with basic VisualGasic syntax
> (`Dim`, `Sub`, `Function`, `For`/`Next`, `Select Case`) and have the VisualGasic
> addon installed. See [Your First 2D Game](your_first_2d_game.md) if you're
> completely new.

> **Demo location:** `demos/2D_Games/Platformer/`

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Godot Integration Points](#2-godot-integration-points)
3. [Physics: Gravity and Jumping](#3-physics-gravity-and-jumping)
4. [Tile-Based Levels with DATA Statements](#4-tile-based-levels-with-data-statements)
5. [Collision Detection](#5-collision-detection)
6. [Enemies and AI](#6-enemies-and-ai)
7. [Camera System](#7-camera-system)
8. [Rendering with _Draw()](#8-rendering-with-_draw)
9. [Game State Machine](#9-game-state-machine)
10. [Advanced Techniques](#10-advanced-techniques)

---

## 1. Project Structure

The platformer follows the same single-file pattern as the other VisualGasic demos:

```
demos/2D_Games/Platformer/
  platformer.vg          ← All game logic in one VB6-style module
  main.tscn              ← Scene: single Node2D with the .vg script
  project.godot          ← Window size, input bindings, plugin config
  addons/visual_gasic/   ← Symlink to the VisualGasic runtime
  README.md
```

The `.tscn` file is minimal — just a `Node2D` with the script attached:

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://platformer.vg" id="1_platformer"]
[node name="Main" type="Node2D"]
script = ExtResource("1_platformer")
```

This mirrors classic VB6 development: one Form with all drawing and logic in a
single module. Godot provides the window and frame timing; VisualGasic handles
everything else.

---

## 2. Godot Integration Points

VisualGasic integrates with Godot through three key virtual methods:

### `_Ready()` — Initialization

Called once when the node enters the scene tree. Use it to set up game state:

```basic
Sub _Ready()
    playerWidth = 24
    playerHeight = 32
    totalLevels = 3
    InitClouds
    gameState = "TITLE"
End Sub
```

### `_Process(delta)` — Frame Update

Called every frame with the time elapsed since the last frame. All game logic
(physics, input, AI) goes here:

```basic
Sub _Process(delta As Single)
    Select Case gameState
        Case "PLAYING"
            UpdatePlayer delta
            UpdateEnemies delta
            UpdateCamera delta
            CheckCoinPickups
        Case "TITLE"
            If Input.IsActionJustPressed("jump") Then
                StartNewGame
            End If
    End Select
End Sub
```

### `_Draw()` — Rendering

Called every frame after `_Process`. All visual output uses Godot's CanvasItem
draw API through VisualGasic wrappers:

```basic
Sub _Draw()
    DrawRect 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, Color("#4488CC")
    DrawString "SCORE: " & Str(score), 10, 10, Color.White, 20
End Sub
```

### Input System

The platformer reads Godot's Input Map actions defined in `project.godot`:

```basic
' Continuous press (held down) — for movement
If Input.IsActionPressed("move_left") Then
    playerVX = -WALK_SPEED
End If

' Just pressed (single frame) — for jumping
If Input.IsActionJustPressed("jump") Then
    playerVY = JUMP_VELOCITY
End If

' Just released — for variable jump height
If Input.IsActionJustReleased("jump") And playerVY < 0 Then
    playerVY = playerVY * 0.5  ' Cut upward momentum
End If
```

---

## 3. Physics: Gravity and Jumping

The platformer implements manual physics — no `CharacterBody2D` required. This is
the same approach used in classic VB6 game development.

### Constants

```basic
Const GRAVITY As Single = 1800.0        ' Acceleration (px/sec²)
Const JUMP_VELOCITY As Single = -620.0  ' Negative = upward
Const WALK_SPEED As Single = 250.0      ' Horizontal (px/sec)
Const TERMINAL_VELOCITY As Single = 900.0
```

### The Physics Loop

Each frame:
1. Read input → set horizontal velocity
2. Apply gravity → increase vertical velocity
3. Move horizontally → resolve tile collisions on X axis
4. Move vertically → resolve tile collisions on Y axis

```basic
Sub UpdatePlayer(delta As Single)
    ' 1. Input
    If Input.IsActionPressed("move_right") Then
        playerVX = WALK_SPEED
        playerFacing = 1
    End If

    ' 2. Gravity
    playerVY = playerVY + GRAVITY * delta
    If playerVY > TERMINAL_VELOCITY Then playerVY = TERMINAL_VELOCITY

    ' 3. Move and collide (separate axes)
    playerX = playerX + playerVX * delta
    ResolveHorizontalCollision

    playerY = playerY + playerVY * delta
    ResolveVerticalCollision
End Sub
```

### Why Separate Axes?

Moving along X and Y separately and resolving collisions after each prevents the
player from clipping through corners. This is the standard approach in tile-based
platformers.

### Coyote Time and Jump Buffering

Two quality-of-life features that make jumping feel responsive:

- **Coyote time**: After walking off an edge, the player can still jump for a
  brief window (0.08 seconds). This forgives slightly late jumps.
- **Jump buffering**: If the player presses jump slightly before landing (0.1
  seconds), the jump executes on the frame they touch ground.

```basic
Const COYOTE_TIME As Single = 0.08
Const JUMP_BUFFER As Single = 0.1

' Track timers
If playerOnGround Then
    coyoteTimer = COYOTE_TIME
Else
    coyoteTimer = coyoteTimer - delta
End If

If Input.IsActionJustPressed("jump") Then
    jumpBufferTimer = JUMP_BUFFER
End If

' Execute jump when both conditions align
If jumpBufferTimer > 0 And coyoteTimer > 0 Then
    playerVY = JUMP_VELOCITY
    coyoteTimer = 0
    jumpBufferTimer = 0
End If
```

---

## 4. Tile-Based Levels with DATA Statements

Levels are defined as ASCII art using VisualGasic's `DATA` / `Read` / `Restore`
statements — a classic BASIC pattern for embedding static data.

### Level Format

Each level starts with width and height, followed by one string per row:

```basic
Level1Data:
Data 60, 18
Data ".......................................................#####"
Data "..............C..C..C...............######.................."
Data "P.........C....######...=====.............................."
Data "###############SSS#########SSS######SSS######SS#########SS##"
```

### Tile Legend

| Char | Meaning |
|------|---------|
| `.`  | Empty air |
| `#`  | Solid ground |
| `=`  | Brick platform |
| `S`  | Spikes (kill) |
| `P`  | Player start |
| `C`  | Coin |
| `E`  | Enemy |
| `F`  | Finish flag |

### Loading a Level

```basic
Sub LoadLevel(levelNum As Integer)
    Select Case levelNum
        Case 1: Restore Level1Data
        Case 2: Restore Level2Data
        Case 3: Restore Level3Data
    End Select

    Read levelWidth
    Read levelHeight

    Dim row As Integer, col As Integer, rowStr As String
    For row = 0 To levelHeight - 1
        Read rowStr
        For col = 0 To levelWidth - 1
            Dim ch As String = Mid(rowStr, col + 1, 1)

            Select Case ch
                Case "P"
                    playerX = col * TILE_SIZE
                    playerY = row * TILE_SIZE
                    levelGrid(col, row) = "."

                Case "C"
                    coinX(coinCount) = col * TILE_SIZE + 16
                    coinY(coinCount) = row * TILE_SIZE + 16
                    coinActive(coinCount) = True
                    coinCount = coinCount + 1
                    levelGrid(col, row) = "."

                Case Else
                    levelGrid(col, row) = ch
            End Select
        Next
    Next
End Sub
```

The `Restore` statement sets the `Read` cursor to a label, and `Read` consumes
values sequentially — exactly like QuickBASIC and early VB. This lets you design
levels as readable text right in your source code.

---

## 5. Collision Detection

### Tile Collision

The `IsSolidTile()` function checks if a grid cell is walkable:

```basic
Function IsSolidTile(col As Integer, row As Integer) As Boolean
    If col < 0 Or col >= levelWidth Or row < 0 Or row >= levelHeight Then
        IsSolidTile = False
        Return
    End If
    Dim tile As String = levelGrid(col, row)
    IsSolidTile = (tile = "#" Or tile = "=" Or tile = "^")
End Function
```

Collision resolution checks every tile the player's bounding box overlaps:

```basic
Sub ResolveVerticalCollision()
    playerOnGround = False
    Dim tileLeft As Integer = Int(playerX / TILE_SIZE)
    Dim tileRight As Integer = Int((playerX + playerWidth - 1) / TILE_SIZE)
    Dim tileTop As Integer = Int(playerY / TILE_SIZE)
    Dim tileBottom As Integer = Int((playerY + playerHeight - 1) / TILE_SIZE)

    For row = tileTop To tileBottom
        For col = tileLeft To tileRight
            If IsSolidTile(col, row) Then
                If playerVY > 0 Then
                    playerY = row * TILE_SIZE - playerHeight  ' Land on top
                    playerVY = 0
                    playerOnGround = True
                ElseIf playerVY < 0 Then
                    playerY = (row + 1) * TILE_SIZE  ' Bonk head
                    playerVY = 0
                End If
            End If
        Next
    Next
End Sub
```

### Entity Collision (AABB)

For player-vs-enemy, we use axis-aligned bounding box overlap:

```basic
Function RectsOverlap(x1, y1, w1, h1, x2, y2, w2, h2) As Boolean
    RectsOverlap = Not (x1+w1 <= x2 Or x2+w2 <= x1 Or y1+h1 <= y2 Or y2+h2 <= y1)
End Function
```

---

## 6. Enemies and AI

Enemies patrol horizontally. They reverse direction when hitting a wall or reaching
a platform edge (so they don't walk off cliffs):

```basic
Sub UpdateEnemies(delta As Single)
    For i = 0 To MAX_ENEMIES - 1
        If enemyActive(i) Then
            enemyX(i) = enemyX(i) + enemyVX(i) * delta

            ' Check for wall ahead
            Dim checkCol As Integer = Int((enemyX(i) + enemyWidth) / TILE_SIZE)
            If IsSolidTile(checkCol, enemyRow) Then
                enemyVX(i) = -enemyVX(i)  ' Reverse direction
            End If

            ' Check for floor edge (don't walk off platforms)
            If Not IsSolidTile(checkCol, footRow) Then
                enemyVX(i) = -enemyVX(i)  ' Turn around
            End If
        End If
    Next
End Sub
```

### Stomp Mechanic

When the player lands on an enemy from above, the enemy is destroyed and the
player bounces:

```basic
If playerVY > 0 And playerBottom < enemyCenter Then
    ' Stomp! Destroy enemy, bounce player
    enemyActive(i) = False
    playerVY = JUMP_VELOCITY * 0.6
    playerScore = playerScore + 200
End If
```

---

## 7. Camera System

The camera smoothly follows the player using linear interpolation (lerp):

```basic
Sub UpdateCamera(delta As Single)
    Dim targetX As Single = playerX - SCREEN_WIDTH / 2
    Dim targetY As Single = playerY - SCREEN_HEIGHT / 2

    ' Lead camera in movement direction
    targetX = targetX + playerVX * 0.15

    ' Smooth follow (lerp)
    cameraX = cameraX + (targetX - cameraX) * 5 * delta
    cameraY = cameraY + (targetY - cameraY) * 5 * delta

    ClampCamera  ' Keep within level bounds
End Sub
```

All drawing subtracts `cameraX`/`cameraY` to convert world coordinates to screen
coordinates:

```basic
Dim screenX As Single = worldX - cameraX
Dim screenY As Single = worldY - cameraY
DrawRect screenX, screenY, width, height, color
```

---

## 8. Rendering with _Draw()

The entire game is rendered with three VisualGasic draw functions:

| Function | Godot Equivalent | Usage |
|----------|-----------------|-------|
| `DrawRect x, y, w, h, color` | `draw_rect()` | Tiles, platforms, HUD bars |
| `DrawCircle x, y, radius, color` | `draw_circle()` | Coins, particles, clouds |
| `DrawString text, x, y, color, size` | `draw_string()` | Score, messages, labels |

### Tile Map Culling

Only tiles visible on screen are drawn — this is essential for performance:

```basic
Dim startCol As Integer = Int(cameraX / TILE_SIZE) - 1
Dim endCol As Integer = Int((cameraX + SCREEN_WIDTH) / TILE_SIZE) + 1

For row = startRow To endRow
    For col = startCol To endCol
        ' Draw only visible tiles
    Next
Next
```

### Player Character

The player is drawn entirely from primitives — no sprite images needed:

```basic
Sub DrawPlayerSprite(x, y, facing, anim)
    DrawRect x+4, y+8, 16, 16, Color("#3366CC")    ' Blue torso
    DrawCircle x+12, y+6, 8, Color("#FFCC88")       ' Head
    DrawRect x+3, y-1, 18, 5, Color("#CC3333")      ' Red cap
    ' Animated legs
    Dim legOffset As Single = Sin(anim) * 4
    DrawRect x+5, y+24, 5, 8+legOffset, Color("#3355AA")
    DrawRect x+14, y+24, 5, 8-legOffset, Color("#3355AA")
End Sub
```

---

## 9. Game State Machine

The game uses a string-based state machine in `_Process` and `_Draw`:

```basic
Dim gameState As String  ' "TITLE", "PLAYING", "DEAD", "GAMEOVER", "VICTORY"

Sub _Process(delta As Single)
    Select Case gameState
        Case "TITLE"
            ' Wait for start input
        Case "PLAYING"
            UpdatePlayer delta
            UpdateEnemies delta
            ' ...
        Case "DEAD"
            deathTimer = deathTimer - delta
            If deathTimer <= 0 Then
                If playerLives > 0 Then
                    LoadLevel currentLevel
                    gameState = "PLAYING"
                Else
                    gameState = "GAMEOVER"
                End If
            End If
    End Select
End Sub
```

Each state has its own draw routine:

```basic
Sub _Draw()
    Select Case gameState
        Case "TITLE":   DrawTitleScreen
        Case "PLAYING": DrawGame: DrawHUD
        Case "DEAD":    DrawGame: DrawDeathOverlay
        Case "GAMEOVER": DrawGameOverScreen
        Case "VICTORY": DrawVictoryScreen
    End Select
End Sub
```

---

## 10. Advanced Techniques

### Particle Effects

Particles use the same object-pool pattern as the Space Shooter demo:

```basic
Sub SpawnParticleBurst(x, y, col, count)
    For i = 0 To MAX_PARTICLES - 1
        If partLife(i) <= 0 Then  ' Find dead slot
            partX(i) = x
            partY(i) = y
            partVX(i) = (Rnd() - 0.5) * 250
            partVY(i) = (Rnd() - 0.5) * 250 - 100
            partLife(i) = 0.3 + Rnd() * 0.5
            partColor(i) = col
        End If
    Next
End Sub
```

### Creating Your Own Levels

To add a new level:

1. Add a new `DATA` label with the level grid:
```basic
Level4Data:
Data 40, 15
Data "........................................"
Data "P........C..C..C...................F..."
' ... more rows
Data "########################################"
```

2. Add a case to `LoadLevel`:
```basic
Case 4: Restore Level4Data
```

3. Update `totalLevels`:
```basic
totalLevels = 4
```

### Comparison with GDScript

Here's the same player physics in GDScript vs VisualGasic:

**GDScript (official demo):**
```gdscript
func _physics_process(delta: float) -> void:
    velocity.y = minf(TERMINAL_VELOCITY, velocity.y + gravity * delta)
    var direction := Input.get_axis("move_left", "move_right") * WALK_SPEED
    velocity.x = move_toward(velocity.x, direction, ACCELERATION_SPEED * delta)
    move_and_slide()
```

**VisualGasic (this demo):**
```basic
Sub _Process(delta As Single)
    playerVY = playerVY + GRAVITY * delta
    If playerVY > TERMINAL_VELOCITY Then playerVY = TERMINAL_VELOCITY
    If Input.IsActionPressed("move_right") Then playerVX = WALK_SPEED
    playerX = playerX + playerVX * delta
    ResolveHorizontalCollision
    playerY = playerY + playerVY * delta
    ResolveVerticalCollision
End Sub
```

Both achieve the same result — VisualGasic uses the familiar VB6 approach of
explicit variables and manual collision, while GDScript uses Godot's built-in
`CharacterBody2D.move_and_slide()`.

---

## Next Steps

- **Add sound effects**: Use `AudioStreamPlayer` nodes and trigger them from VG.
- **Add sprite images**: Replace primitive drawing with `Sprite2D` nodes.
- **Add more levels**: Use the `DATA` statement pattern — it's infinitely extensible.
- **Try the other demos**: See `Space_Shooter` (Parallel For), `Snake` (grid-based),
  `Pong` (two-player), and `Calculator` (UI/input handling).
