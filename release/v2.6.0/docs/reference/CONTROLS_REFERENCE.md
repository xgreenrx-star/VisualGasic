# VisualGasic Controls Reference

This document describes all controls available in the VisualGasic Toolbox.

## Standard Controls

These controls are always available in the Toolbox.

### Label
**VB6 Name:** Label  
**Godot Node:** Label  
**Description:** Displays static text.

**Key Properties:**
- `Text` - The text to display
- `AutoSize` - Automatically size to fit text
- `Alignment` - Text alignment (Left, Center, Right)

---

### TextBox (LineEdit)
**VB6 Name:** TextBox  
**Godot Node:** LineEdit  
**Description:** Single-line text input field.

**Key Properties:**
- `Text` - The current text value
- `MaxLength` - Maximum character count
- `PasswordChar` - Character for password masking
- `ReadOnly` - Prevent user editing

**Key Events:**
- `Change` - Text changed
- `KeyPress` - Key pressed

---

### TextArea (TextEdit)
**VB6 Name:** TextBox (MultiLine=True)  
**Godot Node:** TextEdit  
**Description:** Multi-line text input field.

**Key Properties:**
- `Text` - The current text value
- `ReadOnly` - Prevent user editing
- `WordWrap` - Enable word wrapping

---

### CommandButton (Button)
**VB6 Name:** CommandButton  
**Godot Node:** Button  
**Description:** Clickable button.

**Key Properties:**
- `Caption` / `Text` - Button text
- `Enabled` - Whether button is clickable
- `Default` - Activates on Enter key
- `Cancel` - Activates on Escape key

**Key Events:**
- `Click` - Button clicked

---

### CheckBox
**VB6 Name:** CheckBox  
**Godot Node:** CheckBox  
**Description:** On/off toggle checkbox.

**Key Properties:**
- `Caption` / `Text` - Checkbox label
- `Value` / `ButtonPressed` - Check state (True/False)

**Key Events:**
- `Click` - State changed

---

### OptionButton (RadioButton)
**VB6 Name:** OptionButton  
**Godot Node:** CheckBox (in ButtonGroup)  
**Description:** Radio button for single selection from a group.

**Key Properties:**
- `Caption` / `Text` - Button label
- `Value` / `ButtonPressed` - Selected state

**Key Events:**
- `Click` - Selection changed

---

### ListBox (ItemList)
**VB6 Name:** ListBox  
**Godot Node:** ItemList  
**Description:** Scrollable list of items.

**Key Properties:**
- `List` - Array of items
- `ListIndex` - Currently selected index
- `ListCount` - Number of items
- `MultiSelect` - Allow multiple selections

**Key Methods:**
- `AddItem(text)` - Add an item
- `RemoveItem(index)` - Remove an item
- `Clear()` - Remove all items

**Key Events:**
- `Click` - Item selected
- `DblClick` - Item double-clicked

---

### ComboBox (OptionButton)
**VB6 Name:** ComboBox  
**Godot Node:** OptionButton  
**Description:** Dropdown selection list.

**Key Properties:**
- `List` - Array of items
- `ListIndex` - Currently selected index
- `Text` - Current selection text

**Key Methods:**
- `AddItem(text)` - Add an item
- `RemoveItem(index)` - Remove an item
- `Clear()` - Remove all items

---

### PictureBox (TextureRect)
**VB6 Name:** PictureBox  
**Godot Node:** TextureRect  
**Description:** Displays an image.

**Key Properties:**
- `Picture` / `Texture` - Image to display
- `Stretch` - Resize image to fit

---

### Frame / GroupBox (Panel)
**VB6 Name:** Frame  
**Godot Node:** Panel  
**Description:** Container with border for grouping controls.

**Key Properties:**
- `Caption` - Group title text
- `BorderStyle` - Border appearance

---

### Timer
**VB6 Name:** Timer  
**Godot Node:** Timer  
**Description:** Triggers events at regular intervals.

**Key Properties:**
- `Interval` - Time in milliseconds
- `Enabled` - Whether timer is running

**Key Events:**
- `Timer` - Interval elapsed

---

### HScroll / VScroll (ScrollBar)
**VB6 Name:** HScrollBar / VScrollBar  
**Godot Node:** HScrollBar / VScrollBar  
**Description:** Horizontal or vertical scrollbar.

**Key Properties:**
- `Min` - Minimum value
- `Max` - Maximum value
- `Value` - Current position
- `LargeChange` - Page scroll amount
- `SmallChange` - Arrow scroll amount

**Key Events:**
- `Change` - Value changed
- `Scroll` - Scrolling

---

## Extended Controls

### ProgressBar
**VB6 Name:** ProgressBar  
**Godot Node:** ProgressBar  
**Description:** Shows progress of an operation.

**Key Properties:**
- `Min` - Minimum value (default 0)
- `Max` - Maximum value (default 100)
- `Value` - Current progress

---

### HSlider / VSlider
**VB6 Name:** Slider  
**Godot Node:** HSlider / VSlider  
**Description:** Slider for selecting a value from a range.

**Key Properties:**
- `Min` - Minimum value
- `Max` - Maximum value
- `Value` - Current value
- `Step` - Increment amount

**Key Events:**
- `Change` - Value changed

---

### SpinBox
**VB6 Name:** UpDown + TextBox  
**Godot Node:** SpinBox  
**Description:** Numeric input with up/down buttons.

**Key Properties:**
- `Min` - Minimum value
- `Max` - Maximum value
- `Value` - Current value
- `Step` - Increment amount

---

### Shape (ColorRect)
**VB6 Name:** Shape  
**Godot Node:** ColorRect  
**Description:** Colored rectangle.

**Key Properties:**
- `BackColor` / `Color` - Fill color
- `Shape` - Shape type (Rectangle)

---

### RichText (RichTextLabel)
**VB6 Name:** RichTextBox  
**Godot Node:** RichTextLabel  
**Description:** Formatted text display with BBCode support.

**Key Properties:**
- `Text` - Plain text content
- `BBCodeText` - BBCode formatted text
- `BBCodeEnabled` - Enable BBCode parsing

---

### TreeView (Tree)
**VB6 Name:** TreeView  
**Godot Node:** Tree  
**Description:** Hierarchical tree structure.

**Key Methods:**
- `AddItem(text, parent)` - Add tree item
- `Clear()` - Remove all items

**Key Events:**
- `NodeSelected` - Item selected

---

### TabStrip (TabContainer)
**VB6 Name:** TabStrip / SSTab  
**Godot Node:** TabContainer  
**Description:** Tabbed container for multiple pages.

**Key Properties:**
- `CurrentTab` - Active tab index

---

### Files (FileDialog)
**VB6 Name:** CommonDialog  
**Godot Node:** FileDialog  
**Description:** File open/save dialog.

**Key Properties:**
- `FileName` - Selected file path
- `Filter` - File type filters
- `Title` - Dialog title

---

## 2D Game Controls

### Sprite (Sprite2D)
**Description:** 2D sprite display.

**Key Properties:**
- `Texture` - Sprite image
- `Position` - X, Y coordinates
- `Scale` - Size multiplier
- `Rotation` - Rotation in radians
- `Flip_H` / `Flip_V` - Mirror horizontally/vertically

---

### AnimatedSprite (AnimatedSprite2D)
**Description:** Animated sprite with multiple frames.

**Key Properties:**
- `SpriteFrames` - Animation library
- `Animation` - Current animation name
- `Playing` - Whether animation is playing
- `Frame` - Current frame index

**Key Methods:**
- `Play(animation)` - Play animation
- `Stop()` - Stop animation

---

### Tilemap (TileMapLayer)
**Description:** Tile-based level maps.

**Key Properties:**
- `TileSet` - Tile definitions

**Key Methods:**
- `SetCell(x, y, tile)` - Set tile at position
- `GetCell(x, y)` - Get tile at position

---

### RigidBody (RigidBody2D)
**Description:** Physics-enabled body.

**Key Properties:**
- `Mass` - Object mass
- `LinearVelocity` - Movement velocity
- `AngularVelocity` - Rotation velocity

---

### CharacterBody (CharacterBody2D)
**Description:** Player character with `move_and_slide()`.

**Key Properties:**
- `Velocity` - Movement velocity
- `UpDirection` - Which direction is "up"

**Key Methods:**
- `MoveAndSlide()` - Move with collision

---

### Area (Area2D)
**Description:** Collision detection area.

**Key Events:**
- `BodyEntered` - Body entered area
- `BodyExited` - Body left area

---

### Camera (Camera2D)
**Description:** 2D camera view.

**Key Properties:**
- `Zoom` - Zoom level
- `Position` - Camera position
- `Current` - Is active camera

---

## 3D Game Controls

### MeshInstance (MeshInstance3D)
**Description:** 3D mesh display.

**Key Properties:**
- `Mesh` - 3D mesh resource
- `MaterialOverride` - Surface material

---

### RigidBody3D
**Description:** 3D physics body.

**Key Properties:**
- `Mass` - Object mass
- `LinearVelocity` - Movement velocity

---

### CharacterBody3D
**Description:** 3D player character.

**Key Properties:**
- `Velocity` - Movement velocity

**Key Methods:**
- `MoveAndSlide()` - Move with collision

---

### Camera3D
**Description:** 3D camera.

**Key Properties:**
- `Fov` - Field of view
- `Current` - Is active camera

---

### DirectionalLight3D
**Description:** Sunlight / directional light.

**Key Properties:**
- `Color` - Light color
- `Energy` - Light intensity

---

### SpotLight3D / OmniLight3D
**Description:** Spotlight or point light.

**Key Properties:**
- `Color` - Light color
- `Energy` - Light intensity
- `Range` - Light distance

---

### WorldEnvironment
**Description:** Sky, fog, and environment settings.

**Key Properties:**
- `Environment` - Environment resource

---

### CSGBox3D
**Description:** CSG box primitive for prototyping.

**Key Properties:**
- `Size` - Box dimensions
- `Material` - Surface material

---

## Optional Components

These controls are available via **Project > Visual Gasic Components...**

### Calendar
**Description:** Month/date picker calendar control.

**Key Properties:**
- `Value` - Currently selected date (as string "YYYY-MM-DD")
- `Year` - Current year
- `Month` - Current month (1-12)
- `FirstDayOfWeek` - Week start day (0=Sunday, 1=Monday)
- `HighlightToday` - Highlight current date
- `ShowWeekNumbers` - Display week numbers

**Key Methods:**
- `SetDate(year, month, day)` - Set the selected date
- `GetDate()` - Get selected date as Dictionary
- `GoToToday()` - Navigate to current date

**Key Events:**
- `DateSelected(date_dict)` - Date was selected
- `MonthChanged(year, month)` - Month navigation changed

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
