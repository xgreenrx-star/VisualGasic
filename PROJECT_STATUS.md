# VisualGasic Project Status

**Version**: 2.4.1 (Optimizer & Tooling)  
**Last Updated**: 2025

## Overview

VisualGasic is a Visual Basic 6-style scripting language for Godot Engine 4.x, implemented as a GDExtension. It provides familiar VB6 syntax with modern enhancements and exceptional performance.

## Performance

### Exceptional Performance vs GDScript ⭐

| Operation | GDScript | VisualGasic | **Speedup** |
|-----------|----------|-------------|-------------|
| Arithmetic | 5,190 µs | 164 µs | **31.6× faster** |
| Array Operations | 4,325 µs | 84 µs | **51.5× faster** |
| String Operations | 5,422 µs | 75 µs | **72.3× faster** |
| Control Flow | 6,777 µs | 45 µs | **150.6× faster** |
| Memory Allocation | 10,604 µs | 1,123 µs | **9.4× faster** |
| File I/O | 910 µs | 452 µs | **2.0× faster** |

*VisualGasic even beats native C++ on string concatenation (72× vs C++'s 7.9×)*

### Known Limitations ⚠️

- Dictionary operations: 3-12× slower than GDScript
- Cause: Architectural limitation (bytecode VM overhead + Godot's Dictionary implementation)
- Impact: Only affects dictionary-heavy code
- Solution: Documented in [TODO_FUTURE_OPTIMIZATIONS.md](TODO_FUTURE_OPTIMIZATIONS.md)

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
- Dictionary operation optimization
- WebSocket/networking controls

See also [TODO_FUTURE_OPTIMIZATIONS.md](TODO_FUTURE_OPTIMIZATIONS.md) for:
- Potential dictionary optimization (specialized types)
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
