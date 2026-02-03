# Visual Gasic Development Roadmap

**Last Updated**: February 3, 2026  
**Current Version**: 2.1.0 (Debugging & IntelliSense Release)

This document outlines the planned improvements and features for Visual Gasic. Items are prioritized by impact and development effort.

---

## ✅ Recently Completed Features

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
**Status**: ✅ Completed  
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

**Files**:
- `form_preview_toolbar.gd` - Toolbar with preview buttons
- F5 keyboard shortcut for quick preview

---

### Nice-to-Have - Future Enhancements

#### 11. Linting / Warnings
**Status**: ✅ Completed  
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

**Files**:
- `vg_linter.gd` - VGLinter class with 10 issue codes
- LintIssue class with severity, code, message, location
- Check functions for various issues

---

#### 12. Snippet Manager
**Status**: ✅ Completed  
**Priority**: Low  
**Estimated Effort**: Low

User-defined code snippets with placeholders.

**Features**:
- Create custom snippets
- Tabstop placeholders
- Import/export snippets
- Snippet categories
- Built-in VB6 snippets (For loop, Select Case, etc.)

**Files**:
- `vg_snippet_manager.gd` - VGSnippetManager class
- 40+ built-in snippets across 8 categories
- User snippet persistence in `vg_snippets.cfg`

---

#### 13. Theme Support
**Status**: ✅ Completed  
**Priority**: Low  
**Estimated Effort**: Low

Visual theme options for the VB6 experience.

**Features**:
- Classic VB6 gray theme
- Modern dark theme
- Light theme
- Custom color schemes
- Form designer themes

**Files**:
- `vg_theme_manager.gd` - VGThemeManager class
- 5 built-in themes (VB6 Classic, Modern Dark, Modern Light, High Contrast, Solarized)
- Custom theme save/load/persistence
- CSS export for documentation

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
