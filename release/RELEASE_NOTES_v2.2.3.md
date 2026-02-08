# VisualGasic v2.2.3 Release Notes

**Release Date:** February 7, 2026  
**Type:** Bugfix Release

## Overview

This bugfix release focuses on VB6-style control property access, making it possible to directly manipulate form controls using familiar VB6 syntax like `txtTest.Text = "Hello World"`.

---

## 🐛 Bug Fixes

### VB6-Style Control Property Access Now Works at Runtime

**Problem:** Writing code like `txtTest.Text = "Hello World"` in a Button_Click event would not update the LineEdit control, even though the event fired correctly.

**Root Cause:** The bytecode compiler created local variable slots for control names like `txtTest`. At runtime, `OP_GET_LOCAL` returned NIL because the slot was never initialized with the actual control reference.

**Solution:** 
- `OP_GET_LOCAL` now checks if the local slot value is NIL, and if so, searches for a child control by that name using `find_child()`
- `OP_GET_GLOBAL` also searches for child controls when a variable is not found in the variables map

---

## ✨ New Features

### VB6 Property Aliasing

Common VB6 property names are now automatically mapped to their Godot equivalents:

| VB6 Property | Godot Property | Supported Controls |
|-------------|----------------|-------------------|
| `Text` | `text` | LineEdit, Label, Button, TextEdit, RichTextLabel |
| `Caption` | `text` | Label, Button, Window |
| `Visible` | `visible` | All Control nodes |
| `Enabled` | `disabled` (inverted) | All Control nodes |
| `Left` | `position.x` | All Control nodes |
| `Top` | `position.y` | All Control nodes |
| `Width` | `size.x` | All Control nodes |
| `Height` | `size.y` | All Control nodes |
| `Value` | `value` | Slider, SpinBox, ProgressBar |

### Example Usage

```vb
Sub Button1_Click()
    ' Set text on a LineEdit
    txtName.Text = "Hello World"
    
    ' Set caption on a Label
    lblStatus.Caption = "Ready"
    
    ' Toggle visibility
    txtPassword.Visible = False
    
    ' Disable a button
    btnSubmit.Enabled = False
    
    ' Position and size controls
    txtName.Left = 100
    txtName.Top = 50
    txtName.Width = 200
    txtName.Height = 30
    
    ' Read properties
    Dim x As Integer
    x = txtName.Left
    Print "Control is at x=" & x
End Sub
```

---

## 🔧 Technical Details

### Files Modified

- `src/visual_gasic_instance.cpp`
  - `OP_GET_LOCAL`: Added child control lookup when local slot is NIL
  - `OP_GET_GLOBAL`: Added child control lookup when variable not found
  - `OP_GET_MEMBER`: Added VB6 property aliasing for reads
  - `OP_SET_MEMBER`: Added VB6 property aliasing for writes

### Bytecode VM Behavior Change

When the bytecode VM encounters a variable name that:
1. Is stored in a local slot but has NIL value, OR
2. Is not found in the global variables map

It now searches the form's child nodes recursively using `find_child(name, true, false)` to locate controls by name. This enables VB6-style direct control access without requiring explicit variable declarations.

---

## 📋 Compatibility

- **Godot Version:** 4.5.1
- **Platforms:** Linux (x86_64), Windows, macOS
- **Backward Compatible:** Yes - existing code continues to work

---

## 🔄 Upgrade Notes

No breaking changes. Simply update the library to enable VB6-style control property access.

---

## 📝 Known Limitations

- `BackColor` and `ForeColor` map to `self_modulate` which may not produce exact VB6 color behavior
- Complex property paths like `txtName.Font.Size` are not yet supported
- Control names must match exactly (case-insensitive matching uses the control's actual name)
