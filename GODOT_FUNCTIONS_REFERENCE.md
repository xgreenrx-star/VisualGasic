# Godot-Specific Builtin Functions Reference

This document provides a complete reference for all Godot-specific builtin functions available in VisualGasic. These functions provide direct integration with Godot 4 engine features for game development.

---

## Table of Contents

1. [Scene/Node Management](#scenenode-management)
2. [Input Functions](#input-functions)
3. [Timing Functions](#timing-functions)
4. [Memory/Lifecycle](#memorylifecycle)
5. [Scene Loading](#scene-loading)
6. [Transform/Position](#transformposition)
7. [Physics Functions](#physics-functions)
8. [Signals](#signals)
9. [Engine Info](#engine-info)
10. [Math Helpers](#math-helpers)
11. [Rendering](#rendering)

---

## Scene/Node Management

### GetNode(path As String) As Node
Gets a node by path relative to the script owner.

**Syntax:**
```vb
Dim node = GetNode(path)
```

**Example:**
```vb
Dim player = GetNode("Player")
Dim health_label = GetNode("UI/HealthLabel")
Dim sibling = GetNode("../OtherNode")
```

---

### HasNode(path As String) As Boolean
Checks if a node exists at the specified path.

**Syntax:**
```vb
Dim exists = HasNode(path)
```

**Example:**
```vb
If HasNode("Enemy") Then
    Dim enemy = GetNode("Enemy")
    Print "Enemy found"
End If
```

---

### GetParent() As Node
Returns the parent node of the script owner.

**Syntax:**
```vb
Dim parent = GetParent()
```

**Example:**
```vb
Dim parent = GetParent()
If Not IsNull(parent) Then
    Print "Parent: " & parent.get_name()
End If
```

---

### GetChildren() As Array
Returns an array of all child nodes.

**Syntax:**
```vb
Dim children = GetChildren()
```

**Example:**
```vb
Dim children = GetChildren()
Print "Number of children: " & UBound(children)

For i = 0 To UBound(children)
    Print "Child " & i & ": " & children[i].get_name()
Next i
```

---

### FindChild(name As String, [recursive As Boolean = True]) As Node
Finds a child node by name. Searches recursively by default.

**Syntax:**
```vb
Dim child = FindChild(name, recursive)
```

**Example:**
```vb
' Find in immediate children only
Dim sprite = FindChild("Sprite", False)

' Find recursively (default)
Dim deep_child = FindChild("DeepNode", True)
```

---

### GetTree() As SceneTree
Returns the SceneTree object.

**Syntax:**
```vb
Dim tree = GetTree()
```

**Example:**
```vb
Dim tree = GetTree()
If Not IsNull(tree) Then
    Print "Scene tree available"
End If
```

---

### GetRoot() As Node
Returns the root node of the scene tree.

**Syntax:**
```vb
Dim root = GetRoot()
```

**Example:**
```vb
Dim root = GetRoot()
Print "Root node: " & root.get_name()
```

---

## Input Functions

### IsActionPressed(action As String) As Boolean
Returns true if the action is currently pressed.

**Syntax:**
```vb
Dim pressed = IsActionPressed(action_name)
```

**Example:**
```vb
If IsActionPressed("ui_right") Then
    ' Move right
    Dim pos = GetPosition()
    SetPosition(pos.x + 5, pos.y)
End If
```

---

### IsActionJustPressed(action As String) As Boolean
Returns true if the action was just pressed this frame.

**Syntax:**
```vb
Dim just_pressed = IsActionJustPressed(action_name)
```

**Example:**
```vb
If IsActionJustPressed("ui_accept") Then
    Print "Jump!"
    EmitSignal("player_jumped")
End If
```

---

### IsActionJustReleased(action As String) As Boolean
Returns true if the action was just released this frame.

**Syntax:**
```vb
Dim just_released = IsActionJustReleased(action_name)
```

**Example:**
```vb
If IsActionJustReleased("fire") Then
    Print "Fire button released"
End If
```

---

### GetActionStrength(action As String) As Float
Returns the strength of the action (0.0 to 1.0).

**Syntax:**
```vb
Dim strength = GetActionStrength(action_name)
```

**Example:**
```vb
Dim throttle = GetActionStrength("accelerate")
Dim speed = throttle * 500
```

---

### IsKeyPressed(keycode As Integer) As Boolean
Returns true if the specified key is pressed.

**Syntax:**
```vb
Dim pressed = IsKeyPressed(keycode)
```

**Example:**
```vb
' Check if Space (32) is pressed
If IsKeyPressed(32) Then
    Print "Space is pressed"
End If

' Check if Escape (4194305) is pressed
If IsKeyPressed(4194305) Then
    Print "Escape pressed"
End If
```

**Common Key Codes:**
- Space: 32
- Enter: 13
- Escape: 4194305
- Arrow Up: 4194320
- Arrow Down: 4194322
- Arrow Left: 4194319
- Arrow Right: 4194321

---

### IsMouseButtonPressed(button As Integer) As Boolean
Returns true if the specified mouse button is pressed.

**Syntax:**
```vb
Dim pressed = IsMouseButtonPressed(button)
```

**Example:**
```vb
' Left mouse button (1)
If IsMouseButtonPressed(1) Then
    Print "Left mouse clicked"
End If

' Right mouse button (2)
If IsMouseButtonPressed(2) Then
    Print "Right mouse clicked"
End If
```

**Mouse Button Values:**
- Left: 1
- Right: 2
- Middle: 3
- Wheel Up: 4
- Wheel Down: 5

---

### GetMousePosition() As Vector2
Returns the mouse position in viewport coordinates.

**Syntax:**
```vb
Dim pos = GetMousePosition()
```

**Example:**
```vb
Dim mouse_pos = GetMousePosition()
Print "Mouse X: " & mouse_pos.x & ", Y: " & mouse_pos.y
```

---

### GetLastMouseVelocity() As Vector2
Returns the velocity of the last mouse movement.

**Syntax:**
```vb
Dim velocity = GetLastMouseVelocity()
```

**Example:**
```vb
Dim vel = GetLastMouseVelocity()
If vel.length() > 100 Then
    Print "Fast mouse movement!"
End If
```

---

## Timing Functions

### GetDeltaTime() As Float
Returns the time elapsed since the last frame (in seconds).

**Syntax:**
```vb
Dim delta = GetDeltaTime()
```

**Example:**
```vb
Sub _process()
    Dim delta = GetDeltaTime()
    Dim pos = GetPosition()
    Dim speed = 200
    
    ' Frame-independent movement
    SetPosition(pos.x + speed * delta, pos.y)
End Sub
```

---

### GetPhysicsDeltaTime() As Float
Returns the physics time step (in seconds).

**Syntax:**
```vb
Dim delta = GetPhysicsDeltaTime()
```

**Example:**
```vb
Sub _physics_process()
    Dim delta = GetPhysicsDeltaTime()
    Dim vel = GetVelocity()
    
    ' Apply gravity
    vel.y = vel.y + 980 * delta
    SetVelocity(vel.x, vel.y)
End Sub
```

---

## Memory/Lifecycle

### QueueFree()
Queues the current node for deletion at the end of the frame.

**Syntax:**
```vb
QueueFree()
```

**Example:**
```vb
Sub OnDeath()
    Print "Entity destroyed"
    QueueFree()
End Sub
```

**Warning:** Do not access the node after calling QueueFree()!

---

## Scene Loading

### LoadScene(path As String) As PackedScene
Loads a scene from the specified path.

**Syntax:**
```vb
Dim scene = LoadScene(path)
```

**Example:**
```vb
Dim enemy_scene = LoadScene("res://enemies/enemy.tscn")
If Not IsNull(enemy_scene) Then
    Dim enemy = enemy_scene.instantiate()
    GetTree().get_root().add_child(enemy)
End If
```

---

### ChangeScene(path As String) As Integer
Changes to a different scene. Returns error code (0 = OK).

**Syntax:**
```vb
Dim result = ChangeScene(path)
```

**Example:**
```vb
Sub GoToMainMenu()
    Dim result = ChangeScene("res://menus/main_menu.tscn")
    If result = 0 Then
        Print "Scene changed successfully"
    Else
        Print "Error changing scene: " & result
    End If
End Sub
```

---

### ReloadCurrentScene() As Integer
Reloads the current scene. Returns error code (0 = OK).

**Syntax:**
```vb
Dim result = ReloadCurrentScene()
```

**Example:**
```vb
Sub RestartLevel()
    Dim result = ReloadCurrentScene()
    If result = 0 Then
        Print "Level restarted"
    End If
End Sub
```

---

### GetCurrentScene() As Node
Returns the current scene node.

**Syntax:**
```vb
Dim scene = GetCurrentScene()
```

**Example:**
```vb
Dim scene = GetCurrentScene()
Print "Current scene: " & scene.get_name()
```

---

## Transform/Position

These functions work with Node2D and derived types (Sprite2D, CharacterBody2D, etc.).

### GetPosition() As Vector2
Returns the local position of the node.

**Syntax:**
```vb
Dim pos = GetPosition()
```

**Example:**
```vb
Dim pos = GetPosition()
Print "Position: (" & pos.x & ", " & pos.y & ")"
```

---

### SetPosition(x As Float, y As Float)
### SetPosition(pos As Vector2)
Sets the local position of the node.

**Syntax:**
```vb
SetPosition(x, y)
SetPosition(vector)
```

**Example:**
```vb
' Set position with coordinates
SetPosition(100, 200)

' Set position with vector
Dim new_pos = Vector2(150, 250)
SetPosition(new_pos)
```

---

### GetGlobalPosition() As Vector2
Returns the global position of the node.

**Syntax:**
```vb
Dim pos = GetGlobalPosition()
```

**Example:**
```vb
Dim global_pos = GetGlobalPosition()
Print "Global position: " & global_pos
```

---

### SetGlobalPosition(x As Float, y As Float)
### SetGlobalPosition(pos As Vector2)
Sets the global position of the node.

**Syntax:**
```vb
SetGlobalPosition(x, y)
SetGlobalPosition(vector)
```

**Example:**
```vb
SetGlobalPosition(500, 300)
```

---

### GetRotation() As Float
Returns the rotation in radians.

**Syntax:**
```vb
Dim rotation = GetRotation()
```

**Example:**
```vb
Dim rot = GetRotation()
Dim degrees = Rad2Deg(rot)
Print "Rotation: " & degrees & " degrees"
```

---

### SetRotation(angle As Float)
Sets the rotation in radians.

**Syntax:**
```vb
SetRotation(angle)
```

**Example:**
```vb
' Set to 45 degrees
SetRotation(Deg2Rad(45))

' Set to 90 degrees
SetRotation(1.5708)
```

---

### GetScale() As Vector2
Returns the scale of the node.

**Syntax:**
```vb
Dim scale = GetScale()
```

**Example:**
```vb
Dim scale = GetScale()
Print "Scale: (" & scale.x & ", " & scale.y & ")"
```

---

### SetScale(x As Float, y As Float)
### SetScale(scale As Vector2)
Sets the scale of the node.

**Syntax:**
```vb
SetScale(x, y)
SetScale(vector)
```

**Example:**
```vb
' Double the size
SetScale(2, 2)

' Flip horizontally
SetScale(-1, 1)
```

---

## Physics Functions

These functions work with CharacterBody2D and other physics bodies.

### MoveAndSlide() As Boolean
Moves the body using current velocity with collision detection.

**Syntax:**
```vb
Dim moved = MoveAndSlide()
```

**Example:**
```vb
Sub _physics_process()
    Dim vel = GetVelocity()
    vel.x = GetActionStrength("ui_right") * 200
    SetVelocity(vel.x, vel.y)
    MoveAndSlide()
End Sub
```

---

### MoveAndCollide(velocity As Vector2) As KinematicCollision2D
Moves the body and returns collision information.

**Syntax:**
```vb
Dim collision = MoveAndCollide(velocity)
```

**Example:**
```vb
Dim delta = GetPhysicsDeltaTime()
Dim vel = Vector2(100, 0)
Dim collision = MoveAndCollide(vel * delta)
If Not IsNull(collision) Then
    Print "Collided with: " & collision.get_collider().get_name()
End If
```

---

### IsOnFloor() As Boolean
Returns true if the body is on the floor.

**Syntax:**
```vb
Dim on_floor = IsOnFloor()
```

**Example:**
```vb
If IsOnFloor() Then
    ' Can jump
    If IsActionJustPressed("ui_accept") Then
        Dim vel = GetVelocity()
        vel.y = -400
        SetVelocity(vel.x, vel.y)
    End If
End If
```

---

### IsOnCeiling() As Boolean
Returns true if the body is touching the ceiling.

**Syntax:**
```vb
Dim on_ceiling = IsOnCeiling()
```

**Example:**
```vb
If IsOnCeiling() Then
    Print "Hit the ceiling!"
    Dim vel = GetVelocity()
    vel.y = 0  ' Stop upward movement
    SetVelocity(vel.x, vel.y)
End If
```

---

### IsOnWall() As Boolean
Returns true if the body is touching a wall.

**Syntax:**
```vb
Dim on_wall = IsOnWall()
```

**Example:**
```vb
If IsOnWall() Then
    ' Wall jump
    If IsActionJustPressed("ui_accept") Then
        Dim vel = GetVelocity()
        vel.x = -vel.x  ' Bounce off wall
        vel.y = -300
        SetVelocity(vel.x, vel.y)
    End If
End If
```

---

### GetVelocity() As Vector2
Returns the current velocity (CharacterBody2D).

**Syntax:**
```vb
Dim vel = GetVelocity()
```

**Example:**
```vb
Dim vel = GetVelocity()
Print "Speed: " & vel.length()
```

---

### SetVelocity(x As Float, y As Float)
### SetVelocity(velocity As Vector2)
Sets the velocity (CharacterBody2D).

**Syntax:**
```vb
SetVelocity(x, y)
SetVelocity(vector)
```

**Example:**
```vb
' Stop all movement
SetVelocity(0, 0)

' Set horizontal movement
Dim vel = GetVelocity()
SetVelocity(200, vel.y)
```

---

## Signals

### EmitSignal(signal_name As String, [args...])
Emits a signal with optional arguments.

**Syntax:**
```vb
EmitSignal(signal_name, arg1, arg2, ...)
```

**Example:**
```vb
' Emit signal without arguments
EmitSignal("player_died")

' Emit signal with arguments
EmitSignal("score_changed", 100, "Player1")
EmitSignal("item_collected", "gold_coin", 5)
```

---

### ConnectSignal(signal_name As String, method_name As String) As Integer
Connects a signal to a method. Returns error code (0 = OK).

**Syntax:**
```vb
Dim result = ConnectSignal(signal_name, method_name)
```

**Example:**
```vb
Sub _ready()
    ' Connect ready signal to OnReady method
    ConnectSignal("ready", "OnReady")
End Sub

Sub OnReady()
    Print "Node is ready!"
End Sub
```

---

### DisconnectSignal(signal_name As String, method_name As String)
Disconnects a signal from a method.

**Syntax:**
```vb
DisconnectSignal(signal_name, method_name)
```

**Example:**
```vb
DisconnectSignal("ready", "OnReady")
```

---

## Engine Info

### GetFPS() As Integer
Returns the current frames per second.

**Syntax:**
```vb
Dim fps = GetFPS()
```

**Example:**
```vb
Dim fps = GetFPS()
Print "FPS: " & fps

If fps < 30 Then
    Print "Low FPS warning!"
End If
```

---

### IsEditorHint() As Boolean
Returns true if running in the Godot editor.

**Syntax:**
```vb
Dim is_editor = IsEditorHint()
```

**Example:**
```vb
If IsEditorHint() Then
    Print "Running in editor"
Else
    Print "Running in game"
End If
```

---

### GetEngineVersion() As Dictionary
Returns a dictionary with engine version information.

**Syntax:**
```vb
Dim version = GetEngineVersion()
```

**Example:**
```vb
Dim ver = GetEngineVersion()
Print "Godot version: " & ver["major"] & "." & ver["minor"]
Print "Full info: " & ver
```

---

## Math Helpers

### Deg2Rad(degrees As Float) As Float
Converts degrees to radians.

**Syntax:**
```vb
Dim radians = Deg2Rad(degrees)
```

**Example:**
```vb
Dim angle_deg = 90
Dim angle_rad = Deg2Rad(angle_deg)
SetRotation(angle_rad)

Print "45 degrees = " & Deg2Rad(45) & " radians"
```

---

### Rad2Deg(radians As Float) As Float
Converts radians to degrees.

**Syntax:**
```vb
Dim degrees = Rad2Deg(radians)
```

**Example:**
```vb
Dim rot = GetRotation()
Dim degrees = Rad2Deg(rot)
Print "Rotation: " & degrees & " degrees"
```

---

### Clamp(value As Float, min As Float, max As Float) As Float
Clamps a value between min and max.

**Syntax:**
```vb
Dim clamped = Clamp(value, min_value, max_value)
```

**Example:**
```vb
Dim health = 150
health = Clamp(health, 0, 100)  ' health = 100

Dim speed = -50
speed = Clamp(speed, 0, 200)  ' speed = 0
```

---

### Lerp(from As Float, to As Float, weight As Float) As Float
Linearly interpolates between two values.

**Syntax:**
```vb
Dim interpolated = Lerp(from, to, weight)
```

**Example:**
```vb
' Smooth camera follow
Dim camera_x = GetPosition().x
Dim target_x = player.position.x
Dim smooth_x = Lerp(camera_x, target_x, 0.1)
SetPosition(smooth_x, GetPosition().y)

' Fade alpha
Dim alpha = Lerp(0, 1, 0.5)  ' alpha = 0.5
```

---

### MoveToward(from As Float, to As Float, delta As Float) As Float
Moves a value toward a target by a maximum delta.

**Syntax:**
```vb
Dim new_value = MoveToward(from, to, delta)
```

**Example:**
```vb
Dim current_speed = 0
Dim target_speed = 100
Dim acceleration = 5

' Move toward target speed
current_speed = MoveToward(current_speed, target_speed, acceleration)
```

---

## Rendering

### SetVisible(visible As Boolean)
Sets the visibility of the node.

**Syntax:**
```vb
SetVisible(visible)
```

**Example:**
```vb
' Hide node
SetVisible(False)

' Show node
SetVisible(True)

' Toggle visibility
Dim is_vis = IsVisible()
SetVisible(Not is_vis)
```

---

### IsVisible() As Boolean
Returns true if the node is visible.

**Syntax:**
```vb
Dim visible = IsVisible()
```

**Example:**
```vb
If IsVisible() Then
    Print "Node is visible"
End If
```

---

### SetModulate(color As Color)
Sets the modulate color (tint) of the node.

**Syntax:**
```vb
SetModulate(color)
```

**Example:**
```vb
' Tint red (requires Color type)
' SetModulate(Color(1, 0, 0, 1))

' Half transparency
' SetModulate(Color(1, 1, 1, 0.5))
```

---

### GetModulate() As Color
Returns the current modulate color.

**Syntax:**
```vb
Dim color = GetModulate()
```

**Example:**
```vb
Dim mod = GetModulate()
Print "Modulate: " & mod
```

---

## Complete Examples

### Example 1: Player Movement

```vb
Sub _process()
    Dim delta = GetDeltaTime()
    Dim pos = GetPosition()
    Dim speed = 200
    
    ' Horizontal movement
    If IsActionPressed("ui_right") Then
        SetPosition(pos.x + speed * delta, pos.y)
    ElseIf IsActionPressed("ui_left") Then
        SetPosition(pos.x - speed * delta, pos.y)
    End If
    
    ' Jump
    If IsActionJustPressed("ui_accept") Then
        EmitSignal("player_jumped")
    End If
End Sub
```

### Example 2: Physics Character

```vb
Sub _physics_process()
    Dim delta = GetPhysicsDeltaTime()
    Dim vel = GetVelocity()
    
    ' Gravity
    If Not IsOnFloor() Then
        vel.y = vel.y + 980 * delta
    End If
    
    ' Movement
    Dim speed = 200
    If IsActionPressed("ui_right") Then
        vel.x = speed
    ElseIf IsActionPressed("ui_left") Then
        vel.x = -speed
    Else
        vel.x = MoveToward(vel.x, 0, speed * delta * 10)
    End If
    
    ' Jump
    If IsActionJustPressed("ui_accept") And IsOnFloor() Then
        vel.y = -400
    End If
    
    SetVelocity(vel.x, vel.y)
    MoveAndSlide()
End Sub
```

### Example 3: Scene Management

```vb
Sub SpawnEnemy()
    Dim enemy_scene = LoadScene("res://enemies/enemy.tscn")
    If Not IsNull(enemy_scene) Then
        Dim enemy = enemy_scene.instantiate()
        Dim spawn_pos = Vector2(100, 100)
        enemy.position = spawn_pos
        GetTree().get_root().add_child(enemy)
        Print "Enemy spawned"
    End If
End Sub

Sub GameOver()
    Print "Game Over!"
    Dim result = ChangeScene("res://menus/game_over.tscn")
End Sub
```

---

## Summary

VisualGasic now includes **60+ Godot-specific functions** covering:
- ✅ Scene/Node Management (8 functions)
- ✅ Input Functions (8 functions)
- ✅ Timing Functions (2 functions)
- ✅ Memory/Lifecycle (1 function)
- ✅ Scene Loading (4 functions)
- ✅ Transform/Position (8 functions)
- ✅ Physics Functions (7 functions)
- ✅ Signals (3 functions)
- ✅ Engine Info (3 functions)
- ✅ Math Helpers (5 functions)
- ✅ Rendering (4 functions)

These functions provide seamless integration between VB6-style syntax and Godot 4's powerful game engine features!
