# VisualGasic v4.2.0-beta5 — IDE Bottom Panel & Live Console

**Release Date**: March 15, 2026  
**Platforms**: Linux x86_64, Windows x86_64  
**Godot**: 4.5+ (tested on 4.6.1)

---

## What is VisualGasic?

**VisualGasic** is a modern, event-driven programming language for the Godot Engine inspired by Visual Basic 6's legendary approachability. It features a full Form Designer, JIT compiler, auto event wiring, and 66 demo projects.

---

## What's New in v4.2.0-beta5

This release focuses on **IDE bottom panel improvements** — making the Immediate Window, Output tab, and System Console fully functional.

### Screenshots

![Code Editor with Bottom Panel](docs/screenshots/ide_bottom_panel.png)

*Code Editor with draggable bottom panel: Immediate Window · Output · System Console tabs*

![Immediate Window](docs/screenshots/ide_immediate_window.png)

*Immediate Window: Interactive REPL for live code execution and variable inspection*

### 🔧 Bottom Panel — Draggable VSplitContainer

The bottom panel (Immediate / Output / System Console) now uses a **VSplitContainer** with a draggable splitter between the code editor and the tabbed panel below.

- **Before**: Bottom panel tabs were visible but the content area had zero height — the `VBoxContainer` layout let the CodeEdit consume all vertical space
- **After**: A `VSplitContainer` splits the code editor (top) and bottom panel (bottom) with a draggable divider. Minimum height of 160px ensures the panel is always usable
- Users can drag the splitter to resize the code editor vs. bottom panel area

### 🛠️ Immediate Window — Timing Fix

The Immediate Window tab was appearing blank because `set_immediate_window()` was called **before** `_ready()` had fired on the target nodes.

- **Root Cause**: `.new()` creates the node, but `_ready()` (which builds the internal UI) only fires on the *next* frame after `add_child()`. The plugin was calling `set_immediate_window()` immediately after `add_child()`, so the Immediate Window had zero children and the code editor's `_bottom_tabs` was still null
- **Fix**: Changed to `set_immediate_window.call_deferred()` so the reparenting happens after `_ready()` completes on both nodes
- Also changed Immediate Window from `extends Control` to `extends MarginContainer` for proper container-compatible layout

### 📤 Output Tab — Debug.Print & Lifecycle Events

The Output tab is now wired to real data sources:

- **Debug.Print** — Any `Debug.Print` statement in your VB code routes to the Output tab via the debugger protocol (`visualgasic:debug_print` message capture)
- **Build/Run lifecycle** — Starting and stopping scenes logs timestamped messages:
  - `▶ Running main scene...`
  - `▶ Preview Form...`
  - `■ Stopped.`
- **Profiler summaries** — When profiling is active, summary reports appear in the Output tab
- **Session timestamps** — Each session start is logged with a timestamp so you can tell runs apart
- Cream-colored background, matching the VB6 Output window aesthetic

### 🖥️ System Console — Live Godot Log Tailing

The System Console tab now **tails the Godot engine log file** in real time:

- Reads from `user://logs/godot.log` (cross-platform: works on Linux, Windows, macOS)
- Polls every **0.5 seconds** for new content
- **Color-coded output**:
  - 🔴 Red — Errors (`ERROR`, `SCRIPT ERROR`)
  - 🟡 Amber — Warnings (`WARNING`)
  - 🔵 Cyan — VisualGasic messages (`[VG]`, `visualgasic`)
  - 🟢 Green — Normal engine output
- Dark terminal background with green text, like a classic terminal
- Starts automatically when the code editor opens; no manual setup needed

### Layout Changes

The Immediate Window is now correctly embedded in the bottom `TabContainer`:
- **Tab 0**: Immediate — Full interactive REPL with variable inspection
- **Tab 1**: Output — Your program's debug messages and lifecycle events
- **Tab 2**: System Console — Godot engine internals

---

## Commits in this release

| Commit | Description |
|--------|-------------|
| `b2dc938` | Fix bottom panel: use VSplitContainer for code/panel split |
| `dbfa9f9` | Fix Immediate Window: change extends Control → MarginContainer |
| `069b63f` | Fix Immediate Window blank: defer set_immediate_window() until _ready() |
| `4edd3da` | Wire Output and System Console tabs to live data |

---

## What's included

- **71 demo projects** — 2D games (Pong, Snake, Space Shooter, Platformer), 3D (Squash the Creeps), shaders, audio, UI apps, threading, networking, and more
- **5 new application demos** — VG Terminal (BBS client), VG Paint (MS Paint clone), VG Vector (vector editor), VG Movie (.VGV player), VG Music (live coding synthesizer)
- **4 ported official Godot demos** — Screen Space Shaders, Sky Shaders, 2D Platformer, Squash the Creeps
- **Custom Controls system** — build your own .tscn controls with a wizard and drag them onto forms
- **Form Designer** — full VB6-style WYSIWYG with 40+ controls, Properties panel, Toolbox, live preview
- **JIT Compiler** — hot loops compile to native x86-64 (2×–118× faster than GDScript on benchmarks)
- **IntelliSense** with 80+ completions, snippets, and Godot type awareness
- **Debugger** with conditional breakpoints, watch window, call stack, and time-travel debugging
- **108 built-in functions** (string, math, file I/O, date/time, collections, and more)
- **Immediate Window** with interactive REPL, remote debugging, and data breakpoints
- **Output tab** with Debug.Print routing, lifecycle events, and profiler summaries
- **System Console** with live Godot log tailing and color-coded output
- **481 tests passing**
- **Linux and Windows binaries** included

---

## Install

1. Download the release zip
2. Copy `addons/visual_gasic/` into your Godot project folder
3. Open Project → Project Settings → Plugins → Enable "Visual Gasic"
4. Create `.vg` files and start coding

---

## Links

- **GitHub**: https://github.com/xgreenrx-star/VisualGasic
- **License**: MIT
