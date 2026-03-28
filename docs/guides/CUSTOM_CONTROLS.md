# Creating and Using Custom Controls

## Overview

The Visual Gasic IDE ships with 40+ built-in controls (Button, Label, TextBox,
ListBox, etc.), but you can also **create your own controls** in Godot and use them
on your forms exactly like the built-in ones. This lets you design themed game buttons,
animated menus, custom widgets — anything you can build as a Godot scene.

---

## Quick Start (5 minutes)

### Step 1: Design your control in Godot

1. In Godot's **FileSystem** dock, right-click → **New Scene**
2. Choose a root node type (usually `Button`, `Control`, `PanelContainer`, etc.)
3. Customize it:
   - Add child nodes (icons, labels, particles, AnimationPlayer, etc.)
   - Change theme overrides (colors, fonts, StyleBox)
   - Attach a GDScript for animations or custom behavior
4. Save the scene somewhere in your project, e.g. `res://my_controls/GlowButton.tscn`

**Example — a button with a glow effect:**

```
GlowButton.tscn
├── Button (root)
│   ├── theme_override: custom StyleBox with rounded corners
│   ├── AnimationPlayer (hover glow animation)
│   └── TextureRect (icon overlay)
```

### Step 2: Add it to the Toolbox

1. Open the **Components** dialog: **Project → Components** (or right-click the Toolbox)
2. Click **Browse...**
3. Select your `.tscn` file (e.g. `res://my_controls/GlowButton.tscn`)
4. Enter a display name (e.g. "GlowButton") and click **Add**
5. The component appears in the list with a ✓ checkmark (enabled)
6. Click **OK**

Your control now appears in the **Toolbox** alongside Button, Label, etc.

### Step 3: Use it on a form

1. Click your custom control in the Toolbox
2. Draw it on the form canvas (click and drag)
3. Resize and position it like any built-in control
4. Double-click to generate an event handler stub

```vb
' Auto-generated when you double-click GlowButton1
Sub GlowButton1_Click()
    Print "Glow button clicked!"
End Sub
```

### Step 4: Save and run

When you save the form (Ctrl+S), the generated `.tscn` file will use
`instance=ExtResource()` to reference your custom scene — so all your
animations, scripts, and child nodes come through in the final output.

---

## How It Works

### What happens behind the scenes

| Step | What happens |
|------|-------------|
| **Browse** | The Components dialog records the scene path and display name in `custom_components.cfg` |
| **Toolbox** | On plugin load, enabled custom components are added to the Toolbox via `register_custom_control_type()` |
| **Draw on form** | The Visual Gasic IDE creates a `FormControlItem` with `scene_path` pointing to your `.tscn` |
| **Canvas display** | The Visual Gasic IDE draws a colored rectangle with the control name (design-time placeholder) |
| **Save** | `_serialize_to_tscn()` emits an `ext_resource` entry for your scene and an `instance=ExtResource()` node |
| **Run / Preview** | Godot instances your actual scene with all its children, scripts, and themes |

### Design-time vs. run-time appearance

On the Visual Gasic IDE canvas, custom controls appear as a **colored rectangle** with
the control name — the designer doesn't render the actual Godot scene. This is normal.
When you **Preview** or **Run** the form, you'll see the real control with all its
styling, animations, and children.

---

## Managing Custom Controls

### The Components Dialog

Open via **Project → Components** or right-click the Toolbox.

| Action | How |
|--------|-----|
| **Add** | Click "Browse..." → select a `.tscn` → name it → OK |
| **Enable/Disable** | Double-click a component in the list to toggle (✓ = in Toolbox) |
| **Remove** | Select a custom component → click "Remove" (built-in components cannot be removed) |
| **Apply** | Click "Apply" to update the Toolbox without closing the dialog |

Custom component settings are saved to `res://addons/visual_gasic/custom_components.cfg`
and persist across editor sessions.

### Scene path validation

If a custom control's `.tscn` file is moved or deleted:

- **At save time**: The Visual Gasic IDE automatically detects the missing file and falls back
  to the built-in prototype for that control type. A warning is printed to the console.
- **In the Toolbox**: The control still appears, but placing it will use a generic fallback.

To fix: re-add the control via Browse, or move the `.tscn` back to its original location.

---

## Tips for Designing Custom Controls

### Choose the right root node

| Root Node | Best for |
|-----------|----------|
| `Button` | Clickable controls (generates `pressed` signal → `_Click()` event) |
| `Control` | Fully custom widgets (you handle all drawing/input) |
| `PanelContainer` | Container-style controls with background |
| `HBoxContainer` / `VBoxContainer` | Multi-part controls (icon + label + badge) |
| `TextureRect` | Image-based controls |

### Make it self-contained

Your custom control scene should work independently — it shouldn't depend on nodes
that only exist in a specific form. This ensures it works when instanced on any form.

**Good:**
```
GlowButton.tscn
├── Button
│   ├── AnimationPlayer (hover glow — self-contained)
│   └── icon.png (embedded or in same folder)
```

**Avoid:**
```
GlowButton.tscn
├── Button
│   └── Script that references "../../GameManager"  ← breaks on other forms
```

### Expose properties via export variables

If you attach a GDScript to your control, use `@export` to expose properties
that can be set per-instance:

```gdscript
# glow_button.gd
extends Button

@export var glow_color: Color = Color.CYAN
@export var glow_intensity: float = 1.0
@export var pulse_speed: float = 2.0
```

These exports will appear in Godot's Inspector when the control is selected in the
final generated scene.

### Keep file paths portable

Store custom control scenes inside your project:
- `res://custom_controls/` — recommended default location
- `res://ui/controls/` — alternative
- `res://addons/my_controls/` — if packaging as a reusable addon

Avoid absolute paths or paths outside the project.

---

## Examples

### Animated Game Button

A button with a bounce animation on hover:

1. Create `res://custom_controls/BounceButton.tscn`:
   - Root: `Button`
   - Child: `AnimationPlayer` with a "hover" animation that scales to 1.1x
   - Attach script:
     ```gdscript
     extends Button
     func _ready():
         mouse_entered.connect(func(): $AnimationPlayer.play("hover"))
         mouse_exited.connect(func(): $AnimationPlayer.play("RESET"))
     ```
2. Components → Browse → select `BounceButton.tscn` → name it "BounceButton"
3. Draw on form, double-click → write `Sub BounceButton1_Click()`

### Themed Panel

A panel with a custom border and background:

1. Create `res://custom_controls/GamePanel.tscn`:
   - Root: `PanelContainer`
   - Add `theme_override/styles/panel` → `StyleBoxFlat` with rounded corners,
     custom colors, border width
   - Child: `MarginContainer` → `Label` (optional default text)
2. Add via Components dialog
3. Use on forms for consistent game UI panels

### Icon Button

A button with an image instead of text:

1. Create `res://custom_controls/IconButton.tscn`:
   - Root: `TextureButton`
   - Set `texture_normal`, `texture_hover`, `texture_pressed`
2. Add via Components dialog
3. Perfect for toolbar icons, inventory slots, etc.

---

## Frequently Asked Questions

**Q: Can I edit a custom control after adding it to forms?**  
A: Yes. Edit the `.tscn` file in Godot's scene editor. Changes automatically apply
everywhere the control is used (since forms reference the scene via `instance=`).

**Q: Will my custom control have VB6-style event wiring?**  
A: Yes. If the root node emits standard Godot signals (e.g. `pressed` for Button),
the auto-wiring system picks them up. `Sub MyButton1_Click()` works automatically.

**Q: Can I share custom controls with other projects?**  
A: Yes. Copy the `.tscn` file (and any assets it uses) to the other project, then
add it via Components → Browse.

**Q: Why does my control look like a plain rectangle on the Visual Gasic IDE?**  
A: The Visual Gasic IDE canvas draws design-time placeholders for all controls.
Use **Preview** (or F5) to see the actual rendered control.

**Q: What if I delete the `.tscn` file?**  
A: The Visual Gasic IDE detects missing files at save time and falls back to the
built-in prototype for that control type. Your form won't break — it just
reverts to a standard control.

---

## Exposing Runtime Properties (VG_Properties)

Custom controls can expose **named VB6 properties** that your `.vg` code can
read and write at runtime — just like the built-in properties (`Text`, `Visible`,
`BackColor`, etc.) work on standard controls.

This is done by adding a **`VG_Properties` metadata Dictionary** to the custom
control's root node. The VisualGasic bytecode VM checks this dictionary
automatically whenever a property access doesn't match one of the 50+ built-in
VB6 aliases.

### How the Lookup Chain Works

When your VB6 code accesses `Me.MyWidget1.SomeProperty`, the VM tries — in order:

1. **Built-in VB6 aliases** (Text, Visible, BackColor, FontBold, etc.)
2. **VG_Properties dictionary** on the node's metadata ← *your custom mappings*
3. **Native Godot property** (`obj.get("SomeProperty")` / `obj.set(...)`)
4. **Child node lookup** (`find_child("SomeProperty")`)

So your custom property names take priority over Godot-native properties, but
built-in VB6 aliases always win.

---

### Step-by-Step: Creating a Custom Control with Runtime Properties

This walkthrough builds a **HealthBar** custom control with `Health`, `MaxHealth`,
`BarColor`, and `LabelText` properties that can be read and written from VB6 code.

#### Step 1: Create the Godot Scene

1. In Godot's **FileSystem** dock, right-click → **New Scene**
2. Choose **PanelContainer** as the root node
3. Add children:

```
HealthBar.tscn
├── PanelContainer (root)
│   ├── VBoxContainer
│   │   ├── Label (name: "Label")
│   │   └── ProgressBar (name: "ProgressBar")
```

4. Configure the ProgressBar:
   - `min_value` = 0
   - `max_value` = 100
   - `value` = 100
   - `show_percentage` = true

5. Configure the Label:
   - `text` = "HP"
   - `horizontal_alignment` = Center

#### Step 2: Attach a Script with VG_Properties

Attach a GDScript to the **root PanelContainer**:

```gdscript
# health_bar.gd
extends PanelContainer

@export var max_health: float = 100.0

func _ready():
    # Register VB6 property names → Godot property mappings
    set_meta("VG_Properties", {
        "Health":     "ProgressBar:value",       # ProgressBar child, "value" property
        "MaxHealth":  "ProgressBar:max_value",   # ProgressBar child, "max_value" property
        "BarColor":   "ProgressBar:self_modulate",  # ProgressBar child, "self_modulate" property
        "LabelText":  "Label:text",              # Label child, "text" property
        "ShowLabel":  "Label:visible"            # Label child, "visible" property
    })

    # Initialize
    $ProgressBar.max_value = max_health
    $ProgressBar.value = max_health
```

6. Save as `res://custom_controls/HealthBar.tscn`

#### Step 3: Add to the Toolbox

1. Open **Project → Components**
2. Click **Browse** → select `HealthBar.tscn`
3. Name it "HealthBar" → click **Add** → **OK**

#### Step 4: Use It on a Form

1. Click "HealthBar" in the Toolbox
2. Draw it on your form
3. The design-time placeholder shows as a colored rectangle labeled "HealthBar1"

#### Step 5: Write VB6 Code

```vb
Sub Form_Load()
    ' Initialize the health bar
    Me.HealthBar1.MaxHealth = 200
    Me.HealthBar1.Health = 200
    Me.HealthBar1.LabelText = "Player HP"
    Me.HealthBar1.BarColor = vbGreen
    Me.HealthBar1.ShowLabel = True
End Sub

Sub btnTakeDamage_Click()
    Dim hp As Integer
    hp = Me.HealthBar1.Health
    hp = hp - 25
    If hp < 0 Then hp = 0
    Me.HealthBar1.Health = hp

    ' Change color based on remaining health
    If hp < 50 Then
        Me.HealthBar1.BarColor = vbYellow
    End If
    If hp < 25 Then
        Me.HealthBar1.BarColor = vbRed
    End If
End Sub

Sub btnHeal_Click()
    Me.HealthBar1.Health = Me.HealthBar1.MaxHealth
    Me.HealthBar1.BarColor = vbGreen
End Sub
```

#### Step 6: Run and Test

Press **F5** (or Preview). The HealthBar renders as a real ProgressBar with a label.
Clicking "Take Damage" decreases the health and changes the bar color.
Clicking "Heal" restores it.

---

### VG_Properties Dictionary Format

The dictionary maps VB6 property names to Godot properties:

| Format | Meaning | Example |
|---|---|---|
| `"PropertyName": "godot_property"` | Read/write `godot_property` on **self** (the root node) | `"Opacity": "modulate:a"` → `self.modulate.a` |
| `"PropertyName": "ChildName:godot_property"` | Read/write `godot_property` on a **child node** | `"Health": "ProgressBar:value"` → `ProgressBar.value` |

**Child resolution:** The child name is first tried with `find_child()` (searches
by node name), then with `get_node_or_null()` (accepts relative paths like
`"VBox/ProgressBar"`).

**Any Godot property works:** You can map to any property that Godot's
`Object.get()` / `Object.set()` supports — including theme overrides, transforms,
materials, and custom `@export` variables.

---

### More Examples

#### Skill Cooldown Button

```gdscript
# cooldown_button.gd
extends Button

@export var cooldown_time: float = 5.0

func _ready():
    set_meta("VG_Properties", {
        "CooldownTime":  "cooldown_time",        # @export var on self
        "IsReady":       "disabled",             # Godot native (note: inverted semantics)
        "ButtonText":    "text"                  # native property on self
    })
```

```vb
Sub Form_Load()
    Me.SkillBtn1.CooldownTime = 3.0
    Me.SkillBtn1.ButtonText = "Fire!"
End Sub
```

#### Stat Display Panel

```gdscript
# stat_display.gd
extends PanelContainer

func _ready():
    set_meta("VG_Properties", {
        "StatName":      "HBox/NameLabel:text",
        "StatValue":     "HBox/ValueLabel:text",
        "BarPercent":    "HBox/MiniBar:value",
        "NameColor":     "HBox/NameLabel:self_modulate",
        "ValueColor":    "HBox/ValueLabel:self_modulate"
    })
```

```vb
Sub Form_Load()
    Me.StatPanel1.StatName = "Strength"
    Me.StatPanel1.StatValue = "42"
    Me.StatPanel1.BarPercent = 84
End Sub
```

---

### Tips for VG_Properties

1. **Keep property names VB6-style** — PascalCase, descriptive (e.g. `BarColor`
   not `bar_color`), since your users write VB6 code

2. **Set VG_Properties in `_ready()`** — the dictionary must exist before the
   first VB6 property access, which happens after `_ready()` completes

3. **You can update the dictionary at runtime** — call `set_meta("VG_Properties", ...)`
   again if you need to add or change mappings dynamically

4. **Built-in names take priority** — if you name a custom property `"Text"` or
   `"Visible"`, the built-in alias wins. Pick unique names for your custom properties

5. **Type conversion is automatic** — the VM passes Variant values through, so
   Color, int, float, String, bool all work seamlessly

6. **Works with events too** — if your custom control emits Godot signals (e.g.
   `pressed`, `value_changed`), the auto-wiring system picks them up. Combined
   with VG_Properties, you get a fully interactive custom control with readable
   state

---

### See Also

- [Runtime Properties Reference](../reference/RUNTIME_PROPERTIES_REFERENCE.md) — full list of all 50+ built-in property aliases
- [Controls Reference](../reference/CONTROLS_REFERENCE.md) — design-time property tables for every control type
