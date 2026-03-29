# VisualGasic v4.4.0-rc4 Release Notes — VB6 Property System v2

**Release Date**: March 29, 2026  
**Previous Version**: 4.4.0-rc3  
**Status**: **Release Candidate 4** — Comprehensive property system upgrade with 7 new properties, events, IntelliSense, and Watch Window integration

---

## 🏁 Release Candidate 4 — What Changed

RC4 is a **property system overhaul** with 9 focused improvements since RC3. The headline changes are VB6-style output formatting, StringName HashMap dispatch for O(1) property lookups, 7 new runtime properties, property change events, 62+ IntelliSense property completions, and Watch Window VB6 evaluation.

**Upgrade from RC3:** Drop-in replacement — copy `addons/visual_gasic/` over the RC3 version and restart Godot. No migration steps needed.

---

## 🆕 New Features

### 📝 VB6-Style Output Formatting

The Immediate Window and REPL now format output using VB6 conventions:

- Booleans display as `True` / `False` (not `true` / `false`)
- Whole-number floats display without decimals: `100` not `100.0`
- Integers never show `.0` suffix

```vb
? 1 = 1         ' → True   (was "true")
? 100.0          ' → 100    (was "100.0")
? 3.14           ' → 3.14   (unchanged)
```

### 🔍 StringName HashMap Property Dispatch

Property lookups now use a static `HashMap<StringName, int>` for O(1) dispatch:

- **`_vb6_prop_id()`** — Maps all 62 property names to integer IDs at startup
- **Fast-reject** — Unknown property names bail out immediately before any if/else chain
- Both `_vb6_read_property()` and `_vb6_write_property()` use the new fast path

### 🏗️ 7 New Runtime Properties

| Property | Type | Description |
|----------|------|-------------|
| `BackStyle` | Integer | 0 = Transparent, 1 = Opaque (adjusts `self_modulate` alpha) |
| `Appearance` | Integer | 0 = Flat, 1 = 3D (stored as meta `vg_appearance`) |
| `TabIndex` | Integer | Tab order index (stored as meta `vg_tabindex`) |
| `Parent` | Object | Returns the parent node (read-only) |
| `Container` | Object | Alias for Parent (read-only) |
| `Index` | Integer | Control array index (stored as meta `vg_index`) |
| `DragMode` | Integer | 0 = Manual, 1 = Automatic (stored as meta `vg_dragmode`) |

All 7 properties work in both the AST interpreter and bytecode VM paths.

### 🎯 Property Change Events

Setting `Text`, `Caption`, or `Value` programmatically now fires the corresponding `_Change` event handler, matching VB6 behavior:

```vb
' Setting Text fires the _Change handler automatically
txtName.Text = "Hello"     ' → fires Sub txtName_Change()
lblTitle.Caption = "Hi"    ' → fires Sub lblTitle_Change()
```

Works in both the AST interpreter (`call.inc`) and the bytecode VM (`OP_SET_MEMBER`).

### 💡 IntelliSense Property Completions

Typing a dot after any control now suggests all VB6 property aliases:

- **62+ property completions** — Name, Caption, Text, Visible, Enabled, Left, Top, Width, Height, BackColor, ForeColor, FontSize, FontBold, FontItalic, FontName, Tag, ToolTipText, TabStop, TabIndex, MousePointer, BorderStyle, Opacity, ZOrder, Rotation, hWnd, BackStyle, Appearance, Parent, Container, Index, DragMode, and more
- **Type-specific properties** — LineEdit shows MaxLength/PasswordChar/SelStart, Timer shows Interval/OneShot/Autostart, Button shows Style/Flat/ClipText/Icon
- **Common methods** — Show, Hide, Move, SetFocus, Refresh appear in completions

### 👁️ Watch Window VB6 Property Evaluation

Watch expressions now evaluate through the VG Immediate Window engine:

```vb
' In Watch Window:
Me.Text1.Caption    ' → resolves VB6 property correctly
Me.Width            ' → returns form width
lblStatus.ForeColor ' → returns color value
```

Falls back to the simple GDScript evaluator for non-VG expressions.

---

## 🧪 Test Suite Improvements

### New Test Files

| Test File | Assertions | Coverage |
|-----------|-----------|----------|
| `test_me_properties.vg` | 23 | Me.Name, Me.hWnd, Me.Tag, Me.BackStyle, Me.Appearance, Me.TabIndex, Me.DragMode, Me.Index, control-specific properties |
| `test_prop_events.vg` | 5 | _Change event firing on programmatic Text/Caption SET |
| `test_design_persist.vg` | 30+ | Property roundtrip on Button, Label, Timer, LineEdit, Panel |
| `run_immediate_test.gd` (expanded) | 53 (was 34) | VB6 formatting, new properties, compound expressions, error handling |

### Test Suite Totals

| Metric | RC3 | RC4 | Change |
|--------|-----|-----|--------|
| Test files | 75 | 82 | +7 |
| Assertions | 578 | 646 | +68 |
| Passed | 576 | 644 | +68 |
| Failed | 2 | 2 | — (symlink tests) |

---

## 📁 Files Changed

### C++ Runtime (6 files)
- `visual_gasic_instance.cpp` — `_vb6_prop_id()` HashMap, `_vb6_format_variant()`, 7 new properties in read/write helpers
- `visual_gasic_instance.h` — New method declarations
- `visual_gasic_instance_bytecode_vm.cpp` — `OP_SET_MEMBER` _Change event firing
- `visual_gasic_instance_call.inc` — AST _Change event firing on property SET
- `visual_gasic_instance_evaluate.inc` — Updated comment (62 aliases)
- `visual_gasic_language.cpp` — 62+ IntelliSense property completions, type-specific methods

### GDScript (1 file)
- `addons/visual_gasic/immediate_window.gd` — Watch Window `_eval_vg_immediate()` integration

### Tests (4 new files)
- `test_me_properties.vg`, `test_prop_events.vg`, `test_design_persist.vg`
- `run_immediate_test.gd` (expanded)

---

## 📊 What's Included in v4.4.0-rc4

- **Full VB6 language** — Dim, Sub/Function, If/Select/For/Do/While, Classes, Enums, Events, With, Error Handling
- **108 built-in functions** — String, math, file I/O, date/time, collections
- **62 VB6 runtime property aliases** — O(1) HashMap dispatch, property change events
- **IntelliSense** — 80+ function completions, 62+ VB6 property completions, snippets, Godot types
- **Debugger** — Conditional breakpoints, Watch Window with VB6 eval, call stack, time-travel
- **Form Designer** — Drag-and-drop RAD with VB6-style property sheet, auto-wiring
- **66 demo projects** — 2D/3D games, shaders, audio, UI, threading, networking
- **82 test files, 646 assertions** — 99.7% pass rate
- **Linux, Windows, and macOS binaries**
