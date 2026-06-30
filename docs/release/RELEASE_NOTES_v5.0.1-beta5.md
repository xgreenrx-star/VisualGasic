# VisualGasic v5.0.1 Beta 5 — Release Notes

**Release Date**: April 22, 2026
**Tag**: `v5.0.1-beta5`
**Status**: 🟡 **BETA — NOT FOR PRODUCTION USE**

---

> ## ⚠️ BETA CAUTION
>
> **This is a Beta 5 pre-release.** It is provided for **evaluation and testing purposes only.**
>
> - 🚧 **Experimental** — Fast-moving changes; expect rough edges.
> - 💾 **Back up your projects** before opening them with this version.
> - 🖥️ Windows binaries are cross-compiled via MinGW and have not been verified on native hardware.
> - 📝 Please **report issues** at [GitHub Issues](https://github.com/xgreenrx-star/VisualGasic/issues).
>
> **Do not ship games built with this Beta.** Wait for the stable release.

---

## 🚀 Highlights

Beta 5 is a **polish + new plugin** release focused on the VG IDE shell and the game-development workflow. The headline addition is the new **Working Nodes** visual scripting plugin. Alongside it are major fixes to the embedded editor workflow, the Ctrl+S contract, level-swapping in AGCK games, and the IDE layout when switching between Form / 2D / 3D / Sprite views.

---

## 🆕 New — Working Nodes Visual Scripting Plugin

A node-graph visual scripting editor shipped as a first-class VG plugin.

- Wire-based graph editor with ports, curved bezier connections, and zoom / pan / snap
- Two-row toolbar (File / Edit / View / Run controls on row 1, node palette on row 2) that no longer overflows the IDE at narrow widths
- Full **📖 Help** button that opens the Working Nodes manual in the system viewer
- Load / Save graphs via standard VG file dialog (Open / Save / Save As)
- Clean integration with the VG plugin strip — activates as its own main view

See [docs/plugins/WORKING_NODES.md](docs/plugins/WORKING_NODES.md) for the manual.

![Working Nodes — node palette open in the VG IDE](docs/screenshots/Screenshot%20at%202026-04-22%2007-13-30.png)

*Working Nodes main view with the Shift+A node palette open, the Help button in the toolbar, and the Project Explorer / Properties panels docked on the right.*

![Working Nodes manual — in-IDE help](docs/screenshots/Screenshot%20at%202026-04-22%2009-09-40.png)

*Clicking the 📖 Help button opens the full Working Nodes manual in the built-in e-book viewer.*

---

## ✨ What's Improved

### 🧠 Code Editor — normal "save only on Ctrl+S" semantics

The embedded VG code editor now behaves like a standard code editor:

- **Ctrl+S** in the Form Designer now always saves the active `.vg` code buffer (previously, only the `.tscn` was saved — this was the root cause of "my edits don't take effect" reports).
- **Run Project** (toolbar button, Debug menu, Run menu) flushes the current buffer to disk so the running game uses your latest edits, **but does not clear the dirty indicator**. The only way to formally save is Ctrl+S / File → Save. This matches the behavior of VS Code, Visual Studio, and every other modern editor.

### 🎛️ IDE Layout — Form / 2D / 3D / Sprite view switching

- **New `CenterStack` wrapper** — the center column of the IDE used to stuff every embedded editor (form canvas, code editor, embedded 2D, embedded 3D, sprite editor) as direct children of an `HSplitContainer`. `HSplitContainer` is only designed for two children, so the 2D / 3D / Sprite editors were being sized to (0, 0) and rendered as a black blank area. All five editors are now parented under a single `CenterStack` `MarginContainer`, so each one expands to fill the center slot correctly.
- **Right-side panels (Project Explorer + Properties) now stay visible** when switching to 2D, 3D, or Sprite view — they previously forced themselves into Godot's docks on every main-screen change and blocked Godot's own 2D/3D editors from displaying.
- **`undock_vg_panels()`** now always performs the cleanup step (it previously early-returned when the IDE layout was already built, which left the VG panels stuck in the docks after a restart).

![3D racing game built in VisualGasic running in Godot](docs/screenshots/Screenshot%20at%202026-04-22%2016-12-58.png)

*A 3D racing game built with the VisualGasic VG3D tooling, running in a debug session — showing the kind of project you can build with this release.*

### 🕹️ AGCK Game Engine Fixes

- **Level swapping** now works reliably in the Platformer kit. Old level nodes are removed from the scene tree (`container.RemoveChild(child); child.QueueFree()`) before the replacement is added, fixing:
  - Level 2 rendering as a blank screen because the previous level's `Camera2D` still claimed `current` for a frame.
  - Lives counter going to negative values on death because the `LoseLife` Case 0 path left stale level nodes parented.
  - Codegen for `NextLevel`, `GoToLevel`, and `LoseLife` (Case 0) all emit the new pattern.
- **Hero invincibility blink** is now time-based (10 Hz via `Int(InvincibleTimer * 10) Mod 2`), not per-physics-frame. The sprite now actually appears to flash instead of being invisible for the entire invincibility window.

### 🧩 FormDesigner C++

- Removed the per-custom-control `"FormDesigner: Set preview texture for..."` debug `print()` that was spamming the Output panel every 66 ms (15 fps live preview).
- Live preview manager is now frozen when the main screen is not the Form Designer (`_on_main_screen_changed` calls `_live_preview_mgr.set_frozen(not is_form_screen)`).

---

## 🐛 Bug Fixes

- **Ctrl+S no-op in Form Designer** — Ctrl+S saved only the `.tscn`, never the code. Fixed at both event handlers (`_input()` and `_on_canvas_gui_input()`).
- **Black viewport in 2D / 3D / Sprite views** — caused by stacking 6 direct children under an `HSplitContainer`. Fixed via new `CenterStack` wrapper.
- **VG Properties window blocking Godot 2D/3D editors** — VG dock panels were not being undocked when leaving VB6 mode. Fixed in `undock_vg_panels()`.
- **Camera stuck on previous level** — old `Camera2D.current = true` persisted across level swaps. Fixed by removing level nodes from the tree immediately.
- **`platformer_2d` sample project** — missing `vg_2d_editor.gd` and `vg_3d_editor.gd` (addon folder was out of sync). Resolved by full addon resync in the shipped sample.

---

## 📦 Downloads

| Package | Size (approx) | Notes |
| --- | --- | --- |
| `VisualGasic_v5.0.1-beta5_linux_x86_64.zip` | ~450 MB | Full package: addon, editor binary, docs, demos |
| `VisualGasic_v5.0.1-beta5_windows_x86_64.zip` | ~500 MB | MinGW cross-compiled |

SHA-256 checksums are provided as `.sha256` next to each zip.

---

## 🧰 Upgrading

1. **Back up your projects.**
2. Close Godot.
3. Delete your existing `addons/visual_gasic/` folder.
4. Extract the new release's `addons/visual_gasic/` into your project (or into `~/.local/share/visual_gasic/` for the global install).
5. Restart Godot.

If you had unsaved changes in the embedded code editor before upgrading, re-open each form and press Ctrl+S to write the latest buffer to disk.

---

## 🗺️ Known Issues

- **Windows binaries are untested on native hardware.** They are MinGW cross-builds from Linux. If Ctrl+S, the 2D/3D editors, or Working Nodes misbehaves on Windows, please file an issue.
- **macOS binary is not rebuilt in this beta.** The `beta1` universal framework is still the latest macOS build.
- **Working Nodes** is a first pass. Graph execution is not yet wired to the VG runtime — for now it serves as a visual design surface.

---

## 🙌 Thanks

Thanks to everyone who has been hammering on the beta and filing reports — especially for the "my code isn't running what I see in the editor" thread that pinpointed the Ctrl+S bug and led to the new save-on-Ctrl+S-only contract.

— The VisualGasic team
