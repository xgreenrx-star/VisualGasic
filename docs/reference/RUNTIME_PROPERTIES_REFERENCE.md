# VisualGasic Runtime Properties Reference

This document lists every VB6 property that the VisualGasic bytecode VM handles
at **runtime** — i.e. properties you can read and write in your `.vg` code at
run time, not just at design time in the Properties panel.

All 62 property aliases are resolved inside the C++ `OP_GET_MEMBER` and
`OP_SET_MEMBER` handlers, so they work on any Godot `Control`, `Window`, or
`Node` that the corresponding Godot property applies to.

> **Performance:** Property names are resolved via a static `HashMap<StringName, int>`
> (`_vb6_prop_id()`) for O(1) lookup. Unknown property names are fast-rejected
> before any if/else chain, so non-VB6 Godot property access has near-zero overhead.

> **Design-time properties** (the Properties panel in the Form Designer) are
> documented in [CONTROLS_REFERENCE.md](CONTROLS_REFERENCE.md).
> This page covers **runtime** access only.

---

## Table of Contents

- [Common Properties (All Controls)](#common-properties-all-controls)
- [Font Properties](#font-properties)
- [TextBox / TextArea Properties](#textbox--textarea-properties)
- [Selection Properties](#selection-properties)
- [Button Properties](#button-properties)
- [Picture / Icon Properties](#picture--icon-properties)
- [Timer Properties](#timer-properties)
- [ListBox / ComboBox Properties](#listbox--combobox-properties)
- [Layout Properties](#layout-properties)
- [Form / Window Properties](#form--window-properties)
- [Container & Index Properties](#container--index-properties)
- [Miscellaneous Properties](#miscellaneous-properties)
- [Custom Control Properties (VG_Properties)](#custom-control-properties-vg_properties)
- [Quick Reference Table](#quick-reference-table)

---

## Common Properties (All Controls)

These work on every control type placed on a form.

| VB6 Property | Godot Mapping | Type | Read | Write | Notes |
|---|---|---|:---:|:---:|---|
| `Text` / `Caption` | `.text` | String | ✅ | ✅ | Display text on any control |
| `Visible` | `.visible` | Bool | ✅ | ✅ | Show / hide the control |
| `Enabled` | `.disabled` (inverted) | Bool | ✅ | ✅ | `True` = accepts input; uses `editable` fallback for TextBox |
| `Left` | `position.x` | Number | ✅ | ✅ | Horizontal position in pixels |
| `Top` | `position.y` | Number | ✅ | ✅ | Vertical position in pixels |
| `Width` | `size.x` | Number | ✅ | ✅ | Control width in pixels |
| `Height` | `size.y` | Number | ✅ | ✅ | Control height in pixels |
| `BackColor` | StyleBoxFlat `bg_color` | Color | ✅ | ✅ | Background color; overrides all button states |
| `ForeColor` | theme `font_color` | Color | ✅ | ✅ | Text / foreground color |
| `FontSize` | theme `font_size` | Number | ✅ | ✅ | Font size in pixels |
| `Value` | `.value` | Number | ✅ | ✅ | For sliders, spinboxes, progress bars, checkboxes |
| `ToolTipText` | `.tooltip_text` | String | ✅ | ✅ | Hover tooltip |
| `TabStop` | `.focus_mode` | Bool | ✅ | ✅ | `True` = FOCUS_ALL, `False` = FOCUS_NONE |
| `Opacity` | `modulate.a` | Number | ✅ | ✅ | 0–100 (VB6 scale); maps to 0.0–1.0 |
| `MousePointer` | `.mouse_default_cursor_shape` | Enum | ✅ | ✅ | Cursor shape constant |
| `Locked` | `!editable` | Bool | ✅ | ✅ | Inverted: `Locked = True` → `editable = false` |
| `MaxLength` | `.max_length` | Number | ✅ | ✅ | LineEdit character limit |
| `Alignment` | `.horizontal_alignment` | Enum | ✅ | ✅ | Text alignment |
| `WordWrap` | `.autowrap_mode` | Bool | ✅ | ✅ | `True` = AUTOWRAP_WORD_SMART |
| `Tag` | meta `vg_tag` | Variant | ✅ | ✅ | General-purpose user data (any type) |
| `Name` | node `.name` | String | ✅ | ✅ | The node's name in the scene tree |
| `hWnd` | `instance_id` | Int64 | ✅ | ❌ | Read-only unique object handle |

### Code Example — Common Properties

```vb
Sub Form_Load()
    Me.btnPlay.Caption = "Start"
    Me.btnPlay.Left = 100
    Me.btnPlay.Top = 50
    Me.btnPlay.Width = 200
    Me.btnPlay.Height = 40
    Me.btnPlay.Enabled = True
    Me.btnPlay.BackColor = vbGreen
    Me.btnPlay.ForeColor = vbWhite
    Me.btnPlay.ToolTipText = "Click to start the game"
    Me.btnPlay.Tag = "player_action"
    Me.btnPlay.Opacity = 80   ' 80% opaque
End Sub
```

---

## Font Properties

Change fonts at runtime using `FontVariation` and `SystemFont` under the hood.

| VB6 Property | Godot Mapping | Type | Read | Write | Notes |
|---|---|---|:---:|:---:|---|
| `FontBold` | FontVariation `embolden` | Bool | ✅ | ✅ | SET creates/modifies FontVariation with embolden 1.2 |
| `FontItalic` | FontVariation `variation_transform` skew | Bool | ✅ | ✅ | SET applies a 0.2 skew transform for italic |
| `FontName` | SystemFont `font_names` | String | ✅ | ✅ | SET creates a new SystemFont; preserves bold/italic |
| `FontUnderline` | meta `vg_font_underline` | Bool | ✅ | ✅ | Stored as node metadata (no native Godot underline on Control fonts) |
| `FontStrikethrough` | meta `vg_font_strikethrough` | Bool | ✅ | ✅ | Stored as node metadata |

### Code Example — Font Properties

```vb
Sub Form_Load()
    Me.lblTitle.FontName = "Arial"
    Me.lblTitle.FontSize = 24
    Me.lblTitle.FontBold = True
    Me.lblTitle.FontItalic = False
    Me.lblTitle.FontUnderline = True
End Sub

Sub btnToggleBold_Click()
    Me.txtInput.FontBold = Not Me.txtInput.FontBold
End Sub
```

### How Font Properties Work Internally

When you set `FontBold = True`, the VM:
1. Gets the current theme font override on the control
2. If it's already a `FontVariation`, modifies its `embolden` property
3. If not, creates a new `FontVariation`, sets the existing font as its base, and applies embolden
4. Applies the result as a theme font override

When you set `FontName`, the VM:
1. Creates a new `SystemFont` with the specified family name
2. If the control already has a `FontVariation` (with bold/italic), it preserves those settings by creating a new `FontVariation` wrapping the new `SystemFont`
3. This means `FontBold`, `FontItalic`, and `FontName` can be set independently in any order

---

## TextBox / TextArea Properties

| VB6 Property | Godot Mapping | Type | Read | Write | Notes |
|---|---|---|:---:|:---:|---|
| `MultiLine` | (type check) | Bool | ✅ | ❌ | Returns `True` if the control is a TextEdit, `False` for LineEdit |
| `ScrollBars` | meta `vg_scrollbars` | Enum | ✅ | ✅ | 0=None, 1=Horiz, 2=Vert, 3=Both (stored as meta; Godot TextEdit has limited scroll control) |
| `PasswordChar` | LineEdit `.secret` + `.secret_character` | String | ✅ | ✅ | Empty = normal; any character = masked input |
| `PlaceholderText` | `.placeholder_text` | String | ✅ | ✅ | Grayed-out hint when field is empty |
| `Editable` | `.editable` | Bool | ✅ | ✅ | Direct (not inverted, unlike `Locked`) |

### Code Example — TextBox Properties

```vb
Sub Form_Load()
    ' Set up a password field
    Me.txtPassword.PasswordChar = "*"
    Me.txtPassword.MaxLength = 20
    Me.txtPassword.PlaceholderText = "Enter password..."

    ' Make a read-only output area
    Me.txtOutput.Editable = False
    Me.txtOutput.Locked = True

    ' Check if multi-line
    If Me.txtNotes.MultiLine Then
        Debug.Print "Notes field supports multiple lines"
    End If
End Sub
```

---

## Selection Properties

Read and manipulate text selection in LineEdit and TextEdit controls.

| VB6 Property | Godot Mapping | Type | Read | Write | Notes |
|---|---|---|:---:|:---:|---|
| `SelStart` | `.caret_column` | Number | ✅ | ✅ | Caret position / selection start column |
| `SelLength` | (calculated from selection) | Number | ✅ | ✅ | SET selects N characters from current caret |
| `SelText` | `.get_selected_text()` | String | ✅ | ✅ | GET returns selected text; SET replaces selection (or inserts at caret) |

### Code Example — Selection Properties

```vb
Sub btnSelectAll_Click()
    Me.txtInput.SelStart = 0
    Me.txtInput.SelLength = Len(Me.txtInput.Text)
End Sub

Sub btnInsert_Click()
    ' Insert text at the current caret position
    Me.txtInput.SelText = "Hello "
End Sub

Sub btnReplaceSelection_Click()
    ' Replace whatever is selected
    If Me.txtInput.SelLength > 0 Then
        Me.txtInput.SelText = "[REDACTED]"
    End If
End Sub

Sub btnShowSelection_Click()
    Debug.Print "Selected: " & Me.txtInput.SelText
    Debug.Print "Start: " & Me.txtInput.SelStart
    Debug.Print "Length: " & Me.txtInput.SelLength
End Sub
```

---

## Button Properties

| VB6 Property | Godot Mapping | Type | Read | Write | Notes |
|---|---|---|:---:|:---:|---|
| `Style` / `Flat` | Button `.flat` | Bool | ✅ | ✅ | `True` = no 3D border (flat appearance) |
| `ClipText` | Button `.clip_text` | Bool | ✅ | ✅ | Clip text that overflows the button area |
| `Icon` | Button `.icon` | Texture / String | ✅ | ✅ | SET accepts a file path string (auto-loaded) or a Texture2D object |

### Code Example — Button Properties

```vb
Sub Form_Load()
    Me.btnStart.Style = True       ' Flat style
    Me.btnStart.Icon = "res://icons/play.png"
    Me.btnStart.ClipText = True
End Sub
```

---

## Picture / Icon Properties

| VB6 Property | Godot Mapping | Type | Read | Write | Notes |
|---|---|---|:---:|:---:|---|
| `Picture` | TextureRect `.texture` | Texture / String | ✅ | ✅ | For TextureRect: loads from path; for others: stored as `vg_picture_path` meta |
| `Icon` | Button `.icon` | Texture / String | ✅ | ✅ | Button icon texture |

### Code Example — Picture

```vb
Sub Form_Load()
    Me.picAvatar.Picture = "res://images/player.png"
End Sub

Sub btnChangeImage_Click()
    Me.picAvatar.Picture = "res://images/player_alt.png"
End Sub
```

---

## Timer Properties

| VB6 Property | Godot Mapping | Type | Read | Write | Notes |
|---|---|---|:---:|:---:|---|
| `Interval` | Timer `.wait_time` | Number | ✅ | ✅ | **Milliseconds** (VB6) ↔ **seconds** (Godot); auto-converted |
| `OneShot` | Timer `.one_shot` | Bool | ✅ | ✅ | Fire once then stop |
| `Autostart` | Timer `.autostart` | Bool | ✅ | ✅ | Start automatically when added to scene |

### Code Example — Timer Properties

```vb
Sub Form_Load()
    Me.tmrEnemy.Interval = 2000   ' Fire every 2 seconds
    Me.tmrEnemy.OneShot = False   ' Repeating
End Sub

Sub tmrEnemy_Timer()
    ' Spawn an enemy every 2 seconds
    SpawnEnemy
End Sub

Sub btnFaster_Click()
    ' Speed up the timer
    Dim current As Integer
    current = Me.tmrEnemy.Interval
    If current > 500 Then
        Me.tmrEnemy.Interval = current - 250
    End If
End Sub
```

---

## ListBox / ComboBox Properties

| VB6 Property | Godot Mapping | Type | Read | Write | Notes |
|---|---|---|:---:|:---:|---|
| `ListCount` | `.item_count` / `.get_item_count()` | Number | ✅ | ❌ | Read-only count of items (ItemList and OptionButton) |
| `ListIndex` | selected item index | Number | ✅ | ✅ | GET returns first selected index (-1 if none); SET selects the item |
| `Sorted` | meta `vg_sorted` | Bool | ✅ | ✅ | SET to `True` sorts items and stores flag; ItemList uses `sort_items_by_text()` |

### Code Example — ListBox

```vb
Sub Form_Load()
    Me.lstItems.Sorted = True
End Sub

Sub btnShowCount_Click()
    Debug.Print "Items: " & Me.lstItems.ListCount
    Debug.Print "Selected: " & Me.lstItems.ListIndex
End Sub

Sub btnSelectFirst_Click()
    If Me.lstItems.ListCount > 0 Then
        Me.lstItems.ListIndex = 0
    End If
End Sub
```

---

## Layout Properties

| VB6 Property | Godot Mapping | Type | Read | Write | Notes |
|---|---|---|:---:|:---:|---|
| `AutoSize` | Label: `!clip_text` + `autowrap_mode=OFF` | Bool | ✅ | ✅ | Label auto-resizes to fit content |
| `BorderStyle` | StyleBoxFlat border widths | Enum | ✅ | ✅ | 0=None, 1=FixedSingle (1px black border) |

### Code Example — Layout

```vb
Sub Form_Load()
    Me.lblStatus.AutoSize = True
    Me.txtInput.BorderStyle = 1   ' FixedSingle — 1px black border
End Sub
```

---

## Form / Window Properties

These apply to the form itself (the `Window` node). Access via `Form1.Property` or `Me.Property` when no control is specified.

| VB6 Property | Godot Mapping | Type | Read | Write | Notes |
|---|---|---|:---:|:---:|---|
| `WindowState` | Window `.mode` | Enum | ✅ | ✅ | 0=Normal, 1=Minimized, 2=Maximized |
| `ShowInTaskbar` | Window `FLAG_NO_FOCUS` (inverted) | Bool | ✅ | ✅ | `True` = visible in taskbar |
| `Moveable` | Window `FLAG_RESIZE_DISABLED` (inverted) | Bool | ✅ | ✅ | `True` = user can move/resize the form |
| `MinButton` | Window `FLAG_RESIZE_DISABLED` (inverted) | Bool | ✅ | ✅ | Show minimize button |
| `MaxButton` | Window `FLAG_RESIZE_DISABLED` (inverted) | Bool | ✅ | ✅ | Show maximize button |
| `ControlBox` | Window `FLAG_BORDERLESS` (inverted) | Bool | ✅ | ✅ | `True` = show title bar with close/min/max |

### Code Example — Form Properties

```vb
Sub Form_Load()
    Me.Caption = "My Application"
    Me.WindowState = 0  ' Normal
    Me.ControlBox = True
    Me.MinButton = True
    Me.MaxButton = True
    Me.Moveable = True
    Me.BackColor = vbWhite
End Sub

Sub btnMaximize_Click()
    Me.WindowState = 2  ' Maximized
End Sub

Sub btnMinimize_Click()
    Me.WindowState = 1  ' Minimized
End Sub
```

---

## Container & Index Properties

These properties provide container relationships and control-array-style indexing.

| VB6 Property | Godot Mapping | Type | Read | Write | Notes |
|---|---|---|:---:|:---:|---|
| `BackStyle` | meta `vg_backstyle` | Number | ✅ | ✅ | 0 = Transparent, 1 = Opaque; writing 0 sets `self_modulate.a = 0` |
| `Appearance` | meta `vg_appearance` | Number | ✅ | ✅ | 0 = Flat, 1 = 3D; stored as metadata |
| `TabIndex` | meta `vg_tabindex` | Number | ✅ | ✅ | Tab-order index for the control |
| `Parent` | `get_parent()` | Object | ✅ | ❌ | Returns the parent node (read-only) |
| `Container` | `get_parent()` | Object | ✅ | ❌ | Alias for Parent (read-only) |
| `Index` | meta `vg_index` | Number | ✅ | ✅ | Control array index; stored as metadata |
| `DragMode` | meta `vg_dragmode` | Number | ✅ | ✅ | 0 = Manual, 1 = Automatic; stored as metadata |

### Code Example — Container & Index Properties

```vb
Sub Form_Load()
    ' Check transparency
    If Me.lblOverlay.BackStyle = 0 Then
        Print "Label is transparent"
    End If
    Me.lblOverlay.BackStyle = 1   ' Make opaque

    ' Navigate parent
    Dim p As Object
    Set p = Me.btnOK.Parent
    Print p.Name   ' Prints the form's name

    ' Control array indexing
    Me.optChoice.Index = 0
    Me.optChoice2.Index = 1

    ' Tab order
    Me.txtFirst.TabIndex = 0
    Me.txtLast.TabIndex = 1
    Me.btnSubmit.TabIndex = 2
End Sub
```

---

## Miscellaneous Properties

| VB6 Property | Godot Mapping | Type | Read | Write | Notes |
|---|---|---|:---:|:---:|---|
| `ZOrder` | `.z_index` | Number | ✅ | ✅ | Drawing order (higher = on top) |
| `Rotation` | `rotation` (degrees ↔ radians) | Number | ✅ | ✅ | Rotation in degrees; auto-converted to/from Godot radians |

### Code Example — Misc

```vb
Sub Form_Load()
    Me.imgStar.Rotation = 45   ' Rotate 45 degrees
    Me.imgStar.ZOrder = 10     ' Draw on top
End Sub

Sub tmrSpin_Timer()
    Me.imgStar.Rotation = Me.imgStar.Rotation + 5
End Sub
```

---

## Custom Control Properties (VG_Properties)

Custom controls can expose **arbitrary VB6 property names** that map to Godot
properties on the control itself or on its children. This is done via a
`VG_Properties` metadata Dictionary on the control's root node.

Both GET (read) and SET (write) are fully supported.

### How It Works

When you access a property on a control (e.g. `Me.HealthBar1.Health`), the
VM checks — in order:

1. **Built-in VB6 aliases** (the 62 properties listed above)
2. **VG_Properties dictionary** (custom mappings from the control's metadata)
3. **Native Godot properties** (direct obj.get / obj.set)
4. **Child node lookup** (find_child fallback)

The `VG_Properties` dictionary is checked at step 2, so custom property names
can shadow native Godot names if needed.

### Dictionary Format

```
{
    "VB6PropertyName": "godot_property",           # on self
    "VB6PropertyName": "ChildNodeName:godot_prop"  # on a child node
}
```

- **On self** — `"Health": "value"` maps `Me.ctrl.Health` → `ctrl.value`
- **On child** — `"BarColor": "Fill:self_modulate"` maps `Me.ctrl.BarColor` → `ctrl/Fill.self_modulate`

The child can be specified by name (uses `find_child`) or by relative path
(uses `get_node_or_null`).

### Step-by-Step: Exposing Custom Properties

See the [Custom Controls Guide](../guides/CUSTOM_CONTROLS.md#exposing-runtime-properties-vg_properties)
for a complete walkthrough with screenshots.

### Quick Example

**GDScript on the custom control:**
```gdscript
# health_bar.gd — attached to root PanelContainer
extends PanelContainer

@export var max_health: float = 100.0

func _ready():
    set_meta("VG_Properties", {
        "Health":     "ProgressBar:value",
        "MaxHealth":  "ProgressBar:max_value",
        "BarColor":   "ProgressBar:self_modulate",
        "LabelText":  "Label:text",
        "ShowLabel":  "Label:visible"
    })

    $ProgressBar.max_value = max_health
    $ProgressBar.value = max_health
```

**VB6 code using the custom control:**
```vb
Sub Form_Load()
    Me.HealthBar1.MaxHealth = 200
    Me.HealthBar1.Health = 200
    Me.HealthBar1.LabelText = "Player HP"
    Me.HealthBar1.BarColor = vbGreen
End Sub

Sub tmrPoison_Timer()
    Dim hp As Integer
    hp = Me.HealthBar1.Health
    hp = hp - 5
    If hp < 0 Then hp = 0
    Me.HealthBar1.Health = hp

    ' Change color based on health
    If hp < 50 Then
        Me.HealthBar1.BarColor = vbYellow
    End If
    If hp < 20 Then
        Me.HealthBar1.BarColor = vbRed
    End If
End Sub
```

---

## Quick Reference Table

All 62 runtime properties in one table.

| # | VB6 Property | Category | Read | Write | Applies To |
|---|---|---|:---:|:---:|---|
| 1 | `Text` / `Caption` | Common | ✅ | ✅ | All |
| 2 | `Visible` | Common | ✅ | ✅ | All |
| 3 | `Enabled` | Common | ✅ | ✅ | All |
| 4 | `Left` | Common | ✅ | ✅ | All Controls |
| 5 | `Top` | Common | ✅ | ✅ | All Controls |
| 6 | `Width` | Common | ✅ | ✅ | All Controls |
| 7 | `Height` | Common | ✅ | ✅ | All Controls |
| 8 | `BackColor` | Common | ✅ | ✅ | All Controls + Forms |
| 9 | `ForeColor` | Common | ✅ | ✅ | All Controls |
| 10 | `FontSize` | Common | ✅ | ✅ | All Controls |
| 11 | `Value` | Common | ✅ | ✅ | Range controls, CheckBox |
| 12 | `ToolTipText` | Common | ✅ | ✅ | All Controls |
| 13 | `TabStop` | Common | ✅ | ✅ | All Controls |
| 14 | `Opacity` | Common | ✅ | ✅ | All Controls |
| 15 | `MousePointer` | Common | ✅ | ✅ | All Controls |
| 16 | `Locked` | Common | ✅ | ✅ | TextBox, TextArea |
| 17 | `MaxLength` | Common | ✅ | ✅ | TextBox |
| 18 | `Alignment` | Common | ✅ | ✅ | Label, TextBox |
| 19 | `WordWrap` | Common | ✅ | ✅ | Label |
| 20 | `Tag` | Common | ✅ | ✅ | All |
| 21 | `Name` | Common | ✅ | ✅ | All Nodes |
| 22 | `hWnd` | Common | ✅ | ❌ | All Objects |
| 23 | `FontBold` | Font | ✅ | ✅ | All Controls |
| 24 | `FontItalic` | Font | ✅ | ✅ | All Controls |
| 25 | `FontName` | Font | ✅ | ✅ | All Controls |
| 26 | `FontUnderline` | Font | ✅ | ✅ | All Controls |
| 27 | `FontStrikethrough` | Font | ✅ | ✅ | All Controls |
| 28 | `MultiLine` | TextBox | ✅ | ❌ | TextBox / TextArea |
| 29 | `ScrollBars` | TextBox | ✅ | ✅ | TextArea |
| 30 | `PasswordChar` | TextBox | ✅ | ✅ | TextBox (LineEdit) |
| 31 | `PlaceholderText` | TextBox | ✅ | ✅ | TextBox, TextArea |
| 32 | `Editable` | TextBox | ✅ | ✅ | TextBox, TextArea |
| 33 | `SelStart` | Selection | ✅ | ✅ | TextBox, TextArea |
| 34 | `SelLength` | Selection | ✅ | ✅ | TextBox, TextArea |
| 35 | `SelText` | Selection | ✅ | ✅ | TextBox, TextArea |
| 36 | `Style` / `Flat` | Button | ✅ | ✅ | Button |
| 37 | `ClipText` | Button | ✅ | ✅ | Button |
| 38 | `Icon` | Button | ✅ | ✅ | Button |
| 39 | `Picture` | Picture | ✅ | ✅ | PictureBox (TextureRect) |
| 40 | `Interval` | Timer | ✅ | ✅ | Timer |
| 41 | `OneShot` | Timer | ✅ | ✅ | Timer |
| 42 | `Autostart` | Timer | ✅ | ✅ | Timer |
| 43 | `ListCount` | List | ✅ | ❌ | ListBox, ComboBox |
| 44 | `ListIndex` | List | ✅ | ✅ | ListBox, ComboBox |
| 45 | `Sorted` | List | ✅ | ✅ | ListBox |
| 46 | `AutoSize` | Layout | ✅ | ✅ | Label |
| 47 | `BorderStyle` | Layout | ✅ | ✅ | All Controls |
| 48 | `WindowState` | Form | ✅ | ✅ | Form (Window) |
| 49 | `ShowInTaskbar` | Form | ✅ | ✅ | Form (Window) |
| 50 | `Moveable` | Form | ✅ | ✅ | Form (Window) |
| 51 | `MinButton` | Form | ✅ | ✅ | Form (Window) |
| 52 | `MaxButton` | Form | ✅ | ✅ | Form (Window) |
| 53 | `ControlBox` | Form | ✅ | ✅ | Form (Window) |
| 54 | `ZOrder` | Misc | ✅ | ✅ | All Controls |
| 55 | `Rotation` | Misc | ✅ | ✅ | All Controls |
| 56 | `BackStyle` | Container | ✅ | ✅ | All Controls |
| 57 | `Appearance` | Container | ✅ | ✅ | All Controls |
| 58 | `TabIndex` | Container | ✅ | ✅ | All Controls |
| 59 | `Parent` | Container | ✅ | ❌ | All Nodes |
| 60 | `Container` | Container | ✅ | ❌ | All Nodes |
| 61 | `Index` | Container | ✅ | ✅ | All Controls |
| 62 | `DragMode` | Container | ✅ | ✅ | All Controls |
| — | *(custom)* | VG_Properties | ✅ | ✅ | Custom Controls |
