# VisualGasic Documentation Index

## Getting Started

- [README.md](../README.md) - Project overview and quick start
- [GET_STARTED.md](guides/GET_STARTED.md) - Installation and first steps
- [MIGRATION_GUIDE.md](guides/MIGRATION_GUIDE.md) - Migrating from VB6/VBA
- [IMPORTING_VB6.md](guides/IMPORTING_VB6.md) - Importing existing VB6 projects

## Language Reference

### Core Features
- [BUILTIN_FUNCTIONS_REFERENCE.md](reference/BUILTIN_FUNCTIONS_REFERENCE.md) - Built-in functions (Print, Input, MsgBox, etc.)
- [CONTROLS_REFERENCE.md](reference/CONTROLS_REFERENCE.md) - **Complete toolbox controls reference**
- [GODOT_FUNCTIONS_REFERENCE.md](reference/GODOT_FUNCTIONS_REFERENCE.md) - Godot integration functions
- [GODOT_QUICK_REF.md](reference/GODOT_QUICK_REF.md) - Quick reference for Godot features
- [MODERN_SYNTAX_QUICK_REF.md](reference/MODERN_SYNTAX_QUICK_REF.md) - Modern syntax features
- [VB6_FEATURES_IMPLEMENTATION.md](reference/VB6_FEATURES_IMPLEMENTATION.md) - VB6 feature compatibility

### Editor Features
- [ide_tools.md](manual/ide_tools.md) - **Complete IDE tools guide** (Watch Window, Alignment, IntelliSense, Debugging, Linting, Snippets, Themes)
- [BRACKET_COMPLETION.md](BRACKET_COMPLETION.md) - Smart bracket completion system (type `}` to auto-complete blocks)
- [BRACKET_COMPLETION_QUICK_REF.md](BRACKET_COMPLETION_QUICK_REF.md) - Quick reference for bracket completion
- [IMMEDIATE_WINDOW.md](IMMEDIATE_WINDOW.md) - Interactive debugging console

### Modern Features
- [MODERN_FEATURES_README.md](guides/MODERN_FEATURES_README.md) - Overview of modern extensions
- [MODERN_FEATURES.md](guides/MODERN_FEATURES.md) - Detailed modern feature documentation
- [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md) - Advanced language features

## API Documentation

- [SYSTEM_INTEGRATION.md](SYSTEM_INTEGRATION.md) - **v3.0/v3.1 System Integration Reference** (FFI, ODBC, Crypto, XML, ZIP, Async, Packages, System Info, Signals, Permissions, Memory, IPC, Android)
- [VisualGasic_Language_Reference.md](VisualGasic_Language_Reference.md) - **Complete language reference** (4000+ lines)
- [WINFORMS_FORM_GUIDE.md](WINFORMS_FORM_GUIDE.md) - WinForms-style form development
- [BUILTINS.md](BUILTINS.md) - Built-in functions overview

## Tutorials

- [Your First 2D Game](tutorials/your_first_2d_game.md) - Dodge the Creeps-style introduction
- [Building a 2D Platformer](tutorials/2d_platformer.md) - Complete platformer walkthrough (gravity, tile-based levels, enemies, camera)

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

### v3.0 System Integration Demos

| Demo | Location | Key Features |
|------|----------|-------------|
| **FFI** | `demos/Utilities/FFI/` | NativeLibrary, call C functions, NativeStruct |
| **Crypto** | `demos/Utilities/Crypto/` | MD5, SHA, AES-256, Base64, UUID, HMAC |
| **XML** | `demos/Utilities/XML/` | Parse, XPath queries, save/load |
| **ZIP** | `demos/Utilities/ZIP/` | Create, read, extract archives |
| **ODBC** | `demos/Data_and_Files/ODBC/` | Database connect, query, transactions |
| **Async Tasks** | `demos/Threading/` | VGTask, VGTaskRunner, background work |
| **Package Manager** | `demos/Utilities/PackageManager/` | Install, registries, semver |

### v3.1 System-Level Programming Classes

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

### Code Editing Tools
| Tool | Description | Location |
|------|-------------|----------|
| IntelliSense | Code completion with 80+ functions | Automatic in .vg files |
| Linter | Static analysis (10 issue codes) | Automatic in .vg files |
| Snippet Manager | 40+ built-in code snippets | IntelliSense suggestions |
| Code Formatter | Auto-indent, keyword capitalization | Tools menu |
| Find All References | Show all usages of a symbol | Right-click identifier |
| Go to Definition | Jump to declaration (Ctrl+Click/F12) | Any identifier |
| Rename Refactoring | Scope-aware renaming (Ctrl+R) | Any identifier |

### Form Designer Tools
| Tool | Description | Location |
|------|-------------|----------|
| Snap-to-Grid | Configurable grid snapping | 2D Canvas Toolbar |
| Alignment Toolbar | Align and distribute controls | 2D Canvas Toolbar |
| Form Preview | Live preview window with full control rendering (F5) | 2D Canvas Toolbar |
| Tab Order Editor | Set focus order | Tools menu |
| Menu Editor | Visual menu bar designer | Tools menu |
| Components Dialog | Add/remove optional controls | Project menu |
| New Form Dialog | Create forms from templates | Toolbox |

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
- [RELEASE_NOTES_v2.10.0.md](../RELEASE_NOTES_v2.10.0.md) - v2.10.0 release notes (COM Objects, VB6 Globals, GoSub, File I/O)
- [RELEASE_NOTES_v2.9.0.md](../RELEASE_NOTES_v2.9.0.md) - v2.9.0 release notes
- [RELEASE_NOTES_v2.8.0.md](../RELEASE_NOTES_v2.8.0.md) - v2.8.0 release notes (C++ Form Designer, Live Preview)
- [RELEASE_NOTES_v2.3.0.md](../RELEASE_NOTES_v2.3.0.md) - v2.3.0 release notes
- [RELEASE_NOTES_v2.4.0.md](../RELEASE_NOTES_v2.4.0.md) - v2.4.0 release notes
- [RELEASE_NOTES_v2.4.1.md](../RELEASE_NOTES_v2.4.1.md) - v2.4.1 release notes
- [RELEASE_NOTES_v2.4.2.md](../RELEASE_NOTES_v2.4.2.md) - v2.4.2 release notes

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

### Navigation & Refactoring Files
| File | Description |
|------|-------------|
| `vg_goto_definition.gd` | Go to definition support |
| `find_references_panel.gd` | Find all references UI |
| `code_navigator.gd` | Code structure browser |
| `vg_recent_projects.gd` | Recent projects tracking |
| `recent_projects_menu.gd` | Recent projects menu UI |

### Form Designer Files
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
