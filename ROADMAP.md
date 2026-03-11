# Visual Gasic Development Roadmap

**Last Updated**: March 2026  
**Current Version**: 3.5.0-beta2 (IDE Themes, VB6 Importer, Custom Controls, Language Enhancements)

This document outlines the planned improvements and features for Visual Gasic. Items are prioritized by impact and development effort.

---

## ✅ Recently Completed Features

### v2.4.0 — Classes & Objects, Functional Programming

#### Classes & Objects ✅
**Status**: ✅ Completed  
**Priority**: High  
**Completed**: February 12, 2026

Full VB6/VB.NET-style class system with parser and runtime integration.

**Implemented Features**:
- ✅ `Class...End Class` blocks with members, methods, properties, events
- ✅ `Property Get/Let/Set` accessor definitions
- ✅ `New ClassName` instantiation with unique object IDs
- ✅ `Class_Initialize` constructor (auto-called on `New`)
- ✅ `Class_Terminate` destructor scaffolding
- ✅ `Me` keyword for self-reference inside methods
- ✅ `Public`/`Private` visibility modifiers
- ✅ `Inherits BaseClass` — full runtime: member inheritance, method override (polymorphism), Property Get/Let inheritance, Class_Initialize chain, multi-level (22/22 tests pass)
- ✅ Independent instance state (each `New` creates separate object)

**Files Modified**: `visual_gasic_parser.cpp`, `visual_gasic_parser.h`, `visual_gasic_ast.h`, `visual_gasic_tokenizer.cpp`, `visual_gasic_instance.cpp`

---

#### Functional Programming Builtins ✅
**Status**: ✅ Completed  
**Priority**: High  
**Completed**: February 12, 2026

Higher-order array functions using lambda callbacks.

**Implemented Functions**:
- ✅ `Map(array, lambda)` — Transform each element
- ✅ `Filter(array, lambda)` — Select matching elements
- ✅ `Reduce(array, lambda [, init])` — Fold to single value
- ✅ `Any(array, lambda)` — Check if any match
- ✅ `All(array, lambda)` — Check if all match
- ✅ `Find(array, lambda)` — First matching element

**Files Modified**: `visual_gasic_builtins.cpp`, `visual_gasic_instance.cpp`

---

#### Block Lambda (Multi-Statement) Runtime ✅
**Status**: ✅ Completed  
**Priority**: High  
**Completed**: February 12, 2026

Multi-statement lambda bodies with Return keyword.

**Implemented Features**:
- ✅ Block `Function` lambdas with `Return value`
- ✅ Block `Sub` lambdas with multi-statement bodies
- ✅ `invoke_lambda()` consolidated method with synthetic `SubDefinition`
- ✅ Proper variable scoping and EXIT_SUB handling

**Files Modified**: `visual_gasic_instance.cpp`, `visual_gasic_instance.h`

---

### High Priority - Enhanced Developer Experience

#### 1. Watch Window Enhancements ✅
**Status**: ✅ Completed  
**Priority**: High  
**Completed**: February 3, 2026

Enhanced the Immediate Window's Watch tab with improved functionality:

**Implemented Features**:
- ✅ Color-coded value changes (yellow=changed, green=unchanged)
- ✅ Context menu with "Delete Watch" option
- ✅ Persist watch expressions between sessions (`user://vg_watch_expressions.cfg`)
- ✅ Previous value tracking for comparison
- ✅ GUI input handling for right-click context menu

**Files Modified**: `immediate_window.gd`

---

#### 2. Snap-to-Grid & Alignment Tools ✅
**Status**: ✅ Completed  
**Priority**: High  
**Completed**: February 3, 2026

Full form designer enhancements for precise control placement:

**Implemented Features**:
- ✅ **Grid Snapping**: Configurable grid size with `snap_to_grid()` function
- ✅ **Grid Overlay**: Visual grid drawn on form canvas
- ✅ **Alignment Toolbar**: Added to canvas editor menu
  - Align Left / Center / Right
  - Align Top / Middle / Bottom
  - Distribute Horizontally / Vertically
  - Make Same Width / Height / Both
- ✅ Grid toggle and size controls in toolbar

**Files Created**: `form_editor_helper.gd`, `alignment_toolbar.gd`

---

#### 3. IntelliSense / Autocomplete ✅
**Status**: ✅ Completed  
**Priority**: High  
**Completed**: February 3, 2026

Full code completion system for .vg files:

**Implemented Features**:
- ✅ **50+ VB6 Keywords**: Declaration, control flow, OOP keywords
- ✅ **12 VB6 Data Types**: Integer, Long, String, Boolean, etc.
- ✅ **80+ Built-in Functions**: With signatures and descriptions
- ✅ **30+ Godot Types**: Node types for interop
- ✅ **14 Code Snippets**: sub, func, if, for, select, try, class, etc.
- ✅ **VGCodeEdit**: Custom CodeEdit with syntax highlighting and auto-indent

**Files Created**: `vg_intellisense.gd`, `vg_code_edit.gd`

---

#### 4. Breakpoint Conditions ✅
**Status**: ✅ Completed  
**Priority**: High  
**Completed**: February 3, 2026

Full conditional breakpoint system:

**Implemented Features**:
- ✅ Condition expressions (break when expression is true)
- ✅ Hit count types: equals, greater-equal, multiple
- ✅ Log messages with `{variable}` substitution (tracepoints)
- ✅ Temporary breakpoints (delete after first hit)
- ✅ Full UI dialog for editing conditions
- ✅ Persistence via ConfigFile

**Files Created**: `vg_breakpoint_conditions.gd`, `breakpoint_condition_dialog.gd`

---

#### 5. Call Stack Panel ✅
**Status**: ✅ Completed  
**Priority**: High  
**Completed**: February 3, 2026

Visual call stack display during debugging:

**Implemented Features**:
- ✅ Tree view showing frame #, function name, file:line
- ✅ Click to navigate to stack frame
- ✅ Color-coded current frame (highlighted)
- ✅ Integration with debugger plugin messaging
- ✅ Auto-request call stack on breakpoint hit

**Files Created**: `call_stack_panel.gd`

---

## 🎯 Upcoming Features

## 🎯 Upcoming Features

### Medium Priority - Productivity Features (Recently Completed)

#### 6. Recent Projects List ✅
**Status**: ✅ Completed  
**Priority**: Medium  
**Completed**: February 3, 2026

Quick access to recently opened .vbp/.vg projects.

**Implemented Features**:
- ✅ "Recent Projects" submenu in Tools menu
- ✅ Stores last 10 projects via EditorSettings
- ✅ Pin/unpin favorite projects
- ✅ Clear recent / Clear all options
- ✅ Tooltip shows full path
- ✅ Handles missing files gracefully

**Files Created**: `vg_recent_projects.gd`, `recent_projects_menu.gd`

---

#### 7. Code Formatter / Beautifier ✅
**Status**: ✅ Completed  
**Priority**: Medium  
**Completed**: February 3, 2026

Automatic code formatting for .vg files in VB6 style.

**Implemented Features**:
- ✅ Auto-indent based on blocks (Sub/End Sub, If/End If, etc.)
- ✅ Consistent spacing around operators
- ✅ Keyword capitalization (100+ keywords in proper case)
- ✅ Blank line normalization (configurable max)
- ✅ Format selection only support
- ✅ `.vgformat` config file support
- ✅ FormatOptions class with full customization

**Files Created**: `vg_formatter.gd`

---

#### 8. Find All References ✅
**Status**: ✅ Completed  
**Priority**: Medium  
**Completed**: February 3, 2026

Show all usages of a variable, Sub, or Function.

**Implemented Features**:
- ✅ Results panel with file:line listings
- ✅ Click to navigate to reference
- ✅ Filter by type (Declaration/Read/Write/Call)
- ✅ Search across all .vg files
- ✅ Group results by file
- ✅ Type detection (declaration, read, write, call)

**Files Created**: `find_references_panel.gd`

---

#### 9. Go to Definition ✅
**Status**: ✅ Completed  
**Priority**: Medium  
**Completed**: February 3, 2026

Navigate to Sub/Function/Variable declarations.

**Implemented Features**:
- ✅ Find definition in current file first, then all files
- ✅ Supports Sub, Function, Property, Class, Variable, Const
- ✅ Returns file path, line, column, type, signature
- ✅ Symbol extraction for building indexes
- ✅ Pattern matching for all VB6 declaration styles

**Files Created**: `vg_goto_definition.gd`

---

### Medium Priority - Remaining Features

#### 10. Form Preview ✅
**Status**: ✅ Completed  
**Priority**: Medium  
**Completed**: February 2026

Run just the current form without launching the full game.

**Implemented Features**:
- ✅ "Preview Form" button in toolbar
- ✅ Opens form in popup window
- ✅ Fires Form_Load, Form_Shown events
- ✅ Interactive - buttons, inputs work
- ✅ Close returns to editor
- ✅ Uses `EditorInterface.play_custom_scene()`

---

### v2.6.0 — Custom Icons, IntelliSense Update, Profiler UI

#### 14. Custom .vg File Icons ✅
**Status**: ✅ Completed  
**Priority**: Medium  
**Completed**: February 2026

Custom file icons for .vg files in the Godot FileSystem dock.

**Implemented Features**:
- ✅ Blue file icon with "VG" text for .vg scripts
- ✅ Purple variant for plugin icon
- ✅ SVG-based, scales cleanly at all sizes
- ✅ Registered via editor theme integration

**Files Created**: `vg_file_icon.svg`, `vg_plugin_icon.svg`

---

#### 15. IntelliSense for New Builtins ✅
**Status**: ✅ Completed  
**Priority**: Medium  
**Completed**: February 2026

Updated autocomplete for all v2.5.0 built-in functions.

**Implemented Features**:
- ✅ `Stop` added to VB6 keywords for syntax highlighting
- ✅ `Weekday`, `WeekdayName`, `MonthName` in Date/Time functions
- ✅ `QBColor` in Color functions
- ✅ `Environ`, `Beep` in new System Functions section
- ✅ Full signature and description for each entry

**Files Modified**: `vg_intellisense.gd`

---

#### 16. Integrated Profiler UI ✅
**Status**: ✅ Completed  
**Priority**: Medium  
**Completed**: February 2026

Bytecode-level performance analysis panel in the editor.

**Implemented Features**:
- ✅ "VG Profiler" bottom panel in editor
- ✅ Functions tab: sortable tree (Name, Category, Calls, Total/Avg/Min/Max ms)
- ✅ Counters tab: performance counter display (Name, Value, Updates, Unit)
- ✅ Start/Stop toggle, Refresh, Clear, Export buttons
- ✅ Hot-path coloring (Red ≥50ms, Orange ≥10ms, Yellow ≥1ms, Green <1ms)
- ✅ Auto-refresh timer (2s interval while profiling)
- ✅ JSON export to `user://vg_profile_export.json`
- ✅ C++ profiler bindings via `_vg_profiler_*` instance methods
- ✅ Debug protocol: `visualgasic:profiler_start/stop/get_data/clear`

**Files Created**: `vg_profiler_panel.gd`  
**Files Modified**: `vg_debugger_plugin.gd`, `vg_debug_handler.gd`, `visual_gasic_plugin.gd`, `visual_gasic_instance.cpp`, `visual_gasic_profiler.cpp`

---

### Nice-to-Have - Future Enhancements (Recently Completed)

#### 11. Linting / Warnings ✅
**Status**: ✅ Completed  
**Priority**: Low  
**Completed**: February 2026

Static analysis for code quality.

**Implemented Features**:
- ✅ Unused variable detection
- ✅ Unreachable code warnings
- ✅ Undefined variable usage
- ✅ Deprecated syntax warnings
- ✅ Severity levels (error, warning, info)
- ✅ Inline squiggles in editor (via Godot `_validate()` pipeline)
- ✅ Unused subs/parameters, empty blocks, shadowed variables

---

#### 12. Snippet Manager ✅
**Status**: ✅ Completed  
**Priority**: Low  
**Completed**: February 2026

User-defined code snippets with placeholders.

**Implemented Features**:
- ✅ 30+ built-in snippets across 8 categories
- ✅ Create custom snippets
- ✅ Tabstop placeholders
- ✅ Import/export snippets via ConfigFile
- ✅ Snippet categories (Control Flow, Loops, Procedures, Properties, etc.)
- ✅ Built-in VB6 snippets (For loop, Select Case, etc.)
- ✅ Snippet Browser UI with search, preview, and insert

---

#### 13. Theme Support ✅
**Status**: ✅ Completed  
**Priority**: Low  
**Completed**: February 2026

Visual theme options for the VB6 experience.

**Implemented Features**:
- ✅ Classic VB6 blue theme
- ✅ Modern dark theme
- ✅ Modern light theme
- ✅ High Contrast and Solarized Dark themes
- ✅ Custom color schemes (23 configurable properties)
- ✅ Font settings (name, size, bold keywords)
- ✅ Theme Picker UI with live preview
- ✅ Persistence via user config files

---

## ✅ Recently Completed

### Form Template System (v2.0.0)
**Completed**: February 2026

- 23 form templates across 4 categories:
  - VB6 Classic (9 templates)
  - Game Forms (8 templates)
  - Platform-Specific (6 templates)
  - Custom Templates (user-defined)
- Custom template save/load/delete
- `.vgtemplate.json` format support

### Remote Debugger (v2.0.0)
**Completed**: January 2026

- Phase 1: Line Number Tracking
- Phase 2: Breakpoint Integration
- Phase 3: Pause/Resume via Godot Debugger
- Data breakpoints (watchpoints)
- Expression evaluation at breakpoints

### Immediate Window (v1.5.0)
**Completed**: January 2026

- Interactive REPL
- Remote debugging connection
- Variable inspection and modification
- Watch expressions

---

## 📊 Implementation Priority Matrix

| Feature | Impact | Effort | Priority |
|---------|--------|--------|----------|
| Watch Window | High | Medium | 1 |
| Snap-to-Grid | High | Medium | 2 |
| IntelliSense | Very High | High | 3 |
| Breakpoint Conditions | High | Medium | 4 |
| Call Stack Panel | High | Low | 5 |
| Recent Projects | Medium | Low | 6 |
| Code Formatter | Medium | Medium | 7 |
| Find All References | Medium | Medium | 8 |
| Go to Definition | Medium | Medium | 9 |
| Form Preview | Medium | Medium | 10 |
| Linting | Low | Medium | 11 |
| Snippet Manager | Low | Low | 12 |
| Theme Support | Low | Low | 13 |
| Custom .vg File Icons | Medium | Low | 14 |
| IntelliSense Builtins Update | Medium | Low | 15 |
| Integrated Profiler UI | High | Medium | 16 |

---

## 🔧 Contributing

Want to help implement these features? See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Each feature has implementation notes that describe:
- Which files to modify
- Existing infrastructure to leverage
- Integration points with current systems

---

## 📝 Version History

- **v3.5.0-beta2** (Current) - IDE Themes, Custom Theme Editor, Object Browser, VB6 Importer Enhancements, Documentation Generator, Custom Control Designer, Windows CI, 15+ Bug Fixes
- **v3.3.0** - Language Enhancements: 18 new features (String Interpolation, Bitwise, StringBuilder, RegExp, Static locals, etc.)
- **v3.2.0-beta1** - JIT Compiler, LSP, Performance, First Public Beta
- **v3.1.0** - System-Level Programming: VGSystem, Signals, Permissions, Memory, IPC, Android, Real Threading
- **v3.0.0** - System Integration: FFI, ODBC, Crypto, XML, ZIP, Tasks, Packages, Cross-Platform System Calls, COM Interop
- **v2.8.0** - VB6 Importer (15 fixes), Form Designer, Godot 4.6.1 Support
- **v2.7.0** - Theme Picker, Form Preview, Screenshot Overhaul
- **v2.6.1** - Bytecode Compiler Batches 1-4 (39 tests), Updated Benchmarks (18.9× geo mean vs GDScript)
- **v2.6.0** - Custom .vg Icons, IntelliSense Update, Profiler UI
- **v2.5.0** - Computed Gotos, 11 New Builtins, Stop Statement, Conditional Breakpoints, 12 Demo Projects
- **v2.0.0** - Advanced Features Release
- **v1.5.0** - Immediate Window and debugging
- **v1.0.0** - Initial release with VB6 compatibility

---

## 🚀 v3.0 Roadmap — "Production Ready"

Targeted improvements for a stable 3.0 release:

### ✅ Completed in v3.1 — System-Level Programming

All items from the system-programming audit are now implemented:

1. **VGSystem** — Cross-platform system info (hostname, CPU, RAM, disk, OS, uptime, env, locale)
2. **VGSignalHandler** — OS signal handling (SIGINT/SIGTERM/SIGHUP/atexit + Windows SetConsoleCtrlHandler)
3. **VGFilePermissions** — File permissions (chmod, chown, symlinks, locking, VB6 GetAttr/SetAttr)
4. **VGMemoryBuffer** — Raw memory (Peek/Poke, CopyMemory, HexDump, FFI pointer)
5. **VGIPC** — IPC (named pipes, UNIX domain sockets, shared memory)
6. **Real Threading** — Task.Run / Parallel For / Parallel Section backed by real std::thread
7. **VGAndroidBridge** — JNI bridge (device info, permissions, intents, toast, vibrate, battery)

### 🔴 High Priority

1. ~~**LSP Integration**~~  ✅ **Done (v3.2)**
   Resolved `LspPosition` type conflict — public methods now use `int line, int character` params.  
   LSP class registered, all methods bound. Enables: go-to-definition, hover docs, diagnostics, symbol search.

2. ~~**Refactor visual_gasic_instance.cpp**~~ ✅ **Done (v3.2)**
   Split 8K-line core into focused `.inc` modules: `_evaluate.inc` (2537 lines), `_execute.inc` (2435 lines), `_call.inc` (1730 lines).  
   Main file reduced to 1497 lines of preamble, constructor, and property system.

3. ~~**Automated Release Pipeline**~~ ✅ **Done (v3.2)**
   Added `.github/workflows/release.yml` — tag-triggered Linux + Windows builds, addon .zip packaging, GitHub Release publishing.  
   Windows cross-compilation CI job also added to `ci.yml`.

4. ~~**Remaining Bytecode Gaps**~~ ✅ **Resolved (v3.2)**
   The "2 failing tests (interop fusion, allocation fusion)" were stale — no such tests exist in the codebase.  
   All 4 compiler test batches pass. Struct/Class opcodes (OP_GET_MEMBER, OP_SET_MEMBER, OP_NEW_OBJECT, OP_IS_CLASS) are fully implemented.

### 🟡 Medium Priority

5. **macOS / ARM64 Build**  
   Add `platform=macos` CI job with universal binary (x86_64 + arm64). Validate GDExtension loads on Apple Silicon.

6. **Windows CI Testing**  
   Add a `windows-latest` runner to CI. Cross-compile with MinGW or use MSVC.

7. **Runtime Error Recovery** ✅ Done  
   VB6 `On Error Resume Next` / `On Error GoTo` runtime plumbing for production scripts.  
   *Implemented*: Centralized `try_recover_error` lambda covers all 37+ `raise_error` sites.  
   Nested `Try/Catch` via `TryHandler` stack replaces single-handler approach.  
   Division-by-zero check added to `OP_DIV_F64` fast path.  
   `raise_error()` now creates the `Err` dictionary lazily and sets `error_state.code`.  
   File I/O errors (Open/Print/Write/Input/LineInput) now recoverable.

8. **Debugger Protocol v2** ✅ Done  
   Wire Godot's `EngineDebugger` messages for watch expressions, conditional breakpoints, and step-over-bytecode.  
   *Implemented*: Watchpoint checking in `OP_DEBUG_LINE` handler; 6 new protocol messages  
   (`add_watchpoint`, `remove_watchpoint`, `clear_watchpoints`, `get_watchpoints`,  
   `eval_watch_expressions`, `set_conditional_breakpoint`).  
   Step debugging stubs wired to C++ `VisualGasicLanguage` static methods.  
   Editor-side `vg_debugger_plugin.gd` extended with matching API.

### 🟢 Nice-to-Have

9. **Hot Reload** ✅  
   Detect .vg file saves and re-parse without restarting the scene.  
   *Implemented*: Script registry (`live_scripts` set) in `VisualGasicLanguage` with  
   `register_script()` / `unregister_script()` lifecycle.  `_frame()` polls  
   `pending_reloads`, re-reads source from disk, calls `_set_source_code()` +  
   `_reload(true)`.  `_reload_all_scripts()` refreshes every live script.  
   `_reload_tool_script()` queues via `pending_reloads` to avoid re-entrancy.  
   Thread-safe via `std::mutex`.

10. **Asset Library Submission** ⏳  
    Package for Godot Asset Library (requires single-addon zip with proper plugin.cfg).  
    *Status*: Submitted March 2026, awaiting Godot team review.

11. **Documentation Generator** ✅  
    Parse `'''` doc comments from .vg files and emit HTML/Markdown API docs.  
    *Implemented*: `doc_generator.gd` — Tools → Generate Documentation. Parses `'''` triple-apostrophe  
    doc-comments with `@param`, `@return`, `@example` tags. Generates Markdown and/or HTML  
    index + per-module detail pages. Supports Const, Dim, Enum, Type, Sub, Function.  
    Filter options for private members and event handlers. VB6 cream-themed config dialog.  
    Example project in `demos/Utilities/DocGen_Example/` with 4 fully-documented .vg files.

12. **JIT Tier 2** ✅  
    Extend the JIT framework from simple loops to full function bodies (requires register allocator).  
    *Implemented*: Native x86-64 function body compilation in `visual_gasic_jit_tier2.h/cpp`.  
    Pipeline: bytecode → typed IR (`IROp` / `IRInst`) → linear-scan register allocation  
    (`LiveRange` / `RegAlloc`) → x86-64 machine code (`CodeBuf` emitter) → `mmap`+`mprotect`  
    executable memory.  Supports integer/float arithmetic, locals load/store, comparisons,  
    branches, loops, return values.  Hot detection at threshold 50 calls; unsupported opcodes  
    gracefully fall back to interpreter.  Activated via `VG_JIT=2` environment variable.

13. **Custom Control Designer (UserControl Editor)** ✅  
    A WYSIWYG editor for designing reusable custom controls — wobbly buttons, animated  
    dropdowns, themed game UI widgets, etc. Users design a control visually, save it as a  
    `.tscn`, and it appears in the Toolbox alongside the built-in controls for drag-and-drop  
    reuse across any form.  
    *Implemented*: `custom_control_designer.gd` (~630 lines). Tools → New Custom Control /  
    Edit Custom Control. 16 child node types, snap grid, drag/move/resize handles,  
    SubViewport live preview, PackedScene `.tscn` save with proper owner chain.  
    Auto-registers in Toolbox via `register_custom_control_type()`.


14. **Live Animation for Custom Controls in Form Designer (v4)**  
    Currently, custom controls are rendered in the Form Designer as **static preview
    textures** — a single SubViewport snapshot captured once at startup via
    `_generate_preview_for_custom_control()` and stored through
    `set_control_preview_texture()`.  This means `@tool` controls like WobblyButton
    that animate via `_process()` appear frozen at design time, even though they
    animate correctly in Godot's 2D editor (which instantiates real scene nodes).  
    **Goal**: Replace the static-texture path with **live embedded SubViewports** so
    each custom control instance in the Form Designer runs its `@tool` script in
    real time, showing wobble, pulse, glow, particle effects, and shader animations
    right on the design surface.  
    **Approach**:  
    - Maintain a per-instance `SubViewportContainer` + `SubViewport` for every custom
      control placed on the form (instead of one shared static texture per type)  
    - Instantiate the control's `.tscn` inside its SubViewport so `_process()` runs
      every frame and animations play live  
    - Blit each SubViewport's `ViewportTexture` in `_draw()` at the control's rect,
      replacing the current `draw_texture()` call for custom types  
    - Add a "Freeze Previews" toggle (toolbar button or property) for users who
      prefer the lightweight static snapshots or have many heavy custom controls  
    - Throttle live viewports to ~15 FPS when the Form Designer tab is not focused
      to save CPU/GPU  
    **Foundation already in place**: SubViewport capture pipeline in GDScript,
    `control_preview_textures` HashMap in C++, per-control rect tracking in
    `FormControlItem`, custom control `.tscn` scene_path storage.

---

## ✅ v3.6 Roadmap — "Modern Language Features"

Language-level additions inspired by twinBASIC, VB.NET, and modern BASIC dialects.
Strategic goal: make VisualGasic's *language* competitive with twinBASIC and RAD Basic
while leaning into our unique advantage — cross-platform game engine integration.

> **Already shipped:** `Inherits` (v2.4.0), `AndAlso`/`OrElse` (v3.4),
> `Return <expr>` (v3.5), `Continue For/Do/While` (v3.5), Classes + Properties (v2.4).
> **v3.6.0 shipped:** Compound Assignment (`+=` etc.), Bit-Shift (`<<` `>>`), `LongLong` type.
> **v3.7.0 shipped:** Method Overloading, Parameterized Constructors, Generics Phase 1, Game UI Mode.

### ✅ Shipped in v3.6.0

1. **Compound Assignment Operators — `+=  -=  *=  /=  \=  &=  ^=  <<=  >>=`** ✅
   Desugared at parse time into equivalent `x = x op y`. All 9 operators work on any L-value.
   31 test assertions (10 compound, 12 bit-shift, 9 combined).

2. **Bit-Shift Operators — `<<  >>`** ✅
   New precedence level between comparison and addition (VB.NET-compatible).
   `OP_SHL`/`OP_SHR` bytecode opcodes. 12 test assertions.

3. **`LongLong` (64-bit Integer) Type** ✅
   Type alias for `Long`. `CLngLng()` conversion function. Works in `Dim`, arrays,
   arithmetic, bit-shift. 8 test assertions.

### ✅ Shipped in v3.7.0

4. **Method Overloading** ✅
   Multiple `Sub`/`Function` signatures with the same name but different parameter counts.
   Arity-based dispatch in compiler, bytecode VM, and AST interpreter. Class method
   overloading via `find_method_in_hierarchy`. Falls back to first-match for backward compat.
   11 test assertions.

5. **Parameterized Constructors — `New ClassName(args)`** ✅
   `New Bullet(speed, angle, damage)` and `Dim b As New Bullet(100, 45, 10)` both work.
   Parser fixes for 2nd `New` path and `Dim As New` path. Runtime already supported args
   passthrough to `Class_Initialize`. 8 test assertions.

6. **Generics (Typed Collections) — `Collection(Of T)`** ✅
   `Dim enemies As New Collection(Of Sprite)` with runtime type-check on `.Add()`.
   Parser `(Of T)` lookahead distinguishes from constructor args. Auto-instantiation
   for `Dim col As Collection(Of Integer)` without `New`. 12 test assertions.

9. **Game UI Mode for Form Designer** ✅
   Form Designer generates `CanvasLayer` root (layer 10) with full-rect `Control` child
   instead of `Window` when game UI mode is enabled. Dark canvas background with crosshair
   guides, safe area rectangle, and "GAME UI" badge. Toolbox gains 11 game UI controls:
   HealthBar, ScoreLabel, DialogBox, MiniMap, Inventory, ActionButton, AmmoCounter,
   BossBar, Crosshair, Tooltip, Pointer.

### 🟢 Nice-to-Have — Ecosystem Alignment

7. **Additional Compound Operators — `And=  Or=  Xor=  Mod=`**
   Bitwise compound assignment for flag manipulation:
   `collisionMask And= Not(LAYER_WATER)`. Lower priority than the arithmetic
   compounds above because they're less commonly used.
   **Effort**: ~1 hour (pattern identical to item 1)

8. **`Enum` with Explicit Values**
   VB6/twinBASIC `Enum` declarations with explicit member values. Currently VG
   uses `Const` blocks for this. Proper `Enum` gives IntelliSense grouping,
   type safety, and `Enum.ToString()`.
   **Scope**:
   - `Enum Direction: Up = 0 : Down = 1 : Left = 2 : Right = 3 : End Enum`
   - Auto-increment when values are omitted
   - `[Flags]` attribute for bitfield enums
   **Effort**: ~3–4 hours

### 📊 v3.6 Priority Matrix

| # | Feature | Game Dev Value | Effort | Status |
|---|---------|---------------|--------|--------|
| 1 | Compound Assignment `+=` etc. | ⭐⭐⭐⭐⭐ | 2–3 hrs | ✅ Shipped |
| 2 | Bit-Shift `<<` `>>` | ⭐⭐⭐⭐ | 2–3 hrs | ✅ Shipped |
| 3 | `LongLong` type alias | ⭐⭐⭐ | 1 hr | ✅ Shipped |
| 4 | Method Overloading | ⭐⭐⭐⭐ | 4–6 hrs | ✅ Shipped |
| 5 | Parameterized Constructors | ⭐⭐⭐⭐⭐ | 3–4 hrs | ✅ Shipped |
| 6 | Generics Phase 1 | ⭐⭐⭐⭐ | 6–8 hrs | ✅ Shipped |
| 7 | Enum Declarations | ⭐⭐⭐ | 3–4 hrs | 🟢 Nice-to-have |
| 8 | Game UI Mode | ⭐⭐⭐⭐⭐ | 6–8 hrs | ✅ Shipped |

### ❌ Deliberately Skipped (Not Relevant to Game Engine)

These twinBASIC / RAD Basic features were evaluated and intentionally excluded:

| Feature | Reason |
|---------|--------|
| COM / ActiveX | Windows-only, no game use case |
| Win32 API (`Declare Function`) | Godot has its own platform API |
| Standalone `.exe` compilation | Godot handles export to all platforms |
| WebView2 embedding | Use Godot's UI system instead |
| Inline assembly | Security risk in a scripting language |
| Static linking | Godot GDExtension handles linking |
| LLVM backend | Our JIT + Godot VM is sufficient |
| Report Designer | Not relevant to game development |
| DPI awareness | Godot handles DPI scaling natively |

---

## �🚀 v4.0 Roadmap — "Next Generation"

Targeted improvements for a major v4.0 release. Requires v3.5.0 stable first.

### Prerequisites — Ship v3.5.0 Stable

Before v4 development begins, the current beta must graduate:

- [ ] **macOS / ARM64 CI build** — Add `platform=macos` CI job with universal binary (x86_64 + arm64). Validate GDExtension loads on Apple Silicon.
- [ ] **Asset Library acceptance** — Submitted, awaiting Godot team review.
- [ ] **Calculator tutorial screenshots** — Capture real screenshots for all 📸 placeholders in `docs/tutorials/calculator_form_designer.md`.
- [ ] **Beta → Stable testing pass** — Full test suite run, verify all demos, tag v3.5.0 stable.

### 🔴 High Priority — Flagship Features

1. **Live Animation for Custom Controls in Form Designer**  
   Replace static SubViewport snapshots with per-instance live SubViewports so  
   `@tool` controls (WobblyButton, particle effects, shader animations) play in  
   real time on the Form Designer design surface.  
   **Approach**:  
   - Per-instance `SubViewportContainer` + `SubViewport` for every custom control  
   - Instantiate `.tscn` inside SubViewport so `_process()` runs every frame  
   - Blit `ViewportTexture` in `_draw()` at the control's rect  
   - "Freeze Previews" toolbar toggle for lightweight static mode  
   - Throttle to ~15 FPS when Form Designer tab is unfocused  
   **Foundation**: SubViewport capture pipeline, `control_preview_textures` HashMap,  
   per-control rect tracking, `.tscn` scene_path storage.  
   **Effort**: ~4–6 hours

2. **Multi-Module Project Compilation**  
   Currently each `.vg` file is standalone. Add a project-level compilation model  
   where `Import MathHelpers` resolves symbols across files with proper symbol tables  
   and cross-file IntelliSense.  
   **Scope**:  
   - `Import <ModuleName>` statement parsed in tokenizer/parser  
   - Project-wide symbol table built at compile time  
   - Cross-file go-to-definition and find-all-references  
   - Circular import detection  
   - IntelliSense autocomplete includes imported module members  
   **Effort**: ~8–12 hours (parser + VM + IntelliSense changes)

3. **Visual Form Debugger**  
   Click a control on the running form → jump to its event handler source.  
   Hover a control → tooltip shows its live property values. Inspect  
   `Me.Controls` tree during a breakpoint.  
   **Scope**:  
   - Design-time control → source line mapping  
   - Runtime overlay on form showing control names and live values  
   - "Inspect" context menu on running forms  
   - Integration with existing debugger protocol (watchpoints, breakpoints)  
   **Effort**: ~6–8 hours

### 🟡 Medium Priority — Ecosystem Features

4. **Database Controls (Data, DBGrid, DBCombo)**  
   VB6's killer feature: data-bound controls. SQLite-backed `Data` control with  
   bound `DBGrid`/`DBCombo` for the VB6 nostalgia crowd.  
   **Scope**:  
   - `Data` control wrapping SQLite (via Godot's built-in SQLite or GDExtension)  
   - `DBGrid` — read/write data grid bound to a `Data` source  
   - `DBCombo` — dropdown populated from a query column  
   - `Recordset` object with `MoveFirst`/`MoveNext`/`MoveLast`/`AddNew`/`Update`/`Delete`  
   - SQL query property on `Data` control  
   - Design-time column layout in Form Designer  
   **Effort**: ~8–10 hours

5. **Package Manager**  
   `vg install <package>` to pull .vg libraries from a registry (GitHub-based).  
   **Scope**:  
   - `vg.json` project manifest with dependencies  
   - `Imports` resolution from `vg_modules/` folder  
   - GitHub-backed registry (simple JSON index + tagged releases)  
   - `vg install`, `vg update`, `vg remove` CLI commands  
   - Tools menu integration for GUI-based package browsing  
   **Effort**: ~6–8 hours

6. **Migration Wizard v2 (Full VBP Import)**  
   Import entire VB6 `.vbp` projects (multi-form, modules, classes, references)  
   in one click, not just individual `.frm` files.  
   **Scope**:  
   - Parse all `.vbp` entries: Form=, Module=, Class=, Reference=, Object=  
   - Batch-import all forms, modules, and classes  
   - Generate project structure with proper `Import` statements  
   - Conversion report summarizing what worked and what needs manual fixes  
   - Build on existing `frm_import_plugin.gd` and `vbp_parser` infrastructure  
   **Effort**: ~4–6 hours

### 🟢 Nice-to-Have — Performance & Platform

7. **macOS Universal Binary**  
   Fill the last platform gap with fat binary (x86_64 + arm64).  
   **Scope**:  
   - macOS CI job (GitHub Actions `macos-latest` or `macos-14` for ARM)  
   - `lipo` to combine architectures into universal binary  
   - Code-signing for Gatekeeper compliance  
   - Release pipeline integration  
   **Effort**: ~2–3 hours

8. **JIT Tier 3 (Call Graph Compilation)**  
   Extend JIT from hot function bodies to entire call graphs — inline small  
   callees, eliminate call overhead for tight inner loops.  
   **Scope**:  
   - Call graph analysis to identify hot call chains  
   - Function inlining heuristic (size threshold, call frequency)  
   - Inter-procedural register allocation  
   - Would push more benchmarks past C++  
   **Effort**: ~10+ hours

9. **WebAssembly Export Validation**  
   Godot already exports to HTML5. Ensure VisualGasic scripts work correctly  
   in web builds (bytecode VM path, no JIT) and document the workflow.  
   **Scope**:  
   - Test all language features in HTML5 export  
   - Disable JIT gracefully on WASM (already falls back to interpreter)  
   - Fix any threading/IPC issues (no real threads in WASM)  
   - Demo project deployed to itch.io or GitHub Pages  
   **Effort**: ~3–4 hours

### 📊 v4.0 Priority Matrix

| # | Feature | Impact | Effort | Priority |
|---|---------|--------|--------|----------|
| 1 | Live Animation | High | 4–6 hrs | 🔴 Must-have |
| 2 | Multi-Module Imports | Very High | 8–12 hrs | 🔴 Must-have |
| 3 | Visual Form Debugger | High | 6–8 hrs | 🔴 Must-have |
| 4 | Database Controls | High | 8–10 hrs | 🟡 Should-have |
| 5 | Package Manager | Medium | 6–8 hrs | 🟡 Should-have |
| 6 | Migration Wizard v2 | Medium | 4–6 hrs | 🟡 Should-have |
| 7 | macOS Universal | Medium | 2–3 hrs | 🟢 Nice-to-have |
| 8 | JIT Tier 3 | Medium | 10+ hrs | 🟢 Nice-to-have |
| 9 | WASM Validation | Low | 3–4 hrs | 🟢 Nice-to-have |
| | **Total (must-have)** | | **~20–26 hrs** | |
| | **Total (all)** | | **~52–67 hrs** | |

---

*This roadmap is a living document. Priorities may shift based on community feedback and development resources.*
