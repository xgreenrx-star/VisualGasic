# Custom Forms: Build an Animated Wobbly Form

*Two approaches to creating animated form effects — custom controls and shaders.*

---

## What You'll Build

A form with an animated "wobbly" background that rotates, pulses, and reacts to mouse hover. You'll learn two techniques:

- **Approach A** — A **WobblyPanel** custom control (GDScript) you drag from the Toolbox
- **Approach B** — A **wobble shader** (GLSL) applied to the form background via ShaderMaterial

Both produce a living, breathing form. Approach A is easier and integrates with the VisualGasic toolbox. Approach B is GPU-driven and more flexible for advanced effects.

**Time:** ~15 minutes per approach

**Prerequisites:** Godot 4.5+, VisualGasic installed and enabled. Familiarity with the Form Designer (see the [Calculator Tutorial](calculator_form_designer.md) first).

---

## Approach A — WobblyPanel Custom Control

This follows the same pipeline as the built-in WobblyButton example. You create a `@tool` script, wrap it in a `.tscn` scene, register it in the Components dialog, and drag it onto forms from the Toolbox.

### Step 1 — Create the Custom Controls Folder

1. In Godot's **FileSystem** dock, right-click the `res://` root folder.
2. Click **New Folder** and name it `custom_controls`.

> This is the conventional location for user-created controls. The WobblyButton example already lives here if you've used it before.

---

### Step 2 — Create the WobblyPanel Script

1. Right-click the `custom_controls` folder → **New Script**.
2. Set the script name to `WobblyPanel.gd`.
3. Set **Inherits** to `Panel`.
4. Click **Create** and paste the following:

```gdscript
@tool
extends Panel
## WobblyPanel — An animated panel that wobbles, breathes, and ripples.
## Use as a form background replacement or decorative container.

## How much the panel rotates back and forth (degrees).
@export var wobble_amount: float = 1.5
## Speed of the wobble oscillation.
@export var wobble_speed: float = 2.0
## How much the panel scales up/down (breathing effect).
@export var pulse_amount: float = 0.02
## Speed of the pulse oscillation.
@export var pulse_speed: float = 1.5
## Whether the wobble is always active or only when hovered.
@export var always_animate: bool = true
## Tint color when hovered.
@export var hover_tint: Color = Color(0.9, 0.95, 1.0, 1.0)

var _time: float = 0.0
var _is_hovered: bool = false
var _hover_t: float = 0.0

func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    pivot_offset = size / 2.0
    mouse_filter = Control.MOUSE_FILTER_PASS

func _process(delta: float) -> void:
    _time += delta

    if _is_hovered:
        _hover_t = minf(_hover_t + delta * 5.0, 1.0)
    else:
        _hover_t = maxf(_hover_t - delta * 5.0, 0.0)

    var anim_strength: float
    if always_animate:
        anim_strength = lerpf(0.6, 1.0, _hover_t)
    else:
        anim_strength = _hover_t

    rotation_degrees = sin(_time * wobble_speed) * wobble_amount * anim_strength

    var pulse := 1.0 + sin(_time * pulse_speed) * pulse_amount * anim_strength
    scale = Vector2.ONE * pulse
    pivot_offset = size / 2.0

    if _hover_t > 0.01:
        modulate = Color(1, 1, 1, 1).lerp(hover_tint, _hover_t * 0.5)
    else:
        modulate = Color(1, 1, 1, 1)

func _on_mouse_entered() -> void:
    _is_hovered = true

func _on_mouse_exited() -> void:
    _is_hovered = false
```

**Key points:**
- `@tool` — makes the wobble visible in the editor, not just at runtime
- `MOUSE_FILTER_PASS` — the panel receives hover events but lets clicks through to child controls
- `always_animate` — when `true`, a gentle wobble runs even without hover
- `pivot_offset = size / 2.0` — rotates around the center, not the top-left corner

---

### Step 3 — Create the Scene File

1. In Godot, go to **Scene → New Scene**.
2. Click **Other Node** and choose **Panel**.
3. With the root Panel selected, drag `WobblyPanel.gd` onto the **Script** property in the Inspector.
4. In the Inspector, set:
   - **Custom Minimum Size** → `200 × 150`
   - **Anchors Preset** → **Custom** (leave offsets at 0, 0, 200, 150)
5. Save the scene as `res://custom_controls/WobblyPanel.tscn`.

The resulting `.tscn` file should look like:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://custom_controls/WobblyPanel.gd" id="1"]

[node name="WobblyPanel" type="Panel"]
custom_minimum_size = Vector2(200, 150)
offset_right = 200.0
offset_bottom = 150.0
mouse_filter = 1
script = ExtResource("1")
wobble_amount = 1.5
wobble_speed = 2.0
pulse_amount = 0.02
pulse_speed = 1.5
always_animate = true
hover_tint = Color(0.9, 0.95, 1, 1)
```

---

### Step 4 — Register It in the Components Dialog

Now make it appear in the Toolbox.

1. In the Form Designer, go to **Project → Components** (or right-click the Toolbox and choose **Components…**).
2. Click the **Add** button.
3. Fill in:
   - **Name:** `WobblyPanel`
   - **Scene:** `res://custom_controls/WobblyPanel.tscn`
   - **Icon:** `Panel` *(this is the Godot editor icon name used as a placeholder — VisualGasic will display a custom WobblyPanel SVG icon instead if one exists in `vb6_toolbox_icons.gd`, or a generic gear ⚙ fallback otherwise)*
   - **Class:** `Panel`
   - **Category:** `2D`
   - **Description:** `Animated panel that wobbles and breathes — use as a form background`
4. Click **OK**.
5. Make sure the checkbox next to **WobblyPanel** is checked (enabled).
6. Click **OK** to close the Components dialog.

The **WobblyPanel** tool now appears at the bottom of the Toolbox. Hover over it to see the tooltip you entered in the Description field.

---

### Step 5 — Use It on a Form

1. Open the Form Designer and create a new form (or open an existing one).
2. Click **WobblyPanel** in the Toolbox.
3. Click on the form canvas to place it.
4. Drag the edges to fill the entire form.
5. In the Properties panel, tweak the exported values:
   - **wobble_amount** — increase to `3.0` for a dramatic effect
   - **wobble_speed** — try `4.0` for faster wobble
   - **always_animate** — set to `false` if you only want wobble on hover

6. Place other controls (Buttons, Labels, etc.) **on top of** the WobblyPanel — they'll ride along with the wobble since they're siblings in the form.

7. Press **F5** to run. The form background gently wobbles and pulses, and wobbles harder when you move the mouse over it.

---

### Customizing the WobblyPanel

All parameters are exposed as `@export` properties, so you can adjust them per-instance in the Properties panel:

| Property | Default | Description |
|----------|---------|-------------|
| `wobble_amount` | `1.5` | Rotation range in degrees |
| `wobble_speed` | `2.0` | How fast the wobble oscillates |
| `pulse_amount` | `0.02` | Scale breathing depth (0.02 = 2%) |
| `pulse_speed` | `1.5` | How fast the breathing oscillates |
| `always_animate` | `true` | Animate even without hover |
| `hover_tint` | Light blue | Color tint on mouse hover |

**Tip:** Set `wobble_amount = 0` and increase `pulse_amount = 0.05` for a breathing-only effect with no rotation.

---

---

## Approach B — Wobble Shader on the Form Background

This approach uses a GPU shader applied to the form's built-in `_FormBackground` panel. No custom controls needed — you attach a `ShaderMaterial` to the existing form node.

### Step 1 — Create the Shader

1. In Godot's FileSystem dock, create the `custom_controls` folder (if it doesn't exist).
2. Right-click → **New Resource** → choose **Shader** → save as `res://custom_controls/wobble_form.gdshader`.
3. Paste the following:

```glsl
shader_type canvas_item;

// Wobble Form Shader — applies a wavy distortion to the form background.

/// How far pixels are displaced (in pixels).
uniform float amplitude : hint_range(0.0, 20.0) = 3.0;
/// How many waves fit across the panel height.
uniform float frequency : hint_range(0.0, 20.0) = 5.0;
/// Speed of the wave animation.
uniform float speed : hint_range(0.0, 10.0) = 2.0;
/// Vertical wave strength (set to 0 for horizontal-only wobble).
uniform float vertical_amplitude : hint_range(0.0, 20.0) = 1.5;
/// Vertical wave frequency.
uniform float vertical_frequency : hint_range(0.0, 20.0) = 4.0;

void vertex() {
    // Horizontal wave: displaces X based on Y position and time
    VERTEX.x += sin(TIME * speed + VERTEX.y * frequency * 0.01) * amplitude;
    // Vertical wave: displaces Y based on X position and time (offset phase)
    VERTEX.y += sin(TIME * speed * 0.8 + VERTEX.x * vertical_frequency * 0.01 + 1.57) * vertical_amplitude;
}
```

This displaces every vertex of the Panel in a sine-wave pattern, creating a smooth ripple across the entire form.

---

### Step 2 — Design Your Form

1. In the Form Designer, create a new form normally (File → New Form → Blank Form).
2. Add controls as usual — buttons, labels, text boxes, etc.
3. Save the form (**Ctrl+S**).

---

### Step 3 — Attach the Shader to _FormBackground

1. Switch back to the Godot editor (click the **2D** tab or the **↩ Godot Editor** button).
2. In the **Scene** dock, open your form's `.tscn` (e.g., `Form1.tscn`).
3. Expand the scene tree and select the `_FormBackground` node (it's a `Panel` child of the root `Window`).
4. In the **Inspector**, scroll to **CanvasItem → Material**.
5. Click the `[empty]` dropdown → **New ShaderMaterial**.
6. Click the new ShaderMaterial to expand it.
7. Click the **Shader** `[empty]` dropdown → **Load** → choose `res://custom_controls/wobble_form.gdshader`.
8. The shader parameters appear in the Inspector. Adjust them:
   - **amplitude** — `3.0` for subtle, `10.0` for dramatic
   - **frequency** — higher = more wave cycles
   - **speed** — `2.0` is gentle, `6.0` is frantic
   - **vertical_amplitude** — set to `0.0` for horizontal-only waves
9. Save the scene (**Ctrl+S**).

---

### Step 4 — Run It

Press **F5**. The form background (and all controls on it) ripple with a smooth wave animation.

**Note:** The shader affects the `_FormBackground` Panel and all of its visual content. Controls that are children of the form `Window` (not the panel) won't be affected. In the standard form layout, all user controls are siblings of `_FormBackground`, so only the background panel itself wobbles.

---

### Shader Parameters

| Uniform | Default | Description |
|---------|---------|-------------|
| `amplitude` | `3.0` | Horizontal displacement in pixels |
| `frequency` | `5.0` | Horizontal wave density |
| `speed` | `2.0` | Animation speed |
| `vertical_amplitude` | `1.5` | Vertical displacement in pixels |
| `vertical_frequency` | `4.0` | Vertical wave density |

**Tip:** Set `amplitude = 0` and `vertical_amplitude = 5` for a vertical-only jelly wobble.

**Tip:** For a screen-distortion effect (like looking through wavy glass), add a `fragment()` function with UV manipulation instead of vertex displacement.

---

---

## Setting a Custom Tooltip for Your Control

When you register a custom control (Approach A), the **Description** field you enter in the Components dialog becomes the tooltip shown when users hover over the tool in the Toolbox.

This is especially useful when sharing custom controls with other people on your team — the tooltip tells them what the control does without opening the source code.

### How the Tooltip Priority Works

VisualGasic resolves tooltips in this order:

1. **Component description** — the Description you set in the Components dialog (stored in `custom_components.cfg`)
2. **Built-in tips** — hard-coded descriptions for all standard tools (Label, Button, Timer, etc.)
3. **Auto-generated** — if no description is found, VisualGasic generates `"Custom control (ClassName)"` from the underlying Godot class
4. **Tool name** — as a final fallback, the tool's display name is used

### Changing a Tooltip Later

1. Open **Project → Components** in the Form Designer.
2. Find your control in the list.
3. Click **Add** (or edit the `custom_components.cfg` file directly).
4. Update the **Description** field.
5. Click **OK** — the tooltip updates immediately.

### Editing custom_components.cfg Directly

The config file lives at `res://addons/visual_gasic/custom_components.cfg`. Custom entries look like this:

```ini
[custom]

WobblyPanel={
"category": "2D",
"class": "Panel",
"description": "Animated panel that wobbles and breathes — use as a form background",
"enabled": true,
"icon": "Panel",
"name": "WobblyPanel",
"scene": "res://custom_controls/WobblyPanel.tscn"
}
```

Edit the `"description"` value to change the tooltip. The change takes effect after reloading the plugin or restarting Godot.

---

## Custom Toolbox Icons

By default, every custom control gets a **gear icon** (⚙) in the Toolbox — a generic fallback that clearly marks it as a custom component rather than a built-in control.

VisualGasic also ships with specific icons for the bundled custom controls (WobblyButton, WobblyPanel). If you create your own controls and want a distinctive icon, you can add one.

### How icon resolution works

When the Toolbox is styled, VisualGasic resolves each button's icon in this order:

1. **Exact name match** — if `vb6_toolbox_icons.gd` contains an SVG keyed to the control's exact name (e.g. `"WobblyButton"`), that icon is used.
2. **Icon-key remap** — some built-in controls have aliases (e.g. `"VScrollBar"` → `"VScroll"`). The `icon_key_map` dictionary handles this.
3. **Generic fallback** — if no match is found, the `_CustomControl` gear icon is used automatically. This prevents the black-box problem that occurs when Godot editor icons are tinted white on a white background.

### Adding a custom SVG icon

To give your custom control a unique icon, add an entry to the `_svgs()` dictionary in `addons/visual_gasic/vb6_toolbox_icons.gd`:

```gdscript
# Inside _svgs() → return { ... }:
"MyControl": '<rect x="2" y="2" width="16" height="16" fill="#4488CC" stroke="#000" stroke-width="1"/><text x="10" y="13" text-anchor="middle" font-family="sans-serif" font-weight="bold" font-size="8" fill="#FFF">MC</text>',
```

**Guidelines for custom SVG icons:**

| Rule | Detail |
|------|--------|
| ViewBox | All icons use a **20×20** coordinate space |
| Style | Bold black outlines, high-contrast fills, VB6 system palette |
| Key name | Must exactly match the control's **Name** in `custom_components.cfg` |
| Colors | Use VB6 palette: `#C0C0C0` (silver), `#808080` (grey), `#000080` (navy), `#FFFF00` (yellow), `#008000` (green) |

After adding the SVG, reload the plugin (Project → Project Settings → Plugins → toggle off/on) to see the new icon.

### Bundled custom control icons

| Control | Icon |
|---------|------|
| WobblyButton | Wavy-edged button with "~OK~" text |
| WobblyPanel | Wavy-edged panel with ripple lines |
| *(any other)* | ⚙ Gear/cog (generic fallback) |

---

## Comparing the Two Approaches

| | Approach A (WobblyPanel) | Approach B (Shader) |
|---|---|---|
| **Difficulty** | Beginner | Intermediate |
| **Language** | GDScript | GLSL (shader language) |
| **Toolbox integration** | ✅ Drag from Toolbox | ❌ Manual attachment in Inspector |
| **Per-instance properties** | ✅ Via Properties panel | ✅ Via ShaderMaterial in Inspector |
| **Works in editor** | ✅ (`@tool` script) | ✅ (shaders always run) |
| **Custom tooltip** | ✅ Description field | N/A (no toolbox entry) |
| **Performance** | CPU (GDScript `_process`) | GPU (vertex shader) |
| **Best for** | Reusable animated panels | Full-form visual effects |

**Recommendation:** Use Approach A for reusable controls you'll drag onto multiple forms. Use Approach B for one-off visual effects or advanced GPU-driven animations (ripples, distortion, color shifts).

---

## What You Learned

- ✅ How to create a **custom control** with a `@tool` GDScript + `.tscn` scene
- ✅ How to **register custom controls** in the Components dialog
- ✅ How to set a **custom tooltip description** for your control
- ✅ How to write a **vertex shader** for form background effects
- ✅ How to attach a **ShaderMaterial** to `_FormBackground`
- ✅ The difference between **script-based** and **shader-based** animation

---

## Next Steps

- **Try the WobblyButton** — the included example in `custom_controls/WobblyButton.gd` shows hover glow and pulse on a Button
- **Combine both approaches** — put a WobblyPanel on a form AND apply a shader to `_FormBackground` for layered effects
- **Create more custom controls** — animated text boxes, gradient frames, or particle-emitting panels
- **Share your controls** — just send the `.gd` + `.tscn` files; the recipient registers them through Components
- **Explore the shader demos** — see `demos/Graphics/Screen_Space_Shaders/` for vignette, blur, sepia, and more
