# VisualGasic v3.5.0 Beta 3 — Code Editor & Stability Release

**Release Date**: March 9, 2026  
**Platforms**: Linux x86_64, Windows x86_64  
**Godot**: 4.5+ (tested on 4.6.1)

---

## What is VisualGasic?

**VisualGasic** is a modern, event-driven programming language for the Godot Engine inspired by Visual Basic 6's legendary approachability. It features the Visual Gasic IDE with a full WYSIWYG form editor, JIT compiler, auto event wiring, and 66 demo projects.

---

> ## ⚠️ BETA — READ THIS FIRST
>
> This is a **beta release** focused on embedded code editor stability, IDE
> navigation, and UX polish. The core language, compiler, and JIT are stable.
> The Visual Gasic IDE continues to be refined based on real-world testing.
>
> **This is not production-ready software.** Please use it to experiment, learn, build
> prototypes, and help us find bugs.

---

## What's New in v3.5.0-beta3

### 🖥️ Renamed: "Form Designer" → "Visual Gasic IDE"

The main editor tab in the Godot toolbar has been renamed from **Form Designer** to **Visual Gasic IDE**. This better reflects that the tab is a complete IDE — not just a form designer, but also a code editor, project explorer, properties panel, and debugging environment.

![Visual Gasic IDE with Code Editor](docs/screenshots/Screenshot%20at%202026-03-09%2012-23-57.png)
*The Visual Gasic IDE tab in Godot's toolbar — showing the embedded code editor with VB6 syntax highlighting*

### 📝 Embedded Code Editor Overhaul

The embedded VB6 code editor has been significantly stabilized:

- **Grey window on switch** — Fixed: switching between form canvas and code view no longer shows a grey/blank panel
- **Double-click to edit** — Fixed: double-clicking a control on the form correctly opens the code editor to that control's event handler
- **Scrollbar visibility** — Fixed: scrollbars now use a high-contrast dark grabber against the light background, with triple-method theme application to ensure visibility
- **Syntax highlighting** — Fixed: washed-out colors resolved; keywords, strings, comments, and types now display with proper contrast
- **Theme timing** — Fixed: theme colors are applied *after* `_ready()` so they aren't overwritten by Godot's default theme cascade

### 📂 Three-Way Project Explorer

The Project Explorer panel now classifies files into three clear categories:

| Category | Contains | Icon |
|----------|----------|------|
| **Forms** | `.tscn` files that have a paired `.vg` script | 📋 |
| **Components** | `.tscn` files without a `.vg` script (scenes, prefabs) | 🧩 |
| **Modules** | Standalone `.vg` code modules (no form) | 📄 |

Previously, all `.tscn` files were lumped together as "Scenes". This makes it much easier to navigate projects that mix forms with standalone scenes and code modules.

### 📦 Formless Module Support

You can now edit standalone `.vg` module files (files without a paired `.tscn` form) directly in the embedded code editor. Double-click a Module in the Project Explorer to open it. This is useful for utility libraries, game logic modules, and shared code.

### 🔇 "Reload from Disk" Fix

**Fixed**: Godot no longer shows a "reload from disk?" dialog every time you switch to another application and come back. The root cause was that the IDE was unconditionally writing `.tscn` files to disk on every auto-save cycle — even when nothing had changed. The IDE now only writes to disk when the form has actually been modified (the dirty flag is set).

---

## All Changes Since v3.5.0-beta2

### New Features
- **Renamed "Form Designer" → "Visual Gasic IDE"** in toolbar, tooltips, and all documentation
- **Three-way Project Explorer** — Forms, Components, and Modules classification
- **Formless module editing** — standalone `.vg` files editable in the embedded code editor

### Bug Fixes — Code Editor
- **Grey window** when switching to code view — fixed (restored 3-child HSplitContainer layout)
- **Double-click to code** — fixed `super._gui_input()` call that broke event routing
- **Scrollbar grabber invisible** — triple-method theme fix ensures dark grabber on light background
- **Scrollbar styling** — uses `get_v_scroll_bar()`/`get_h_scroll_bar()` for reliable targeting
- **Washed-out syntax colors** — proper color values applied with correct theme timing
- **Theme cascade timing** — apply VB6 theme *after* `_ready()` so Godot defaults don't overwrite

### Bug Fixes — IDE
- **"Reload from disk" dialog** — no longer triggers on every focus-loss; `.tscn` only written when form is dirty
- **EditorFileSystem notification** — `update_file()` called after all file saves to prevent stale cache
- **Project Explorer** — Resources section collapsed by default, Modules expanded for visibility

### Documentation
- All 17 documentation files updated: "Form Designer" → "Visual Gasic IDE"
- Calculator tutorial, Getting Started, Language Reference, Programming Manual, and more

---

## What's Included

- **66 demo projects** — 2D games, 3D, shaders, audio, UI apps, threading, networking
- **4 ported official Godot demos** — Screen Space Shaders, Sky Shaders, 2D Platformer, Squash the Creeps
- **Custom Controls system** — build your own `.tscn` controls and drag them onto forms
- **Visual Gasic IDE** — full VB6-style WYSIWYG with 40+ controls, Properties panel, Toolbox, live preview, embedded code editor
- **JIT Compiler** — hot loops compile to native x86-64 (2×–118× faster than GDScript)
- **IntelliSense** with 80+ completions, snippets, and Godot type awareness
- **Debugger** with conditional breakpoints, watch window, call stack, and time-travel debugging
- **Theme Editor** with 8 built-in themes and custom theme creation
- **Object Browser** for exploring the Godot class hierarchy
- **108 built-in functions** (string, math, file I/O, date/time, collections)
- **481 tests passing**
- **Linux and Windows binaries** included

---

## Install

1. Download the release ZIP for your platform
2. Extract and copy `addons/visual_gasic/` into your Godot project folder
3. Open **Project → Project Settings → Plugins** → Enable **"Visual Gasic"**
4. Create `.vg` files and start coding — or use **File → New Form** in the Visual Gasic IDE

---

## Upgrade from v3.5.0-beta2

1. Back up your project
2. Delete your existing `addons/visual_gasic/` folder
3. Copy the new `addons/visual_gasic/` from the release ZIP
4. Re-enable the plugin if needed
5. Your `.vg` files and `.tscn` forms are fully compatible — no migration needed

> **Note:** The editor toolbar button is now called **"Visual Gasic IDE"** instead
> of "Form Designer". It's the same feature — just a better name.

---

## Known Issues

- macOS builds not included in this release (coming in next beta)
- Theme Editor font settings (font name, size, bold keywords) are stored in VGTheme but not yet exposed in the editor UI
- Custom themes are saved per-project, not globally
- Internal code comments in `.gd` source files still reference "Form Designer" (developer-facing only, no user impact)

---

## Links

- **GitHub**: https://github.com/xgreenrx-star/VisualGasic
- **License**: MIT
- **Previous Release**: [v3.5.0-beta2 Release Notes](RELEASE_NOTES_v3.5.0-beta2.md)
- **First Beta**: [v3.2.0-beta1 Release Notes](RELEASE_NOTES_v3.2.0-beta1.md)
