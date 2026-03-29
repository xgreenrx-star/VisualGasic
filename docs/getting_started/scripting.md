# Scripting with VisualGasic

## Creating a Script

### In the VisualGasic IDE

The VisualGasic IDE is the primary way to write code:

1. Open your project in Godot with the VisualGasic addon installed.
2. Open the **VG IDE** from the editor.
3. Use **File → New** or the Form Designer to create a new `.vg` file.
4. The code editor provides syntax highlighting, IntelliSense, and auto-indent.

### Attaching to a Node

You can also attach a script to any node:

1. Right-click a node in the Scene dock.
2. Select **Attach Script**.
3. Choose **Language: VisualGasic**.
4. Save with a `.vg` extension (e.g., `Player.vg`).

## The Anatomy of a Script

A VisualGasic script corresponds to a class attached to a Godot node. It can define variables, constants, subroutines, and functions.

```vb
' Member Variables
Dim Speed As Integer
Dim PlayerName As String

' Entry Point — called when the node enters the scene tree
Sub _Ready()
    Speed = 400
    PlayerName = "Hero"
    Print "Ready!"
End Sub

' Called every frame
Sub _Process(delta)
    ' delta is time in seconds since the last frame
    If Input.IsKeyPressed(KEY_RIGHT) Then
        Me.Position = Me.Position + Vector2(Speed * delta, 0)
    End If
End Sub
```

## Virtual Methods

VisualGasic supports all standard Godot virtual methods:

| Method | When Called |
|--------|------------|
| `Sub _Ready()` | When the node enters the scene tree |
| `Sub _Process(delta)` | Every graphics frame |
| `Sub _PhysicsProcess(delta)` | Every physics tick (60 Hz default) |
| `Sub _Input(event)` | When an input event occurs |
| `Sub _Draw()` | When the node needs to redraw (CanvasItem) |
| `Sub _EnterTree()` | When the node is added to the tree |
| `Sub _ExitTree()` | When the node is removed from the tree |

## Literals and Types

| Type | Syntax |
|:-----|:-------|
| **Integer** | `Dim a As Integer = 10` |
| **Float** | `Dim b As Single = 3.14` |
| **String** | `Dim s As String = "Hello World"` |
| **Boolean** | `Dim b As Boolean = True` |
| **Vector2** | `Dim v = Vector2(10, 20)` |
| **Color** | `Dim c = Color(1, 0, 0)` or `vbRed` |
| **Array** | `Dim arr = [1, 2, 3]` |
| **Dictionary** | `Dim d = {"key": "value"}` |

## Control Flow

VisualGasic uses English-like keyword-based blocks — no curly braces or semicolons.

### If/Else
```vb
If Health < 0 Then
    Die
ElseIf Health < 10 Then
    PlayLowHealthSound
Else
    Print "Healthy"
End If
```

### Select Case
```vb
Select Case direction
    Case "up"
        MoveUp
    Case "down"
        MoveDown
    Case Else
        Print "Unknown direction"
End Select
```

### For Loops
```vb
For i = 0 To 9
    Print i
Next

For Each enemy In enemies
    enemy.TakeDamage 10
Next
```

### Do/While
```vb
Do
    x = x + 1
Loop While x < 100
```

## Functions and Return Values

```vb
Function CalculateDamage(baseDamage As Integer, multiplier As Single) As Integer
    CalculateDamage = baseDamage * multiplier
End Function

' Or use Return
Function GetGreeting(name As String) As String
    Return "Hello, " & name & "!"
End Function
```

## Next Steps

- **[Signals](signals.md)** — Handle events and user input with VB6-style auto-wiring
- **[VisualGasic Language Reference](../VisualGasic_Language_Reference.md)** — Complete language manual
