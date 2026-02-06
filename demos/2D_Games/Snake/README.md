# Snake - DATA & Whenever Demo

Classic Snake game demonstrating DATA statements and the Whenever system.

## Features Demonstrated

### DATA Statements for Game Data
```vb
FoodTypeData:
' Name, Points, R, G, B
Data "Apple", 10, 255, 0, 0
Data "Cherry", 20, 255, 0, 100
Data "Banana", 15, 255, 255, 0
Data "END", 0, 0, 0, 0

LevelData:
' Name, MoveInterval, TargetScore
Data "Grassland", 0.15, 500
Data "Forest", 0.12, 1000
Data "END", 0, 0

Level2Walls:
Data 5, 5
Data 5, 18
Data -1, 0
```

### Whenever for Game State
```vb
' Score milestones
Whenever Section ScoreMilestone score Exceeds 1000 ShowMilestoneBonus

' Level completion (dynamic target)
Whenever Section LevelComplete score Exceeds GetLevelTarget() AdvanceLevel

' Speed boost monitoring
Whenever Section SpeedBoostEnd speedBoostTimer Below 0 EndSpeedBoost

' Achievement system
Whenever Section LongSnake snakeLength Exceeds 20 ShowLengthAchievement
```

### Suspend/Resume for State Management
```vb
Sub OnStateChange()
    Select Case gameState
        Case "playing"
            Resume Whenever ScoreMilestone
        Case "paused", "gameover"
            Suspend Whenever ScoreMilestone
    End Select
End Sub
```

### Restore for Level Loading
```vb
Sub LoadLevelWalls()
    Select Case level
        Case 2
            Restore Level2Walls
            ReadWalls
        Case 3
            Restore Level3Walls
            ReadWalls
    End Select
End Sub
```

## Game Features

- **5 Levels** with increasing difficulty
- **6 Food Types** with different point values
- **4 Power-ups**: Speed, Slow, Shrink, Points
- **Wall Obstacles** in later levels
- **Achievement System** via Whenever

## Controls

| Key | Action |
|-----|--------|
| W / ↑ | Move Up |
| S / ↓ | Move Down |
| A / ← | Move Left |
| D / → | Move Right |
| ESC | Pause |

## How to Run

1. Open this folder in Godot 4.5+
2. Make sure the VisualGasic addon is enabled
3. Run the project (F5)
