# VisualGasic v5.1.0-rc.2 — Release Candidate

**Tag**: `v5.1.0-rc.2` · **Date**: 2026-05-03 · **Status**: Pre-release · **Engine**: Godot 4.6.1+

> ⚠️ **Beta-test call (especially Windows & macOS).** Linux is the daily-driver platform for the maintainer; the **Windows and macOS binaries in this release are cross-compiled by CI and have not been smoke-tested on native hardware**. If you can spare 30 minutes on either OS, please install, run a demo, and file an issue at <https://github.com/xgreenrx-star/VisualGasic/issues>. We hope `v5.1.0` final will follow once we have green smoke from at least one tester on each platform.

> 🔁 **What changed since `rc.1`?** Two things, both polish-grade rather than feature-grade:
> 1. The welcome shell ↔ Godot editor handoff has been overhauled so Godot no longer flashes up uncovered while the IDE boots.
> 2. The Form Designer toolbox grew by **15 controls**, including a new **Game UI** tab for retro / HUD widgets.
>
> Everything from `rc.1` (AGCK 8 templates, AI personas + voice mode, plugin SDK, unified ▶ Play menu, Linux one-shot installer, Narcea agent mode, …) is unchanged — see [`RELEASE_NOTES_v5.1.0-rc.1.md`](RELEASE_NOTES_v5.1.0-rc.1.md) for that list.

---

## What is VisualGasic?

VisualGasic is a **VB6 / VB.NET-style language and IDE bolted on top of Godot 4.6**. You write `Sub Form_Load()` and `Sub btnSave_Click()` and a real game runs. Under the hood it's a C++ GDExtension with a 5-tier JIT, an event-driven naming-convention dispatcher, and an IDE built into the Godot editor. The pitch is: **the productivity of GDScript, the speed of C++, and the muscle memory of VB6.**

---

## 🪟 Welcome shell loading experience — overhaul

The biggest user-visible polish in `rc.2`. In `rc.1` you'd see Godot's editor paint to the screen for a half-second before the welcome shell could minimize itself or move out of the way. Two earlier attempts to fix this were tried and abandoned:

| Approach | Why it didn't work |
| --- | --- |
| `get_tree().get_root().mode = Window.MODE_MINIMIZED` after `OS.create_process` | The plugin runs in the *new* editor process, so by the time it can act, the editor window has already been laid out and painted. |
| `--position 30000,30000 --resolution 1x1` flags to Godot | Godot ignores the position when no fullscreen mode is set, and resolutions below the project minimum get clamped. |

The **working** fix flips the welcome shell itself into a borderless always-on-top fullscreen window *before* spawning Godot, then lingers there until the IDE plugin signals ready by clearing `~/.config/visual_gasic/launching.flag`.

### What you actually see

![Welcome shell — fullscreen project picker with thumbnails and search](docs/screenshots/Screenshot%20at%202026-05-03%2020-38-10.png)
*Welcome shell on launch — fullscreen project picker with icon thumbnails, live search, and tag chips. Godot's stock Project Manager never gets a chance to appear.*

![Welcome cover with circular spinner — “Loading project…”](docs/screenshots/Screenshot%20at%202026-05-03%2020-38-25.png)
*The cover during handoff — modern rotating-arc spinner sits 40 px below the loading text. Always-on-top so the editor's first paint stays hidden underneath. When `launching.flag` clears, the spinner ring goes solid green and the shell waits 1.5 s for the IDE's first frame before quitting.*

![Welcome shell after a project is selected — Recent project list](docs/screenshots/Screenshot%20at%202026-05-03%2020-41-10.png)
*Cross-platform recent list — moved-to-front, capped at 16, written by the IDE plugin to `~/.config/visual_gasic/recent_projects.cfg` (Linux) / `~/Library/Application Support/VisualGasic/recent_projects.cfg` (macOS) / `%APPDATA%\VisualGasic\recent_projects.cfg` (Windows).*

### Under the hood

- **Welcome opens fullscreen.** `_ready()` sets `get_window().mode = Window.MODE_FULLSCREEN` so the picker takes the whole screen on launch.
- **Cover phase before spawn.** `_launch_godot()` now sets `borderless = true; always_on_top = true; mode = MODE_FULLSCREEN` *before* `OS.create_process(...)`. The Godot binary is invoked with just `["--path", project_dir, "--editor"]` — no position or resolution hints.
- **Modern circular spinner.** Custom-drawn 48 px rotating-arc indicator. Two `draw_arc` calls — a faint track plus a leading 110° arc that rotates ~0.9 rev/sec via `get_tree().process_frame`. On `set_meta("done", true)` the leading arc closes into a solid green ring. The spinner is wrapped in a `VBoxContainer` with a 40 px top pad so it sits below the loading label, not next to it.
- **Synchronized handoff via `launching.flag`.** The IDE plugin clears `~/.config/visual_gasic/launching.flag` from a `call_deferred` in `_enter_tree`. The shell polls every 0.15 s for up to 20 s, then waits an extra 1.5 s so the editor's first paint doesn't race the cover's `quit()`.
- **Named Quit handler.** The cover's Quit button is now wired to `_on_quit_pressed`, a real method (not a lambda). It logs `[VG Welcome] Quit pressed`, drops `always_on_top` + fullscreen, then calls `get_tree().quit()`. This was previously broken in a `rc.1` build with a parse error in the spinner draw closure (a `center` local clashing with `Control.center`); both are fixed in `rc.2`.

---

## 🧰 Form Designer toolbox — 15 new controls

The Toolbox panel grew by 10 controls in the **Standard 2D** tab and 5 in a new **Game UI** tab. All 15 ship as `.tscn` prototypes under [`addons/visual_gasic/prototypes/`](addons/visual_gasic/prototypes/) and are registered via a thin `_register_extra_tools()` helper in [`visual_gasic_plugin.gd`](addons/visual_gasic/visual_gasic_plugin.gd) — no C++ rebuild required, and you can add your own the same way:

```gdscript
var rt = VisualGasicToolbox.singleton()
rt.add_tool("MyControl", "Control", "MiscIcon", "res://my_proto/MyControl.tscn", "2D")
```

> **Why a separate Game UI tab?** Retro / HUD aesthetics (8-bit pixel cells, thick outlines, HSV color shifts) are eye-clutter when you're laying out a regular OS-style form. Splitting them into a dedicated tab keeps the Standard tab clean. AGCK and other game-builder views default to the Game UI tab; the VG IDE form designer defaults to Standard.

### Standard 2D tab additions

| Control | What it is |
| --- | --- |
| **Spinner** | `@tool` rotating-arc indeterminate indicator. Runs live in the designer. |
| **BusyDots** | Three dots bouncing in sequence. Cleaner than a spinner for inline "thinking" states. |
| **ToggleSwitch** | Slide toggle that emits `toggled(pressed)`. Stand-in for the iOS-style switch missing from stock Godot. |
| **ColorPickerButton** | Godot's `ColorPickerButton` exposed as a draggable tool. |
| **LinkButton** | Hyperlink-style label-button with underline-on-hover. |
| **HSplit** | Pre-populated `HSplitContainer` with named Left/Right `Panel` children so dropping it on the canvas gives you something visible. |
| **VSplit** | Same, vertical, with Top/Bottom `Panel` children. |
| **VideoPlayer** | `VideoStreamPlayer` wrapped as a draggable tool. |
| **Expander** | Collapsible header + content panel (`@tool`, fold animation runs in the editor). |
| **Breadcrumbs** | `LinkButton` chain with `▸` separators. `set_path([...])` API. |

### Game UI tab additions

| Control | What it is |
| --- | --- |
| **PixelProgressBar** | 8-bit pixel-cell progress bar with configurable cell count and gap (`@tool`, designer-live). |
| **SegmentedProgressBar** | Rounded multi-chunk bar for stamina / shield gauges. |
| **RetroLifeBar** | Health bar that HSV-shifts green → yellow → red as `value` drops, with thick black outline and highlight strip. Drop-in for top-down RPGs. |
| **CircularProgress** | Determinate ring (`draw_arc`) with center `%` label. |
| **Badge** | Pill / circle count overlay (notification dot). Hides at 0, displays `99+` at overflow. |

These join the existing 7 Tier 1 animated Game UI controls (DialogPanel, InventoryGrid, StatBar, HUDCounter, CooldownButton, NotificationToast, GameMenu).

---

## 🛠 Fixes since `rc.1`

- **Welcome ↔ editor race.** All post-spawn editor-window manipulation is gone; the welcome cover handles concealment instead. (See *Welcome shell loading experience* above for the full rationale.)
- **Spinner lambda scope clash.** `_make_circular_spinner` had a local `center` variable that collided with `Control.center` in the `_draw` callback, throwing a parse error on plugin reload. Renamed to `center_box`.
- **Quit button regression.** The Quit button's inline lambda silently broke during the parse-error window and looked "stuck" in tester reports. The handler is now a real `_on_quit_pressed` method with a diagnostic print.
- **`recent_projects.cfg` re-seed.** `_record_recent_vg_project` now survives a missing or malformed cfg cleanly. Users who deleted the file (or upgraded across the rc.1 JSON-vs-Array format tweak) now get a fresh `[recent]` section instead of a silent no-op.

---

## 📥 Installing

**One-shot installers** (recommended — bundle Godot 4.6.1 and land you straight in the VG IDE):

| Platform | Download | Install |
| --- | --- | --- |
| 🐧 **Linux x86_64** | [`VisualGasic-Installer-v5.1.0-rc.2-x86_64.AppImage`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.1.0-rc.2/VisualGasic-Installer-v5.1.0-rc.2-x86_64.AppImage) | `chmod +x *.AppImage && ./VisualGasic-Installer-v5.1.0-rc.2-x86_64.AppImage` |
| 🪟 **Windows x64** | [`VisualGasic-Installer-v5.1.0-rc.2-x86_64.exe`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.1.0-rc.2/VisualGasic-Installer-v5.1.0-rc.2-x86_64.exe) | Double-click. SmartScreen → *More info* → *Run anyway* (unsigned). |
| 🍎 **macOS** | *coming with v5.1.0 stable* | Use the `vg` CLI or unzip the release for now. |

**Offline bundles** (Godot included, no internet needed during install): [Linux](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.1.0-rc.2/VisualGasic-Installer-Offline-v5.1.0-rc.2-linux-x86_64.zip) · [Windows](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.1.0-rc.2/VisualGasic-Installer-Offline-v5.1.0-rc.2-windows-x86_64.zip)

**Portable zips** (bring your own Godot 4.6.1+): [Linux](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.1.0-rc.2/VisualGasic_v5.1.0-rc.2_linux_x86_64.zip) · [Windows](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.1.0-rc.2/VisualGasic_v5.1.0-rc.2_windows_x86_64.zip)

**Linux bootstrap from source** (alternative to AppImage):

```bash
git clone https://github.com/xgreenrx-star/VisualGasic.git
cd VisualGasic
git checkout v5.1.0-rc.2
./scripts/bootstrap_install.sh
```

Full installation guide, troubleshooting, and uninstall: [`docs/guides/INSTALLATION.md`](docs/guides/INSTALLATION.md). All assets also browsable on the [release page](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.1.0-rc.2).

---

## 🔗 Related links

- **Documentation hub** — [`docs/DOCS.md`](docs/DOCS.md)
- **Changelog** — [`CHANGELOG.md`](CHANGELOG.md)
- **Previous notes** — [`v5.1.0-rc.1`](RELEASE_NOTES_v5.1.0-rc.1.md), [`v5.1.0-Beta1`](RELEASE_NOTES_v5.1.0-Beta1.md)
- **Issue tracker** — <https://github.com/xgreenrx-star/VisualGasic/issues>
- **Release process** — [`RELEASE_PROCESS.md`](RELEASE_PROCESS.md)
