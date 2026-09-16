# Galactic Defender — Tower Defense Showcase

**The ultimate VisualGasic feature showcase** — a complete tower defense game written entirely in VisualGasic, demonstrating every major language feature introduced through v2.4.1.

![Tower Defense](https://img.shields.io/badge/Genre-Tower_Defense-blue) ![Lines](https://img.shields.io/badge/Lines-850+-green) ![Features](https://img.shields.io/badge/Features-15+-gold)

## 🎮 How to Play

| Control | Action |
|---------|--------|
| **1-4** | Select tower type (Blaster / Cannon / Tesla / Missile) |
| **Click** | Place tower on empty grid cell |
| **U** | Upgrade selected tower (up to level 3) |
| **S** | Sell selected tower (60% refund) |
| **SPACE** | Start next wave |
| **R** | Restart game |

## 🏗 Tower Types (Class Inheritance)

All towers inherit from `Tower ← Entity` base classes:

| Tower | Cost | Damage | Speed | Range | Special |
|-------|------|--------|-------|-------|---------|
| 🔵 **Blaster** | 50g | 8 | Fast (3.0/s) | 130 | Single-target rapid fire |
| 🟠 **Cannon** | 100g | 30 | Slow (0.8/s) | 150 | **Splash damage** (50px radius) |
| 🔷 **Tesla** | 125g | 12 | Med (1.5/s) | 110 | **Chain lightning** (3 bounces) |
| 🟣 **Missile** | 175g | 50 | Slow (0.5/s) | 200 | **Homing projectiles** |

## 👾 Enemy Types (Class Inheritance)

All enemies inherit from `Enemy ← Entity` base classes:

| Enemy | Health | Speed | Armor | Gold | Special |
|-------|--------|-------|-------|------|---------|
| 🟢 **Scout** | 30 | Fast | 0 | 8g | Weak but numerous |
| 🟠 **Soldier** | 80 | Med | 2 | 15g | Balanced stats |
| 🔴 **Tank** | 250 | Slow | 8 | 40g | Heavy armor reduces damage |
| 🔵 **Flyer** | 45 | Fast | 0 | 20g | **Ignores path**, flies direct! |
| ❤️ **Boss** | 2000 | V.Slow | 15 | 200g | Massive health pool |

## ⭐ VisualGasic Features Demonstrated

### 1. Classes & Inheritance (v2.4.1)
```vb
Class Entity
    Public x As Single
    Public y As Single
    Function DistanceTo(otherX, otherY) As Single
        ...
    End Function
End Class

Class Tower
    Inherits Entity        ' ← Inherits x, y, DistanceTo() from Entity
    Public damage As Single
    Property Get SellValue() As Integer
        SellValue = Int(cost * 0.6) * level
    End Property
End Class

Class Blaster
    Inherits Tower         ' ← 3 levels deep: Blaster → Tower → Entity
    Sub Class_Initialize()
        towerName = "Blaster"
        damage = 8
    End Sub
End Class
```

### 2. Whenever System (Reactive Programming)
```vb
Whenever Section WaveComplete enemyCount Becomes 0 OnWaveCleared
Whenever Section LowLives lives Below 5 OnLowLives
Whenever Section ScoreBonus score Exceeds 1000 OnScoreBonus1
```

### 3. Lambda Expressions
```vb
Dim Dist = Lambda(x1, y1, x2, y2) Sqr((x2-x1)*(x2-x1) + (y2-y1)*(y2-y1))
Dim InRange = Lambda(x1, y1, x2, y2, r) Dist(x1, y1, x2, y2) <= r
```

### 4. DATA Statements
```vb
WaveData:
Data 1, 6, 1.2, "Scout,Scout,Scout,Scout,Scout,Scout"
Data 5, 12, 0.7, "Scout,Scout,Soldier,Tank,Scout,Scout,..."
Data 10, 1, 2.0, "Boss"
```

### 5. String Interpolation
```vb
Print $"Wave {wave} cleared!"
Print $"Killed {e.enemyName}! +{e.goldValue}g  Score: {score}"
```

### 6. Properties (Get/Let)
```vb
Property Get HealthPercent() As Single
    HealthPercent = health / maxHealth
End Property

Property Get EffectiveSpeed() As Single
    If slowTimer > 0 Then
        EffectiveSpeed = speed * slowFactor
    Else
        EffectiveSpeed = speed
    End If
End Property
```

### 7. Parallel For (Bulk Updates)
```vb
Parallel For i = 0 To MAX_PROJECTILES - 1
    If projActive(i) Then
        projX(i) = projX(i) + projVX(i) * delta
        ' Homing, collision detection...
    End If
Next
```

### 8. Dictionary (Stats Tracking)
```vb
Dim stats As New Dictionary
stats.Add "enemies_killed", 0
stats.Add "gold_earned", 0
stats.Item("enemies_killed") = stats.Item("enemies_killed") + 1
```

### 9. Additional Features Used
- **Select Case/Match** — Tower type switching, enemy behavior, color selection
- **For Each** — Collection iteration
- **Error Handling** — Graceful edge cases
- **Polymorphic instantiation** — `New Scout`, `New Tank`, `New Boss` via Select Case
- **`_Draw()` rendering** — Grid, path, towers, enemies, projectiles, particles, HUD
- **Const declarations** — Game configuration constants
- **Multiple function types** — Sub, Function, Property Get/Let

## 📊 Game Statistics

The game tracks stats using Dictionary:
- Enemies killed
- Gold earned
- Towers built / upgraded
- Waves cleared
- Total damage dealt

## 🗺 Level Design

12 waves with escalating difficulty:
- Waves 1-3: Scouts and Soldiers (learning phase)
- Waves 4-6: Flyers introduced (aerial threat)
- Waves 7-9: Mixed heavy assault with Tanks
- Wave 10: **BOSS BATTLE** (2000 HP!)
- Waves 11-12: Endgame gauntlet

Enemy health scales +10% per wave.

## Running

```bash
cd demos/2D_Games/Galactic_Defender
# Ensure addons/visual_gasic symlink exists
ln -sf ../../../demo/addons/visual_gasic addons/visual_gasic
# Run with Godot
/path/to/Godot --main-scene res://main.tscn
```
