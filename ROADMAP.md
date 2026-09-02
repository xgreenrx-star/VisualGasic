# Visual Gasic Development Roadmap

**Last Updated**: August 30, 2026  
**Current Version**: 5.4.0-beta1 (current public beta) — see [`CHANGELOG.md`](CHANGELOG.md) for the full set  
**Current Scope**: M0–M9 milestones (Jul 2026 – Jan 2027 stable release)  
**Next Cut**: v5.4.0-beta2 (Oct 15, 2026) — see [`RELEASE_SCHEDULE.md`](RELEASE_SCHEDULE.md) and [`docs/VERSIONING.md`](docs/VERSIONING.md)

**Roadmap Scope**:
- ✅ **M0–M9 milestones** (Jul 2026 – Jan 1 2027): Current active development
- 📖 **v2.4–v5.0 Completed Features** (lines ~120–1000): Historical context — these are shipped
- 🚀 **v6.0 In-Scope Features** (lines ~1000–1100): Core language/Godot integration for stable release
- 🌌 **v7.0+ Out-of-Scope** (lines ~1100+): Explicitly mothballed until post-v6.0 stable
- **VG Standalone IDE Shell**: Mothballed behind `vg/enable_experimental_plugins` — focus is Godot IDE integration only (Toolbox, Properties, Code Navigator, autocomplete, Narcea AI Pair)

This document outlines the planned improvements and features for Visual Gasic. Items are prioritized by impact and development effort. **Aspirational items live in v6.0 / v7.0 sections — do not pull them forward.**

---

## Project Goal

> Write your Godot game logic in plain English with AI, get back code that reads like a document, not a puzzle. VisualGasic brings the clarity of VB6 to Godot — AI writes it, you understand it.

LLMs were trained on decades of VB/VBA/VBScript. That prior knowledge transfers directly to VisualGasic. The Godot indie developer using AI-assisted workflows gets code that is linearly auditable — explicit `End Sub`, `Dim x As String`, `If...Then...End If` — not a wall of braces that requires an IDE to follow. The language is the audit trail.

---

## ✅ Shipped in v5.4.0-beta1 (Aug 30, 2026)

| Feature | Notes |
|---------|--------|
| **12/12 compute + 9/9 draw** | Full published benchmark suite faster than GDScript; FunctionCall fixed via compiler inlining + nested-loop fusion |
| **Draw grid-loop fusion** | Hot `_Draw` paths compile to native `OP_DRAW_*_GRID_LOOP` opcodes |
| **CI benchmark regression gate** | `scripts/benchmark_regression_check.sh` blocks speed regressions |
| **891/891 regression assertions** | `.vg` test suite green (122 runnable files) |
| **VG Beta Showcase** | `projects/vg_beta_showcase/` — Backrooms hub tour, shader reel, About VG, Squash tease, Neon Runner, Vector Storm; Movie Maker script |
| **Track D groundwork** | `DataFile` / `.vgd` sidecar, context rail preview, Tiled import hooks |
| **CInt VB6 rounding** | `CInt(3.7)` → 4, not truncated 3 |

Full notes: [`RELEASE_NOTES_v5.4.0-beta1.md`](RELEASE_NOTES_v5.4.0-beta1.md)

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

- **v5.3.0-Beta3** (2026-07-31) - C64 Emulator + GBA Emulator demos (real ROMs), cross-module bytecode compilation for imported Subs, MemoryBuffer global support, Buffer Type + Optimizer Hints (#4/#5), `Global` keyword, cross-file class `Import`, `Exit While`, ~21-40% call/hot-path overhead reduction, DeepSeek AI provider, 777/777 assertions, 54 corpus examples
- **v5.3.0-Beta2** (2026-07-15) - Python bridge int/float decode fix, `IsNot` operator, ByRef write-back fix, Codeium/Amazon Q AI providers, Python/C++ FFI demos, Narcea AI Pair floating window, Thrust tribute demo
- **v5.2.0-Beta4** (2026-05-11) - Android plugin (GPS/Steps/Sensor), Pass-6 namespace verbs (Camera.PanTo/Bounce, Crypto.Hex/Base64, Physics.GravityV2/V3, Ray.Cast2D/Cast3D, Joypad.Stick, Sensor.Magnetometer, Theme/Shader/Speaker.Bus…), 358-entry Command Help DB, AI correctness 100% on Claude Sonnet 4.5 and qwen2.5-coder:7b, Browser Dashboard (5 phases + headless + tray)
- **v5.1.0-rc.2** - Release candidate 2 for v5.1.0 stable line
- **v5.1.0-rc.1** - Release candidate 1; Fix-with-AI diff repair, AI voice mode (PTT)
- **v5.1.0-Beta1** - VG Welcome launcher, first-run wizard, AGCK templates, 3D pipeline, Make EXE, Publish to Web, Live Control Animation, Multi-Provider AI Help, WebSocket Controls, cross-platform installers
- **v4.2.0-beta4** - GDScript Parity: Export, Await, Import, ClassName, $NodeName + "Why VG" docs
- **v4.1.0** - Property System Overhaul: 70+ runtime properties, Font/BackColor/ForeColor/BorderStyle sub-resources
- **v4.0.0** - Game UI Form Designer: 7 Tier 1 animated controls (DialogPanel, InventoryGrid, StatBar, etc.)
- **v3.8.0** - Compound logical operators (And=/Or=/Xor=/Mod=), `<Flags>` enum, compile-time dot access
- **v3.7.0** - Method Overloading, Parameterized Constructors, Collection(Of T) Generics, Game UI Mode
- **v3.6.0** - Compound Assignment (`+=` etc.), Bit-Shift (`<<` `>>`), `LongLong` type
- **v3.5.0-beta2** - IDE Themes, Custom Theme Editor, Object Browser, VB6 Importer Enhancements, Documentation Generator, Custom Control Designer, Windows CI, 15+ Bug Fixes
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

### 🟢 Nice-to-Have — Ecosystem Alignment (Shipped in v3.8.0)

7. **Additional Compound Operators — `And=  Or=  Xor=  Mod=`** ✅
   Bitwise compound assignment for flag manipulation:
   `collisionMask And= Not(LAYER_WATER)`. These keywords are two-token sequences
   (keyword + `=`) desugared at parse time. `And`/`Or`/`Xor` also upgraded to
   bitwise-when-numeric (VB6 semantics). 12 test assertions.

8. **`Enum` with `<Flags>` Attribute** ✅
   Enhanced existing Enum with `<Flags>` attribute for bitfield enums.
   `HasFlag(value, flag)` method, flags-aware `ToString()` decomposition, and
   compile-time dot access resolution in the bytecode compiler. 26 new test
   assertions (35 total).

### 📊 v3.6 Priority Matrix

| # | Feature | Game Dev Value | Effort | Status |
|---|---------|---------------|--------|--------|
| 1 | Compound Assignment `+=` etc. | ⭐⭐⭐⭐⭐ | 2–3 hrs | ✅ Shipped |
| 2 | Bit-Shift `<<` `>>` | ⭐⭐⭐⭐ | 2–3 hrs | ✅ Shipped |
| 3 | `LongLong` type alias | ⭐⭐⭐ | 1 hr | ✅ Shipped |
| 4 | Method Overloading | ⭐⭐⭐⭐ | 4–6 hrs | ✅ Shipped |
| 5 | Parameterized Constructors | ⭐⭐⭐⭐⭐ | 3–4 hrs | ✅ Shipped |
| 6 | Generics Phase 1 | ⭐⭐⭐⭐ | 6–8 hrs | ✅ Shipped |
| 7 | Compound Logical `And=` etc. | ⭐⭐⭐ | 1 hr | ✅ Shipped |
| 8 | Enum `<Flags>` / HasFlag | ⭐⭐⭐ | 3–4 hrs | ✅ Shipped |
| 9 | Game UI Mode | ⭐⭐⭐⭐⭐ | 6–8 hrs | ✅ Shipped |

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

## ✅🚀 v4.0 Roadmap — "Next Generation" — COMPLETE

All v4.0 roadmap features have been implemented as of v4.3.0 (March 21, 2026).

### ✅ Completed — v3.6.0 through v4.3.0

These features shipped between March 10–21, 2026:

- [x] **v3.6.0** — Compound assignment (`+=`, `-=`, etc.), bit-shift (`<<`, `>>`), `LongLong` type
- [x] **v3.7.0** — Method overloading, parameterized constructors, Generics Phase 1, Game UI Mode
- [x] **v3.8.0** — Keyword compound (`And=`, `Or=`, `Xor=`, `Mod=`), bitwise semantics, `<Flags>` enum, compile-time dot access
- [x] **v4.0.0** — 7 Tier 1 animated Game UI controls (DialogPanel, InventoryGrid, StatBar, HUDCounter, CooldownButton, NotificationToast, GameMenu)
- [x] **v4.1.0** — Property System Overhaul: 70+ runtime property translations, Font/BackColor/ForeColor/BorderStyle/ShapeColor sub-resources, complete live preview, full round-trip parser
- [x] **v4.2.0** — GDScript Parity: `Export`, `Await`, `Import`, `ClassName`, `$NodeName` + "Why VisualGasic" documentation
- [x] **v4.2.0-beta6** — Drawing APIs, 18 new VB6 commands, 13 financial functions, IDE enhancements, macOS build, documentation overhaul
- [x] **v4.3.0** — Multi-Module Compilation, Visual Form Debugger, Database Controls, Package Manager, macOS Universal Binary, JIT Tier 3
- [ ] **Calculator tutorial screenshots** — Capture real screenshots for all 📸 placeholders in `docs/tutorials/calculator_form_designer.md`

### Prerequisites — Ship to Platform

- [x] **macOS / ARM64 CI build** — Added `build-macos` job to `release.yml`. Builds x86_64 + arm64, `lipo` into universal framework. Triggered on tag push alongside Linux and Windows.
- [x] **macOS Universal Binary** — `scripts/build_macos_universal.sh` + `.github/workflows/macos-universal.yml` CI workflow
- [x] **Asset Library acceptance** — ✅ **ACCEPTED (Aug 13, 2026)** — Visual Gasic is now available on Godot's official Asset Library at https://store.godotengine.org/asset/visual-gasic/visual-gasic/

### ✅ High Priority — Flagship Features (ALL COMPLETE)

1. ~~**Live Animation for Custom Controls in Form Designer**~~ — *Skipped (static preview sufficient for current use cases)*

2. **✅ Multi-Module Project Compilation** *(Completed v4.3.0)*  
   Cross-file `Import` with project-wide symbol tables, circular import detection, and cross-file IntelliSense.

3. **✅ Visual Form Debugger** *(Completed v4.3.0)*  
   Controls Inspector panel with tree view, click-to-source, and debugger integration.

### ✅ Medium Priority — Ecosystem Features (ALL COMPLETE)

4. **✅ Database Controls (Data, DBGrid, DBCombo)** *(Completed v4.3.0 — SQLite path; ODBC parity planned v6.1+)*  
   VGRecordset C++ class with ADODB.Recordset-compatible API, Data/DBGrid/DBCombo toolbox controls, 13 tests pass. **Limitation (Sept 2026):** recordset + bound controls are wired to **`Database` / SQLite** today, not to **`VGOdbc`**. Server DBs (Postgres, MySQL/MariaDB) work via **`VGOdbc` programmatic SQL** only. See [ODBC / Database — Phased Improvement Plan](#odbc--database--phased-improvement-plan-v61).

5. **✅ Package Manager** *(Completed v4.3.0)*  
   `vg pkg` CLI, `vg.json` manifests, GitHub-backed registry, GUI Package Browser panel, 11 tests pass.

6. **✅ Migration Wizard v2 (Full VBP Import)** *(Completed earlier)*  
   Full `.vbp` project import with batch form/module/class processing.

### ✅ Nice-to-Have — Performance & Platform (7/8 COMPLETE)

7. **✅ macOS Universal Binary** *(Completed v4.3.0)*  
   `scripts/build_macos_universal.sh` build script + `.github/workflows/macos-universal.yml` CI workflow.

8. **✅ JIT Tier 3 (Call Graph Compilation)** *(Completed v4.3.0)*  
   Call graph profiling, inline candidate selection, callee IR lowering, fused compilation, x86-64 emission. Complete 5-tier JIT stack: Tier 0 → 0.5 → 1 → 2 → 3. 10 tests pass.

9. **WebAssembly Export Validation** — *Not yet started*  
   Ensure VisualGasic scripts work correctly in HTML5 exports.

### 📊 v4.0 Priority Matrix (Final Status)

| # | Feature | Status | Version |
|---|---------|--------|----------|
| 1 | Live Animation | ⏭️ Skipped | — |
| 2 | Multi-Module Imports | ✅ Complete | v4.3.0 |
| 3 | Visual Form Debugger | ✅ Complete | v4.3.0 |
| 4 | Database Controls | ✅ Complete | v4.3.0 |
| 5 | Package Manager | ✅ Complete | v4.3.0 |
| 6 | Migration Wizard v2 | ✅ Complete | v4.2.0 |
| 7 | macOS Universal | ✅ Complete | v4.3.0 |
| 8 | JIT Tier 3 | ✅ Complete | v4.3.0 |
| 9 | WASM Validation | 🔲 Not started | — |

---

## 🚀 v5.0.1 Beta — shipped, rolled forward into v5.1

The v5.0.1 Beta feature set is **complete and live in 5.1.0-Beta1**. Cross-platform installer, `vg` CLI, pre-built binaries (Linux/Windows/macOS), 3D asset import + properties + animation, Make EXE, Publish to Web, Live Control Animation, Multi-Provider AI Help (OpenAI / Claude / Gemini + Ollama), and WebSocket Controls all landed. See [`CHANGELOG.md`](CHANGELOG.md) for the per-feature receipts.

Three items deliberately did **not** block v5.1 stable:

| Feature | Status | Disposition |
|---------|--------|-------------|
| Browser Dashboard | ✅ Shipped (post-v5.2.0-Beta4) | 5-phase dashboard + headless launcher + tray icon. |
| Community Testing | 🟡 Ongoing | Continues across the v5.2.x line. Not a release gate. |
| Issue triage | 🟡 Ongoing | Whatever community testing surfaces lands as patches. |

### v5.1.0 stable cut — SHIPPED

1. ✅ All 5.1.0-Beta1 features wired and parsing clean.
2. ✅ Addon-symlink drift check green.
3. ✅ First-run picker works on a brand-new project.
4. ✅ Tagged `v5.1.0-rc.2`; line rolled forward into v5.2.

---

## 💭 v5.2 Roadmap — focused

Short, finishable list. **No new aspirational items.**

| Feature | Description | Priority | Rationale |
|---------|-------------|----------|-----------|
| ~~**Browser Dashboard**~~ | ~~Browser-based project dashboard, settings panel, build monitor.~~ ✅ **Shipped** — 5-phase TCP-server HTTP dashboard + headless `vg-dashboard` launcher + tray icon mode. | ~~High~~ |
| ~~**Working Nodes — Merge `On Input` chains**~~ | ~~Multiple `On Input` nodes each generating duplicate `Sub Form_KeyDown()`.~~ ✅ **Shipped** — `working_nodes_codegen.gd` `_emit_merged_input_sub` merges all `On Input` nodes into a single `Sub Form_KeyDown` with `If key = "..." Then` guards. | ~~Medium~~ |
| ~~**Working Nodes — runtime gaps**~~ | ~~`WN_Wait` / `WN_Spawn` / `WN_Animate` stubs.~~ ✅ **Shipped** — `WN_Wait`/`WN_Spawn` now `Await GetTree().create_timer(sec).timeout`; `WN_Animate` falls back to scale-pulse tween when no AnimationPlayer is present. | ~~Medium~~ |
| ~~**Fix boolean `Or` runtime/parser regression**~~ | ~~MUST FIX~~ ✅ **Fixed** — parser now treats condition-continuation boolean operators correctly (including multiline `If ... Or ... Then` patterns), preventing erroneous `CallStatement("Or")` paths that caused runtime `Err 35`. Regression coverage added in `tests/generated/test_boolean_or_regression.vg`; parser handling references in `src/visual_gasic_parser.cpp` (`parse_if` continuation logic + guarded keyword-start statement handling). | ~~High~~ |
| **UI Forms — 2D viewport authoring (new approach)** | New lightweight form editor that works WITH Godot's 2D editor, not against it. **Toolbox as transient popup**: clicking `[+ Add Control]` opens a native floating `Window` with the Godot Control palette; click a control → window closes → ghost/outline follows mouse → single click places it on the form; double-click an already-placed control to auto-wire + create a VG event stub. **Signal architecture (two-layer)**: Layer 1 — controls connect their default Godot signals to `Form1.vg` exactly like VB6 (`Sub Button1_Click()`); Layer 2 — the form declares `Event` declarations for high-level outcomes (`Event FormSubmitted(data)`) that parent scenes connect to. Both layers visible in Godot's signal graph. **No extraction yet**: Form Designer stays in place behind the Experimental Plugins gate. Separate repo target: `xgreenrx-star/vg-plugin-ui-forms`. | High |
| **Experimental Plugins setting** | Add `vg/enable_experimental_plugins` boolean in Godot Project Settings (VisualGasic category, default: `false`). When `false`, experimental plugins (UI Forms; others added later) are hidden from the toolbar and plugin manager. When `true` they appear at the user's own risk. Check this setting in `visual_gasic_plugin.gd` alongside the existing `vg/form_designer_enabled` check (~line 669). UI Forms is the first plugin behind this gate; Form Designer extraction deferred to v6.0+. | High |
| **Installer polish** | `install.py/.sh/.ps1` improvements: (a) `--uninstall` that cleanly removes addon + `vg` CLI; (b) upgrade detection with overwrite warning; (c) Windows: auto-append `~\.local\bin` to user PATH via `setx`; (d) optional `--install-godot` that downloads + SHA-512-verifies the matching Godot binary; (e) optional `--activate-in <project>`; (f) optional desktop launcher. | Medium |
| **Android / iOS validation** | Test and fix mobile platform builds. Stretch — not a 5.2 blocker. | Low |
| **WebAssembly Export validation** | Ensure HTML5 export compatibility end-to-end. | Low |

---

## 🎯 AI Crash Positioning — Feature Priority (Jun 27 2026)

> **Context**: When the trust collapse in AI-generated code arrives, VG's pitch is: human-readable, auditable, English-like code for Godot. VG is ironically *better* for AI generation than GDScript because it is simpler and more auditable. We need a working, usable VG before that window opens. Below is the explicit advance/mothball list.

### 🗓️ Milestone Timeline — Stable Target: January 1 2027

**Why January 1:** The AI code trust collapse window runs through Q4 2026 – Q2 2027. A credible, working stable release by January 1 2027 puts VG in position to be the answer when the question becomes mainstream — and allows time to ship Python integration, C++ interop, `Let` keyword, and language parity before tagging stable.

| Milestone | Target Date | Exit Criteria |
|-----------|------------|---------------|
| **M0 — Restart** | July 1 2026 | Codebase reviewed, bug list confirmed, all known regressions documented |
| **M1 — Bug fixes** | July 31 2026 | ✅ **DONE** (Jun 29) — All 8 critical bugs fixed and regression-tested: `Or` operator (`fbb5984b`), error state corruption, phantom double-press (`2700b580` — `HashSet _active_signal_subs`), `.tscn` signal mismatch (`552fd5f4` — preserve `[connection]`), ByRef recursion (`b130dd8e`), Join float format, Dict properties (`Count/Keys/Items` w/o parens), chained calls. |
✅ **Post-M1 catch (Jul 15 2026)** — `IsNot` operator implemented across parser/bytecode compiler/both evaluator paths (negation of `Is`: class type-check, `Nothing` null check, reference inequality). A **second, distinct ByRef bug** was found and fixed during verification: expression-level function calls (`result = DoubleAndReturn(val)`) never wrote the modified value back to the caller — the evaluator's write-back path read the already-erased `variables[param.name]` instead of `_last_byref_captures` (the mechanism the `STMT_CALL` path already used correctly). This is **not** the same bug as the Jun 29 ByRef-recursion fix (`b130dd8e`) — that one was about default parameters colliding during recursive calls; this one affects **any** `ByRef` function called as part of an expression, regardless of recursion. Full regression suite: 763/763 assertions pass (was 762/763 before the fix). See `CHANGELOG.md` [Unreleased] for details.
| **M2 — Corpus / examples proof** | August 15 2026 | ✅ **DONE** (Jun 30) — 44/44 corpus examples pass across basics, control flow, strings, arrays, dictionaries, classes, file I/O, math, state machines, and Godot integration. |
| **M3 — Code Navigator upgrade** | August 31 2026 | ✅ **DONE** (Jul 1) — Object dropdown surfaces all scripts on all scene nodes; GDScript `func` definitions in Event dropdown; clicking navigates to correct line. |
| **M4 — UI Forms experimental** | September 30 2026 | ✅ **DONE** (Jul 1) — Control picker popup → ghost placement → single-click place → double-click wire → `Sub Button1_Click()` in `Form1.vg`. Save/reopen preserves everything. Gated behind `vg/enable_experimental_plugins`. |
| **M5 — Narcea AI pair** | October 15 2026 | (1) "Describe a form in English → Narcea generates working VG code" demo runs end-to-end on Claude and local Ollama. (2) **NEW: Buffer Type** — Dim mem As Buffer; BufRead/BufWrite/BufRead16/BufWrite32 opcodes for zero-overhead byte-level access; 10-100× faster than Array(As Byte) for emulation/I/O. (3) **NEW: Optimizer Hints** — @fast_loop, @accumulator, @simd_candidate directives; user-extensible optimizer; users tune hot paths without compiler pattern-matching. Expected 1.5-3× speedup on common loops. |
✅ **DeepSeek, Qwen, and other low-cost API providers on the roadmap** — provider list to be expanded in v5.4 (Phase 6c): DeepSeek (Chat API, function-calling via OpenAI-compatible schema), Qwen (DashScope / Alibaba Cloud API), and any OpenAI-compatible endpoint. Goal: give users affordable cloud alternatives to Claude/OpenAI for agent-mode coding. See `vg_ai_providers.gd` and `vg_ai_function_calling.gd` — new providers need a `ProviderInfo` entry and, if they advertise native function-calling, a `PROVIDERS_WITH_NATIVE_FC` entry. Free/cheap model tiers (DeepSeek-V2, Qwen2.5-Coder-32B-API) should be enabled by default alongside existing local Ollama path.
✅ **Codeium (Windsurf) and Amazon Q Developer agents added to roadmap (v5.4+)** — both offer free/low-cost tiers and support OpenAI-compatible API patterns. Codeium's Windsurf models (stable-code, stable-cascade) and Amazon Q Developer's LLM backend are accessible via API. These expand the "budget AI assistant" tier for users who want agent-mode coding without Claude/OpenAI pricing. Implementation reuses the existing OpenAI-compatible provider path. |
| **M6 — Causal Chain Visualization (teaser)** | October 31 2026 | Static AST walk generates a readable call-chain report for any VG form. Even a text-mode output qualifies. Visual panel is v6.1+. |
| **M7 — Python Library Integration (Tier A)** | November 15 2026 | `PyImport("numpy")` / `PyCallAsync` / `Await` works end-to-end on Linux + Windows desktop. Out-of-process worker via existing IPC/process/async stack. Native wheels (numpy, opencv) load without engine changes. Clean error on missing Python. |
| **M7+ — Performance Optimizations (Phase 1)** | December 2026+ | (1) **Tagged Stack** (research): Union-based stack with type tags (int64, float64, ptr) to eliminate Variant constructor/destructor overhead on every push/pop. Expected 2-3× speedup on all operations; requires full opcode refactor (~3-4 months). (2) **Packed Arrays** (v6.1 candidate): Fast-path opcodes (OP_ARRAY_ADD_I64_INPLACE, etc.) for common array patterns without Variant dispatch. Expected 1.5-2× speedup on particle systems, mesh manipulation. (3) **SIMD Hinting** (research for v7.0): OP_VEC_ADD, OP_VEC_MUL opcodes with AVX2/AVX-512 code generation hints for batch math (physics, 3D transforms, audio DSP). Expected 3-5× speedup on batch workloads. |
✅ **EARLY PROGRESS (Jul 11)** — `PyImport("math")` / `PyImport("json")` + `PyCall` working end-to-end via `demo_python_bridge.vg`. Synchronous call, serialisation (json.dumps/loads), error handling, buffer processing, and graceful shutdown all tested. Demo, README, and documentation in `docs/SYSTEM_INTEGRATION.md` §17 and `docs/VisualGasic_Language_Reference.md` complete. numpy Phase 0 (array, dot, sum, linalg.norm, scalars) added to demo and tested Jul 11. **Remaining**: numpy Phase 1 (binary protocol for large arrays), Phase 2 (opencv, torch, structured data), `PyCallAsync`/`Await`, Windows validation.
✅ **Phase 2/3 shipped (Jul 14)** — Real `PyCallAsync` implemented via `PyAsyncTask` (new `RefCounted` in `visual_gasic_py_facade.h/cpp`): runs the Python call on a background `std::thread`, mirrors `VGTask`'s public surface (`IsComplete`/`IsFailed`/`Result`/`ErrorMessage`) so VG's `Await` keyword duck-types on it with zero runtime changes. Also added: binary data lane for `PyProcessBuffer`, Windows `CreateProcess` launch path (was Linux/macOS-only), auto-restart on worker crash, a structured error model, project settings for the Python bridge, `PyEnvInfo`/`PyLastError`/`PyCallMany` helpers, and a fuller test matrix. **Remaining for M7 close-out**: Windows end-to-end validation of the new async path, numpy Phase 1 (typed binary protocol), numpy Phase 2 (opencv/torch/pandas).

#### numpy Support — Phased Plan (within M7 scope)

| Phase | What | Status | Work |
|-------|------|--------|------|
| **0 — JSON-serializable numpy** | `numpy.array()`, `dot()`, `sum()`, `linalg.norm()`, `float32()`, scalars, small 2D arrays | ✅ **Done** (Jul 11) | All work via existing `_make_json_safe()` in `python_worker.py` (has `tolist()`/`item()` fallbacks). Demo tested with 5 operations. |
| **1 — Type-fidelity binary protocol** | Replace JSON serialization with a typed binary protocol (msgpack or custom) that preserves int/float/string/array distinction. Eliminates the float-only limitation on `Array()` args. Also enables >100×100 array performance. | 🟡 **Not started** | ~2-3 days: (1) msgpack dep in worker + typed `call` handler; (2) `PyCallTyped()` C++ method packing VG Variant types; (3) int/float/string/bool/array/null round-trip tests; (4) PackedFloat64Array path for large arrays. |
| **2 — Ecosystem expansion** | opencv (image load/process/return pixels), torch (tensor round-trip), pandas (DataFrame via JSON). Structured dtype support. | 🟡 **Not started** | ~3-5 days: (1) per-ecosystem handler patterns; (2) structured array support; (3) error quality; (4) example demos. |
| **3 — Worker hardening** | venv detection, `PYTHONPATH` config, Windows validation, timeout recovery. | 🟡 **Not started** | ~2 days |

**Current limitation**: Two separate int/float type-loss bugs in the Python bridge (discovered + fixed/documented Jul 15, 2026):
1. ✅ **Decode-path int loss (FIXED)** — Worker sends correct Python int (e.g., `math.floor(5.7)` → `5`), but Godot's `JSON::parse_string()` collapsed every number to float. Fixed via custom `vg_json_parse_typed()` decoder in C++ that preserves int vs float semantics. Verified end-to-end via `demo/test_python_int_float.vg` — scalar int, negative int, nested dict/array, mixed types all round-trip correctly.
2. 🔴 **Encode-path literal typing (UNFIXED — v6.1 candidate)** — VG bare numeric literals (0, 5, 65) boxed into `Array(...)` as PyCall arguments arrive in Python as `float` instead of `int`. Root cause: VG's literal tokenizer defaults untyped numeric literals to `Double` rather than `Integer`. Symptom: `PyCall(builtins, "range", Array(0, 5))` fails with `TypeError: 'float' object cannot be interpreted as an integer`. See `/memories/repo/v6.0_blockers.md` section 6 for full analysis. **Phase 1 mitigation (v6.1 Polish)**: add literal type annotation syntax (e.g., `0i` for int literal); or change default to Integer for literals without decimal point (breaking change, requires testing). **Phase 2 optimization (v6.5+)**: typed binary protocol for performance, not correctness.

#### Performance Optimizations — Phased Plan (M7+ Research)

**Context**: Current benchmark suite shows VG dominates GDScript (26.9× average) but trades numeric loop performance to C++ (AllocationsFast 13.4× slower, Arithmetic 4.4× slower). Three targeted optimizations can close this gap while maintaining language clarity.

| Optimization | Approach | Expected Impact | Effort | Priority |
|---|---|---|---|---|
| **Type-Tagged Locals** | Specialize VM locals storage: variables declared `As Integer`/`As Long`/`As Double` use direct int64/double registers instead of Variant dispatch. All arithmetic ops (ADD, SUBTRACT, DIVIDE, etc.) check local type tags and use fast-path int64/double handlers. No new opcodes. | 2-5× speedup on Arithmetic, ArraySum, ArrayDict, Allocations (affect ~6 benchmarks) | Medium (2-3 weeks: VM layout redesign, hot-path handler specialization, regression test suite) | **HIGH** — most transformative single optimization |
| **On-Stack Replacement (OSR)** | Tier-2 JIT enhancement: instrumentation in tier-1 detects loops running N iterations; pauses execution, compiles a specialized trace of the loop body (with type-specific operations and optimization passes); jumps into compiled code and resumes. Classical implementation from Lua/LuaJIT/V8. | 3-10× speedup on long-running loops (big-O workloads) | High (3-6 months: tracer design, stop-the-world mechanism, compiled trace cache, correctness testing) | **MEDIUM** — long-term correctness investment, not immediate ROI |
| **String Arena** | Thread-local `String` accumulator: chained `&` ops append to buffer instead of creating intermediate `String` objects. Drain buffer on scope exit or explicit flush. No new opcodes. | 1.5-3× speedup on StringConcat and string-heavy code | Low (1-2 weeks: buffer management, escape analysis for drain points) | **LOW** — niche optimization, already at 74× vs GDScript |
| **Sub/Function Call Overhead Reduction** | **FIXED for hot paths in 5.4.0-beta1 (Aug 2026).** Trivial helpers (`Function Helper(x As Long) As Long` with body `Helper = x + 1`) **inline at call sites**; nested `For` loops with inner `s = Helper(s)` fuse to closed-form multiply-add. FunctionCall went from ~8× slower than GDScript to **~60× faster** — part of **12/12 compute** wins. CI gate: `scripts/benchmark_regression_check.sh`. Regression test: `test_function_call_inline.vg`. **Earlier work (Jul 2026):** per-instance `HashMap` call-resolution cache (~21% absolute call-time reduction) remains; general multi-statement helpers still use normal call overhead — only fusion/inlining patterns covered by tests. Non-trivial call-heavy code (emulators, AST walkers) may still benefit from inlining or MemoryBuffer/Bit* builtins. See [`BENCHMARK_PUBLISHED_RESULTS.md`](BENCHMARK_PUBLISHED_RESULTS.md). |

**Timeline**:
- **M7 (Nov 15)**: Research phase — validate approach on benchmark suite, prototype type-tagged locals
- **M7+ (Dec 2026)**: Implementation phase — Type-Tagged Locals first (highest ROI), then OSR research, String Arena as polish
- **v6.1 (Jan-Feb 2027)**: Rollout — Type-Tagged Locals stable; OSR exploratory code available; String Arena optional

**Success criteria**:
- Type-Tagged Locals: Arithmetic 215 µs → ~130 µs (4.4× closer to C++ baseline 49 µs)
- OSR: Branching 60 µs → ~30 µs (achieves parity with C++ 23 µs on hot loops)
- String Arena: StringConcat 47 µs → ~35-40 µs (still 80-100× vs GDScript)

#### ODBC / Database — Phased Improvement Plan (v6.1+)

**User signal (Sept 2026):** Former VB6 developers on r/visualbasic flagged **forms designer** and **standard ODBC** (Postgres/MySQL/MariaDB via vendor drivers, not Jet/ACE/COM ADO) as adoption blockers.

**What ships today (v5.4.x):**

| Layer | Class / API | Status | Notes |
|-------|-------------|--------|-------|
| **ODBC connectivity** | `VGOdbc` (`New VGOdbc`, `New Odbc`) | ✅ Shipped v3.0 | Any installed ODBC driver; `ConnectionString`, `Open`, `Query`, `Execute`, `QueryParams`, transactions. Linux: `unixODBC` + `odbc-postgresql` / `odbc-mariadb`. Demo: `demos/Data_and_Files/ODBC/demo_odbc.vg`. Docs: `docs/SYSTEM_INTEGRATION.md` §2. |
| **Embedded SQL** | `Database` / `VGDatabase` | ✅ Shipped | SQLite file via dynamic `libsqlite3` load. |
| **ADO-*style* cursor** | `Recordset` / `VGRecordset` | ✅ Partial | `MoveNext`, `Fields`, `AddNew`, `Update`, `EOF`/`BOF` — **SQLite backend only** (`rs.Open sql, db`). Tests: `demo/test_suites/test_db_controls.vg`. |
| **Bound controls** | Data / DBGrid / DBCombo toolbox | ✅ Partial | Prototype scenes; **SQLite recordset path** only. |
| **Legacy stub** | `OpenDatabase(path)` | ⚠️ Misleading | Reads a **JSON file**, not SQL/ODBC — do not use for server DBs. |

**Gaps vs VB6 LOB workflow:**

1. No **`Recordset` over `VGOdbc`** — server queries return `Array` of `Dictionary`; no navigable cursor on Postgres/MySQL.
2. No **DBGrid/Data binding to ODBC recordsets** — grid workflow requires SQLite today.
3. No COM **`ADODB.Connection`** — by design (no Jet/ACE); ODBC-native API only.
4. **`OpenDatabase` naming** confuses users expecting DAO/ADO file or DSN open.
5. **CI/live-driver tests** missing — ODBC demo documents API when no driver installed; no automated Postgres/MySQL regression.

**Phased plan:**

| Phase | Target | Scope | Effort | Priority |
|-------|--------|-------|--------|----------|
| **1 — ODBC hardening** | v6.1 | Live-driver docs + optional CI job (Postgres/MySQL via unixODBC); map ODBC diag → VG `Err`; deprecate/document `OpenDatabase` JSON stub; corpus example: connect + `Query` + loop rows. | ~1 week | 🔴 **HIGH** |
| **2 — Recordset over ODBC** | v6.1–v6.2 | Extend `VGRecordset` (or sibling `OdbcRecordset`) to open on `Ref<VGOdbc>`; forward-only cursor from `Query`/`Execute`; `Requery`, `Fields`, CRUD where driver supports it. | ~2–3 weeks | 🔴 **HIGH** |
| **3 — Bound controls + forms** | v6.2 | Wire Data/DBGrid/DBCombo to ODBC-backed recordset; pairs with **UI Forms** leaving experimental. Exit: bind grid to live Postgres/MySQL table in a form. | ~2–3 weeks | 🔴 **HIGH** |
| **4 — RAII & ergonomics** | v6.2+ | `Using conn = …` / `End Using` for `VGOdbc` + `Database` (see v6.1 `Using...End Using` row); connection-string helpers for common DSN-less Postgres/MySQL templates. | ~1–2 weeks | 🟡 MEDIUM |

**Success criteria (v6.2):**

- Former VB6 dev can connect to **Postgres or MySQL/MariaDB** with a standard ODBC driver, run `SELECT`, navigate rows with **Recordset** semantics, and display rows in **DBGrid** without hand-rolling loops.
- No Microsoft Jet/ACE/COM dependency required.
- Regression: SQLite recordset path unchanged; new `test_odbc_recordset.vg` (or CI service container) for server driver path.

**Out of scope:** COM ADO, Access `.mdb` native, ORM/query builder, connection pooling microservice.

---


✅ **EARLY PROGRESS (Jul 11)** — C++ FFI interop proven via `demo_ffi_cpp_lib.vg` (Vec2 C++ class with C ABI wrappers: create/destroy, get/set, length, dot product, scale, add, normalize, string representation). All 7 sections pass on Linux. `QuickCall` alias added to `visual_gasic_ffi.cpp` for docs-compatible calling. Demo, README, and documentation in `docs/SYSTEM_INTEGRATION.md` §1 and `docs/VisualGasic_Language_Reference.md` complete. **Remaining**: `Declare`/`DllImport` syntax, Windows validation, packaging docs. |
| **M9 — Release readiness** | November 28 2026 | (1) ✅ **Godot Asset Library acceptance: COMPLETE (Aug 13, 2026)** — Now live at https://store.godotengine.org/asset/visual-gasic/visual-gasic/. (2) Installer smoke-tested on clean Linux + Windows VMs — first-run works without manual steps. (3) 50+ corpus examples pass. (4) README and CHANGELOG reflect v6.0 features accurately. |
| **🎉 Stable v6.0 release** | January 1 2027 | All M1–M9 complete. Installer works first try. ✅ Asset Library submission accepted and live. Public announcement. |

**Buffer**: October is the buffer month. If M4 slips, M5 and M6 compress, not the release date.

**What stable means**: language core is reliable, bugs above are fixed, examples work, installer works. It does NOT mean every feature is complete — it means what ships is honest and solid.

---

## 🔄 Retired: VB6 Importer Plugin

**Decision**: The VB6 Importer has been retired from the core VG distribution and will be maintained as a **separate, community-driven plugin**.

**Reasoning**:
- VG's focus is Godot indie game development with AI-assisted workflows, not legacy VB6 migration
- Supporting VB6 project import is significant maintenance burden (COM, ActiveX, ADO, complex .vbp layouts)
- Better served as an optional plugin for users who need it, not core product noise
- Keeps VG's positioning clean: "auditable AI code for Godot," not "VB6 migration tool"

**What happens to it**:
- Source code archived on a dedicated GitHub repository: **`vgtools-vb6-importer`** (community-maintained)
- Full source including form parsing, .vbp project handling, and import report generation
- Available for any developer who wants to finish it or adapt it for their use case
- VG main addon cleaned of importer code in v5.3.0 stable

**If you want to continue**:
- Fork `vgtools-vb6-importer`, extend the parser/importer, add tests
- Package as a standalone Godot plugin
- Publish to Godot Asset Library under your name
- VG team happy to link to community plugins in docs

### ✅ ADVANCE — required for positioning

| Feature | Why it matters |
|---------|---------------|
| **VG Core stability** (parser/compiler/VM/JIT) | The product itself. Nothing else matters if the language is broken. |
| **Debugger** (breakpoints, watch, call stack) | Auditability: humans must be able to step through and verify AI-generated VG code. |
| **Linter + formatter** | Keeps AI-generated code clean. Core audit tool. |
| **IntelliSense / CBM completion** | Reduces friction for non-GDScript developers. |
| **Human-readable error messages** | When AI gets it wrong, humans must understand what broke. |
| **Narcea basic AI help** | Generates VG. The AI coding assistant that proves the pitch. |
| **20 clean working examples** | Proof points. Newcomers need to see VG work before trusting it. |
| **Installer polish** | First impression. If install fails, nobody sees the rest. |
| **AI Transport Compaction (VG6.1)** | Cuts AI development costs. Pays for itself immediately. |
| **UI Forms (experimental)** | Demonstrates VG for app/UI development. Differentiator from game-only tools. |
| **Code Navigator enhancement** | Extend existing `code_navigator.gd` to surface ALL scene scripts in the Object dropdown — critical for UI Forms workflow where multiple nodes each have scripts. |
| **Causal Chain Visualization (teaser in v6.0, full in v6.1)** | Static analysis of a VG form's AST produces a human-readable causal chain: every user action → every Sub it calls → every outcome it produces. The auditor reads the chain, not the code, to verify AI-generated output. Text-mode output for v6.0; visual panel for v6.1. |
| **Language reference + 5 tutorials** | When AI crashes, humans read docs again. This is the moment docs matter. Includes: **First Program Tutorial (Manual vs. AI-Assisted)** — step-by-step beginners guide showing how to build the same simple form/game twice: once by typing VG code, once using Narcea AI pair. Side-by-side comparison, screenshots, workflow explained. Entry point for new developers deciding between manual VG coding and AI-assisted development. |
| **AI-optimized language manual** (`VG_LANGUAGE_SPEC.md` or similar) | Condense the human-facing manuals (`docs/VisualGasic_Language_Reference.md`, `docs/BUILTINS.md`, corpus, etc.) into a dense, machine-parsable reference — syntax tables, builtin signatures, bytecode opcodes, common patterns, known gotchas — modeled on `.github/copilot-instructions.md`'s style (tables, no narrative). Lets Copilot/Narcea/any AI pair load VG's rules in far fewer tokens than scanning prose docs or inferring from source, and speeds up every future AI-assisted VG session. Low-risk, no code changes; ~2-4 hours to draft from existing docs. |

### 🛑 MOTHBALL — defer until post-positioning

> **STRATEGIC DECISION — Jul 4 2026 (locked):**
> VG's **standalone custom IDE shell** (the separate IDE window/layout, Form Designer, embedded code editor, project explorer) is **mothballed until after v6.0 stable ships (Jan 1 2027)**.
> The VG IDE shell remains in the codebase but only activates when `vg/enable_experimental_plugins = true` — users are not expected to use it before v6.0 stable.
>
> **This does NOT affect Godot IDE integration work**, which is the primary focus:
> Toolbox panel, Properties window, Immediate window, Narcea AI Pair, Code Navigator, autocomplete,
> dot-completion, and any future docked panels or tools that extend Godot's native editor are all
> **active work and in scope for all milestones through v6.0**.
>
> Rule: if the feature lives *inside* Godot's editor as a docked panel or tool → **build it**.
> If it requires the VG standalone IDE shell/window to be open → **defer to post-v6.0**.

| Feature | Reason |
|---------|--------|
| **VG's custom IDE / Form Designer** | **MOTHBALLED until post-v6.0 stable.** The standalone IDE *shell/window* is hidden behind `vg/enable_experimental_plugins`. Docked panels inside Godot's editor (Toolbox, Properties, Immediate, Narcea) are **NOT** mothballed. |
| **Form Designer extraction to standalone plugin/repo** | Too complex, not a positioning feature. Keep in-place with Experimental Plugins gate. Defer to post-v6.0. |
| **Full IDE refactor to plugin architecture** | Architecturally correct but months of risk. Post-VG Core MVP. |
| **Working Nodes new features** | Maintenance-only. Do not expand. |
| **AGCK new features** | Maintenance-only. Do not expand. |
| **VGMusic / VGSFX / VGAIArt plugins** | Already separate. No new work. |
| **Package manager enhancements** | Low-value for positioning. |
| **Python / C++ / Java interop** | v6.0. Important but not positioning-critical. |
| **Narcea full agent parity (Tiers 4-8)** | Continue phased. Don't block on it. |
| **Browser Dashboard new features** | Already shipped. Freeze it. |
| **VG3D / VGVR** | v7.0. Do not touch. |
| **Plugin Marketplace UI** | Post-positioning. |
| **Causal Chain Visualization — full visual panel** | Text-mode teaser ships in v6.0. Full interactive panel (graph in Godot 2D viewport) is v6.1 scope — requires stable Code Navigator and UI Forms first. |

---

### Post-v6.0 UI/IDE Strategy — Floating Panels, Dual-Monitor & VG IDE Refactor

**STRATEGIC DECISION — August 12, 2026 (User), updated August 19, 2026:**

The VG IDE is being **refactored to keep the text editor (more functional than Godot's native editor), properties, and everything else other than the 2D/3D viewport editors**. The custom 2D/3D viewport editors are being **removed entirely** since Godot's native 2D/3D editors already exist and are sufficient. This reduces scope while preserving VG's unique value-add (more functional text editor than Godot's native editor).

**Dual-monitor goal (August 19, 2026):** Godot's native 2D/3D/Script editors stay on the primary monitor; VG panels (Immediate, Output, AI Pair, Toolbox, Properties) and optionally the full VG IDE shell can live on a second monitor **at the same time** — without forcing a main-screen tab switch.

#### Shipped partial (pre-v6.0 stable — Godot IDE integration)

| Feature | Status | Notes |
|---------|--------|-------|
| **In-viewport floating panels** | ✅ Shipped (v5.3.x) | Toolbox, Properties, and **Visual Gasic Panels** (Immediate, Output, System Console, Errors, Profiler, Controls, Packages, AI Pair, Hex Editor) use `_create_floating_panel()` — draggable `PanelContainer` overlays **inside** Godot's single editor window. Same-viewport design preserves C++ Toolbox drag-and-drop to the 2D canvas. **Limitation:** panels cannot be moved to a second monitor as OS windows. |
| **Godot IDE vs VG IDE routing** | ✅ Shipped (v5.3.x) | On Godot 2D/3D/Script: bottom tabs float (📊 VG Panels / 🤖 Narcea AI). On VG IDE Code view: bottom tabs embed under the code editor. VG IDE tab + Narcea opens Code view + embedded AI Pair. |

#### v6.1–v6.2 Roadmap: True OS Windows & Multi-Monitor *(after v6.0 stable — Jan 2027)*

| Feature | Timeline | Effort | Notes |
|---------|----------|--------|-------|
| **Phase A — Panels on monitor 2** | v6.1 | ~1 week | Replace in-viewport overlays with real Godot `Window` nodes (`popup_window`, `exclusive = false`) for **VG Panels** (AI Pair + bottom tabs), **Properties**, and optionally **Project Explorer**. Persist geometry + target screen via `EditorSettings` + `DisplayServer.screen_get_usable_rect()`. Patterns already exist (`ui_forms_control_picker.gd`, `vg_snippet_browser.gd`). |
| **Phase A — Monitor hotplug adaptation** | v6.1 | (included) | Before restoring window geometry, verify screen still exists (`DisplayServer.screen_get_list()`). Clamp off-screen positions to primary monitor; provide **Reset to Primary Screen** in preferences. |
| **Phase A — Toolbox on monitor 2** | v6.1–v6.2 | ~3–7 days | **Harder:** C++ Toolbox drag-and-drop requires same viewport as 2D canvas. Options: (1) keep Toolbox in-viewport on primary monitor only, click-to-place when floated (partially shipped); (2) cross-window drag bridge via global `_vg_active_drag` meta + screen coord mapping (~L-size, fragile). |
| **Phase B — VG IDE pop-out window** | v6.2 | ~2–4 weeks | Pop `_ide_layout` into a top-level `Window` so **Visual Gasic IDE** (form designer + code editor) can run on monitor 2 while Godot 2D/3D/Script stays on monitor 1 in the same process. Requires: reparent lifecycle, `_make_visible` across windows, scene/form sync, focus routing, bottom-panel embed vs float rules. Alternative: second Godot process + MCP/file sync (more powerful, ~L-size). |
| **Phase C — Dual-monitor polish** | v6.2 | ~1 week | Per-monitor geometry restore, **Dock back** / **Pop out** commands, toolbar discoverability, dual-monitor smoke tests. |

**Deferred until after v6.0 stable:** All Phase A/B/C work above. Do not pull forward — v6.0 scope remains Godot IDE integration + language/runtime parity only.

#### v6.1 Roadmap: Narcea Online Data *(after v6.0 stable — Jan 2027)*

Narcea today can call cloud LLM APIs but has **no agent tool to read the public web**. Prompts like “search online for what Joust is” fail because `vg_ai_tools.gd` only exposes project-local actions (`read_file`, `list_dir`, `write_file`, …). The HTTP stack already exists elsewhere in the addon (`HTTPRequest` / `HTTPClient` in providers, Lospec, asset browsers) — what’s missing is a **registered read-only tool** wired into the agent loop.

| Feature | Timeline | Effort | Notes |
|---------|----------|--------|-------|
| **Phase 1 — `fetch_url` read-only tool** | v6.1 | ~1–2 days | HTTPS GET via blocking `HTTPClient` poll (same pattern as model probes in `vg_ai_providers.gd`). Strip HTML to plain text; cap response (~64 KB) and timeout (~15 s). Register in `READ_ONLY_TOOLS`, `TOOLS_PROMPT`, and `vg_ai_function_calling.gd`; results feed the multi-hop agent loop like `list_dir`. **Security:** HTTPS only; SSRF blocklist (`127.0.0.1`, loopback, RFC1918, non-HTTP schemes); Project Setting `vg/ai/allow_web_fetch` (default on, user can disable). Enables “look up X” when the model chooses a public URL (Wikipedia, game docs, API reference pages). |
| **Phase 2 — Non-blocking fetch UX** | v6.1 | ~1 day | Optional polish: queued `HTTPRequest` + “Fetching…” status so the Godot editor doesn’t freeze on slow pages. MVP can ship with sync poll first. |
| **Phase 3 — `web_search` API tool** | v6.2 | ~2–3 days | Optional: query → snippets via Brave Search / Google Custom Search (API key in ⚙️). Separate from raw `fetch_url`; needs billing, parsing, and rate limits. |
| **vs. Browser embed stack** | v7.0+ | — | Lightweight agent tool only. The v6.0 **Browser embed stack** row (interactive in-IDE browser) remains the long-term UI; it can reuse fetch plumbing later. |

**Deferred until after v6.0 stable** — Narcea’s v6.0 security model stays project-directory jail + approval for mutations; `fetch_url` is a deliberate **read-only outbound exception**, not general browsing or JS execution.

#### v7.0+ Roadmap: VG IDE Refactor

| Feature | Scope | Rationale |
|---------|-------|----------|
| **VG Text Editor as Standalone Window** | Keep the VG text editor (more functional than Godot's native editor), move to floating `Window`. Syntax highlighting, VB6 intellisense, breakpoint gutters, call-stack debug view. Syncs with Godot file system and open script state. | VG text editor's feature set justifies a separate tool. |
| **Remove VG IDE 2D/3D Viewport Editors** | **DELETE** the custom 2D and 3D canvas implementations from the IDE shell. Users use Godot's native 2D/3D editors for layout/preview. VG focus is on CODE readability, not visual editing. | Godot's native 2D/3D editors are sufficient; no need to reinvent. Removes ~40% of IDE scope. |
| **VG IDE Lifecycle** | v7.0+ (post-stable): Extract as a separate application OR as a Godot `Window` in the same plugin process (TBD). Phase B pop-out (v6.2) is the incremental step; full separate app is optional long-term. | Mothballed until post-v6.0 stable. When revisited, user will decide window vs. app approach. |

**Prerequisite for VG text editor work**: Define "more functional than Godot's native editor" concretely — what features does it have that Godot's CodeEdit lacks? Document the feature matrix and prioritize which are worth shipping in the refactored version.

---

### Visual AI audit — three tracks (ties M5/M6 + Tier-3 together)

VG's pitch is *"AI writes it, you audit it without reading every line."* Three complementary visuals cover **plan**, **actions**, and **code**:

| Track | Question it answers | Reuses | Status |
|-------|---------------------|--------|--------|
| **Agent run graph** | What did Narcea *do/plan* each hop? (`read_file`, `write_file`, blocked tools) | Working Nodes canvas (`.wnodes` JSON) | **Shipped** — auto-written to `res://.narcea/agent_runs/<ts>.wnodes` at session end; **🧩** toolbar opens it |
| **Reference offer on Send** | Should Narcea use Wikipedia / Godot docs for this clone? | `reference_catalog.json` + countdown panel | **Shipped** — auto-accept after `vg/ai/reference_offer_seconds` (default 5) |
| **`vg-wnodes-spec` / Make WN** | Can Narcea express logic as a flowchart *before* coding? | Same WN editor + codegen | **Shipped** — Narcea emits fenced spec; **Make WN** writes `.wnodes` |
| **Causal Chain** | What does the *resulting `.vg`* actually do on click? | Code Navigator AST walk; v6.1 adds `VGVectorCanvas2D` graph | **Text shipped** (M6); **visual panel v6.1** |

**Typical workflow:**
1. Multi-hop Narcea run → review **🧩 agent graph** (tool trail) or NDJSON transcript.
2. Optional: ask for **`vg-wnodes-spec`** to sketch game logic as nodes before Apply.
3. After Apply → **Show Causal Chain** on the `.vg` to verify event→Sub→Call flow.

Implementation: `vg_ai_agent_graph.gd` (hop log → WN project), `vg_ai_wnodes_spec.gd`, `vg_causal_chain.gd` + Code Navigator button. Phase 6d chat collapsible plan header remains a polish item; the graph is the visual substitute.

---

### Narcea — editor validation queue (post–Beta7, manual / live)

Headless work shipped in **v5.3.0-Beta7+** (`95f44490`): Tier B manifest gate (only `recorded/manifest.json` scenarios), `play.run_main` launch-failure recovery, approval-dialog agent continuation, launch-detection regression test. **Still requires Godot editor or live API** — schedule when time allows:

| Step | What to verify | How |
|------|----------------|-----|
| **1. Mutation → run → ingest E2E** | Edit → `play.run_main` → output in chat → Narcea auto-continues (fix or summary) without manual Send | AI Pair: Agent mode **All**, Approvals **Bypass** (first pass); prompt a `.vg` edit + run |
| **2. Tier C live scenarios** | Asteroids create/iterate, platformer scaffolds pass rubrics with real LLM | `NARCEA_LIVE=1 NARCEA_PROVIDER=… bash scripts/run_narcea_live_suite.sh` or `NARCEA_SCENARIO=asteroids_iterate` |
| **3. Approval UI loop** | After **Apply selected** in the mutation dialog, agent loop continues (not silent stop) | Approvals **Ask** → multi-edit response → approve → confirm next hop |
| **4. Record passing replay (optional)** | Expand Tier B beyond `fixture_counter` | `bash scripts/copy_narcea_transcript.sh "VG Narcea Test" <id>` → add manifest entry → `bash scripts/run_narcea_golden.sh --tier B` |

**Exit criterion for M5 demo:** one game path (asteroids *or* platformer *or* counter→game) runs end-to-end in the editor without hand-holding, with NDJSON/transcript archived for Tier B.

---

### Narcea — game art on disk (M5+ / v6.x)

**User story:** Narcea scaffolds a playable game quickly; the user then **replaces placeholder art** in a normal editor (Sprite Editor, external paint tool, VGAIArt) instead of rewriting `_Draw()` math. Art must live **on disk** (PNG or an editable structured format), not only as runtime `DrawRect` / `DrawCircle` calls.

**Today (5.4.0-beta1):**
- Default 2D scaffolds use **Node2D + `_Draw()`** procedural shapes (`vg_ai_project_synth.gd` → `pure_2d_game_prompt_extra`).
- **Beta Showcase** (`projects/vg_beta_showcase/`) demonstrates VGVectorCanvas2D, SubViewport portal embed, and attract-mode games — see `ARCHITECTURE.md`.
- Narcea **does not** emit PNG binaries (`write_file` / SafeWrite are UTF-8 text only).
- **VGAIArt**, **Sprite Editor**, **Kenney browser**, and **AGCK Build** can produce `.png`, but none are agent-callable from chat.
- Classic **`Data` / `Read` / `Restore`** exists (piano notes, pong power-up tables) — **not used for pixel art** in current Narcea output.

#### Track A — PNG pipeline (ship first)

| Step | Deliverable |
|------|-------------|
| **A1. Agent tool: `generate_sprite`** | Narcea calls VGAIArt backend (HF / A1111) or a **deterministic procedural placeholder** (AGCK tile-library style); writes `res://ai_projects/<name>/sprites/<id>.png` via binary-safe write path. |
| **A2. Scaffold policy** | When user asks for sprites / art: emit `Sprite2D` + `LoadPicture("res://…png")` or `DrawTexture` — **never** reference paths that were not written. Fallback: generate placeholder PNG before referencing. |
| **A3. Project-spec assets** | Extend `vg-project-spec` with optional `assets[]`: `{path, kind:"png", source:"base64"|"procedural"|"prompt"}`. |
| **A4. Post-scaffold UX** | Double-click sprite path in code → **Sprite Editor**; right-click → **Regenerate in VGAIArt** (prefill prompt from Narcea chat). |

**Exit criterion:** “Make a space shooter with ship and bullet sprites” → runnable game with **real PNG files on disk**, editable in Sprite Editor, no broken `ext_resource` refs.

#### Track B — Embedded sprite data + **inline** contextual editor (user proposal)

**Idea:** Pixel art lives in **labeled `Data` blocks** seeded by Narcea or the user. When the caret is **inside** a sprite section, a **small live preview/editor** appears in an existing idle panel slot (same pattern as **Command Help** in the Toolbox / `CodeHelpPanel` — not a separate Sprite Editor tab). Paint a pixel → **`Data` lines update immediately** in the open `.vg` buffer (debounced per stroke). Right-click remains optional (“Open in full Sprite Editor” for large sheets).

**Why this fits VG:** VB6-era tables in source are auditable, diff-friendly, and don’t require a separate asset pipeline for tiny 8×8–32×32 tiles. Fast jam workflow: AI scaffolds `PlayerSprite:` → user clicks into the block → paints in the side panel → runs game.

**Why inline (not modal):** Matches `_on_caret_moved()` → `_update_command_help()` — already wired on every caret move in `vg_embedded_code_editor.gd`. Zero context switch; also useful for **UI icon grids** (16×16 toolbar glyphs) if labeled `Icon_*Sprite:` blocks.

**Problem — raw `Data` has no schema today:**
- `Data 1, 2, 0, 1, …` is indistinguishable from a power-up color table or piano frequencies **unless the block is named and structured**.
- Row width, palette, transparency, and frame count are not encoded in the AST by default.
- LLMs often break comma/grid alignment on multi-line `Data`.

**VG already has the right primitive — labeled Data sections:**
- `PlayerSprite:` (label) followed by `Data …` lines works like `PowerUpDefinitions:` / `NoteData:` in existing demos.
- At init, `scan_data_sections` flattens all `Data` values and maps each label → start index (`label_to_data_index`).
- The **next label** ends the section (`get_section_end` / `DataCount("label")` / `DataToArray("label")` / `PeekData("label", offset)` — see `docs/BUILTINS.md`).
- `Restore PlayerSprite` jumps the read pointer to that block (classic BASIC).

**Suggested v1 convention (labels + header row):**
```vg
PlayerSprite:
Data 8, 8, 0, 0          ' w, h, transparentIdx, paletteId (0=NES)
Data 0,0,1,1,0,0,0,0
Data 0,1,2,2,1,0,0,0
' … next label ends this section …
NoteData:
Data "C4", 261.63, …     ' unrelated — not a sprite block
```

**Inline editor UX (v1):**
| Piece | Behavior |
|-------|----------|
| **Trigger** | `caret_changed` → if caret line ∈ labeled `*Sprite` section with valid header → show panel; else hide (or revert to Command Help). |
| **Placement** | Toolbox `CodeHelpPanel` area: tab or auto-switch **“Sprite”** vs **“Command Help”**; optional bottom-tab fallback for wide layouts. |
| **Widget** | Minimal grid + 8–16 color palette strip extracted from `vg_sprite_editor.gd` (pen, eraser, fill — no layers/animation in v1). |
| **Live write-back** | Grid mutation → rewrite header + grid `Data` lines via `set_line()` on known line range; **debounce** (~150 ms) per stroke; `_sprite_sync_guard` to avoid caret feedback loops. |
| **Limits** | Inline editor capped at **32×32** (configurable); larger blocks → read-only preview + “Open in Sprite Editor”. |
| **Undo** | One undo step per debounced stroke (merge into code editor undo stack). |
| **Runtime** | `LoadSpriteData("PlayerSprite")` wraps `PeekData` + palette → `ImageTexture`; optional `DrawSpriteData`. |

**Phasing:**
1. **Spec doc** — `docs/manual/sprite_data_format.md` (header row, palettes, label rules).
2. **Section resolver** — given `(file, caret_line)` → `{label, header_line, data_line_start..end}` (regex v0, AST v1 via existing label/`Data` nodes). ✅ **`vg_sprite_data_resolver.gd`**
3. **Inline panel** — `vg_sprite_data_panel.gd`; VG IDE **Help | Sprite** tabs; floating **VG Help** window + Godot Script editor `caret_changed`. ✅ **v1 shipped**
4. **Live sync** — grid ↔ `Data` line rewriter + undo. ✅ **debounced write-back** (undo stack integration TBD)
5. **Narcea prompt** — emit `*Sprite:` + header + grid for 8×8–16×16; PNG track (A) for larger art.
6. **Optional:** Export section → `.png`; re-import into `Data` lines.

**Do not:** silently treat arbitrary `Data` as pixel art (piano `Data "C4", 261.63` would false-positive). Require **label naming** (`*Sprite`), a validated header row, or future `SpriteData` syntax.

#### Track C — Hybrid default for Narcea scaffolds

| Game size | Default art |
|-----------|-------------|
| Jam / prototype | labeled `*Sprite` `Data` blocks or procedural `_Draw()` (zero deps) |
| User says “sprites” / “my own art” | PNG placeholders + Sprite2D (Track A) |
| AGCK platformer | AGCK Build → `.png` sheets (existing path) |

**Cross-links:** Sprite Editor (`vg_sprite_editor.gd`), VGAIArt plugin, AGCK tile library procedural gen, `LoadPicture` / `DrawTexture` builtins.

#### Track D — External data files (`.vgd`) + sidecar preview (**shipped 5.4.0-beta1**)

**Idea:** Large level maps, tile grids, and tables live **on disk** (not inline `Data` rows). `.vg` source references them with labeled `DataFile "path"` blocks. Binary `.vgd` loads into **`MemoryBuffer`** at parse time; CSV/text merges onto the classic DATA tape. Context rail shows preview + **Open in Tiled** / import actions — no custom level editor in v1.

**Why this fits VG:** Inline sprites (Track B) cap at 32×32 for audit/edit in source. Levels and 64×64+ grids need external authoring (Tiled, CSV) but the **reference in code** stays auditable like VB6 `Data` labels.

| Tier | Storage | Editor |
|------|---------|--------|
| ≤32×32 sprites | Inline `*Sprite:` `Data` | Context rail grid (shipped) |
| Large grids / levels | `.vgd` or `.csv` on disk | **Tiled**, spreadsheet → import |
| Display art | `.png` | Sprite Editor / Track A |

**Format:** `.vgd` native binary — see [`docs/manual/vg_data_format.md`](docs/manual/vg_data_format.md). CSV inlined at parse or pre-imported to `.vgd`. PNG stays on `LoadPicture` path (not `.vgd`).

**Shipped (5.4.0-beta1):**

| Phase | Deliverables |
|-------|--------------|
| **D0** | `vg_datafile_resolver.gd`, sidecar preview, outline landmarks |
| **E1** | Flat literal cache for numeric `Data` / CSV sections |
| **D1/E2** | `.vgd` sniff → `MemoryBuffer`; `DataBuffer`, labeled `PeekData` / `DataCount` |
| **D2** | CSV/Tiled JSON → `.vgd`, Tiled detect/install, grid metadata preview |

**Follow-ups (5.5+):** image `.vgd` payloads, CSV export, extended Narcea examples.

Full reference: [`docs/design/external_data_files.md`](docs/design/external_data_files.md)

**Do not:** inline-edit 256×256 maps in sidecar; overload `LoadData` (data tape); build a VG level editor before Tiled pipeline works.

---

### Causal Chain Visualization — Design Spec

**The problem it solves**: When AI generates a VG form, the auditor currently must read every line of code to verify what happens when a button is clicked. For a 200-line form this takes minutes. For a 2000-line form it is impractical. No existing tool answers the question *"does this code do what I asked, and is there anything hiding in it I didn’t ask for?"*

**The idea**: VG’s explicit event model (`Sub Button1_Click()`, `RaiseEvent FormSubmitted(data)`, `Call ValidateForm()`) means the entire causal chain from user action to outcome is statically traceable from the AST. The parser already builds the AST. A single recursive walk produces the chain — no runtime required.

**What the auditor sees (text-mode v6.0):**
```
User clicks [Submit]
  └─ Sub SubmitButton_Click()
      ├─ Call ValidateForm()
      │   ├─ If txtName.Text = "" → MsgBox "Name required" → EXIT
      │   └─ Returns True
      ├─ Call SaveData(userName, txtName.Text)
      │   └─ File.Write("save.dat", ...)
      └─ RaiseEvent FormSubmitted(txtName.Text)
          └─ [Parent scene connects here]
```

**What the auditor sees (visual panel v6.1):** The same graph rendered in Godot’s 2D viewport as a node graph. Each box is a Sub or outcome. Edges are calls and signal paths. Clicking a box navigates to that line in the code editor.

**Why VG is uniquely suited to this:**
1. `Sub Button1_Click()` is an unambiguous entry point — the parser already knows every entry point without running the code
2. BASIC has no hidden side effects, metaclasses, or decorators that change what a function does — static analysis is reliable and complete
3. The two-layer signal architecture (Layer 1: controls → form; Layer 2: form → parent) makes the causal chain traceable across scene boundaries
4. The Code Navigator already walks the AST — the chain generator reuses the same infrastructure

**What Python, GDScript, C# cannot do:** They have implicit control flow (metaclasses, decorators, dynamic dispatch, `__getattr__`). A static walk of their AST does not reliably represent what runs. VG’s "what you see is what runs" guarantee is what makes causal chain analysis trustworthy.

**The AI audit workflow this enables:**
1. AI generates a VG form
2. Developer clicks “Show Causal Chain”
3. Reads the chain in 30 seconds — confirms it matches intent
4. Spots any surprise call or side effect
5. Accepts or rejects the AI output *before* it runs

**v6.0 implementation (text-mode, low cost):**
- AST walker: `_walk_chain(sub_name, depth)` — recursive, returns an indented string
- Entry points: every `Sub <ControlName>_<EventName>()` in the file
- Calls: every `Call` statement and `RaiseEvent` in each Sub
- Output: printed to the Output panel or a dedicated “Audit” tab
- File: extend `code_navigator.gd` or add `vg_causal_chain.gd` (~100 lines)
- Trigger: “Show Causal Chain” button in the code editor toolbar or right-click menu

**v6.1 implementation (visual panel):**
- Render chain as a graph in a Godot `SubViewport` embedded in a dock panel
- Nodes: `Panel` + `Label` per Sub, colored by type (event handler, helper, signal emitter)
- Edges: `Line2D` for calls, dashed `Line2D` for signals
- Click a node → navigate to that line in the code editor (reuses `_navigate_to_offset`)
- Reuses `VGVectorCanvas2D` infrastructure already in the codebase

**Prerequisite**: Code Navigator upgrade must be complete (M3) before v6.1 visual panel.

**Differentiator statement** (for website/README when it ships): *"VG is the only Godot language where you can read what AI wrote without reading the code."*

---

### UI Forms — Design Spec (2D viewport + floating toolbox + signal architecture)

**Why this approach stops fighting Godot**: the previous Form Designer recreated Godot's windowing system from scratch. This approach uses Godot's 2D viewport as the canvas and a single transient native popup for control selection. Minimal surface contact with the windowing system.

**Interaction flow:**
1. User clicks `[+ Add Control]` toolbar button in VG
2. A native `Window` popup opens showing the Godot Control palette (Button, Label, LineEdit, Panel, etc.)
3. User clicks a control — window closes immediately
4. Mouse cursor shows a ghost/outline of the chosen control
5. Single click in 2D viewport — places the control as a child node at that position
6. Double-click an already-placed control — auto-wires it: connects its default Godot signal to a stub in `Form1.vg`, inserts `Sub Button1_Click()`, done

**Signal architecture (two-layer pattern):**

*Layer 1 — Controls → Form (VB6-familiar):*
- All event handlers live in `Form1.vg` — exactly like VB6
- When wired, VG connects `Button1.pressed` → `Form1.vg::Sub Button1_Click()`
- Controls do NOT get their own `.vg` script by default
- The form's `.tscn` stores Godot signal connections as normal Godot metadata (auditable, visible in the Godot signal graph)

*Layer 2 — Form → Parent Scene (Godot-native):*
- `Form1.vg` declares `Event` declarations for form-level outcomes
- Parent scenes connect to these to react to the form completing
- Generated pattern:
  ```vb
  ' Form1.vg
  Event FormSubmitted(data As Variant)
  Event FormCancelled()

  Sub SubmitButton_Click()
      RaiseEvent FormSubmitted(txtName.Text)
  End Sub

  Sub CancelButton_Click()
      RaiseEvent FormCancelled()
  End Sub
  ```

**Why this is the right architecture:** the form is a Godot scene node. It can be instanced, themed, tested, and inspected in Godot's normal workflow. Every connection is visible in the Godot signal graph — auditable by humans, generatable by AI. VB6 and Godot solve the same problem the same way; VG is the bridge.

---

### Code Navigator Enhancement — All-Scene Script Navigation

**Problem**: Godot's default code workflow requires the user to find a node in the Scene tree, right-click it, and select "Open Script" — cumbersome when a form has 10 controls each with scripts.

**Solution**: Extend the existing `code_navigator.gd` Object/Event dropdown bar (already part of VG's code editor) so that it surfaces **all scripts attached to any node in the open scene** alongside the VG form script. This gives VB6-style two-dropdown navigation over the entire form's code surface.

**Existing foundation** (`code_navigator.gd`):
- Already walks all scene nodes recursively via `_add_node_recursive(root)`
- Already lists nodes in the Object dropdown (left)
- Already parses VG `Sub`/`Function`/`Property` definitions for the Event dropdown (right)
- Already navigates to a line in the VG code editor when an event is selected

**Enhancement needed — Object dropdown additions:**
- When a node in the Object dropdown is selected, check `node.get_script()`
- If the script is a `.vg` file: populate Event dropdown with `Sub`/`Function`/`Property` entries as today
- If the script is a `.gd` file: populate Event dropdown with all `func` definitions (parsed via regex `^func (\w+)\(` or Godot's `get_script_method_list()`)
- If the script is any other type: show a single entry `[Open Script]` which calls `editor_interface.edit_resource(script)`
- Clicking any entry in the Event dropdown navigates directly to that procedure in that script — no Scene tree hunting

**Enhancement needed — Object dropdown scope for UI Forms:**
- Add a second section separator `── Scene Scripts ──` below the form's own nodes
- List any `.vg` or `.gd` script attached to child nodes, labelled `Button1.vg`, `Button1.gd`, etc.
- Selecting a script from this section opens it in the code editor and populates the Event dropdown with its procedures
- This replaces the need to hunt through the scene tree to find and open a child node's script

**Implementation reference**: `code_navigator.gd` already has all the infrastructure (`_add_node_recursive`, `_parse_procedures`, `_on_object_selected`, `_navigate_to_offset`). The change is additive — extend `_on_object_selected` to branch on script type.

**M1 file-by-file checklist (implementation-ready):**
- Create `addons/visual_gasic/plugins/ui_forms/plugin.cfg` (hidden unless `vg/enable_experimental_plugins` is `true`)
- Create `addons/visual_gasic/plugins/ui_forms/ui_forms_plugin.gd` (entrypoint; based on existing `plugins/form_designer/form_designer_plugin.gd`)
- Create `addons/visual_gasic/plugins/ui_forms/ui_forms_control_picker.gd` (transient `Window` popup with Control palette)
- Create `addons/visual_gasic/plugins/ui_forms/ui_forms_viewport_adapter.gd` (ghost placement, click-to-place, double-click-to-wire)
- Create `addons/visual_gasic/plugins/ui_forms/ui_forms_scene_bridge.gd` (scene save/open sync + VG stub insertion)
- Create `addons/visual_gasic/plugins/ui_forms/ui_forms_selection_overlay.gd` (selection rect + resize handles)
- Reuse/adapt: `form_editor_helper.gd` (alignment/grid logic), `new_form_dialog.gd` (form init), `code_navigator.gd` (dropdown bar — extend don't replace)
- Host integration: `visual_gasic_plugin.gd` checks `vg/enable_experimental_plugins` before showing UI Forms toolbar button
- Code Navigator enhancement: extend `code_navigator.gd` `_on_object_selected` to branch on `.get_script()` type; parse GDScript `func` definitions alongside VG `Sub`/`Function`
- M1 acceptance:
  - Place Button/Label/LineEdit via popup → double-click to wire → `Sub Button1_Click()` appears in `Form1.vg` → save/reopen preserves everything
  - Object dropdown lists all scene nodes; selecting a node with a `.gd` script populates Event dropdown with its `func` definitions; clicking a func navigates to that line

**Architectural gap — Form1.vg as the form controller**: The current UI Forms architecture places all event handlers into `Form1.vg` (Layer 1), but there is no clear ownership model for **which scene node owns `Form1.vg`**. In a real Godot workflow, a form might be:
- (a) A standalone `.tscn` root node (e.g., "Form1.tscn") with `Form1.vg` as its script — autoloaded or instanced by a manager
- (b) A child panel inside a larger HUD scene, where the `.tscn` is already scripted by a game manager `.gd` script — does `Form1.vg` replace that script? Does it merge? Is there a "VG overlay" that lives alongside GDScript?
- (c) An instanced popup/window that appears dynamically — `Form1.vg` must handle `_ready()`, `_process()`, and lifecycle without clashing with Godot's native popup behavior

The current spec assumes case (a) implicitly. Cases (b) and (c) are undefined and will cause real integration friction when users try to embed forms inside existing scenes. **Recommendation**: Before UI Forms leaves experimental status (planned for v6.0+, per the M1 checklist), define a "Form Controller Contract" that specifies:
1. The `.tscn` root node's script relationship with `Form1.vg` (replaces, wraps, or coexists)
2. How `Form1.vg` accesses sibling nodes (e.g., `GetNode("Button1")` vs. named-`@onready` equivalent)
3. Whether `Form1.vg` receives Godot lifecycle callbacks (`_ready`, `_process`, `_input`) alongside event handlers, or whether those must be implemented elsewhere
4. What happens when a form scene is instanced as a child of another scripted node — does `Form1.vg`'s `_ready()` fire before or after the parent's?
5. How `Awake`/`Initialize` event parity maps to Godot's node lifecycle (is `Form_Load` ≡ `_ready()`? Does `Form_Shown` exist as a separate signal?)
This contract should be documented before the v6.0 integration milestone that extracts Forms from experimental status.

---

## 🌌 v6.0 Roadmap — needs design work

Items below are real but require non-trivial design / scoping. **Do not** start any of them until v5.2 is cut.

**📌 IDE Focus**: All v6.0 work focuses on **Godot IDE integration only** (Toolbox, Properties, Code Navigator, Narcea AI Pair, autocomplete, dot-completion). The **VG standalone IDE shell** (separate editor window, form designer as primary surface) is **mothballed behind `vg/enable_experimental_plugins`** and will not ship as core until v7.0+ at earliest. Users should build games using Godot's native editor with VG script overlays.

| Feature | Description | Priority | Rationale |
|---------|-------------|----------|-----------|
| **~~Unboxed Typed Value Stack Redesign~~ — MEASUREMENT RESULT (NOT PURSUED, v6.1+)** | **Performance optimization (measured Sept 1, 2026 — recommend HOLD).** Prototyped behind `VG_TAGGED_STACK` flag: unbox operand stack (`std::vector<StackValue>` int64/float64/bool tags instead of 24-byte Variant) for arith/compare opcodes. Measured two-point (1M/100k iters) instruction delta via `perf stat -e instructions:u`: **`BenchArithStack` (14 unboxed ADD/SUB+cmp/iter) on 6.1% faster, but `BenchArithNoFuse` (realistic code) on 4.8% *slower*** because locals stay boxed → each load/store pays a Variant↔StackValue conversion tax. **Conclusion:** Stack-only wins only when generic stack arithmetic dominates (ceiling ~6%); net-negative on normal code. **Root cause:** The 6.2× GDScript gap (8,323 vs 1,338 instr/call) is NOT operand-stack boxing — it's boxed *locals* + per-opcode dispatch + call marshalling. Full typed-VM conversion (unboxed locals + fused local opcodes + stack) would be required to capture the theoretical 2–3× win, but that is a multi-month effort for the team. **Recommendation:** HOLD. If perf is revisited, prioritize (a) unboxed *locals* (removes the conversion tax), (b) per-opcode dispatch overhead, (c) fused `OP_*_LOCAL_I64_STACK` opcodes. Slice code flag-gated in src/ and uncommitted. **Files:** `src/visual_gasic_stack_value.h`, `src/visual_gasic_stack_value_selftest.cpp`, `src/visual_gasic_bytecode.h`, `src/visual_gasic_instance_bytecode_vm.cpp` (flag-gated edits), `docs/vm_tagged_stack_migration.md` (migration plan for future reference). Full measurement details: `/memories/repo/vg_bytecode_perf.md` (top entry) and `/memories/session/vm_perf_sprint.md`. | Low | Measurement showed the isolated stack optimization does not deliver promised returns. Multi-week effort no longer justified. Future perf work should target the real bottlenecks (typed locals, dispatch, fused local opcodes) instead. |
| **`Let` keyword — block-scoped variables** | Add `Let x As Type` as a block-scoped variable declaration (C++/JS semantics: variable is re-initialized on each block entry and destroyed on exit). `Dim` retains VB6 sub-scope hoisting behavior. This keeps VB6 compatibility while giving C++/modern programmers an intuitive opt-in for loop-local variables. `Let` is already obsolete in VB6 (it was just an optional prefix for assignment: `Let x = 5`), so repurposing it is safe and zero-breaking. AI code generators trained on JavaScript will naturally reach for `let`-style semantics inside loops — this makes their output correct without restructuring. IDE IntelliSense should suggest `Let` when `Dim` is typed inside a block. Runtime: requires a scope stack in the bytecode VM (push/pop on block enter/exit). Implementation notes: (1) parser: if keyword is `LET` followed by an identifier and `AS`, treat as block-scoped `DimStatement` with a `is_block_scoped` flag; (2) compiler: don't hoist to sub-level slots — allocate a fresh slot on each block entry via a new `OP_PUSH_SCOPE`/`OP_POP_SCOPE` pair; (3) VM: small scope stack alongside `locals[]`. See also: conversation thread Jun 26, 2026. | High |
| **AST Interpreter Performance Overhaul** | **CRITICAL BLOCKER for emulator use cases.** The C64/GBA emulator demos currently run at ~600-700 cycles/sec because cross-module Subs/Functions fall back to slow tree-walk AST interpretation instead of bytecode. Real hardware: ~985,000 cycles/sec. Fix requires either: (a) enabling bytecode compilation for Class methods (not just module-level Subs), or (b) implementing a specialized fast path in the AST interpreter for hot loops (cache node evaluation, reduce allocations). Current bottleneck confirmed: `C64_Step()` and `Vic_Tick()` are tree-walked ~985K times per second. Estimated impact: 20–50× speedup would bring emulation from "glacial 30+ minute boot" to "real-time playable" (~5–10 sec to READY prompt). **Timeline:** v6.0 stable must have a solution (either full bytecode for methods or fast-path AST). Defer implementation details until core language features (Nullable Types, Generics) are finalized. | **Critical** | Determines whether VG is viable for performance-critical applications (emulators, physics engines, audio DSP). Current state is unusable for real-time code. Blocking C64/GBA demo quality. Fix is mandatory for v6.0 credibility. |
| **Fix: AST Evaluator Type-Constructor Dispatch** | **Known bug (documented Jul 30 2026).** Bytecode compiler recognizes `Vector2i()`, `Rect2i()`, `Color()`, etc. as type constructors (emits `OP_NEW_OBJECT`), but AST tree-walk evaluator has no equivalent dispatch. Calling e.g. `Rect2i(...)` in a Sub that's fallen back to AST interpretation throws `Sub or Function not defined`. Found while debugging C64 emulator `BlitImage` calls. **Fix scope:** Add type-constructor dispatch to `VisualGasicExpressionEvaluator::evaluate_expression()` (C++ side) for all Godot built-in constructors. Mirror the bytecode path (`src/visual_gasic_compiler.cpp` line ~6953 `_godot_type_ctors[]`). **Fallback:** If this doesn't make v6.0, defer to v6.1 with a workaround (wrap type constructors in module-level helper functions). | High | Blocks cross-module code using Godot type constructors. Low frequency in typical code, but high severity (silent crashes). Pre-v6.0 fix preferred; v6.1 fallback acceptable. |
| **Full Python library support** | Include full Python library support in v6.0 so VG projects can use Python ecosystems through a supported integration path. Start with a stable bridge/service architecture and document export/runtime limits clearly. Detailed implementation plan: [`/memories/repo/v6.0_blockers.md`](/memories/repo/v6.0_blockers.md), section "v6.0 plan — Full Python library support". |
🟡 **Early demo (Jul 11):** Phase 0 (stdlib + numpy JSON-serializable ops) complete. Phase 1–3 planned. See numpy phased plan above. | High |
| **C++ library interoperability support** | Add a supported C++ interop path (native bridge/FFI + packaging docs) so VG projects can call external C++ libraries without custom engine forks. Ship desktop-first and clearly document mobile/web constraints. |
🟡 **Early demo (Jul 11):** Vec2 C++ class called via C ABI wrappers — create/destroy, get/set, length, dot, scale, add, normalize, to_string. `QuickCall` alias added. All tested and documented. **Remaining:** `Declare`/`DllImport` syntax, Windows validation, packaging docs. | High |
| **Browser embed stack** | Add a browser surface to VG for InfoView-style workflows and web-powered tools. The goal is a VG-owned browser/window experience that feels integrated into the app and supports the project's browser-driven workflows. **Precursor:** v6.1 Narcea `fetch_url` tool (read-only HTTPS, agent loop) — see [Narcea Online Data](#v61-roadmap-narcea-online-data-after-v60-stable--jan-2027). | High |
| **Java library support (v6.x, Android-first)** | Add Java interop for Android plugins and Java ecosystems, with import tooling and runtime bridge documentation. Stage this for v6.x after Python/C++ foundations are stable. | Medium |
| **AGCK advanced behaviors / user templates** | Promote hard-coded actor magic numbers (`rotation_speed`, `snap_angle_deg`, `jump_force`, `jump_velocity`, etc.) into actor-data fields, surface them in an "Advanced" card in the Actor editor, add Save/Load Template buttons that round-trip user-authored game templates as JSON in `user://agck_templates/`. Long-term: extract behaviors into external `.vg` files with typed param schemas. Plan parked in [`/memories/repo/visualgasic_todo.md`](/memories/repo/visualgasic_todo.md). | High |
| **Narcea Full Agent Parity** | Extend Narcea beyond Tier 3 (tool dispatcher + run loop) with full IDE access: debug integration (set breakpoints, step through code, inspect variables), sandboxed terminal (whitelist-only commands: build/test/git), git operations (status, diff, commit, branch), asset pipeline (view images, import assets, slice spritesheets), project management (settings, autoloads, plugins), advanced refactoring (rename across files, extract/inline subs). 8 phases, 8-10 weeks total. Security: approval UI for all mutations, project-directory jail, budget caps; **v6.1 adds gated read-only `fetch_url`** (HTTPS outbound only — see [Narcea Online Data](#v61-roadmap-narcea-online-data-after-v60-stable--jan-2027)). Target: Narcea can complete "make a demoscene demo" end-to-end (code + debug + iterate) with ≥60% success on local 7B models, ≥90% on Claude. Full plan in [`/memories/repo/visualgasic_todo.md`](/memories/repo/visualgasic_todo.md) Tier 3+ section. Phased rollout: v5.4 (debug), v5.5 (terminal+diagnostics), v6.0 (git+assets+project), v6.1+ (refactoring + online data). |
🟡 **Provider expansion detailed plan (v5.4 — all 8 providers implemented):** The codebase supports **8 providers** (ollama, openai, claude, gemini, deepseek, qwen, codeium, amazonq) across three independent layers. Here is the full architecture audit and remaining gaps:

**Layer 1 — Provider registry & streaming (`vg_ai_providers.gd`):**
- `ProviderInfo` struct: `id`, `display_name`, `is_local`, `api_host`, `api_port`, `api_path`, `use_tls`, `models[]`, `default_model`
- `get_providers()` — all 8 entries, ordered: ollama, openai, claude, gemini, deepseek, qwen, codeium, amazonq
- `build_request()` routing: `ollama` → `_build_ollama`, `openai|deepseek|qwen|codeium|amazonq` → `_build_openai`, `claude` → `_build_claude`, `gemini` → `_build_gemini`
- `parse_stream_line()` routing: same pattern — all 5 OpenAI-compatible providers reuse `_parse_openai_line`
- `get_effective_provider(provider_id)` — reads EditorSettings overrides for Amazon Q (host/port/TLS); others return `find_provider` verbatim
- API keys: `load_api_key(id)` / `save_api_key(id)` — auto-constructs path `visual_gasic/ai/<id>_key`. EditorSettings registered for all 8 in `visual_gasic_plugin.gd`
- Legacy migration `_migrate_legacy_to_editor_settings_if_needed()` — migrates old `ai_keys.cfg` (openai/claude/gemini only; deepseek/qwen/codeium/amazonq never had legacy files)
- ✅ **All routing, key management, and effective-provider logic done**

**Layer 2 — GDAI standalone HTTP client (`gdai_*.gd`):**
- `gdai_provider.gd` (`GDAIProvider`) — base class
- `gdai_openai_provider.gd` (`GDAIOpenAIProvider`) — completions, chat, embeddings, image generation via OpenAI-compatible REST
- `gdai_local_provider.gd` (`GDAILocalProvider`) — same interface, no image generation, for any local OpenAI-compatible endpoint
- `gdai.gd` (`GDAI`) — static registry with `_provider_map = {"openai": ..., "local": ...}` only; **does NOT have entries for deepseek, qwen, codeium, amazonq, or ollama** (ollama isn't needed — it uses a different streaming path). `register_provider()` exists for dynamic registration. Since all are OpenAI-compatible, they'd use the `openai` script path anyway
- ⚠️ **Minor gap:** If any consumer calls `GDAI.initialize({"provider": "deepseek"})` directly, it would fail because the provider map doesn't list deepseek. The AI Pair panel bypasses GDAI and uses Layer 1's `vg_ai_providers.gd`, so this only affects code that uses the raw `GDAI` class. Fix: add entries to `_provider_map` for deepseek, qwen, codeium, amazonq (all map to the same `gdai_openai_provider.gd` script). Est. 10 min.
- ✅ **Core GDAI HTTP layer works for all OpenAI-compatible endpoints**

**Layer 3 — Native function-calling adapter (`vg_ai_function_calling.gd`):**
- `PROVIDERS_WITH_NATIVE_FC` = `["openai", "claude", "gemini", "deepseek", "qwen", "codeium", "amazonq"]` — all 7 cloud providers
- `supports_native_fc(id)` — returns true for all 7, false for ollama
- `inject_tools_into_body()` — `openai|deepseek|qwen|codeium|amazonq` → `_to_openai_schema`, `claude` → `_to_claude_schema`, `gemini` → `_to_gemini_schema`
- `parse_stream_line_for_fc()` — `openai|deepseek|qwen|codeium|amazonq` → `_parse_openai_fc`, `claude` → `_parse_claude_fc`, `gemini` → `_parse_gemini_fc`
- `assemble_fc_calls(fragments)` → `to_fenced_text(calls)` — converts native FC to fenced vg-tool blocks, processed by existing dispatch path unchanged
- ✅ **All 7 cloud providers have full native FC support**

**Layer 4 — AI Pair panel integration (`vg_ai_help.gd` + `visual_gasic_plugin.gd`):**
- `preferred_provider` enum in EditorSettings includes all 8: `"ollama,openai,claude,gemini,deepseek,qwen,codeium,amazonq"`
- `_on_provider_selected()` switches provider, loads model dropdown from `ProviderInfo.models`, persists to EditorSettings
- Cloud providers (all except ollama) skip ping/warmup and send directly via shared streaming HTTPClient path
- Error handling: `_parse_cloud_error()` extracts human-readable message from HTTP 4xx/5xx bodies for OpenAI/Claude/Gemini error JSON shapes
- API key dialog: shows key-getting URL for each provider (platform.openai.com, console.anthropic.com, aistudio.google.com, platform.deepseek.com, dashscope.console.aliyun.com, codeium.com/profile, Bedrock Access Gateway setup)
- ✅ **Full UI integration for all 8 providers done**

**Remaining gaps (all small, <2 hours total):**

| Gap | Location | Impact | Estimate |
|-----|----------|--------|----------|
| 1. `GDAI._provider_map` incomplete | `gdai.gd` | Raw `GDAI` API calls with `provider="deepseek"/"qwen"/"codeium"/"amazonq"` fail silently. AI Pair panel unaffected. | ✅ **Done** — added 4 entries mapping to `gdai_openai_provider.gd` |
| 2. Static model lists outdate | `vg_ai_providers.gd` `get_providers()` | Hardcoded model arrays go stale as APIs evolve. No way to refresh. | ✅ **Done** — `refresh_models(provider_id)` implemented: fetches live model list from `/v1/models` (OpenAI-compatible) or equivalent endpoint (Ollama `/api/tags`, Gemini `/v1beta/models`, Claude `/v1/models`), caches in EditorSettings. Includes `_load_cached_models()`/`_save_cached_models()` and auto-applies cached overrides in `get_providers()`. 103/103 tests pass including test 10. |
| 3. Codeium default model unstable | `vg_ai_providers.gd` line 120 | `default_model = "windsurf-claude-3.5-sonnet"` — Codeium/Windsurf rebrands models frequently. This ID may be stale. | **15 min** — verify current Codeium API model IDs at codeium.com/profile |
| 4. Amazon Q Bedrock model IDs stale | `vg_ai_providers.gd` line 137 | `default_model = "anthropic.claude-3-5-sonnet-20241022-v2:0"` — AWS Bedrock model IDs change with region and availability. | **15 min** — verify current Bedrock model IDs for the default region |
| 5. No unit tests for Amazon Q host/port override | `tests/test_narcea_agent_loop.gd` test 9 | The override logic in `get_effective_provider()` exists but isn't covered by a test that actually sets EditorSettings values | ✅ **Done** — added null-safety + idempotency test (headless can't set EditorSettings, so the test verifies the no-override path is stable across repeated calls) |
| 6. No smoke test automation for cloud providers | `tests/test_narcea_agent_loop.gd` | Tests run headless and only verify routing/parsing, not actual API round-trips. Users discover auth errors at runtime. | **Deferred** — end-to-end tests require real API keys and network, so CI can't run them. Document in TESTING.md instead (est. 30 min) |

**Key architectural decisions:**
- **OpenAI-compatible providers (deepseek, qwen, codeium, amazonq) share 100% of the code path** with `openai` in all three layers — no separate request body builder, no separate stream parser, no separate FC parser. A new OpenAI-compatible provider can be added in ~20 minutes (ProviderInfo entry + EditorSetting keys + enum entry + API key dialog URL).
- **Claude and Gemini each have their own path** because their JSON schemas, auth headers, and SSE line formats differ fundamentally.
- **Ollama is the only local provider** — uses `_build_ollama` and `_parse_ollama_line` (raw JSON lines, not SSE). No API key needed.
- **The HG icon shows "AI Pair" not provider-specific branding** — the provider dropdown in the toolbar is the primary affordance. | High |
| **Godot Asset Library publish** | Package and submit VisualGasic to the official Asset Library. | High |
| **Plugin Marketplace** | In-IDE package browsing and one-click install. Registry query (`query_registry()`) now implemented; publish HTTP upload also wired. Remaining: full browse/search UI in the Package Browser panel. | Medium |
| **VGMusic startup errors (bosca/ visibility)** | When VGMusic is disabled, Godot 4.6 still compiles all `@tool` scripts in the `bosca/` subdirectory at startup before any `EditorPlugin` code runs. Because `Controller` is only registered as an autoload when the plugin is enabled, ~200 "Identifier not found: Controller" errors fire on every project open. Root cause confirmed: Godot does not respect `.gdignore` for compilation purposes; only dotdirs (`.dirname`) are fully skipped. The fix requires physically renaming `bosca/` → `.bosca.vgd` before Godot starts (e.g. from `vg-ide` launcher), but the welcome_shell path adds complexity. Approach explored and partially implemented — revert to `8acf7255` as stable baseline; implement as a dedicated sub-milestone before v6.0 stable. | High |
| **Godot 4.5→4.6 API compatibility migration** | Multiple GDScript and C++ files use Godot 4.5 APIs deprecated in 4.6: `emit_signal()` (90 instances: 53 GDScript + 37 C++), `is_connected()` signature changes (71 instances), `gui_get_focus_owner()` (4 instances, still works but warnings). **Scope:** `addons/visual_gasic/`, `src/`, AGCK plugins. **Fix:** Migrate `emit_signal()` → signal emission syntax, update `is_connected()` signatures to 4.6 API. **Estimate:** 3–4 hours (search-and-replace for signal emission, validation of new method signatures). **Deferred to:** August 2026 (post-M5) when credit budget resets. **Audit generated:** Jul 6, 2026. | Medium |
| **Tweak Overlay — auto `get_tweak_targets()` for VG scripts** | The Tweak Overlay currently shows only built-in Godot node properties (position, rotation, scale, etc.) for any node running a VG script. The fix: at VG script compile time, inspect the AST for all `Dim`-declared variables and auto-generate a `get_tweak_targets()` implementation on the VGASIC node (either injected GDScript or exposed via the C++ runtime). This would make every VG node automatically appear in the Tweak Overlay with all its script variables — zero user opt-in required. The existing `get_tweak_targets()` duck-typed protocol already supports this; it's a matter of wiring the VG compiler output to produce the schema. | Medium |
| **Visual Debugger v2** | Graphical call-flow visualization, flame graphs. | Medium |
| **Native Image Clipboard** | C++ GDExtension replacing the current `OS.execute` bridge with proper X11 / Wayland / Win32 / macOS APIs. Works fine today; this is a cleanup, not a feature. | Low |
| **Code Profiler** | Line-level perf in IDE. Pure stretch goal. | Low |
| **VG3D Preview** | Limited 3D game kit demo — voxel-based level editor, basic FPS/TPS camera, CSG primitives. Proof-of-concept only. Real VG3D lives in v7.0. | Low |

---

## 🗓️ Milestone Schedule — v5.1+

| Milestone | Focus | Due | Status |
|-----------|-------|-----|--------|
| **M1** | 8 critical bugs (Or operator `fbb5984b`, error state corruption, phantom double-press `2700b580`, .tscn signal mismatch `552fd5f4`, ByRef recursion `b130dd8e`, Join float format, Dict properties, chained calls) | Jul 31 | ✅ **DONE** (Jun 29) |
| **M2** | 44 corpus examples pass (all domains: basics, control flow, strings, arrays, dicts, classes, I/O, math, state machines, Godot) | Aug 15 | ✅ **DONE** (Jun 30) |
| **M3** | Code Navigator upgrade (#7): multi-file symbol search, definition/reference indexing, call hierarchy | Aug 31 | ✅ **DONE** (Jul 1) |
| **M4** | UI Forms experimental (#8–#12): VB6 visual form designer, control picker popup, ghost placement, signal wiring, two-layer events | Sep 30 | ✅ **DONE** (Jul 1) |
| **M5** | Narcea AI pair (#13): pair-programming mode, provider routing, system prompt templates. **NEW:** Buffer Type (zero-overhead byte access) + Optimizer Hints (@fast_loop, @accumulator directives). | Oct 15 | 🔄 **NEXT** — ✅ 8 providers + architecture (Jul 13); 🚀 **Performance foundation laid (Aug 1):** Parts D/E/F bytecode VM optimizations (+47% C64 throughput, general benefit to all VG code). Remaining: Buffer Type (1-2 weeks), Optimizer Hints (1-2 weeks). |
| **M6** | Causal Chain text-mode (#14): new AST evaluator path, narrative code generation, explain-before-compute | Oct 31 | — |
| **M7** | Python Library Integration: `PyImport` / `PyCallAsync` / `Await` via out-of-process worker. numpy, opencv, torch usable from VG scripts. | Nov 15 | 🟡 **Phase 2/3 done** (Jul 14): real `PyCallAsync`/`Await` via `PyAsyncTask` background thread, Windows launch path, auto-restart, structured errors. numpy Phases 1–2 pending |
| **M8** | Language parity (Try/Catch/Lambda/`?.` corpus tests), `Let` block-scoped vars, C++ library interop via `Declare`/`DllImport`, optional named arguments (`:=`). **Post-v6.0 (v6.1):** `Interface...End Interface`, `Using...End Using`, Programmer's Reference runtime harness — see [v6.1 Programmer's Reference gaps](#programmers-reference--remaining-language-gaps-v61). | Nov 22 | 🟡 **Early demo done** (Jul 11): Vec2 C++ class via C ABI, `QuickCall` alias |
| **M9** | Release readiness: Asset Library submission, installer smoke test (Linux + Windows), 50+ corpus, docs current | Nov 28 | — |
| **v6.0** | Stable release | Jan 1 2027 | — |
| **Bugfix** | C64 Emulator: native `FOR`/assignment statements raised `?SYNTAX ERROR` on run — **FIXED Sep 2026**. Root cause was NOT a 6502 CPU-core or ROM emulation gap (CPU/ROM traced instruction-by-instruction and confirmed correct/unmodified); it was VG's own `c64_main.vg` BASIC tokenizer omitting the 8 single-character operator tokens (`+ - * / ^ > = <` → `$AA`-`$B3`) that real C64 BASIC V2 tokenizes alongside its 68 keyword tokens (confirmed via c64-wiki.com). Any statement with `=` (virtually all `FOR`/assignment statements) got a literal ASCII byte instead of the ROM-expected token, so the real ROM correctly rejected it. Fixed by adding `OperatorToken()` tokenization to `TokenizeLine()` in `c64_main.vg`, respecting string-literal/REM boundaries. Verified: `FOR X=1 TO 5 / PRINT X / NEXT X` now prints 1-5; 855/855 regression suite unaffected. Full findings: `/memories/repo/c64_native_for_loop_bug.md`. | Sep 2026 | ✅ **DONE** (Sep 2026) |

---

## 🚀 v6.1 Roadmap — Performance + Polish

**After v6.0 stable, focus shifts to performance and developer ergonomics while maintaining language stability.**

| Feature | Description | Priority | Timeline |
|---------|-------------|----------|----------|
| **Packed Arrays (Fast-Path Opcodes)** | Fast-path opcodes for common array patterns: `OP_ARRAY_ADD_I64_INPLACE [slot] [index_slot]`, `OP_ARRAY_MUL_I64_INPLACE`, etc. Direct memory access without Variant dispatch for numeric array operations. Expected 1.5-2× speedup on particle systems, mesh manipulation, audio DSP. | High | 2-3 weeks |
| **String Arena** | Thread-local string accumulator for chained `&` operations. Expected 1.5-2× speedup on StringConcat-heavy code. | Medium | 1-2 weeks |
| **Literal Type Annotations** | Optional `0i` for int literal, `0.0d` for double literal syntax to fix Python bridge encode-path type loss. Allows `PyCall(builtins, "range", Array(0i, 5i))` to work correctly. | Medium | 1 week |
| **ODBC / Database parity (Phase 1–2)** | Harden `VGOdbc`; **`Recordset` over ODBC** (Postgres/MySQL/MariaDB via standard drivers). User-driven priority from ex-VB6 feedback. Full plan: [ODBC phased plan](#odbc--database--phased-improvement-plan-v61). | **High** | 3–4 weeks |
| **ODBC bound controls (Phase 3)** | DBGrid/Data over ODBC recordset + UI Forms. Depends on Phase 2 + UI Forms stable. | **High** | 2–3 weeks |

### Programmer's Reference — remaining language gaps (v6.1)

Tracked by `scripts/audit_command_implementation.py` against `addons/visual_gasic/vg_command_help.gd`. **`Implements InterfaceName` already works**; these are the two documented keywords still missing full support:

| Feature | Description | Priority | Timeline |
|---------|-------------|----------|----------|
| **`Interface...End Interface`** | Parse and compile interface declaration blocks (`Interface IFoo` / `Sub`/`Function` signatures / `End Interface`). Today only `Class ... Implements IFoo` is wired; declaring a new interface type from VG source fails. Needs parser + AST + (minimal) type-check pass so AI/docs examples compile. | Medium | 1–2 weeks |
| **`Using...End Using`** | RAII-style resource scope: `Using conn = OpenDatabase(...)` … `End Using` auto-disposes/closes on exit (normal, `Return`, and error paths). Needs parser, scope stack in compiler/VM, and disposal hook per resource type (start with `File`/`Database` patterns from docs). | Medium | 1–2 weeks |
| **`Whenever` block form** | ✅ **Docs aligned (Aug 2026):** reference now documents `Whenever Section … callbackProc`; inline `End Whenever` blocks remain a future parser feature if demand warrants. | Done | — |
| **Programmer's Reference runtime harness** | ✅ **Shipped (Aug 2026):** `tests/test_command_reference_harness.gd` + `scripts/run_command_reference_harness.sh` — parse all `_add()` examples; critical runtime checks for `End`, `DoEvents`, `Throw`, `LoadForm`, `ChangeScene`. CI: run before releases. | Done | — |

*Deferred past v6.0 stable (Jan 2027): not release blockers — games/forms ship without them; `Implements` covers the common interface-consumption case.*

---

## 🔬 v6.1+ Research — Performance (Post-Stable)

| Feature | Description | Timeline | Rationale |
|---------|-------------|----------|-----------|
| **~~Tagged Stack~~ — Measured Sept 2026: NOT PURSUED** | Prototyped operand stack unboxing (`std::vector<StackValue>` int64/float64/bool). Measured real instruction delta on arith-heavy and realistic-mixed workloads via two-point `perf stat -e instructions:u` isolation: unboxed stack wins ~6% on pure arithmetic but **loses ~5% on realistic code** (locals boxed → conversion tax per load/store). Root cause: 6.2× GDScript gap is not stack boxing (only ~6% upside), but boxed locals + dispatch + call marshalling. Multi-week effort not justified for ceiling of ~6%. **Recommendation:** HOLD. If perf revisited later, prioritize typed unboxed *locals* (removes tax + speeds every GET/SET), per-opcode dispatch, and fused OP_*_LOCAL_I64_STACK opcodes instead. Slice code flag-gated and uncommitted (in src/ + docs/). Measurement: `/memories/repo/vg_bytecode_perf.md` top entry. | Not Planned | Measurement proved the isolated win too small to justify multi-week migration. Larger architectural wins available. Team should focus on v6.0 stable release. |
| **SIMD Hinting** | Vector opcodes (OP_VEC_ADD, OP_VEC_MUL, OP_VEC_DOT) with JIT code generation hints for AVX2/AVX-512. Expected 3-5× speedup on batch math (physics, 3D transforms, audio DSP, image processing). Pairs well with v7.0 3D kit. | v7.0 research | Niche use case; valuable for game engines and scientific computing; research phase only. |
| **On-Stack Replacement (OSR)** | Tier-2 JIT enhancement: detect hot loops running N iterations, compile specialized trace, jump into compiled code. Expected 3-10× on long-running loops. Classic implementation (Lua/LuaJIT). | v7.0 research | Complements tier-1 JIT; requires stop-the-world mechanism; research before committing. |
| **VG → C++ transpiler ("Build & Run" IDE option)** | Ahead-of-time compile selected VG modules to C++ (reusing the existing bytecode compiler's AST + the JIT Tier2 IR-lowering stage as a front end, with a new textual-C++ backend instead of x86 codegen) as an alternative to today's "Run" (bytecode VM). IDE would offer per-module opt-in so incompatible/dynamic modules stay interpreted. Requires bundling or detecting a C++ toolchain (see `/memories/repo/vg_bytecode_perf.md` for the full feasibility writeup, incl. why `Asic`'s line-based VB6→Arduino-C++ transpiler is a conceptual reference only, not reusable code). Real native-speed win for numeric/call-heavy VG code; distinct from Option 1B (a hand-written native C64 core). | v7.0 research | Large (multi-month) compiler-team project; needs its own supervised design pass (dynamic-feature fallback, error mapping, build/link pipeline) before scheduling. |
| **Native Emulator Cores (Option 1B: `VGCpuCore` interface + C64/6510 CPU & VIC-II Graphics)** | **STATUS: ✅ CPU CORE SHIPPED (Aug 2 2026) — `VGCpu6502` native 8-bit core registered & validated.** Rather than hand-write a 6510 dispatcher, we vendored the public-domain (CC0) **fake6502 v1.3** core (validated upstream against a real KERNAL + a 6502 exerciser), refactored it from file-scope globals into a **reentrant `Fake6502` context struct** (`src/cpu_cores/fake6502_ctx.h`) so many CPU instances coexist, and wrapped it as `VGCpu6502 : RefCounted` (`src/cpu_cores/visual_gasic_cpu_6502.{h,cpp}`, registered via `SConstruct` glob + `register_types.cpp`). VG-facing API: `Reset/Step/RunCycles/TriggerIRQ/TriggerNMI`, register get/set (PC/A/X/Y/SP/Status as methods **and** inspector properties for the debugger/Immediate window/Toolbox), flat 64 KB RAM (`PeekRAM/PokeRAM/LoadBytes/GetMemory/GetMemoryRange/SetResetVector`), and an optional memory-mapped-**I/O hook window** (`SetIOHook lo,hi,readCallable,writeCallable`) so emulators can wire VIC/SID/CIA-style device registers while ordinary RAM stays native-fast. Validated end-to-end from VG (`test_proj/test_suite/test_cpu_6502.vg`: reset vector, backward-branch loop, BCD `ADC`, JSR/RTS, and two-instance reentrancy — 5/5) with the full suite green (817/817). **Reusable recipe for future systems:** find a permissively-licensed native core → refactor to a per-instance context struct (reentrancy) → wrap as `VGCpuXXX : RefCounted` with PascalCase VB-style bindings → register in the GDExtension. **Still future (not yet done):** native VIC-II/display core, and the actual C64 *Turbo Mode* swap-in — the pure-VG `demos/C64_Emulator/c64_cpu.vg` stays the default so the "C64 emulator written in 100% VG" claim holds; the native core is an **opt-in** engine primitive. Next candidate `VGCpuARM7TDMI` (GBA) follows the same recipe. *(Historical design notes below retained for reference.)* Hand-written native C++ implementations of performance-critical emulated hardware, behind a small shared **`VGCpuCore` interface** (`Reset()`/`Step()`/register peek-poke for the debugger/Immediate window/Toolbox + a memory-bus adapter bridging to `VGMemoryBuffer`/global-buffer opcodes) so each concrete chip core plugs into VG's GDExtension registration and tooling the same way. The interface is shared; the actual opcode-decode/execute loop is **NOT** — each ISA (6502, ARM7TDMI, etc.) is architecturally too different (addressing modes, register models, flag semantics, encoding) for one "configurable" engine to cover well, and forcing that would reintroduce the indirection/config-lookup overhead this effort exists to eliminate. **v6.0 scope: only `VGCpu6502` (8-bit, C64/6510) ships** — C++ class registered as GDExtension, replacing hot inner-loop VB bytecode dispatch with native x86-64 code. Pattern: existing C64 emulator boots to KERNAL successfully in bytecode (~7.5k cyc/sec); native core would achieve ~985k cyc/sec (real C64 speed) — **~130× speedup**. Reuses VGVectorCanvas2D integration pattern (`src/visual_gasic_vector_canvas.cpp` + GDExtension registry in `SConstruct`). **Scope:** Week 1 = 6510 opcode dispatcher + addressing modes (against the `VGCpuCore` interface); Week 2 = memory banking; Week 3 = VIC integration + display pipeline; Week 4 = test/polish. Supervised build recommended. Estimated 2–4 weeks. Cost: O(50–100 hours Opus 4.8 max mode), zero new dependencies. **Post-v6.0 candidate (not scheduled):** `VGCpuARM7TDMI` (32-bit, GBA) as the second core once the interface is proven — GBA already has a working (if slow) VG-script ARM/Thumb core to port from. A 16-bit tier has no concrete consumer in this repo today (no SNES/Genesis project) and is intentionally NOT planned — avoid speculative engineering until a real target exists. **Fallback**: deferring this defers real-time emulation quality; VG remains viable for performance-insensitive games and tools. Tracks both current C64/GBA demos and future emulator use cases. | v6.1+ (on-demand) | **Why it matters:** Removes the performance ceiling for emulator-class use cases. Current bytecode interpretation is unusable for cycle-accurate simulation. Native cores enable VG as a credible retro-gaming/emulation platform. Complements AST interpreter performance work (M5/v6.0); orthogonal to transpiler (which targets general numeric code, not single hot-loop replacements). Users get to choose: "rewrite this Sub in C++" (native core) vs. "compile this module to C++" (transpiler). Both are real wins, different scales. |

---

## �🚀 v7.0 Long-term — explicitly out of scope for 5.x / 6.x

| Feature | Description | Priority | Rationale |
|---------|-------------|----------|-----------|
| **Operator Overloading** | Enable `Shared Operator +(a As Vector2D, b As Vector2D) As Vector2D` syntax to define mathematical operations on custom types. No VB6 collision; matches VB.NET convention. Example: `result = pos + vel` instead of `Vector2D.Add(pos, vel)`. | Medium | Dramatically improves readability for math-heavy code (emulators, physics engines, 3D graphics); keeps VG competitive with modern languages; cleaner than functional-style helper methods. |
| **Extension Methods** | Allow adding methods to existing types: `Public Sub String.IsNumeric() As Boolean ... End Sub` using `Me` for the receiver. No new block-level keywords needed. Enables fluent, chainable APIs. Example: `If txt.IsEmpty() Then ...` flows naturally. | Medium | Eliminates boilerplate wrapper classes; enables readable, fluent chaining; common modern pattern (C#, Kotlin, Swift); high user-request feature. |
| **Tuples with Named Fields** | Support tuple return types and destructuring: `Function GetCoords() As (X As Integer, Y As Integer) : Return (10, 20) : End Function`. Destructure: `Dim x, y = GetCoords()`. **Requirement**: Named fields always (no anonymous tuples like `(Integer, Integer)`) — keeps every tuple self-documenting. | Medium | Cleaner multi-return values than ByRef parameters; reduces struct boilerplate; `(X, Y)` pattern is instantly readable; modern QoL feature. |
| **Module Blocks** | Add `Module...End Module` top-level construct for organizing utility functions (VB6 equivalent of "static class"). All members implicitly shared/non-instantiable. Example: `Module MathUtils : ... Public Function Clamp(...) : ... End Module`. Also serves as container for Extension Methods (see above). | Medium | VB6-native pattern; cleaner code organization than bare module-level Subs; reduces namespace pollution; foundation for extension methods; unambiguous (no keyword collision). |
| **Nullable Reference Types (opt-in)** | Two-phase rollout: Phase 1 (safe, v7.0): Syntax + narrowing checks — `Dim x As String?` means "can be Nothing"; compiler narrows type after `If x IsNot Nothing Then`. Phase 2 (risky, v7.1+): Strict mode option `Option Strict Nullable` that prevents assigning `String?` to `String` without null-check. Phase 1 only for v7.0 to avoid breaking existing code. | High | Catches Nothing-reference crashes at compile time; modern best practice (C#, TypeScript, Kotlin); reduces runtime errors; VB.NET-compatible syntax. |
| **TypeAlias Declarations** | Support `TypeAlias Point = Vector2i` and `TypeAlias RawAddr = Integer` for semantic type naming without struct boilerplate. Single-line, no `End`. Example: `Dim spawn As Point = Point(10, 20)`. Uses `TypeAlias` keyword (not `Type`) to avoid collision with existing `Type...End Type` struct blocks. | Low | Improves code semantics and readability; zero implementation risk; useful for domain-specific naming (physics, memory addresses, game coordinates); lightweight feature. |
| **Partial Classes** | Allow splitting a class definition across multiple files: `Partial Class Form1` in `form1_ui.vg` and `Partial Class Form1` in `form1_logic.vg`. Compiler merges partial definitions before instantiation. Unambiguous syntax (no VB6 collision). | Medium | Reduces merge conflicts in large AI-generated forms; improves file organization for UI+logic separation; matches C#/VB.NET patterns; useful for substantial generated classes. |
| **Generic Types** | Support parameterized types: `Dim items As List(Of String)`, `Dim map As Dictionary(Of String, Integer)`. Type-safe collections without code generation. Pairs with Tuples (v7.0) to enable library authors to write reusable, type-checked code. VG syntax mirrors VB.NET. | Medium | Enables ecosystem growth — libraries can ship generic containers and algorithms; eliminates untyped-collection friction; modern language feature; maintains type safety for cross-module code sharing. |
| **Async/Await Consolidation** | Formalize structured concurrency: extend existing `PyCallAsync`/`Await` flow to general async patterns. Add `Async Function`/`Async Sub` declarations, `Await expression`, `Task(Of T)` type, cancellation tokens, timeout support. Pairs with Python Integration (M7) for truly asynchronous AI workflows. | Medium | Enables readable concurrent code without callback pyramids; pairs with Narcea (AI pair) for real-time multitasking; modern best practice (C#, Python, JavaScript). |
| **Comprehensive Stack Traces + Actionable Error Messages** | Improve error reporting: include full call stack (Sub name + line number), module path, variable state at crash point, and AI-friendly suggestions ("Did you mean `IsNot`?", "Variable undefined; did you forget `Dim`?", "Type mismatch: expected `String`, got `Integer`"). IDE integration: errors link directly to problem lines. Color-coded severity (error/warning/info). | High | Debugging is 10× faster with full context; users spot mistakes instantly; AI pair learns from patterns in errors; reduces support burden; essential for production code quality. |
| **Standard Library: Regex + JSON Native Support** | Expose native Regex + JSON as first-class VG builtins: `Dim pattern As Regex = Regex("^[0-9]+$")`, `If pattern.IsMatch(str) Then ...`. JSON: `Dim obj As JSONObject = JSON.Parse(str)`, `obj.Set("key", value)`. Wrappers around Godot's RegEx/JSON classes. Eliminates user FFI boilerplate for the two most common utility tasks. | High | Regex/JSON are 80% of utility function needs; users shouldn't need FFI for standard tasks; pairs with Python Integration (file I/O, data munging); improves developer experience dramatically. |
| **VG3D — 3D Game Kit** | Full 3D game creation kit plugin. Voxel/grid-based level editor, built-in voxel model editor (MagicaVoxel-style), pre-built camera modes (FPS / TPS / top-down), CSG/primitive environments, actor system ported from AGCK, procedural 3D actor models, animation, build pipeline emitting Godot 3D scenes. | High | Expands VG beyond 2D; complements existing canvas workflows; attracts 3D game developers. |
| **VGVR — VR Game Kit** | VR mode add-on for VG3D. OpenXR integration, hand/controller input mapping, VR camera rig, teleport / smooth locomotion presets. Requires VG3D as foundation. | Medium | Emerging VR market; works with existing VG3D actor/animation/input systems. |
| **Python Integration (v6.0 continuation)** | Consolidate `PyImport`, `PyCallAsync`, async/await flow. Expand ecosystem: numpy, opencv, torch, pandas, scikit-learn. Error handling, type coercion, memory management. FFI documentation and best practices. Out-of-process worker stability hardening. | High | Unlocks AI/ML/data science workflows; enables procedural generation (numpy), image processing (opencv), physics sim (torch). |
| **C++ Interop (v6.0 continuation)** | Two-way binding: VG classes callable from C++, C++ classes callable from VG. Callback injection (VG lambdas → C++ std::function). Native bridge packaging, multiplatform support (desktop + mobile). Documentation and example projects. | High | Custom Godot node authoring in VG; hooking into physics/rendering pipelines; performance-critical paths can stay native. |
| **Delegates / Function Pointers** | First-class callable values: `Delegate` type system for storing and invoking function references. VG syntax: `Dim fn As Delegate = AddressOf MyFunc`, `Call fn(args)`, `Dim handlers() As Delegate` for event callback arrays. Compiler support for function-pointer dispatch tables, eliminating current workarounds (goto-dispatch in emulators). Easy-to-read syntax with explicit `Delegate` keyword and `AddressOf` operator (VB6-compatible). | Medium | Enables cleaner event systems, functional programming patterns, callback-heavy code (UI handlers, state machines); reduces goto-based dispatch boilerplate in performance-critical code like emulators. Paradigm expansion without breaking VB6 semantics. |
| **Case Fallthrough (multi-label Case blocks)** | Allow multiple `Case` labels before one code block: `Case 1, 2, 3: ... statement ... : Case Else:`. Parser enhancement only; compiles to same opcode sequence (jump table or compare chain). Improves readability for shared handler logic (e.g., C64 emulator illegal NOP opcodes that share one 2-cycle implementation). Not idiomatic BASIC, but clean when needed. | Low | QoL improvement for emulators and tight dispatch tables; optional language polish; can be deferred if higher priorities consume budget. |
| **Vextrex OS / narcean.com Website Launch** | **Genuinely great viral concept, deferred to post-v6.0 stable.** Complete narcean.com with fully interactive Vextrex OS — a GEOS-inspired vector desktop environment built entirely in VG, playable in browser. **Desktop Shell**: Icon grid, taskbar, draggable vector windows with minimize/close, app launcher. **Built-in Apps**: VexWrite (text editor), VexPaint (vector drawing tool with Bezier curves), Terminal (BASIC-style prompt), Vector Storm (embedded playable), DEMOscen Gallery (showcase runner), Downloads Manager (triggers real VG installer downloads), About VG (interactive tutorial). **Visual Aesthetic**: Monochrome phosphor green (CRT shader with scan lines, bloom/glow), pure vector rendering via VGVectorCanvas2D, fake 1987 boot sequence ("Vextrex OS v1.2 - Discovered Archive"). **Website Integration**: narcean.com gets "⚡ The Visual Gasic Initiative" prominent link → launches fullscreen Vextrex OS web player (Escape or "Shut Down" to exit). **Repo Strategy**: Separate `narcean/vextrex-os` repo for clean deployment, mirrored from VG development. **Narrative**: Present as "lost 1980s vector workstation" with retro manual PDF, easter eggs, hidden demos. **Estimate**: ~7-8 weeks (3wk core OS, 2wk apps, 1wk demo integration, website, 1wk polish). **Impact**: Demonstrates VG's web export, UI toolkit, vector rendering, and game engine capabilities in one self-documenting interactive experience. Shareable, viral-ready, establishes VG as serious platform. | Medium | Marketing differentiation; complements v6.0 stable release messaging; does not block core feature ship. |
| **Java/Android Integration** | Java interop for Android plugins and ecosystems. Import tooling, runtime bridge, Android-first staging. | Medium | Mobile expansion; Android ecosystem access; pairs with VG Mobile Kit work. |
| **Causal Chain Debugging (text-mode narrative)** | Structured debugging mode: trace execution flow as readable "causal chain" narrative—what happened, why, in what order. Pairs with Narcea AI pair (M5). AI-assisted test case generation, performance bottleneck identification. | Medium | Enables AI-assisted debugging; improves code comprehension; pairs with GBA/PS1 emulator and complex systems work. |
| **Asset Streaming & Dynamic Loading** | Lazy-load resources (ROMs, sprite sheets, audio, voxel models). Per-asset memory budgets. Preload hints, streaming queues, asset lifecycle management. | Medium | Supports large game projects and mobile optimization; essential for emulator ROM loading and procedural asset generation from v7.0 3D kit. |
| **Web Export + Publish Pipeline** | One-click "Publish" button: exports VG game to WebAssembly (browser) or native executables (Win/Mac/Linux/Mobile) with automatic asset bundling and code signing. Integrates Godot export system with VG toolchain. Ships with preset configs for itch.io, Steam, web. The feature that makes VG mainstream for indie shipping. | High | **100× reach multiplier.** Browser distribution unlocks millions of casual players. Removes friction from game publishing workflow. Positions VG as complete end-to-end solution: write game → ship to all platforms in 2 clicks. |
| **JIT Compiler (Tier 2) — Performance Multiplier** | Hot-loop detection and tier-2 JIT: detects loops running N iterations, compiles specialized code, jumps in. Does NOT replace AST interpreter — complements it. Expected 10–100× speedup on performance-critical code (emulators, physics, procedural generation, audio DSP). Makes C64 emulator boot from "30+ minutes" to "5 seconds." Removes VG's performance ceiling for real-time applications. | High | **Removes blocking constraint on performance-critical uses.** Transforms VG from "indie toy" to "viable game engine for all use cases." Essential for emulator quality + physics/AI-heavy games. Current AST fallback unacceptable for production code. |
| **Narcea AI Behavior Designer** | Extend Narcea from "code-writing assistant" to "game-logic co-author." Designer says *"Boss charges, pauses, jumps, slams, then retreats and shoots fireballs"* → Narcea generates full state machine, timing loops, particle effects, sound calls as clean VG code. Uses existing Narcea + causal chain debugging. Integrated behavior library (boss patterns, enemy AI, puzzle mechanics, NPC dialog flows). | High | **3–5× game dev speed multiplier.** Narcea moves from Tier 3 (paired programming) to Tier 5 (creative co-author). Game designers script constraints, AI fills in implementation. Democratizes game AI authoring. |
| **Game Modding Framework** | Standardized modding API. VG games automatically support player-created mods (`.vg` files loaded at runtime). Security sandbox + mod marketplace (like Steam Workshop). Players extend games post-ship: new levels, mechanics, balance tweaks, total conversions. | High | **10–100× increase in game lifespan.** Player-created content = community engagement = sustained revenue stream. Separates VG from one-off game distribution. |
| **Game Console Emulation as First-Class Feature** | Formalize emulation as canonical VG use case. Ship 5 complete reference emulators (C64, GBA, NES, SNES, Atari 2600) with full source code. Narcea can generate opcode dispatchers for new CPUs. Documentation + tutorials on cycle-accurate emulation, memory mapping, graphics pipelines. Positions VG as **"the language for retro gaming and emulation."** | Medium | **Niche but powerful positioning.** Emulator developers become VG's marquee use case. Differentiates VG from mainstream game engines. Builds on existing C64/GBA demos. |
| **Live Multiplayer Framework** | Built-in support for networked games. VG handles RPC boilerplate, sync, lag compensation, player state replication. Narcea assists with network architecture design. Example: "Make a couch-co-op game, add one line: `EnableMultiplayer()`, ship it." Supports both LAN and cloud backends. Planned for v7.1 after v7.0 core stabilizes. | Medium | **Unlocks entire game category.** Multiplayer is 2nd-most-common indie game mechanic (after single-player). Currently requires custom netcode. VG providing batteries-included solution attracts multiplayer-focused devs. Pairs with Web Export (cross-platform play). |

---

## 🎵 v6.5+ Audio DSP Capabilities — Professional Audio Tool Features (Post-Stable)

**Status:** Research / Capability Planning | **Timeline:** v6.5+ (Feb 2027+) | **Scope:** Low-level audio synthesis and effects library for users building professional audio tools (DAWs, synthesizers, trackers)

### Rationale

Users interested in building FL Studio-like DAWs, synthesizers, or music production plugins should have battle-tested, low-latency audio DSP primitives available in VG. This opens the door for community-built professional audio tools without committing VG to shipping a specific DAW implementation. Developers can focus on UI (Forms Designer) + business logic (VG), while VG provides the audio math.

### Audio DSP Feature Set

| Capability | Current State | v6.5+ Goal | Use Cases |
|------------|---------------|-----------|-----------|
| **Oscillator Library** | SoundGen provides basic sine/square/sawtooth/triangle/noise | Extend: band-limited wavetables, PWM duty cycle, phase distortion, sub-oscillator stacking | Synthesizer cores, chiptune trackers |
| **ADSR Envelopes** | ❌ Not in VG | Add VG API: `Envelope.Create(A, D, S, R)`, `Envelope.Process(env, trigger)` returns 0–1 amplitude. Multi-envelope support (pitch, filter, amplitude). | Synth dynamics, drum synthesis, expressive control |
| **Low-Pass Filter (IIR)** | ❌ Not in VG | Add C++ GDExtension: Butterworth / Moog ladder filter. VG wrapper: `Filter.Create(cutoff, resonance)`, `Filter.Process(sample)`. State-variable design for stability. | Synth character, subtractive synthesis, audio cleanup |
| **Effects: Reverb** | ❌ Not in VG | Add Freeverb algorithm (public domain). VG API: `Reverb.Create(room_size, damping)`, `Reverb.Process(L, R)`. | Spatial ambience, professional polish |
| **Effects: Delay** | ❌ Not in VG | Add circular buffer delay line. VG API: `Delay.Create(max_ms)`, `Delay.PushSample(s)`, `Delay.GetSample(ms)`. Feedback control. | Chorus, echo, tempo-synced repeats |
| **Effects: Compressor** | ❌ Not in VG | Add fast-attack compressor. VG API: `Compressor.Create(threshold, ratio, attack, release)`, `Compressor.Process(sample)` returns compressed sample. | Leveling, punch control, mastering chain |
| **Wave Table Editor** | ❌ Not in VG | VG UI (Forms Designer) for drawing custom waveforms, FFT analysis, import/export. Generate optimized lookup tables. | Sound design, custom instrument creation |
| **MIDI Controller Mapping** | ❌ Not in VG | VG wrapper for Godot's Input system: `MIDI.GetCC(channel, cc_num)`, `MIDI.GetNote(channel)`, `MIDI.GetVelocity()`. Mapping UI. | Real-time performance, hardware integration |
| **Audio Recording (WAV capture)** | ⚠️ Partial (SoundGen output only) | Extend: record raw PCM to Ring Buffer, export as WAV on-demand. Metadata support (sample rate, bit depth). | Session capture, loop recording, undo buffer |
| **Real-time Spectrum Analyzer** | ❌ Not in VG | Add FFT (radix-2 or radix-4). VG visualization wrapper for frequency bins. Optional: peak hold, smoothing. | Visual feedback, mastering reference |
| **Polyphonic Voice Manager** | ❌ Not in VG (SoundGen is monolithic) | Add note-on/note-off scheduling, voice allocation (round-robin or LRU), per-voice state (pitch, ADSR, filter). VG API: `Synth.NoteOn(pitch, velocity)`, `Synth.NoteOff(pitch)`, `Synth.Process()`. | Multi-note instruments, drum machines, polyphonic synths |

### Implementation Notes

- **All DSP in C++**: Audio thread safety, low-latency, no GDScript → C++ call overhead per sample.
- **VG Wrappers**: Each DSP component exposed as simple VG API (open handle, push/pull data, close). Data flows: VG UI → C++ parameters, C++ audio output → VG visualization.
- **Test Suite**: Regression tests for filter stability (extreme frequencies), envelope timing precision (ms-accurate), effect clarity.
- **Platform-Specific**: Validate on Linux (ALSA), Windows (WinMM + WASAPI), macOS (CoreAudio) for latency and jitter.

### Expected Outcomes

Users can build:
- **Synthesizers**: Polyphonic synths with ADSR, filters, effects
- **DAWs / Multi-track Sequencers**: Mixer UI, plugin-like synth instances, FX chains
- **Drum Machines**: Step sequencer, sound design, MIDI triggering
- **Audio Visualizers**: Real-time spectrum, waveform rendering, VU meters
- **Chiptune Trackers**: 4-8 voice sequencer with retro synth sound

### Roadmap Integration

- **v6.5 (Feb–Apr 2027)**: ADSR envelopes, low-pass filter, Freeverb reverb. First-pass testing. `demos/audio_dsp/` example library.
- **v6.6+ (May 2027+)**: Delay, compressor, wave table editor, MIDI mapping, spectrum analyzer, polyphonic voice manager.
- **v7.0+ (Q3 2027+)**: Advanced effects (chorus, distortion, granular), modulation matrix, preset system.

### Non-Commitments

- VG will **not ship** an official FL Studio clone DAW plugin.
- Community is free to build one (or many) using these primitives; VG will highlight excellent third-party tools in docs/showcase.
- VG core focus: language quality + Godot IDE integration. Audio DSP library is a capability, not a product.

---

### v7.0 Showcase Projects (Proposed)

| Project | Description | Demonstrates |
|---------|-------------|--------------|
| **Procedural 3D Voxel Generator** | VG + v7.0 VG3D kit. Uses numpy (shape manipulation), OpenGL compute shaders (performance), generates terrain/structures, exports to Godot scenes. | VG3D, Python integration, C++ perf paths |
| **AI-Powered Game Level Designer** | VG + Narcea AI pair + causal chain debugging. Designer writes level constraints in VG, AI generates playable levels, causal chain shows reasoning, debugger helps refine. | Narcea integration, causal chain, AI workflows |
| **Cross-Platform Mobile Game** | VG + Java/Android integration + asset streaming. Multi-touch input, dynamic loading, local persistence. iOS via Godot's Vulkan layer. | Java interop, asset streaming, mobile optimization |

| Project | Description | Scope | ETA | Status |
|---------|-------------|-------|-----|--------|
| **GBA or PS1 Emulator in VG (Primary)** | Primary advanced emulator showcase after v6.0. Final target selected by feasibility checkpoint (documentation maturity, profiler data, and implementation risk). **Scope:** Tier 2 (playable subset, not cycle-accurate). **Architecture:** VG-first core with reusable C++ primitives only. **Deliverable:** Standalone VG project in `demos/GBA_Emulator/` or `demos/PS1_Emulator/` with compatibility matrix and profiling report. **Impact:** Harder-than-NES proof point with realistic delivery risk, and direct inputs for runtime optimization priorities. | 8-12 weeks | Post-v6.0 | Planned |
| **PS1 Deep-Compatibility Expansion (Candidate)** | If primary target is GBA, expand to PS1 compatibility after the core architecture and profiling pipeline are proven. Focus on phased delivery: CPU core + memory map + minimal GPU path before compatibility expansion. **Scope:** Tier 3 (technical preview first, selective title support). **Impact:** High prestige systems-programming showcase for VG when prerequisites are proven. | 16+ weeks | Post-Primary Milestone | Candidate |

### Emulator Engineering Rules (VG-first, reusable by design)

These rules prevent "VG shell + hidden native emulator" and ensure emulator work improves core VG for all domains.

1. **VG-first logic boundary**: CPU dispatch, memory map policy, DMA/interrupt scheduling, and emulator state machine live in VG.
2. **C++ primitives only**: Native code may provide generic primitives (packed buffers, binary I/O, bit intrinsics, audio ring buffers, profiling hooks), not console-specific behavior.
3. **Reuse gate for native additions**: every new C++ primitive must show at least one non-emulator use case (e.g., image processing, physics grids, networking, tooling) and a benchmark.
4. **No black-box cores**: disallow native implementations that contain full console CPU/PPU/APU/GPU logic while VG acts only as UI glue.
5. **Profiling-driven optimization**: optimize only after hotspot proof from emulator traces and microbenchmarks; track before/after deltas in docs.
6. **Deliverable parity**: each emulator milestone must produce both (a) user-visible compatibility progress and (b) at least one reusable VG runtime/tooling improvement.

---

### External C++ Library Integration Strategy (v6.0+)

**Objective**: Enable high-performance emulation and numeric computing by linking against pre-existing C++ libraries without breaking the VG-first architecture.

**Architecture Principles**:

1. **Thin native wrappers, not full reimplementations**  
   - Link against libraries (libopenmpt, zstd, xsimd, mimalloc, etc.) via `SConstruct` flags
   - Wrap library APIs in lightweight C++ adapters (50-200 lines per library, live in `src/visual_gasic_external_libs.cpp` or per-subsystem `.h/.cpp`)
   - Expose to VG as builtins or opcodes with zero semantic changes

2. **License compatibility (MIT/Apache/BSD preferred)**  
   - GPL/copyleft libraries acceptable only for optional subsystems (clearly marked `[GPL]` in docs)
   - Vendored libs become the plugin maintainer's responsibility for security patches

3. **Platform build validation**  
   - Every linked library must build on **at least Linux + Windows + macOS**
   - CI matrix: test each integration on the three platforms before merge
   - Fails on any platform → library addition is deferred or marked experimental

4. **Binary footprint awareness**  
   - Log `.so` size deltas (`stat libvisualgasic.linux.editor.so`) for each major library
   - Document the tradeoff: e.g., "xsimd adds 0 bytes to binary; mimalloc adds 150KB"
   - Large libs (>1MB delta) need strong ROI proof from emulator or real project

5. **Profiling-driven adoption**  
   - Link a candidate library only **after** profiling hotspots prove the bottleneck
   - Example: "vector_storm profiling showed `Dim arr(N) As Single` boxes every access (70µs/iteration). SIMD library would reduce this to ~7µs. Adding xsimd to SConstruct."
   - Track before/after benchmark deltas in `performance.conf` and CHANGELOG

**Recommended Library Tiers** (candidate for v6.2+):

| Tier | Libraries | Purpose | Effort | ROI |
|------|-----------|---------|--------|-----|
| **A — Audio/I/O** | libopenmpt (tracker), PortAudio (real-time audio), zstd (compression) | Music/emulation audio fidelity, buffer compression for large arrays | Low (~1 day each; mostly parsing/binding work) | High — emulators + game audio benefit immediately |
| **B — SIMD/Numerics** | xsimd (vector ops abstraction), mimalloc (faster allocator), Eigen (linear algebra) | Physics grids, particle systems, 3D math, emulation inner loops | Medium (~3-5 days; requires opcode specialization) | High — 2-10x speedup on batch workloads |
| **C — System/Crypto** | OpenSSL/MbedTLS (if not already available via Godot), libsodium (modern crypto) | Networking, asset encryption, secure RNG | Low (~1 day; usually already available) | Medium — security + game networking |
| **D — Research/Optional** | TinyJIT (lightweight JIT), LLVM subset (advanced compilation) | Advanced optimization tier; deferred to v6.3+ | High (~2-4 weeks) | Speculative — wait for profiler data first |

**Integration Checklist**:
- [ ] Profiler output showing measurable bottleneck in target workload
- [ ] Library selection decision document (why this library, not alternatives)
- [ ] SConstruct patch: `-I`, `-L`, `-l` flags + pkg-config fallback
- [ ] CI verification: builds clean on Linux/Windows/macOS
- [ ] Wrapper code: `extern "C"` wrappers or safe C++ adapters
- [ ] VG binding: opcodes or builtins exposed to VG-side code
- [ ] Documentation: BUILTINS.md entries with examples + platform notes
- [ ] Benchmark: before/after performance delta in `performance.conf`
- [ ] Example: demo project in `demos/` showing library in action

**Known Integrations Ready for v6.2**:

| Library | Candidate Date | Status | Blocker |
|---------|---|---|---|
| **xsimd** (SIMD abstraction) | v6.2 (Dec 2026) | Planned | Profiling proof from emulator or vector_storm follow-up |
| **mimalloc** (allocator) | v6.2–v6.3 | Planned | Binary size validation; ensure jemalloc not already linked by Godot |
| **zstd** (compression) | v6.3 | Candidate | Use case proof (asset streaming, save game compression) |
| **OpenSSL/MbedTLS** | v6.2 | Candidate | Check if Godot already exposes TLS via GDExtension |

**Post-v6.0 Discussion**:
After the stable release, measure real emulator hotspots (GBA/PS1 profiler data) and circle back to this checklist. The library roadmap is data-driven; speculative tier-D additions wait for proof.

---

### Platform Expansion: Windows Support for Audio/Tracker Subsystems

**Task**: Bring Tracker (libopenmpt), Music (SiONDriver), and SoundGen (audio synthesis) builtins to Windows.

**Current Status**: 
- ✅ Linux/macOS: Full support via libopenmpt + native audio APIs
- ❌ Windows: These subsystems NOT available (libopenmpt not in Windows build config)
- 📖 **Documentation**: Phase 1 backfill of VisualGasic_Language_Reference.md marks these as `[Linux/macOS only]` (51 new entries added as of Jul 9, 2026)

**Strategy** (Pre-v6.1, candidate for v6.2):
1. **libopenmpt on Windows**: Add Windows pkg-config or VCPKG fallback in SConstruct; verify build + link against prebuilt binaries
2. **Audio infrastructure parity**: Ensure SiONDriver + AudioStreamGenerator work on Windows (likely already compatible; just needs testing)
3. **Regression testing**: Validate all Music/Tracker/SoundGen examples run identically on Win/Mac/Linux
4. **Remove platform badge**: Once verified cross-platform, remove `[Linux/macOS only]` from docs

**Blocker**: Windows CI pipeline for libopenmpt verification (currently missing)

---

### Tier 3: Platform Compatibility Audit (Backlog, Post-v6.0)

**Goal**: Make platform behavior explicit and testable across all target exports: **Windows, macOS, Linux, Web, Android**.

**Status**: Backlog (documentation-driven first, implementation only when audit evidence confirms gaps)

**Scope**:
1. Build and maintain a command/platform support matrix for user-facing APIs.
2. Complete platform badges in the language reference (`supported`, `fallback`, `no-op`, `unsupported`).
3. Verify behavior parity by target via smoke tests for subsystem commands (Process/Socket/FileWatcher/COM/JS/GPS/Permissions/Steps/Audio Tracker).
4. Standardize policy wording in docs and runtime: distinguish clearly between `unsupported` vs `safe default` vs `platform fallback`.

**Deliverables**:
- Platform compatibility matrix (single source of truth)
- Documentation parity report (all platform-sensitive commands annotated)
- Targeted test checklist per platform (Windows/macOS/Linux/Web/Android)
- Gap list with owner and severity (doc-only, runtime bug, or feature request)

**Decision Gate**:
- Promote findings to scheduled milestone work only when reproducible tests show user-facing impact on one or more target platforms.

---

## 🚀 Performance Optimizations — Post-M8 (Conditional on Profiling)

These optimizations emerged from real VG projects (vector_storm, Jun 2026) and are candidates for v6.2+. **Tier A** items have measured proof; **Tier B** items are speculative but plausible. **Do not implement until profiling from a GBA or PS1 emulator (or similar) confirms the bottleneck.**

### Tier A: High Confidence (Proven via vector_storm)

| Feature | Description | Evidence | Impact | Priority | ETA |
|---------|-------------|----------|--------|----------|-----|
| **Typed Array Specialization (PackedArray fast-path)** | Auto-convert `Dim x(N) As Byte/Int32/Float64` to Godot `PackedByteArray`/`PackedInt32Array`/`PackedFloat64Array` with dedicated bytecode fast-path opcodes (`OP_PACKED_BYTE_GET`, `OP_PACKED_INT32_GET`, etc.). Measured impact: **5-10x speedup** on array-heavy loops. **Mechanism:** Today, `Dim arr(N) As Byte` boxes every access through Variant → 70µs per iteration (from `vg_bytecode_perf.md`). Specialization emits raw `PackedByteArray` ops → ~7µs per iteration. **Who benefits:** image processing (pixel buffers), graphics (vertex/point arrays), animation (keyframe arrays), particle systems, physics grids, emulators (memory arrays). | vector_storm case study (Jun 2026): 240-cell loop hit 16ms/frame due to Variant boxing on `Dim arr(N) As Single`. Profiling proved root cause. Specialization would recover 80-90% of frame time. | Broadly applicable across all array-heavy projects; not emulator-specific. | High | v6.2–v6.3 |

### Tier B: Medium Confidence (Speculative, needs data)

| Feature | Description | Rationale | Use Cases | Blocker | Priority | ETA |
|---------|-------------|-----------|-----------|---------|----------|-----|
| **Bit Manipulation Builtins** | Low-latency intrinsic functions: `GetBit(val, bit)`, `SetBit(val, bit, state)`, `CountBits(val)` (popcount), `RotateLeft(val, n)`, `RotateRight(val, n)`. Avoids C++ library marshalling overhead (~1-10µs per call). For emulators, graphics, compression, and networking, bit ops can comprise 20-30% of frame time if not optimized. | Emulator work (GBA or PS1) will use these heavily. Graphics masks, color channels, collision flags. Compression (DEFLATE, LZ77). Network protocols (TCP flags, packet headers). | Emulators, image processing, game logic (collision masks, tile attributes), compression, networking | Profiling data from a GBA or PS1 emulator showing bit ops >5% of frame time; or similar project | Medium | Post-v6.2 |
| **Switch Statement Jump Table Optimization** | Compile dense `Select Case` blocks with numeric constants (0–255) to O(1) jump tables instead of O(n) sequential comparisons. Typical for instruction decoders (6502, Z80, 68000), event dispatchers, game state machines. | Instruction dispatch is the hottest loop in emulators. Each CPU cycle runs one instruction. Dense `Select Case opcode` (0–255) would benefit from jump table. Estimated 2-3x speedup on dispatch. | Emulators (instruction decoders), state machines, event routing, message dispatch | Profiling data from a GBA or PS1 emulator showing `Select Case` is >10% of frame time | Medium | Post-v6.2 |
| **Rotate Operators (`<<<`, `>>>`)**  | Add bitwise rotate operators: `value <<< n` (rotate left), `value >>> n` (rotate right). Distinct from shifts (`<<`, `>>`): rotate preserves all bits by wrapping. Many 6502/Z80 instructions include rotate ops; currently simulated via shift+mask combos. | CPU emulation, encryption (rotations in AES/SALSA20), graphics (rotation matrices), compression (bit rotation in adaptive codes) | Emulators, cryptography, graphics, compression | Natural fit with existing `<<`/`>>` operators; low implementation cost | Low | v6.2+ |

---

## 🔧 v6.1: Performance Patch Cycle (Jan–Feb 2027)

Following v6.0 stable release, v6.1 will focus on measured performance improvements derived from GBA or PS1 emulator profiling and real-world VG projects. These are **compiler/VM optimizations only**—no breaking language changes.

**Rationale**: v6.0 ships with stable core language and Godot IDE integration. v6.1 consolidates performance wins discovered during GBA or PS1 emulator work, delivering faster code without complexity. This keeps v6.0 release schedule clean and v6.1 as a fast, high-confidence patch cycle.

### v6.1 Optimization Candidates (Prioritized)

| Feature | Scope | Evidence | Impact | Blocker | ETA |
|---------|-------|----------|--------|---------|-----|
| **String Specialization (PackedStringArray)** | `Dim strings(N) As String` → `PackedStringArray` backing with `OP_PACKED_STRING_GET/SET` fast-path opcodes. String concatenation via `String.join()` pattern instead of repeated `&` operators. | Common in asset loading (parsing CSV, JSON headers, sprite names, audio metadata). GBA or PS1 emulator profiling will reveal if string ops dominate asset I/O. | Estimated 5-15x speedup on string-heavy workloads (CSV/JSON parsing, log formatting, text rendering). | GBA or PS1 emulator profiling showing string ops >2% of frame time; or similar project with heavy string I/O | v6.1 Phase 1 |
| **Dictionary Access Fast-Path** | Specialized `OP_GET_DICT_FAST` / `OP_SET_DICT_FAST` opcodes for String or Integer keys, with early-exit for cache hit. Similar to existing dict handling but with instruction-level optimization. | GBA or PS1 likely uses lookup tables: palette cache, sprite metadata, ROM offset index. If dict access is measurable bottleneck, specialization yields 2-5x speedup. | Estimated 2-5x speedup on dictionary-heavy code (lookup tables, state maps, asset registries). | GBA or PS1 emulator profiling showing dict access >2% of frame time; or benchmark dictionary-heavy code | v6.1 Phase 1 |
| **Inline Builtins** | Convert high-frequency function calls to single-opcode patterns: `Len(arr)`, `UBound(arr)`, `LBound(arr)` → `OP_BUILTIN_LEN`, etc. String functions: `Mid(s, n, m)`, `Left(s, n)`, `Right(s, n)` → specialized opcodes for small constant ranges. `Abs()`, `Min()`, `Max()`, `Mod()` → typed fast-path for Int/Float. | Every loop that checks `Len()` or accesses array bounds does a function call stack push/pop. GBA or PS1 emulator will have tight inner loops checking `UBound()` for bounds validation. | Estimated 1-3x speedup on loop-heavy code; broadly applicable across all projects. QoL improvement: no measurable frame-time cost to ship. | Profiling data showing function-call overhead >1% on tight loops; or commit based on code review (low risk). | v6.1 Phase 2 |

### v6.1 Decision Gates

- **Phase 1 (Feb 1–14)**: String specialization + dictionary fast-path **only if** GBA or PS1 emulator profiling shows measurable bottleneck (>2% frame time each).
- **Phase 2 (Feb 15–28)**: Inline builtins, shipped regardless of profiling (zero risk, pure QoL).
- **Post-v6.1 blocker**: If GBA/PS1 profiling reveals no string/dict bottleneck, defer those items to v6.2 and focus engineering effort elsewhere.

---

> 💬 **Community input drives priorities.** Open a [GitHub Issue](https://github.com/xgreenrx-star/VisualGasic/issues) or discussion to vote on features.

---

## 📝 Language Feature Candidates — Future Cycles

These are high-value language additions discovered through real-world projects (GBA or PS1 emulator work, vector_storm, UI Forms). Prioritized by impact and implementation effort.

### Immediate / High-ROI (v6.x Tier)

| Feature | Description | Syntax Example | Effort | ETA | Rationale |
|---------|-------------|-----------------|--------|-----|-----------|
| **String Interpolation** | Native string interpolation syntax for cleaner readability and AI code generation. Current: `"Hello " & name & "!"`. | `$"Hello {name}!"` | 1 week | v6.0 (if time) / v6.2 | Universally loved, universally used. Dramatically improves log/UI text generation. AI-friendly (LLMs generate fewer concat errors). |
| **Null-Coalescing Operator** | Provide default value when expression is null. Complements existing `?.` safe navigation. | `value = obj?.Property ?? default` | 2 weeks | v6.2 | Common defensive-programming pattern; reduces nested If blocks. Essential for Godot's nullable object model. |
| **Tuple Deconstruction** | Unpack multi-value returns into individual variables. Pairs with `Await` for async ops. | `Dim (x, y, z) = GetCoordinates()` | 1.5 weeks | v6.2 | Cleaner than indexing for functions returning multiple values. Improves readability of AI-generated code. |
| **Defer Statement** | Guarantee cleanup code runs at scope exit (alternative to Try/Catch/Finally). | `Defer f.Close()` | 2 weeks | v6.2 | Simpler than Try/Catch for file I/O, locks, emulator state save/restore. Especially valuable for systems programming (GBA/PS1 emulators). |

### v7.0 Expansion (Core Language Maturity)

| Feature | Description | Syntax Example | Effort | ETA | Rationale |
|---------|-------------|-----------------|--------|-----|-----------|
| **Module / Namespace System** | Organize functions into logical groups, prevent naming collisions in large projects. | `Module Emulator.CPU` / `Function Emulator.CPU.Execute()` | 3 weeks | v7.0 | Essential for emulator projects (CPU, GPU, APU modules). Supports team projects. Links to symbol table redesign. |
| **Using Statement** | Automatic disposal of objects at scope exit (pairs with Godot's `free()` / `queue_free()`). | `Using f = File.Open(path) ... End Using` | 2 weeks | v7.0 | Cleaner than Defer for Godot objects. RAII-like behavior without language complexity. |
| **Pipeline Operator** | Chain function calls for functional composition. | `arr \|> Filter(...) \|> Map(...) \|> Print()` | 1 week | v7.0 | Improves readability of complex data transformations. Attracts functional programming community. |

### Nice-to-Have (Lower Priority)

| Feature | Description | Syntax Example | Effort | ETA | Rationale |
|---------|-------------|-----------------|--------|-----|-----------|
| **Switch Expressions** | More concise match syntax (already have statement form). | `status = x Match { "on" => "active", _ => "unknown" }` | 2 weeks | v7.x | Pairs with pattern matching; reduces boilerplate for event dispatchers. |
| **Record Types** | Immutable data classes with auto-generated equality and hashing. | `Record Point(x As Integer, y As Integer)` | 2 weeks | v7.x | Clean syntax for data-heavy domain models. Useful for game state snapshots, asset metadata. |
| **Computed Indexers** | Allow classes to define custom `obj(index)` access like arrays. | `Default Property Item(x, y) As Tile` | 1.5 weeks | v7.x | Enables grid, tree, graph abstractions to behave like built-in arrays. |

---

## 🎮 Porting VG to Other Game Engines — Feasibility Analysis

**Short Answer**: Yes, but with caveats. VG's core design is engine-agnostic; porting requires ~4-6 weeks per engine for bindings + integration.

### Architecture Overview (Why Portability is Feasible)

VG's stack is cleanly layered:

```
┌─────────────────────────────────────┐
│  VG Language Frontend               │  Tokenizer, Parser, AST
│  (engine-agnostic)                  │  — same for all engines
├─────────────────────────────────────┤
│  VG Compiler → Bytecode             │  Generates portable bytecode
│  (engine-agnostic)                  │  — same VM for all engines
├─────────────────────────────────────┤
│  VG Bytecode VM (C++)               │  Stack machine, ~200 opcodes
│  (engine-agnostic)                  │  — same for all engines
├─────────────────────────────────────┤
│  Engine Bindings (engine-specific)  │  Language stdlib, IDE integration
│  (engine-specific adapter)          │  ← THIS PART CHANGES per engine
├─────────────────────────────────────┤
│  Target Engine (Godot / Unity / etc)│
└─────────────────────────────────────┘
```

**What's reusable across engines**: Tokenizer, Parser, AST, Compiler, VM bytecode dispatch  
**What needs per-engine work**: Language bindings (stdlib functions), editor integration, debugging hooks

---

### Tier 1: High-Confidence Ports (4-6 weeks each)

#### **Unity (C#)**
- **Status**: Most feasible. C# has near-identical semantics to VB6 (sister language at Microsoft)
- **Work Required**:
  - Write VG→C# binding layer (~2 weeks) mapping VG opcodes to C# function calls
  - Godot stdlib → Unity API translation (~2 weeks): Canvas2D → Unity Sprite/Canvas, AudioStreamPlayer → AudioSource, etc.
  - Unity editor toolbar + script inspector (~1 week)
  - Testing on 3-4 sample games
- **Risk**: Low. Both managed runtimes with similar GC behavior.
- **Advantage**: Massive market (10M+ Unity devs); iOS/Android support native

#### **Unreal Engine (C++)**
- **Status**: Feasible but more complex. UE native code, no scripting VM by default
- **Work Required**:
  - Embed VG VM as Unreal plugin (~2 weeks)
  - Write VG UObject binding layer (~2 weeks): property reflection, UFunctions, delegates
  - Custom Blueprints node for VG script embed (~1 week)
  - C++ interop (two-way calling between VG ↔ UE natives) — likely covered by v7.0 C++ interop work
- **Risk**: Medium. UE's property system requires custom reflection layer
- **Advantage**: AAA-grade engine; attracts larger studios

---

### Tier 2: Medium-Confidence Ports (6-8 weeks each)

#### **Defold (Lua-based)**
- **Status**: Feasible. Defold has clean runtime architecture
- **Work Required**:
  - Port VG VM to Lua FFI (~2 weeks)
  - Defold collection/sprite API bindings (~2 weeks)
  - Editor integration via Defold's extension API (~2 weeks)
- **Risk**: Medium. Smaller ecosystem; less demand
- **Advantage**: Mobile-optimized; free deployment

#### **Game Maker Studio (GML)**
- **Status**: Feasible. GML is also procedural like VB6
- **Work Required**:
  - GML bytecode transpiler OR VM embedding (~3 weeks)
  - GML stdlib bindings (~2 weeks)
  - IDE integration via GML extensions API (~1 week)
- **Risk**: Low-Medium. GML is well-documented
- **Advantage**: Strong 2D indie community

---

### Tier 3: Lower-Priority / Speculative (8+ weeks)

| Engine | Feasibility | Notes |
|--------|-------------|-------|
| **Bevy (Rust)** | Speculative | Would need full Rust FFI layer; VG type system → Rust trait system mapping. Risk: High. Benefit: Niche (game dev + Rust enthusiasts). |
| **O3DE (C++)** | Feasible but niche | Sister to Lumberyard; similar UE binding approach. Lower market demand than UE. |
| **Stride (C#)** | Medium | C# sibling of Unity; similar binding work. Smaller ecosystem. |
| **Pygame / Arcade (Python)** | Low priority | Python ecosystem has strong native VB/BASIC-like language (not needed). Educational audience only. |

---

### Business/Strategy Considerations

**Timeline for multi-engine support:**

| Phase | Timeline | Scope |
|-------|----------|-------|
| **v6.0–v7.0** | Jan–Jul 2027 | Godot only (current focus). Stabilize core VM, C++/Python interop, NES emulator. |
| **v7.0–v8.0** | Jul–Jan 2028 | **Unity port begins**. Highest ROI: largest non-Godot engine community. |
| **v8.0–v9.0** | Jan–Jul 2028 | **Unreal port**. Targets AAA/larger studios. C++ interop from v7.0 provides foundation. |
| **v9.0+** | 2028+ | Defold / Game Maker / others on demand |

**Why Unity first?**
- C# familiarity reduces impedance mismatch
- Largest game dev community after Unreal
- ~1.5 weeks faster than Unreal port (no UObject reflection layer)
- Proven success with VB6 → C# as sister languages

**Positioning strategy:**
- v6.0 launch: "The Godot BASIC."
- v7.1 (post-v7.0): "The cross-platform BASIC." (Unity announcement)
- Marketing angle: "Write your game logic once, run in Godot / Unity / Unreal."

---

> 💬 **Community input drives priorities.** Open a [GitHub Issue](https://github.com/xgreenrx-star/VisualGasic/issues) or discussion to vote on features.

---

*This roadmap is a living document. Priorities may shift based on community feedback and development resources.*
*Reality-pass policy: the v5.x window is for finishing. New ambitious ideas go to v6.0 or v7.0 \u2014 not into the next minor.*

---

## 📈 v6.0 Messaging Rebranding — "Professional Positioning" (Phase 1: Jul–Dec 2026)

**Strategic Goal**: Shift from "hobbyist/indie nostalgia" framing to **"enterprise-grade safety & auditability for AI-native development"** while keeping VB-inspired syntax that works exceptionally well in practice.

### Core Insight

Current messaging emphasizes auditing, VB6 familiarity, and indie game tooling. This is *honest* but narrow. The deeper win is: **VG's explicit type system, block-bounded syntax, and "what you see is what runs" guarantee eliminate an entire class of AI hallucination failures before they reach runtime.**

For professionals shipping AI-generated code under regulatory oversight, this is worth more than nostalgia.

### Messaging Shifts (v6.0 launch)

| Current Frame | Rebranding (v6.0) | Rationale |
|---|---|---|
| *"The language you read when you don't trust the AI"* | *"The language that eliminates AI type-hallucination failures before compile."* | Shifts from human audit → automated guardrails. Compliance-first angle. |
| "VB6-style BASIC" | "Explicit-Type Deterministic Language" (or "Deterministic Systems Language") | Removes legacy baggage; emphasizes modern properties (safety, predictability, auditability). VB6 syntax is a *property*, not the brand. |
| "Auditable AI code for Godot" | **Multi-context framing**: (A) **Godot games**: "VG brings AI-readable syntax to game logic." (B) **Microservices/CLI**: "Type-safe AI code for data pipelines and tools." (C) **Enterprise apps**: "Compliance-first language for regulated AI systems." | Broadens appeal; prepares for post-Godot expansion (v7.0+). |
| "50 years of VB heritage" | "Modern language, proven syntax" | Neutral framing; emphasizes proven-ness without baggage. |
| Performance: "30–119× faster than GDScript" | Performance: "Native-tier speed (JIT Tier 3 compile-to-x86-64)" | Technical credibility; doesn't rely on comparison; speaks to absolute capability. |

### Rebranding Rollout (v6.0 release cycle)

**Phase 1a — Documentation & README (Aug–Sep 2026)**
- [ ] Rewrite README.md headline to emphasize compliance/safety over nostalgia
- [ ] Add "Why Explicit Types Matter for AI Safety" section to docs/manifesto.md
- [ ] Update landing page on website to lead with compliance narrative
- [ ] Add case study: "How VG Eliminates Common AI Hallucination Patterns" (doc with 3–5 examples: type confusion, API parameter order, boundary errors)
- [ ] Add "Enterprise" FAQ section covering licensing, support, security model
- [ ] Update all marketing copy in GitHub release notes

**Phase 1b — Naming Adjustments (Sep–Oct 2026)**
- [ ] Internal rename codebase references from "VB6 BASIC" → "Explicit-Type Deterministic" or settle on clearer name post-stakeholder feedback
- [ ] File a **discussion** to crowdsource final name ("Explicit-Type Language"? "SafeBasic"? Input welcome)
- [ ] Once settled, update all `*.md`, comments, and marketing (non-code-breaking)

**Phase 1c — Logo / Visual Identity (Sep–Oct 2026)**
- [ ] Current VG logo (purple shield) is fine, but marketing collateral should emphasize "professional" theme:
  - Remove casual/indie styling if present
  - Add "Enterprise-Grade" tagline below VG in press materials
  - Security badge / certification placeholder for future compliance certifications (SOC 2, SLSA, etc.)

**Phase 2 — Asset Library Submission (Nov 2026)**
- [ ] Rewrite plugin description to lead with enterprise positioning
- [ ] Include "Compliance & Safety" as primary category (alongside Game Development)
- [ ] Add release notes emphasizing compliance features
- [ ] Highlight that VG is **free & open-source** under GPL-3.0 (removes enterprise "black box" concerns)

### Expected Outcomes

- **CTO-level interest**: Language positioned as AI governance tool, not legacy nostalgia
- **Hiring pool expansion**: Enterprise shops considering VG for non-game workflows (data tools, microservices, scripts)
- **Broader market messaging**: "Works great for games AND business logic"
- **Reposition "boring" as strength**: Explicit syntax + strict types = "boring by design" (trusted, predictable, auditable)

### Risk Mitigations

| Risk | Mitigation |
|---|---|
| Lose indie/hobbyist appeal | Keep game dev focus. Emphasize: "Games are apps too." VG is still the best Godot scripting language. Add "Hobbyist Friendly" marketing path alongside enterprise. |
| Jargon alienates existing users | Transition messaging, not language. VB-inspired syntax unchanged. Existing users see no impact. |
| "Deterministic" claim under-delivered | Document guarantees clearly: no metaclasses, no implicit dispatch, no hidden decorators. What's in the source is what runs. Deliver receipts via formal verification roadmap (v7+). |
| Enterprise customers ask "Where's the support?"; "Is this production-ready?" | v6.0 stable must ship with: (1) clear support/SLA documentation, (2) security policy, (3) known limitations, (4) roadmap. Open discussion for potential commercial support partner (v6.1+). |

---

## 🔧 v6.1 Roadmap — "Language Parity & Developer Experience" (Post-v6.0 stable, Q1 2027)

**Strategic Goal**: Close remaining gaps between VG and modern BASIC/twinBASIC/C# capabilities. Add compiler-enforced API safety and visual debugging enhancements. Deliver features Godot users have explicitly requested.

**Context**: v6.0 ships with core language stability, Python bridge (Tier A), and C++ FFI. v6.1 polishes the language with compile-time enforcement of design patterns (abstract classes/methods), adds a visual causal chain debugger, and completes Try/Catch/Finally stress testing across all execution paths.

### Flagship Feature: Abstract Classes & Methods — Compile-Time API Safety

**Problem it solves**: Godot users requested "true abstract classes or interface systems to enforce rigid design patterns and compile-time API safety across codebases." VG currently has `Implements` but doesn't enforce that interface methods are actually defined (loose checking). v6.1 adds compile-time validation.

**Implementation**:

| Feature | Scope | Estimate |
|---------|-------|----------|
| **`MustOverride` keyword** | Mark interface/base methods as required in derived classes. Parser recognizes; compiler validates every `Implements X` class defines all `MustOverride` methods. | 1 week |
| **`MustInherit` class modifier** | Prevents direct instantiation of base classes; only derived classes can be instantiated. Pairs with abstract method pattern. | 3–4 days |
| **Compile-time validation** | (1) Track all `MustOverride` methods in an interface. (2) Check derived class methods at parse/compile time. (3) Report clear error: "Class X implements IEnemy but does not define MustOverride Sub TakeDamage(amount As Integer)". | 1 week |
| **IntelliSense integration** | When auto-completing a derived class, suggest stubs for all `MustOverride` methods (like IDE "Implement Interface" helper). | 3–4 days |

**Example**:
```vb
Interface IEnemy
    MustOverride Sub TakeDamage(amount As Integer)
    MustOverride Function GetHealth() As Integer
End Interface

MustInherit Class Enemy Implements IEnemy
    ' Derived classes MUST implement these
End Class

Class Zombie Inherits Enemy
    Sub TakeDamage(amount As Integer)
        health = health - amount
    End Sub
    
    Function GetHealth() As Integer
        Return health
    End Function
End Class

' Compile error (prevents shipping broken code):
Class BrokenZombie Inherits Enemy
    ' Missing TakeDamage and GetHealth → compile error
End Class
```

**Impact**: Eliminates runtime dispatch failures; catches API mismatches before shipping. Competitive with C#'s abstract classes and GDScript's informal duck-typing.

**Acceptance**:
- 15+ test cases covering valid/invalid overrides, multi-level inheritance, interface composition
- IntelliSense stubs generated correctly
- Error messages point to exact line number of missing method
- No silent fallbacks

---

### Secondary Feature: Causal Chain Visualization — Visual Interactive Panel

**Problem it solves**: "Show auditor what happens when user clicks a button" in visual form (not just text). Extends M6 text-mode teaser to full interactive graph.

**What ships in v6.0 (M6 teaser)**: Text-mode causal chain (AST walk output, 100 lines)

**What ships in v6.1 (visual)**: 
- Rendered as a Godot 2D node graph in a docked panel
- Each Sub/Function/Event is a box; calls/signals are edges
- Click a box → navigate to that line in code editor
- Color-coded by type (event handler = red, helper = blue, signal = green)
- Supports cross-file navigation (UI Forms importing from game scripts)

**Implementation**:
- Reuse `VGVectorCanvas2D` infrastructure from codebase
- Extend `code_navigator.gd` with `_build_causal_graph()` method
- Layout algorithm: simple top-down tree (no cycle detection needed — VG has no circular calls)
- Interactive: hover highlights path, click navigates

**Effort**: 2–3 weeks (depends on complexity; text mode already done in M6)

**Acceptance**:
- 500-line form renders full causal chain in <1s
- Click navigation works and highlights visited boxes
- Cross-file links (e.g., form → game script) trace correctly

---

### Tertiary Features: Language Parity Polish

| Feature | Scope | From M8? | Estimate |
|---------|-------|----------|----------|
| **Try/Catch/Finally stress test** | Full regression suite: nested blocks, error state corruption, resource cleanup (`Finally` always runs), cross-module exception bubbling. | Yes (M8) | 3–4 days |
| **Lambda edge cases** | Multi-line block lambdas with nested control flow (nested Lambdas, Return in inner lambda, etc.). Stress test both bytecode VM and tree-walk evaluator. | Yes (M8) | 2–3 days |
| **Null-conditional operator `?.` completeness** | Chained `obj?.Method()?.Property?.Field` and mixed null checks. Edge case: `dict?.Keys?.Count`. | Yes (M8) | 3–4 days |
| **Named argument calls** | `Call Foo(x:=10, y:=20)` fully tested across Sub/Function/Property overloads. Mixed positional/named. | Yes (M8) | 3–4 days |
| **Set Collection** | Stdlib `Set(Of T)` wrapper class. Add `Add()`, `Remove()`, `Contains()`, `Count` property. Built on Dictionary keys (no value duplication). Full test suite for arity, iteration, hashing. | New | 1 week |
| **Tuple Support** | Lightweight `Tuple(Of T1, T2, ...)` class with unpacking: `Dim x, y = coords.Unpack()`. Support tuples in return values and function parameters. | New | 1–2 weeks |

---

### v6.1 Priority Matrix

| Feature | Impact | Effort | Status |
|---------|--------|--------|--------|
| **Abstract Classes/Methods** | 🔴 HIGH (GDScript never had this; competitive advantage) | 3 weeks | 🆕 New |
| **Causal Chain Visual** | 🟠 MEDIUM (audit trail; mostly infrastructure) | 2–3 weeks | Extends M6 |
| **Set & Tuple Collections** | 🟠 MEDIUM (quick wins; functional programming) | 2–3 weeks | 🆕 New |
| **Try/Catch/Finally stress** | 🟠 MEDIUM (stability, not new feature) | 1 week | From M8 |
| **Lambda / null-conditional / named args** | 🟡 LOW (edge cases; nice-to-have polish) | 2–3 weeks | From M8 |

### v6.1 Exit Criteria

✅ **Must Have**:
1. Abstract methods compile-time validation working
2. MustInherit prevents instantiation
3. IntelliSense stubs for Implements classes
4. All 15+ test cases pass
5. Set(Of T) fully functional with Add/Remove/Contains
6. Tuple(Of T1, T2, ...) unpacking works in all contexts

🟡 **Should Have**:
1. Causal Chain visual panel renders and navigates
2. Try/Catch/Finally stress suite all green
3. Named arguments fully tested
4. Set operations (Union, Intersection, Difference) documented
5. Tuple integration with method returns

🟢 **Nice to Have**:
1. Lambda edge cases documented and tested
2. Null-conditional operator chain handling
3. Set hashing optimization for large collections
4. Tuple pattern matching (future v6.5 candidate)

---

## � v6.5 Roadmap — "Python Performance Optimization" (Post-v6.0 stable, Q1 2027)

**Strategic Goal**: Eliminate cross-process IPC overhead for Python integration, enabling real-time data processing (image/audio/ML workloads) without architectural compromises.

**Context**: v6.0 ships Python bridge Tier A (out-of-process worker via JSON-RPC). While correct and safe, it has fundamental latency floor (~5–20ms per call) that makes pixel-by-pixel image processing infeasible. v6.5 addresses this with phased performance improvements culminating in embedded CPython (Tier B), unlocking real-time workflows.

### Performance Target

| Scenario | v6.0 Tier A | v6.5 Target | Delta |
|----------|-----------|-----------|-------|
| Single `py_call()` | 5–20ms | <1ms | **50× faster** |
| 100-call loop | ~2s | ~20ms | **100× faster** |
| Image filter (1080p) | ❌ Infeasible | <50ms | ✅ Real-time |
| Async queuing (10 concurrent) | Blocks caller | Returns immediately | ✅ Non-blocking |

### Phase Breakdown

#### ✅ **Phase 3: Async Queue (M5 blocker, ships Oct 2026)**
**Status**: Prerequisite, lands before v6.0 stable  
**Work**: VGTask-compatible async queue; `py_call_async()` returns immediately with task handle  
**Impact**: 5–10% latency improvement (reduced lock contention); unblocks Narcea AI pair  
**Acceptance**: 10 concurrent calls queue without blocking; Narcea integrates successfully

#### 🔶 **Phase 4: Binary Protocol (v6.5, Week 1)**
**Status**: Post-v6.0, optional optimization  
**Work**: Replace JSON with MessagePack; 30–40% serialization overhead reduction  
**Impact**: ~50% faster IPC (~5–15ms per call vs 5–20ms)  
**Files**: `src/python_bridge/visual_gasic_py_facade.cpp`, `addons/visual_gasic/python_worker.py`  
**Acceptance**: numpy.dot() <15ms; backward-compat verified; no Variant corruption

#### 🔶 **Phase 5: Batch API (v6.5, Week 2)**
**Status**: Post-v6.0, algorithmic win  
**Work**: Single RPC for array of calls; eliminates round-trip amplification  
**Impact**: **100× speedup for loops** (1000 calls: 2s → 20ms)  
**API**: `PyCallBatch(module, method, args_array)` returns result_array  
**Example**:
```vb
' Old: 100 calls × 20ms = 2 seconds
For i = 0 To pixels.Count - 1
    processed(i) = py_call(filter, "process_pixel", Array(pixels(i)))
Next

' New: 1 call × 20ms = 20ms
processed = py_call_batch(filter, "process_pixels", Array(pixels))
```
**Files**: `src/python_bridge/visual_gasic_py_facade.cpp`, `python_worker.py`  
**Acceptance**: 1000-pixel image filter <100ms; demo in `demo_python_bridge.vg`

#### 🔴 **Phase 6: Tier B — Embedded CPython (v6.5, Weeks 3–4)**
**Status**: Major milestone  
**Work**: Link CPython directly into libvisualgasic; direct C++ ↔ Python via `PyC_CallFunction`  
**Impact**: **50× baseline improvement** (~0.1ms per call)  
**Trade-offs**:
- ✅ **Pros**: Real-time processing; full numpy/scipy; no subprocess overhead
- ❌ **Cons**: +20MB binary; Python GIL blocks Godot frame (requires thread strategy); Windows requires Python dev libs; WASM unsupported

**Platform Support**:
| Platform | Status | Notes |
|----------|--------|-------|
| Linux x86_64 | ✅ Supported | CPython dev headers via apt/yum |
| Windows x86_64 | ✅ Supported | CPython dev from microsoft.com/python |
| macOS (Intel) | ✅ Supported | CPython via Homebrew or official installer |
| macOS (ARM64) | ✅ Supported | CPython universal binary |
| Android | 🔲 Not planned | Python overhead excessive for mobile |
| WASM | ❌ Not supported | CPython doesn't compile to WASM; recommend Phase 7 if needed |

**GIL Strategy**:
- Option A (Simple, conservative): Single-threaded interpreter; VG calls block until Python returns. **Safe but limited parallelism.**
- Option B (Advanced, deferred to v7.0): Per-worker subinterpreter (PEP 554); each background thread gets its own Python context without GIL. **Requires Python 3.12+.**
- **v6.5 ships with Option A**; Option B available as v7.0 stretch goal.

**Build**:
```bash
# Linux
scons platform=linux python=1 target=editor

# Windows (requires vcvarsall.bat environment)
scons platform=windows python=1 target=editor

# macOS universal
scons platform=macos python=1 target=editor arch=universal
```

**Project Setting**: `vg/python/backend` (dropdown: "auto" / "tier_a" / "tier_b")  
**Behavior**:
- "auto": Use Tier B if Python dev libs found, else fall back to Tier A
- "tier_a": Force out-of-process (for debugging or embedded deployments)
- "tier_b": Force embedded (fail at launch if Python unavailable)

**Files to Create**:
- `src/python_bridge/visual_gasic_py_embedded.h/cpp` — CPython bindings, GIL management
- `scripts/build_python_wheels.py` — Optional: pre-build numpy/scipy wheels for embedded distribution

**Acceptance**:
- numpy.dot(1000×1000) <1ms
- torch.tensor creation <0.1ms
- No GIL deadlocks during frame render
- Windows, Linux, macOS all ship working binaries

#### 🟢 **Phase 7: Zero-Copy Buffers (v6.5, Optional, post-Phase 6)**
**Status**: Advanced optimization  
**Work**: Pass `PackedByteArray` / `PackedFloat64Array` directly to worker without JSON encoding  
**Impact**: **Image/video pipelines <50ms** (was infeasible in v6.0)  
**API**:
```vb
Dim image As PackedByteArray = LoadPNG("photo.png")
py_process_buffer(cv2, "apply_filter", image)  ' modifies in-place
SavePNG("output.png", image)
```

**Implementation**:
- Shared memory buffer (mmap on Linux, CreateFileMapping on Windows)
- Worker reads/writes directly to buffer
- Zero serialization overhead

**Files**: `src/python_bridge/visual_gasic_py_facade.cpp`, `python_worker.py`  
**Acceptance**: 1080p image filter <50ms; test with OpenCV blur + edge detection

#### 🔵 **Phase 8: Worker Pool (v6.5+, If Needed)**
**Status**: Deferred; only implement if user demand warrants  
**Work**: 4 worker threads (configurable); round-robin request queue; separate module state per worker  
**Rationale**: Parallelizes `py_call_async()` calls; doesn't help single-call latency  
**Trade-off**: Complicates import caching, state sync, memory overhead  
**Decision Gate**: Implement only if Narcea or user feedback indicates async queue bottleneck

### Implementation Priority

| Phase | Timeline | Effort | Blocker? | Revenue Impact |
|-------|----------|--------|----------|-----------------|
| **3: Async Queue** | Oct 2026 (M5) | 1 week | ✅ YES | Medium (Narcea unblocked) |
| 4: Binary Protocol | Jan 2027 (v6.5 W1) | 2 weeks | No | Low (30% incremental) |
| 5: Batch API | Jan 2027 (v6.5 W2) | 1 week | No | **HIGH** (100× for data loops) |
| **6: Tier B Embedded** | Jan 2027 (v6.5 W3–4) | 3 weeks | No | **HUGE** (unlocks ML/vision) |
| 7: Zero-Copy | Jan 2027 (v6.5 W4+) | 2 weeks | No | **HUGE** (real-time processing) |
| 8: Worker Pool | v6.5+ | 2 weeks | No | Medium (parallelism expert use) |

### Success Metrics (v6.5 Exit Criteria)

✅ **Must Have**:
1. Phase 3 (Async) — Already shipped (M5)
2. Phase 6 (Tier B) — Tier A and Tier B both available; auto-detection works
3. numpy.dot(1000×1000) < 1ms (Tier B)
4. Linux, Windows, macOS all pass smoke tests

🟡 **Should Have**:
1. Phase 4 (Binary Protocol) — Optional but improves Tier A by 30%
2. Phase 5 (Batch API) — Enables efficient data-parallel loops
3. Documentation: "Python for Real-Time Image Processing" tutorial

🟢 **Nice to Have**:
1. Phase 7 (Zero-Copy) — Enables OpenCV workflows
2. Phase 8 (Worker Pool) — Parallelism for multi-module async
3. Community benchmarks and case studies

### Testing Strategy

**Benchmark Suite** (`tests/python_performance_benchmarks.vg`):
```vb
' Tier A (async JSON-RPC)
elapsed = Timer()
For i = 1 To 100
    result = py_call(math, "sqrt", Array(i))
Next
Assert elapsed < 2000  ' < 2s total

' Tier B (embedded CPython)
elapsed = Timer()
For i = 1 To 100
    result = py_call(math, "sqrt", Array(i))
Next
Assert elapsed < 100   ' < 100ms total

' Batch API
Dim args As New Collection(Of Array)
For i = 1 To 1000
    args.Add(Array(i))
Next
elapsed = Timer()
results = py_call_batch(math, "sqrt", args)
Assert elapsed < 50    ' < 50ms for 1000 calls
```

**Integration Tests**:
- numpy: basic array ops, dot product, linalg
- torch (optional): tensor creation, basic ops
- pandas (optional): DataFrame round-trip
- OpenCV (optional): image load/blur/save
- Windows, Linux, macOS CI runners

### Known Risks & Mitigations

| Risk | Mitigation |
|---|---|
| CPython build complexity (Windows) | Provide pre-built wheels + CI validation; document fallback to Tier A if build fails |
| GIL blocks Godot frame | v6.5 ships single-threaded (acceptable); v7.0 explores PEP 554 subinterpreters |
| +20MB binary size | Optional Tier B (project setting); users can choose Tier A if size critical |
| WASM incompatibility | Document limitation; recommend Phase 7 bridge + server if WASM needed |
| numpy/scipy wheel size | Pre-compile manylinux wheels; optional separate download if space concern |

### Post-v6.5 Future (Noted for Awareness)

**v7.0 Possibilities**:
- PEP 554 subinterpreters (true parallelism without GIL)
- WASM bridge (ship Python worker to CDN, call via HTTP/WebSocket)
- Rust interop layer (abi3 stable ABI)
- GPU compute (numba JIT, torch CUDA)

---

### Language Extensions — Namespaces & Generics (Parallel Track, Optional v6.5.1)

**Context**: While v6.5 focuses on Python performance, the type system can advance in parallel. Large VG codebases requested namespace organization and type-safe collections. Both are Godot-rejected features that VG can deliver.

#### **Namespaces — Project Organization**

**Problem it solves**: Large projects (asset plugins, game frameworks, enterprise tools) need to organize code without global class naming collisions.

**Implementation**:
```vb
Namespace Game.AI.Pathfinding
    Class Dijkstra
        Function FindPath(start As Node, goal As Node) As Array(Of Node)
            ' ...
        End Function
    End Class
End Namespace

' Usage:
Using Game.AI.Pathfinding
Dim solver As New Dijkstra()

' Or fully qualified:
Dim solver2 As New Game.AI.Pathfinding.Dijkstra()
```

**Effort**: 2–3 weeks
- Parser: recognize `Namespace X.Y.Z ... End Namespace` blocks
- Symbol table: qualify class names (e.g., `Game.AI.Pathfinding.Dijkstra`)
- Import system: `Using` statement for alias resolution
- Godot FFI: map VG namespaces to GDScript node paths

**Acceptance**:
- Multi-level namespaces parse correctly
- Class resolution works with qualified and unqualified names
- No global namespace pollution
- IntelliSense auto-complete includes namespace paths

---

#### **Generics — Type-Safe Collections**

**Problem it solves**: VG v3.7+ has strict typing; users need `Array(Of Enemy)` instead of `Array(Of Variant)` to avoid casting and catch type mismatches at compile time.

**Implementation**:
```vb
Dim enemies As Array(Of Enemy)
Dim bosses As Array(Of Boss)

For Each e In enemies
    e.TakeDamage(10)  ' Type-safe; no casting
Next

' Generic functions (future):
Function Clamp(Of T As Comparable)(value As T, min As T, max As T) As T
    If value < min Then Return min
    If value > max Then Return max
    Return value
End Function
```

**Effort**: 2–3 weeks
- Type system: `Array(Of T)`, `List(Of T)`, `Dictionary(Of K, V)` as generic containers
- Parser: recognize `Of` syntax (already partial in Godot 4)
- Compiler: emit type metadata; validate element assignment
- Evaluator: enforce type checks at runtime (fallback to Variant if mismatch)

**Acceptance**:
- Generic arrays parse and type-check
- Nested generics work: `Dictionary(Of String, Array(Of Enemy))`
- Error messages: "Cannot assign Enemy to Array(Of Player)"
- Stdlib updated: `Array(Of T)`, `List(Of T)`, `Dictionary(Of K, V)` shipped

**Note**: Generic functions (e.g., `Function Clamp(Of T)`) are v6.5.2 stretch goal.

---

## 🚀 v7.0 Roadmap — "Enterprise Expansion" (Post-v6.5, Q2–Q4 2027)

**Strategic Goal**: Reduce institutional friction for enterprise adoption by providing supply-chain security, database integration, and ecosystem bridges.

**High-Level Vision**: VG at v6.0 is linguistically complete and production-ready for Godot. v7.0 adds the plumbing that enterprises demand: provenance, standards compliance, and drop-in integration with existing corporate infrastructure.

### v7.0 Feature Tiers

#### **Tier 1 — Supply Chain Security (HIGH PRIORITY)**

**Why it matters**: Enterprise teams will not adopt a language whose package ecosystem relies on unverified sources. VG Package Manager (shipped in v4.3) is functional but lacks provenance guarantees.

| Feature | Scope | Estimate | Priority |
|---------|-------|----------|----------|
| **Code Signing for Packages** | 1. Add `gpg sign` layer to `vg pkg publish`. 2. CLI flag `--sign-key <path>` to publish. 3. Registry stores public key fingerprint per package. 4. `vg pkg install` verifies signature before extracting. 5. UI warning if signature missing. | 2–3 weeks | 🔴 HIGH |
| **Built-in Vulnerability Scanning** | 1. Native `vg audit` command that scans all `.vg` files for known anti-patterns (unbounded loops, unhandled file I/O, unsafe FFI, etc.). 2. Registry publishes CVE-style database of known issues in packages. 3. `vg pkg install --check-vulnerabilities` blocks install if known CVE found. 4. IDE: linter integration shows vulnerability warnings inline. | 3–4 weeks | 🔴 HIGH |
| **Supply Chain Attestation (SLSA)** | 1. Publish artifacts with SLSA L3 provenance (build env, commit hash, signer identity). 2. GitHub Actions CI: sign release artifacts with `sigstore`. 3. Registry stores attestation metadata. 4. Documentation: how to verify provenance client-side. | 4–5 weeks | 🟡 MEDIUM |
| **Private Enterprise Registries** | 1. Support `vg pkg registry add <name> <url>` for Artifactory / GitHub Packages / Nexus. 2. Credentials management (env var, token file, prompt). 3. Package resolution: search private registries first, fallback to public. 4. UI: manage registries in a "Package Sources" settings panel. | 2–3 weeks | 🟡 MEDIUM |

**Deliverable**: v7.0 launches with code signing + basic vulnerability database + private registry support. SLSA provenance is v7.1.

---

#### **Tier 2 — Enterprise Bridges (MEDIUM–HIGH PRIORITY)**

**Why it matters**: A language locked to a single game engine has limited appeal. But VG's FFI capabilities (shipped in v6.0) create a foundation for drop-in integrations with existing corporate stacks.

---

#### **Tier 3 — Type System Enhancements (MEDIUM PRIORITY, v7.1+)**

**Why it matters**: Modern languages use algebraic data types (Option, Result, Sum types) for compile-time error handling. VG's strict typing creates an opportunity to ship better error patterns than GDScript's informal returns.

| Feature | Scope | Estimate | Rationale |
|---------|-------|----------|----------|
| **Option/Result Monadic Types** | Stdlib `Option(Of T)` and `Result(Of T, E)` classes. `Result.Ok(x)` and `Result.Err(msg)` constructors. Compiler linting: warn if Result is created but never checked. Runtime: no null-dereference on `.Value` without `.IsOk` guard. Examples: `SafeDivide()`, `ParseInt()`, safe file I/O. | 3–4 weeks | Modern error handling without Try/Catch boilerplate; eliminates nil-checking bugs. |
| **Sum Types / Tagged Unions (Stretch)** | `Type Weapon = Sword Or Axe Or Spell`. Pattern matching: `Match weapon With Sword -> ..., Axe -> ..., End Match`. Full exhaustiveness checking. | 4–5 weeks | Eliminates error cases; makes state machines explicit. Rust-style safety. |
| **Pattern Matching (Stretch)** | Extend `Case` statements to pattern match on types, tuples, sum variants. Example: `Case (x, y) Where x > 10 -> ...`. | 3–4 weeks | Cleaner control flow than nested Ifs. Pairs with Sum Types. |

**Tier 3 Rationale**: These are long-term (v7.1, late 2027), shipped AFTER enterprise stability (Tier 1–2 solid). They unlock VG as a research/academic language and attract sophisticated game devs (roguelikes, simulations).

**Acceptance**:
- Option/Result: 20+ test cases covering Ok, Err, chaining (`.Map()`, `.FlatMap()`)
- Sum Types: 10+ test cases for variant construction, pattern matching exhaustiveness
- Pattern Matching: IDE support for pattern suggestions; linter warns on non-exhaustive matches

---

| Feature | Scope | Estimate | Priority |
|---------|-------|----------|----------|
| **ODBC enterprise polish** | **Base `VGOdbc` shipped v3.0** (`src/visual_gasic_odbc.cpp`). v7.0 scope: enterprise hardening — pooled connections, structured `Err` from SQLSTATE, audited query logging, DSN management UI, compliance docs. **Recordset + bound-grid over ODBC** tracked in [v6.1 ODBC plan](#odbc--database--phased-improvement-plan-v61) (not deferred to v7). | 2–3 weeks | 🟡 MEDIUM |
| **Java Interop (JNI Bridge)** | 1. C++ layer: `visual_gasic_jni.cpp` marshals VG Variants ↔ Java objects. 2. `JavaClass.New()` instantiation, method calls, property access. 3. VG callbacks as Java lambda expressions. 4. Tested on: Android (via existing JNI bindings in Godot), desktop JVM. 5. Example: call Android sensor APIs from VG. | 5–6 weeks | 🟡 MEDIUM |
| **.NET Interop (P/Invoke Alternative)** | 1. C++ marshaling layer for .NET types (int, string, arrays, delegates). 2. VG bindings for managed .NET libraries via DLL imports + type reflection. 3. Alternative: CppCLI wrapper for cleaner interop. 4. Tested on: Windows desktop, future .NET cross-platform (MAUI). 5. Example: call Prism MVVM framework from VG app logic. | 6–8 weeks | 🟡 MEDIUM |

**Deliverable**: v6.1–v6.2 ships **ODBC recordset + bound-control parity** (ex-VB6 LOB path). v7.0 adds enterprise ODBC polish. Java/JNI and .NET are v7.1.

---

#### **Tier 3 — Package Manager Enhancements (MEDIUM PRIORITY)**

| Feature | Scope | Estimate | Priority |
|---------|-------|----------|----------|
| **Dependency Resolution & Lock Files** | 1. Upgrade `vg.json` to support version constraints (`^1.0`, `~1.2.3`, `>=2.0`). 2. Implement semver conflict resolution. 3. Generate `vg.lock` on install (pins exact versions for reproducibility). 4. `vg pkg update` respects constraints in `vg.json` but updates `vg.lock`. | 2–3 weeks | 🟡 MEDIUM |
| **Workspaces & Multi-Module Projects** | 1. Extend `vg.json` to declare workspace members (e.g., "projects": ["core/", "tools/", "ui/"]). 2. `vg pkg` commands resolve paths within workspace. 3. Shared transitive dependencies resolved once. 4. Integrated with Code Navigator (cross-module symbol search). | 3–4 weeks | 🟡 MEDIUM |
| **Package Metadata & Discoverability** | 1. Registry returns rich metadata: tags, keywords, author/org, license, source URL, documentation link. 2. Registry search: `vg pkg search --keyword "database"` → matches ODBC wrapper, etc. 3. Web-based registry UI: browse, star, filter by category. 4. Telemetry (opt-in): track downloads, popular packages. | 2–3 weeks | 🟡 MEDIUM |

---

#### **Tier 4 — Ecosystem & Standards (LOW–MEDIUM PRIORITY)**

| Feature | Scope | Estimate | Priority |
|---------|-------|----------|----------|
| **SBOM (Software Bill of Materials) Export** | 1. `vg pkg sbom` generates SPDX-compliant BOM of all dependencies + versions + licenses. 2. Enterprise compliance: audit chains of dependencies, identify GPL/proprietary mixed licenses. | 1–2 weeks | 🟢 LOW |
| **License Compliance Checker** | 1. `vg pkg license-check` scans all dependencies, flags incompatible license combinations (e.g., GPL + proprietary). 2. Report: compatible/incompatible/requires-approval. 3. Config file: allowlist approved licenses per project. | 1 week | 🟢 LOW |

---

### v7.0 Secondary Features (Language & Runtime)

These ship v7.0 alongside enterprise bridges if time permits; otherwise v7.1.

| Feature | Description | Priority |
|---------|-------------|----------|
| **Headless Runtime Variant** | Optional lightweight VG runtime (no Godot windowing, no 3D). Single `.exe` / `.so` binary for CLI scripts, data processing, microservices. Ships as separate distribution. NOT a full "standalone language" — still compiled from VG source to bytecode, still targets Godot VM. Useful for: `vg run script.vg --headless`, server-side AI code generation, batch processing. | 🟡 MEDIUM |
| **Module Visibility Modifiers** | `Public Module` vs. `Internal Module` declarations; scopes exported symbols. Prevents accidental public API surface. Simplifies refactoring. | 🟢 LOW |
| **Async/Await Enhancements** | Fully specify cancellation tokens, timeout management, exception propagation across task boundaries. | 🟡 MEDIUM |

---

### v7.0 Timeline & Sequencing

| Phase | Milestone | Target | Deliverable |
|-------|-----------|--------|-------------|
| **Phase 1** | Package signing & audit | Feb 2027 | Code signing + vulnerability DB operational |
| **Phase 2** | ODBC enterprise polish | Mar 2027 | Pooling, audit logging, compliance docs (base `VGOdbc` + v6.1 recordset/grid parity already shipped) |
| **Phase 3** | Registry enhancements | Apr 2027 | Private registries + private artifact support |
| **Phase 4** | Java/JNI bridge | May 2027 | Android sensor access from VG demo |
| **Phase 5** | .NET interop | Jun 2027 | Prism MVVM example or similar |
| **Phase 6** | Polish & docs | Jul 2027 | Security guide, enterprise integration guide |
| **v7.0 release** | | **Jul 31 2027** | All enterprise bridges + supply chain security |

---

### v7.0 Marketing Narrative

**"VG is no longer just Godot's scripting language. It's a compliance-first systems language with enterprise ecosystem bridges."**

- **Headline**: "Supply-chain secure, type-safe, and runs in your database."
- **Tagline**: "AI-generated code that corporate security approves."
- **Key differentiators**:
  1. **Provenance**: Code-signed packages, vulnerability scanning, SBOM exports
  2. **Integration**: ODBC, Java/JNI, .NET interop — drop into existing stacks
  3. **Transparency**: GPL-3.0 open-source; no black boxes; full audit trail

**Target audiences**:
- CIOs evaluating "AI-native language for regulated workflows"
- DevOps teams building internal tools in VG
- Banks, insurance, healthcare firms adopting AI code generation

---

## 🔄 Comparison: v6.0 vs v7.0 Positioning

| Dimension | v6.0 "Stability" | v7.0 "Enterprise" |
|-----------|------------------|-------------------|
| **Primary Use Case** | Game development + Godot integrations | Regulated industries + microservices + multi-engine adoption |
| **Language** | Stable, feature-complete | Minor tweaks + interop depth |
| **Ecosystem** | Functional package manager, Godot-centric | Supply-chain secured, corporate-registry ready, multi-language bridges |
| **Marketing** | "AI-readable, auditable, type-safe" | "Compliance-first, provably auditable, enterprise-grade" |
| **Roadmap After v7.0** | v6.1 (Causal Chain visual panel), v6.2+ (performance tweaks, language parity) | v8.0 (multi-engine: Unity port) |

