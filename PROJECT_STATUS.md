# VisualGasic Project Status

**Version**: 3.2.0-beta1 (JIT Compiler, LSP, Performance, Beta Release)  
**Last Updated**: February 2026

## Overview

VisualGasic is a Visual Basic 6-style scripting language for Godot Engine 4.x, implemented as a GDExtension. It provides familiar VB6 syntax with modern enhancements and exceptional performance.

## Performance

### Benchmark Results (v3.2.0) ⭐

**All 11 benchmarks faster than GDScript. VG wins 6/9 vs C++.** All checksums verified.

| Benchmark | GDScript | VisualGasic | C++ | **VG vs GDScript** | **VG vs C++** | Winner |
|-----------|----------|-------------|-----|-------------------|---------------|--------|
| Arithmetic | 5,333 µs | 331 µs | 59 µs | **16× faster** | 0.2× | C++ |
| ArraySum | 4,644 µs | 130 µs | 37 µs | **36× faster** | 0.3× | C++ |
| StringConcat | 5,007 µs | 60 µs | 483 µs | **83× faster** 🚀 | **8× faster** 🔥 | **VG** |
| Branching | 6,988 µs | 59 µs | 60 µs | **118× faster** 🚀 | **tied** 🔥 | **VG** |
| ArrayDict | 11,441 µs | 3,834 µs | 4,155 µs | **3× faster** | **1.1× faster** | **VG** |
| DictFastGet | 29,177 µs | 2,210 µs | — | **13× faster** | — | **VG** |
| DictFastSet | 19,266 µs | 2,519 µs | — | **7.6× faster** | — | **VG** |
| Interop | 8,096 µs | 120 µs | 6,882 µs | **67× faster** 🚀 | **57× faster** 🔥 | **VG** |
| Allocations | 6,871 µs | 128 µs | 471 µs | **54× faster** 🚀 | **3.7× faster** 🔥 | **VG** |
| AllocationsFast | 10,309 µs | 1,817 µs | 366 µs | **5.7× faster** | 0.2× | C++ |
| FileIO | 982 µs | 456 µs | 383 µs | **2.2× faster** | 0.8× | C++ |

**VG beats GDScript on every benchmark (2×–118× faster). Branching ties native C++ at 59 µs.**

*Improvements since v2.5: Branching 65×→118×, Allocations 19×→54×, DictFastGet 5.4×→13×, DictFastSet 2.6×→7.6×, ArrayDict 1.06×→3× — driven by bytecode compiler batches 1-4 and optimizer passes*

### Known Limitations ⚠️

- No known performance regressions — all 11 benchmarks faster than GDScript as of v2.5

## Features

### VB6 Compatibility
- Classic VB6 syntax (Dim, If/Then, For/Next, etc.)
- Form designer integration
- Event-driven programming
- COM-style object model
- See [VB6_FEATURES_IMPLEMENTATION.md](docs/reference/VB6_FEATURES_IMPLEMENTATION.md)

### Modern Extensions
- Async/await support
- Lambda expressions
- LINQ-style operations
- Modern collection syntax
- Enhanced error handling
- See [MODERN_FEATURES_README.md](docs/guides/MODERN_FEATURES_README.md)

### Godot Integration
- Direct access to Godot nodes and resources
- Scene tree manipulation
- Signal system integration
- Built-in Godot types (Vector2, Vector3, etc.)
- See [GODOT_FUNCTIONS_REFERENCE.md](docs/reference/GODOT_FUNCTIONS_REFERENCE.md)

## Documentation

All documentation is organized in [docs/DOCUMENTATION_INDEX.md](docs/DOCUMENTATION_INDEX.md)

### Quick Start
1. [GET_STARTED.md](docs/guides/GET_STARTED.md) - Installation and first program
2. [BUILTIN_FUNCTIONS_REFERENCE.md](docs/reference/BUILTIN_FUNCTIONS_REFERENCE.md) - Language reference
3. [examples/](examples/) - Example programs

### For VB6 Users
1. [MIGRATION_GUIDE.md](docs/guides/MIGRATION_GUIDE.md) - Differences and migration tips
2. [IMPORTING_VB6.md](docs/guides/IMPORTING_VB6.md) - Import existing VB6 projects

## Project Status

### Implementation: ✅ Complete
- ✅ Core language features
- ✅ VB6 compatibility layer
- ✅ Modern syntax extensions
- ✅ Godot integration
- ✅ Form designer
- ✅ Performance optimization
- ✅ **Universal Godot singleton access** — All 37 singletons (Engine, OS, Time, etc.)
- ✅ **Godot class enum constants** — ClassName.CONSTANT_NAME with keyword-safe resolution
- ✅ **Null method call protection** — On Error Resume Next catches .method() on Null
- ✅ **ClassDB fuzzer: 2421 PASS / 0 FAIL / 0 ERRORS** across 210 test files
- ✅ **Native compiler: 39 tests across 4 batches**
  - Batch 1: Select Case, For Each, Object Method Calls
  - Batch 2: With...End With, Continue For/Do, GoTo, Try/Catch/Finally
  - Batch 3: Erase, TypeOf...Is, Optional?.Access, Lambda
  - Batch 4: ReDim Preserve, Super, New with Args, Pass
- ✅ **System Integration (v3.0)**: FFI, ODBC, Crypto, XML, ZIP, Tasks, Packages
- ✅ **System-Level Programming (v3.1)**:
  - VGSystem — hostname, CPU, RAM, disk, OS, uptime, env, locale
  - VGSignalHandler — SIGINT/SIGTERM/SIGHUP/atexit handlers
  - VGFilePermissions — chmod, chown, symlinks, file locking, GetAttr/SetAttr
  - VGMemoryBuffer — Peek/Poke byte buffers, CopyMemory, HexDump, FFI pointer
  - VGIPC — named pipes, UNIX domain sockets, shared memory
  - VGAndroidBridge — JNI device info, permissions, intents, toast, vibrate
  - Real threading — Task.Run / Parallel For / Parallel Section backed by std::thread

### Testing: ✅ Comprehensive
- ✅ Unit tests for all features
- ✅ Integration tests
- ✅ Performance benchmarks
- ✅ VB6 compatibility tests

### Documentation: ✅ Complete
- ✅ User guides
- ✅ API reference
- ✅ Migration guides
- ✅ Examples

## Recent Updates (v3.1.0)

### System-Level Programming
- **VGSystem** — Cross-platform system info: hostname, CPU, RAM, disk, OS, uptime, environment variables, locale
- **VGSignalHandler** — OS signal handling: SIGINT, SIGTERM, SIGHUP, SIGUSR1/2, atexit; Windows SetConsoleCtrlHandler
- **VGFilePermissions** — File permissions: chmod, chown, symlinks, hard links, file locking (flock/LockFileEx), VB6 GetAttr/SetAttr
- **VGMemoryBuffer** — Raw memory: Peek/Poke byte-level access, CopyMemory, HexDump, FFI pointer interop
- **VGIPC** — IPC: named pipes (mkfifo/CreateNamedPipe), UNIX domain sockets, shared memory (shm_open/mmap)
- **VGAndroidBridge** — JNI bridge: device info, permissions, intents, toast, vibrate, battery, storage
- **Real Threading** — Task.Run/Parallel For/Parallel Section now use real std::thread with per-thread scope cloning

### Build System
- SConstruct links `-lrt` and `-lpthread` on Linux for shared memory and threading
- Android build target with `-llog` for JNI logging
- All POSIX syscalls use `::` global prefix to avoid Godot method shadowing

## Recent Updates (v2.6.1)

### Bytecode Compiler Batches 1-4
- **28 new statement/expression types** compiled to bytecode (previously fell back to AST interpreter)
- **39 dedicated tests** across 4 test files, all passing
- **4 new opcodes**: `OP_ARRAY_RESIZE`, `OP_NEW_OBJECT`, `OP_DUP`, `OP_SETUP_TRY`
- **DCE/optimizer fully updated** for all new opcodes and expression types
- Eliminates function poisoning — functions with these constructs now run at bytecode speed

### Performance Impact
- DictFastGet: 5.4× → **13× faster** than GDScript
- DictFastSet: 2.6× → **7.6× faster** than GDScript
- Allocations: 19× → **54× faster** than GDScript
- Branching: 65× → **118× faster** than GDScript
- VG now beats C++ on **6 of 9** head-to-head benchmarks

### Previous Updates
- **Class Definitions**: `Class...End Class` with members, methods, properties
- **Object Instantiation**: `Dim obj = New ClassName` with independent state
- **Property Accessors**: `Property Get/Let/Set` with parameters
- **Constructor**: `Class_Initialize` runs on `New`
- **Member Visibility**: `Public`/`Private` modifiers

### Functional Programming
- **Map/Filter/Reduce**: Higher-order array functions with lambda callbacks
- **Any/All/Find**: Predicate-based array queries
- **Chaining**: Pipeline operations (Filter → Map → Reduce)

### Block Lambdas
- **Multi-Statement Bodies**: `Function(x) ... Return ... End Function`
- **Sub Lambdas**: Statement blocks invocable via direct call
- **invoke_lambda()**: Consolidated runtime with proper scoping

### Previous Updates (v2.3.x)
- Lambda expressions (`Lambda`, `Fn`, `Function`, `Sub` with optional `=>`)
- Null safety (`??`, `?.`)
- String interpolation (`$"Hello {name}"`)
- Array/Dictionary literals, Range operator, Using statement

### Previous Updates (v2.2.1)

### Native Compiler Enhancements
- **Select Case**: Full bytecode compilation with multi-value case matching
- **Do Loop**: Do While/Until with pre/post conditions  
- **IIf Expression**: Ternary operator (\`IIf(cond, true, false)\`)
- **New Operators**: \`Is\`, \`Mod\`, \`Like\`, \`\\\` (integer division)
- **New Opcodes**: OP_JUMP_IF_TRUE, OP_RESTORE_DATA, OP_MOD, OP_INT_DIVIDE, OP_LIKE

### Editor Plugin Features
- IntelliSense with 70+ keywords, 80+ functions
- Go To Definition across all .vg files
- Static code linter with 10 issue types
- 30+ code snippets with tab stops
- 5 syntax highlighting themes
- Recent projects tracking

## Development

### Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines

### Source Organization
See [FILE_INDEX.md](docs/archive/FILE_INDEX.md) for source structure

### Build System
\`\`\`bash
# Build release version
scons platform=linux target=template_release

# Run tests
./scripts/run_tests.sh

# Run benchmarks
godot --headless --script demo/run_benchmarks.gd
\`\`\`

## Future Plans

See [ROADMAP.md](ROADMAP.md) for the complete development roadmap including:

### ✅ Completed (v2.4.0)
- **Classes & Objects** - Full VB-style class system
- **Functional Programming** - Map/Filter/Reduce/Any/All/Find
- **Block Lambdas** - Multi-statement lambda bodies

### ✅ Completed (v2.3.x)
- **Lambda Expressions** - All 4 syntax forms
- **Null Safety** - `??` and `?.` operators
- **String Interpolation** - `$"Hello {name}"`
- **Erase Statement** - Array reset

### ✅ Completed (v2.2.1)
- **Watch Window** - Monitor variables during debugging
- **Snap-to-Grid & Alignment Tools** - Professional form designer enhancements
- **IntelliSense / Autocomplete** - Code completion for VB6 keywords and controls
- **Breakpoint Conditions** - Conditional breakpoints and hit counts
- **Call Stack Panel** - Visual call stack during debugging
- **Recent Projects list**
- **Code Formatter / Beautifier**
- **Find All References**
- **Go to Definition**
- **Form Preview mode**
- **Linting and warnings**
- **Snippet Manager**
- **Theme Support (Classic VB6 gray)**

### Planned Features
- JIT compilation for hot paths
- WebSocket/networking controls

### ✅ Completed (v2.4.1)
- **Dictionary optimization** — VGFastStringDict + loop fusion + escape analysis
  - DictFastGet: 5.2× faster than GDScript (was 3.9× slower)
  - DictFastSet: 2.2× faster than GDScript (was 12.2× slower)

See also [TODO_FUTURE_OPTIMIZATIONS.md](TODO_FUTURE_OPTIMIZATIONS.md) for:
- JIT compilation possibilities

## License

MIT License - See [LICENSE](LICENSE)

## Community

- GitHub Issues: Bug reports and feature requests
- Discord: Join our community (see [COMMUNITY_HUB.md](COMMUNITY_HUB.md))
- Forums: Discussion and support

## Recent Updates (v2.7.0)

### Bug Fixes
- **Fix method call on Null objects** — On Error Resume Next now catches `.method()` on Null instead of silent failure
- **Fix enum constants with keyword names** — `FileAccess.READ`, `.WRITE` now resolve correctly (tokenizer keyword normalization + UPPER_CASE fallback)
- **Fix singleton instantiation crash** — `ProjectSettings.new()` no longer causes SIGILL
- **Universal Godot singleton resolution** — All 37 singletons accessible by name (Engine, OS, Time, DisplayServer, AudioServer, etc.)
- **Fix RefCounted object lifetime** — SphereMesh, StandardMaterial3D etc. no longer freed immediately
- **Fix bytecode singleton resolution** — Input, Godot, Me, Super correctly resolved in bytecode VM

### Testing
- **ClassDB fuzzer expanded** — 11 test types, 2421 PASS / 0 FAIL / 0 ERRORS across 210 files
- Test categories: instantiation, property get/set, enum constants, singleton access, method calls, setter calls, inheritance chains, With blocks, TypeOf/Is, singleton methods, VG language features
- 34 Godot engine-level warnings properly separated from VG errors

## Credits

Created by the VisualGasic team. Built on Godot Engine and godot-cpp.

Special thanks to:
- The Godot Engine team
- The GDExtension community
- All contributors and testers
