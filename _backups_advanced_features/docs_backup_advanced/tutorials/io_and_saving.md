# Saving and Loading Data

Handling files is essential for saving game progress, high scores, or configuration settings. Visual Gasic provides a robust set of File I/O commands inspired by classic BASIC.

## Basic File Operations

Visual Gasic uses **File Numbers** (1, 2, 3...) to identify open files. 

### Writing to a File

To save data, use `Output` mode.

```basic
Sub SaveGame()
    Dim f = 1
    Open "user://savegame.dat" For Output As f
    
    Print #f, Player.Score
    Print #f, Player.Name
    Print #f, Player.Position.x
    Print #f, Player.Position.y
    
    Close f
End Sub
```

> **Note:** We use `user://` path prefix. This is a special Godot path that maps to a safe, writable directory on the player's device (e.g., AppData on Windows).

### Reading from a File

To load data, use `Input` mode.

```basic
Sub LoadGame()
    ' Check if file exists using Godot's FileAccess (Future feature)
    ' For now, ensure file exists or handle error
    
    Dim f = 1
    Open "user://savegame.dat" For Input As f
    
    Line Input #f, Player.Score
    Line Input #f, Player.Name
    
    Dim tempX = 0
    Dim tempY = 0
    Line Input #f, tempX
    Line Input #f, tempY
    
    Player.Position.x = tempX
    Player.Position.y = tempY
    
    Close f
End Sub
```

## Advanced: CSV and Structured Data

You can use loops to save complex data like high score lists.

```basic
Sub SaveHighScores()
    Dim f = FreeFile()
    Open "user://scores.txt" For Output As f
    
    For i = 0 To 9
        Print #f, HighScores(i)
    Next
    
    Close f
End Sub
```

## Using `FreeFile`

Hardcoding file numbers (like `1`) can lead to conflicts if you open multiple files. Use `FreeFile()` to get an available number.

```basic
Dim fileNum = FreeFile()
Open "data.txt" For Output As fileNum
' ...
Close fileNum
```
