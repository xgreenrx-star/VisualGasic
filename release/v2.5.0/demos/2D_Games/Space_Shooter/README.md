# Space Shooter - Parallel Processing & Lambda Demo

A retro-style space shooter demonstrating VisualGasic's modern features.

## Features Demonstrated

### Lambda Expressions
```vb
' Reusable game logic as lambdas
Dim IsOnScreen = Lambda(x, y) (x >= -50 And x <= SCREEN_WIDTH + 50 And y >= -50 And y <= SCREEN_HEIGHT + 50)
Dim Distance = Lambda(x1, y1, x2, y2) Sqr((x2-x1)*(x2-x1) + (y2-y1)*(y2-y1))
Dim Collides = Lambda(x1, y1, r1, x2, y2, r2) Distance(x1, y1, x2, y2) < (r1 + r2)

' Usage
If Collides(bulletX(i), bulletY(i), 5, enemyX(j), enemyY(j), 20) Then
    ' Hit!
End If
```

### Parallel For Loops
```vb
' Update many bullets efficiently using all CPU cores
Parallel For i = 0 To MAX_BULLETS - 1
    If bulletActive(i) Then
        bulletY(i) = bulletY(i) - BULLET_SPEED * delta
        If Not IsOnScreen(bulletX(i), bulletY(i)) Then
            bulletActive(i) = False
        End If
    End If
Next

' Same for enemies and particles
Parallel For i = 0 To MAX_ENEMIES - 1
    ' Enemy AI updates...
Next
```

### DATA Statements for Game Data
```vb
EnemyTypeData:
' Name, Speed, Health, Points
Data "SCOUT", 200.0, 1, 100
Data "FIGHTER", 150.0, 2, 200
Data "BOMBER", 100.0, 3, 300
Data "ELITE", 180.0, 4, 500
Data "BOSS", 50.0, 20, 2000
Data "END", 0, 0, 0

WaveData:
' EnemyCount, TypePattern
Data 5, "SCOUT"
Data 8, "SCOUT,SCOUT,FIGHTER"
Data 1, "BOSS"
Data -1, ""
```

### Pattern Matching
```vb
Select Match enemyTypeNames(typeIdx)
    Case "SCOUT"
        enemyColor = Color("#FF4444")
    Case "FIGHTER"
        enemyColor = Color("#FF8844")
    Case "BOSS"
        enemyColor = Color("#FF0000")
    Case Else
        enemyColor = Color.White
End Select
```

### String Functions
```vb
Dim types() As String = Split(typePattern, ",")
Dim typeName As String = Trim(types(typeIdx))
```

## Controls

| Key | Action |
|-----|--------|
| A / ← | Move Left |
| D / → | Move Right |
| Space | Fire |

## Game Features

- 10 progressive waves
- 5 enemy types (Scout, Fighter, Bomber, Elite, Boss)
- Particle explosions
- Scrolling starfield
- Score tracking
- Lives system

## How to Run

1. Open this folder in Godot 4.5+
2. Make sure the VisualGasic addon is enabled
3. Run the project (F5)
