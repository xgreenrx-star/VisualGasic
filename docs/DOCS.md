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
| 2 | [Installation](getting_started/installation.md) | Setting up the GDExtension plugin in a Godot 4.5+ project |
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
| [Language Reference](VisualGasic_Language_Reference.md) | **Comprehensive reference** (6500+ lines) — every keyword, statement, operator, and data type |
| [Keywords Reference](manual/keywords.md) | Core BASIC keywords and syntax quick-reference |
| [Built-in Functions](reference/BUILTIN_FUNCTIONS_REFERENCE.md) | All 108+ built-in functions with signatures and examples (Print, Input, MsgBox, Len, Mid, Val, Format, etc.) |
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
| [Immediate Window](IMMEDIATE_WINDOW.md) | **Interactive REPL console** (882 lines) — multi-line input, variable inspector, Watch tab (with VB6 property evaluation), Whenever tab, remote debugging, data breakpoints, VB6-style output formatting (True/False, no `.0`) |

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
| [Game UI Controls](tutorials/game_ui_controls.md) | Using the 23 Game UI drag-and-drop controls (InventoryGrid, StatBar, HUDCounter, etc.) |
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
| [Community Hub](../COMMUNITY_HUB.md) | Community resources and links |

---

## 📋 Project Status & Releases

| Document | Description |
|----------|-------------|
| [README](../README.md) | Project overview, feature list, screenshots, and quick start |
| [Changelog](../CHANGELOG.md) | Full change log in Keep a Changelog format (latest: v4.4.0-rc4) |
| [Roadmap](../ROADMAP.md) | Development roadmap and feature timeline |
| [Project Status](../PROJECT_STATUS.md) | Current project status summary |
| [Security Policy](../SECURITY.md) | Security policy and vulnerability reporting |
| [License](../LICENSE) | MIT License |

### Release Notes

| Version | File | Highlights |
|---------|------|------------|
| v4.4.0-rc3 | [RELEASE_NOTES_v4.4.0-rc3.md](../RELEASE_NOTES_v4.4.0-rc3.md) | IntelliSense chaining, keyword-named Subs |
| v4.4.0-rc2 | [RELEASE_NOTES_v4.4.0-rc2.md](../RELEASE_NOTES_v4.4.0-rc2.md) | Debugger UX overhaul, Set Next Statement |
| v4.4.0-rc1 | [RELEASE_NOTES_v4.4.0-rc1.md](../RELEASE_NOTES_v4.4.0-rc1.md) | Release candidate — feature-complete |
| v4.3.0 | [RELEASE_NOTES_v4.3.0.md](../RELEASE_NOTES_v4.3.0.md) | |
| v4.2.0 | [RELEASE_NOTES_v4.2.0.md](../RELEASE_NOTES_v4.2.0.md) | |
| v4.1.0 | [RELEASE_NOTES_v4.1.0.md](../RELEASE_NOTES_v4.1.0.md) | |
| v4.0.0 | [RELEASE_NOTES_v4.0.0.md](../RELEASE_NOTES_v4.0.0.md) | Major version — bytecode VM, JIT |
| v3.8.0 | [RELEASE_NOTES_v3.8.0.md](../RELEASE_NOTES_v3.8.0.md) | |
| v3.7.0 | [RELEASE_NOTES_v3.7.0.md](../RELEASE_NOTES_v3.7.0.md) | |
| v3.5.0 | [RELEASE_NOTES_v3.5.0-beta4.md](../RELEASE_NOTES_v3.5.0-beta4.md) | |
| v3.4.1 | [RELEASE_NOTES_v3.4.1.md](../RELEASE_NOTES_v3.4.1.md) | |
| v3.3.0 | [RELEASE_NOTES_v3.3.0.md](../RELEASE_NOTES_v3.3.0.md) | |
| v3.2.0 | [RELEASE_NOTES_v3.2.0-beta1.md](../RELEASE_NOTES_v3.2.0-beta1.md) | |
| v2.10.0 | [RELEASE_NOTES_v2.10.0.md](../RELEASE_NOTES_v2.10.0.md) | COM Objects, VB6 Globals, GoSub |
| v2.9.0 | [RELEASE_NOTES_v2.9.0.md](../RELEASE_NOTES_v2.9.0.md) | |
| v2.8.0 | [RELEASE_NOTES_v2.8.0.md](../RELEASE_NOTES_v2.8.0.md) | C++ Visual Gasic IDE, Live Preview |

---

## 📁 Archive

Historical development docs preserved for reference. These cover completed work and are not actively maintained.

| Document | Description |
|----------|-------------|
| [Async/JIT/REPL Status](archive/ASYNC_JIT_REPL_STATUS.md) | Implementation status of async, JIT, and REPL features |
| [Complete Implementation Summary](archive/COMPLETE_IMPLEMENTATION_SUMMARY.md) | Full summary of all implemented features |
| [Comprehensive Gap Analysis](archive/COMPREHENSIVE_GAP_ANALYSIS.md) | Feature gap analysis vs VB6 |
| [Dictionary Performance Analysis](archive/DICT_PERFORMANCE_ANALYSIS.md) | HashMap optimization analysis |
| [Integration Testing Report](archive/INTEGRATION_TESTING_FINAL_REPORT.md) | Final integration test results |
| [Modernization Summary](archive/MODERNIZATION_SUMMARY.md) | Language modernization changelog |
| [Multitasking Implementation](archive/MULTITASKING_IMPLEMENTATION_COMPLETE.md) | Threading and async implementation details |
| [Optimization Results](archive/OPTIMIZATION_RESULTS.md) | Performance optimization results |
| [Performance Reports](archive/PERFORMANCE_REPORT.md) | Historical performance benchmarks |
| [Phase 1 Checklist](archive/PHASE_1_COMPLETION_CHECKLIST.md) | Phase 1 completion status |
| [Priority Improvements](archive/PRIORITY_IMPROVEMENTS.md) | Prioritized improvement backlog |
| [Test Results](archive/TEST_RESULTS_FINAL.md) | Historical test suite results |

---

## 📰 Community & Marketing

| Document | Description |
|----------|-------------|
| [Reddit Announcement](reddit_announcement.md) | Pre-formatted Reddit announcement post |
| [Community Hub](../COMMUNITY_HUB.md) | Community resources, links, and support channels |

---

## 🗂️ Existing Index Files

These older index files are preserved but this document (`DOCS.md`) supersedes them as the primary documentation hub.

| File | Description |
|------|-------------|
| [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) | Previous detailed index with plugin file listings and demo tables |
| [DOCUMENTATION_INDEX_OLD.md](DOCUMENTATION_INDEX_OLD.md) | Legacy documentation index |
| [index.md](index.md) | Short landing page linking to getting started and manual sections |
| [archive/FILE_INDEX.md](archive/FILE_INDEX.md) | Historical file listing |

---

*Last updated: March 29, 2026 — v4.4.0-rc4*
