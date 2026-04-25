# VisualGasic v5.1.0 Beta 1 — Release Notes

**Release Date**: April 24, 2026
**Tag**: `v5.1.0-Beta1`
**Status**: 🟡 **BETA — NOT FOR PRODUCTION USE**

---

> ## ⚠️ BETA CAUTION
>
> **This is a Beta 1 pre-release.** It is provided for **evaluation and testing purposes only.**
>
> - 🚧 Features may be incomplete, unstable, or subject to change.
> - 💾 Back up your projects before opening them with this version.
> - 🖥️ Windows and macOS binaries (when produced) are cross-compiled and have not been verified on native hardware.
> - 📝 Report issues at [GitHub Issues](https://github.com/xgreenrx-star/VisualGasic/issues).
>
> **Do not ship games built with this Beta.** Wait for the stable release.

---

## 🚀 Highlights

v5.1.0 is a **UX-focused follow-up** to 5.0.1 that unifies the IDE's run/preview surface, makes the Form Designer a first-class toggleable plugin, and ships a one-line installer for Linux. Working Nodes (new in 5.0.1) is now fully integrated into the unified ▶ Play menu and F5 shortcut.

- **🎛️ Unified ▶ Play menu** — one MenuButton replaces the old `Preview` / `Preview (Debug)` / `Build` / `Run` button row, available in every view.
- **⌨️ F5 dispatches to the active plugin** — plugins can opt into handling F5 / Shift+F5 / Ctrl+F5 via a new `on_play_shortcut()` API.
- **🧩 Form Designer as a toggleable plugin** — disable the legacy VB6-style designer per-project from the ⚙ Plugin Settings dialog; new projects default to code-first.
- **📥 One-click installers** — platform-native installers (Linux AppImage, Windows .exe) with a graphical wizard that lets you pick the Godot version, starter project name/folder, shortcuts, and optional AI keys. Installs Godot, VG, the starter project, and `.vg` file association with no terminal required.
- **🖱️ Draggable left-sidebar splitters** — the 2D and 3D editors finally have a working VSplitContainer between Object List and Scene Tree.
- **🔌 Working Nodes plugin** — full plugin polish: graphs run from the Play menu, F5 runs the current graph, no more double-Play buttons.

---

## 🎛️ Unified ▶ Play Menu

The top-toolbar run/preview buttons have been consolidated into a single **▶ Play MenuButton** (`form_preview_toolbar.gd`).

| Menu Item | Shortcut | Action |
|-----------|----------|--------|
| Run Current Scene | F5 | Launch the active scene (or dispatch to the active plugin) |
| Run Main Scene | Ctrl+F5 | Launch the project's main scene |
| Preview Current Form | Shift+F5 | Form-designer-aware preview |
| Preview (Debug) | Ctrl+Shift+F5 | Preview with debugger attached |
| Build Project | — | Compile/validate without launching |

The Play menu is visible in **every view** (Code, Form, 2D, 3D, Sprite, and plugin views) — no more switching to the Form Designer just to hit Run.

### Plugin API

Plugins can surface their own entries in the Play menu:

```gdscript
var id := form_preview_toolbar.add_menu_item("Run Graph   F5", _run_graph)
# ... later ...
form_preview_toolbar.remove_menu_item(id)
```

And opt into handling the F5 shortcut when their view is active:

```gdscript
func on_play_shortcut(ctrl: bool, shift: bool) -> bool:
    if ctrl: return false              # let Run Main Scene fall through
    _run_graph()
    return true                        # consume the event
```

See [docs/guides/PLUGIN_SYSTEM.md → ▶ Play Menu Integration](docs/guides/PLUGIN_SYSTEM.md#-play-menu-integration-new-in-510) for the full contract.

---

## 🧩 Form Designer is now a toggleable plugin

The legacy VB6-style Form Designer has been retrofitted as a **pseudo-plugin** — it shows up in the **⚙ Plugin Settings** dialog alongside community plugins and can be disabled per-project.

When disabled (`ProjectSettings → vg/form_designer_enabled = false`):

- The "🎨 Form Designer" plugin-strip button is removed.
- The legacy top-toolbar `▣ Form` mode-toggle button is hidden.
- Form-specific widgets (alignment toolbar, color palette, `Indexes`, `▶ Live`) are hidden in every view.
- The startup auto-open-first-form behavior is skipped — the IDE opens in the code editor.
- New projects created by `install.sh` set `vg/default_mode = "code"` and do not auto-open forms.

This is the first step toward making VisualGasic **code-first by default** while keeping the Form Designer available for projects that need it.

---

## 🖱️ Draggable Left-Sidebar Splitters (2D & 3D Editors)

The left sidebar of the 2D and 3D scene editors now has a **draggable VSplitContainer** between the Object list (top) and Scene Tree (bottom). Previously the child `ItemList` and `Tree` controls had pinned `custom_minimum_size.y` values that left no slack — the splitter handle existed but couldn't actually resize anything. Child minimums are now zero; the split container itself sets the combined minimum (520 px).

| Before | After |
|--------|-------|
| Sidebar sections had fixed heights | Drag the divider to resize |
| "Scene Tree" could be crushed by a long tool list | Both panes respect the drag |

---

## 🔌 Working Nodes — Play-menu integration & F5

The Working Nodes visual-scripting plugin (new in 5.0.1) now participates in the unified Play surface:

- **▶ Play → "Run Graph"** and **"Run Graph Headless"** menu entries appear only when the plugin is loaded.
- **F5** runs the current graph when the Working Nodes view is active.
- **Shift+F5** runs headless.
- **Ctrl+F5** falls through to `Run Main Scene` (the host wins).
- Menu entries are deregistered on plugin cleanup.

Also fixed: the plugin briefly caused **two ▶ Play buttons** to appear because `add_menu_item()` lazily rebuilt the UI before `_ready()` had a chance to; `_build_ui()` is now idempotent.

---

## 📥 One-Click Installers (new)

v5.1.0-Beta1 ships **double-clickable installers** with a **graphical wizard** for Linux and Windows. Zero terminal usage, zero prior Godot setup, zero config editing — download, double-click, fill in the wizard, and the VisualGasic IDE is ready. The installers also register `.vg` files so double-clicking a `.vg` file opens the IDE directly on it.

### Download

| Platform | File | Size |
|----------|------|------|
| Linux    | `VisualGasic-Installer-v5.1.0-Beta1-x86_64.AppImage`                 | ~1.1 MB |
| Windows  | `VisualGasic-Installer-v5.1.0-Beta1-x86_64.exe`                      | ~9.6 MB |
| Linux (offline, bundles Godot)   | `VisualGasic-Installer-Offline-v5.1.0-Beta1-linux-x86_64.zip`   | ~70 MB |
| Windows (offline, bundles Godot) | `VisualGasic-Installer-Offline-v5.1.0-Beta1-windows-x86_64.zip` | ~86 MB |

All four are attached to this release — grab them from the [Assets section](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.1.0-Beta1).

### The graphical wizard

Double-click the installer and a wizard opens (Tkinter on Linux, native NSIS dialogs on Windows) with the same options on both platforms:

![Installer Options page — Godot version dropdown, project name/folder, AI keys, shortcuts](docs/screenshots/installer_options.png)

- **Godot version** — dropdown, defaults to `4.6.1-stable`.
- **Starter project name and folder** — defaults to `~/VisualGasic/MyFirstGame` (Linux) or `%USERPROFILE%\VisualGasic\MyFirstGame` (Windows); Browse button to change it.
- **Shortcuts & `.vg` file association** — checkboxes for Start Menu / Applications-menu entries and the file type registration.
- **AI Coding Assistant (optional)** — dedicated page with password fields for OpenAI, Claude, and Gemini. Leave blank to configure from inside the IDE later. Ollama runs locally and needs no key.
- **Install progress** — live log and a step indicator while Godot downloads and the project is scaffolded.

![Installer Install page — live progress log while Godot downloads and the project is scaffolded](docs/screenshots/installer_install.png)

On Linux the wizard requires `python3-tk` (pre-installed on most desktops). If it's missing, the AppImage falls back to the text-mode installer and shows a hint on how to install Tk.

### What the installers do

1. Download and unpack a matching Godot (**4.6.1-stable** by default) to a user-scoped location (no admin required).
2. Install the VisualGasic editor plugin.
3. Create a starter project at the location you picked in the wizard (default **MyFirstGame** in `~/VisualGasic/` on Linux or `%USERPROFILE%\VisualGasic\` on Windows) with VG pre-enabled and a sample `Form1.vg`.
4. Add a **VisualGasic IDE** entry to the Applications menu / Start Menu / Desktop.
5. Register the `.vg` file type so double-clicking a `.vg` file launches the IDE on it.

### Power-user / scripted install (flags still work)

Every wizard option is also available as a command-line flag, for CI, scripting, or power users. Pass `--no-gui` to skip the wizard, `--gui` to force it on, or just let the installer auto-detect (it opens the GUI when double-clicked, and uses text mode when run from a terminal with other flags).

The installer supports **Godot 4.6.1-stable and newer**:

```bash
# Linux — list everything the installer will accept
./VisualGasic-Installer-v5.1.0-Beta1-x86_64.AppImage --no-gui --list-godot-versions

# Interactive text-mode picker
./VisualGasic-Installer-v5.1.0-Beta1-x86_64.AppImage --no-gui --pick-godot

# Fully scripted install
./VisualGasic-Installer-v5.1.0-Beta1-x86_64.AppImage --no-gui \
    --godot-version 4.6.2-stable \
    --project-dir ~/Games/MyGame \
    --display-name "My Game"

# Include beta / RC builds in the picker
./VisualGasic-Installer-v5.1.0-Beta1-x86_64.AppImage --no-gui --pick-godot --include-prereleases
```

The Windows `.exe` accepts the same flags via its shortcut's target field (or the `run_installer.cmd` it drops).

### Optional: seed AI keys at install time

Use the wizard's **AI Coding Assistant** page, or pass the flags (opt-in, written with `0600` permissions on POSIX to Godot's per-user ConfigFile):

```bash
./VisualGasic-Installer-v5.1.0-Beta1-x86_64.AppImage --no-gui \
    --with-ai-keys \
    --openai-key "sk-..." \
    --claude-key "sk-ant-..." \
    --gemini-key "AIza..."
```

Without `--with-ai-keys` (or leaving the wizard's fields blank) no keys are written; the AI assistant stays disabled until configured from inside the IDE.

### Offline install (no internet)

The two `-Offline-` bundles include a pre-downloaded Godot alongside the installer. Unzip and follow the `README.txt` — the installer uses the bundled Godot automatically, and the graphical wizard still opens when you double-click.

### Build the installers yourself

Four scripts under `scripts/`:

| Script | Output |
|--------|--------|
| `scripts/bootstrap_gui.py`                     | Tkinter wizard (imported by `bootstrap_vg.py` — run it directly to preview the UI) |
| `scripts/build_appimage.sh <version>`          | Linux AppImage (bundles the Tk wizard) |
| `scripts/build_windows_installer.sh <version>` | Windows NSIS `.exe` with native `nsDialogs` wizard (requires `nsis` package on Linux build host) |
| `scripts/build_offline_bundle.sh <version>`    | Both offline `.zip` bundles |

The installer engine itself is `scripts/bootstrap_vg.py` — a stdlib-only Python 3 script you can run directly on any platform.

---

## 📥 Legacy `install.sh` Bootstrap (still supported)

Command-line users can still install via the shell one-liners. These are unchanged in v5.1.0 apart from now honoring the GitHub Releases API (including pre-releases) instead of the `main` branch:

```bash
# Linux / macOS
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.sh | bash

# Windows PowerShell
irm https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.ps1 | iex

# Cross-platform Python
python3 install.py --github
```

Projects created via `vg new` ship with `vg/default_mode = "code"` so the IDE opens directly into the code editor instead of the Form Designer.

---

## 🐛 Other Fixes

- **Right-side panel no longer disappears** after switching back from a plugin view (Working Nodes / AGCK) to Code view. The `RightPanelSplit` is now explicitly restored on every view switch — previously `_show_code_view()` forgot to turn it back on.
- **`form_preview_toolbar._build_ui()` is now idempotent** — guarded against double-run so late-registering plugins no longer produce duplicate `▶ Play` buttons.
- **Profiler panel wired to C++ singleton** via static class methods, fixing the "Profiler button does nothing" bug.
- **Default registry for package management** is now documented as unwired (tracked in a TODO).

---

## 🔁 Changelog Since v5.0.1-beta5

```
4a1e5b3 visual_gasic_plugin: hide form-designer-only toolbar widgets in code/3D/2D/Sprite views
c5607d0 visual_gasic_plugin: honor form_designer_enabled on toolbar + startup
bdb855e vg_{2d,3d}_editor: make split divider actually draggable
a7465f4 visual_gasic_plugin: restore right panel when leaving plugin view
b209de7 vg_{2d,3d}_editor: draggable split between object list and scene tree
dc7b4b8 form_preview_toolbar: guard _build_ui() against double-run
2d690e0 working_nodes: surface Run Graph in ▶ Play menu + F5 shortcut
3f43a16 ux: Form Designer appears in Plugin Settings as a toggleable entry
7c19097 ux: log built-in Form Designer entry registration
d460d84 ux: code-first by default; surface Form Designer in plugin strip
9f39e72 ux: default to code editor; make Form Designer an opt-in mode
4837742 ux: unify Preview/Build/Run buttons into one ▶ Play menu
f8503cd installer: bootstrap script installs Godot + VG + launcher (Linux MVP)
7138b97 working_nodes: fix plugin load — typed scroll + single-line Sub sig
af2c906 working_nodes: wn_runtime.vg + visible scene gen + Run Graph button
305a696 docs: document Profiler, Controls, Packages, and AI Help bottom-dock panels
0fb9dcb profiler: wire C++ singleton to IDE panel via static class methods
d11f7ff pkg: TODO note that default registry is unwired
df69cf4 addons: dedup real-dir copies into symlinks + CI drift guard
e9daae8 AI Help: speed opts, first-run model picker, UI cleanup
b1a7a72 build_release.sh: copy plugins/ to staging + strip nested demo bin dirs
```

---

## 📖 Documentation

Updated in this release:

- **[IDE Shortcuts & Features](docs/manual/IDE_SHORTCUTS.md)** — new **▶ Play Menu** section covering F5 / Ctrl+F5 / Shift+F5 behavior and the plugin dispatch protocol.
- **[Plugin System](docs/guides/PLUGIN_SYSTEM.md)** — new **▶ Play Menu Integration** and **Form Designer as a Toggleable Plugin** sections; full `add_menu_item()` / `on_play_shortcut()` contracts.

Other relevant manuals (unchanged in this release but worth linking):

- **[Getting Started](docs/guides/GET_STARTED.md)**
- **[Installation Guide](docs/guides/INSTALLATION.md)** — including `vg` CLI usage
- **[VisualGasic Language Reference](docs/VisualGasic_Language_Reference.md)**
- **[Working Nodes Manual](addons/visual_gasic/plugins/working_nodes/WORKING_NODES_MANUAL.md)**
- **[AGCK Manual](docs/manual/AGCK_MANUAL.md)**
- **[Debugging Guide](docs/manual/debugging.md)**

---

## 📦 What's in the Release Archive

Each platform zip (`VisualGasic_v5.1.0-Beta1_{linux,windows,macos}_*.zip`) contains:

- `addons/visual_gasic/` — GDScript IDE, `.gdextension` manifest, platform-specific C++ binaries in `bin/`.
- **`addons/visual_gasic/plugins/`** — all bundled IDE plugins:
  - `agck/` — Arcade Game Construction Kit
  - `vg3d/` — 3D editor integration
  - `web_publish/` — HTML5 export helper
  - `working_nodes/` — Visual node-graph scripting + its manual
- `install.sh` / `install.ps1` / `install.py` — installers
- `vg` — CLI launcher
- `README.md` / `CHANGELOG.md` / `LICENSE` / `CONTRIBUTING.md`
- `RELEASE_NOTES_v5.1.0-Beta1.md` (this file)
- `docs/` — full documentation tree (archives and dev-only files excluded)
- `examples/`, `demos/`, `tutorials/` — sample projects

---

## 🔄 Upgrade Notes

- **No breaking GDScript API changes.** Existing plugins that don't implement `on_play_shortcut()` and don't register Play-menu entries continue to work unchanged.
- The **`▣ Form` button** is hidden when `vg/form_designer_enabled = false`. If you rely on it, make sure the Form Designer is enabled in your project's **⚙ Plugin Settings**.
- **`_build_ui()` on `form_preview_toolbar`** is now idempotent; plugins that were calling it directly should instead go through `add_menu_item()`.

---

**Thanks for testing!** Please report regressions or UX rough edges at [GitHub Issues](https://github.com/xgreenrx-star/VisualGasic/issues) with the `5.1.0-Beta1` label.
