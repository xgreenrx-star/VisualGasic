# VisualGasic v2.2.1 Release Notes

## 🔧 **Bugfix Release - Native Compiler Complete**

VisualGasic v2.2.1 is a focused bugfix release that **completes the native C++ compiler** with missing statement handlers, expression support, and new operators.

**Release Date**: February 5, 2026  
**Platforms**: Windows x86_64, Linux x86_64

> 📖 **For full feature documentation, see [v2.2.0 Release Notes](../RELEASE_NOTES_v2.2.0.md)**

---

## 🆕 **What's New in v2.2.1**

### 🛠️ New Statement Handlers

The native C++ compiler now properly handles all VB-style control flow statements:

| Statement | Status | Description |
|-----------|--------|-------------|
| `Select Case` | ✅ Fixed | Multi-branch conditionals with Case/Case Else |
| `Do...Loop` | ✅ Fixed | Pre/post-condition loops (While/Until) |
| `Return` | ✅ Fixed | Function/Sub return statements |
| `Restore` | ✅ Fixed | DATA/READ pointer reset |

**Example:**
```vb
Select Case grade
    Case "A": Print "Excellent!"
    Case "B": Print "Good!"
    Case Else: Print "Keep trying!"
End Select
```

### ➕ IIf() Expression Support

The inline If expression is now fully supported:

```vb
Dim status As String = IIf(score >= 60, "Pass", "Fail")
Dim sign As Integer = IIf(x < 0, -1, 1)
```

### 🧮 New Operators

| Operator | Type | Description |
|----------|------|-------------|
| `Is` | Comparison | Object reference equality |
| `Mod` | Arithmetic | Modulo (remainder) operation |
| `Like` | Pattern | Wildcard string matching |
| `\` | Arithmetic | Integer division |

```vb
' Modulo operator
Dim remainder = 17 Mod 5  ' Returns 2

' Integer division
Dim quotient = 17 \ 5     ' Returns 3

' Pattern matching
If filename Like "*.txt" Then Print "Text file!"

' Object comparison
If obj1 Is obj2 Then Print "Same object"
```

### 🔢 New Bytecode Opcodes

| Opcode | Purpose |
|--------|---------|
| `OP_JUMP_IF_TRUE` | Conditional jump for Select Case |
| `OP_RESTORE_DATA` | Reset DATA/READ pointer |
| `OP_MOD` | Modulo operation |
| `OP_INT_DIVIDE` | Integer division |
| `OP_LIKE` | Pattern matching |

---

## 🎨 Editor Plugin Features

| Feature | Description |
|---------|-------------|
| **VG IntelliSense** | 70+ keywords, 80+ functions, Godot types |
| **VG Go To Definition** | Navigate to Sub, Function, Variable declarations |
| **VG Linter** | Static analysis (unused vars, missing End statements) |
| **VG Snippet Manager** | 30+ code templates with tab stops |
| **VG Theme Manager** | 5 themes (VB6 Classic, Modern Dark/Light, etc.) |
| **VG Recent Projects** | Track and quickly access recent .vg/.vbp projects |

---

## 🐛 Bug Fixes

- ✅ Fixed `STMT_SELECT` not handled in native compiler
- ✅ Fixed `STMT_DO` not handled in native compiler  
- ✅ Fixed `STMT_RETURN` not handled in native compiler
- ✅ Fixed `STMT_RESTORE` not handled in native compiler
- ✅ Fixed `EXPRESSION_IIF` not handled in native compiler
- ✅ Added missing `Is`, `Mod`, `Like`, `\` binary operators
- ✅ Added 5 new bytecode opcodes for complete VB compatibility

---

## 🎮 Demo Projects (Included)

| Category | Project | Description |
|----------|---------|-------------|
| **2D Games** | Pong | Classic paddle game |
| | Breakout | Brick-breaking game |
| | Snake | Snake game with growing tail |
| | Asteroids | Space shooter with wrapping |
| **UI** | Calculator | 4-function calculator |
| | TodoApp | Task list manager |
| **Graphics** | Screensaver | Animated visual effects |
| **Audio** | Piano | Musical keyboard |
| **Data** | HighScores | File I/O with scores |
| **Threading** | ParallelDemo | Multi-threaded example |

> ⚠️ **Note:** Demo projects are included for reference but may require testing with your specific Godot version.

---

## 📦 Installation

### Quick Install
1. Extract `VisualGasic_v2.2.1.zip`
2. Copy the `addons/visual_gasic/` folder to your Godot project root
3. Enable the plugin: **Project > Project Settings > Plugins**
4. Restart Godot

### Running Demo Projects
1. Copy a demo folder (e.g., `demos/2D_Games/Pong/`) to your workspace
2. Open the project in Godot 4.5+
3. The addon is already included in each demo

---

## 📁 Package Contents

### Addon (`addons/visual_gasic/`)
```
bin/
  libvisualgasic.windows.template_debug.x86_64.dll    (Windows Debug)
  libvisualgasic.windows.template_release.x86_64.dll  (Windows Release)
  libvisualgasic.linux.editor.x86_64.so               (Linux Editor)
  libvisualgasic.linux.template_debug.x86_64.so       (Linux Debug)
  libvisualgasic.linux.template_release.x86_64.so     (Linux Release)
prototypes/                                            (40+ control templates)
*.gd                                                   (GDScript plugin files)
visual_gasic.gdextension                               (Extension manifest)
plugin.cfg                                             (Plugin configuration)
```

### Demos (`demos/`)
```
2D_Games/       Pong, Breakout, Snake, Asteroids
UI/             Calculator, TodoApp
Data_and_Files/ HighScores
Graphics/       Screensaver
Audio/          Piano
Threading/      ParallelDemo
```

---

## 🔧 Requirements

- **Godot:** 4.5+ (4.5.1 recommended)
- **Platforms:** Windows x86_64, Linux x86_64
- **Architecture:** 64-bit only

---

## 📊 Upgrade from v2.2.0

This is a **drop-in replacement** for v2.2.0:

1. Delete your existing `addons/visual_gasic/` folder
2. Copy the new `addons/visual_gasic/` folder from this release
3. Restart Godot

**No code changes required** — all existing `.vg` files are fully compatible.

---

## ⚠️ Known Issues

- Dictionary operations are slower than GDScript (architectural limitation)
- macOS binaries not included (requires macOS build environment)

---

## 🔗 Links

- **Repository:** https://github.com/xgreenrx-star/VisualGasic
- **v2.2.0 Release Notes:** [RELEASE_NOTES_v2.2.0.md](../RELEASE_NOTES_v2.2.0.md)
- **Documentation:** See `docs/` folder in repository
- **Issues:** https://github.com/xgreenrx-star/VisualGasic/issues

---

## 📄 License

MIT License - Free for personal and commercial use.

---

**VisualGasic v2.2.1: Native Compiler Complete.**

*All VB control flow statements now work in the high-performance native compiler.*
