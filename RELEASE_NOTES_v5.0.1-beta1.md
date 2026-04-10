# VisualGasic v5.0.1 Beta 1 — Release Notes

**Release Date**: April 9, 2026  
**Tag**: `v5.0.1-beta1`  
**Status**: 🟡 **BETA — NOT FOR PRODUCTION USE**

---

> ## ⚠️ BETA CAUTION
>
> **This is a Beta 1 pre-release.** It is provided for **evaluation and testing purposes only.**
>
> - 🚧 **UNTESTED** — This release has not undergone full QA testing across all platforms.
> - 🐛 **Expect bugs** — Features may be incomplete, unstable, or subject to change.
> - 💾 **Back up your projects** before opening them with this version.
> - 🖥️ **Windows and macOS binaries are cross-compiled** and have not been verified on native hardware.
> - 📝 Please **report issues** at [GitHub Issues](https://github.com/xgreenrx-star/VisualGasic/issues).
>
> **Do not ship games built with this Beta.** Wait for the stable release.

---

## 🚀 What's New in v5.0.1 Beta 1

This is a **major version jump** — we skipped the 4.x stable release because too many significant features landed since RC7. VisualGasic v5.0.1 introduces a full plugin system, the AGCK game construction kit, a Piskel-style sprite editor, and complete 3D game development tools.

### 🔌 Plugin System

A brand-new extensible plugin architecture for the VG IDE:

- **`VGPluginBase`** — RefCounted base class with lifecycle signals, toolbar integration, and view management
- **`VGPluginManager`** — Automatic plugin discovery from `plugins/<name>/plugin.cfg`, activation/deactivation lifecycle, toolbar button placement with mutual-exclusion view switching
- **INI-based `plugin.cfg`** — Simple declarative plugin registration
- **Developer guide** — Full documentation at `docs/guides/PLUGIN_SYSTEM.md`

### 🎮 AGCK (Adventure Game Construction Kit)

A complete retro game construction kit inspired by the Commodore 64's *Adventure Game Construction Kit*, reimagined for VisualGasic:

- **Game Settings Editor** — Game identity, world physics (gravity, friction, thrust, terminal velocity), screen edge behavior (wrap/bounce/block), player settings, display, FX channels
- **Actor Editor** — 5 actor types (Player, Enemy, Bullet, Pickup, Scenery), movement states, collision modes, death/rebirth, awards, entrance, AI behaviors, auto-shoot, sound effects, FX scripts
- **Sound Editor** — 4-voice polyphonic sound designer with bar graph note editor, 4 waveforms (Square, Sawtooth, Triangle, Noise), filter, tempo/transport controls
- **Level Editor** — 24×20 tile grid with 7 block types, painting tools, actor placement, material properties, sentry paths, level management
- **Game Builder** — Build targets (C64/Modern/HTML5), splash screen config, simulated build process
- **User manual** — Full documentation at `docs/manual/AGCK_MANUAL.md`

### 🎨 Piskel-Style Sprite Editor

- Pixel art editor built directly into the VG IDE
- Drawing tools: Pencil, Eraser, Bucket Fill, Color Picker, Line, Rectangle
- 16-color palette with custom color support
- Canvas sizes from 8×8 to 128×128
- Frame-based animation with preview playback
- Export to PNG

### 🏗️ 3D Game Development Tools

Complete 3D workflow added in the RC series, now included in v5.0.1:

- **3D Asset Import** — `.glb`/`.gltf`/`.obj`/`.fbx` import from toolbar
- **3D Properties Inspector** — Transform, material, light, camera, physics editing (35 properties)
- **Input Map Editor** — Keyboard/mouse/gamepad binding dialog with deadzone control
- **Environment Presets** — 4 one-click lighting setups (Outdoor Day, Outdoor Night, Indoor, Space)
- **Animation Editor** — Timeline, keyframes, playback controls, .glb animation import
- **Make EXE** — File → Make EXE with auto-generated export presets

### 📦 Included Demo Projects

This release ships with two complete game projects:

- **2D Platformer** (`game_projects/platformer_2d/`) — Side-scrolling platformer with player physics, tile-based levels, and collision handling
- **3D Racer** (`game_projects/racing_3d/`) — 3D racing game with 6 car models (.glb), track scene, and VG game logic

### 📚 Full Documentation Suite

76 documentation files covering:

- Getting Started guide (installation, introduction, scripting, signals, nodes & scenes)
- Language Reference (keywords, built-in functions, Godot mappings)
- IDE Tools Manual (shortcuts, debugging, performance, controls reference)
- 13 Game UI control manuals (AmmoCounter, ChatBox, Compass, MiniMap, SkillTree, etc.)
- Plugin System developer guide
- AGCK user manual
- Tutorials (2D platformer, calculator, game UI, custom controls, I/O, app development)
- Migration guide for VB6 users
- Modern features guide (generics, pattern matching, GPU computing, async)

---

## 📸 New Screenshots

79 screenshots included in `docs/screenshots/`, including these recent additions:

| Screenshot | Description |
|------------|-------------|
| ![IDE](docs/screenshots/ide_form_designer.png) | VG IDE Form Designer |
| ![Code Editor](docs/screenshots/ide_code_editor.png) | Code Editor with IntelliSense |
| ![Debug](docs/screenshots/ide_debug_breakpoint.png) | Debugger with Breakpoints |
| ![Debug Vars](docs/screenshots/ide_debug_variables.png) | Variables Panel |
| ![Object Browser](docs/screenshots/object_browser.png) | Object Browser |
| ![Themes](docs/screenshots/theme_picker_editor.png) | Theme Picker |
| ![Snippets](docs/screenshots/snippet_browser.png) | Snippet Browser |
| ![Galactic Defender](docs/screenshots/galactic_defender_demo.png) | Galactic Defender Demo |
| ![Game UI](docs/screenshots/game_ui_controls.png) | Game UI Controls |
| ![Piano](docs/screenshots/piano_demo_1.png) | Piano Demo |
| ![Pong](docs/screenshots/pong_demo.png) | Pong Demo |
| ![Menu Editor](docs/screenshots/menu_editor.png) | Menu Editor |
| ![Sky Shaders](docs/screenshots/sky_shaders_clouds.webp) | Sky Shader Demo |
| ![Screen Shaders](docs/screenshots/screen_shaders_whirl.png) | Screen Shaders |

---

## 📥 Release Assets

| Asset | Description | Platform |
|-------|-------------|----------|
| `VisualGasic-v5.0.1-beta1-linux-x86_64.zip` | Linux binaries (editor + debug + release) | Linux x86_64 |
| `VisualGasic-v5.0.1-beta1-windows-x86_64.zip` | Windows binaries (editor + debug + release) | Windows x86_64 |
| `VisualGasic-v5.0.1-beta1-macos-universal.zip` | macOS frameworks (editor + debug + release) | macOS Universal |
| `VisualGasic-v5.0.1-beta1-addon.zip` | Complete addon directory (drop into your Godot project) | All platforms |
| `VisualGasic-v5.0.1-beta1-platformer2d.zip` | 2D Platformer demo project | All platforms |
| `VisualGasic-v5.0.1-beta1-racing3d.zip` | 3D Racing demo project with car models | All platforms |
| `VisualGasic-v5.0.1-beta1-agck-plugin.zip` | AGCK game construction kit plugin | All platforms |
| `VisualGasic-v5.0.1-beta1-docs.zip` | Complete documentation (76 files + 79 screenshots) | — |

---

## 🔧 Installation

### Quick Install (Linux)
```bash
# Extract the addon zip into your Godot project
unzip VisualGasic-v5.0.1-beta1-addon.zip -d your_project/

# Or use the installer
./install.sh
```

### Quick Install (Windows)
```powershell
# Extract the addon zip into your Godot project
Expand-Archive VisualGasic-v5.0.1-beta1-addon.zip -DestinationPath your_project\

# Or use the installer
.\install.ps1
```

### Quick Install (Cross-Platform Python)
```bash
python install.py
```

### Manual Installation
1. Download `VisualGasic-v5.0.1-beta1-addon.zip`
2. Extract into your Godot 4.5+ project root
3. Enable the plugin in Project → Project Settings → Plugins
4. Create `.vg` files and start coding!

---

## ⚙️ System Requirements

- **Godot Engine**: 4.5 or later (tested with 4.6.1)
- **Operating Systems**: Linux x86_64, Windows x86_64, macOS (Intel + Apple Silicon)
- **Disk Space**: ~200MB for full installation with all binaries

---

## 🔜 Coming Next

- Community testing feedback integration
- Full QA pass across all platforms
- AGCK Game Builder — actual Godot scene generation (currently simulated)
- Sound Editor — real AudioStreamWAV synthesis
- Stable v5.0.1 release

---

## 📋 Full Changelog

See [CHANGELOG.md](CHANGELOG.md) for the complete list of changes from v4.4.0-rc7 through v5.0.1-beta.

---

*Thank you for testing VisualGasic! Your feedback helps make the stable release better.*  
*Report issues: https://github.com/xgreenrx-star/VisualGasic/issues*
