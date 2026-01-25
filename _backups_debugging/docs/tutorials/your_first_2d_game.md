# Your First 2D Game

This tutorial will guide you through creating a simple "Dodge the Creeps" style game using Visual Gasic.

## Project Setup

1.  Open Godot Engine.
2.  Create a new project named "VisualGasicGame".
3.  Ensure the **Visual Gasic** GDExtension is compiled and present in your project binary folder.

## Scene Structure

We will create a scene with a Player, a Mob, and the game logic.

1.  **Main (Node2D)**: The root node.
2.  **Player (CharacterBody2D/KinematicBody2D)**:
    *   Sprite2D
    *   CollisionShape2D
3.  **UI (CanvasLayer)**:
    *   ScoreLabel (Label)
    *   Message (Label)
    *   StartButton (Button)

## The Script (`main.bas`)

Create a text file named `main.bas` (or `.gas`) in your project folder.

### 1. Variables and Initialization

```basic
Global Score
Global ScreenSize

Sub _Ready()
    ScreenSize = GetViewportRect().Size
    Randomize()
    Call NewGame
End Sub

Sub NewGame()
    Score = 0
    Player.Position.x = ScreenSize.x / 2
    Player.Position.y = ScreenSize.y / 2
    
    ' Hide the Start Button
    StartButton.Visible = False
    Message.Text = "Get Ready!"
End Sub
```

### 2. Player Movement

We use `_Process` to update the player each frame.

```basic
Sub _Process(delta)
    Dim velocityX = 0
    Dim velocityY = 0
    Dim speed = 400

    If Input.IsActionPressed("ui_right") Then velocityX = velocityX + 1
    If Input.IsActionPressed("ui_left") Then velocityX = velocityX - 1
    If Input.IsActionPressed("ui_down") Then velocityY = velocityY + 1
    If Input.IsActionPressed("ui_up") Then velocityY = velocityY - 1

    Dim hasMovement = False
    If velocityX <> 0 Then hasMovement = True
    If velocityY <> 0 Then hasMovement = True

    If hasMovement Then
        ' Normalize vector roughly
        ' Ideally: velocity = velocity.normalized() * speed
        Player.Velocity.x = velocityX * speed
        Player.Velocity.y = velocityY * speed
        
        Player.MoveAndSlide()
    End If
    
    ' Clamp position to screen
    If Player.Position.x < 0 Then Player.Position.x = 0
    If Player.Position.y < 0 Then Player.Position.y = 0
    If Player.Position.x > ScreenSize.x Then Player.Position.x = ScreenSize.x
    If Player.Position.y > ScreenSize.y Then Player.Position.y = ScreenSize.y
End Sub
```

### 3. Handling UI Events

When the start button is pressed:

```basic
Sub _On_StartButton_Pressed()
    Call NewGame
End Sub
```

## Running the Game

1.  Assign `main.bas` as the script for the Root node, or use the Visual Gasic runner node.
2.  Press F5 in Godot to run.

You now have a basic interactive loop!
