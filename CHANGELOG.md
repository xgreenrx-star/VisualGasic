# Changelog

All notable changes to Visual Gasic will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
