# VGFormBase Auto-Wiring Guide

## Table of Contents

- [Overview](#overview)
- [How It Works](#how-it-works)
  - [Naming Pattern](#naming-pattern)
  - [Supported Events](#supported-events)
- [Example: Before and After](#example-before-and-after)
  - [❌ OLD WAY (Manual Connection)](#old-way-manual-connection)
  - [✅ NEW WAY (Auto-Wired)](#new-way-auto-wired)
- [Complete Working Example](#complete-working-example)
- [Key Points](#key-points)
- [When Auto-Wiring Occurs](#when-auto-wiring-occurs)
- [Troubleshooting](#troubleshooting)
  - [Events not firing?](#events-not-firing)
- [Benefits](#benefits)
- [Migration from Manual Wiring](#migration-from-manual-wiring)

## Overview

The new WinForms-style forms in Visual Gasic now include **automatic event wiring** - you no longer need to manually call `.connect()` on your controls!

## How It Works

VGFormBase automatically connects control events to handler methods based on **naming conventions**:

### Naming Pattern
```
ControlName_EventType
```

### Supported Events

| Control Type | Signal | Event Suffix | Handler Example |
|-------------|--------|--------------|-----------------|
| Button, CheckBox, etc. | `pressed` | `Click` | `btnOK_Click()` |
| Label | `gui_input` | `Click` | `lblTitle_Click()` |
| Label | `gui_input` | `DblClick` | `lblTitle_DblClick()` |
| Panel | `gui_input` | `Click` | `pnlMain_Click()` |
| Panel | `gui_input` | `DblClick` | `pnlMain_DblClick()` |
| LineEdit, TextEdit | `text_changed` | `Change` | `txtName_Change(newText)` |
| Slider, ScrollBar | `value_changed` | `Change` | `hSlider1_Change(value)` |
| Timer | `timeout` | `Timer` | `Timer1_Timer()` |
| ItemList, OptionButton | `item_selected` | `Click` | `lstItems_Click(index)` |
| MenuBar > PopupMenu | `id_pressed` | `Click` | `mnuFile_Click(id)` |
| Any Control | `focus_entered` | `GotFocus` | `txtName_GotFocus()` |
| Any Control | `focus_exited` | `LostFocus` | `txtName_LostFocus()` |
| Any Control | `mouse_entered` | `MouseMove` | `btnOK_MouseMove()` |
| Any Control | `mouse_exited` | `MouseExit` | `btnOK_MouseExit()` |
| Any Control | `gui_input` (drag) | `DragDrop` | `lstTarget_DragDrop(data, x, y)` |
| Any Control | `gui_input` (drag) | `DragOver` | `lstTarget_DragOver(data, x, y)` |

### Programmatic `_Change` Events

In VB6, the `_Change` event fires not only when the user types in a control, but also when you set a property **programmatically**. VisualGasic matches this behavior:

```vb
' This fires txtName_Change() automatically:
txtName.Text = "Hello"

' This fires lblScore_Change() automatically:
lblScore.Caption = "Score: 100"
```

The `_Change` event fires whenever `Text`, `Caption`, or `Value` is SET on any control — whether by user input (Godot signal) or by code assignment. This works in both the AST interpreter and the bytecode VM.

## Example: Before and After

### ❌ OLD WAY (Manual Connection)
```vbnet
Sub InitializeComponent()
    Set btnOK = Button.new()
    btnOK.name = "btnOK"
    btnOK.text = "OK"
    Me.add_child(btnOK)
    
    ' Manual connection - NOT NEEDED ANYMORE!
    btnOK.pressed.connect(Callable(Me, "btnOK_Click"))
End Sub

Sub btnOK_Click()
    Print "Button clicked"
End Sub
```

### ✅ NEW WAY (Auto-Wired)
```vbnet
Sub InitializeComponent()
    Set btnOK = Button.new()
    btnOK.name = "btnOK"  ' Name is important!
    btnOK.text = "OK"
    Me.add_child(btnOK)
    ' That's it! No .connect() needed
End Sub

' VGFormBase will automatically connect btnOK.pressed to this method
Sub btnOK_Click()
    Print "Button clicked"
End Sub
```

## Complete Working Example

```vbnet
' MyForm.vg
Option Explicit

Dim btnSave As Button
Dim btnCancel As Button
Dim txtName As LineEdit
Dim lblStatus As Label

Sub InitializeComponent()
    Me.Text = "User Form"
    Me.StartPosition = FormStartPositionEnum.CenterScreen
    Me.size = Vector2(400, 300)
    
    ' Label
    Set lblStatus = Label.new()
    lblStatus.name = "lblStatus"
    lblStatus.text = "Enter your name"
    lblStatus.position = Vector2(20, 20)
    Me.add_child(lblStatus)
    
    ' Text input
    Set txtName = LineEdit.new()
    txtName.name = "txtName"
    txtName.position = Vector2(20, 60)
    txtName.size = Vector2(360, 30)
    Me.add_child(txtName)
    
    ' Save button
    Set btnSave = Button.new()
    btnSave.name = "btnSave"
    btnSave.text = "Save"
    btnSave.position = Vector2(220, 240)
    Me.add_child(btnSave)
    
    ' Cancel button
    Set btnCancel = Button.new()
    btnCancel.name = "btnCancel"
    btnCancel.text = "Cancel"
    btnCancel.position = Vector2(310, 240)
    Me.add_child(btnCancel)
End Sub

Sub Form_Load()
    InitializeComponent()
End Sub

' ====== AUTO-WIRED EVENT HANDLERS ======

' Automatically connected to txtName.text_changed
Sub txtName_Change(newText)
    lblStatus.text = "Name: " + newText
End Sub

' Automatically connected to btnSave.pressed
Sub btnSave_Click()
    lblStatus.text = "Saved: " + txtName.text
    Print "Data saved!"
End Sub

' Automatically connected to btnCancel.pressed
Sub btnCancel_Click()
    Me.DialogResult = DialogResultEnum.Cancel
    Me.Close()
End Sub
```

## Key Points

1. **Name your controls properly**: The control's `.name` property must match the prefix of your handler method
2. **Use correct event suffixes**: `_Click`, `_Change`, `_Timer`, etc.
3. **Auto-wiring happens in `_ready()`**: After `Form_Load()` and `InitializeComponent()` complete
4. **Nested controls work**: Controls inside containers are also auto-wired
5. **No manual `.connect()` needed**: VGFormBase handles it automatically

## When Auto-Wiring Occurs

The auto-wiring happens automatically in this sequence:

1. Form is created and added to scene tree
2. `_ready()` is called
3. `Form_Load()` is called
4. Your `InitializeComponent()` runs (controls are created)
5. `call_deferred("_wire_control_events")` runs
6. All controls are scanned and events are auto-connected
7. `Form_Shown()` is called

## Troubleshooting

### Events not firing?

1. **Check control names**: The control's `.name` must match exactly (case-sensitive)
   ```vbnet
   btnOK.name = "btnOK"  ' ✓ Correct
   btnOK.name = "buttonOK"  ' ❌ Won't match btnOK_Click
   ```

2. **Check handler names**: Use correct event suffix
   ```vbnet
   Sub btnOK_Click()  ' ✓ Correct for buttons
   Sub btnOK_Pressed()  ' ❌ Wrong suffix
   ```

3. **Check control type**: Make sure you're using the right event for the control type
   - Buttons use `_Click`
   - TextEdit/LineEdit use `_Change`
   - Timers use `_Timer`

4. **Verify method exists**: The handler method must be defined in your form
   ```vbnet
   Sub btnOK_Click()  ' Must exist for auto-wiring to work
       Print "Clicked"
   End Sub
   ```

## Benefits

✅ **Less code to write** - No manual `.connect()` calls
✅ **VB6-style** - Familiar pattern for Visual Basic developers
✅ **Cleaner code** - Handlers are clearly separated
✅ **WinForms compatible** - Follows Microsoft's proven patterns
✅ **Automatic** - Just name controls and define handlers

## Migration from Manual Wiring

If you have existing forms with manual `.connect()` calls:

1. Remove the `.pressed.connect()` lines from `InitializeComponent()`
2. Ensure control `.name` properties are set correctly
3. Rename handler methods to match naming pattern (if needed)
4. Test that events still fire

That's it! Your forms will now use the automatic event wiring system.

---

---

---

---

## Alphabetical Index

*Quick-jump: [A](#index-a) · [C](#index-c) · [E](#index-e) · [H](#index-h) · [M](#index-m) · [N](#index-n) · [O](#index-o) · [S](#index-s) · [T](#index-t) · [W](#index-w)*


### A {#index-a}

- **Auto-Wired** — [NEW WAY (Auto-Wired)](#new-way-auto-wired)

### C {#index-c}

- **Complete Working Example** — [Complete Working Example](#complete-working-example)

### E {#index-e}

- **Events not firing?** — [Events not firing?](#events-not-firing)
- **Example: Before and After** — [Example: Before and After](#example-before-and-after)

### H {#index-h}

- **How It Works** — [How It Works](#how-it-works)

### M {#index-m}

- **Manual Connection** — [OLD WAY (Manual Connection)](#old-way-manual-connection)
- **Migration from Manual Wiring** — [Migration from Manual Wiring](#migration-from-manual-wiring)

### N {#index-n}

- **Naming Pattern** — [Naming Pattern](#naming-pattern)
- **NEW WAY** — [NEW WAY (Auto-Wired)](#new-way-auto-wired)

### O {#index-o}

- **OLD WAY** — [OLD WAY (Manual Connection)](#old-way-manual-connection)

### S {#index-s}

- **Supported Events** — [Supported Events](#supported-events)

### T {#index-t}

- **Troubleshooting** — [Troubleshooting](#troubleshooting)

### W {#index-w}

- **When Auto-Wiring Occurs** — [When Auto-Wiring Occurs](#when-auto-wiring-occurs)
