# VisualGasic: Getting Started

**Current version**: v5.6.0-beta1 · **Godot**: 4.6.1+

Welcome to **VisualGasic** — a VB6-style `.vg` language that runs as a C++ GDExtension inside Godot 4.6. This guide takes you from installation to your first working program.

---

## Quick Start (5 minutes)

### 1. Install

**Linux — one-shot bootstrap (recommended):**
```bash
git clone https://github.com/xgreenrx-star/VisualGasic.git
cd VisualGasic && ./scripts/bootstrap_install.sh
```

**Or install from Godot's Asset Library** (Method 0 in the [Installation Guide](INSTALLATION.md)) — search **VisualGasic** in the AssetLib tab, install, enable the plugin, restart Godot.

**Or grab a pre-built installer from the [latest GitHub Release](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.6.0-beta1):**

| Platform | Installer |
|----------|-----------|
| 🐧 Linux x86_64 | `VisualGasic-Installer-v5.6.0-beta1-x86_64.AppImage` |
| 🪟 Windows x64 | `VisualGasic-Installer-v5.6.0-beta1-x86_64.exe` |
| 🔧 Manual (BYO Godot) | `VisualGasic_AssetLibrary_v5.6.0-beta1.zip` — or install from Godot AssetLib |

> **Portable platform zips** are no longer published. Install Godot 4.6.1+, then use AssetLib or a release zip above.

See the [Installation Guide](INSTALLATION.md) for full details including manual plugin copy and uninstall instructions.

### 2. Create a new project

```bash
vg new MyGame
cd MyGame
```

Or from the VG Welcome launcher: click **New Project**, enter a name, pick a folder.

Then in Godot: **Project → Project Settings → Plugins → visual_gasic → Enable**, and restart if prompted.

### 3. Write your first script

Create `Hello.vg` and attach it to a Node in Godot (right-click node → Attach Script → Language: VisualGasic), or open it in the floating VG Code Editor:

```vb
' Hello.vg
Sub _Ready()
    Print "Hello, VisualGasic World!"

    Dim name As String = "player"
    Dim score As Integer = 42
    Print "Name: " & name & "  Score: " & CStr(score)
End Sub
```

Press **F5** to run. `Print` goes to Godot's Output / the VG Immediate Window.

### 4. Try the Beta Showcase (optional)

Open `samples/showcases/vg_beta_showcase/project.godot` in Godot 4.6.1, enable VisualGasic, press **F5**. **Space** skips segments. See [samples/showcases/vg_beta_showcase/README.md](../../samples/showcases/vg_beta_showcase/README.md).

---

## Learning Paths

### 🎯 New to programming?

Start with the [Getting Started series](../getting_started/) — short guides that walk you through Godot nodes, attaching scripts, and writing event handlers:

1. [Quick Start](../getting_started/QUICK_START.md) — Forms, 2D, and Narcea in one pass
2. [Introduction](../getting_started/introduction.md) — What VisualGasic is
3. [Installation](../getting_started/installation.md) — Plugin setup
4. [Nodes and Scenes](../getting_started/nodes_and_scenes.md) — Godot building blocks
5. [Scripting](../getting_started/scripting.md) — Your first `.vg` script
6. [Signals](../getting_started/signals.md) — Event-driven programming with VB6 naming

Then try the beginner tutorials:
- [Your First 2D Game](../tutorials/your_first_2d_game.md) — Dodge the Creeps-style introduction
- [Build a Calculator](../tutorials/calculator_form_designer.md) — Form / UI walkthrough

### 📐 Coming from VB6 / VBA?

Your existing syntax knowledge transfers directly. Key differences:

- Prefer **Godot’s Script / 2D / 3D editors** with floating VG panels (Code Navigator, Toolbox, Properties, Vibe Code). Legacy Form Designer / standalone shell is **experimental Alpha** — [VG IDE Alpha](../manual/VG_IDE_ALPHA.md)
- Use `Sub _Ready()` instead of (or alongside) `Form_Load` for Node2D / Control roots
- Use `Sub _Process(delta)` for per-frame logic
- `Print` outputs to Godot's debug console (and the Output / Immediate panels)
- Signal handlers are auto-wired by naming: `Sub btnOK_Click()`, `Sub tmrSpawn_Timer()`
- Use VB6 property aliases on controls: `Caption`, `Left`/`Top`/`Width`/`Height`, `Visible`, `Enabled` (not raw Godot `position.x` writes)

See [Migration Guide](MIGRATION_GUIDE.md) and [VB6 legacy import policy](IMPORTING_VB6.md) (bulk import not v6.0 core).

### 🎮 Want to make games?

Open any demo and press F5. Canonical copies live under both `demos/` and `samples/demos/` (same content):

| Demo | Location | What it shows |
|------|----------|---------------|
| Pong | `demos/2D_Games/Pong/` | Basic 2D physics, input, scoring |
| Snake | `demos/2D_Games/Snake/` | Grid movement, game loop |
| Space Shooter | `demos/2D_Games/Space_Shooter/` | Spawning, Lambdas, Parallel For |
| Galactic Defender | `demos/2D_Games/Galactic_Defender/` | Classes, inheritance |
| Calculator | `demos/UI/Calculator/` | UI + event handlers |

For a guided walkthrough, see the [Game Development Tutorial](../tutorials/GAME_DEVELOPMENT.md) or the [2D Platformer Tutorial](../tutorials/2d_platformer.md).

**Also useful early:**
- **AGCK** — Arcade Game Construction Kit (🕹️ toolbar) for no-code retro games
- **Sprite Editor** / **Vector Editor** — paint `*Sprite` / `*Vector` Data blocks and `.vgv` art
- **ScreenBox** — toolbox control that hosts classic BASIC `SCREEN` / `PSET` / `LINE` inside a normal form ([QB graphics mode](../manual/qb_graphics_mode.md))

---

## Essential Reference

| What you need | Where to look |
|---------------|---------------|
| Language syntax | [Language Reference](../VisualGasic_Language_Reference.md) |
| Built-in functions | [Built-in Functions Reference](../reference/BUILTIN_FUNCTIONS_REFERENCE.md) |
| Godot integration functions | [Godot Functions Reference](../reference/GODOT_FUNCTIONS_REFERENCE.md) |
| Toolbox controls | [Controls Reference](../reference/CONTROLS_REFERENCE.md) |
| VB6 compatibility | [VB6 Features Implementation](../reference/VB6_FEATURES_IMPLEMENTATION.md) |
| IDE keyboard shortcuts | [IDE Shortcuts](../manual/IDE_SHORTCUTS.md) |
| Debugging guide | [Debugging](../manual/debugging.md) |
| Performance benchmarks | [Performance](../manual/performance.md) |
| What's new | [Changelog](../../CHANGELOG.md) · [v5.6.0-beta1 Release Notes](../../RELEASE_NOTES_v5.6.0-beta1.md) |

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

- **[Why VisualGasic over GDScript?](VG_ADVANTAGES_OVER_GDSCRIPT.md)** — capabilities VG has that GDScript does not
- **[Plugin System](PLUGIN_SYSTEM.md)** — Build your own IDE panels and tools
- **[Advanced Features](../ADVANCED_FEATURES.md)** — Generics, lambdas, GPU computing, pattern matching
- **[ROADMAP.md](../../ROADMAP.md)** — What's planned toward v6.0 stable
