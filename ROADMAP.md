# Visual Gasic Development Roadmap

**Last Updated**: February 3, 2026  
**Current Version**: 2.0.0 (Advanced Features Release)

This document outlines the planned improvements and features for Visual Gasic. Items are prioritized by impact and development effort.

---

## 🎯 Upcoming Features

### High Priority - Enhanced Developer Experience

#### 1. Watch Window
**Status**: 📋 Planned  
**Priority**: High  
**Estimated Effort**: Medium

A dedicated panel to monitor variable values during debugging, complementing the existing Immediate Window.

**Features**:
- Add expressions to watch list
- Auto-update values when paused at breakpoint
- Support for complex expressions (e.g., `player.health`, `items.Count`)
- Color-coded value changes (green=unchanged, yellow=modified)
- Persist watch list between sessions
- Integration with existing debugger infrastructure

**Implementation Notes**:
- Extends `vg_debugger_plugin.gd`
- Uses existing `:eval` command infrastructure
- Adds new bottom panel tab "Watch"

---

#### 2. Snap-to-Grid & Alignment Tools
**Status**: 📋 Planned  
**Priority**: High  
**Estimated Effort**: Medium

Form designer enhancements for precise control placement, matching VB6's visual design experience.

**Features**:
- **Grid Snapping**: Configurable grid size (8px, 16px, custom)
- **Alignment Toolbar**:
  - Align Left / Center / Right
  - Align Top / Middle / Bottom
  - Distribute Horizontally / Vertically
  - Make Same Width / Height / Both
- **Smart Guides**: Visual guides when controls align
- **Keyboard nudging**: Arrow keys move by 1px, Shift+Arrow by grid size

**Implementation Notes**:
- Extends `form_editor_helper.gd`
- Adds overlay canvas for grid display
- Integrates with Godot's editor selection system

---

#### 3. IntelliSense / Autocomplete
**Status**: 📋 Planned  
**Priority**: High  
**Estimated Effort**: High

Code completion for VB6 keywords, control names, and built-in functions.

**Features**:
- **VB6 Keywords**: `Dim`, `Sub`, `Function`, `If`, `For`, `Select Case`, etc.
- **Form Control Names**: Typing `btn` suggests `btnOK`, `btnCancel`, etc.
- **Built-in Functions**: All functions from `BUILTIN_FUNCTIONS_REFERENCE.md`
- **Method Signatures**: Parameter hints on function calls
- **Property Completion**: Object properties and methods
- **Snippet Expansion**: Common patterns like `For i = 1 To n`

**Implementation Notes**:
- Extends CodeEdit completion provider
- Parses current form scene for control names
- Integrates with existing LSP infrastructure

---

#### 4. Breakpoint Conditions
**Status**: 📋 Planned  
**Priority**: High  
**Estimated Effort**: Medium

Enhanced breakpoints with conditional expressions.

**Features**:
- Right-click breakpoint gutter to add condition
- Condition expressions (e.g., `counter > 10`, `player.health < 50`)
- Hit count conditions (break after N hits)
- Log message without breaking (tracepoints)
- Breakpoint groups for enable/disable sets

**Implementation Notes**:
- Extends `VisualGasicDebugger` class
- Stores conditions in breakpoint map
- Evaluates conditions using existing expression evaluator

---

#### 5. Call Stack Panel
**Status**: 📋 Planned  
**Priority**: High  
**Estimated Effort**: Low

Visual call stack display during debugging.

**Features**:
- Show full call stack when paused
- Click to navigate to any stack frame
- Display local variables for selected frame
- Show file:line for each frame
- Collapse/expand nested calls

**Implementation Notes**:
- Uses existing `_debug_get_stack_*` methods
- Adds panel to debugger dock
- Already have infrastructure from Phase 2 debugging work

---

### Medium Priority - Productivity Features

#### 6. Recent Projects List
**Status**: 📋 Planned  
**Priority**: Medium  
**Estimated Effort**: Low

Quick access to recently opened .vbp/.vg projects.

**Features**:
- "Recent Projects" submenu in Tools menu
- Stores last 10 projects
- Pin favorite projects
- Clear history option
- Tooltip shows full path

**Implementation Notes**:
- Uses `EditorSettings` for persistence
- Adds menu items dynamically

---

#### 7. Code Formatter / Beautifier
**Status**: 📋 Planned  
**Priority**: Medium  
**Estimated Effort**: Medium

Automatic code formatting for .vg files in VB6 style.

**Features**:
- Auto-indent based on blocks (Sub/End Sub, If/End If, etc.)
- Consistent spacing around operators
- Keyword capitalization (configurable)
- Blank line normalization
- Format on save option
- Format selection only

**Implementation Notes**:
- New `vg_formatter.gd` script
- Integrates with script editor
- Respects `.vgformat` config file if present

---

#### 8. Find All References
**Status**: 📋 Planned  
**Priority**: Medium  
**Estimated Effort**: Medium

Show all usages of a variable, Sub, or Function.

**Features**:
- Ctrl+Shift+F on identifier
- Results panel with file:line listings
- Click to navigate
- Filter by type (read/write/call)
- Search across all .vg files

**Implementation Notes**:
- Extends rename refactoring infrastructure
- Uses existing `_find_all_vg_files()` method

---

#### 9. Go to Definition
**Status**: 📋 Planned  
**Priority**: Medium  
**Estimated Effort**: Medium

Navigate to Sub/Function/Variable declarations.

**Features**:
- Ctrl+Click or F12 on identifier
- Jump to definition in same or different file
- Peek Definition (inline preview without leaving current file)
- Back navigation after jumping

**Implementation Notes**:
- Parses .vg files for declarations
- Caches symbol locations for performance
- Integrates with existing LSP framework

---

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

### Nice-to-Have - Future Enhancements

#### 11. Linting / Warnings
**Status**: 📋 Planned  
**Priority**: Low  
**Estimated Effort**: Medium

Static analysis for code quality.

**Features**:
- Unused variable detection
- Unreachable code warnings
- Undefined variable usage
- Deprecated syntax warnings
- Severity levels (error, warning, info)
- Inline squiggles in editor

---

#### 12. Snippet Manager
**Status**: 📋 Planned  
**Priority**: Low  
**Estimated Effort**: Low

User-defined code snippets with placeholders.

**Features**:
- Create custom snippets
- Tabstop placeholders
- Import/export snippets
- Snippet categories
- Built-in VB6 snippets (For loop, Select Case, etc.)

---

#### 13. Theme Support
**Status**: 📋 Planned  
**Priority**: Low  
**Estimated Effort**: Low

Visual theme options for the VB6 experience.

**Features**:
- Classic VB6 gray theme
- Modern dark theme
- Light theme
- Custom color schemes
- Form designer themes

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
