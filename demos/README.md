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
| **Screen_Space_Shaders/** | 11 full-screen 2D shader effects | ShaderMaterial, ResourceLoader, Select Case, animated _Draw scene |
| **Sky_Shaders/** | Volumetric clouds + physical sky (3D) | MeshInstance3D, StandardMaterial3D, _Input mouselook, shader parameters |

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
| **demo_async_tasks/** | Async task runner | **VGTask**, **VGTaskRunner**, background work, cancellation |

### 🔧 Utilities

| Demo | Description | Features Demonstrated |
|------|-------------|----------------------|
| **FFI/** | Load native C libraries | **NativeLibrary** load .so/.dll, call C functions, **NativeStruct** |
| **Crypto/** | Cryptography & encoding | **VGCrypto** MD5/SHA/AES, Base64, UUID, HMAC |
| **XML/** | XML processing | **VGXml** parse, XPath queries, save/load |
| **ZIP/** | ZIP archive management | **VGZip** create, read, extract archives |
| **PackageManager/** | Dependency management | **VisualGasicPackage** install, registries, versioning |

### 💾 Data and Files

| Demo | Description | Features Demonstrated |
|------|-------------|----------------------|
| **HighScores/** | High score management | DATA/Read/Restore, LoadData, DataFile, sorting |
| **ODBC/** | Database connectivity | **VGOdbc** connect, query, parameterized SQL, transactions |

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
│   ├── Screensaver/
│   ├── Screen_Space_Shaders/
│   └── Sky_Shaders/
├── Audio/
│   └── Piano/
├── UI/
│   ├── Calculator/
│   └── TodoApp/
├── Data_and_Files/
│   ├── HighScores/
│   └── ODBC/
├── Threading/
│   ├── ParallelDemo/
│   └── demo_async_tasks/
├── Utilities/
│   ├── FFI/
│   ├── Crypto/
│   ├── XML/
│   ├── ZIP/
│   └── PackageManager/
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
