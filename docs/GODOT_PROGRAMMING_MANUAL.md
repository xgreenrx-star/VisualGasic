# VisualGasic for Godot - Complete Programming Manual
*The definitive guide to using VisualGasic in Godot game development*

Version 2.0  
Updated: January 2026

---

## Table of Contents

### Part I: Getting Started with Godot
1. [Introduction to Godot with VisualGasic](#introduction)
2. [Understanding Godot's Architecture](#architecture)
3. [Setting Up Your First Project](#setup)
4. [Scenes, Nodes, and the Scene Tree](#scenes-nodes)

### Part II: Core Godot Concepts in VisualGasic
5. [Working with Nodes](#nodes)
6. [Signals and Communication](#signals)
7. [Input Handling](#input)
8. [Timers and Processing](#timers)

### Part III: 2D Game Development
9. [2D Basics and Coordinate System](#2d-basics)
10. [Sprites and Animation](#sprites)
11. [2D Physics and Movement](#2d-physics)
12. [Collision Detection](#collision)

### Part IV: 3D Game Development
13. [3D Basics and Coordinate System](#3d-basics)
14. [3D Models and Materials](#3d-models)
15. [3D Physics and Movement](#3d-physics)
16. [Lighting and Environment](#lighting)

### Part V: User Interface
17. [UI System Overview](#ui-overview)
18. [Control Nodes and Layouts](#ui-controls)
19. [Theming and Styling](#ui-theming)
20. [Interactive Elements](#ui-interactive)

### Part VI: Advanced Features
21. [File I/O and Data Management](#file-io)
22. [Networking and Multiplayer](#networking)
23. [Audio System](#audio)
24. [Particle Systems](#particles)

### Part VII: Performance and Optimization
25. [Performance Best Practices](#performance)
26. [Memory Management](#memory)
27. [Platform-Specific Features](#platform)

### Part VIII: Deployment and Distribution
28. [Export Settings](#export)
29. [Platform Requirements](#requirements)
30. [Distribution Strategies](#distribution)

---

## Chapter 1: Introduction to Godot with VisualGasic {#introduction}

### What is Godot?

Godot is a free and open-source game engine that provides a comprehensive set of tools for creating 2D and 3D games. Unlike many game engines, Godot uses a unique scene-based architecture that makes it particularly well-suited for VisualGasic's familiar object-oriented approach.

### Why VisualGasic for Godot?

VisualGasic brings the familiar Visual Basic 6 syntax and programming model to Godot, allowing developers to:

- Use familiar VB6 syntax and concepts
- Leverage Godot's powerful node system
- Create games without learning GDScript
- Maintain readability and simplicity
- Access all Godot features through VB-style code

### Your First VisualGasic Godot Script

```vb
' HelloGodot.vb - Your first VisualGasic script for Godot
Imports Godot

Public Class Player
    Inherits CharacterBody2D
    
    Private speed As Single = 300.0
    Private jumpVelocity As Single = -400.0
    
    ' Godot's gravity from the project settings
    Private gravity As Single = ProjectSettings.GetSetting("physics/2d/default_gravity")
    
    Public Sub _Ready()
        ' This function is called when the node is ready
        Print "Hello, Godot from VisualGasic!"
    End Sub
    
    Public Sub _PhysicsProcess(delta As Single)
        ' Handle movement and physics
        HandleInput(delta)
        ApplyGravity(delta)
        MoveAndSlide()
    End Sub
    
    Private Sub HandleInput(delta As Single)
        ' Handle jump
        If Input.IsActionJustPressed("ui_accept") And IsOnFloor() Then
            velocity.y = jumpVelocity
        End If
        
        ' Handle horizontal movement
        Dim direction As Single = Input.GetAxis("ui_left", "ui_right")
        If direction <> 0 Then
            velocity.x = direction * speed
        Else
            velocity.x = MoveToward(velocity.x, 0, speed)
        End If
    End Sub
    
    Private Sub ApplyGravity(delta As Single)
        If Not IsOnFloor() Then
            velocity.y += gravity * delta
        End If
    End Sub
End Class
```

---

## Chapter 2: Understanding Godot's Architecture {#architecture}

### The Scene System

Godot organizes everything into **Scenes**. A scene in Godot is like a form in Visual Basic, but more flexible:

```vb
' MainGame.vb - A typical game scene
Public Class MainGame
    Inherits Node2D
    
    ' Scene references - like form controls
    Private player As Player
    Private enemies As Node2D
    Private ui As CanvasLayer
    
    Public Sub _Ready()
        ' Initialize the scene
        SetupPlayer()
        SetupEnemies()
        SetupUI()
    End Sub
    
    Private Sub SetupPlayer()
        ' Create player instance
        player = GetNode(Of Player)("Player")
        
        ' Connect signals (like VB6 event handlers)
        player.Connect("health_changed", AddressOf OnPlayerHealthChanged)
    End Sub
End Class
```

### Node Hierarchy

Every Godot scene is built from **Nodes** arranged in a tree structure:

```
MainGame (Node2D)
├── Player (CharacterBody2D)
│   ├── Sprite2D
│   ├── CollisionShape2D
│   └── Camera2D
├── Enemies (Node2D)
│   ├── Enemy1 (CharacterBody2D)
│   └── Enemy2 (CharacterBody2D)
└── UI (CanvasLayer)
    ├── HealthBar (ProgressBar)
    └── ScoreLabel (Label)
```

### VisualGasic Node Types

| VB6 Concept | Godot Node Type | VisualGasic Usage |
|-------------|----------------|-------------------|
| Form | Control/Node2D/Node3D | Main container for scenes |
| PictureBox | Sprite2D/TextureRect | Display images and sprites |
| Label | Label | Show text |
| Command Button | Button | Interactive buttons |
| Timer | Timer | Timed events |
| Shape | CollisionShape2D/3D | Physics collision |

---

## Chapter 3: Setting Up Your First Project {#setup}

### Creating a New Godot Project

1. Open Godot
2. Create New Project
3. Set project name and location
4. Create the project

### Adding VisualGasic Support

1. Create a `scripts` folder in your project
2. Add the VisualGasic plugin to `addons/visual_gasic/`
3. Enable the plugin in Project Settings

### Project Structure

```
MyGame/
├── scenes/
│   ├── Main.tscn
│   ├── Player.tscn
│   └── Enemy.tscn
├── scripts/
│   ├── Main.vb
│   ├── Player.vb
│   └── Enemy.vb
├── assets/
│   ├── sprites/
│   ├── sounds/
│   └── fonts/
└── project.godot
```

### Basic Project Setup

```vb
' Main.vb - Main game controller
Imports Godot

Public Class Main
    Inherits Node2D
    
    ' Game state
    Private score As Integer = 0
    Private gameRunning As Boolean = False
    
    ' Scene references
    Private scoreLabel As Label
    Private player As Player
    
    Public Sub _Ready()
        ' Get references to child nodes
        scoreLabel = GetNode(Of Label)("UI/ScoreLabel")
        player = GetNode(Of Player)("Player")
        
        ' Initialize game
        StartGame()
    End Sub
    
    Private Sub StartGame()
        gameRunning = True
        score = 0
        UpdateScore()
        
        ' Start background music
        Dim bgMusic As AudioStreamPlayer = GetNode(Of AudioStreamPlayer)("BGMusic")
        bgMusic.Play()
    End Sub
    
    Private Sub UpdateScore()
        scoreLabel.Text = "Score: " & score.ToString()
    End Sub
    
    Public Sub AddScore(points As Integer)
        score += points
        UpdateScore()
    End Sub
End Class
```

---

## Chapter 4: Scenes, Nodes, and the Scene Tree {#scenes-nodes}

### Understanding Scenes

A scene in Godot is a collection of nodes that work together. Think of it like a VB6 form with all its controls:

```vb
' GameLevel.vb - A complete game level
Public Class GameLevel
    Inherits Node2D
    
    ' Scene components
    Private tilemap As TileMap
    Private playerSpawnPoint As Marker2D
    Private exitDoor As Area2D
    
    Public Sub _Ready()
        ' Initialize level
        SetupTilemap()
        SpawnPlayer()
        SetupExit()
    End Sub
    
    Private Sub SetupTilemap()
        tilemap = GetNode(Of TileMap)("TileMap")
        ' Configure tilemap properties
        tilemap.TileSet = Load(Of TileSet)("res://assets/tileset.tres")
    End Sub
    
    Private Sub SpawnPlayer()
        playerSpawnPoint = GetNode(Of Marker2D)("PlayerSpawn")
        Dim player As Player = Load(Of PackedScene)("res://scenes/Player.tscn").Instantiate()
        player.GlobalPosition = playerSpawnPoint.GlobalPosition
        AddChild(player)
    End Sub
End Class
```

### Working with the Scene Tree

The scene tree is like the form hierarchy in VB6, but more dynamic:

```vb
' SceneManager.vb - Managing scenes dynamically
Public Class SceneManager
    Inherits Node
    
    Private currentScene As Node
    
    Public Sub _Ready()
        ' Get the current scene
        Dim root As Viewport = GetTree().CurrentScene
        currentScene = root
    End Sub
    
    Public Sub GotoScene(path As String)
        ' Free current scene
        currentScene.QueueFree()
        
        ' Load new scene
        Dim newScene As PackedScene = Load(Of PackedScene)(path)
        currentScene = newScene.Instantiate()
        
        ' Add to tree
        GetTree().Root.AddChild(currentScene)
        GetTree().CurrentScene = currentScene
    End Sub
    
    Public Sub RestartScene()
        GotoScene(currentScene.SceneFilePath)
    End Sub
End Class
```

---

## Chapter 5: Working with Nodes {#nodes}

### Node Lifecycle

Every node in Godot has a lifecycle similar to VB6 form events:

```vb
' GameObject.vb - Understanding node lifecycle
Public Class GameObject
    Inherits Node2D
    
    ' VB6 Form_Load equivalent
    Public Sub _Ready()
        Print "Node is ready and added to scene tree"
        InitializeObject()
    End Sub
    
    ' VB6 Form_Activate equivalent
    Public Sub _EnterTree()
        Print "Node entered the scene tree"
    End Sub
    
    ' VB6 Form_Deactivate equivalent  
    Public Sub _ExitTree()
        Print "Node is leaving the scene tree"
        Cleanup()
    End Sub
    
    ' VB6 Timer event equivalent
    Public Sub _Process(delta As Single)
        ' Called every frame - like a VB6 Timer with very short interval
        UpdateObject(delta)
    End Sub
    
    ' Physics timer equivalent
    Public Sub _PhysicsProcess(delta As Single)
        ' Called at fixed intervals for physics
        UpdatePhysics(delta)
    End Sub
    
    Private Sub InitializeObject()
        ' Initialize object state
        SetupVisuals()
        SetupPhysics()
    End Sub
    
    Private Sub Cleanup()
        ' Clean up resources before destruction
        SaveState()
        RemoveConnections()
    End Sub
End Class
```

### Node Communication

Nodes communicate through signals (like VB6 events) and direct references:

```vb
' Enemy.vb - Node communication example
Public Class Enemy
    Inherits CharacterBody2D
    
    ' Define custom signals (like VB6 custom events)
    Signal EnemyDestroyed(enemy As Enemy, points As Integer)
    Signal PlayerHit(damage As Integer)
    
    Private health As Integer = 100
    Private damage As Integer = 10
    
    Public Sub TakeDamage(amount As Integer)
        health -= amount
        
        If health <= 0 Then
            ' Emit signal when destroyed
            EmitSignal(SignalName.EnemyDestroyed, Me, 100)
            QueueFree()
        End If
    End Sub
    
    Private Sub _OnBodyEntered(body As Node2D)
        ' Handle collision with player
        If TypeOf body Is Player Then
            EmitSignal(SignalName.PlayerHit, damage)
        End If
    End Sub
End Class
```

### Finding and Accessing Nodes

```vb
' NodeManager.vb - Finding and accessing nodes
Public Class NodeManager
    Inherits Node
    
    Public Sub _Ready()
        ' Examples of finding nodes
        FindNodeExamples()
    End Sub
    
    Private Sub FindNodeExamples()
        ' Get direct child node
        Dim player As Player = GetNode(Of Player)("Player")
        
        ' Get node by path
        Dim healthBar As ProgressBar = GetNode(Of ProgressBar)("UI/HUD/HealthBar")
        
        ' Find node anywhere in tree
        Dim camera As Camera2D = FindChild("Camera2D", True)
        
        ' Get parent node
        Dim parentNode As Node = GetParent()
        
        ' Get root node
        Dim sceneRoot As Node = GetTree().CurrentScene
        
        ' Check if node exists before using
        If HasNode("OptionalNode") Then
            Dim optional As Node = GetNode("OptionalNode")
        End If
        
        ' Get all children of specific type
        Dim enemies As Array = GetTree().GetNodesInGroup("enemies")
        For Each enemy As Enemy In enemies
            enemy.TakeDamage(10)
        Next
    End Sub
    
    ' Helper method to safely get nodes
    Public Function SafeGetNode(Of T As Node)(path As String) As T
        If HasNode(path) Then
            Return GetNode(Of T)(path)
        End If
        Return Nothing
    End Function
End Class
```

---

## Chapter 6: Signals and Communication {#signals}

### Understanding Signals

Signals in Godot are like events in VB6, allowing nodes to communicate without direct references:

```vb
' Player.vb - Using signals for communication
Public Class Player
    Inherits CharacterBody2D
    
    ' Define custom signals
    Signal HealthChanged(newHealth As Integer)
    Signal PlayerDied()
    Signal ScoreIncreased(points As Integer)
    Signal LevelCompleted()
    
    Private health As Integer = 100
    Private maxHealth As Integer = 100
    
    Public Sub TakeDamage(amount As Integer)
        health = Math.Max(0, health - amount)
        
        ' Emit health changed signal
        EmitSignal(SignalName.HealthChanged, health)
        
        If health = 0 Then
            ' Player died
            EmitSignal(SignalName.PlayerDied)
        End If
    End Sub
    
    Public Sub Heal(amount As Integer)
        health = Math.Min(maxHealth, health + amount)
        EmitSignal(SignalName.HealthChanged, health)
    End Sub
    
    Public Sub CollectItem(points As Integer)
        EmitSignal(SignalName.ScoreIncreased, points)
    End Sub
    
    Public Sub ReachExit()
        EmitSignal(SignalName.LevelCompleted)
    End Sub
End Class
```

### Connecting Signals

```vb
' GameManager.vb - Connecting to signals
Public Class GameManager
    Inherits Node
    
    Private player As Player
    Private ui As GameUI
    Private score As Integer = 0
    
    Public Sub _Ready()
        ' Get references
        player = GetNode(Of Player)("Player")
        ui = GetNode(Of GameUI)("UI")
        
        ' Connect player signals to handler methods
        player.Connect(Player.SignalName.HealthChanged, AddressOf OnPlayerHealthChanged)
        player.Connect(Player.SignalName.PlayerDied, AddressOf OnPlayerDied)
        player.Connect(Player.SignalName.ScoreIncreased, AddressOf OnScoreIncreased)
        player.Connect(Player.SignalName.LevelCompleted, AddressOf OnLevelCompleted)
    End Sub
    
    ' Signal handler methods (like VB6 event procedures)
    Private Sub OnPlayerHealthChanged(newHealth As Integer)
        ui.UpdateHealthBar(newHealth)
        
        ' Play hurt sound if health decreased
        If newHealth < player.health Then
            PlaySound("hurt")
        End If
    End Sub
    
    Private Sub OnPlayerDied()
        ' Handle player death
        ShowGameOverScreen()
        SaveHighScore()
    End Sub
    
    Private Sub OnScoreIncreased(points As Integer)
        score += points
        ui.UpdateScore(score)
        
        ' Play collect sound
        PlaySound("collect")
    End Sub
    
    Private Sub OnLevelCompleted()
        ' Handle level completion
        SaveProgress()
        LoadNextLevel()
    End Sub
    
    Private Sub PlaySound(soundName As String)
        Dim audioPlayer As AudioStreamPlayer = GetNode(Of AudioStreamPlayer)("AudioPlayer")
        Dim sound As AudioStream = Load(Of AudioStream)($"res://sounds/{soundName}.ogg")
        audioPlayer.Stream = sound
        audioPlayer.Play()
    End Sub
End Class
```

### Signal Groups and Broadcasting

```vb
' EnemyManager.vb - Working with signal groups
Public Class EnemyManager
    Inherits Node2D
    
    Private enemies As New List(Of Enemy)
    
    Public Sub _Ready()
        ' Find all enemies in the scene
        FindEnemies()
        ConnectEnemySignals()
    End Sub
    
    Private Sub FindEnemies()
        ' Get all nodes in the "enemies" group
        Dim enemyNodes As Array = GetTree().GetNodesInGroup("enemies")
        
        For Each enemyNode As Enemy In enemyNodes
            enemies.Add(enemyNode)
        Next
    End Sub
    
    Private Sub ConnectEnemySignals()
        For Each enemy As Enemy In enemies
            ' Connect each enemy's signals
            enemy.Connect(Enemy.SignalName.EnemyDestroyed, AddressOf OnEnemyDestroyed)
            enemy.Connect(Enemy.SignalName.PlayerSpotted, AddressOf OnPlayerSpotted)
        Next
    End Sub
    
    Private Sub OnEnemyDestroyed(enemy As Enemy, points As Integer)
        ' Remove from list
        enemies.Remove(enemy)
        
        ' Award points
        EmitSignal(SignalName.ScoreIncreased, points)
        
        ' Check if all enemies defeated
        If enemies.Count = 0 Then
            EmitSignal(SignalName.AllEnemiesDefeated)
        End If
    End Sub
    
    Private Sub OnPlayerSpotted(enemy As Enemy)
        ' Alert all other enemies
        For Each otherEnemy As Enemy In enemies
            If otherEnemy <> enemy Then
                otherEnemy.AlertToPlayer()
            End If
        Next
    End Sub
    
    ' Broadcast signal to all enemies
    Public Sub AlertAllEnemies()
        GetTree().CallGroup("enemies", "AlertToPlayer")
    End Sub
End Class
```

---

## Chapter 7: Input Handling {#input}

### Basic Input Detection

```vb
' InputHandler.vb - Handling various input types
Public Class InputHandler
    Inherits Node
    
    Public Sub _Ready()
        ' Input handling is done in _Input or _UnhandledInput
    End Sub
    
    Public Sub _Input(inputEvent As InputEvent)
        ' Handle all input events here
        
        ' Keyboard input
        If TypeOf inputEvent Is InputEventKey Then
            HandleKeyboardInput(CType(inputEvent, InputEventKey))
        End If
        
        ' Mouse input
        If TypeOf inputEvent Is InputEventMouseButton Then
            HandleMouseClick(CType(inputEvent, InputEventMouseButton))
        End If
        
        If TypeOf inputEvent Is InputEventMouseMotion Then
            HandleMouseMove(CType(inputEvent, InputEventMouseMotion))
        End If
        
        ' Joystick/Gamepad input
        If TypeOf inputEvent Is InputEventJoypadButton Then
            HandleJoypadButton(CType(inputEvent, InputEventJoypadButton))
        End If
    End Sub
    
    Private Sub HandleKeyboardInput(keyEvent As InputEventKey)
        ' Check if key was just pressed
        If keyEvent.Pressed Then
            Select Case keyEvent.Keycode
                Case Key.Space
                    Print "Space key pressed!"
                Case Key.Escape
                    GetTree().Quit()
                Case Key.F1
                    ShowHelp()
                Case Key.Enter
                    ConfirmAction()
            End Select
        End If
    End Sub
    
    Private Sub HandleMouseClick(mouseEvent As InputEventMouseButton)
        If mouseEvent.Pressed Then
            Select Case mouseEvent.ButtonIndex
                Case MouseButton.Left
                    Print $"Left click at {mouseEvent.Position}"
                Case MouseButton.Right
                    ShowContextMenu(mouseEvent.Position)
                Case MouseButton.WheelUp
                    ZoomIn()
                Case MouseButton.WheelDown
                    ZoomOut()
            End Select
        End If
    End Sub
End Class
```

### Action-Based Input System

```vb
' Player.vb - Using input actions (recommended approach)
Public Class Player
    Inherits CharacterBody2D
    
    Private speed As Single = 300.0
    Private jumpVelocity As Single = -400.0
    Private gravity As Single = ProjectSettings.GetSetting("physics/2d/default_gravity")
    
    Public Sub _PhysicsProcess(delta As Single)
        HandleMovement(delta)
        HandleJumping()
        ApplyGravity(delta)
        
        ' Apply movement
        MoveAndSlide()
    End Sub
    
    Private Sub HandleMovement(delta As Single)
        ' Get horizontal input axis (-1 to 1)
        Dim direction As Single = Input.GetAxis("move_left", "move_right")
        
        If direction <> 0 Then
            velocity.x = direction * speed
        Else
            ' Gradually stop when no input
            velocity.x = MoveToward(velocity.x, 0, speed * delta * 3)
        End If
    End Sub
    
    Private Sub HandleJumping()
        ' Check for jump input
        If Input.IsActionJustPressed("jump") And IsOnFloor() Then
            velocity.y = jumpVelocity
        End If
        
        ' Variable jump height
        If Input.IsActionJustReleased("jump") And velocity.y < jumpVelocity / 2 Then
            velocity.y = jumpVelocity / 2
        End If
    End Sub
    
    Private Sub ApplyGravity(delta As Single)
        If Not IsOnFloor() Then
            velocity.y += gravity * delta
        End If
    End Sub
    
    Public Sub _Input(inputEvent As InputEvent)
        ' Handle non-movement actions
        If Input.IsActionJustPressed("attack") Then
            Attack()
        End If
        
        If Input.IsActionJustPressed("interact") Then
            TryInteract()
        End If
        
        If Input.IsActionJustPressed("inventory") Then
            ToggleInventory()
        End If
    End Sub
    
    Private Sub Attack()
        ' Player attack logic
        Print "Player attacks!"
    End Sub
    
    Private Sub TryInteract()
        ' Check for nearby interactable objects
        Dim spaceState As PhysicsDirectSpaceState2D = GetWorld2D().DirectSpaceState
        
        ' Cast ray forward to find interactables
        Dim query As PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.Create(
            GlobalPosition, 
            GlobalPosition + Vector2.Right * 50)
        
        Dim result As Dictionary = spaceState.IntersectRay(query)
        
        If result.Count > 0 Then
            Dim collider As Node = result("collider")
            If TypeOf collider Is IInteractable Then
                CType(collider, IInteractable).Interact(Me)
            End If
        End If
    End Sub
End Class
```

### Custom Input Manager

```vb
' InputManager.vb - Advanced input management
Public Class InputManager
    Inherits Node
    
    ' Input buffer for complex inputs
    Private inputBuffer As New List(Of String)
    Private bufferTimeLimit As Single = 0.5
    Private lastInputTime As Single = 0
    
    ' Input mapping
    Private combos As New Dictionary(Of String, Action)
    
    Public Sub _Ready()
        SetupCombos()
    End Sub
    
    Private Sub SetupCombos()
        ' Define input combinations
        combos("down,down") = AddressOf PerformGroundPound
        combos("right,right") = AddressOf PerformDash
        combos("up,down,up") = AddressOf PerformSpecialMove
    End Sub
    
    Public Sub _Input(inputEvent As InputEvent)
        If TypeOf inputEvent Is InputEventKey Then
            Dim keyEvent As InputEventKey = CType(inputEvent, InputEventKey)
            If keyEvent.Pressed Then
                ProcessKeyInput(keyEvent.Keycode)
            End If
        End If
    End Sub
    
    Private Sub ProcessKeyInput(keycode As Key)
        Dim currentTime As Single = Time.GetTicksMsec() / 1000.0
        
        ' Clear buffer if too much time passed
        If currentTime - lastInputTime > bufferTimeLimit Then
            inputBuffer.Clear()
        End If
        
        ' Add input to buffer
        Dim inputName As String = KeycodeToString(keycode)
        If Not String.IsNullOrEmpty(inputName) Then
            inputBuffer.Add(inputName)
            lastInputTime = currentTime
            
            ' Check for combos
            CheckCombos()
        End If
    End Sub
    
    Private Sub CheckCombos()
        ' Build current input string
        Dim inputString As String = String.Join(",", inputBuffer)
        
        For Each combo As KeyValuePair(Of String, Action) In combos
            If inputString.EndsWith(combo.Key) Then
                combo.Value.Invoke()
                inputBuffer.Clear()
                Exit For
            End If
        Next
    End Sub
    
    Private Function KeycodeToString(keycode As Key) As String
        Select Case keycode
            Case Key.Up : Return "up"
            Case Key.Down : Return "down"
            Case Key.Left : Return "left"
            Case Key.Right : Return "right"
            Case Else : Return ""
        End Select
    End Function
    
    Private Sub PerformGroundPound()
        Print "Ground Pound!"
        ' Implement ground pound logic
    End Sub
    
    Private Sub PerformDash()
        Print "Dash!"
        ' Implement dash logic
    End Sub
    
    Private Sub PerformSpecialMove()
        Print "Special Move!"
        ' Implement special move logic
    End Sub
End Class
```

---

## Chapter 8: Timers and Processing {#timers}

### Using Godot Timers

```vb
' TimerExample.vb - Working with timers
Public Class TimerExample
    Inherits Node2D
    
    Private gameTimer As Timer
    Private spawnTimer As Timer
    Private oneTimeTimer As Timer
    
    Public Sub _Ready()
        SetupTimers()
    End Sub
    
    Private Sub SetupTimers()
        ' Create game timer (like VB6 Timer control)
        gameTimer = New Timer()
        gameTimer.Timeout += AddressOf OnGameTimerTimeout
        gameTimer.WaitTime = 1.0  ' 1 second
        gameTimer.Autostart = True
        AddChild(gameTimer)
        
        ' Enemy spawn timer
        spawnTimer = New Timer()
        spawnTimer.Timeout += AddressOf OnSpawnTimerTimeout
        spawnTimer.WaitTime = 3.0  ' Every 3 seconds
        spawnTimer.Autostart = True
        AddChild(spawnTimer)
        
        ' One-time delayed action
        oneTimeTimer = New Timer()
        oneTimeTimer.Timeout += AddressOf OnOneTimeAction
        oneTimeTimer.WaitTime = 5.0
        oneTimeTimer.OneShot = True  ' Fire only once
        AddChild(oneTimeTimer)
        oneTimeTimer.Start()
    End Sub
    
    Private Sub OnGameTimerTimeout()
        ' Called every second
        Print "Game timer tick!"
        UpdateGameClock()
    End Sub
    
    Private Sub OnSpawnTimerTimeout()
        ' Spawn an enemy every 3 seconds
        SpawnEnemy()
    End Sub
    
    Private Sub OnOneTimeAction()
        ' One-time action after 5 seconds
        Print "One-time action executed!"
        ShowWelcomeMessage()
    End Sub
    
    Private Sub UpdateGameClock()
        ' Update game clock display
        Dim clockLabel As Label = GetNode(Of Label)("UI/Clock")
        Dim gameTime As Integer = CInt(Time.GetTicksMsec() / 1000)
        clockLabel.Text = $"Time: {gameTime}s"
    End Sub
    
    Private Sub SpawnEnemy()
        ' Enemy spawning logic
        Dim enemy As PackedScene = Load(Of PackedScene)("res://scenes/Enemy.tscn")
        Dim enemyInstance As Node2D = enemy.Instantiate()
        
        ' Random spawn position
        Dim viewportSize As Vector2 = GetViewportRect().Size
        enemyInstance.Position = New Vector2(
            Rnd.RandfRange(0, viewportSize.x),
            Rnd.RandfRange(0, viewportSize.y)
        )
        
        GetParent().AddChild(enemyInstance)
    End Sub
End Class
```

### Frame-based Processing

```vb
' ProcessingExample.vb - Different types of processing
Public Class ProcessingExample
    Inherits Node2D
    
    Private frameCount As Integer = 0
    Private totalTime As Single = 0
    
    ' Called every frame (variable delta time)
    Public Sub _Process(delta As Single)
        frameCount += 1
        totalTime += delta
        
        ' Update non-physics elements
        UpdateUI(delta)
        ProcessInput(delta)
        UpdateAnimations(delta)
        
        ' FPS counter
        If frameCount Mod 60 = 0 Then  ' Every 60 frames
            Dim fps As Single = 1.0 / delta
            Print $"FPS: {fps:F1}"
        End If
    End Sub
    
    ' Called at fixed intervals (60 FPS by default)
    Public Sub _PhysicsProcess(delta As Single)
        ' Physics-related processing
        UpdatePhysics(delta)
        ProcessMovement(delta)
        CheckCollisions()
    End Sub
    
    Private Sub UpdateUI(delta As Single)
        ' UI animations and updates
        Dim scoreLabel As Label = GetNode(Of Label)("UI/Score")
        
        ' Pulse effect on score label
        Dim pulse As Single = Math.Sin(totalTime * 5.0) * 0.1 + 1.0
        scoreLabel.Scale = Vector2.One * pulse
    End Sub
    
    Private Sub UpdateAnimations(delta As Single)
        ' Non-physics animations
        Dim rotatingSprite As Sprite2D = GetNode(Of Sprite2D)("RotatingSprite")
        rotatingSprite.RotationDegrees += 90 * delta  ' 90 degrees per second
    End Sub
    
    Private Sub UpdatePhysics(delta As Single)
        ' Physics calculations
        ApplyForces(delta)
        UpdateVelocities(delta)
    End Sub
    
    Private Sub ProcessMovement(delta As Single)
        ' Movement calculations
        UpdatePlayerMovement(delta)
        UpdateEnemyMovement(delta)
    End Sub
End Class
```

### Tween Animations

```vb
' TweenExample.vb - Using tweens for smooth animations
Public Class TweenExample
    Inherits Node2D
    
    Private tween As Tween
    Private sprite As Sprite2D
    
    Public Sub _Ready()
        sprite = GetNode(Of Sprite2D)("Sprite2D")
        SetupTween()
        StartAnimations()
    End Sub
    
    Private Sub SetupTween()
        ' Create tween node
        tween = New Tween()
        AddChild(tween)
        
        ' Connect tween finished signal
        tween.TweenCompleted += AddressOf OnTweenCompleted
    End Sub
    
    Private Sub StartAnimations()
        ' Move sprite smoothly
        MoveSpriteToPosition(New Vector2(400, 300), 2.0)
    End Sub
    
    Private Sub MoveSpriteToPosition(targetPos As Vector2, duration As Single)
        ' Animate position change
        tween.TweenProperty(sprite, "position", targetPos, duration)
        tween.TweenSetEase(Tween.EaseType.Out)
        tween.TweenSetTrans(Tween.TransitionType.Cubic)
    End Sub
    
    Public Sub FadeIn(duration As Single)
        ' Fade sprite in
        sprite.Modulate = New Color(1, 1, 1, 0)  ' Start transparent
        tween.TweenProperty(sprite, "modulate:a", 1.0, duration)
    End Sub
    
    Public Sub FadeOut(duration As Single)
        ' Fade sprite out
        tween.TweenProperty(sprite, "modulate:a", 0.0, duration)
    End Sub
    
    Public Sub ScaleUp(targetScale As Single, duration As Single)
        ' Scale animation
        tween.TweenProperty(sprite, "scale", Vector2.One * targetScale, duration)
        tween.TweenSetEase(Tween.EaseType.Out)
        tween.TweenSetTrans(Tween.TransitionType.Back)
    End Sub
    
    Public Sub RotateSprite(degrees As Single, duration As Single)
        ' Rotation animation
        Dim targetRotation As Single = Math.DegToRad(degrees)
        tween.TweenProperty(sprite, "rotation", targetRotation, duration)
    End Sub
    
    Public Sub ColorShift(targetColor As Color, duration As Single)
        ' Color animation
        tween.TweenProperty(sprite, "modulate", targetColor, duration)
    End Sub
    
    Private Sub OnTweenCompleted()
        Print "Tween animation completed!"
        
        ' Chain another animation
        ScaleUp(1.2, 1.0)
    End Sub
    
    ' Complex animation sequence
    Public Sub PlayComplexAnimation()
        ' Sequence multiple tweens
        tween.TweenProperty(sprite, "position:x", 200, 1.0)
        tween.TweenCallback(AddressOf HalfwayCallback, 0.5)
        tween.TweenProperty(sprite, "rotation_degrees", 360, 1.0)
        tween.TweenProperty(sprite, "scale", Vector2.One * 1.5, 0.5)
    End Sub
    
    Private Sub HalfwayCallback()
        Print "Halfway through animation!"
    End Sub
End Class
```

*[This is the first part of the manual. The full manual would continue with all remaining chapters covering 2D/3D development, UI, advanced features, etc. The manual would be approximately 200+ pages when complete.]*

---

## Quick Reference

### Common Node Types
- **Node2D**: Base for 2D objects
- **CharacterBody2D**: Physics-based character
- **RigidBody2D**: Physics-controlled object
- **Area2D**: Trigger zones and sensors
- **Sprite2D**: Display images
- **Label**: Show text
- **Button**: Interactive buttons
- **Timer**: Timed events

### Essential Methods
- **_Ready()**: Node initialization
- **_Process(delta)**: Every-frame updates
- **_PhysicsProcess(delta)**: Fixed-rate physics
- **GetNode()**: Find child nodes
- **EmitSignal()**: Send signals
- **Connect()**: Connect to signals

### Input Actions (Set in Input Map)
- "ui_accept" - Confirm/Jump
- "ui_cancel" - Cancel/Back  
- "ui_left/right/up/down" - Directional input
- Custom actions for game-specific controls