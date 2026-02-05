# Changelog

All notable changes to Visual Gasic will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
