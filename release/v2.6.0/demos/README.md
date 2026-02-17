# VisualGasic Demos

Complete, working demo programs written in VisualGasic. Each demo is a full Godot project showcasing various language features and capabilities.

## Quick Start

```bash
# Set up symlinks so all demos share the central addon
cd demos
chmod +x setup_symlinks.sh
./setup_symlinks.sh

# Then open any demo folder in Godot 4.5+
```

## Available Demos

### 🎮 2D Games

| Demo | Description | Features Demonstrated |
|------|-------------|----------------------|
| **Pong/** | Classic Pong game | Basic game loop, input, collision, drawing |
| **Pong_Advanced/** | Enhanced Pong with power-ups | **Whenever** system, DATA statements, reactive programming |
| **Space_Shooter/** | Vertical scrolling shooter | **Parallel For**, **Lambda**, pattern matching, arrays |
| **Snake/** | Classic Snake with levels | DATA for level layouts, **Whenever** for achievements |

### 🖼️ Graphics

| Demo | Description | Features Demonstrated |
|------|-------------|----------------------|
| **Screensaver/** | Retro-style screensaver | DrawRect, DrawLine, DrawCircle, DrawString, Color functions |

### 🔊 Audio

| Demo | Description | Features Demonstrated |
|------|-------------|----------------------|
| **Piano/** | Interactive piano keyboard | **PlayTone** for audio, DATA for note frequencies, recording |

### 🖥️ UI

| Demo | Description | Features Demonstrated |
|------|-------------|----------------------|
| **Calculator/** | Four-function calculator | UI layout, event handling, string formatting |
| **TodoApp/** | Full todo list application | **File I/O**, **Lambda** filtering, **Whenever** reactive stats |

### 💾 Data and Files

| Demo | Description | Features Demonstrated |
|------|-------------|----------------------|
| **HighScores/** | High score management | DATA/Read/Restore, LoadData, DataFile, sorting |

### ⚡ Threading

| Demo | Description | Features Demonstrated |
|------|-------------|----------------------|
| **ParallelDemo/** | Parallel processing showcase | **Parallel For**, **Task.Run**, **Await**, Lock/Unlock |

## Features Showcased

### Whenever System (Reactive Programming)
```vb
Whenever Section GameLogic
    Whenever score Changes
        UpdateDisplay
    End Whenever
    
    Whenever health Becomes 0
        GameOver
    End Whenever
    
    Whenever enemies Exceeds 10
        IncreaseDifficulty
    End Whenever
End Whenever Section
```

### Parallel Processing
```vb
' Distribute work across CPU cores
Parallel For i As Integer = 0 To 1000
    ProcessItem i
Next

' Async task execution
Task.Run Sub()
    DoBackgroundWork
End Sub

' Await for results
Dim result = Await Task.Run(Function() CalculateValue())
```

### DATA Statements
```vb
LevelData:
Data "Level 1", 100, 5
Data "Level 2", 200, 8
Data "END", 0, 0

Restore LevelData
Read levelName, targetScore, enemies
```

### Lambda Expressions
```vb
Dim squared = Lambda(x) x * x
Dim filtered = items.Where(Lambda(i) i.Active)
```

### File I/O
```vb
Open "user://save.dat" For Output As #1
Print #1, playerName
Print #1, score
Close #1
```

## Folder Structure

```
demos/
├── 2D_Games/
│   ├── Pong/
│   ├── Pong_Advanced/
│   ├── Space_Shooter/
│   └── Snake/
├── 3D_Games/          (coming soon)
├── Graphics/
│   └── Screensaver/
├── Audio/
│   └── Piano/
├── UI/
│   ├── Calculator/
│   └── TodoApp/
├── Data_and_Files/
│   └── HighScores/
├── Threading/
│   └── ParallelDemo/
├── Utilities/         (coming soon)
├── Networking/        (coming soon)
├── setup_symlinks.sh
└── README.md
```

## Requirements

- Godot 4.5+
- VisualGasic addon (automatically linked via setup script)

## How to Run a Demo

1. Run `./setup_symlinks.sh` once to configure all projects
2. Open any demo folder in Godot 4.5+
3. Press F5 to run

## Contributing

Want to add a demo? See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines. Demos must be:
- Complete, working programs (not snippets)
- Well-commented with explanations
- Include a README explaining what features are demonstrated
- Use pure VisualGasic (no GDScript mixing)
