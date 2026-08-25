# VisualGasic: Getting Started

**Current version**: v5.4.0-beta1 · **Godot**: 4.6.1+

Welcome to **VisualGasic** — a VB6-syntax language that runs as a C++ GDExtension inside Godot 4.6. This guide takes you from installation to your first working program.

---

## Quick Start (5 minutes)

### 1. Install

**Linux — one-shot bootstrap (recommended):**
```bash
git clone https://github.com/xgreenrx-star/VisualGasic.git
cd VisualGasic && ./scripts/bootstrap_install.sh
```

**Or install from Godot's Asset Library** (Method 0 in the [Installation Guide](INSTALLATION.md)) — search **VisualGasic** in the AssetLib tab, install, enable the plugin, restart Godot.

**Or grab a pre-built installer from the [latest GitHub Release](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.4.0-beta1):**

| Platform | Installer |
|----------|-----------|
| 🐧 Linux x86_64 | `VisualGasic-Installer-v5.4.0-beta1-x86_64.AppImage` |
| 🪟 Windows x64 | `VisualGasic-Installer-v5.4.0-beta1-x86_64.exe` |
| 📦 Portable zip | `VisualGasic_v5.4.0-beta1_linux_x86_64.zip` |

See the [Installation Guide](INSTALLATION.md) for full details including manual plugin copy and uninstall instructions.

### 2. Create a new project

```bash
vg new MyGame
cd MyGame
```

Or from the VG Welcome launcher: click **New Project**, enter a name, pick a folder.

### 3. Write your first script

Create `Hello.vg` and attach it to a Node in Godot, or use the VG IDE's built-in code editor:

```vb
' Hello.vg
Sub _Ready()
    Print "Hello, VisualGasic World!"

    Dim name As String = "player"
    Dim score As Integer = 42
    Print "Name: " & name & "  Score: " & str(score)
End Sub
```

Press **F5** to run.

---

## Learning Paths

### 🎯 New to programming?

Start with the [Getting Started series](../getting_started/) — four short guides that walk you through Godot nodes, attaching scripts, and writing event handlers:

1. [Introduction](../getting_started/introduction.md) — What VisualGasic is
2. [Installation](../getting_started/installation.md) — Plugin setup
3. [Scripting](../getting_started/scripting.md) — Your first `.vg` script
4. [Signals](../getting_started/signals.md) — Event-driven programming with VB6 naming

Then try the beginner tutorials:
- [Your First 2D Game](../tutorials/your_first_2d_game.md) — Dodge the Creeps-style introduction
- [Build a Calculator](../tutorials/calculator_form_designer.md) — Form Designer walkthrough

### 📐 Coming from VB6 / VBA?

Your existing syntax knowledge transfers directly. Key differences:

- Attach scripts to Godot nodes instead of forms (though Form Designer is built in)
- Use `Sub _Ready()` instead of `Form_Load`
- Use `Sub _Process(delta)` instead of a Timer at the top level
- `Print` outputs to Godot's debug console (and to the Output panel in the IDE)
- Signal handlers are auto-wired by naming convention: `Sub btnOK_Click()`, `Sub tmrSpawn_Timer()`

See the full [Migration Guide](MIGRATION_GUIDE.md) and [Importing VB6 Projects](IMPORTING_VB6.md).

### 🎮 Want to make games?

VisualGasic ships with 13 playable demo projects. Open any of them and press F5:

| Demo | Location | What it shows |
|------|----------|---------------|
| Pong | `demos/2D_Games/Pong/` | Basic 2D physics, input, scoring |
| Snake | `demos/2D_Games/Snake/` | Grid movement, game loop |
| Space Shooter | `demos/2D_Games/Space_Shooter/` | Spawning, Lambdas, Parallel For |
| Galactic Defender | `demos/2D_Games/Galactic_Defender/` | Classes, 3-level inheritance |
| Calculator | `demos/UI/Calculator/` | Form Designer, event handlers |

For a guided walkthrough, see the [Game Development Tutorial](../tutorials/GAME_DEVELOPMENT.md) (builds Pong from scratch) or the [2D Platformer Tutorial](../tutorials/2d_platformer.md).

The **AGCK (Arcade Game Construction Kit)** lets you build a complete playable game with no code — click the 🕹️ AGCK toolbar button to open it.

---

## Essential Reference

| What you need | Where to look |
|---------------|---------------|
| Language syntax | [Language Reference](../VisualGasic_Language_Reference.md) |
| Built-in functions | [Built-in Functions Reference](../reference/BUILTIN_FUNCTIONS_REFERENCE.md) |
| Godot integration functions | [Godot Functions Reference](../reference/GODOT_FUNCTIONS_REFERENCE.md) |
| All 40+ toolbox controls | [Controls Reference](../reference/CONTROLS_REFERENCE.md) |
| VB6 compatibility | [VB6 Features Implementation](../reference/VB6_FEATURES_IMPLEMENTATION.md) |
| IDE keyboard shortcuts | [IDE Shortcuts](../manual/IDE_SHORTCUTS.md) |
| Debugging guide | [Debugging](../manual/debugging.md) |
| Performance benchmarks | [Performance](../manual/performance.md) |
| What's new | [Changelog](../../CHANGELOG.md) · [v5.4.0-beta1 Release Notes](../../RELEASE_NOTES_v5.4.0-beta1.md) |

---

## The `vg` CLI

The `vg` command-line tool manages projects and packages:

```bash
vg new MyGame          # Create a new VG project
vg run MyGame          # Run a project headlessly
vg pkg install Lib     # Install a package from the registry
vg pkg publish         # Publish your package
vg help                # Show all commands
```

---

## Next Steps

- **[Why VisualGasic over GDScript?](VG_ADVANTAGES_OVER_GDSCRIPT.md)** — 19 concrete capabilities VG has that GDScript does not
- **[Plugin System](PLUGIN_SYSTEM.md)** — Build your own IDE panels and tools
- **[Advanced Features](../ADVANCED_FEATURES.md)** — Generics, lambdas, GPU computing, pattern matching
- **[ROADMAP.md](../../ROADMAP.md)** — What's planned for v5.2 stable and beyond

