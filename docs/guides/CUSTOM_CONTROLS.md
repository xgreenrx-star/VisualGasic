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
