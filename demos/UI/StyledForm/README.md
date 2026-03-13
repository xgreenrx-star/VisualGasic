# Styled Form Demo

Demonstrates VisualGasic v4.1.0's property system with live Font, Color, and Border support.

## Properties Showcased

| Property | What It Does | Control |
|----------|-------------|---------|
| **FontName** | Sets typeface (e.g. "Segoe UI", "Courier New") | lblTitle, txtInput |
| **FontBold** | Bold weight (True/False) | lblTitle |
| **FontItalic** | Italic style (True/False) | lblSubtitle |
| **ForeColor** | Text color (`&HRRGGBB`) | lblTitle, txtInput |
| **BackColor** | Background color (`&HRRGGBB`) | txtInput, Frame1 |
| **BorderStyle** | 0 = None, 1 = Fixed Single | txtInput, Frame1 |
| **ShapeColor** | Fill color for ColorRect | shpAccent |

## How to Run

1. Open the **demo/** project in Godot 4.6+
2. Open `styled_form.vg` in the Visual Gasic Form Designer
3. Observe the **live preview** — fonts, colors, and borders render in real-time
4. Press **F5** to run — the serializer generates proper Godot sub-resources

## What Happens Under the Hood

- `FontName="Segoe UI"` + `FontBold=True` → `[sub_resource type="SystemFont"]` with `font_names` and `font_weight=700`
- `BackColor=&H1A1A2E` → `[sub_resource type="StyleBoxFlat"]` with `bg_color = Color(0.1, 0.1, 0.18, 1)`
- `ForeColor=&HFF6600` → `theme_override_colors/font_color = Color(1, 0.4, 0, 1)`
- `BorderStyle=1` → `StyleBoxFlat` with `border_width_left/top/right/bottom = 1`
- `ShapeColor=&H3366FF` → `color = Color(0.2, 0.4, 1, 1)` on ColorRect
