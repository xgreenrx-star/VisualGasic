# VisualGasic — A Modern Language for Godot 4

[![CI](https://github.com/xgreenrx-star/VisualGasic/actions/workflows/ci.yml/badge.svg)](https://github.com/xgreenrx-star/VisualGasic/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-4.4.0--rc1-blue.svg)](https://github.com/xgreenrx-star/VisualGasic/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Godot](https://img.shields.io/badge/Godot-4.5+-purple.svg)](https://godotengine.org)

**World-Class RAD Platform**: A modern, forward-looking programming language with **event-driven programming**, cutting-edge features including multitasking, advanced type system, pattern matching, GPU computing, and comprehensive development tools.

> **VisualGasic is not a VB6 clone.** It is a modern language that draws inspiration from VB6's approachable syntax and ease of learning, while introducing advanced features that go well beyond what VB6 ever offered. VG is VB6-*compatible* where it makes sense — you can port VB6 projects and feel at home immediately — but the language itself is designed to look forwards, not backwards.

> 🚀 **Release Candidate** — v4.4.0-rc1 is feature-complete with cross-platform binaries, installers, and IDE project creation. Community testing welcome! [See release notes](RELEASE_NOTES_v4.4.0-rc1.md).

## 🚀 **Key Features**

### **Event-Driven Programming** *(Unique to VisualGasic)*
- **Automatic event binding** — Name a Sub `btnSave_Click()` and it's wired automatically. No manual `connect()` calls.
- **Timer events** — `Sub tmrSpawn_Timer()` fires automatically. No signal boilerplate.
- **Godot signal integration** — `Sub Player_AreaEntered(area)` just works by naming convention.
- **Visual Gasic IDE events** — Double-click any control → event handler Sub is created and connected.
- No other Godot language offers this workflow. GDScript, C++, and C# all require explicit signal wiring.

### **Core Language**
- **Clean, Familiar Syntax** — Inspired by VB6's simplicity; VB6-compatible where it counts, modern where it matters
- **Classes & Objects** - `Class...End Class`, `New`, `Property Get/Let/Set`, `Class_Initialize`
- **Class Inheritance** - `Inherits`, `MyBase`, `MustOverride`, `Overrides`, multi-level chains
- **Lambda Expressions** - `Lambda`, `Fn`, `Function`, `Sub` with optional `=>` arrow
- **Block Lambdas** - Multi-statement `Function(x) ... Return ... End Function`
- **Functional Programming** - `Map`, `Filter`, `Reduce`, `Any`, `All`, `Find`
- **Null Safety** - `??` null-coalescing and `?.` optional access
- **Erase Statement** - Clear/reset arrays with `Erase arr`
- **ReDim Preserve** - Resize arrays while keeping existing data
- **Try/Catch/Finally** - Structured exception handling
- **Select Case** - Multi-value, range, and comparison matching
- **For Each** - Collection iteration for arrays and dictionaries
- **Advanced Type System** - Generics, optional types, union types, type inference
- **Pattern Matching** - VB.NET-style Select Match with destructuring
- **Multitasking** - Native async/await, parallel processing, task coordination

### **High-Performance Computing**
- **GPU Acceleration** - SIMD vector operations and compute shaders
- **Parallel Processing** - Automatic GPU/CPU fallback for optimal performance
- **Memory Optimization** - Efficient memory management and leak detection
- **JIT Compilation** - 5-tier JIT stack (Tier 0 interpreter → 0.5 loop → 1 AST → 2 function body x86-64 → 3 call graph) with function inlining

### **Professional Development Tools**
- **IntelliSense** - Code completion with 80+ functions, 62+ VB6 property completions, snippets, and Godot types
- **Interactive REPL** - Live coding with variable inspection and session management
- **Language Server Protocol** - Intelligent IDE integration with completion and diagnostics
- **Advanced Debugger** - Conditional breakpoint expressions, Stop statement, call stack, watch window, time-travel debugging
- **Code Linting** - Static analysis with 10 issue codes (VG001-VG010)
- **Snippet Manager** - 40+ built-in snippets with custom snippet support
- **Theme Support** - 8 built-in themes with full IDE chrome theming + Custom Theme Editor
- **Visual Gasic IDE** - Full C++ WYSIWYG form editor with VB6-style Toolbox, Properties Panel, live Preview, 40+ controls
- **Full Property Wiring** - 62+ VB6 runtime property aliases with O(1) StringName HashMap dispatch, including Font, Colors, Border sub-resources, and `_Change` event firing on programmatic SET
- **Game UI Controls** - 7 Tier 1 animated controls: DialogPanel, InventoryGrid, StatBar, HUDCounter, CooldownButton, NotificationToast, GameMenu
- **IDE Bottom Panel** - Draggable VSplitContainer with Immediate Window (REPL), Output (Debug.Print + lifecycle), and System Console (live Godot log tailing)
- **Database Controls** - VGRecordset (ADODB.Recordset API), Data/DBGrid/DBCombo toolbox controls, SQL queries at design time
- **Package Manager** - `vg pkg` CLI, `vg.json` manifests, GitHub-backed registry, GUI Package Browser panel
- **Multi-Module Compilation** - Cross-file `Import` with project-wide symbol tables and circular import detection
- **Visual Form Debugger** - Controls Inspector panel with tree view, click-to-source, debugger integration

### **VB6-Style Visual Gasic IDE**

![Form Designer](docs/screenshots/ide_form_designer.png)

*Form Designer: Toolbox (40+ controls) · WYSIWYG Canvas · Properties Panel · Project Explorer · Alignment Toolbar · Live Preview*

![Code Editor with Bottom Panel](docs/screenshots/ide_bottom_panel.png)

*Code Editor: Procedure navigation · Command Help panel · Tabbed bottom panel (Immediate Window, Output, System Console)*

![Code Editor](docs/screenshots/ide_code_editor.png)

*Code view: Left panel with Command Help & Index Map · Syntax-highlighted editor · Draggable split with bottom panel*

### **Immediate Window & Debugging**

![Immediate Window](docs/screenshots/ide_immediate_window.png)

*Interactive REPL: Execute expressions live · Inspect variables · Remote debugging · Data breakpoints*

### **Command Help & IDE Tools**

![Command Help](docs/screenshots/ide_command_help.png)

*Command Help panel: VB6-style keyword reference · Index Map for quick lookup · Cream-themed classic look*

### **Custom Theme Editor**

![Theme Editor](docs/screenshots/theme_picker_editor.png)

*8 built-in themes + Custom Theme Editor with 38 adjustable colors and live preview*

### **Game UI Controls**

![Game UI Controls](docs/screenshots/game_ui_controls.png)

*7 Tier 1 animated controls: DialogPanel · InventoryGrid · StatBar · HUDCounter · CooldownButton · NotificationToast · GameMenu*

### **Game Development**
- **Entity Component System** - High-performance ECS with archetype optimization
- **Godot Integration** - Native scene tree synchronization and node management
- **Godot Singleton Access** - All 37 engine singletons (Engine, OS, Time, Input, DisplayServer, AudioServer, etc.)
- **Godot Enum Constants** - `ClassName.CONSTANT_NAME` for all class enums with keyword-safe resolution
- **Built-in Components** - Transform, Velocity, Render, and custom component support

### **System-Level Programming** *(New in v3.1)*
- **System Info** - Hostname, CPU, RAM, disk, OS, uptime, environment, locale via `VGSystem`
- **OS Signals** - SIGINT/SIGTERM/SIGHUP/atexit handling via `VGSignalHandler`
- **File Permissions** - chmod, chown, symlinks, file locking, VB6 GetAttr/SetAttr via `VGFilePermissions`
- **Raw Memory** - Peek/Poke byte-level buffers, CopyMemory, HexDump, FFI pointers via `VGMemoryBuffer`
- **IPC** - Named pipes, UNIX domain sockets, shared memory via `VGIPC`
- **Real Threading** - Task.Run/Parallel For/Parallel Section backed by real `std::thread`
- **Android Bridge** - JNI device info, permissions, intents, toast, vibrate via `VGAndroidBridge`

## 📁 **Project Structure**

```
VisualGasic/
├── src/                          # Core implementation
│   ├── visual_gasic_*.cpp/.h    # Language core, parser, AST
│   ├── visual_gasic_repl.*      # Interactive REPL system
│   ├── visual_gasic_gpu.*       # GPU computing and SIMD
│   ├── visual_gasic_lsp.*       # Language server protocol
│   ├── visual_gasic_debugger.*  # Advanced debugging tools
│   ├── visual_gasic_linter.*    # Static analysis & warnings
│   ├── visual_gasic_optimizer.* # Bytecode peephole optimizer
│   ├── visual_gasic_package.*   # Package management
│   ├── visual_gasic_recordset.* # Database Controls (VGRecordset)
│   ├── visual_gasic_jit_tier3.* # JIT Tier 3 call graph compilation
│   └── visual_gasic_ecs.*       # Entity component system
│   ├── visual_gasic_system.*    # System info (hostname, CPU, RAM, OS)
│   ├── visual_gasic_signal_handler.* # OS signal handling
│   ├── visual_gasic_file_permissions.* # chmod, chown, symlinks, locking
│   ├── visual_gasic_memory_buffer.*   # Raw Peek/Poke byte buffers
│   ├── visual_gasic_ipc.*       # Named pipes, sockets, shared memory
│   └── visual_gasic_android_bridge.*  # JNI Android bridge
├── docs/                        # Comprehensive documentation
│   ├── reference/              # API and syntax references
│   ├── guides/                 # Getting started and tutorials
│   ├── development/            # Implementation status and TODOs
│   └── archive/                # Historical documentation
├── demo/                        # Godot test project
├── examples/                    # Example VisualGasic projects
├── tests/                       # Test suite
├── godot-cpp/                   # Godot C++ bindings (submodule)
└── addons/visual_gasic/         # Godot plugin files
```

## ⚡ **Quick Start**

### **Prerequisites**
- **Godot 4.5+** (4.6.1 recommended) — Download from [godotengine.org](https://godotengine.org)

### **Installation**

**From Godot Asset Library (Easiest):**
1. Open your Godot project
2. Go to **AssetLib** tab → Search **"VisualGasic"**
3. Click **Download** → **Install**
4. Enable the plugin: **Project → Project Settings → Plugins → VisualGasic ✓**

**Using the `vg` CLI (Fastest for new projects):**
```bash
# Install (one time)
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.sh | bash

# Create a new project with VG pre-installed
vg new MyGame
cd MyGame && godot .
```
The `vg` CLI stores the addon globally so you never need to copy it manually. See `vg help` for all commands.

**From the VG IDE (inside Godot):**
1. In an existing VG project, go to **File → New Project...**
2. Enter a name and pick a folder
3. A new VG-ready project is created and opened

**From GitHub Release:**
1. Download from [Releases](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v4.3.0)
2. Copy the `addons/visual_gasic/` folder into your project's `addons/` directory
3. Enable the plugin: **Project → Project Settings → Plugins → VisualGasic ✓**

**Build from Source** (for contributors):
```bash
git clone --recurse-submodules https://github.com/xgreenrx-star/VisualGasic.git
cd VisualGasic
scons platform=linux target=editor -j$(nproc)   # or platform=windows / platform=macos
```
See [INSTALLATION.md](docs/guides/INSTALLATION.md) for full build instructions.

## 🎯 **Usage Examples**

### **Basic VisualGasic Script**
```vb
' hello_world.vg
Sub Main()
    Print "Hello, VisualGasic World!"
    
    ' Advanced type system
    Dim numbers As List(Of Integer) = {1, 2, 3, 4, 5}
    
    ' Pattern matching
    Select Match numbers.Count
        Case 0
            Print "Empty list"
        Case Is Integer n When n > 3
            Print "List has " & n & " items"
        Case Else
            Print "Small list"
    End Select
End Sub
```

### **Async/Await Multitasking**
```vb
Async Function LoadDataAsync() As Task(Of String)
    Await Task.Delay(1000)  ' Simulate network delay
    Return "Data loaded!"
End Function

Sub Main()
    Dim result As String = Await LoadDataAsync()
    Print result
End Sub
```

### **GPU Computing**
```vb
Sub PerformVectorMath()
    Dim gpu As New VGGpu
    gpu.Initialize

    Dim a = Array(1.0, 2.0, 3.0, 4.0)
    Dim b = Array(2.0, 3.0, 4.0, 5.0)
    
    ' GPU-accelerated vector operations (CPU fallback)
    Dim sum = gpu.VectorAdd(a, b)       ' {3, 5, 7, 9}
    Dim dot = gpu.DotProduct(a, b)      ' 40
    Dim avg = gpu.VectorAverage(a)      ' 2.5
    Print "Sum: " & str(sum) & " Dot: " & str(dot)
End Sub
```

### **Interactive Development**
```bash
# Start REPL for live coding
gasic repl

# Package management
gasic pkg install MathLibrary@^2.1.0
gasic pkg publish MyAwesomeLib

# Advanced debugging
gasic debug --time-travel MyProject.vg
```

## 🎮 **Demo Projects (Included in Release)**

VisualGasic ships with **14 playable demo projects** — open any of them in Godot and hit F5:

| Demo | Type | Description |
|------|------|-------------|
| Pong | 2D Game | Classic 2-player Pong with AI paddle |
| Pong Advanced | 2D Game | Enhanced Pong with particles and power-ups |
| Snake | 2D Game | Classic Snake with score tracking |
| Space Shooter | 2D Game | Scrolling shooter with enemies and explosions |
| Galactic Defender | 2D Game | Tower defense with 13 classes, 3-level inheritance |
| Calculator | UI App | VB6-style calculator with full keyboard support |
| Todo App | UI App | CRUD todo list with file persistence |
| Piano | Audio | Playable piano keyboard with tone generation |
| Screensaver | Graphics | Animated bouncing shapes screensaver |
| Screen Space Shaders | Graphics | 11 full-screen 2D shader effects (whirl, blur, CRT, etc.) |
| Sky Shaders | Graphics | Volumetric clouds + Rayleigh/Mie sky (3D) |
| High Scores | Data | File I/O with DATA/READ statements |
| Parallel Demo | Threading | Async/Await and Parallel For demonstration |

See the [demos/](demos/) directory for source code.

## 📖 **Documentation**

### **Core Documentation**
- [**Built-in Functions Reference**](docs/reference/BUILTIN_FUNCTIONS_REFERENCE.md) - Complete API documentation (108 functions)
- [**VB6 Features**](docs/reference/VB6_FEATURES_IMPLEMENTATION.md) - VB6 compatibility reference
- [**Godot Functions**](docs/reference/GODOT_FUNCTIONS_REFERENCE.md) - Godot integration API

### **Getting Started Guides**
- [**Getting Started**](docs/guides/GET_STARTED.md) - Quick start guide
- [**Importing VB6 Projects**](docs/guides/IMPORTING_VB6.md) - Migration from Visual Basic 6
- [**Installation Guide**](docs/guides/INSTALLATION.md) - Detailed setup instructions

### **Advanced Topics**
- [**System Integration**](docs/SYSTEM_INTEGRATION.md) - FFI, ODBC, Crypto, XML, ZIP, IPC, Signals, Memory, Android
- [**Language Reference**](docs/VisualGasic_Language_Reference.md) - Complete syntax and API reference
- [**Advanced Features**](docs/ADVANCED_FEATURES.md) - Type system, GPU computing, ECS, pattern matching
- [**Advanced Features Manual**](docs/ADVANCED_FEATURES_MANUAL.md) - Detailed walkthroughs with examples

### **Developer Resources**
- [**Keywords Reference**](docs/manual/keywords.md) - Complete syntax reference
- [**IDE Integration**](docs/manual/ide_tools.md) - LSP and development tools
- [**Performance Guide**](docs/manual/performance.md) - Benchmarks and optimization
- [**Contributing Guide**](CONTRIBUTING.md) - How to contribute to VisualGasic

## 🛠️ **Development Architecture**

### **Core Components**
- **Language Core** (`visual_gasic_script.cpp`, `visual_gasic_language.cpp`) - Base language implementation
- **Parser & AST** (`visual_gasic_parser.cpp`, `visual_gasic_ast.h`) - Syntax analysis and tree generation  
- **Runtime** (`visual_gasic_instance.cpp`) - Execution engine with multitasking support
- **Advanced Features** - Modular systems for GPU, ECS, debugging, LSP, and package management

### **Extension Points**
- **Built-in Functions** - Extensible function library via `visual_gasic_builtins.cpp`
- **Type System** - Generic types, optional types, and union types
- **Component System** - Custom ECS components and systems
- **GPU Kernels** - Custom compute shaders and SIMD operations

### **Performance Features**
- **Archetype-based ECS** - Memory-efficient entity storage
- **GPU Computing** - Automatic fallback to CPU when needed
- **JIT Compilation** - Runtime optimization for hot code paths
- **Bytecode Optimizer** - 9-pass peephole optimizer with computed-goto threaded dispatch (~20% faster VM)
- **Memory Profiling** - Built-in leak detection and analysis

## 🧪 **Testing & Bytecode Regression**
### ClassDB Fuzzer — 2421 Tests, 0 Failures

The automated ClassDB fuzzer generates and runs **2421 tests** across 210 `.vg` files covering:
- Class instantiation (854 Godot classes)
- Property get/set, enum constants
- Zero-arg method calls, setter methods
- Inheritance chain verification, With blocks
- TypeOf/Is operators, singleton method calls
- VG language features (For Each, error handling, string/vector ops)

```bash
python3 tools/classdb_fuzzer.py --run   # Generate + run all 2421 tests
```

### Bytecode Regression Harness
Use the regression harness in [Makefile.tests](Makefile.tests) to keep builds, tests, and benchmarks reproducible:

```bash
make -f Makefile.tests test           # Headless bytecode test suite
make -f Makefile.tests bench          # Cross-language benchmark harness
make -f Makefile.tests bytecode-dump  # Deterministic bytecode JSON capture
make -f Makefile.tests update-bytecode-baseline  # Refresh baseline + changelog entry
```

`make bytecode-dump` drives [demo/dump_bytecode.gd](demo/dump_bytecode.gd) in headless Godot to emit the JSON file pointed to by `BYTECODE_DUMP_OUTPUT` (defaults to `./bytecode_dump.json`). Customize what gets captured with `BYTECODE_DUMP_ENTRIES` (comma-delimited entry points) and `BYTECODE_DUMP_OUTPUT` (absolute or relative destination). The committed baseline at [tests/bytecode_baseline.json](tests/bytecode_baseline.json) is compared against the freshly generated dump via [scripts/compare_bytecode_dump.py](scripts/compare_bytecode_dump.py); CI fails if the opcode stream changes unexpectedly. When an intentional opcode change lands, refresh the baseline after reviewing the diff:

```bash
make -f Makefile.tests update-bytecode-baseline
git add tests/bytecode_baseline.json README_UPDATES.md
```

The helper script [scripts/update_bytecode_changelog.py](scripts/update_bytecode_changelog.py) drives the changelog entry automatically, listing the entry points captured in the refreshed dump under the "Bytecode Baseline Updates" section of [README_UPDATES.md](README_UPDATES.md). Every CI run now captures release **and** debug Godot builds, compares both against the baseline, uploads the resulting dumps, and posts an inline PR comment containing the diff whenever mismatches occur.

## 🤝 **Contributing**

VisualGasic welcomes contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for:
- Development setup and coding standards
- Testing requirements and procedures
- Documentation guidelines
- Pull request process

## 📊 **Project Status**

**Current Version**: 4.4.0-rc1 (Release Candidate)

> See [RELEASE_NOTES_v4.4.0-rc1.md](RELEASE_NOTES_v4.4.0-rc1.md) for the latest changes.

**Completion Status**:
- ✅ **Core Language** - 95% (VB6 compatibility — see [Known Issues](docs/KNOWN_ISSUES.md) for edge cases)
- ✅ **Advanced Types** - 100% (Generics, optionals, unions)
- ⚠️ **Multitasking** - Experimental (Task.RunAsync works; Parallel For/Task.Run bytecode not yet compiled)
- ✅ **GPU Computing** - 100% (19 methods: vector math, reduction, element-wise ops; CPU fallback)
- ✅ **System Integration** - 100% (FFI, ODBC, Crypto, XML, ZIP, Tasks, Packages)
- ✅ **System Programming** - 100% (VGSystem, Signals, Permissions, Memory, IPC, Android Bridge)
- ✅ **Development Tools** - 100% (REPL, LSP, debugger, linter, snippet browser, theme picker)
- ✅ **Bytecode Optimizer** - 100% (9-pass peephole optimizer)
- ✅ **ECS Integration** - 100% (18 methods: entities, Dictionary components, queries, serialization)
- ✅ **Visual Gasic IDE** - 100% (C++ WYSIWYG editor, 40+ controls, VB6 properties, live preview)
- ✅ **Form Templates** - 100% (23 templates: VB6, Game, Platform, Custom)
- ✅ **Game Demos** - 100% (14 demos: Pong, Snake, Space Shooter, Galactic Defender, Calculator, Piano, and more)
- ✅ **Documentation** - 100% (Comprehensive guides and references)
- ✅ **Performance** - 11/11 benchmarks faster than GDScript (up to 118× faster) — VG wins 6/9 vs C++
- ✅ **Database Controls** - 100% (VGRecordset, Data/DBGrid/DBCombo, 13 tests pass)
- ✅ **Package Manager** - 100% (vg pkg CLI, vg.json, GitHub registry, GUI browser, 11 tests pass)
- ✅ **JIT Compilation** - 100% (5-tier stack: Tier 0→0.5→1→2→3, call graph compilation, 10 tests pass)
- ✅ **Multi-Module** - 100% (Cross-file Import, project-wide symbols, circular import detection)
- ✅ **macOS Universal** - 100% (x86_64 + arm64 fat binary, CI workflow)
- ✅ **Cross-Platform Installer** - 100% (install.sh, install.ps1, install.py, vg CLI)
- ✅ **Pre-Built Binaries** - 100% (Linux x86_64, Windows x86_64, macOS Universal)
- ✅ **IDE Project Creation** - 100% (File → New Project from within VG IDE)

> **Note:** See [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) for a complete list
> of confirmed engine bugs and workarounds.

### 🚧 Coming Soon

See [ROADMAP.md](ROADMAP.md) for the full development roadmap:
- **Stable Release (v4.4.0)** - Pending community testing of RC1
- **Asset Library** - Publish to Godot Asset Library
- **WebAssembly Validation** - Verify HTML5 export compatibility

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🌟 **Acknowledgments**

- **Godot Engine** - For providing the excellent GDExtension API
- **Visual Basic Community** - For inspiration and feedback
- **Contributors** - Everyone who has helped make VisualGasic better

---

**VisualGasic** - Where Visual Basic meets modern programming! 🚀

## Immediate Window

VisualGasic includes an **Immediate Window** for interactive code execution during development. Execute expressions, test functions, and debug code in real-time without running your full program.

### Quick Start

1. Open Godot Editor
2. Click **Immediate** tab at bottom panel
3. Type expressions and press Enter

### Example Usage

```
> 2 + 2
4

> Dim x As Integer = 42
✓ x = 42

> x * 2
84

> Print "Hello World"
Hello World
```

### Remote Debugging

Connect to running game instances and debug live:
- **Auto-connect** when single instance is running
- **Live refresh** toggle for real-time variable updates
- **Edit values remotely** by double-clicking in Variables tab

### Refactoring Tools

Press **Ctrl+R** on any variable in the script editor:
- **Rename in Current Scope** - Within the current Sub/Function
- **Rename in Entire Script** - All occurrences in the file
- **Rename Everywhere** - Across all .vg files in the project

### Commands

- `:help` - Show available commands
- `:clear` - Clear output
- `:vars` - List variables
- `:history` - Command history
- `:eval [expr]` - Evaluate expression in paused debug context
- `:wp add [var]` - Add data breakpoint (break when variable changes)
- `:wp remove [var]` - Remove data breakpoint
- `:wp` - List active data breakpoints

See [Immediate Window Documentation](docs/IMMEDIATE_WINDOW.md) for complete guide.
