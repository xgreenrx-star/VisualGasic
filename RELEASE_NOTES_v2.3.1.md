# VisualGasic v2.3.1 — Form Designer Button & Layout Overhaul

**Release Date:** February 11, 2026  
**Godot Compatibility:** 4.3+ (built with 4.5.1 stable)  
**Platforms:** Linux x86_64, Windows x86_64

---

## Summary

v2.3.1 is a focused IDE quality-of-life release that overhauls the VB6 Form Designer mode activation, compacts all VG toolbars to fix dock resizing issues, and rewrites the layout manager for clean Godot/VB6 mode switching.

**Key highlight:** A new **"Form Designer"** button appears in the main editor toolbar alongside 2D / 3D / Script / AssetLib — click it to activate VB6 mode with a single click, click any other screen button to return to standard Godot.

---

## What's New

### 🎨 Form Designer Button in Main Toolbar
- **"Form Designer" button** placed next to AssetLib in the main screen bar (2D | 3D | Script | AssetLib | **Form Designer**)
- Gold-tinted text with Window icon for visual distinction
- Font and size copied from sibling buttons for pixel-perfect alignment
- **Click to activate** → docks VG panels (Toolbox, Properties, Project Explorer) + adds VG toolbars to 2D canvas
- **Click 2D/3D/Script/AssetLib** → auto-deactivates Form Designer and undocks all VG panels/toolbars
- **Click Form Designer again** → deactivates (toggles off), returns to standard 2D mode
- Proper pressed/unpressed visual state synced with sibling main screen buttons
- Also available via **Project > Tools > Toggle VG IDE Layout** menu item

### 🔧 Layout Manager Rewrite
- **Complete rewrite** of `vb6_layout_manager.gd` — now extends `Node` instead of `HBoxContainer`
- **Dynamic dock management:** panels are `add_child()` → `add_control_to_dock()` on activate, `remove_control_from_docks()` → `add_child()` on deactivate
- **Dynamic toolbar management:** VG toolbars (Alignment, Preview, Color Palette) added/removed from `CONTAINER_CANVAS_EDITOR_MENU` on mode toggle instead of always being present
- **`switching_internally` guard flag** prevents `main_screen_changed` signal from causing re-entrant deactivation when VB6 mode switches to 2D internally
- **Removed `set_main_screen_editor("2D")` from deactivate** — user is already switching screens, so no need to fight the editor
- **Layout persistence:** VB6 mode state saved/restored across sessions via `ConfigFile` and `ProjectSettings`

### 📐 Compact Toolbars (Fixed Dock Resizing)
The combined minimum width of all three VG toolbars was ~1200px, which plus Godot's native 2D toolbar (~500px) exceeded typical screen widths and prevented dock panels from being resized. All three toolbars have been dramatically compacted:

**Alignment Toolbar** (~220px, was ~500px):
- Removed text labels ("Grid:", "Align:", "Distribute:", "Size:")
- Icon-only buttons with new `_add_icon_button()` helper (24px minimum)
- Compact 60px SpinBox for grid size

**Form Preview Toolbar** (~200px, was ~400px):
- Shortened button text: "▶ Preview", "Preview+Debug", "Build", "▶ Run Project"
- Removed emoji prefixes (🐛, 🔨) and extra separators

**Color Palette** (~190px, was ~300px):
- 10×10px swatches (was 14×10)
- Zero horizontal/vertical grid separation
- Smaller preview (28px, was 36px)
- Removed separators between sections

**Total VG toolbar width: ~610px** (was ~1200px) — docks are now fully resizable.

### 🏠 Dynamic Panel Docking
- VG panels (Toolbox, Properties, Project Explorer) are **no longer always in docks**
- In Godot mode: panels are hidden children of the plugin node (zero dock footprint)
- In VB6 mode: panels are dynamically added to appropriate dock slots
- Fixed the root cause of dock squishing: `visible = false` on a control inside a dock TabContainer still reserves layout space — now panels are fully removed from docks when not in VB6 mode
- Reduced `custom_minimum_size` on Properties (150px, was 180px) and Project Explorer (150px, was 180px) for better fit on smaller screens

### 🐛 Bug Fixes
- **C++ editor plugin:** Fixed `_exit_tree` to use `remove_control_from_bottom_panel()` instead of `remove_control_from_docks()` for the toolbox (was causing warnings)
- **C++ toolbox:** Reduced `custom_minimum_size` comment cleanup (100×200px)
- **Cleanup safety:** `_exit_tree` now correctly handles panels/toolbars in any state (docked or undocked) without crashes
- **Menu cleanup:** `remove_tool_menu_item` calls added for "Toggle VG IDE Layout" and "New Module..." on plugin exit

---

## Files Changed

### Core Plugin (GDScript)
| File | Changes |
|------|---------|
| `visual_gasic_plugin.gd` | +250 lines: Form Designer button, dock/toolbar management, main_screen_changed handler, style/font matching |
| `vb6_layout_manager.gd` | Complete rewrite: Node-based, dynamic dock/toolbar toggle, switching_internally guard |
| `alignment_toolbar.gd` | Compact icon-only buttons, removed text labels |
| `form_preview_toolbar.gd` | Shortened text, removed emoji, removed separators |
| `color_palette_toolbar.gd` | Smaller swatches, zero grid spacing, compact preview |
| `simple_inspector.gd` | Reduced custom_minimum_size (150px) |
| `vb6_project_explorer.gd` | Reduced custom_minimum_size (150px) |
| `vb6_main_screen.gd` | New file: VB6 main screen panel (form/module listing, quick actions) |

### C++ Source
| File | Changes |
|------|---------|
| `visual_gasic_editor_plugin.cpp` | Fix: `remove_control_from_bottom_panel()` |
| `visual_gasic_toolbox.cpp` | Minor: comment cleanup |

---

## Upgrade Notes

- **No breaking changes.** All existing `.vg` scripts, forms, and project settings work unchanged.
- **Delete `editor_layout.cfg`** in your project's `.godot/editor/` folder after updating to reset dock positions (recommended for clean slate).
- The old "Visual Gasic IDE" toggle button (in the right-side toolbar area) has been replaced by the new "Form Designer" button in the main screen bar.
- VB6 mode state is still saved via `ProjectSettings` — if you were in VB6 mode before updating, it will restore on next editor launch.

---

## Test Results

| Metric | Count |
|--------|-------|
| **Total checklist items** | 264 |
| **Passed ✅** | 251 |
| **Not implemented** | 13 |
| **Failed** | 0 |
| **Pass rate (of implemented)** | **100%** |
| **Overall completion** | **95.1%** |

All 243+ automated tests continue to pass with 0 failures.

---

## Build Info

```
Godot: 4.5.1 stable
godot-cpp: 4.5.1
Compiler: GCC (Linux), MinGW-w64 (Windows cross-compile)
Build: scons platform=linux/windows target=template_debug/template_release -j4
```
