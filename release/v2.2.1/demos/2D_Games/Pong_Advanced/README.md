# Pong Advanced - Whenever System Demo

An enhanced Pong game demonstrating VisualGasic's **reactive Whenever system**.

## Whenever Features Demonstrated

### Score Monitoring
```vb
Whenever Section Player1Scores score1 Changes OnPlayer1Score
Whenever Section Player2Scores score2 Changes OnPlayer2Score
```

### Win Conditions (Becomes operator)
```vb
Whenever Section Player1Wins score1 Becomes WIN_SCORE DeclareWinner1
```

### Threshold Triggers (Exceeds operator)
```vb
Whenever Section ComboBonus comboHits Exceeds 3 ActivateComboBonus
Whenever Section SuperCombo comboHits Exceeds 7 ActivateSuperCombo
```

### Complex Expressions
```vb
Whenever Section CloseGame (score1 >= WIN_SCORE - 1 Or score2 >= WIN_SCORE - 1) ShowMatchPoint
```

### Suspend/Resume Control
```vb
Sub OnGameStateChange()
    Select Case gameState
        Case "paused"
            Suspend Whenever Player1Scores
            Suspend Whenever Player2Scores
        Case "playing"
            Resume Whenever Player1Scores
            Resume Whenever Player2Scores
    End Select
End Sub
```

## Additional Features

- **DATA Statements** - Power-up definitions stored in code
- **Combo System** - Rally tracking with reactive bonuses
- **Screen Shake** - Visual feedback on hits
- **Power-ups** - Speed, Slow, Big, Multi, Shield

## Why Use Whenever?

Traditional approach (checking every frame):
```vb
Sub _Process(delta)
    If score1 >= WIN_SCORE Then  ' Checked 60 times/second
        DeclareWinner1
    End If
End Sub
```

Whenever approach (reactive):
```vb
Whenever Section Player1Wins score1 Becomes WIN_SCORE DeclareWinner1
' Only triggers when condition actually becomes true!
```

**Benefits:**
- Cleaner, more declarative code
- No redundant condition checks
- Automatic state change detection
- Built-in debouncing and performance optimization

## Controls

| Player | Up | Down |
|--------|-----|------|
| Player 1 (Left) | W | S |
| Player 2 (Right) | ↑ | ↓ |

- **Enter** - Restart (after game over)
- **Escape** - Pause/Resume

## How to Run

1. Open this folder in Godot 4.5+
2. Make sure the VisualGasic addon is enabled
3. Run the project (F5)
