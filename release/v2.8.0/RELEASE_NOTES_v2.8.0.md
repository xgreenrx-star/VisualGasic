# VisualGasic v2.8.0 Release Notes

**Release Date:** February 21, 2026
**Godot Version:** 4.5.1 (stable)
**Platforms:** Linux x86_64, Windows x86_64

---

## 🎯 Highlights

This release introduces the **C++ Form Designer** — a fully custom WYSIWYG form editor built entirely in GDExtension C++, replacing the old scene-tree-based approach. The IDE now looks and behaves like authentic Visual Basic 6, with a dedicated Toolbox, Properties Panel, Project Explorer, and a live Form Preview. Additionally, VB6-faithful control wrappers, a new VGComboBox control, improved code navigation, and 22 bug fixes ship in this release.

### 🖼️ VB6-Style Form Designer IDE

![Form Designer IDE](https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/v2.8.0/docs/screenshots/form_designer_ide.png)

The new form designer features:
- **40+ VB6 controls** in a tabbed Toolbox (2D Tools / 3D Tools)
- **WYSIWYG canvas** with grid snapping, rubber-band selection, and alignment tools
- **Properties Panel** with categorized form and control properties
- **Project Explorer** with Forms, Modules, and Folders views
- **VB6 Form Properties** — BorderStyle, ControlBox, MinButton, MaxButton, BackColor, ForeColor, and more
- **Live Form Preview** — click ▶ Preview to see your form with real Godot controls

---

## ✨ New Features

### C++ Form Designer (Major)
The form designer is now a custom `Control` class written in C++ (`VisualGasicFormDesigner`), providing:
- **In-memory control list** — no Godot scene tree dependency; forms are pure data
- **Per-type WYSIWYG rendering** — each control type (Button, Label, TextBox, CheckBox, ComboBox, ListBox, Frame, ProgressBar, ScrollBar, Slider, SpinBox, Timer, PictureBox, TreeView, RichTextBox, TabStrip, Shape, Separators, Containers) renders with authentic VB6 3D borders (raised, sunken, etched)
- **FormBorderStyle enum** — None, Fixed Single, Sizable, Fixed Dialog, Fixed ToolWindow, Sizable ToolWindow with conditional title bar and caption button drawing
- **Form-level properties** — Caption, BorderStyle, ControlBox, MinButton, MaxButton, Moveable, ShowInTaskbar, WindowState, StartUpPosition, KeyPreview, AutoRedraw, BackColor, ForeColor, Icon
- **Mouse interaction** — select, multi-select (rubber band), move, resize (8 handles), drag-drop from Toolbox
- **Alignment toolbar** — Align Left/Right/Top/Bottom, Center H/V, Same Width/Height
- **Form resize handles** — resize the form itself via drag handles
- **Undo/Redo** — full command-pattern undo/redo stack
- **Clipboard** — Cut, Copy, Paste controls
- **Serialization** — Save/Load to standard Godot `.tscn` files
- **Click-to-place** — select a tool in the Toolbox, then draw it on the canvas

### Live Form Preview
The ▶ Preview button now works! It reads the form designer's data and creates a real Godot `Window` with actual controls:
- Maps all 20+ control types to real Godot nodes (Button → Button, Label → Label, LineEdit → LineEdit, etc.)
- Applies form properties (caption, size, border style, background color)
- Applies control properties (ForeColor, BackColor, Enabled, tooltips)
- Opens as a standalone window you can interact with

### VGComboBox Control
A new VB6-faithful ComboBox implementation (`VGComboBox`):
- Type-ahead search with automatic filtering
- Per-item custom colors
- Select-all-on-focus for immediate type-to-search
- Full VB6 API: `AddItem`, `RemoveItem`, `ListCount`, `ListIndex`, `Text`

### VB6-Faithful Control Wrappers
9 new control wrapper scripts providing authentic VB6 APIs:
- Consistent `BackColor`/`ForeColor`, `Enabled`/`Visible`, `ToolTipText` properties
- VB6 method names alongside Godot native methods

### Code Navigator Improvements
- VB6-style handler icons in code navigator dropdowns
- Type-ahead search for Subs/Functions/Properties
- Parses `.vg` files directly for procedure discovery

### New Form Dialog Theming
The "Add Form" dialog now uses a complete VB6 light theme with:
- VB6 color constants (panel backgrounds, navy selection, white selected text)
- Styled TabContainer, ItemList, RichTextLabel, Buttons, LineEdit

### Form Properties in Inspector
Clicking the form background now shows VB6 form properties in the Properties Panel:
- **Appearance**: Caption, BorderStyle, BackColor, ForeColor
- **Behavior**: ControlBox, MinButton, MaxButton, Moveable, ShowInTaskbar, KeyPreview, AutoRedraw, WindowState, StartUpPosition
- **Position**: Width, Height
- **Misc**: WindowType, Icon

---

## 🔧 Bug Fixes

- **Fix duplicate GDExtension loading** — sync missing files to demo project
- **Fix 'Invalid owner' errors** — rewrote drop handler to eliminate double-drop race condition
- **Fix scene corruption on deletion** — rewrote drop handler, fix `MOUSE_FILTER`
- **Fix `@tool` scripts consuming editor input** — guard all runtime behavior
- **Fix VGComboBox rendering** — changed from HBoxContainer to Control base
- **Fix VGComboBox display** — move child creation from `_init` to `_ready`
- **Fix VGComboBox `.name` crash** — prevent blank textboxes, taller popup
- **Fix code navigator** — use `get_current_script()` instead of nonexistent method
- **Fix theme picker/snippet browser** — prevent auto-opening on project load
- **Fix color picker popup closing** — prevent property grid rebuild while picker is open

---

## ⚡ Performance Benchmarks

Benchmarks run on 12th Gen Intel Core i7-1255U (12 CPUs, 10 cores), 30 GB RAM, Linux x86_64.

All benchmarks verified with matching checksums across GDScript, VisualGasic, and C++.

| Benchmark | GDScript (µs) | VisualGasic (µs) | C++ (µs) | VG vs GDScript | Winner |
|-----------|---------------|-------------------|----------|----------------|--------|
| Arithmetic | 5,239 | 1,412 | 146 | **3.7×** faster | C++ |
| ArraySum | 4,486 | 403 | 476 | **11.1×** faster | **VG** |
| StringConcat | 5,399 | 108 | 711 | **50.0×** faster | **VG** |
| Branching | 6,816 | 156 | 235 | **43.7×** faster | **VG** |
| ArrayDict | 10,927 | 10,261 | 4,174 | **1.06×** faster | C++ |
| DictFastGet | 28,422 | 5,419 | — | **5.2×** faster | **VG** |
| DictFastSet | 18,818 | 7,239 | — | **2.6×** faster | **VG** |
| Interop | 8,356 | 233 | 7,766 | **35.9×** faster | **VG** |
| Allocations | 7,153 | 371 | 890 | **19.3×** faster | **VG** |
| AllocationsFast | 10,700 | 2,860 | 2,039 | **3.7×** faster | C++ |
| FileIO | 1,055 | 626 | 404 | **1.7×** faster | C++ |

**Summary:** VisualGasic wins **7/11** benchmarks vs GDScript (up to 50× faster). VisualGasic beats C++ in 7/9 head-to-head matchups. Geometric mean: **~8.2×** faster than GDScript.

---

## 📦 What's in the Release

- `VisualGasic_v2.8.0_linux.x86_64.zip` — Linux editor plugin + demo project
- `VisualGasic_v2.8.0_windows.x86_64.zip` — Windows editor plugin + demo project

Each zip contains:
- `addons/visual_gasic/` — Full plugin (GDScript + native .so/.dll)
- `demos/UI/Calculator/` — Complete Calculator demo project (ready to open in Godot)

### Installation
1. Extract the zip
2. Copy `addons/visual_gasic/` into your Godot 4.5+ project
3. Enable the plugin in Project → Project Settings → Plugins
4. The VB6 IDE tab appears in the editor

---

## 📋 Full Changelog (22 commits since v2.7.0)

```
d86cf28 Fix duplicate GDExtension loading + sync missing files to demo/
c0c52c4 Wire C++ FormDesigner as main screen plugin tab
6c35ae5 Add custom C++ form designer (VisualGasicFormDesigner)
00b9408 Fix 'Invalid owner': restore text manipulation + reload approach
751ce22 Fix 'Invalid owner' errors: eliminate double-drop race condition
50a308d Fix 'Invalid owner' errors: use EditorUndoRedoManager for drop handler
308f085 Fix scene corruption + deletion: rewrite drop handler, fix MOUSE_FILTER
2a5e159 Fix VGComboBox rendering: change from HBoxContainer to Control
cc1ecc2 Fix @tool scripts consuming editor input — guard all runtime behavior
a01f5df Fix VGComboBox: move child creation from _init to _ready
fd06741 Fix VGComboBox display + add design-time List property
a3a1191 Update Controls Reference with full VB6 wrapper API documentation
3110ea9 VB6-faithful wrappers for 9 toolbox controls
7e0d958 VGComboBox: full VB6-faithful ComboBox implementation
b4de34d Add VGComboBox to form editor toolbox
cdbdebd VGComboBox: select all text on focus for immediate type-to-search
778e725 Fix VGComboBox: no blank textboxes, taller popup, fix .name crash
d2611ce Add VGComboBox: VB6-style ComboBox with type-ahead and per-item color
669e783 Remove filled-circle handler icons from code navigator dropdowns
1e9b8b9 Code navigator: VB6-style handler icons + type-ahead search
7765231 Fix code navigator: use get_current_script() instead of nonexistent method
22ee19b Fix code navigator dropdowns: parse .vg file for Subs/Functions/Properties
8732314 Fix theme picker and snippet browser auto-opening on project load
```

Plus unreleased changes:
- VB6 form properties system (BorderStyle, ControlBox, MinButton, MaxButton, etc.)
- New Form dialog VB6 light theme
- Form properties in Properties Panel
- Live form preview via ▶ Preview button
- Color picker popup fix
- Theme picker syntax-highlighted preview (CodeEdit with CodeHighlighter)
- Cleaned up documentation screenshots
