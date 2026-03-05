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
4. The control will appear in the Toolbox with a **gear ⚙ icon** (generic fallback)
5. *(Optional)* To give it a unique icon, add an SVG entry to `vb6_toolbox_icons.gd` keyed to the control's name

Custom controls are saved to `custom_components.cfg` and persist between sessions.

**Bundled custom control icons:** WobblyButton and WobblyPanel ship with specific SVG icons. All other custom controls use the generic gear fallback. See the [Custom Toolbox Icons](../tutorials/custom_wobbly_form.md#custom-toolbox-icons) section for details on creating your own.

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

## Form Designer Properties Reference

The **Properties** panel shows VB6-style properties organized into categories.
Select any control on the canvas and these properties appear in the right-hand panel.
Toggle between **A–Z** (alphabetic) and **≡** (categorized) views.

Colors can be entered as:
- Hex: `#FF0000` or `0xFF0000`
- VB6 constants: `vbRed`, `vbBlue`, `vbGreen`, etc.
- RGB: `RGB(255, 0, 0)`

---

### Common Properties (All Controls)

These properties appear for every control type.

#### (Name) — *always first*

| Property | Type | Description |
|----------|------|-------------|
| `(Name)` | String | Control name used in code to identify the control |

#### APPEARANCE

| Property | Type | Controls | Description |
|----------|------|----------|-------------|
| `Caption` / `Text` | String | All with text | Display text (Caption for Buttons/Labels, Text for TextBoxes) |
| `BackColor` | Color | All | Background color |
| `ForeColor` | Color | All | Text/foreground color |
| `Appearance` | Enum | All | `0 - Flat`, `1 - 3D` (raised/sunken effect) |
| `BorderStyle` | Enum | Label, Panel, LineEdit, TextEdit | `0 - None`, `1 - Fixed Single` |

#### BEHAVIOR

| Property | Type | Controls | Description |
|----------|------|----------|-------------|
| `Enabled` | Bool | All | Whether the control responds to user input |
| `Visible` | Bool | All | Whether the control is displayed |
| `TabStop` | Bool | All | Whether the user can TAB to this control |
| `TabIndex` | Number | All | Tab order within the form |

#### FONT

| Property | Type | Controls | Description |
|----------|------|----------|-------------|
| `FontName` | String | All | Font family name (default: "MS Sans Serif") |
| `FontSize` | Number | All | Font size in points |
| `FontBold` | Bool | All | Bold text |
| `FontItalic` | Bool | All | Italic text |
| `FontUnderline` | Bool | All | Underlined text |
| `FontStrikethrough` | Bool | All | Strikethrough text |

#### POSITION

| Property | Type | Controls | Description |
|----------|------|----------|-------------|
| `Left` | Number | All | X position on the form (pixels) |
| `Top` | Number | All | Y position on the form (pixels) |
| `Width` | Number | All | Control width (pixels) |
| `Height` | Number | All | Control height (pixels) |

#### EFFECTS

| Property | Type | Controls | Description |
|----------|------|----------|-------------|
| `Opacity` | Slider (0–100) | All | Transparency level (100 = fully opaque, 0 = invisible) |
| `Rotation` | Number | All | Rotation angle in degrees |
| `ScaleX` | Number | All | Horizontal scale factor (1.0 = normal) |
| `ScaleY` | Number | All | Vertical scale factor (1.0 = normal) |

#### LAYOUT

| Property | Type | Controls | Description |
|----------|------|----------|-------------|
| `MinWidth` | Number | All | Minimum width constraint |
| `MinHeight` | Number | All | Minimum height constraint |
| `ClipContents` | Bool | All | Clip child controls to this control's boundaries |

#### MISC

| Property | Type | Controls | Description |
|----------|------|----------|-------------|
| `ToolTipText` | String | All | Text shown when hovering over the control |
| `Tag` | String | All | General-purpose storage string |
| `MousePointer` | Enum | All | Cursor shape (Default, Arrow, Crosshair, IBeam, Hand, etc.) |
| `Index` | Readonly | All | Control index in the form designer's array |

---

### Button (CommandButton)

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `Caption` | String | Appearance | Button label text |
| `Style` | Enum | Appearance | `0 - Standard`, `1 - Graphical` |
| `Flat` | Bool | Appearance | Removes 3D border (flat appearance) |
| `Icon` | String | Appearance | Path to icon texture displayed on the button |
| `IconAlignment` | Enum | Appearance | `0 - Left`, `1 - Center`, `2 - Right` |
| `Default` | Bool | Behavior | Whether this is the form's default button (Enter key) |
| `Cancel` | Bool | Behavior | Whether this is the form's Cancel button (Escape key) |

---

### Label

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `Caption` | String | Appearance | Label display text |
| `Alignment` | Enum | Appearance | `0 - Left`, `1 - Right`, `2 - Center` |
| `VerticalAlignment` | Enum | Appearance | `0 - Top`, `1 - Center`, `2 - Bottom` |
| `AutoSize` | Bool | Appearance | Automatically resize to fit text |
| `WordWrap` | Bool | Appearance | Wrap long text to next line |
| `MaxLinesVisible` | Number | Appearance | Maximum visible lines (-1 = unlimited) |

---

### TextBox (LineEdit)

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `Text` | String | Appearance | Current text content |
| `PasswordChar` | String | Appearance | Mask character (e.g. `"*"`), empty = normal |
| `MaxLength` | Number | Appearance | Maximum characters (0 = unlimited) |
| `Locked` | Bool | Appearance | Read-only mode |
| `PlaceholderText` | String | Appearance | Grayed-out hint text when empty |
| `ClearButton` | Bool | Appearance | Show ✕ clear button when field has text |
| `SelectAllOnFocus` | Bool | Behavior | Auto-select all text when control receives focus |

---

### TextArea (TextEdit)

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `Text` | String | Appearance | Current text content |
| `MultiLine` | Bool | Appearance | Accept multiple lines of text |
| `ScrollBars` | Enum | Appearance | `0 - None`, `1 - Horizontal`, `2 - Vertical`, `3 - Both` |
| `Editable` | Bool | Behavior | Whether the user can edit the content |

---

### CheckBox

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `Caption` | String | Appearance | Checkbox label text |
| `Value` | Bool | Appearance | Current checked state |

---

### Range Controls (ProgressBar, HSlider, VSlider, HScrollBar, VScrollBar, SpinBox)

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `Value` | Number | Appearance | Current value |
| `Min` | Number | Appearance | Minimum value |
| `Max` | Number | Appearance | Maximum value |
| `Step` | Number | Appearance | Increment step |

---

### ProgressBar (additional)

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `ShowPercentage` | Bool | Appearance | Display value as percentage text |
| `FillMode` | Enum | Appearance | `0 - Left to Right`, `1 - Right to Left`, `2 - Top to Bottom`, `3 - Bottom to Top` |

---

### SpinBox (additional)

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `Prefix` | String | Appearance | Text before the value (e.g. `"$"`) |
| `Suffix` | String | Appearance | Text after the value (e.g. `"%"`, `"px"`) |
| `Wrap` | Bool | Behavior | Wrap from Max→Min and Min→Max |

---

### PictureBox (TextureRect)

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `Picture` | String | Appearance | Path to the image resource |
| `Stretch` | Bool | Appearance | Legacy stretch toggle |
| `StretchMode` | Enum | Appearance | `0 - Scale`, `1 - Tile`, `2 - Keep`, `3 - Keep Centered`, `4 - Keep Aspect`, `5 - Keep Aspect Centered`, `6 - Keep Aspect Covered` |
| `FlipH` | Bool | Appearance | Flip image horizontally |
| `FlipV` | Bool | Appearance | Flip image vertically |

---

### Shape (ColorRect)

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `ShapeColor` | Color | Appearance | Fill color of the rectangle |

---

### ListBox (ItemList)

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `Sorted` | Bool | Behavior | Sort items alphabetically |
| `MultiSelect` | Enum | Behavior | `0 - None`, `1 - Simple`, `2 - Extended` |
| `Columns` | Number | Behavior | Number of columns |
| `IconMode` | Enum | Appearance | `0 - Top`, `1 - Left` |
| `MaxColumns` | Number | Appearance | Maximum columns (0 = auto-fit) |
| `FixedColumnWidth` | Number | Appearance | Fixed column width (0 = auto) |

---

### ComboBox (OptionButton)

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `ListItems` | String | Appearance | Pipe-separated items (e.g. `"Red|Green|Blue"`) |

---

### TreeView (Tree)

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `Sorted` | Bool | Behavior | Sort items alphabetically |
| `HideRoot` | Bool | Appearance | Hide the root tree item |
| `HideFolding` | Bool | Appearance | Hide the expand/collapse arrows |

---

### TabStrip (TabContainer)

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `CurrentTab` | Number | Appearance | Currently active tab index (0-based) |
| `TabAlignment` | Enum | Appearance | `0 - Left`, `1 - Center`, `2 - Right` |

---

### Timer

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `Interval` | Number | Behavior | Milliseconds between Timer events |

---

### Form Properties

When you click the form background (no control selected), these properties appear:

| Property | Type | Category | Description |
|----------|------|----------|-------------|
| `(Name)` | String | — | Form name |
| `Caption` | String | Appearance | Title bar text |
| `BorderStyle` | Enum | Appearance | `0 - None`, `1 - Fixed Single`, `2 - Sizable`, `3 - Fixed Dialog`, `4 - Fixed ToolWindow`, `5 - Sizable ToolWindow` |
| `BackColor` | Color | Appearance | Form background color |
| `ForeColor` | Color | Appearance | Default text color for new controls |
| `ControlBox` | Bool | Behavior | Show close/min/max buttons in title bar |
| `MinButton` | Bool | Behavior | Show minimize button |
| `MaxButton` | Bool | Behavior | Show maximize button |
| `Moveable` | Bool | Behavior | Allow user to drag the form |
| `ShowInTaskbar` | Bool | Behavior | Appear in the OS taskbar |
| `KeyPreview` | Bool | Behavior | Form receives key events before controls |
| `AutoRedraw` | Bool | Behavior | Automatically handle Paint events |
| `WindowState` | Enum | Behavior | `0 - Normal`, `1 - Minimized`, `2 - Maximized` |
| `StartUpPosition` | Enum | Behavior | `0 - Manual`, `1 - CenterOwner`, `2 - CenterScreen`, `3 - Windows Default` |
| `Width` | Number | Position | Form width |
| `Height` | Number | Position | Form height |
| `WindowType` | Enum | Misc | `0 - Game (SubViewport)`, `1 - Windows`, `2 - Linux/CSD`, `3 - macOS` |
| `Icon` | String | Misc | Path to the form's title bar icon |

---

## Custom Controls

You can design your own controls in Godot and add them to the Toolbox.
See the **[Custom Controls Guide](../guides/CUSTOM_CONTROLS.md)** for
step-by-step instructions on creating, registering, and using custom controls.
