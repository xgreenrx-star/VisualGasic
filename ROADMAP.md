# Visual Gasic Development Roadmap

**Last Updated**: July 9, 2026  
**Current Version**: 5.3.0-Beta1 (current public beta) — see [`CHANGELOG.md`](CHANGELOG.md) for the full set  
**Current Scope**: M0–M9 milestones (Jul 2026 – Jan 2027 stable release)  
**Next Cut**: v5.3.0 stable

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
- [ ] **Asset Library acceptance** — Submitted, awaiting Godot team review.

### ✅ High Priority — Flagship Features (ALL COMPLETE)

1. ~~**Live Animation for Custom Controls in Form Designer**~~ — *Skipped (static preview sufficient for current use cases)*

2. **✅ Multi-Module Project Compilation** *(Completed v4.3.0)*  
   Cross-file `Import` with project-wide symbol tables, circular import detection, and cross-file IntelliSense.

3. **✅ Visual Form Debugger** *(Completed v4.3.0)*  
   Controls Inspector panel with tree view, click-to-source, and debugger integration.

### ✅ Medium Priority — Ecosystem Features (ALL COMPLETE)

4. **✅ Database Controls (Data, DBGrid, DBCombo)** *(Completed v4.3.0)*  
   VGRecordset C++ class with ADODB.Recordset-compatible API, Data/DBGrid/DBCombo toolbox controls, 13 tests pass.

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
| **Fix boolean `Or` runtime/parser regression** | MUST FIX: some boolean conditions using inline `If ... Or (...) Then` can throw runtime `Err 35: Sub or Function not defined: Or` (observed in `infoview_companion.vg`). Patch parser/runtime operator handling so `Or` is always treated as boolean operator in condition expressions; add regression tests for single-line and multi-clause `If` conditions. | High |
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
| **M1 — Bug fixes** | July 31 2026 | All 4 critical bugs fixed and regression-tested: `Or` operator, error state corruption, phantom double-press, `.tscn` signal mismatch |
| **M2 — 20 proven examples** | August 15 2026 | Every example in the repo compiles and runs correctly. Unproven files deleted. |
| **M3 — Code Navigator upgrade** | August 31 2026 | Object dropdown surfaces all scripts on all scene nodes; GDScript `func` definitions in Event dropdown; clicking navigates to correct line |
| **M4 — UI Forms experimental** | September 30 2026 | Control picker popup → ghost placement → single-click place → double-click wire → `Sub Button1_Click()` in `Form1.vg`. Save/reopen preserves everything. Gated behind `vg/enable_experimental_plugins`. |
| **M5 — Narcea AI pair** | October 15 2026 | "Describe a form in English → Narcea generates working VG code" demo runs end-to-end on Claude and local Ollama |
| **M6 — Causal Chain Visualization (teaser)** | October 31 2026 | Static AST walk generates a readable call-chain report for any VG form. Even a text-mode output qualifies. Visual panel is v6.1+. |
| **M7 — Python Library Integration (Tier A)** | November 15 2026 | `PyImport("numpy")` / `PyCallAsync` / `Await` works end-to-end on Linux + Windows desktop. Out-of-process worker via existing IPC/process/async stack. Native wheels (numpy, opencv) load without engine changes. Clean error on missing Python. |
| **M8 — Language parity + `Let` keyword** | November 22 2026 | (1) Corpus tests for `Try`/`Catch`/`Finally`, `Lambda`, `?.` null-conditional — confirms bytecode compiler handles them, no silent AST fallback. (2) `AndAlso`/`OrElse` CHANGELOG entry added. (3) `Let x As Type` block-scoped variable: fresh slot per block entry via `OP_PUSH_SCOPE`/`OP_POP_SCOPE`; `Dim` retains VB6 sub-scope hoisting. (4) C++ library interop: supported `Declare` / `DllImport` path on Linux + Windows desktop via existing `visual_gasic_ffi.cpp`; packaging docs; clean failure on unsupported platforms. (5) Optional named arguments at call sites (`Call Foo(x:=10, y:=20)`) — VB6-compatible `:=` syntax; positional calls remain valid; parser activates named path only when `:=` present; reduces AI parameter-order errors. |
| **M9 — Release readiness** | November 28 2026 | (1) Godot Asset Library package prepared and submitted. (2) Installer smoke-tested on clean Linux + Windows VMs — first-run works without manual steps. (3) 50+ corpus examples pass. (4) README and CHANGELOG reflect v6.0 features accurately. |
| **🎉 Stable v6.0 release** | January 1 2027 | All M1–M9 complete. Installer works first try. Asset Library submission accepted or in review. Public announcement. |

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
| **Language reference + 5 tutorials** | When AI crashes, humans read docs again. This is the moment docs matter. |

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

---

## 🌌 v6.0 Roadmap — needs design work

Items below are real but require non-trivial design / scoping. **Do not** start any of them until v5.2 is cut.

**📌 IDE Focus**: All v6.0 work focuses on **Godot IDE integration only** (Toolbox, Properties, Code Navigator, Narcea AI Pair, autocomplete, dot-completion). The **VG standalone IDE shell** (separate editor window, form designer as primary surface) is **mothballed behind `vg/enable_experimental_plugins`** and will not ship as core until v7.0+ at earliest. Users should build games using Godot's native editor with VG script overlays.

| Feature | Description | Priority | Rationale |
|---------|-------------|----------|-----------|
| **`Let` keyword — block-scoped variables** | Add `Let x As Type` as a block-scoped variable declaration (C++/JS semantics: variable is re-initialized on each block entry and destroyed on exit). `Dim` retains VB6 sub-scope hoisting behavior. This keeps VB6 compatibility while giving C++/modern programmers an intuitive opt-in for loop-local variables. `Let` is already obsolete in VB6 (it was just an optional prefix for assignment: `Let x = 5`), so repurposing it is safe and zero-breaking. AI code generators trained on JavaScript will naturally reach for `let`-style semantics inside loops — this makes their output correct without restructuring. IDE IntelliSense should suggest `Let` when `Dim` is typed inside a block. Runtime: requires a scope stack in the bytecode VM (push/pop on block enter/exit). Implementation notes: (1) parser: if keyword is `LET` followed by an identifier and `AS`, treat as block-scoped `DimStatement` with a `is_block_scoped` flag; (2) compiler: don't hoist to sub-level slots — allocate a fresh slot on each block entry via a new `OP_PUSH_SCOPE`/`OP_POP_SCOPE` pair; (3) VM: small scope stack alongside `locals[]`. See also: conversation thread Jun 26, 2026. | High |
| **Full Python library support** | Include full Python library support in v6.0 so VG projects can use Python ecosystems through a supported integration path. Start with a stable bridge/service architecture and document export/runtime limits clearly. Detailed implementation plan: [`/memories/repo/v6.0_blockers.md`](/memories/repo/v6.0_blockers.md), section "v6.0 plan — Full Python library support". | High |
| **C++ library interoperability support** | Add a supported C++ interop path (native bridge/FFI + packaging docs) so VG projects can call external C++ libraries without custom engine forks. Ship desktop-first and clearly document mobile/web constraints. | High |
| **Browser embed stack** | Add a browser surface to VG for InfoView-style workflows and web-powered tools. The goal is a VG-owned browser/window experience that feels integrated into the app and supports the project's browser-driven workflows. | High |
| **Java library support (v6.x, Android-first)** | Add Java interop for Android plugins and Java ecosystems, with import tooling and runtime bridge documentation. Stage this for v6.x after Python/C++ foundations are stable. | Medium |
| **AGCK advanced behaviors / user templates** | Promote hard-coded actor magic numbers (`rotation_speed`, `snap_angle_deg`, `jump_force`, `jump_velocity`, etc.) into actor-data fields, surface them in an "Advanced" card in the Actor editor, add Save/Load Template buttons that round-trip user-authored game templates as JSON in `user://agck_templates/`. Long-term: extract behaviors into external `.vg` files with typed param schemas. Plan parked in [`/memories/repo/visualgasic_todo.md`](/memories/repo/visualgasic_todo.md). | High |
| **Narcea Full Agent Parity** | Extend Narcea beyond Tier 3 (tool dispatcher + run loop) with full IDE access: debug integration (set breakpoints, step through code, inspect variables), sandboxed terminal (whitelist-only commands: build/test/git), git operations (status, diff, commit, branch), asset pipeline (view images, import assets, slice spritesheets), project management (settings, autoloads, plugins), advanced refactoring (rename across files, extract/inline subs). 8 phases, 8-10 weeks total. Security: approval UI for all mutations, no network access, project-directory jail, budget caps. Target: Narcea can complete "make a demoscene demo" end-to-end (code + debug + iterate) with ≥60% success on local 7B models, ≥90% on Claude. Full plan in [`/memories/repo/visualgasic_todo.md`](/memories/repo/visualgasic_todo.md) Tier 3+ section. Phased rollout: v5.4 (debug), v5.5 (terminal+diagnostics), v6.0 (git+assets+project), v6.1+ (refactoring). | High |
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

## � Milestone Schedule — v5.1+

| Milestone | Focus | Due | Status |
|-----------|-------|-----|--------|
| **M1** | 4 critical bugs (ByRef recursion, Join float format, Dict properties, chained calls) | Jul 31 | ✅ **DONE** (Jun 29) |
| **M2** | 44 corpus examples pass (all domains: basics, control flow, strings, arrays, dicts, classes, I/O, math, state machines, Godot) | Aug 15 | ✅ **DONE** (Jun 30) |
| **M3** | Code Navigator upgrade (#7): multi-file symbol search, definition/reference indexing, call hierarchy | Aug 31 | ✅ **DONE** (Jul 1) |
| **M4** | UI Forms experimental (#8–#12): VB6 visual form designer, control picker popup, ghost placement, signal wiring, two-layer events | Sep 30 | ✅ **DONE** (Jul 1) |
| **M5** | Narcea AI pair (#13): pair-programming mode, provider routing, system prompt templates | Oct 15 | — |
| **M6** | Causal Chain text-mode (#14): new AST evaluator path, narrative code generation, explain-before-compute | Oct 31 | — |
| **M7** | Python Library Integration: `PyImport` / `PyCallAsync` / `Await` via out-of-process worker. numpy, opencv, torch usable from VG scripts. | Nov 15 | — |
| **M8** | Language parity (Try/Catch/Lambda/`?.` corpus tests), `Let` block-scoped vars, C++ library interop via `Declare`/`DllImport`, optional named arguments (`:=`) | Nov 22 | — |
| **M9** | Release readiness: Asset Library submission, installer smoke test (Linux + Windows), 50+ corpus, docs current | Nov 28 | — |
| **v6.0** | Stable release | Jan 1 2027 | — |

---

## �🚀 v7.0 Long-term — explicitly out of scope for 5.x / 6.x

| Feature | Description | Priority | Rationale |
|---------|-------------|----------|-----------|
| **VG3D — 3D Game Kit** | Full 3D game creation kit plugin. Voxel/grid-based level editor, built-in voxel model editor (MagicaVoxel-style), pre-built camera modes (FPS / TPS / top-down), CSG/primitive environments, actor system ported from AGCK, procedural 3D actor models, animation, build pipeline emitting Godot 3D scenes. | High | Expands VG beyond 2D; complements existing canvas workflows; attracts 3D game developers. |
| **VGVR — VR Game Kit** | VR mode add-on for VG3D. OpenXR integration, hand/controller input mapping, VR camera rig, teleport / smooth locomotion presets. Requires VG3D as foundation. | Medium | Emerging VR market; works with existing VG3D actor/animation/input systems. |
| **Python Integration (v6.0 continuation)** | Consolidate `PyImport`, `PyCallAsync`, async/await flow. Expand ecosystem: numpy, opencv, torch, pandas, scikit-learn. Error handling, type coercion, memory management. FFI documentation and best practices. Out-of-process worker stability hardening. | High | Unlocks AI/ML/data science workflows; enables procedural generation (numpy), image processing (opencv), physics sim (torch). |
| **C++ Interop (v6.0 continuation)** | Two-way binding: VG classes callable from C++, C++ classes callable from VG. Callback injection (VG lambdas → C++ std::function). Native bridge packaging, multiplatform support (desktop + mobile). Documentation and example projects. | High | Custom Godot node authoring in VG; hooking into physics/rendering pipelines; performance-critical paths can stay native. |
| **Vextrex OS / narcean.com Website Launch** | **Genuinely great viral concept, deferred to post-v6.0 stable.** Complete narcean.com with fully interactive Vextrex OS — a GEOS-inspired vector desktop environment built entirely in VG, playable in browser. **Desktop Shell**: Icon grid, taskbar, draggable vector windows with minimize/close, app launcher. **Built-in Apps**: VexWrite (text editor), VexPaint (vector drawing tool with Bezier curves), Terminal (BASIC-style prompt), Vector Storm (embedded playable), DEMOscen Gallery (showcase runner), Downloads Manager (triggers real VG installer downloads), About VG (interactive tutorial). **Visual Aesthetic**: Monochrome phosphor green (CRT shader with scan lines, bloom/glow), pure vector rendering via VGVectorCanvas2D, fake 1987 boot sequence ("Vextrex OS v1.2 - Discovered Archive"). **Website Integration**: narcean.com gets "⚡ The Visual Gasic Initiative" prominent link → launches fullscreen Vextrex OS web player (Escape or "Shut Down" to exit). **Repo Strategy**: Separate `narcean/vextrex-os` repo for clean deployment, mirrored from VG development. **Narrative**: Present as "lost 1980s vector workstation" with retro manual PDF, easter eggs, hidden demos. **Estimate**: ~7-8 weeks (3wk core OS, 2wk apps, 1wk demo integration, website, 1wk polish). **Impact**: Demonstrates VG's web export, UI toolkit, vector rendering, and game engine capabilities in one self-documenting interactive experience. Shareable, viral-ready, establishes VG as serious platform. | Medium | Marketing differentiation; complements v6.0 stable release messaging; does not block core feature ship. |
| **Java/Android Integration** | Java interop for Android plugins and ecosystems. Import tooling, runtime bridge, Android-first staging. | Medium | Mobile expansion; Android ecosystem access; pairs with VG Mobile Kit work. |
| **Causal Chain Debugging (text-mode narrative)** | Structured debugging mode: trace execution flow as readable "causal chain" narrative—what happened, why, in what order. Pairs with Narcea AI pair (M5). AI-assisted test case generation, performance bottleneck identification. | Medium | Enables AI-assisted debugging; improves code comprehension; pairs with GBA/PS1 emulator and complex systems work. |
| **Asset Streaming & Dynamic Loading** | Lazy-load resources (ROMs, sprite sheets, audio, voxel models). Per-asset memory budgets. Preload hints, streaming queues, asset lifecycle management. | Medium | Supports large game projects and mobile optimization; essential for emulator ROM loading and procedural asset generation from v7.0 3D kit. |

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
