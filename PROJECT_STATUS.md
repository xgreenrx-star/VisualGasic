# VisualGasic Project Status

**Version**: 2.4.2 (Benchmark Fusion Fixes)  
**Last Updated**: June 2025

## Overview

VisualGasic is a Visual Basic 6-style scripting language for Godot Engine 4.x, implemented as a GDExtension. It provides familiar VB6 syntax with modern enhancements and exceptional performance.

## Performance

### Benchmark Results (v2.4.2) ⭐

10 of 11 benchmarks faster than GDScript. All checksums verified.

| Benchmark | GDScript | VisualGasic | C++ | **VG vs GDScript** |
|-----------|----------|-------------|-----|-------------------|
| Arithmetic | 5,197 µs | 1,470 µs | 145 µs | **3.5× faster** |
| ArraySum | 4,513 µs | 411 µs | 467 µs | **11.0× faster** |
| Branching | 6,726 µs | 142 µs | 212 µs | **47.4× faster** |
| Interop | 8,368 µs | 209 µs | 7,720 µs | **40.0× faster** |
| Allocations | 7,101 µs | 368 µs | 878 µs | **19.3× faster** |
| ArrayDict | 10,810 µs | 10,281 µs | 4,169 µs | **1.05× faster** |
| DictFastGet | 27,862 µs | 5,392 µs | — | **5.2× faster** |
| DictFastSet | 18,636 µs | 7,451 µs | — | **2.5× faster** |
| AllocationsFast | 10,651 µs | 2,705 µs | 2,206 µs | **3.9× faster** |
| FileIO | 907 µs | 492 µs | 407 µs | **1.8× faster** |
| StringConcat | 5,412 µs | 169,112 µs | 719 µs | 31× slower ⚠️ |

*Interop and Allocations were previously 32× and 238× slower — now 40× and 19× faster via loop fusion rewrites*

### Known Limitations ⚠️

- StringConcat: 31× slower than GDScript (fusion fires correctly but `variables.duplicate(true)` deep-copy overhead in `call_internal()` dominates — tracked for v2.5)

## Features

### VB6 Compatibility
- Classic VB6 syntax (Dim, If/Then, For/Next, etc.)
- Form designer integration
- Event-driven programming
- COM-style object model
- See [VB6_FEATURES_IMPLEMENTATION.md](VB6_FEATURES_IMPLEMENTATION.md)

### Modern Extensions
- Async/await support
- Lambda expressions
- LINQ-style operations
- Modern collection syntax
- Enhanced error handling
- See [MODERN_FEATURES_README.md](MODERN_FEATURES_README.md)

### Godot Integration
- Direct access to Godot nodes and resources
- Scene tree manipulation
- Signal system integration
- Built-in Godot types (Vector2, Vector3, etc.)
- See [GODOT_FUNCTIONS_REFERENCE.md](GODOT_FUNCTIONS_REFERENCE.md)

## Documentation

All documentation is organized in [docs/DOCUMENTATION_INDEX.md](docs/DOCUMENTATION_INDEX.md)

### Quick Start
1. [GET_STARTED.md](GET_STARTED.md) - Installation and first program
2. [BUILTIN_FUNCTIONS_REFERENCE.md](BUILTIN_FUNCTIONS_REFERENCE.md) - Language reference
3. [examples/](examples/) - Example programs

### For VB6 Users
1. [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Differences and migration tips
2. [IMPORTING_VB6.md](IMPORTING_VB6.md) - Import existing VB6 projects

## Project Status

### Implementation: ✅ Complete
- ✅ Core language features
- ✅ VB6 compatibility layer
- ✅ Modern syntax extensions
- ✅ Godot integration
- ✅ Form designer
- ✅ Performance optimization
- ✅ **Native compiler: Select Case, Do Loop, IIf, Mod, Like, Is**

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

## Recent Updates (v2.4.0)

### Classes & Objects
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
See [FILE_INDEX.md](FILE_INDEX.md) for source structure

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

## Credits

Created by the VisualGasic team. Built on Godot Engine and godot-cpp.

Special thanks to:
- The Godot Engine team
- The GDExtension community
- All contributors and testers
