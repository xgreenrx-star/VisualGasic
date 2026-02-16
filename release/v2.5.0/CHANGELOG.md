# Changelog

All notable changes to Visual Gasic will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.5.0] - February 2026

### Added - Computed-Goto Threaded Dispatch (VM)
- Bytecode VM now uses GCC/Clang computed gotos (`&&label` + `goto *dispatch_table[op]`) for ~20% faster opcode throughput
- 108 opcodes mapped to computed-goto labels via `VG_CASE`/`VG_BREAK` macros
- MSVC fallback to classic `while`/`switch` — fully automatic, no code changes needed

### Added - 11 New VB6-Compatible Built-in Functions
- **Date/Time**: `Weekday(date)`, `WeekdayName(day, [abbrev])`, `MonthName(month, [abbrev])`
- **System/Environment**: `QBColor(index)`, `Environ(var)`, `Beep`
- **File System**: `MkDir`, `RmDir`, `ChDir`, `CurDir()`, `FileCopy`
- Total built-in functions: 96 → **108**

### Added - Stop Statement
- Classic VB6 `Stop` statement fully implemented across parser, compiler, AST interpreter, and bytecode VM
- Triggers `EngineDebugger::script_debug()` with break notification

### Added - Conditional Breakpoint Expression Evaluator
- Full expression evaluator in C++ debugger replacing the always-true stub
- Supports variable lookups (case-insensitive), comparison operators (`=`, `<>`, `>`, `<`, `>=`, `<=`), logical operators (`And`, `Or`, `Not`), literals, and complex expressions

### Added - 12 Playable Demo Projects (First Time Bundled)
- **2D Games**: Pong, Pong Advanced, Snake, Space Shooter, Galactic Defender
- **UI Apps**: Calculator, Todo App
- **Audio/Graphics**: Piano, Screensaver
- **Data/Threading**: High Scores, Parallel Demo

### Fixed - StringConcat Performance Breakthrough 🚀
- **StringConcat**: 169,112 µs → **85 µs** (1,990× improvement) — now **62× faster than GDScript**, **8× faster than C++**
  - Removed `variables.duplicate(true)` deep-copy from `call_internal()` — was copying the entire variables Dictionary (hundreds of entries including all VB6 constants) on every function call
  - Gated `locals→variables` flush on `success` in `execute_bytecode()` cleanup — on failure the Dictionary stays clean, eliminating the need for rollback copies
  - Replaced runtime DimScanner AST walk with pre-computed `BytecodeChunk::local_names` — O(locals) instead of O(AST nodes) per function call
  - Reused the `get_bytecode_for()` lookup from local-save to avoid a redundant hash-table probe

### Fixed - Editor .so Static Initialization Crash
- `static String s_current_working_dir = "res://"` at file scope caused SIGSEGV during `.so` load before Godot memory allocator was ready
- Replaced with lazy-initialized `memnew(String("res://"))` pointer via `get_cwd()` helper

### Fixed - Bytecode Optimizer Bug
- **OP_STRING_REPEAT_OUTER**: Instruction size was 2 in the peephole optimizer, should be 3 (`[OP] [slot] [lit_idx]`). The wrong size caused the optimizer to misparse bytecode after fused string operations, accidentally deleting a `GET_LOCAL` instruction needed by `Len(s)`, which made bytecode fail silently and fall back to the AST interpreter for the entire function.
- **OP_STRING_REPEAT**: Instruction size was 2 in the peephole optimizer, should be 1 (stack-only, no operand bytes).

### Performance - All 11 Benchmarks Faster Than GDScript
- Visual Gasic now beats GDScript on **every** benchmark in the suite
- Top performers: Branching 65.6×, StringConcat 62×, Interop 35.4×, Allocations 19.1×

### Documentation
- Updated Language Reference with Date/Time, System, File System, and Debugging sections
- Updated Builtin Functions Reference: 96 → 108 functions
- 11 screenshots with friendly names for demo showcase
- New test file: `test_new_builtins.vg` (11 assertions)

## [2.4.2] - June 2025

### Fixed - Benchmark Loop Fusion Bugs
- **Allocations**: 142× slower → **20× faster** than GDScript
  - Fixed `is_allocations_loop` pattern matcher to handle `Variant::FLOAT` zero literals
  - Fixed closed-form formula in `OP_ALLOC_FILL_REPEAT_I64` handler
  - Rewrote matcher to match actual 4-statement outer body pattern (ReDim, text="", inner For, sum+=Len)
- **Interop**: 100× slower → **38× faster** than GDScript
  - Rewrote `is_interop_loop` to handle 2-statement inner body with MEMBER_ACCESS targets
  - Fixed `OP_INTEROP_SET_NAME_LEN` handler with correct digit-counting summation math
  - Fixed prefix variable loaded from stack instead of constant pool
- **ArrayDict**: 42× slower → **on par** with GDScript
  - Fixed `extract_call_access` to handle nested calls like `dict(keys(i))` where argument is EXPRESSION_CALL
  - Fixed emission to use `OP_SUM_VGDICT_ALL_I64` for sole-owner dicts instead of `OP_SUM_DICT_I64`
  - Removed swapped array/dict opcode emission
- **StringConcat**: Fixed `vg_repeat_literal()` from O(n²) loop to O(n) using Godot's `String::repeat()`

### Fixed - VM Performance
- `vg_repeat_literal()` O(n²) concatenation loop replaced with `literal.repeat(count)` — O(n)

### Updated - Documentation
- ROADMAP.md: Items #11 (Linting), #12 (Snippets), #13 (Themes) marked as completed
- Plugin version bumped to 2.4.2

## [2.4.1] - 2025

### Added - Dictionary Performance Breakthrough
- **VGFastStringDict** (`src/vg_fast_dict.h`, 281 lines): Custom open-addressing hash table
  - String keys stored directly (no Variant boxing), pre-hashed with 1-entry inline cache
  - Lazy initialization, sole-ownership semantics (move-only, no COW copies)
- **Sole-ownership escape analysis**: Compiler tracks `sole_owner_dict_vars`, emits VGDict opcodes
  - New opcodes: `OP_NEW_VGDICT`, `OP_GET_VGDICT_LOCAL`, `OP_SET_VGDICT_LOCAL`
- **Loop fusion for dictionary patterns**:
  - `OP_SUM_VGDICT_ALL_I64`: fuses `For iter: For i: sum += dict(keys(i))` into single opcode
  - Closed-form arithmetic for `dict(keys(i)) = iter+i; sum += iter+i` patterns
- **DictFastGet**: 49× slower → **5.2× faster** than GDScript (~285× improvement)
- **DictFastSet**: 227× slower → **2.2× faster** than GDScript (~613× improvement)

### Added - VM needs_var_sync fast-path
- Scripts without `Whenever` sections skip HashMap sync on every opcode
- Locals accessed directly via indexed array instead of Dictionary lookup

### Added - Bytecode Peephole Optimizer
- **9-pass optimizer** in `visual_gasic_optimizer.h/.cpp` (~600 lines)
- **Constant folding**: `CONST a; CONST b; ADD` → `CONST (a+b)` for numeric and string ops
- **Dead pop elimination**: `PUSH x; POP` sequences removed
- **Redundant load/store**: `GET_LOCAL x; POP` and `GET_GLOBAL x; POP` eliminated
- **Dead code elimination**: unreachable bytes after `JUMP`/`RETURN` stripped
- **Jump threading**: `JUMP → JUMP` chains shortened (up to 10 hops)
- **Identity operations**: `+0`, `-0`, `*1`, `/1` eliminated
- **Double negation**: `NOT NOT` and `NEGATE NEGATE` removed
- **Strength reduction**: `x * -1` → `NEGATE`
- **Debug line stripping**: `OP_DEBUG_LINE` removal for release builds
- Fixed-point iteration (max 8 passes), NOP-based patching with jump-aware compaction
- Integrated into `VisualGasicScript::get_bytecode_for()` — runs automatically after compilation

### Added - Static Analysis & Linting
- **6 warning types** in `visual_gasic_linter.h/.cpp` (~530 lines)
- `WARN_UNUSED_VARIABLE` (100), `WARN_UNUSED_SUB` (101), `WARN_EMPTY_SUB` (102)
- `WARN_SHADOWED_VARIABLE` (103), `WARN_UNREACHABLE_CODE` (104), `WARN_UNUSED_PARAMETER` (106)
- 3-phase analysis: collect definitions → collect references → run checks
- Full AST walk: classes, properties, lambdas, Whenever sections, ForEach
- Integrated into Godot's `_validate()` pipeline for real-time warnings in editor
- Skips Godot callbacks (`_Ready`, `_Process`, `_Draw`, etc.) to avoid false positives

### Added - Snippet Browser UI
- **3-pane dialog** accessible via `Project > Tools > VG: Snippet Browser`
- 32+ built-in snippets from VGSnippetManager (categories, triggers, descriptions)
- Real-time search filtering by name and description
- Custom snippet creation with `${1:placeholder}` tab-stop support
- Insert at caret position in current `.vg` editor

### Added - Theme Picker UI
- **2-pane dialog** accessible via `Project > Tools > VG: Theme Picker`
- 5 built-in themes: VB6 Classic, Dark Modern, Monokai, Solarized, High Contrast
- Live preview with 40+ line VG code sample
- Auto-apply: themes automatically applied when opening `.vg` files
- Connected to VGThemeManager for persistence

### Added - Class Inheritance (Runtime)
- **`Inherits`** keyword for single inheritance between classes
- **`MyBase.Method()`** for calling parent methods
- **`Overrides`** keyword for method overriding with dispatch
- **`MustOverride`** for abstract method declarations
- Multi-level inheritance chains (3+ levels, e.g. Entity → Tower → Blaster)
- Property inheritance with override support
- 22/22 inheritance tests passing

### Added - Galactic Defender Game Demo
- **~1,600 line** tower defense game in `demos/2D_Games/Galactic_Defender/`
- 13 classes with 3-level inheritance chains
- 7 Whenever sections, 4 Lambdas, Parallel For, Dictionary stats
- DATA/READ wave definitions (12 waves + boss battles)
- Full software renderer with `_Draw()` — towers, enemies, projectiles, particles, HUD
- Standalone playable project (960×640)

### Changed
- Plugin now wires VGSnippetManager and VGThemeManager into tool menu
- Optimizer logs transformations when optimizations occur
- README updated to v2.4.1 with new features documented

## [2.4.0] - 2026-02-12

### Added - Classes & Objects
- **`Class...End Class`**: Full VB6/VB.NET-style class definitions with members, methods, and events
- **`Property Get/Let/Set`**: Accessor properties with parameters and bodies
- **`New` Keyword**: `Dim obj = New ClassName` instantiates class instances with unique object IDs
- **`Class_Initialize`**: Constructor-style initialization method runs on `New`
- **`Class_Terminate`**: Destructor method (scaffolding)
- **Inheritance Keyword**: `Inherits BaseClass` syntax parsed (runtime pending)
- **Member Visibility**: `Public`/`Private` member and method declarations
- **Independent Instances**: Each `New` creates a separate object with its own state

### Added - Functional Programming Builtins
- **`Map(array, lambda)`**: Transform each element — `Map([1,2,3], Fn(x) x*2)` → `[2,4,6]`
- **`Filter(array, lambda)`**: Keep matching elements — `Filter([1,2,3,4], Fn(x) x>2)` → `[3,4]`
- **`Reduce(array, lambda [, init])`**: Fold to single value — `Reduce([1,2,3], Fn(a,b) a+b, 0)` → `6`
- **`Any(array, lambda)`**: Check if any element matches — `Any([1,2,3], Fn(x) x>2)` → `True`
- **`All(array, lambda)`**: Check if all elements match — `All([2,4,6], Fn(x) x Mod 2 = 0)` → `True`
- **`Find(array, lambda)`**: First matching element — `Find([1,2,3], Fn(x) x>1)` → `2`

### Added - Block Lambda (Multi-Statement) Support
- **Block `Function` Lambdas**: Multi-line lambda bodies with `Return` keyword
- **Block `Sub` Lambdas**: Multi-line statement lambdas invocable via `Call` or direct invocation
- **`invoke_lambda()`**: Consolidated lambda invocation with synthetic `SubDefinition` context
- **`Return` in Lambdas**: Block lambdas use `Return value` to return values (VB-style function-name assignment not required)

### Fixed - Runtime
- **Block Lambda Return Values**: `STMT_RETURN` now correctly captures return values in lambda context via synthetic `current_sub`
- **STMT_CALL Lambda Invocation**: `greet("Alice")` now works when `greet` is a lambda variable
- **Builtin Dispatch from Interpreter**: `call_builtin_expr_evaluated()` now called from interpreter's `CallExpression` handler (was only called from bytecode VM)
- **Parameter Keyword Names**: Parser now accepts keywords like `value`, `get`, `let` as parameter names

### Added - Tests
- `demo/test_block_lambda.vg`: 6 tests for block lambdas, Sub lambdas, IIf short-circuit
- `demo/test_functional.vg`: 11 tests for Map/Filter/Reduce/Any/All/Find with arrow and block lambdas
- `demo/test_classes.vg`: 7 tests for class members, methods, instances, initialize, state mutation

## [2.3.3] - 2026-02-11

### Added - Lambda Syntax Improvements
- **`Fn` Keyword**: Short-form lambda keyword — `Fn(x) x * 2`
- **`Function` Without Arrow**: VB.NET-style lambdas — `Function(x) x * 3`
- **`Sub` Lambdas**: Statement lambdas — `Sub(x) Print x`
- **Optional `=>`**: Arrow is now optional for all lambda keywords
- **Formatter Auto-Replace**: `Lambda(x) => expr` automatically normalized to `Function(x) expr`

### Added - 8 Lambda Syntax Tests
- `demo/test_lambda_syntax.vg`: Covers all 4 lambda forms, multi-param, mixed operators, combo with `??`

## [2.3.2] - 2026-02-10

### Added - Lambda Expressions & Erase Statement
- **Lambda Expressions**: Full runtime support — `Lambda(x) => x * 2` creates callable anonymous functions
- **Lambda Runtime**: Dictionary wrapper with `__vg_lambda` marker, `__vg_params`, `__vg_ast_ptr`
- **Lambda Invocation**: Save/restore variable scoping for proper execution
- **`Erase` Statement**: Clear/reset arrays to default values — `Erase myArray`

### Added - Null Safety Operators
- **Null-Coalescing `??`**: `value ?? "default"` — returns left if not null, else right
- **Null-Safe Navigation `?.`**: `obj?.Property?.Value` — returns null instead of error if base is null

## [2.3.1] - 2026-02-09

### Added - Modern Language Features
- **String Interpolation**: `$"Hello {name}"` with expression support
- **Range Operator**: `1..10` creates array of integers
- **Array Literals**: `[1, 2, 3]` inline array creation
- **Dictionary Literals**: `{"key": value}` inline dictionary creation
- **Using Statement**: `Using f = Open(...) ... End Using` for resource management

## [2.3.0] - 2026-02-09

### Added - Comprehensive Test Infrastructure
- **Performance Test Suite** (`test_performance.vg`): Loop 1M iterations, string concat 1K, array 1K, dictionary 1K, Fibonacci(20) recursion, Factorial(12)
- **Regression Test Suite** (`test_regression.vg`): 28 automated tests covering arithmetic (7), strings (10), control flow (5), functions (4), error handling (1), file I/O (1)
- **Test Checklist** (`VG_TEST_CHECKLIST.md`): Comprehensive 9-section checklist with 264 test items, 251 passing (95.1% completion), 243+ automated tests

### Added - Editor Plugin Features
- **VG IntelliSense Provider**: Full code completion with 70+ keywords, 80+ functions, Godot types, snippet templates
- **VG Go To Definition**: Navigate to Sub/Function/Variable/Class definitions across .vg files
- **VG Linter**: Static analysis - unused variables, missing End statements, deprecated syntax, empty blocks, implicit variants
- **VG Snippet Manager**: 30+ code templates with tab stops and categories (Control Flow, Loops, Procedures, etc.)
- **VG Theme Manager**: 5 built-in themes (VB6 Classic, Modern Dark/Light, High Contrast, Solarized Dark)
- **VG Code Formatter**: Auto-indent, keyword capitalization, operator spacing, format on save
- **VG Recent Projects**: Track and quickly access recent .vg/.vbp projects with pin support

### Added - Language Features
- **Write # Statement**: Full VB6-compatible `Write #` for comma-delimited output with quoted strings
- **Error Code Standardization**: `raise_error()` now passes source parameter through all error paths

### Fixed - Critical Bugs
- **For Loop Safety Limit**: Increased from 1,000 to 10,000,000 — loops were silently capping at 1K iterations
- **Recursive Function Variable Scoping**: Functions now properly save/restore local variables (Dim'd vars, For loop vars, parameters, return var) using DimScanner — fixes corruption in recursive calls like Fibonacci
- **EOF Off-by-One Error**: Changed from `eof_reached()` to `get_position() >= get_length()` — fixes premature EOF detection
- **Array Bounds Error Code**: Now correctly raises error code 9 (Subscript out of range) instead of generic error
- **File Not Found Error Code**: Now correctly raises error code 53 instead of generic error
- **Error Source Passthrough**: `raise_error()` properly propagates source parameter in all 3 code paths

### Changed
- Minimum For loop safety limit now 10,000,000 (was 1,000)
- DimScanner-based selective save/restore for function calls (efficient variable isolation)

## [2.2.4] - 2026-02-08

### Added - Game-Specific Keywords (Section 4.2 Complete)
- **Whenever Event System**: Reactive programming with `Whenever Section Changes(var)` and `Whenever Section Exceeds(var, threshold)`
- **Whenever Control**: `Suspend Whenever`, `Resume Whenever`, `ActiveWheneverCount()`, `WheneverStatus()`
- **Sprite Support**: `CreateNode("Sprite2D")`, `CreateNode("AnimatedSprite2D")`
- **Sound Support**: `CreateNode("AudioStreamPlayer")`, `PlaySound()`
- **Collision Detection**: `HasCollided()`, `CreateTrigger()`, `GetCollisionCount()`
- **Keyboard Input**: `IsKeyDown()`, `Inkey()`, all `KEY_*` constants
- **Mouse Input**: `IsMouseButtonDown()`, `GetMouseX()`, `GetMouseY()`, `MouseClick()`

### Added - Godot Integration (Section 4.1 Complete)
- Full `Input` singleton access: `Input.IsActionPressed()`, `Input.IsActionJustPressed()`, `Input.IsKeyPressed()`, `Input.GetMousePosition()`
- Verified: `Me.name`, `Me.position`, `Me.visible`, `Me.modulate` property access
- Verified: `Me.get_class()`, `Me.has_method()`, `Me.queue_redraw()` method calls
- Verified: `GetNode()`, `Connect()`, `_Process()`, `_Ready()`, `GetDelta()`

### Fixed
- Module-level `Whenever Section` declarations now register correctly during initialization
- `Dim` statements with initializers now execute at module level (e.g., `Dim x As Integer = 5`)
- Case-insensitive variable comparison in Whenever condition checking
- Bytecode `read_local` now re-syncs with `variables` dictionary for proper callback behavior

## [2.2.3] - 2026-02-07

### Added - VB6-Style Control Property Access
- Direct control manipulation: `txtTest.Text = "Hello"`, `lblStatus.Caption = "Ready"`
- VB6 property aliasing: Text, Caption, Visible, Enabled, Left, Top, Width, Height, Value

### Fixed
- `OP_GET_LOCAL` now searches for child controls when local slot is NIL
- `OP_GET_GLOBAL` also searches for child controls when variable not found

## [2.2.1] - 2026-02-05

### Added - Native Compiler Enhancements
- **Select Case Statement**: Full bytecode compilation with multi-value case matching (`Case 1, 2, 3`)
- **Do Loop Statement**: Complete Do While/Until with pre/post conditions
- **Return Statement**: Optional return value support for functions
- **Restore Statement**: DATA pointer manipulation for Read/Data operations
- **IIf Expression**: Ternary operator compilation (`IIf(condition, trueVal, falseVal)`)
- **New Binary Operators**: `Is` (object comparison), `Mod`, `Like` (pattern matching), `\\` (integer division)
- **New Opcodes**: `OP_JUMP_IF_TRUE`, `OP_RESTORE_DATA`, `OP_MOD`, `OP_INT_DIVIDE`, `OP_LIKE`

### Added - Editor Plugin Enhancements
- **VG IntelliSense Provider**: Full code completion with 70+ keywords, 80+ functions, Godot types
- **VG Go To Definition**: Navigate to Sub, Function, Variable declarations across .vg files
- **VG Linter**: Static analysis for unused variables, missing End statements, deprecated syntax
- **VG Snippet Manager**: 30+ code templates with tab stops (if, for, sub, class, etc.)
- **VG Theme Manager**: 5 built-in themes (VB6 Classic, Modern Dark/Light, High Contrast, Solarized)
- **VG Recent Projects**: Track and quickly access recent .vg/.vbp projects

### Fixed
- Unsupported statement type errors for Select Case, Do Loop, Return, Restore
- Unsupported binary operator "Is" causing compilation failures
- Expression type 25 (IIf) not recognized by compiler

## [2.2.0] - 2026-02-05

### Added
- **Components Dialog**: VB6-style dialog for managing optional and custom controls (Project > Visual Gasic Components...)
- **12 New Toolbox Controls**: ProgressBar, HSlider, VSlider, SpinBox, Shape, HLine, VLine, RichText, TabStrip, Files, and more
- **10 Optional Components**: StatusBar, Toolbar, Animation, Calendar, DatePicker, MaskedEdit, Winsock, UpDown, ListView, ImageCombo
- **Functional Calendar Control**: Full month/date picker with configurable properties and events
- **2D Game Controls**: Sprite, AnimatedSprite, Tilemap, RigidBody, CharacterBody, Area, Camera
- **3D Game Controls**: MeshInstance, RigidBody3D, CharacterBody3D, Camera3D, lights, WorldEnvironment, CSGBox
- **VB6 MsgBox Constants**: Full support for button constants (vbOKOnly, vbYesNo, etc.) and icon constants (vbCritical, vbQuestion, etc.)
- **Custom Control Support**: Browse and add your own .tscn prototypes to the Toolbox
- **VB6-Style Properties Panel**: Enhanced inspector with BackColor, ForeColor, Caption, TabIndex, etc.
- **Controls Reference Documentation**: Complete guide to all 40+ toolbox controls

### Changed
- **New Form Dialog**: Resized for better usability, shows 5-6 templates at once
- **Toolbox Organization**: Controls now properly categorized (Standard, Extended, 2D Game, 3D Game, Optional)
- **Components Persistence**: Custom components saved to `custom_components.cfg`

### Fixed
- ProgressBar icon not displaying correctly in toolbox
- VScrollBar default size too small
- Dock panels not resizing properly (removed forced minimum sizes)

## [2.1.0] - 2026-02-03

### Added
- **Vector Math Builtins**: `Vec2`, `Vec3`, `VAdd`, `VSub`, `VMul`, `VDot`, `VCross`, `VLen`, `VNormalize`, `VDistance`, `VLerp`
- **Utility Functions**: `SetProp`, `AddChild`
- **IntelliSense/Autocomplete**: Full code completion with 50+ keywords, 80+ functions, code snippets
- **Go to Definition**: Navigate to function/variable declarations
- **Find All References**: Search for all usages of a symbol
- **Code Formatter**: Auto-format VG code with configurable style
- **Code Linter**: Real-time syntax and style checking
- **Snippet Manager**: Insert common code patterns
- **Theme Manager**: Customizable editor themes
- **Watch Window**: Color-coded value changes, persistence, context menu
- **Snap-to-Grid**: Form designer grid snapping with alignment toolbar
- **Conditional Breakpoints**: Break on condition, hit count, log messages
- **Call Stack Panel**: Visual call stack during debugging
- **Recent Projects List**: Quick access to recent VG projects
- **Form Preview Toolbar**: Preview forms without running
- **Extended Form Templates**: VB6 Classic, Game Forms, Platform-specific, Custom templates
- **Login Form Template**: Pre-built authentication form

### Fixed
- Login Form creation crash (reserved keyword `pass` → `passwd`)
- Form controls not appearing (owner assignment timing)
- GDScript `match` keyword conflict in `vg_formatter.gd`
- `RegEx.sub()` Callable issue in `vg_snippet_manager.gd`

### Changed
- Merged all debugging features into main branch
- Reorganized documentation structure (`docs/reference/`, `docs/guides/`, etc.)
- Updated `.gitignore` to exclude binary files

## [2.0.0] - 2026-01-22

### Added
- **Debugging Support**: Breakpoints, step-through, variable inspection
- **Immediate Window**: REPL for testing expressions
- **Expression Evaluation**: Evaluate VG expressions at breakpoints
- **Data Breakpoints**: Break when variable values change
- **Phase 3 Debug Integration**: Full Godot debugger integration

### Changed
- Migrated from `.bas` files to `.vg` extension
- Updated parser for improved error messages

## [1.5.0] - 2026-01-15

### Added
- **Form Designer**: Visual form builder with drag-and-drop
- **Control Toolbox**: Button, Label, LineEdit, CheckBox, etc.
- **Property Inspector**: Edit control properties visually
- **WinForms-style API**: `Form`, `Me`, event handlers

## [1.0.0] - 2026-01-01

### Added
- Initial release of Visual Gasic
- VB6-compatible syntax parser
- Godot 4.x GDExtension integration
- 80+ built-in functions
- String, Math, Array, Dictionary operations
- File I/O support
- JSON parsing
- Basic error handling

---

## Legend

- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Features to be removed in future
- **Removed**: Features removed in this release
- **Fixed**: Bug fixes
- **Security**: Security-related changes
