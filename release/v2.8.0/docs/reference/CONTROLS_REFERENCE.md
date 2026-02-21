# VisualGasic Controls Reference

This document describes all controls available in the VisualGasic Toolbox.

Every standard control now includes a **VB6 wrapper script** that adds VB6-compatible
property names, method names, and event signals on top of the native Godot node.
You can use either the VB6 names or the native Godot names — both work.

> **Note:** The wrapper scripts only *add* the VB6 API layer.  All underlying Godot
> functionality is fully preserved and accessible.

---

## Standard Controls

These controls are always available in the Toolbox.

---

### Label
**VB6 Name:** Label  
**Godot Node:** Label  
**Wrapper Script:** `vg_label.gd`  
**Description:** Displays static text.

**Properties:**

| VB6 Property | Type | Description |
|-------------|------|-------------|
| `Caption` | String | The label text (alias for `.text`) |
| `Alignment` | Int | 0=Left, 1=Right, 2=Center |
| `AutoSize` | Bool | If true, label resizes to fit its text |
| `WordWrap` | Bool | If true, text wraps to multiple lines |
| `BackStyle` | Int | 0=Transparent (no background), 1=Opaque |
| `BackColor` | Color | Background color when BackStyle=1 |
| `BorderStyle` | Int | 0=None, 1=FixedSingle (thin border) |
| `Tag` | String | General-purpose string storage |

**Events:**

| Signal | Description |
|--------|-------------|
| `Click()` | Label was clicked |
| `DblClick()` | Label was double-clicked |

**Example:**
```vb
Label1.Caption = "Hello World"
Label1.Alignment = 2            ' Center
Label1.BackStyle = 1            ' Opaque background
Label1.BackColor = vbYellow
Label1.BorderStyle = 1          ' Show border
```

---

### TextBox (LineEdit)
**VB6 Name:** TextBox  
**Godot Node:** LineEdit  
**Wrapper Script:** `vg_text_box.gd`  
**Description:** Single-line text input field.

**Properties:**

| VB6 Property | Type | Description |
|-------------|------|-------------|
| `Text` | String | The current text content |
| `PasswordChar` | String | Mask character (e.g. `"*"`), `""` = normal |
| `MaxLength` | Int | Maximum characters (0=unlimited) |
| `Locked` | Bool | If true, text is read-only |
| `Alignment` | Int | 0=Left, 1=Right, 2=Center |
| `SelStart` | Int | Caret position / start of selection |
| `SelLength` | Int | Number of selected characters |
| `SelText` | String | The selected text (set to replace selection) |
| `Tag` | String | General-purpose string storage |

**Methods:**

| Method | Description |
|--------|-------------|
| `SetFocus()` | Give keyboard focus to this control |

**Events:**

| Signal | Description |
|--------|-------------|
| `Change(new_text)` | Text content changed |
| `GotFocus()` | Control received keyboard focus |
| `LostFocus()` | Control lost keyboard focus |

**Example:**
```vb
Text1.Text = "Enter password"
Text1.PasswordChar = "*"
Text1.MaxLength = 20
Text1.Locked = False

' Select all text
Text1.SelStart = 0
Text1.SelLength = Len(Text1.Text)

' Replace selection
Text1.SelText = "new text"

Private Sub Text1_Change(new_text)
    Label1.Caption = "You typed: " & new_text
End Sub

Private Sub Text1_GotFocus()
    Text1.SelStart = 0
    Text1.SelLength = Len(Text1.Text)
End Sub
```

---

### TextArea (TextEdit)
**VB6 Name:** TextBox (MultiLine=True)  
**Godot Node:** TextEdit  
**Description:** Multi-line text input field.

**Properties:**
- `Text` — The current text value
- `ReadOnly` — Prevent user editing
- `WordWrap` — Enable word wrapping

---

### CommandButton (Button)
**VB6 Name:** CommandButton  
**Godot Node:** Button  
**Wrapper Script:** `vg_button.gd`  
**Description:** Clickable button.

**Properties:**

| VB6 Property | Type | Description |
|-------------|------|-------------|
| `Caption` | String | Button text (alias for `.text`) |
| `Style` | Int | 0=Standard (text only), 1=Graphical (can show icon) |
| `Default` | Bool | If true, pressing Enter activates this button |
| `Cancel` | Bool | If true, pressing Escape activates this button |
| `Tag` | String | General-purpose string storage |

**Methods:**

| Method | Description |
|--------|-------------|
| `SetFocus()` | Give keyboard focus to this control |

**Events:**

| Signal | Description |
|--------|-------------|
| `Click()` | Button was pressed |

**Example:**
```vb
Command1.Caption = "OK"
Command1.Default = True          ' Enter key activates

Command2.Caption = "Cancel"
Command2.Cancel = True           ' Escape key activates

Private Sub Command1_Click()
    MsgBox "OK clicked!"
End Sub
```

---

### CheckBox
**VB6 Name:** CheckBox  
**Godot Node:** CheckBox  
**Wrapper Script:** `vg_check_box.gd`  
**Description:** On/off toggle checkbox with optional tri-state (grayed).

**Constants:**

| Constant | Value | Description |
|----------|-------|-------------|
| `vbUnchecked` | 0 | Not checked |
| `vbChecked` | 1 | Checked |
| `vbGrayed` | 2 | Grayed (checked but dimmed) |

**Properties:**

| VB6 Property | Type | Description |
|-------------|------|-------------|
| `Value` | Int | 0=Unchecked, 1=Checked, 2=Grayed |
| `Caption` | String | Text label next to the checkbox |
| `Alignment` | Int | 0=Left (check left of text), 1=Right |
| `Tag` | String | General-purpose string storage |

**Methods:**

| Method | Description |
|--------|-------------|
| `SetFocus()` | Give keyboard focus to this control |

**Events:**

| Signal | Description |
|--------|-------------|
| `Click()` | Checkbox state changed |

**Example:**
```vb
Check1.Caption = "Enable Sound"
Check1.Value = vbChecked         ' 1

If Check1.Value = vbChecked Then
    EnableSound
End If

' Tri-state (grayed)
Check1.Value = vbGrayed          ' 2 — checked but dimmed

Private Sub Check1_Click()
    If Check1.Value = vbChecked Then
        Label1.Caption = "Sound ON"
    Else
        Label1.Caption = "Sound OFF"
    End If
End Sub
```

---

### OptionButton (RadioButton)
**VB6 Name:** OptionButton  
**Godot Node:** CheckBox (in ButtonGroup)  
**Description:** Radio button for single selection from a group.

**Properties:**
- `Caption` / `Text` — Button label
- `Value` / `ButtonPressed` — Selected state

**Events:**
- `Click` — Selection changed

---

### ListBox (ItemList)
**VB6 Name:** ListBox  
**Godot Node:** ItemList  
**Wrapper Script:** `vg_list_box.gd`  
**Description:** Scrollable list of items.

**Properties:**

| VB6 Property | Type | Description |
|-------------|------|-------------|
| `Text` | String | Text of the currently selected item |
| `ListIndex` | Int | Index of the selected item (-1=none) |
| `ListCount` | Int | Number of items (read-only) |
| `Sorted` | Bool | If true, items are kept in alphabetical order |
| `NewIndex` | Int | Index of the most recently added item (read-only) |
| `SelCount` | Int | Number of selected items (for MultiSelect, read-only) |
| `Tag` | String | General-purpose string storage |

**Methods:**

| Method | Description |
|--------|-------------|
| `AddItem(text [, index])` | Insert an item. If Sorted, index is ignored |
| `RemoveItem(index)` | Remove the item at the given index |
| `Clear()` | Remove all items |
| `SetFocus()` | Give keyboard focus to this control |
| `List(index)` | Get the text of an item by index |
| `SetList(index, value)` | Set the text of an item by index |
| `GetItemData(index)` | Get per-item integer data |
| `SetItemData(index, value)` | Set per-item integer data |
| `Selected(index)` | Returns true if item at index is selected (MultiSelect) |

**Events:**

| Signal | Description |
|--------|-------------|
| `Click()` | An item was selected |
| `DblClick()` | An item was double-clicked |

**Example:**
```vb
' Populate a list
List1.Clear
List1.AddItem "Apple"
List1.AddItem "Banana"
List1.AddItem "Cherry"

' Sorted list
List1.Sorted = True
List1.AddItem "Date"             ' Inserted in alphabetical order

' Read selection
Dim sel As String
sel = List1.Text                 ' Text of selected item
Dim idx As Integer
idx = List1.ListIndex            ' Index of selected item

' Per-item data
List1.SetItemData 0, 100
Dim d As Integer
d = List1.GetItemData(0)         ' Returns 100

' Set selection by index
List1.ListIndex = 2

' Set selection by text
List1.Text = "Banana"

Private Sub List1_Click()
    Label1.Caption = "Selected: " & List1.Text
End Sub

Private Sub List1_DblClick()
    MsgBox "You chose: " & List1.Text
End Sub
```

---

### ComboBox
**VB6 Name:** ComboBox  
**Godot Node:** HBoxContainer (custom composite)  
**Wrapper Script:** `vg_combo_box.gd`  
**Description:** Dropdown selection with optional text editing.

**Style Constants:**

| Constant | Value | Description |
|----------|-------|-------------|
| `vbComboDropDown` | 0 | Dropdown combo (editable text + dropdown list) |
| `vbComboSimple` | 1 | Simple combo (editable text + always-visible list) |
| `vbComboDropDownList` | 2 | Dropdown list only (no typing, selection only) |

**Properties:**

| VB6 Property | Type | Description |
|-------------|------|-------------|
| `Style` | Int | 0=DropdownCombo, 1=SimpleCombo, 2=DropdownList |
| `Text` | String | Current text / selected item text |
| `ListIndex` | Int | Index of the selected item (-1=none) |
| `ListCount` | Int | Number of items (read-only) |
| `Sorted` | Bool | If true, items are kept in alphabetical order |
| `Locked` | Bool | If true, the text area is read-only |
| `NewIndex` | Int | Index of the most recently added item (read-only) |
| `Tag` | String | General-purpose string storage |
| `Enabled` | Bool | Whether the control accepts input |

**Methods:**

| Method | Description |
|--------|-------------|
| `AddItem(text [, index])` | Insert an item. If Sorted, index is ignored |
| `RemoveItem(index)` | Remove the item at the given index |
| `Clear()` | Remove all items |
| `SetFocus()` | Give keyboard focus to this control |
| `List(index)` | Get the text of an item by index |
| `SetList(index, value)` | Set the text of an item by index |
| `GetItemData(index)` | Get per-item integer data |
| `SetItemData(index, value)` | Set per-item integer data |

**Events:**

| Signal | Description |
|--------|-------------|
| `item_selected(index)` | An item was clicked (VB6: Click) |
| `text_changed(new_text)` | Text was edited (VB6: Change) |
| `dropdown_opened()` | Dropdown was opened (VB6: DropDown) |

**Example:**
```vb
' Dropdown list (no typing)
Combo1.Style = 2                 ' vbComboDropDownList
Combo1.AddItem "Red"
Combo1.AddItem "Green"
Combo1.AddItem "Blue"
Combo1.ListIndex = 0             ' Select "Red"

' Read current selection
Dim color As String
color = Combo1.Text

' Sorted dropdown with typing
Combo2.Style = 0                 ' vbComboDropDown
Combo2.Sorted = True
Combo2.AddItem "New York"
Combo2.AddItem "Los Angeles"
Combo2.AddItem "Chicago"         ' Auto-sorted alphabetically
```

---

### PictureBox (TextureRect)
**VB6 Name:** PictureBox  
**Godot Node:** TextureRect  
**Description:** Displays an image.

**Properties:**
- `Picture` / `Texture` — Image to display
- `Stretch` — Resize image to fit

---

### Frame / GroupBox (Panel)
**VB6 Name:** Frame  
**Godot Node:** Panel  
**Description:** Container with border for grouping controls.

**Properties:**
- `Caption` — Group title text
- `BorderStyle` — Border appearance

---

### Timer
**VB6 Name:** Timer  
**Godot Node:** Timer  
**Wrapper Script:** `vg_timer.gd`  
**Description:** Triggers events at regular intervals. Non-visual (invisible at runtime).

> **Important:** `Interval` is in **milliseconds** (VB6 convention), not seconds.
> Setting Interval=0 disables the timer.

**Properties:**

| VB6 Property | Type | Description |
|-------------|------|-------------|
| `Interval` | Int | Timer period in milliseconds (1000 = 1 second) |
| `Enabled` | Bool | True=running, False=stopped |
| `Tag` | String | General-purpose string storage |

**Events:**

| Signal | Description |
|--------|-------------|
| `timer_event()` | Fires each time the interval elapses |

**Example:**
```vb
' 1-second timer
Timer1.Interval = 1000
Timer1.Enabled = True

' Stop the timer
Timer1.Enabled = False

' Disable by setting interval to 0
Timer1.Interval = 0

Private Sub Timer1_timer_event()
    ' Runs every 1000ms
    Label1.Caption = Time$
End Sub
```

---

### HScrollBar / VScrollBar
**VB6 Name:** HScrollBar / VScrollBar  
**Godot Node:** HScrollBar / VScrollBar  
**Wrapper Script:** `vg_scroll_bar.gd` (shared by both)  
**Description:** Horizontal or vertical scrollbar.

**Properties:**

| VB6 Property | Type | Description |
|-------------|------|-------------|
| `Min` | Float | Minimum scroll value |
| `Max` | Float | Maximum scroll value |
| `Value` | Float | Current scroll position |
| `SmallChange` | Float | Amount when clicking an arrow button (maps to `step`) |
| `LargeChange` | Float | Amount when clicking the track area (maps to `page`) |
| `Tag` | String | General-purpose string storage |

**Methods:**

| Method | Description |
|--------|-------------|
| `SetFocus()` | Give keyboard focus to this control |

**Events:**

| Signal | Description |
|--------|-------------|
| `Change()` | Value changed (after thumb released) |
| `Scroll()` | Fires continuously while dragging the thumb |

**Example:**
```vb
HScroll1.Min = 0
HScroll1.Max = 255
HScroll1.SmallChange = 1
HScroll1.LargeChange = 16
HScroll1.Value = 128

Private Sub HScroll1_Change()
    Label1.Caption = "Value: " & Str(HScroll1.Value)
End Sub
```

---

## Extended Controls

---

### ProgressBar
**VB6 Name:** ProgressBar  
**Godot Node:** ProgressBar  
**Wrapper Script:** `vg_progress_bar.gd`  
**Description:** Shows progress of an operation.

**Properties:**

| VB6 Property | Type | Description |
|-------------|------|-------------|
| `Min` | Float | Minimum value (alias for `min_value`) |
| `Max` | Float | Maximum value (alias for `max_value`) |
| `Value` | Float | Current progress (inherited from Range) |
| `Tag` | String | General-purpose string storage |

**Example:**
```vb
ProgressBar1.Min = 0
ProgressBar1.Max = 100
ProgressBar1.Value = 50
```

---

### Shape (ColorRect)
**VB6 Name:** Shape  
**Godot Node:** ColorRect  
**Wrapper Script:** `vg_shape.gd`  
**Description:** Draws geometric shapes (rectangle, oval, circle, rounded rect, etc.)  via custom `_draw()`. The ColorRect base is set transparent — all rendering is in the script.

**Shape Type Constants:**

| Constant | Value | Shape |
|----------|-------|-------|
| `vbShapeRectangle` | 0 | Rectangle |
| `vbShapeSquare` | 1 | Square (enforced aspect) |
| `vbShapeOval` | 2 | Oval / Ellipse |
| `vbShapeCircle` | 3 | Circle (enforced aspect) |
| `vbShapeRoundedRectangle` | 4 | Rounded Rectangle |
| `vbShapeRoundedSquare` | 5 | Rounded Square (enforced aspect) |

**Properties:**

| VB6 Property | Type | Description |
|-------------|------|-------------|
| `Shape` | Int | Shape type (0–5, see constants above) |
| `FillColor` | Color | Interior fill color |
| `FillStyle` | Int | 0=Solid (filled), 1=Transparent (outline only) |
| `BorderColor` | Color | Border/outline color |
| `BorderWidth` | Int | Border thickness in pixels (0–20) |
| `BorderStyle` | Int | 0=Transparent (no border), 1=Solid |
| `BackColor` | Color | Alias for FillColor |
| `BackStyle` | Int | 0=Transparent, 1=Opaque (controls whether fill is drawn) |
| `Tag` | String | General-purpose string storage |

**Example:**
```vb
' Blue filled circle with black border
Shape1.Shape = 3                 ' vbShapeCircle
Shape1.FillColor = vbBlue
Shape1.FillStyle = 0             ' Solid
Shape1.BorderColor = vbBlack
Shape1.BorderWidth = 2
Shape1.BorderStyle = 1           ' Solid border

' Red oval outline (no fill)
Shape2.Shape = 2                 ' vbShapeOval
Shape2.FillStyle = 1             ' Transparent (outline only)
Shape2.BorderColor = vbRed
Shape2.BorderWidth = 3

' Rounded rectangle
Shape3.Shape = 4                 ' vbShapeRoundedRectangle
Shape3.FillColor = Color(0.2, 0.8, 0.2)
```

---

### HSlider / VSlider
**VB6 Name:** Slider  
**Godot Node:** HSlider / VSlider  
**Description:** Slider for selecting a value from a range.

**Properties:**
- `Min` — Minimum value (alias for `min_value`)
- `Max` — Maximum value (alias for `max_value`)
- `Value` — Current value
- `Step` — Increment amount

**Events:**
- `Change` — Value changed

---

### SpinBox
**VB6 Name:** UpDown + TextBox  
**Godot Node:** SpinBox  
**Description:** Numeric input with up/down buttons.

**Properties:**
- `Min` — Minimum value
- `Max` — Maximum value
- `Value` — Current value
- `Step` — Increment amount

---

### RichText (RichTextLabel)
**VB6 Name:** RichTextBox  
**Godot Node:** RichTextLabel  
**Description:** Formatted text display with BBCode support.

**Properties:**
- `Text` — Plain text content
- `BBCodeText` — BBCode formatted text
- `BBCodeEnabled` — Enable BBCode parsing

---

### TreeView (Tree)
**VB6 Name:** TreeView  
**Godot Node:** Tree  
**Description:** Hierarchical tree structure.

**Methods:**
- `AddItem(text, parent)` — Add tree item
- `Clear()` — Remove all items

**Events:**
- `NodeSelected` — Item selected

---

### TabStrip (TabContainer)
**VB6 Name:** TabStrip / SSTab  
**Godot Node:** TabContainer  
**Description:** Tabbed container for multiple pages.

**Properties:**
- `CurrentTab` — Active tab index

---

### Files (FileDialog)
**VB6 Name:** CommonDialog  
**Godot Node:** FileDialog  
**Description:** File open/save dialog.

**Properties:**
- `FileName` — Selected file path
- `Filter` — File type filters
- `Title` — Dialog title

---

## 2D Game Controls

### Sprite (Sprite2D)
**Description:** 2D sprite display.

**Properties:**
- `Texture` — Sprite image
- `Position` — X, Y coordinates
- `Scale` — Size multiplier
- `Rotation` — Rotation in radians
- `Flip_H` / `Flip_V` — Mirror horizontally/vertically

---

### AnimatedSprite (AnimatedSprite2D)
**Description:** Animated sprite with multiple frames.

**Properties:**
- `SpriteFrames` — Animation library
- `Animation` — Current animation name
- `Playing` — Whether animation is playing
- `Frame` — Current frame index

**Methods:**
- `Play(animation)` — Play animation
- `Stop()` — Stop animation

---

### Tilemap (TileMapLayer)
**Description:** Tile-based level maps.

**Properties:**
- `TileSet` — Tile definitions

**Methods:**
- `SetCell(x, y, tile)` — Set tile at position
- `GetCell(x, y)` — Get tile at position

---

### RigidBody (RigidBody2D)
**Description:** Physics-enabled body.

**Properties:**
- `Mass` — Object mass
- `LinearVelocity` — Movement velocity
- `AngularVelocity` — Rotation velocity

---

### CharacterBody (CharacterBody2D)
**Description:** Player character with `move_and_slide()`.

**Properties:**
- `Velocity` — Movement velocity
- `UpDirection` — Which direction is "up"

**Methods:**
- `MoveAndSlide()` — Move with collision

---

### Area (Area2D)
**Description:** Collision detection area.

**Events:**
- `BodyEntered` — Body entered area
- `BodyExited` — Body left area

---

### Camera (Camera2D)
**Description:** 2D camera view.

**Properties:**
- `Zoom` — Zoom level
- `Position` — Camera position
- `Current` — Is active camera

---

## 3D Game Controls

### MeshInstance (MeshInstance3D)
**Description:** 3D mesh display.

**Properties:**
- `Mesh` — 3D mesh resource
- `MaterialOverride` — Surface material

---

### RigidBody3D
**Description:** 3D physics body.

**Properties:**
- `Mass` — Object mass
- `LinearVelocity` — Movement velocity

---

### CharacterBody3D
**Description:** 3D player character.

**Properties:**
- `Velocity` — Movement velocity

**Methods:**
- `MoveAndSlide()` — Move with collision

---

### Camera3D
**Description:** 3D camera.

**Properties:**
- `Fov` — Field of view
- `Current` — Is active camera

---

### DirectionalLight3D
**Description:** Sunlight / directional light.

**Properties:**
- `Color` — Light color
- `Energy` — Light intensity

---

### SpotLight3D / OmniLight3D
**Description:** Spotlight or point light.

**Properties:**
- `Color` — Light color
- `Energy` — Light intensity
- `Range` — Light distance

---

### WorldEnvironment
**Description:** Sky, fog, and environment settings.

**Properties:**
- `Environment` — Environment resource

---

### CSGBox3D
**Description:** CSG box primitive for prototyping.

**Properties:**
- `Size` — Box dimensions
- `Material` — Surface material

---

## Optional Components

These controls are available via **Project > Visual Gasic Components...**

### Calendar
**Description:** Month/date picker calendar control.

**Properties:**
- `Value` — Currently selected date (as string "YYYY-MM-DD")
- `Year` — Current year
- `Month` — Current month (1-12)
- `FirstDayOfWeek` — Week start day (0=Sunday, 1=Monday)
- `HighlightToday` — Highlight current date
- `ShowWeekNumbers` — Display week numbers

**Methods:**
- `SetDate(year, month, day)` — Set the selected date
- `GetDate()` — Get selected date as Dictionary
- `GoToToday()` — Navigate to current date

**Events:**
- `DateSelected(date_dict)` — Date was selected
- `MonthChanged(year, month)` — Month navigation changed

---

### StatusBar
**Description:** Status bar with multiple panels.

---

### Toolbar
**Description:** Button toolbar container.

---

### ListView
**Description:** Multi-column list view.

---

### UpDown
**Description:** Spin button control (buddy control for TextBox).

---

### DatePicker
**Description:** Date selection dropdown.

---

### MaskedEdit
**Description:** Text input with input mask.

---

### Winsock
**Description:** Network socket control for TCP/UDP.

---

### Animation
**Description:** Sprite animation control.

---

### ImageCombo
**Description:** ComboBox with images.

---

## Custom Controls

You can add your own custom controls:

1. Create a `.tscn` scene file with your control
2. Open **Project > Visual Gasic Components...**
3. Click **Browse** and select your `.tscn` file
4. The control will appear in the Toolbox

Custom controls are saved to `custom_components.cfg` and persist between sessions.

---

## VB6 Wrapper Scripts Summary

Each wrapper script extends the native Godot class and adds the VB6 API layer.
All 10 wrapper scripts are located in `addons/visual_gasic/`:

| Wrapper Script | Extends | VB6 Control |
|---------------|---------|-------------|
| `vg_label.gd` | Label | Label |
| `vg_text_box.gd` | LineEdit | TextBox |
| `vg_button.gd` | Button | CommandButton |
| `vg_check_box.gd` | CheckBox | CheckBox |
| `vg_list_box.gd` | ItemList | ListBox |
| `vg_combo_box.gd` | HBoxContainer | ComboBox |
| `vg_timer.gd` | Timer | Timer |
| `vg_scroll_bar.gd` | ScrollBar | HScrollBar / VScrollBar |
| `vg_shape.gd` | ColorRect | Shape |
| `vg_progress_bar.gd` | ProgressBar | ProgressBar |

Each prototype `.tscn` in `addons/visual_gasic/prototypes/` references its wrapper script.
When you drag a control from the Toolbox onto the form, the wrapper is automatically attached.

### Common Properties (all wrapped controls)

Every wrapped control has `Tag` (general-purpose string storage, VB6 convention).

The C++ runtime also provides these aliased properties on **all** form controls:

| VB6 Property | Godot Property | Description |
|-------------|---------------|-------------|
| `Text` / `Caption` | `.text` | Display text |
| `Left` | `position.x` | X position |
| `Top` | `position.y` | Y position |
| `Width` | `size.x` | Control width |
| `Height` | `size.y` | Control height |
| `Visible` | `visible` | Whether control is shown |
| `Enabled` | (varies) | Whether control accepts input |
| `BackColor` | (varies) | Background color |
| `ForeColor` | (varies) | Text/foreground color |

---

## VB6 Property Inspector

The **Properties** panel (left dock) shows VB6-style properties for selected controls:

| Property | Description |
|----------|-------------|
| Name | Control name for code access |
| Left | X position |
| Top | Y position |
| Width | Control width |
| Height | Control height |
| Caption/Text | Display text |
| BackColor | Background color |
| ForeColor | Text color |
| Enabled | Whether control accepts input |
| Visible | Whether control is shown |
| TabIndex | Focus order |
| TabStop | Whether control can receive focus |
| ToolTipText | Hover tooltip |

Colors can be entered as:
- Hex: `#FF0000` or `0xFF0000`
- VB6 constants: `vbRed`, `vbBlue`, `vbGreen`, etc.
- RGB: `RGB(255, 0, 0)`
