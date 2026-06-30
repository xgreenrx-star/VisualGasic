# VisualGasic v4.4.0-rc5 Release Notes — Debugger Stability & Built-in Constants

**Release Date**: March 30, 2026  
**Previous Version**: 4.4.0-rc4  
**Status**: **Release Candidate 5** — Major debugger reliability fixes, built-in constants refactor, and comprehensive documentation overhaul

---

## 🚨 We Need Beta Testers — Seriously

**VisualGasic is approaching a stable 4.4.0 release, but we have zero beta testers right now.** We can't ship a stable release with confidence if nobody outside the core team is putting it through real-world use.

### What We Need

- **Anyone willing to build a small game or tool** with VisualGasic and report what breaks.
- **VB6 veterans** who can tell us where the VB6 experience falls short.
- **Godot users** who can stress-test the debugger, Form Designer, and 66 demo projects.
- **Windows and macOS users** — most development happens on Linux, so cross-platform testing is critical.

### What You Get

- **Direct influence** on the final 4.4.0 release — your bugs get fixed first.
- **Named credit** in the release notes and CONTRIBUTORS file.
- **A voice in the roadmap** — tell us what features matter most to you.

### How to Help

1. **Download** the latest release from [GitHub Releases](https://github.com/xgreenrx-star/VisualGasic/releases).
2. **Try it** — open the demo projects, write some code, use the debugger.
3. **Report issues** on [GitHub Issues](https://github.com/xgreenrx-star/VisualGasic/issues) — even "this felt weird" counts.
4. **Join the discussion** on [GitHub Discussions](https://github.com/xgreenrx-star/VisualGasic/discussions).

Even 30 minutes of testing helps. If you find a bug, you might save hundreds of future users from hitting the same wall.

**If you know anyone who misses VB6, please share this project with them.** 🙏

---

## 🏁 Release Candidate 5 — What Changed

RC5 is a **debugger stability release** with 6 commits since RC4. The headline changes are a clean separation of 109 built-in constants from user variables, four debugger fixes that make the Variables panel, Break button, and auto-connect actually work reliably, plus a 17-file documentation overhaul.

**Upgrade from RC4:** Drop-in replacement — copy `addons/visual_gasic/` over the RC4 version and restart Godot. No migration steps needed.

---

## 🆕 New Features

### 🔒 Built-in Constants Separation

The ~109 built-in constants (`vbRed`, `vbCrLf`, `KEY_SPACE`, `True`, `False`, etc.) have been moved out of the general `variables` Dictionary into a dedicated `builtin_constants` Dictionary.

**Why this matters:**
- Built-in constants no longer appear in the debugger Variables panel, reducing clutter.
- User code can no longer accidentally overwrite `vbRed` or `KEY_ESCAPE`.
- The `is_builtin_constant()` accessor provides a clean API for checking constant status.

```vb
' These are now protected — you can read them but not overwrite them
Print vbRed        ' → 16711680
Print vbCrLf       ' → Chr(13) & Chr(10)
Print KEY_SPACE    ' → 32
```

### 📚 Comprehensive Documentation Overhaul

17 documentation files updated across the entire doc tree:

- **Getting Started guides** — expanded nodes_and_scenes.md with VB6 forms, 62+ property aliases, Me keyword, and a complete working example
- **Manual pages** — debugging.md, ide_tools.md, keywords.md, performance.md
- **Tutorials** — updated code examples and cross-references
- **API reference** — refreshed for v4.4.0 feature set

---

## 🐛 Bug Fixes

### 🎨 Fix: Built-in Constants Not Resolved in Bytecode VM

**Problem:** After moving constants to `builtin_constants`, the bytecode VM only checked `variables.has(name)` when initializing local slots. All VB6 color constants (`vbRed`, `vbBlue`, etc.), key constants (`KEY_SPACE`, `KEY_ESCAPE`), and string constants (`vbCrLf`, `vbTab`) resolved to `0` / empty — making every form turn black and every key check fail.

**Fix:** Added `builtin_constants` fallback to **13 code paths** in the bytecode VM:
- `OP_LOAD_VAR` — Variable reads
- `OP_STORE_VAR` — Variable existence checks
- `OP_LOAD_GLOBAL` — Global variable resolution
- `OP_LOAD_MEMBER` — Member access fallback
- Local slot initialization — Pre-populates from `builtin_constants` when `variables` doesn't have the name
- Several additional paths for operators and comparisons

### 🔍 Fix: Debugger Locals Invisible in Variables Panel

**Problem:** The bytecode VM uses stack-local variables that live in a `Vector<Variant>` — completely invisible to the debugger, which only knew about the instance-level `variables` Dictionary.

**Fix:** Added `debug_bc_locals` and `debug_bc_chunk` pointer members to the instance. The VM sets these pointers at the start of `execute_bytecode()` and clears them on exit. Four debugger query functions now include bytecode locals:
- `get_debug_locals()` — Returns name→value pairs for all live local slots
- `get_debug_globals()` — Unchanged (instance-level variables)
- `get_instance_variables()` — Now merges `get_debug_locals()` into `get_debug_globals()`
- Watch expressions — Can evaluate bytecode-local variable names

### ⏸️ Fix: Break Button and Auto-Connect Not Working When Idle

**Problem:** The Break button in the debugger toolbar only worked if the VG script was actively executing bytecode. If the game was idle (sitting in `_Process` with no VG code running), the Break request was never checked. Additionally, the debug handler didn't auto-connect to the IDE on launch.

**Fix:** Three changes:
1. **`idle_break()` C++ static method** — Checks and clears the break-request flag, raises `SCRIPT_ERROR_BREAKPOINT` if set. Called from GDScript via `vg_idle_break()`.
2. **`_process()` in `vg_debug_handler.gd`** — Calls `vg_idle_break()` every frame, so the Break button works even when the VM is idle.
3. **Auto-refresh in `immediate_window.gd`** — The `_on_scene_poll_timeout()` timer retries connection to the running game, so the debugger panels populate automatically on launch.

Three new bindings exposed: `vg_is_break_requested`, `vg_clear_break_request`, `vg_idle_break`.

### 📋 Fix: Variables Panel Empty After Auto-Connect + Dark Filter Text

**Problem:** Two issues: (1) Even after the auto-connect fix, the Variables panel showed no variables because `get_instance_variables()` didn't include bytecode locals. (2) The filter LineEdit in the Variables panel had dark text on a dark background, making it unreadable.

**Fix:**
1. **`get_instance_variables()`** now calls `get_debug_locals()` and merges the result into the globals Dictionary, so all variables (both instance-level and bytecode-local) appear in the panel.
2. **Filter LineEdit** now has explicit `font_color` (white) and `selection_color` (blue) theme overrides for readability on dark backgrounds.

---

## 🧪 Test Suite

### Test Suite Totals

| Metric | RC4 | RC5 | Change |
|--------|-----|-----|--------|
| Test files | 82 | 83 | +1 |
| Assertions | 646 | 659 | +13 |
| Passed | 644 | 657 | +13 |
| Failed | 2 | 2 | — (pre-existing symlink tests) |

---

## 📁 Files Changed

**29 files changed**, 1178 insertions(+), 989 deletions(-)

### C++ Runtime (6 files)
- `visual_gasic_instance.cpp` — `builtin_constants` Dictionary, `is_builtin_constant()`, `get_debug_locals()`, `get_instance_variables()` merge logic
- `visual_gasic_instance.h` — `debug_bc_locals`/`debug_bc_chunk` pointers, `is_builtin_constant()` accessor, `builtin_constants` member
- `visual_gasic_instance_bytecode_vm.cpp` — 13 code paths updated for `builtin_constants` fallback, sets debug pointers
- `visual_gasic_instance_call.inc` — 4 debugger functions updated to include bytecode locals
- `visual_gasic_language.cpp` — `idle_break()` static method, 3 new bindings (`vg_is_break_requested`, `vg_clear_break_request`, `vg_idle_break`)
- `visual_gasic_language.h` — `idle_break()` declaration

### GDScript (2 files)
- `addons/visual_gasic/immediate_window.gd` — Auto-connect retry in `_on_scene_poll_timeout()`, filter LineEdit color overrides
- `addons/visual_gasic/vg_debug_handler.gd` — `_process()` calls `vg_idle_break()` every frame

### Documentation (17+ files)
- Getting started guides, manual pages, tutorials, and API reference updated

---

## 📊 What's Included in v4.4.0-rc5

- **Full VB6 language** — Dim, Sub/Function, If/Select/For/Do/While, Classes, Enums, Events, With, Error Handling
- **109 built-in constants** — Separated and protected from user code
- **108 built-in functions** — String, math, file I/O, date/time, collections
- **62 VB6 runtime property aliases** — O(1) HashMap dispatch, property change events
- **IntelliSense** — 80+ function completions, 62+ VB6 property completions, snippets, Godot types
- **Debugger** — Conditional breakpoints, Variables panel with bytecode locals, Watch Window with VB6 eval, call stack, Break-when-idle, auto-connect
- **Form Designer** — Drag-and-drop RAD with VB6-style property sheet, auto-wiring
- **66 demo projects** — 2D/3D games, shaders, audio, UI, threading, networking
- **83 test files, 659 assertions** — 99.7% pass rate
- **Linux, Windows, and macOS binaries**

---

## 🙏 Help Us Ship 4.4.0 Stable

We're close. The language works. The debugger works. The Form Designer works. But we need **real users testing real projects** before we can call it stable. If you've read this far, please consider giving it a try — or sharing it with someone who would. Every bug report, feature request, and "hey, this is cool" message helps keep this project alive.

**GitHub**: [https://github.com/xgreenrx-star/VisualGasic](https://github.com/xgreenrx-star/VisualGasic)  
**Issues**: [https://github.com/xgreenrx-star/VisualGasic/issues](https://github.com/xgreenrx-star/VisualGasic/issues)  
**Discussions**: [https://github.com/xgreenrx-star/VisualGasic/discussions](https://github.com/xgreenrx-star/VisualGasic/discussions)
