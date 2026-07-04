# VisualGasic v5.3.0-Beta1 — Release Notes

**Released:** July 3, 2026  
**Status:** Public beta (Linux x86_64 + Windows x64)  
**Codename:** *Toolbox on the Canvas*

The IDE ergonomics release. Beta1 ships reworked **2D toolbar buttons** that
open floating Toolbox and Properties windows directly from the Godot 2D
editor, a new **plugin opt-in system** via Project Settings, the **Code
Navigator upgrade** with VB6-faithful Object/Procedure dropdowns, and a
batch of stability fixes.

> 🍏 **macOS:** still unchanged from 5.2 Beta1 — Linux + Windows only for 5.3.

---

## ✨ 2D Canvas Toolbar — Toolbox, Properties, Wire Event

Three new buttons in the Godot 2D editor toolbar provide direct access to
VG's form-building workflow without leaving the 2D viewport:

| Button | Action |
|--------|--------|
| **🖼 Add VG Control** | Opens the floating **Toolbox** window — pick a control type, then click the canvas to place it with VB6 naming (`Command1`, `Text1`, `Timer1`, …) |
| **📋 VG Properties** | Opens the floating **Properties** window — inspect and edit VB6-style properties (Caption, BackColor, Enabled, FontSize, Position, …) for the selected control |
| **⚡ Wire Event** | Creates the primary VB6 event stub (e.g. `Command1_Click`) in the associated `.vg` script and opens the code editor at that line |

All three are also available from the **right-click context menu** on the
2D canvas — alongside Godot's built-in "Add Node Here…" and "Instantiate
Scene Here…" entries.

![2D toolbar showing the Toolbox and Properties floating windows](docs/screenshots/v5.3.0-Beta1/2d_toolbar_toolbox_properties.png)

![Right-click context menu on the 2D canvas with VG actions](docs/screenshots/v5.3.0-Beta1/2d_toolbar_context_menu.png)

---

## ✨ Plugin Opt-In via Project Settings

VG sub-plugins are now **disabled by default** and must be explicitly
enabled per-project. This prevents unused plugins from loading, reduces
editor startup time, and avoids parse errors from optional plugins whose
dependencies aren't present.

Enable a plugin in **Project → Project Settings**:

```
vg/plugins/agck/enabled = true
vg/plugins/working_nodes/enabled = true
vg/plugins/ui_forms/enabled = true
vg/plugins/vector_graphics/enabled = true
vg/plugins/gdai/enabled = true
vg/plugins/vgmusic/enabled = true
```

The VG IDE layout also no longer auto-opens when a project loads. Switch
to it manually via the **"Visual Gasic IDE"** button in the top toolbar.

---

## ✨ Code Navigator Upgrade

The Code Navigator dropdowns above the code editor now match VB6 behavior:

- **Left dropdown (Object):** Lists `(General)` plus every control on the
  form (`Command1`, `Text1`, `Timer1`, etc.).
- **Right dropdown (Procedure):** When `(General)` is selected, shows only
  standalone `Sub`/`Function` procedures — no control event handlers.
  When a specific control is selected, shows that control's wired events
  (`Click`, `Change`, `Timer`).

This matches the classic VB6 IDE experience: select a control on the left
to see its events on the right; select `(General)` to see utility procedures.

---

## ✨ Plugins Dropdown on 2D Toolbar

The per-plugin toolbar buttons have been replaced with a single compact
**"Plugins ▾"** MenuButton on the 2D canvas toolbar. Selecting a plugin
from the dropdown activates it directly — no need to switch to the VG IDE
first.

---

## ✨ Live Plugin Reload via Project Settings

Enabling or disabling a plugin in **Project → Project Settings** now takes
effect immediately — no editor restart required. The plugin manager listens
to `ProjectSettings.settings_changed` and loads/unloads plugins on the fly.

---

## ✨ Code Completion in Godot's Native Script Editor

When editing `.vg` files in Godot's built-in Script editor (not just the
VG IDE), you now get full VB6-aware autocomplete:

- **Control names:** `TextBox1`, `Command1`, `Timer1` — sourced from the
  scene tree and form designer
- **Dot-completion:** Type `TextBox1.` to see VB6-style properties first
  (Text, Enabled, MaxLength, BackColor, etc.) followed by Godot's native
  ClassDB properties and methods below
- **`Me.`** shows all form controls plus form-level members (Caption,
  Width, Height, Show, Hide, etc.)
- **Keywords & variables:** VB6 keywords (Dim, Sub, If, etc.) and locally
  declared variables (`Dim x As String` → `x` appears in completions)
- **Godot's own completions preserved** — VG items are merged alongside
  Godot's native suggestions, not replacing them

---

## 🐛 Bug Fixes

| Fix | Details |
|-----|---------|
| `dict.Count` / `dict.Keys` / `dict.Items` without parens | VB6-style property access now works on dictionaries |
| `arr.Count` / `arr.Length` without parens | VB6-style property on all array types |
| `Join()` integer formatting | No spurious `.0` suffix on integer arrays |
| ByRef default parameters in recursive calls | No longer corrupts locals across recursive frames |
| `_on_vg_ctrl_chosen` dead reference | Removed leftover popup handler referencing deleted `_vg_ctrl_popup` |
| `project_properties.gd` constant assignment | `.pressed` is a signal in Godot 4.6 — fixed to `.button_pressed` |
| `gdai_local_provider.gd` signature mismatch | Return types now match parent class (`String`/`Array`/`Dictionary`) |
| Console error suppression | 4 recurring non-critical errors silenced |
| Code Navigator null class crash | Fixed null `get_class()` return in scene tree iteration |
| Bosca "Controller not declared" spam | Bosca directories now `.gdignore`d when vgmusic plugin is disabled |

---

## 📸 Screenshots

**Floating Toolbox and Properties windows** — opened from the 2D toolbar
buttons. The Toolbox lists all 33+ VB6 control types with icons. The
Properties window shows the selected control's VB6 properties in
categorized/alphabetical views.

![2D toolbar with floating Toolbox and Properties](docs/screenshots/v5.3.0-Beta1/2d_toolbar_toolbox_properties.png)

**Right-click context menu** — VG-specific actions ("Add VG Control…",
"VG Properties", "Wire Event…", "Open Prototype Scene") appear below
Godot's standard entries.

![Context menu with VG actions](docs/screenshots/v5.3.0-Beta1/2d_toolbar_context_menu.png)

---

## 📚 Documentation

| Document | What it covers |
|---|---|
| [IDE Tools Manual](docs/manual/ide_tools.md) | Complete IDE tools guide — now includes 2D toolbar buttons and plugin opt-in |
| [IDE Shortcuts](docs/manual/IDE_SHORTCUTS.md) | Keyboard shortcuts and features quick-reference — updated 2D toolbar section |
| [Language Reference](docs/VisualGasic_Language_Reference.md) | Complete A–Z reference — updated Code Navigator description |
| [Documentation Index](docs/DOCUMENTATION_INDEX.md) | Navigable index of all docs, guides, and tutorials |
| [WinForms Form Guide](docs/WINFORMS_FORM_GUIDE.md) | Forms, dialogs, and form lifecycle |
| [Getting Started — Installation](docs/getting_started/installation.md) | Install scripts, manual setup, `vg` CLI |

---

## 🧪 Test suite

| Suite | Result |
|---|---|
| `.vg` test suite | **91 files / 707 assertions / 707 passed / 0 failed / 0 errors** |
| GDScript test suites | **12 suites / 308 passed / 0 failed** |
| Corpus examples | **44/44 passing** |

Verify locally:

```bash
bash run_test_suite.sh
```

---

## 📦 Downloads

| Platform | One-click installer | Portable zip | Offline bundle (Godot bundled) |
|---|---|---|---|
| 🐧 Linux x86_64 | `VisualGasic-Installer-v5.3.0-Beta1-x86_64.AppImage` | `VisualGasic_v5.3.0-Beta1_linux_x86_64.zip` | `VisualGasic-Installer-Offline-v5.3.0-Beta1-linux-x86_64.zip` |
| 🪟 Windows x64 | `VisualGasic-Installer-v5.3.0-Beta1-x86_64.exe` | `VisualGasic_v5.3.0-Beta1_windows_x86_64.zip` | `VisualGasic-Installer-Offline-v5.3.0-Beta1-windows-x86_64.zip` |
| 🍏 macOS | *not available for 5.3 — open an issue* | — | — |

**Or install from the command line:**

```bash
# Linux / macOS
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.ps1 | iex
```

---

## 🎮 Demos

| Demo | Description |
|---|---|
| [Demoscene Intro](game_projects/demoscene_intro/) | 5-minute procedural demo — 10 effects, one `.vg` file, zero assets |
| [Pong](demos/) | Classic 2-player Pong in ~80 lines of VG |
| [Calculator](tutorials/calculator_form_designer.md) | WinForms-style calculator built with the Form Designer |
| [Your First 2D Game](docs/tutorials/your_first_2d_game.md) | Step-by-step platformer tutorial |

---

## Upgrading from v5.2.0-Beta4

1. Re-run the installer (`install.sh` / `install.ps1`) or extract the new zip.
2. In each project, go to **Project → Project Settings** and enable any
   plugins you use (`vg/plugins/agck/enabled`, etc.) — they are now off by default.
3. The VG IDE no longer auto-opens. Click **"Visual Gasic IDE"** in the top
   toolbar to switch to the VB6 layout.

No `.vg` code changes are required. All existing projects are forward-compatible.
