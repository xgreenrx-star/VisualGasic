# Godot Functions Quick Reference

Essential Godot functions for VisualGasic game development.

---

## 🎮 Top 10 Most Used Functions

### 1. GetNode(path) - Access scene nodes
```vb
Dim player = GetNode("Player")
Dim label = GetNode("UI/ScoreLabel")
```

### 2. IsActionPressed(action) - Check input
```vb
If IsActionPressed("ui_right") Then
    ' Move right
End If
```

### 3. GetDeltaTime() - Frame timing
```vb
Dim delta = GetDeltaTime()
Dim speed = 200 * delta
```

### 4. GetPosition() / SetPosition() - Node position
```vb
Dim pos = GetPosition()
SetPosition(pos.x + 10, pos.y)
```

### 5. IsOnFloor() - Physics check
```vb
If IsOnFloor() Then
    ' Can jump
End If
```

### 6. GetVelocity() / SetVelocity() - Physics movement
```vb
Dim vel = GetVelocity()
SetVelocity(200, vel.y)
```

### 7. EmitSignal(name) - Signal events
```vb
EmitSignal("player_died")
EmitSignal("score_changed", new_score)
```

### 8. LoadScene(path) - Load scenes
```vb
Dim scene = LoadScene("res://enemy.tscn")
Dim instance = scene.instantiate()
```

### 9. Deg2Rad(degrees) - Angle conversion
```vb
SetRotation(Deg2Rad(90))
```

### 10. GetFPS() - Performance monitoring
```vb
Print "FPS: " & GetFPS()
```

---

## 📋 Quick Categories

### Scene/Node
- `GetNode(path)` - Get node by path
- `HasNode(path)` - Check if node exists
- `GetParent()` - Get parent node
- `GetChildren()` - Get all children
- `FindChild(name)` - Find child by name
- `GetTree()` - Get scene tree
- `GetRoot()` - Get root node

### Input
- `IsActionPressed(action)` - Check if action held
- `IsActionJustPressed(action)` - Check if just pressed
- `IsActionJustReleased(action)` - Check if just released
- `GetMousePosition()` - Get mouse position
- `IsKeyPressed(keycode)` - Check specific key
- `IsMouseButtonPressed(button)` - Check mouse button

### Timing
- `GetDeltaTime()` - Get frame delta time
- `GetPhysicsDeltaTime()` - Get physics delta time

### Transform
- `GetPosition()` / `SetPosition(x, y)` - Local position
- `GetGlobalPosition()` / `SetGlobalPosition(x, y)` - Global position
- `GetRotation()` / `SetRotation(angle)` - Rotation in radians
- `GetScale()` / `SetScale(x, y)` - Scale

### Physics (CharacterBody2D)
- `MoveAndSlide()` - Move with collision
- `IsOnFloor()` - Check if on floor
- `IsOnCeiling()` - Check if touching ceiling
- `IsOnWall()` - Check if touching wall
- `GetVelocity()` / `SetVelocity(x, y)` - Get/set velocity

### Scene Management
- `LoadScene(path)` - Load scene resource
- `ChangeScene(path)` - Change to new scene
- `ReloadCurrentScene()` - Reload current scene
- `GetCurrentScene()` - Get current scene node

### Signals
- `EmitSignal(name, args...)` - Emit signal
- `ConnectSignal(signal, method)` - Connect signal
- `DisconnectSignal(signal, method)` - Disconnect signal

### Math
- `Deg2Rad(degrees)` - Convert degrees to radians
- `Rad2Deg(radians)` - Convert radians to degrees
- `Clamp(value, min, max)` - Clamp value
- `Lerp(from, to, weight)` - Linear interpolation
- `MoveToward(from, to, delta)` - Move toward value

### Rendering
- `IsVisible()` / `SetVisible(bool)` - Visibility
- `GetModulate()` / `SetModulate(color)` - Color tint

### Engine
- `GetFPS()` - Current FPS
- `IsEditorHint()` - Check if in editor
- `GetEngineVersion()` - Engine version info
- `QueueFree()` - Queue node for deletion

---

## 🎯 Common Patterns

### Basic Movement
```vb
Sub _process()
    Dim delta = GetDeltaTime()
    Dim speed = 200
    
    If IsActionPressed("ui_right") Then
        Dim pos = GetPosition()
        SetPosition(pos.x + speed * delta, pos.y)
    End If
End Sub
```

### Physics Movement
```vb
Sub _physics_process()
    Dim vel = GetVelocity()
    Dim delta = GetPhysicsDeltaTime()
    
    ' Gravity
    If Not IsOnFloor() Then
        vel.y = vel.y + 980 * delta
    End If
    
    ' Jump
    If IsActionJustPressed("ui_accept") And IsOnFloor() Then
        vel.y = -400
    End If
    
    SetVelocity(vel.x, vel.y)
    MoveAndSlide()
End Sub
```

### Node Access
```vb
' Check before accessing
If HasNode("Enemy") Then
    Dim enemy = GetNode("Enemy")
    enemy.queue_free()
End If

' Find child recursively
Dim sprite = FindChild("Sprite2D", True)
```

### Scene Loading
```vb
Dim scene = LoadScene("res://bullet.tscn")
Dim bullet = scene.instantiate()
bullet.position = GetPosition()
GetParent().add_child(bullet)
```

### Input Handling
```vb
' Continuous input
If IsActionPressed("fire") Then
    Shoot()
End If

' Single press
If IsActionJustPressed("ui_accept") Then
    Jump()
End If

' Mouse position
Dim mouse = GetMousePosition()
LookAt(mouse)
```

### Angle Rotation
```vb
' Set rotation in degrees
SetRotation(Deg2Rad(45))

' Get rotation in degrees
Dim angle = Rad2Deg(GetRotation())
Print "Angle: " & angle
```

### Smooth Movement
```vb
' Lerp position
Dim current = GetPosition()
Dim target = Vector2(100, 100)
Dim smooth = Lerp(current.x, target.x, 0.1)
SetPosition(smooth, current.y)

' Move toward
Dim speed = 0
speed = MoveToward(speed, 100, 5)  ' Accelerate
```

---

## 🔑 Key Codes Reference

```vb
' Letters: 65-90 (A-Z) or 97-122 (a-z)
' Numbers: 48-57 (0-9)
' Space: 32
' Enter: 13
' Escape: 4194305
' Arrow Up: 4194320
' Arrow Down: 4194322
' Arrow Left: 4194319
' Arrow Right: 4194321
```

---

## 🎨 Mouse Buttons

```vb
' Left: 1
' Right: 2
' Middle: 3
' Wheel Up: 4
' Wheel Down: 5
```

---

## ⚙️ Common Actions (project.godot)

```
ui_accept - Space/Enter
ui_select - Space
ui_cancel - Escape
ui_left - Left Arrow/A
ui_right - Right Arrow/D
ui_up - Up Arrow/W
ui_down - Down Arrow/S
```

---

## 💡 Best Practices

1. **Always use GetDeltaTime()** for frame-independent movement
2. **Check HasNode()** before GetNode() to avoid errors
3. **Use IsActionJustPressed()** for single actions (jump, shoot)
4. **Use IsActionPressed()** for continuous actions (move, aim)
5. **Call MoveAndSlide()** after setting velocity
6. **Use Deg2Rad()** when setting rotation angles
7. **Check IsOnFloor()** before allowing jump
8. **Use QueueFree()** instead of immediate deletion
9. **Use signals** for event communication
10. **Profile with GetFPS()** to find performance issues

---

## 🚀 Complete Game Loop Example

```vb
' Player controller script
Dim speed As Single = 200
Dim jump_force As Single = 400
Dim gravity As Single = 980

Sub _ready()
    Print "Player ready!"
    ConnectSignal("body_entered", "OnBodyEntered")
End Sub

Sub _physics_process()
    Dim delta = GetPhysicsDeltaTime()
    Dim vel = GetVelocity()
    
    ' Gravity
    If Not IsOnFloor() Then
        vel.y = vel.y + gravity * delta
    End If
    
    ' Horizontal movement
    vel.x = 0
    If IsActionPressed("ui_right") Then
        vel.x = speed
    ElseIf IsActionPressed("ui_left") Then
        vel.x = -speed
    End If
    
    ' Jump
    If IsActionJustPressed("ui_accept") And IsOnFloor() Then
        vel.y = -jump_force
        EmitSignal("player_jumped")
    End If
    
    ' Apply movement
    SetVelocity(vel.x, vel.y)
    MoveAndSlide()
    
    ' Update UI
    Dim fps = GetFPS()
    Dim pos = GetPosition()
End Sub

Sub OnBodyEntered(body)
    Print "Collided with: " & body.get_name()
End Sub
```

---

For complete documentation, see **GODOT_FUNCTIONS_REFERENCE.md**
