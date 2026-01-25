' VisualGasic - Godot-Specific Features Test
' This file demonstrates all Godot-specific builtin functions

Sub TestGodotFeatures()
    Print "===== GODOT-SPECIFIC FEATURES TEST ====="
    Print ""
    
    ' ===== Scene/Node Management =====
    Print "=== Scene/Node Management ==="
    
    ' Get current node's tree and root
    Dim tree = GetTree()
    Print "SceneTree: " & TypeName(tree)
    
    Dim root = GetRoot()
    Print "Root node: " & TypeName(root)
    
    ' Get parent node
    Dim parent = GetParent()
    Print "Parent: " & TypeName(parent)
    
    ' Get all children
    Dim children = GetChildren()
    Print "Number of children: " & UBound(children)
    
    ' Check if node exists
    Dim hasLabel = HasNode("Label")
    Print "Has Label child: " & hasLabel
    
    ' Find child by name
    Dim foundChild = FindChild("Label", True)
    Print "Found child: " & TypeName(foundChild)
    
    ' Get node by path
    Dim nodeByPath = GetNode(".")
    Print "Node by path '.': " & TypeName(nodeByPath)
    
    Print ""
    
    ' ===== Input Functions =====
    Print "=== Input Functions ==="
    
    ' Check action states (requires project.godot with defined actions)
    Dim isPressed = IsActionPressed("ui_accept")
    Print "ui_accept pressed: " & isPressed
    
    Dim justPressed = IsActionJustPressed("ui_accept")
    Print "ui_accept just pressed: " & justPressed
    
    Dim justReleased = IsActionJustReleased("ui_accept")
    Print "ui_accept just released: " & justReleased
    
    Dim strength = GetActionStrength("ui_accept")
    Print "ui_accept strength: " & strength
    
    ' Check specific key (32 = Space)
    Dim spacePressed = IsKeyPressed(32)
    Print "Space key pressed: " & spacePressed
    
    ' Check mouse button (1 = Left, 2 = Right)
    Dim leftMousePressed = IsMouseButtonPressed(1)
    Print "Left mouse pressed: " & leftMousePressed
    
    ' Get mouse position
    Dim mousePos = GetMousePosition()
    Print "Mouse position: " & mousePos
    
    ' Get mouse velocity
    Dim mouseVel = GetLastMouseVelocity()
    Print "Mouse velocity: " & mouseVel
    
    Print ""
    
    ' ===== Timing Functions =====
    Print "=== Timing Functions ==="
    
    Dim deltaTime = GetDeltaTime()
    Print "Delta time: " & deltaTime
    
    Dim physicsDelta = GetPhysicsDeltaTime()
    Print "Physics delta time: " & physicsDelta
    
    Print ""
    
    ' ===== Scene Loading =====
    Print "=== Scene Loading ==="
    
    ' Load a scene (returns packed scene resource)
    ' Dim scene = LoadScene("res://path/to/scene.tscn")
    ' Print "Loaded scene: " & TypeName(scene)
    
    ' Get current scene
    Dim currentScene = GetCurrentScene()
    Print "Current scene: " & TypeName(currentScene)
    
    ' Change scene (requires valid path)
    ' Dim result = ChangeScene("res://new_scene.tscn")
    ' Print "Change scene result: " & result
    
    ' Reload current scene
    ' Dim reloadResult = ReloadCurrentScene()
    ' Print "Reload result: " & reloadResult
    
    Print ""
    
    ' ===== Transform/Position (for Node2D) =====
    Print "=== Transform/Position ==="
    
    ' Get and set position
    Dim pos = GetPosition()
    Print "Current position: " & pos
    
    SetPosition(100, 200)
    Print "Set position to (100, 200)"
    
    ' Global position
    Dim globalPos = GetGlobalPosition()
    Print "Global position: " & globalPos
    
    SetGlobalPosition(150, 250)
    Print "Set global position to (150, 250)"
    
    ' Rotation
    Dim rotation = GetRotation()
    Print "Current rotation: " & rotation
    
    SetRotation(1.57)  ' ~90 degrees in radians
    Print "Set rotation to 1.57 radians"
    
    ' Scale
    Dim scale = GetScale()
    Print "Current scale: " & scale
    
    SetScale(2, 2)
    Print "Set scale to (2, 2)"
    
    Print ""
    
    ' ===== Physics (for CharacterBody2D) =====
    Print "=== Physics Functions ==="
    
    ' Check floor/ceiling/wall (requires CharacterBody2D)
    ' Dim onFloor = IsOnFloor()
    ' Print "On floor: " & onFloor
    
    ' Dim onCeiling = IsOnCeiling()
    ' Print "On ceiling: " & onCeiling
    
    ' Dim onWall = IsOnWall()
    ' Print "On wall: " & onWall
    
    ' Get/Set velocity (requires CharacterBody2D)
    ' Dim vel = GetVelocity()
    ' Print "Velocity: " & vel
    
    ' SetVelocity(100, -200)
    ' Print "Set velocity to (100, -200)"
    
    ' Dim moved = MoveAndSlide()
    ' Print "Moved and slid: " & moved
    
    Print "Physics functions require CharacterBody2D node type"
    Print ""
    
    ' ===== Signals =====
    Print "=== Signals ==="
    
    ' Emit a signal (requires signal to be defined)
    ' EmitSignal("custom_signal", "arg1", 123)
    ' Print "Emitted custom_signal"
    
    ' Connect signal to method
    ' Dim connectResult = ConnectSignal("ready", "OnReady")
    ' Print "Connect result: " & connectResult
    
    Print "Signal functions work with defined signals"
    Print ""
    
    ' ===== Engine Info =====
    Print "=== Engine Info ==="
    
    Dim fps = GetFPS()
    Print "Current FPS: " & fps
    
    Dim isEditor = IsEditorHint()
    Print "Is editor hint: " & isEditor
    
    Dim version = GetEngineVersion()
    Print "Engine version info: " & version
    
    Print ""
    
    ' ===== Math Helpers =====
    Print "=== Math Helpers ==="
    
    ' Degree/Radian conversion
    Dim radians = Deg2Rad(90)
    Print "90 degrees to radians: " & radians
    
    Dim degrees = Rad2Deg(3.14159)
    Print "Pi radians to degrees: " & degrees
    
    ' Clamp value
    Dim clamped = Clamp(150, 0, 100)
    Print "Clamp(150, 0, 100): " & clamped
    
    ' Lerp (linear interpolation)
    Dim lerped = Lerp(0, 100, 0.5)
    Print "Lerp(0, 100, 0.5): " & lerped
    
    ' Move toward
    Dim moved_val = MoveToward(10, 20, 3)
    Print "MoveToward(10, 20, 3): " & moved_val
    
    Print ""
    
    ' ===== Rendering =====
    Print "=== Rendering ==="
    
    ' Get/Set visibility
    Dim isVis = IsVisible()
    Print "Is visible: " & isVis
    
    SetVisible(True)
    Print "Set visible to True"
    
    ' Get/Set modulate color
    Dim modulate = GetModulate()
    Print "Current modulate: " & modulate
    
    ' SetModulate requires Color type
    ' SetModulate(Color(1, 0, 0, 1))  ' Red tint
    ' Print "Set modulate to red"
    
    Print ""
    
    ' ===== Memory Management =====
    Print "=== Memory Management ==="
    
    Print "QueueFree() - Queues node for deletion"
    Print "Note: Don't call on self in tests!"
    ' QueueFree()  ' This would queue the current node for deletion
    
    Print ""
    Print "===== ALL GODOT FEATURES TESTED ====="
End Sub

' Example: Using Godot features in a game loop
Sub GameLoop()
    Print "=== Game Loop Example ==="
    
    ' Get delta time for frame-independent movement
    Dim delta = GetDeltaTime()
    
    ' Check input
    If IsActionPressed("ui_right") Then
        Dim pos = GetPosition()
        Dim speed = 200
        SetPosition(pos.x + speed * delta, pos.y)
        Print "Moving right"
    End If
    
    If IsActionPressed("ui_left") Then
        Dim pos = GetPosition()
        Dim speed = 200
        SetPosition(pos.x - speed * delta, pos.y)
        Print "Moving left"
    End If
    
    ' Check if space is pressed
    If IsActionJustPressed("ui_accept") Then
        Print "Space pressed! Position: " & GetPosition()
        EmitSignal("player_jumped")
    End If
    
    ' Display FPS
    Print "FPS: " & GetFPS()
End Sub

' Example: Physics movement (requires CharacterBody2D)
Sub PhysicsMovement()
    Print "=== Physics Movement Example ==="
    
    Dim velocity = GetVelocity()
    Dim delta = GetPhysicsDeltaTime()
    
    ' Apply gravity
    If Not IsOnFloor() Then
        velocity.y = velocity.y + 980 * delta
    End If
    
    ' Handle input
    Dim speed = 200
    If IsActionPressed("ui_right") Then
        velocity.x = speed
    ElseIf IsActionPressed("ui_left") Then
        velocity.x = -speed
    Else
        velocity.x = 0
    End If
    
    ' Jump
    If IsActionJustPressed("ui_accept") And IsOnFloor() Then
        velocity.y = -400
    End If
    
    ' Apply velocity
    SetVelocity(velocity.x, velocity.y)
    MoveAndSlide()
    
    Print "Velocity: " & GetVelocity()
End Sub

' Example: Scene management
Sub SceneManagement()
    Print "=== Scene Management Example ==="
    
    ' Find all children
    Dim children = GetChildren()
    Print "Total children: " & UBound(children)
    
    ' Find specific child
    Dim label = FindChild("ScoreLabel", True)
    If Not IsNull(label) Then
        Print "Found score label"
    End If
    
    ' Check if node exists before accessing
    If HasNode("Enemy") Then
        Dim enemy = GetNode("Enemy")
        Print "Enemy node found: " & TypeName(enemy)
    Else
        Print "No enemy node found"
    End If
    
    ' Access tree
    Dim tree = GetTree()
    Print "Scene tree nodes: " & TypeName(tree)
End Sub

' Example: Math conversions
Sub MathConversions()
    Print "=== Math Conversions Example ==="
    
    ' Convert angles
    Dim angle_deg = 45
    Dim angle_rad = Deg2Rad(angle_deg)
    Print angle_deg & " degrees = " & angle_rad & " radians"
    
    ' Back to degrees
    Dim back_to_deg = Rad2Deg(angle_rad)
    Print angle_rad & " radians = " & back_to_deg & " degrees"
    
    ' Use in rotation
    SetRotation(Deg2Rad(90))
    Print "Rotated 90 degrees"
    
    ' Lerp for smooth transitions
    Dim target_pos = 100
    Dim current_pos = 0
    Dim smooth_pos = Lerp(current_pos, target_pos, 0.1)
    Print "Smooth position: " & smooth_pos
    
    ' Clamp values
    Dim health = 150
    Dim clamped_health = Clamp(health, 0, 100)
    Print "Clamped health: " & clamped_health
End Sub
