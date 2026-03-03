# VisualGasic v3.4.1 — Bug Fix Release

**Release Date**: March 3, 2026  
**Platforms**: Linux x86_64, Windows x86_64  
**Godot**: 4.5+ (tested on 4.6.1)

---

## What is VisualGasic?

**VisualGasic** is a modern, event-driven programming language for the Godot Engine inspired by Visual Basic 6's legendary approachability. It features a full Form Designer, JIT compiler, auto event wiring, and 66 demo projects.

---

## Changes since v3.4.0

### Bug Fixes

#### Form Designer no longer hijacks scene tree focus
Previously, clicking on **any** Control or Node2D node in the scene tree would automatically switch to the Form Designer tab — even in non-VG scenes like the Platformer 2D demo. This was caused by `_handles()` returning `true` too aggressively.

**Fix**: `_handles()` now always returns `false`. The Form Designer never auto-activates. Users open it manually via the **Form Designer** tab in the editor toolbar when they want to work on forms. This is less intrusive and works correctly with mixed VG/GDScript projects.

#### Debug handler parser error fixed
Opening a project with the VisualGasic plugin caused a parser error:

> `Parser Error: Static function "get_global_debugger()" not found in base "GDScriptNativeClass"`

This occurred in `vg_debug_handler.gd` line 551. GDScript's parser validates static method calls at parse time, so the runtime guard (`if ClassDB.class_has_method(...)`) didn't prevent the error.

**Fix**: Replaced the direct static call `VisualGasicDebugger.get_global_debugger()` with `ClassDB.class_has_method()` check + dynamic `call()` dispatch, which the parser cannot reject.

#### Double-click on controls works with Toolbox tool active
When a Toolbox tool was selected (e.g., Button, TextBox), double-clicking an existing control on the Form Designer canvas was silently swallowed instead of opening the code editor.

**Fix**: The C++ `_on_mouse_down()` handler now detects double-clicks inside the placing-tool block. If the user double-clicks an existing control while a tool is active, the tool is cancelled and the `control_double_clicked` signal is emitted normally.

#### Clean event handler stubs
Generated event handler code no longer includes debug Print statements. Previously, double-clicking a control would generate:

```vb
Sub Button1_Click()
    Print "Button1 Click"
End Sub
```

Now it generates a clean empty stub:

```vb
Sub Button1_Click()
    
End Sub
```

#### Code editor scrolls to correct handler
After double-clicking a control to jump to its event handler, the code editor now reliably scrolls to the correct line. Previously, the Script editor hadn't finished layout when `center_viewport_to_caret()` was called.

**Fix**: Uses a timer-based deferred scroll (150ms wait + second pass) to ensure the Script editor has finished laying out before scrolling.

#### Unsaved form fallback for code generation
Double-clicking a control on an unsaved form no longer silently fails. The plugin now attempts to sync or auto-save the form before generating the event handler code.

---

## What's included

- **66 demo projects** — 2D games (Pong, Snake, Space Shooter, Platformer), 3D (Squash the Creeps), shaders, audio, UI apps, threading, networking, and more
- **4 ported official Godot demos** — Screen Space Shaders, Sky Shaders, 2D Platformer, Squash the Creeps
- **Custom Controls system** — build your own .tscn controls with a wizard and drag them onto forms
- **Form Designer** — full VB6-style WYSIWYG with 40+ controls, Properties panel, Toolbox, live preview
- **JIT Compiler** — hot loops compile to native x86-64 (2×–118× faster than GDScript on benchmarks)
- **IntelliSense** with 80+ completions, snippets, and Godot type awareness
- **Debugger** with conditional breakpoints, watch window, call stack, and time-travel debugging
- **108 built-in functions** (string, math, file I/O, date/time, collections, and more)
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
