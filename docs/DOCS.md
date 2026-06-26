# VisualGasic Documentation Hub

**The complete documentation map for VisualGasic — a modern, event-driven BASIC language for the Godot Engine.**

This page links to every documentation file in the project, organized by topic. Whether you're a new user, a VB6 veteran, or a contributor — start here.

---

## 📚 Quick Navigation

| I want to... | Go to |
|---|---|
| Install VisualGasic | [Installation Guide](guides/INSTALLATION.md) |
| Learn the basics | [Getting Started](#-getting-started) |
| Port a VB6 project | [Importing VB6 Projects](guides/IMPORTING_VB6.md) |
| Look up a function | [Built-in Functions Reference](reference/BUILTIN_FUNCTIONS_REFERENCE.md) |
| Look up a property | [Runtime Properties Reference](reference/RUNTIME_PROPERTIES_REFERENCE.md) |
| Look up a control | [Controls Reference](reference/CONTROLS_REFERENCE.md) |
| Learn the full language | [Language Reference](VisualGasic_Language_Reference.md) |
| Use the IDE tools | [IDE Tools Guide](manual/ide_tools.md) |
| Debug my code | [Debugging Guide](manual/debugging.md) |
| Build a game | [Game Development Tutorial](tutorials/GAME_DEVELOPMENT.md) |
| Build an app | [App Development Tutorial](tutorials/APP_DEVELOPMENT.md) |
| See what's new | [Changelog](../CHANGELOG.md) |

---

## 🚀 Getting Started

New to VisualGasic? Start here and work down the list.

| # | Document | Description |
|---|----------|-------------|
| 1 | [Introduction](getting_started/introduction.md) | What VisualGasic is, why BASIC on Godot, and what makes it unique |
| 2 | [Installation](getting_started/installation.md) | Setting up the GDExtension plugin in a Godot 4.6.1+ project |
| 3 | [Nodes and Scenes](getting_started/nodes_and_scenes.md) | Core Godot concepts explained for beginners — the building blocks of every game |
| 4 | [Scripting](getting_started/scripting.md) | Creating and attaching `.vg` scripts to nodes — your first code |
| 5 | [Signals](getting_started/signals.md) | Using Godot signals with VB6-style event handlers (`btnOK_Click`, `Timer1_Timer`) |
| 6 | [Get Started Guide](guides/GET_STARTED.md) | Beginner-to-pro path — from Hello World through publishing your first game |
| 7 | [Installation Guide](guides/INSTALLATION.md) | Detailed install instructions (CLI installer, manual copy, Godot Asset Library) |

---

## 📖 Language Reference

The complete language specification and syntax reference.

| Document | Description |
|----------|-------------|
| [Language Reference](VisualGasic_Language_Reference.md) | **Comprehensive reference** (6400+ lines) — every keyword, statement, operator, and data type |
| [Keywords Reference](manual/keywords.md) | Core BASIC keywords and syntax quick-reference |
| [Built-in Functions](reference/BUILTIN_FUNCTIONS_REFERENCE.md) | All 122+ built-in functions with signatures and examples (Print, Input, MsgBox, Len, Mid, Val, Format, etc.) |
| [Godot Functions](reference/GODOT_FUNCTIONS_REFERENCE.md) | Godot-specific functions (CreateNode, AddChild, LoadScene, GetTree, etc.) |
| [Godot Quick Reference](reference/GODOT_QUICK_REF.md) | Essential Godot functions at a glance for game development |
| [API Commands](reference/commands.md) | All built-in commands and their Godot equivalents |
| [Godot API Mapping](reference/godot_mapping.md) | How VB6 PascalCase properties map to Godot's snake_case API |
| [Builtins (Developer)](BUILTINS.md) | Developer docs for built-in function dispatch and C++ extension points |

---

## 🎨 Visual Gasic IDE

The Visual Basic 6-style integrated development environment.

| Document | Description |
|----------|-------------|
| [IDE Tools Guide](manual/ide_tools.md) | **Complete IDE tools reference** — Watch Window, IntelliSense (62+ property completions), Alignment, Linting, Snippets, Themes, and more |
| [IDE Keyboard Shortcuts](manual/IDE_SHORTCUTS.md) | Every keyboard shortcut — canvas, menus, properties, code editor, debugging |
| [Controls Reference](reference/CONTROLS_REFERENCE.md) | **All 40+ Toolbox controls** with properties, events, and design-time configuration |
| [WinForms Form Guide](WINFORMS_FORM_GUIDE.md) | Creating and managing WinForms-style form windows |
| [Custom Controls Guide](guides/CUSTOM_CONTROLS.md) | Building your own `.tscn` controls with a wizard and dragging them onto forms |

---

## 🔌 Plugins & Game Construction Tools

Built-in IDE plugins for game and audio authoring — no coding required.

| Tool | Document | Description |
|------|----------|-------------|
| AGCK | [AGCK Manual](manual/AGCK_MANUAL.md) | Arcade Game Construction Kit — 5 sub-editors (Game Settings, Actors, Sounds, Levels, Build) for retro games |
| Bosca Ceoil Blue | [Bosca Ceoil Manual](manual/BOSCA_CEOIL_MANUAL.md) | Built-in chiptune / music tracker — WAV, OGG, MML export; `VGMusicPlayer` node for in-game dynamic synthesis |
| Working Nodes | [Working Nodes Manual](../addons/visual_gasic/plugins/working_nodes/WORKING_NODES_MANUAL.md) | Visual logic graph editor — Event/Action/Math nodes, smart wire routing, export to VG / 2D / 3D scene |
| Plugin System | [Plugin System Guide](guides/PLUGIN_SYSTEM.md) | Architecture reference for building your own VG IDE plugins |

---

## 🎮 3D Game Development

Tools for building complete 3D games without leaving the VisualGasic IDE.

| Feature | Menu / Location | Description |
|---------|----------------|-------------|
| Asset Import | 📦 Import button (3D toolbar) | Import `.glb`/`.gltf`/`.obj`/`.fbx` models into the scene with one click |
| 3D Properties Inspector | Properties panel (auto) | Edit Node3D transform, MeshInstance3D materials (color/metallic/roughness), Light3D settings, Camera3D FOV/clip, RigidBody3D physics |
| Input Map Editor | Tools → Input Map Editor | Visual dialog for adding keyboard, mouse, and gamepad bindings with live key capture |
| Environment Presets | 🌍 Env button (3D toolbar) | One-click sky + lighting: Outdoor Day, Outdoor Night, Indoor, Space |
| Animation Editor | Tools → Animation Editor | Create animations, insert keyframes, control playback, import from `.glb` |
| Make EXE | File → Make EXE | One-click game export with auto-generated platform export presets |

---

## 🔧 Runtime Properties & Events

How VB6 properties and events work at runtime on Godot nodes.

| Document | Description |
|----------|-------------|
| [Runtime Properties Reference](reference/RUNTIME_PROPERTIES_REFERENCE.md) | **All 62 VB6 runtime property aliases** (Text, Caption, Visible, Enabled, Left, Top, BackColor, FontSize, BackStyle, Parent, TabIndex, etc.) with Godot mappings, types, and code examples. O(1) StringName HashMap dispatch. |
| [Auto-Wiring Guide](AUTO_WIRING_GUIDE.md) | **Automatic event binding** — how `btnOK_Click()`, `txtName_Change()`, and `Timer1_Timer()` are wired automatically by naming convention. Includes programmatic `_Change` events (SET triggers `_Change`). |
| [Godot API Mapping](reference/godot_mapping.md) | PascalCase → snake_case property mapping table |

---

## 🐛 Debugging & Immediate Window

Interactive debugging, REPL, Watch Window, and data breakpoints.

| Document | Description |
|----------|-------------|
| [Debugging Guide](manual/debugging.md) | **Full debugging reference** — Debug toolbar, breakpoints, conditional breakpoints, Step Into/Over/Out, Set Next Statement, Exception Assistant, Variables panel, Watch expressions (with VB6 property eval), Call Stack, data breakpoints |
| [Immediate Window](IMMEDIATE_WINDOW.md) | **Interactive REPL console** (900+ lines) — multi-line input, variable inspector, Watch tab (with VB6 property evaluation), Whenever tab, remote debugging, data breakpoints, VB6-style output formatting (True/False, no `.0`) |

---

## ✨ Modern & Advanced Features

Features that go beyond classic VB6 — generics, lambdas, GPU, async, pattern matching.

| Document | Description |
|----------|-------------|
| [Advanced Features](ADVANCED_FEATURES.md) | Overview of the advanced type system, modern paradigms, and development tools |
| [Advanced Features Manual](ADVANCED_FEATURES_MANUAL.md) | **Deep-dive manual** (1300+ lines) — generics, pattern matching, GPU computing, REPL, debugging, with performance charts |
| [Modern Features](guides/MODERN_FEATURES.md) | All modern extensions beyond VB6 — concise, readable, backward-compatible |
| [Modern Features Overview](guides/MODERN_FEATURES_README.md) | Quick-start overview of 13 modern syntax features with examples |
| [Modern Syntax Quick Ref](reference/MODERN_SYNTAX_QUICK_REF.md) | Side-by-side comparison of traditional vs. modern syntax (arrays, dicts, lambdas) |
| [System Integration](SYSTEM_INTEGRATION.md) | **v3.0/v3.1 system-level APIs** — FFI, ODBC, Crypto, XML, ZIP, Async Tasks, Packages, IPC, Android Bridge, Memory Buffers |

---

## 🎓 Tutorials

Step-by-step guides from beginner to advanced.

### Beginner
| Tutorial | Description |
|----------|-------------|
| [Your First 2D Game](tutorials/your_first_2d_game.md) | "Dodge the Creeps"-style introduction — movement, collisions, scoring, game loop |
| [Build a Calculator](tutorials/calculator_form_designer.md) | **Beginner IDE tutorial** — place controls, set properties, write event code in the Form Designer |
| [App Development](tutorials/APP_DEVELOPMENT.md) | Building a calculator app with memory functions, step by step |

### Intermediate
| Tutorial | Description |
|----------|-------------|
| [2D Platformer](tutorials/2d_platformer.md) | Complete platformer — gravity, jumping, tile-based levels, enemies, coins, scrolling camera |
| [Game Development](tutorials/GAME_DEVELOPMENT.md) | Building a two-player Pong game from scratch |
| [File I/O and Saving](tutorials/io_and_saving.md) | Classic BASIC-style file I/O with file numbers — Open, Print #, Input #, Close |

### Advanced
| Tutorial | Description |
|----------|-------------|
| [Custom Wobbly Form](tutorials/custom_wobbly_form.md) | Creating animated form effects with custom controls and shaders |
| [Game UI Controls](tutorials/game_ui_controls.md) | Using the 16 Game UI drag-and-drop controls (InventoryGrid, StatBar, HUDCounter, etc.) |
| [Tutorials Index](../tutorials/README.md) | Master tutorial listing — 20 tutorials from Hello World to Advanced Game Dev |

---

## 🔀 Migration & Compatibility

Coming from VB6, VBA, or another language? These guides help you transition.

| Document | Description |
|----------|-------------|
| [Migration Guide](guides/MIGRATION_GUIDE.md) | Gradual migration from classic VB6 syntax to modern VisualGasic |
| [Importing VB6 Projects](guides/IMPORTING_VB6.md) | How to import `.vbp` project files and `.frm` form files into VisualGasic |
| [VB6 Features Implementation](reference/VB6_FEATURES_IMPLEMENTATION.md) | VB6 advanced feature compatibility — Class modules, Property Get/Let, Collections, Error handling |
| [VG Advantages over GDScript](guides/VG_ADVANTAGES_OVER_GDSCRIPT.md) | **19 capabilities** VG has that GDScript does not (Form Designer, JIT, GPU, REPL, threading, null safety, FFI) |

---

## ⌨️ Code Editing Features

Smart editing, completion, and refactoring tools.

| Document | Description |
|----------|-------------|
| [Bracket Completion](BRACKET_COMPLETION.md) | Smart bracket/block completion — type `}` or `]` to auto-complete `End Sub`, `End If`, etc. |
| [Bracket Completion Quick Ref](BRACKET_COMPLETION_QUICK_REF.md) | One-page quick reference card for bracket completion shortcuts |
| [Refactoring Guide](guides/REFACTORING_GUIDE.md) | Architecture refactoring patterns — splitting monolithic code into modules |

---

## 📊 Performance & Benchmarks

| Document | Description |
|----------|-------------|
| [Performance Benchmarks](manual/performance.md) | Benchmark results with charts — VisualGasic vs GDScript vs C++ |
| [Godot Programming Manual](GODOT_PROGRAMMING_MANUAL.md) | Complete manual for using VisualGasic in Godot game development |

---

## 🎮 Game UI Controls

16 purpose-built Game UI controls with full documentation.

| Control | Document |
|---------|----------|
| AmmoCounter | [AmmoCounter.md](manual/controls/AmmoCounter.md) |
| ChatBox | [ChatBox.md](manual/controls/ChatBox.md) |
| Compass | [Compass.md](manual/controls/Compass.md) |
| ConfirmDialog | [ConfirmDialog.md](manual/controls/ConfirmDialog.md) |
| DamageNumber | [DamageNumber.md](manual/controls/DamageNumber.md) |
| GamePopup | [GamePopup.md](manual/controls/GamePopup.md) |
| ItemSlot | [ItemSlot.md](manual/controls/ItemSlot.md) |
| LoadingScreen | [LoadingScreen.md](manual/controls/LoadingScreen.md) |
| MiniMap | [MiniMap.md](manual/controls/MiniMap.md) |
| QuestTracker | [QuestTracker.md](manual/controls/QuestTracker.md) |
| RadialMenu | [RadialMenu.md](manual/controls/RadialMenu.md) |
| SettingsPanel | [SettingsPanel.md](manual/controls/SettingsPanel.md) |
| SkillTree | [SkillTree.md](manual/controls/SkillTree.md) |
| TabPanel | [TabPanel.md](manual/controls/TabPanel.md) |
| Tooltip | [Tooltip.md](manual/controls/Tooltip.md) |
| XPBar | [XPBar.md](manual/controls/XPBar.md) |

---

## 🔨 Development & Contributing

Internal docs for contributors and maintainers.

| Document | Description |
|----------|-------------|
| [Implementation Status](development/IMPLEMENTATION_STATUS.md) | What's been built — error reporter, scope system, bytecode cache, property HashMap, remote debugging |
| [Debugging TODO](development/TODO_VG_DEBUGGING.md) | Debugging system implementation status and roadmap |
| [Future Optimizations](development/TODO_FUTURE_OPTIMIZATIONS.md) | Planned optimizations (dictionary perf already 2–5× faster than GDScript) |
| [Bug Testing Plan](BUG_TESTING_PLAN.md) | Systematic QA plan based on v3.1 audit |
| [Known Issues](KNOWN_ISSUES.md) | Confirmed engine bugs and limitations discovered during testing |
| [GitHub Upload Checklist](development/GITHUB_UPLOAD_CHECKLIST.md) | Release checklist for GitHub uploads |
| [Asset Library Submission](development/ASSET_LIBRARY_SUBMISSION.md) | Steps to submit to the Godot Asset Library |
| [Contributing Guide](../CONTRIBUTING.md) | How to contribute — code style, PR process, testing |
---

## 📋 Project Status & Releases

| Document | Description |
|----------|-------------|
| [README](../README.md) | Project overview, feature list, screenshots, and quick start |
| [Changelog](../CHANGELOG.md) | Full change log in Keep a Changelog format (latest: v5.2.0-Beta4) |
| [Roadmap](../ROADMAP.md) | Development roadmap and feature timeline |
| [Security Policy](../SECURITY.md) | Security policy and vulnerability reporting |
| [License](../LICENSE) | GPL-3.0

| Version | File | Highlights |
|---------|------|------------|
| **v5.2.0-Beta4** | [RELEASE_NOTES_v5.2.0-Beta4.md](../RELEASE_NOTES_v5.2.0-Beta4.md) | Current public beta release with latest installers and release packaging updates. |
| **v5.2.0-Beta1** | [RELEASE_NOTES_v5.2.0-Beta1.md](../RELEASE_NOTES_v5.2.0-Beta1.md) | **Android plugin** (GPS, step counter, permissions auto-wire), **Pass-6 namespace gap-fillers** (Camera/Crypto/Physics/Ray/Joypad/Sensor/Theme/Shader/Speaker), **358-entry Command Help DB** with see-also navigation, **AI correctness 100%** on Claude 4.5 + qwen2.5-coder:7b, Linux + Windows installers (macOS deferred). |
| v5.1.0-rc.2 | [RELEASE_NOTES_v5.1.0-rc.2.md](../RELEASE_NOTES_v5.1.0-rc.2.md) | **Welcome shell loading overhaul** (always-on-top fullscreen cover + circular spinner), **15 new Form Designer toolbox controls** (10 Standard + 5 Game UI: pixel/segmented/retro progress bars, badge, toggle switch, breadcrumbs, splits, …) |
| v5.1.0-rc.1 | [RELEASE_NOTES_v5.1.0-rc.1.md](../RELEASE_NOTES_v5.1.0-rc.1.md) | VGAssetBus/Broker/Registry, Default Editors UI, Command Palette MRU, External Watcher, Cross-asset rename rewriter, AGCK 8 templates, plugin capability lint |
| v5.1.0-Beta1 | [RELEASE_NOTES_v5.1.0-Beta1.md](../RELEASE_NOTES_v5.1.0-Beta1.md) | One-click installers (AppImage/EXE), unified ▶ Play menu, Form Designer as toggleable plugin |
| v5.0.1-beta5 | [RELEASE_NOTES_v5.0.1-beta5.md](../RELEASE_NOTES_v5.0.1-beta5.md) | Working Nodes plugin, AGCK, sprite editor, 3D tools |
| v5.0.1-beta1 | [RELEASE_NOTES_v5.0.1-beta1.md](../RELEASE_NOTES_v5.0.1-beta1.md) | Plugin system, major version jump |
| v4.4.0-rc5 | [RELEASE_NOTES_v4.4.0-rc5.md](../RELEASE_NOTES_v4.4.0-rc5.md) | Debugger stability, built-in constants |

Older release notes: see git tags / [GitHub Releases](https://github.com/xgreenrx-star/VisualGasic/releases).

---
