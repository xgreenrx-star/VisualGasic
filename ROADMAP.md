# Visual Gasic Development Roadmap

**Last Updated**: June 2025  
**Current Version**: 2.4.2 (Benchmark Fusion Fixes)

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

#### 10. Form Preview
**Status**: 📋 Planned  
**Priority**: Medium  
**Estimated Effort**: Medium

Run just the current form without launching the full game.

**Features**:
- "Preview Form" button in toolbar
- Opens form in popup window
- Fires Form_Load, Form_Shown events
- Interactive - buttons, inputs work
- Close returns to editor

**Implementation Notes**:
- Creates temporary scene with form
- Uses Godot's `EditorInterface.play_custom_scene()`
- Injects debug handler for Immediate Window support

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

---

## 🔧 Contributing

Want to help implement these features? See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Each feature has implementation notes that describe:
- Which files to modify
- Existing infrastructure to leverage
- Integration points with current systems

---

## 📝 Version History

- **v2.0.0** (Current) - Advanced Features Release
- **v1.5.0** - Immediate Window and debugging
- **v1.0.0** - Initial release with VB6 compatibility

---

*This roadmap is a living document. Priorities may shift based on community feedback and development resources.*
