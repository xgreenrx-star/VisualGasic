# VisualGasic Documentation Index

## ⭐ Why VisualGasic?

- [VG_ADVANTAGES_OVER_GDSCRIPT.md](guides/VG_ADVANTAGES_OVER_GDSCRIPT.md) - **19 capabilities VG has that GDScript does not** (Form Designer, JIT, GPU, REPL, threading, null safety, FFI, and more)

## Getting Started

- [Introduction](getting_started/introduction.md) - What is VisualGasic? Why use it?
- [Installation](getting_started/installation.md) - Install scripts, manual setup, `vg` CLI
- [Nodes and Scenes](getting_started/nodes_and_scenes.md) - Godot's building blocks
- [Scripting](getting_started/scripting.md) - Writing your first VisualGasic code
- [Signals](getting_started/signals.md) - VB6-style auto-wiring and event handling
- [README.md](../README.md) - Project overview and quick start
- [GET_STARTED.md](guides/GET_STARTED.md) - Installation and first steps
- [MIGRATION_GUIDE.md](guides/MIGRATION_GUIDE.md) - Migrating from VB6/VBA
- [IMPORTING_VB6.md](guides/IMPORTING_VB6.md) - Importing existing VB6 projects

## Language Reference

### Core Features
- [BUILTIN_FUNCTIONS_REFERENCE.md](reference/BUILTIN_FUNCTIONS_REFERENCE.md) - Built-in functions (Print, Input, MsgBox, etc.)
- [CONTROLS_REFERENCE.md](reference/CONTROLS_REFERENCE.md) - **Complete toolbox controls reference** (40+ controls, Visual Gasic IDE properties)
- [GODOT_FUNCTIONS_REFERENCE.md](reference/GODOT_FUNCTIONS_REFERENCE.md) - Godot integration functions
- [GODOT_QUICK_REF.md](reference/GODOT_QUICK_REF.md) - Quick reference for Godot features
- [MODERN_SYNTAX_QUICK_REF.md](reference/MODERN_SYNTAX_QUICK_REF.md) - Modern syntax features
- [VB6_FEATURES_IMPLEMENTATION.md](reference/VB6_FEATURES_IMPLEMENTATION.md) - VB6 feature compatibility

### Editor Features
- [ide_tools.md](manual/ide_tools.md) - **Complete IDE tools guide** (Watch Window, Alignment, IntelliSense, Debugging, Linting, Snippets, Themes)
- [IDE_SHORTCUTS.md](manual/IDE_SHORTCUTS.md) - **Keyboard shortcuts & features quick-reference** (canvas, menus, properties, code editor)
- [CUSTOM_CONTROLS.md](guides/CUSTOM_CONTROLS.md) - **Creating and using custom controls** (design in Godot, add via Components, use on forms)
- [BRACKET_COMPLETION.md](BRACKET_COMPLETION.md) - Smart bracket completion system (type `}` to auto-complete blocks)
- [BRACKET_COMPLETION_QUICK_REF.md](BRACKET_COMPLETION_QUICK_REF.md) - Quick reference for bracket completion
- [IMMEDIATE_WINDOW.md](IMMEDIATE_WINDOW.md) - Interactive debugging console

### Plugin System & AGCK
- [PLUGIN_SYSTEM.md](guides/PLUGIN_SYSTEM.md) - **Plugin System Developer Guide** (architecture, base class API, plugin manager, creating plugins, AGCK as reference example)
- [AGCK_MANUAL.md](manual/AGCK_MANUAL.md) - **Arcade Game Construction Kit Manual** (5 sub-editors: Game Settings, Actors, Sounds, Levels, Build — retro game construction)

### Modern Features
- [MODERN_FEATURES_README.md](guides/MODERN_FEATURES_README.md) - Overview of modern extensions
- [MODERN_FEATURES.md](guides/MODERN_FEATURES.md) - Detailed modern feature documentation
- [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md) - Advanced language features

## API Documentation

- [SYSTEM_INTEGRATION.md](SYSTEM_INTEGRATION.md) - **System Integration Reference** (FFI, ODBC, Crypto, XML, ZIP, Async, Packages, System Info, Signals, Permissions, Memory, IPC, Android)
- [VisualGasic_Language_Reference.md](VisualGasic_Language_Reference.md) - **Complete language reference** (6400+ lines)
- [WINFORMS_FORM_GUIDE.md](WINFORMS_FORM_GUIDE.md) - WinForms-style form development
- [BUILTINS.md](BUILTINS.md) - Built-in functions overview

## Tutorials

- [Your First 2D Game](tutorials/your_first_2d_game.md) - Dodge the Creeps-style introduction
- [Building a 2D Platformer](tutorials/2d_platformer.md) - Complete platformer walkthrough (gravity, tile-based levels, enemies, camera)
- [Build a Calculator](tutorials/calculator_form_designer.md) - **Beginner Visual Gasic IDE tutorial** (place controls, set properties, write event code)

## Game Demo Projects

| Demo | Location | Key Features |
|------|----------|-------------|
| **Pixel Platformer** | `demos/2D_Games/Platformer/` | Gravity, jumping, tile-based DATA levels, enemies, coins, scrolling camera |
| **Space Shooter** | `demos/2D_Games/Space_Shooter/` | Parallel For, Lambdas, DATA waves, Select Match |
| **Snake** | `demos/2D_Games/Snake/` | Grid movement, body growth, food spawning |
| **Pong** | `demos/2D_Games/Pong/` | Two-player input, ball physics, scoring |
| **Pong Advanced** | `demos/2D_Games/Pong_Advanced/` | AI opponent, power-ups |
| **Galactic Defender** | `demos/2D_Games/Galactic_Defender/` | Full game project with scenes |
| **Calculator** | `demos/UI/Calculator/` | Input handling, `Is` type-checking, _Draw() UI |

### Application Demos

| Demo | Location | Key Features |
|------|----------|-------------|
| **VG Terminal** | `demos/Networking/VGTerminal/` | ANSI BBS terminal, WinSock TCP, 80×24 buffer, session logging, bookmarks |
| **VG Paint** | `demos/Graphics/VGPaint/` | MS Paint clone, 640×480 canvas, 9 tools, Bresenham lines, flood fill, .VGP format |
| **VG Vector** | `demos/Graphics/VGVector/` | Vector editor, animation timeline, .VGV format, onion skinning, polygon tools |
| **VG Movie** | `demos/Graphics/VGMovie/` | .VGV animation player, transport controls, timeline scrubber, zoom, built-in demo |
| **VG Music** | `demos/Audio/VGMusic/` | Strudel-style live coding, PlayTone synthesis, multi-layer, visualizer, .VGS format |

### System Integration Demos

| Demo | Location | Key Features |
|------|----------|-------------|
| **FFI** | `demos/Utilities/FFI/` | NativeLibrary, call C functions, NativeStruct |
| **Crypto** | `demos/Utilities/Crypto/` | MD5, SHA, AES-256, Base64, UUID, HMAC |
| **XML** | `demos/Utilities/XML/` | Parse, XPath queries, save/load |
| **ZIP** | `demos/Utilities/ZIP/` | Create, read, extract archives |
| **ODBC** | `demos/Data_and_Files/ODBC/` | Database connect, query, transactions |
| **Async Tasks** | `demos/Threading/` | VGTask, VGTaskRunner, background work |
| **Package Manager** | `demos/Utilities/PackageManager/` | Install, registries, semver |

### System-Level Programming Classes

| Class | Description | Platform |
|-------|-------------|----------|
| **VGSystem** | System info: hostname, CPU, RAM, disk, OS, uptime, env, locale | Linux, Windows, macOS |
| **VGSignalHandler** | OS signals: SIGINT, SIGTERM, SIGHUP, atexit | Linux, Windows, macOS |
| **VGFilePermissions** | chmod, chown, symlinks, file locking, GetAttr/SetAttr | Linux, Windows, macOS |
| **VGMemoryBuffer** | Raw Peek/Poke byte buffers, CopyMemory, HexDump, FFI pointer | All |
| **VGIPC** | Named pipes, UNIX domain sockets, shared memory | Linux, macOS (partial Windows) |
| **VGAndroidBridge** | JNI device info, permissions, intents, toast, vibrate | Android (safe no-ops elsewhere) |
| **Real Threading** | Task.Run / Parallel For / Parallel Section → std::thread | All |

## IDE Tools Reference

### Debugging Tools
| Tool | Description | Location |
|------|-------------|----------|
| Watch Window | Color-coded variable watching | Immediate Window > Watch Tab |
| Call Stack Panel | Visual call stack display | Debugger > Call Stack |
| Breakpoint Conditions | Conditional breakpoints, hit counts, tracepoints | Right-click breakpoint gutter |
| Immediate Window | Interactive REPL for debugging | Bottom Panel |

### 3D Game Development Tools
| Tool | Description | Location |
|------|-------------|----------|
| Asset Import | Import `.glb`/`.gltf`/`.obj`/`.fbx` models | 📦 Import button (3D toolbar) |
| 3D Properties Inspector | Edit transform, materials, lights, cameras, physics | Properties panel (auto for Node3D) |
| Input Map Editor | Keyboard/mouse/gamepad binding dialog | Tools → Input Map Editor |
| Environment Presets | One-click sky + lighting setups (Day/Night/Indoor/Space) | 🌍 Env button (3D toolbar) |
| Animation Editor | Create animations, keyframes, playback, .glb import | Tools → Animation Editor |
| Make EXE | One-click game export with auto export presets | File → Make EXE |

### Plugins & Game Construction Tools
| Tool | Description | Location |
|------|-------------|----------|
| Plugin System | Extensible plugin architecture for custom IDE tabs | `plugins/` directory (auto-discovered) |
| AGCK | Arcade Game Construction Kit — 5-editor retro game builder | 🕹️ AGCK toolbar button |
| Sprite Editor | Piskel-style pixel art editor with 15 tools, layers, animation | 🎨 Sprite Editor toolbar button |

### Code Editing Tools
| Tool | Description | Location |
|------|-------------|----------|
| IntelliSense | Code completion with 80+ functions, 62+ VB6 property completions | Automatic in .vg files |
| Linter | Static analysis (10 issue codes) | Automatic in .vg files |
| Snippet Manager | 40+ built-in code snippets | IntelliSense suggestions |
| Code Formatter | Auto-indent, keyword capitalization | Tools menu |
| Find All References | Show all usages of a symbol | Right-click identifier |
| Go to Definition | Jump to declaration (Ctrl+Click/F12) | Any identifier |
| Rename Refactoring | Scope-aware renaming (Ctrl+R) | Any identifier |
| Move Lines Up/Down | Shift selected line(s) (Alt+Up/Down) | Code editor |
| Duplicate Lines | Copy current line(s) below (Ctrl+Shift+D) | Code editor |
| Delete Lines | Remove entire line(s) (Ctrl+Shift+K) | Code editor |
| Multi-Caret Editing | Select next occurrence (Ctrl+D), edit multiple locations | Code editor |
| Word Wrap Toggle | Wrap long lines at the editor boundary | Right-click context menu |
| Show Whitespace Toggle | Render spaces as dots and tabs as arrows | Right-click context menu |
| Code Regions | Fold/unfold with 'Region / 'End Region comments | Code editor |
| Line Length Guideline | Vertical guide at column 80 | Code editor |
| Overtype Mode | Toggle insert/overwrite typing (Insert key) | Code editor |
| Select Line | Select entire current line (Ctrl+L) | Code editor |
| Join Lines | Merge selected lines into one (Ctrl+J) | Code editor |
| Transform Case | UPPERCASE (Ctrl+Shift+U) or lowercase (Ctrl+U) | Code editor |
| Sort Lines | Alphabetically sort selected lines | Right-click context menu |
| Go to Matching Block | Jump between If↔End If, Sub↔End Sub, etc. (Ctrl+Shift+]) | Code editor |
| Surround With | Wrap selection in If, For, Sub, Try, With, or Select Case | Right-click → Surround With |
| Expand / Shrink Selection | Widen/narrow selection by scope (Alt+Shift+Up/Down) | Code editor |
| Highlight Current Line | Subtle background tint on the active line | Code editor |
| Code Minimap | Zoomed-out file overview on the right edge | Code editor / context menu toggle |

### Visual Gasic IDE Tools
| Tool | Description | Location |
|------|-------------|----------|
| Snap-to-Grid | Configurable grid snapping | 2D Canvas Toolbar |
| Alignment Toolbar | Align and distribute controls | 2D Canvas Toolbar |
| Form Preview | Live preview window with full control rendering (F5) | 2D Canvas Toolbar |
| Tab Order Editor | Set focus order | Tools menu |
| Menu Editor | Visual menu bar designer | Tools menu |
| Components Dialog | Add/remove optional controls | Project menu |
| New Form Dialog | Create forms from templates | Toolbox |
| Ctrl+Arrow Nudge | Move controls 1px for precision | Canvas (keyboard) |
| Ctrl+Scroll Zoom | Zoom canvas 25%–400% | Canvas (mouse) |
| Form Resize Handles | Drag edges/corners to resize form | Canvas |
| Z-Order Controls | Bring to Front / Send to Back | Right-click / Format menu |
| Lock Position | Prevent accidental control moves | Right-click context menu |
| Property Filter | 🔍 Search/filter properties by name | Properties panel |
| Property Tooltips | Hover descriptions on all labels | Properties panel |
| Save All | Save form + code together (Ctrl+Shift+S) | File menu |
| Go To Line | Jump to line number (Ctrl+G) | Code editor |
| Scroll Past End | Scroll past the last line for bottom-of-file editing | Code editor |
| Smooth Scrolling | Animated scroll transitions | Code editor |
| Drag & Drop Text | Select and drag text to reposition | Code editor |
| Dirty Indicator | Asterisk `*` for unsaved changes | Status bar |

### Toolbox Controls
| Category | Controls |
|----------|----------|
| Standard | Label, TextBox, Button, CheckBox, OptionButton, ListBox, ComboBox, PictureBox, Frame, GroupBox, Timer |
| Extended | ProgressBar, HSlider, VSlider, SpinBox, HScroll, VScroll, Shape, HLine, VLine, RichText, TreeView, TabStrip, Files |
| 2D Game | Sprite, AnimatedSprite, Tilemap, RigidBody, CharacterBody, Area, Camera |
| 3D Game | MeshInstance, RigidBody3D, CharacterBody3D, Camera3D, DirectionalLight, SpotLight, OmniLight, WorldEnvironment, CSGBox |
| Optional | StatusBar, Toolbar, Animation, Calendar, DatePicker, MaskedEdit, Winsock, UpDown, ListView, ImageCombo |

### Project Tools
| Tool | Description | Location |
|------|-------------|----------|
| Recent Projects | Quick access to recent files | Tools > Recent Projects |
| Object Browser | Browse classes and methods | Tools menu |
| Project Properties | Game configuration | Tools menu |
| Theme Manager | 5 built-in syntax themes | Editor Settings |

## Project Information

### Status & Performance
- [ROADMAP.md](../ROADMAP.md) - **Development roadmap and feature status**
- [PROJECT_STATUS.md](../PROJECT_STATUS.md) - Current project status
- [IMPLEMENTATION_STATUS.md](development/IMPLEMENTATION_STATUS.md) - Current implementation status
- [performance.md](manual/performance.md) - Benchmark results with charts
- [TODO_FUTURE_OPTIMIZATIONS.md](development/TODO_FUTURE_OPTIMIZATIONS.md) - Future optimization opportunities
- [TODO_VG_DEBUGGING.md](development/TODO_VG_DEBUGGING.md) - Debugging system implementation

### Release Notes
- [CHANGELOG.md](../CHANGELOG.md) - Full change log
- [RELEASE_NOTES_v4.4.0-rc4.md](../RELEASE_NOTES_v4.4.0-rc4.md) - v4.4.0-rc4 (latest)
- [RELEASE_NOTES_v4.3.0.md](../RELEASE_NOTES_v4.3.0.md) - v4.3.0
- [RELEASE_NOTES_v4.2.0.md](../RELEASE_NOTES_v4.2.0.md) - v4.2.0
- [RELEASE_NOTES_v4.1.0.md](../RELEASE_NOTES_v4.1.0.md) - v4.1.0
- [RELEASE_NOTES_v4.0.0.md](../RELEASE_NOTES_v4.0.0.md) - v4.0.0
- [RELEASE_NOTES_v3.8.0.md](../RELEASE_NOTES_v3.8.0.md) - v3.8.0
- [RELEASE_NOTES_v3.7.0.md](../RELEASE_NOTES_v3.7.0.md) - v3.7.0
- [RELEASE_NOTES_v3.5.0-beta4.md](../RELEASE_NOTES_v3.5.0-beta4.md) - v3.5.0-beta4
- [RELEASE_NOTES_v3.4.1.md](../RELEASE_NOTES_v3.4.1.md) - v3.4.1
- [RELEASE_NOTES_v3.3.0.md](../RELEASE_NOTES_v3.3.0.md) - v3.3.0
- [RELEASE_NOTES_v3.2.0-beta1.md](../RELEASE_NOTES_v3.2.0-beta1.md) - v3.2.0-beta1
- [RELEASE_NOTES_v2.10.0.md](../RELEASE_NOTES_v2.10.0.md) - v2.10.0
- [RELEASE_NOTES_v2.9.0.md](../RELEASE_NOTES_v2.9.0.md) - v2.9.0
- [RELEASE_NOTES_v2.8.0.md](../RELEASE_NOTES_v2.8.0.md) - v2.8.0

### Development
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution guidelines
- [REFACTORING_GUIDE.md](guides/REFACTORING_GUIDE.md) - Code refactoring guide
- [COMMUNITY_HUB.md](../COMMUNITY_HUB.md) - Community resources

## Plugin Files Reference

### Core Plugin Files
| File | Description |
|------|-------------|
| `visual_gasic_plugin.gd` | Main editor plugin |
| `immediate_window.gd` | Interactive debugging console |
| `vg_debugger_plugin.gd` | Remote debugger integration |
| `vg_debug_handler.gd` | Game-side debug handler |

### IDE Feature Files
| File | Description |
|------|-------------|
| `vg_intellisense.gd` | Code completion provider |
| `vg_code_edit.gd` | Custom CodeEdit with VB6 features |
| `vg_formatter.gd` | Code formatting/beautification |
| `vg_linter.gd` | Static code analysis |
| `vg_snippet_manager.gd` | Code snippet management |
| `vg_theme_manager.gd` | Syntax highlighting themes |

### Plugin System Files
| File | Description |
|------|-------------|
| `vg_plugin_base.gd` | Base class for all VG IDE plugins (extend this) |
| `vg_plugin_manager.gd` | Plugin discovery, lifecycle, and toolbar integration manager |

### AGCK Plugin Files (plugins/agck/)
| File | Description |
|------|-------------|
| `plugin.cfg` | Plugin discovery configuration (name, script, enabled) |
| `agck_plugin.gd` | Main AGCK plugin — TabContainer with 5 sub-editors, save/load |
| `agck_game_settings.gd` | ⚙️ Game Settings — world physics, screen, lives, controls, FX |
| `agck_actor_editor.gd` | 👾 Actor Editor — 16 actors, 5 types, collision, AI, sound |
| `agck_sound_editor.gd` | 🔊 Sound Editor — 8 slots, 2 voices + filter, bar-graph synth |
| `agck_level_editor.gd` | 🗺️ Level Editor — 50 levels, 20×12 grid, 7 block types |
| `agck_game_builder.gd` | 🏗️ Game Builder — build targets, splash screen, export |

### Navigation & Refactoring Files
| File | Description |
|------|-------------|
| `vg_goto_definition.gd` | Go to definition support |
| `find_references_panel.gd` | Find all references UI |
| `code_navigator.gd` | Code structure browser |
| `vg_recent_projects.gd` | Recent projects tracking |
| `recent_projects_menu.gd` | Recent projects menu UI |

### Visual Gasic IDE Files
| File | Description |
|------|-------------|
| `alignment_toolbar.gd` | Alignment and distribution tools |
| `form_preview_toolbar.gd` | Form preview with F5 |
| `form_preview_window.gd` | Live preview window (builds real Godot controls from form data) |
| `form_editor_helper.gd` | Grid snapping and resize |
| `VGFormBase.gd` | WinForms-style form base class |
| `new_form_dialog.gd` | Form template selection dialog |
| `components_dialog.gd` | VB6-style Components dialog |
| `simple_inspector.gd` | VB6-style Properties panel |

### Control Prototypes (prototypes/)
| File | Description |
|------|-------------|
| `Calendar.gd` | Functional calendar control with date selection |
| `*.tscn` | Scene templates for all toolbox controls |

### Debugging Files
| File | Description |
|------|-------------|
| `call_stack_panel.gd` | Call stack visualization |
| `vg_breakpoint_conditions.gd` | Conditional breakpoint manager |
| `breakpoint_condition_dialog.gd` | Breakpoint condition UI |

## Examples

Located in [examples/](../examples/) directory:
- Basic examples - Simple programs to learn the language
- Intermediate examples - More complex applications
- Advanced examples - Advanced techniques and integrations

## Tests

Located in [tests/](../tests/) directory:
- Unit tests - Individual component tests
- Integration tests - Full system tests (26/26 passing)
- Benchmarks - Performance benchmarks

## Quick Links

### For New Users
1. Read [README.md](../README.md)
2. Follow [GET_STARTED.md](guides/GET_STARTED.md)
3. Review [BUILTIN_FUNCTIONS_REFERENCE.md](reference/BUILTIN_FUNCTIONS_REFERENCE.md)
4. Try examples in [examples/](../examples/)

### For VB6/VBA Users
1. Read [MIGRATION_GUIDE.md](guides/MIGRATION_GUIDE.md)
2. Check [VB6_FEATURES_IMPLEMENTATION.md](reference/VB6_FEATURES_IMPLEMENTATION.md)
3. Learn about [MODERN_FEATURES_README.md](guides/MODERN_FEATURES_README.md)
4. Follow [IMPORTING_VB6.md](guides/IMPORTING_VB6.md) for existing projects

### For Contributors
1. Read [CONTRIBUTING.md](../CONTRIBUTING.md)
2. Check [IMPLEMENTATION_STATUS.md](development/IMPLEMENTATION_STATUS.md)
3. See [TODO_FUTURE_OPTIMIZATIONS.md](development/TODO_FUTURE_OPTIMIZATIONS.md)
