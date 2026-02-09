# VisualGasic - Advanced Visual Basic for Godot 4

[![CI](https://github.com/xgreenrx-star/VisualGasic/actions/workflows/ci.yml/badge.svg)](https://github.com/xgreenrx-star/VisualGasic/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-2.3.0-blue.svg)](https://github.com/xgreenrx-star/VisualGasic/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Godot](https://img.shields.io/badge/Godot-4.3+-purple.svg)](https://godotengine.org)

**World-Class RAD Platform**: Professional Visual Basic language implementation with cutting-edge modern features including multitasking, advanced type system, pattern matching, GPU computing, and comprehensive development tools.

## 🚀 **Key Features**

### **Core Language**
- **Complete Visual Basic 6 Syntax** - Full compatibility with VB6 projects
- **Advanced Type System** - Generics, optional types, union types, type inference
- **Pattern Matching** - VB.NET-style Select Match with destructuring
- **Multitasking** - Native async/await, parallel processing, task coordination

### **High-Performance Computing**
- **GPU Acceleration** - SIMD vector operations and compute shaders
- **Parallel Processing** - Automatic GPU/CPU fallback for optimal performance
- **Memory Optimization** - Efficient memory management and leak detection

### **Professional Development Tools**
- **IntelliSense** - Code completion with 80+ functions, snippets, and Godot types
- **Interactive REPL** - Live coding with variable inspection and session management
- **Language Server Protocol** - Intelligent IDE integration with completion and diagnostics
- **Advanced Debugger** - Breakpoint conditions, call stack, watch window, time-travel debugging
- **Code Linting** - Static analysis with 10 issue codes (VG001-VG010)
- **Snippet Manager** - 40+ built-in snippets with custom snippet support
- **Theme Support** - 5 built-in themes including VB6 Classic
- **Form Designer** - Grid snapping, alignment tools, F5 preview

### **Game Development**
- **Entity Component System** - High-performance ECS with archetype optimization
- **Godot Integration** - Native scene tree synchronization and node management
- **Built-in Components** - Transform, Velocity, Render, and custom component support

## 📁 **Project Structure**

```
VisualGasic/
├── src/                          # Core implementation
│   ├── visual_gasic_*.cpp/.h    # Language core, parser, AST
│   ├── visual_gasic_repl.*      # Interactive REPL system
│   ├── visual_gasic_gpu.*       # GPU computing and SIMD
│   ├── visual_gasic_lsp.*       # Language server protocol
│   ├── visual_gasic_debugger.*  # Advanced debugging tools
│   ├── visual_gasic_package.*   # Package management
│   └── visual_gasic_ecs.*       # Entity component system
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
- **Godot 4.5+** - Download from [godotengine.org](https://godotengine.org)
- **SCons** - Build system (`pip install scons`)
- **Git** - For cloning submodules
- **Modern C++ Compiler** - GCC 9+, Clang 10+, or MSVC 2019+

### **Installation**

**Quick Install (Recommended):**

```bash
# Linux/macOS
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.sh | bash

# Windows PowerShell
iwr -useb https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.ps1 | iex
```

This installs VisualGasic as a project template. Create new projects with VisualGasic already configured!

**Alternative Methods:**
- **Asset Library**: Search "VisualGasic" in Godot's AssetLib tab (coming soon)
- **Manual**: Download from [Releases](https://github.com/xgreenrx-star/VisualGasic/releases) and copy to `addons/`
- **Build from Source**: See [INSTALLATION.md](INSTALLATION.md)

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
Imports VisualGasic.GPU

Sub PerformVectorMath()
    Dim a As Vector(Of Single) = {1.0, 2.0, 3.0, 4.0}
    Dim b As Vector(Of Single) = {2.0, 3.0, 4.0, 5.0}
    
    ' GPU-accelerated operations
    Dim sum = GPU.SIMDAdd(a, b)
    Print "Result: " & String.Join(", ", sum)
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

## 📖 **Documentation**

### **Core Documentation**
- [**Built-in Functions Reference**](docs/reference/BUILTIN_FUNCTIONS_REFERENCE.md) - Complete API documentation (96 functions)
- [**VB6 Features**](docs/reference/VB6_FEATURES_IMPLEMENTATION.md) - VB6 compatibility reference
- [**Godot Functions**](docs/reference/GODOT_FUNCTIONS_REFERENCE.md) - Godot integration API

### **Getting Started Guides**
- [**Getting Started**](docs/guides/GET_STARTED.md) - Quick start guide
- [**Importing VB6 Projects**](docs/guides/IMPORTING_VB6.md) - Migration from Visual Basic 6
- [**Installation Guide**](docs/guides/INSTALLATION.md) - Detailed setup instructions

### **Advanced Topics**
- [**Multitasking Guide**](docs/MULTITASKING.md) - Async/await and parallel programming
- [**ECS Development**](docs/ECS.md) - Game development with Entity Component System
- [**GPU Computing**](docs/GPU_COMPUTING.md) - High-performance SIMD operations
- [**Package Management**](docs/PACKAGE_MANAGEMENT.md) - Dependency resolution and publishing

### **Developer Resources**
- [**Language Reference**](docs/manual/keywords.md) - Complete syntax reference
- [**IDE Integration**](docs/manual/ide_tools.md) - LSP and development tools
- [**Performance Guide**](docs/PERFORMANCE.md) - Optimization techniques
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
- **Memory Profiling** - Built-in leak detection and analysis

## 🧪 **Testing & Bytecode Regression**

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

**Current Version**: 2.0.0 (Advanced Features Release)

**Completion Status**:
- ✅ **Core Language** - 100% (Full VB6 compatibility)
- ✅ **Advanced Types** - 100% (Generics, optionals, unions)
- ✅ **Multitasking** - 100% (Async/await, parallel processing)
- ✅ **GPU Computing** - 100% (SIMD, compute shaders)
- ✅ **Development Tools** - 100% (REPL, LSP, debugger, packages)
- ✅ **ECS Integration** - 100% (High-performance game development)
- ✅ **Form Templates** - 100% (23 templates: VB6, Game, Platform, Custom)
- ✅ **Documentation** - 95% (Comprehensive guides and references)

### 🚧 Coming Soon

See [ROADMAP.md](ROADMAP.md) for the full development roadmap:
- **Watch Window** - Variable monitoring during debugging
- **Snap-to-Grid** - Form designer alignment tools
- **IntelliSense** - Code completion for VB6 keywords and controls
- **Breakpoint Conditions** - Conditional breakpoints with expressions
- **Call Stack Panel** - Visual debugging navigation

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
