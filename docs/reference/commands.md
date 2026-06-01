# Command Reference

This document lists all built-in commands and functions available in Visual Gasic.

## Control Flow

| Keyword | Description |
| :--- | :--- |
| `If ... Then ... Else ... EndIf` | Conditional execution. |
| `For ... To ... Step ... Next` | Loop with a counter. |
| `While ... Wend` | Loop while a condition is true. |
| `Oscillate var = from To to [Step s] [Cycles n] ... Loop` | Ping-pong loop that bounces a variable back and forth between two values. |
| `Exit Oscillate` | Exits an Oscillate loop immediately. |
| `Continue Oscillate` | Skips to the next iteration of an Oscillate loop. |
| `Repeat N Times [As counter] ... End Repeat` | Executes a block exactly N times. Optional counter variable is 1-based. |
| `Exit Repeat` | Exits a Repeat loop immediately. |
| `Continue Repeat` | Skips to the next iteration of a Repeat loop. |
| `Cycle Through collection For N As var ... End Cycle` | Takes N items from a collection with automatic wrap-around. |
| `Exit Cycle` | Exits a Cycle loop immediately. |
| `Continue Cycle` | Skips to the next iteration of a Cycle loop. |
| `Every N Frames ... End Every` | Conditional guard — executes body once every N frames inside `_Process`. |
| `Every N Seconds ... End Every` | Conditional guard — executes body once every N seconds inside `_Process`. |
| `Tween target.Property To value Over duration` | One-liner animation. Tweens a node property to a target value over time. |
| `Tween target.Property From start To end Over dur [Ease type] [Trans type]` | Full tween with optional starting value, easing, and transition curve. |
| `Sub ... End Sub` | Defines a subroutine (no return value). |
| `Function ... End Function` | Defines a function (returns a value). |
| `Call Name(Args)` | Executes a subroutine. |
| `Exit Sub/Function` | Exits the current scope immediately. |

---

### Repeat N Times

Execute a block exactly N times. Simpler than `For` when you only need repetition.

```vb
' Basic — no counter needed
Repeat 3 Times
    SpawnBullet()
End Repeat

' With a 1-based counter
Repeat 5 Times As i
    Print "Item " & Str(i)   ' 1, 2, 3, 4, 5
End Repeat

' Expression as count
Repeat difficulty * 2 Times
    SpawnEnemy()
End Repeat

' Exit Repeat — break early
Repeat 100 Times As attempt
    If Rnd() > 0.9 Then Exit Repeat
End Repeat

' Continue Repeat — skip iteration
Repeat 10 Times As n
    If n Mod 2 = 0 Then Continue Repeat
    Print n   ' 1, 3, 5, 7, 9
End Repeat
```

### Cycle Through

Take N items from a collection, wrapping around when the end is reached.

```vb
' Cycle a color pattern beyond the array length
Dim colors As Array = ["Red", "Green", "Blue"]
Cycle Through colors For 7 As c
    Print c   ' Red, Green, Blue, Red, Green, Blue, Red
End Cycle

' Round-robin assignment
Dim teams As Array = ["Alpha", "Bravo", "Charlie"]
Cycle Through teams For 9 As team
    AssignPlayer(team)
End Cycle

' Exit Cycle — stop early
Dim notes As Array = ["C", "E", "G"]
Cycle Through notes For 50 As note
    If PlayerPressedStop() Then Exit Cycle
    PlayNote(note)
End Cycle
```

### Every N Frames / Every N Seconds

Conditional guard for `_Process`. Runs its body at a reduced frequency — every N frames or every N seconds — without manual counters.

```vb
Sub _Process(delta As Single)
    ' Run every 3rd frame
    Every 3 Frames
        UpdateParticles()
    End Every

    ' Run every half second
    Every 0.5 Seconds
        CheckSpawns()
    End Every

    ' Multiple guards at different rates
    Every 10 Frames
        UpdateMinimap()
    End Every

    Every 1.0 Seconds
        AutoSave()
    End Every
End Sub
```

### Tween (One-Liner Animation)

Animate a node property to a target value over time. Supports optional starting value, easing, and transition curves.

```vb
' Basic — slide a sprite
Tween sprite.Position To Vector2(400, 300) Over 2.0

' With starting value — slide in from off-screen
Tween panel.Position From Vector2(0, -200) To Vector2(0, 50) Over 0.8

' Fade out
Tween label.Modulate:a To 0.0 Over 0.5 Ease Out Trans Sine

' All options — ease + trans
Tween btn.Position From Vector2(0, 0) To Vector2(200, 100) Over 1.0 Ease InOut Trans Cubic

' VB6 property aliases
Tween ctrl.Left To 100 Over 0.3 Ease Out Trans Back   ' Left → position:x
Tween ctrl.Width To 400 Over 0.5                      ' Width → size:x
```

**Ease types:** `In`, `Out`, `InOut`, `OutIn`
**Trans types:** `Linear`, `Sine`, `Quad`, `Cubic`, `Quart`, `Quint`, `Expo`, `Circ`, `Elastic`, `Bounce`, `Back`, `Spring`

---

## Variable Declarations

| Keyword | Description |
| :--- | :--- |
| `Dim Name [As Type] [= Value]` | Declares a local variable. |
| `Global Name [= Value]` | Declares a global variable accessible across subroutines. |

## Input & Output

| Function | Description |
| :--- | :--- |
| `Print Expression` | Prints output to the Godot console. |
| `Input("Prompt")` | *(Console only)* Reads a line from standard input. |
| `GetKey()` | Returns the scancode of the last key pressed. |
| `IsKeyDown(Params)` | Checks if a specific key is currently held down. |
| `GetMouseX()` / `GetMouseY()` | Global mouse coordinates. |
| `IsMouseButtonDown(Index)` | Checks mouse button state (1=Left, 2=Right). |

## UI & Object Creation

These helper functions create Godot Nodes dynamically and return a reference to them.

| Function | Description |
| :--- | :--- |
| `CreateButton(Text, X, Y, W, H)` | Creates a UI Button. |
| `CreateLabel(Text, X, Y)` | Creates a Text Label. |
| `CreateInput(Text, X, Y, W, H)` | Creates a LineEdit (Input Box). |

## Physics & Interaction

| Function | Description |
| :--- | :--- |
| `IsOnFloor(CharacterBody)` | Returns true if the body is on the floor (requires `MoveAndSlide`). |
| `IsColliding(RayCast)` | Returns true if a raycast is colliding. |
| `GetCollisionCount(Body)` | Returns number of collision contacts. |
| `GetCollisionObject(Body, Idx)` | Gets the specific collider object. |

## Math & Utility

| Function | Description |
| :--- | :--- |
| `Abs(Num)` | Absolute value. |
| `Sin(Rad)`, `Cos(Rad)` | Trigonometric functions. |
| `Sqrt(Num)` | Square root. |
| `Rnd()` | Returns a random float between 0.0 and 1.0. |
| `Int(Num)` | Truncates decimal part. |
| `Timer()` | Returns time since startup (milliseconds). |
| `Sleep(Ms)` | Pauses execution. |

## Godot Namespace Wrappers (v4.x–v5.1)

High-level dotted-call APIs for Godot subsystems. Each row links to the full
signatures in the
[Language Reference](../VisualGasic_Language_Reference.md#v4xv51-godot-namespace-wrappers).

| Namespace | Purpose | Selected verbs |
| :--- | :--- | :--- |
| `Camera.*` | Camera2D/3D control | `Position`, `Zoom`, `Rotation`, `FOV`, `Follow`, `Shake`, `Limits`, `MakeCurrent`, `PanTo`, `Bounce`, `FlashColor` |
| `Sound.*` | Polyphonic audio | `Play`, `Stop`, `Pause`, `Resume`, `Volume`, `Pitch`, `Seek`, `Position`, `IsPlaying` |
| `Speaker.*` | Audio buses | `Count`, `Exists`, `Name`, `Volume`, `Mute`, `IsMuted`, `Solo` |
| `SoundGen.*` | Real-time PCM synthesis | `Open`, `Close`, `Available`, `PushMono`, `PushStereo` |
| `Animation.*` | AnimationPlayer | `Play`, `Stop`, `Pause`, `Resume`, `Seek`, `Speed`, `Current`, `IsPlaying`, `Length`, `Loop` |
| `Physics.*` | Rigid/Character bodies | `Gravity`, `GravityV2`, `GravityV3`, `Force`, `Impulse`, `Torque`, `Bounce`, `Ray` |
| `Ray.*` | RayCast2D/3D | `Cast2D`, `Cast3D`, `Target`, `Enable`, `ForceUpdate`, `Hit`, `Collider`, `Point`, `Normal` |
| `Cell.*` | TileMap | `Get`, `Set`, `Clear`, `ClearAll`, `Used` |
| `Nav.*` | NavigationAgent | `SetTarget`, `NextPos`, `Path`, `Distance`, `Reached` |
| `Screen.*` | Window/display | `Width`, `Height`, `DPI`, `Orientation`, `Fullscreen`, `IsFullscreen`, `KeepOn` |
| `Joypad.*` | Gamepad input | `Connected`, `IsConnected`, `Name`, `Button`, `Axis`, `Stick` |
| `Sensor.*` | Phone sensors | `Accel`, `Gravity`, `Gyro`, `Magnet`, `Magnetometer`, `Tilt`, `Units` |
| `Permission.*` | OS permissions | `Has`, `Request`, `All` |
| `GPS.*` | Location (Android) | `Lat`, `Lng`, `Alt`, `Speed`, `Accuracy` |
| `Steps.*` | Step counter (Android) | `Today`, `Total`, `Reset` |
| `Crypto.*` | Hashing & encoding | `MD5`, `SHA1`, `SHA256`, `HMAC`, `Hex`, `FromHex`, `Base64`, `Base64Encode`, `Base64Decode`, `RandomBytes` |
| `Theme.*` | Control theming | `Color`, `Constant`, `Font`, `SetColor`, `SetConstant`, `SetFont`, `SetFontSize`, `SetStyle`, `Get`, `Set` |
| `Shader.*` / `Material.*` | Shader materials | `Material.New`, `Material.SetShader`, `Shader.Param`, `Shader.GetParam`, `Shader.Set`, `Shader.Get` |
| `Skeleton.*` / `Bone.*` | Skeletal animation | `Count`, `Name`, `Reset`, `Find`, `Pos`, `Rot`, `Scale`, `SetPos`, `SetRot`, `SetScale`, `LookAt` |
| `Video.*` | VideoStreamPlayer | `Play`, `Stop`, `Pause`, `Resume`, `Seek`, `Position`, `Length`, `Volume`, `IsPlaying` |
| `JS.*` | JS interop (Web export) | `Eval`, `Call`, `Get` |

Globals: `Push`, `Pull`, `Spin` (physics aliases), `Vibrate ms` (haptics),
`Quaternion`/`Basis`/`Transform2D`/`Transform3D`/`Plane`/`AABB` (constructors),
`NewRNG`, `NewNoise`, `NewCurve`, `Slerp`, `ColorFromHSV`, `ColorToHSV`,
`Lighten`, `Darken`.

Auto-wired subs: `Permission_Granted(name)`, `Permission_Denied(name)`,
`GPS_Updated(lat, lng)`, `Steps_Detected(count)`.
