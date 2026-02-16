# Scripting with Visual Gasic

## Creating a Script

To add behavior to a node, create a script.
1.  Right-click a node in the Scene dock.
2.  Select "Attach Script".
3.  Choose **Language: VisualGasic**.
4.  Save as `Main.bas`.

## The Anatomy of a Script

A Visual Gasic script corresponds to a Class. It can define variables, constants, and subroutines.

```bas
' Member Variables
Dim Speed
Dim PlayerName

' Entry Point
Sub _Ready()
    Speed = 400
    Print "Ready!"
End Sub

' Called every frame
Sub _Process(delta)
    ' delta is time in seconds since last frame
End Sub
```

## Methods

Visual Gasic supports standard Godot virtual methods:

-   `Sub _Ready()`: Called when the node enters the scene tree.
-   `Sub _Process(delta)`: Called every graphics frame.
-   `Sub _PhysicsProcess(delta)`: Called every physics tick (60Hz default).
-   `Sub _Input(event)`: Called when an input event occurs.

## Literals and Types

| Type | Syntax |
| :--- | :--- |
| **Number** | `Dim a = 10` or `Dim b = 3.14` |
| **String** | `Dim s = "Hello World"` |
| **Boolean** | `Dim b = True` / `False` |
| **Vector2** | `Dim v = Vector2(10, 20)` |
| **Color** | `Dim c = Color(1, 0, 0)` OR `vbRed` |

## Control Flow

Visual Gasic uses keyword-based blocks.

### If/Else
```bas
If Health < 0 Then
    Die
ElseIf Health < 10 Then
    PlayLowHealthSound
Else
    Print "Healthy"
End If
```

### For Loops
```bas
For i = 0 To 9
    Print i
Next
```

### Do/While
```bas
Do
    x = x + 1
Loop While x < 100
```
