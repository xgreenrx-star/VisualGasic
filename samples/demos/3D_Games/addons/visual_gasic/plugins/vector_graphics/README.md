# Vector Graphics Plugin

This plugin provides a small vector drawing API for VisualGasic projects.
It includes a helper resource script and a lightweight `VectorCanvas` node that records drawing commands and renders them with Godot.

## Plugin Files

- `vg_vector_api.gd` — API helper wrapper used by VisualGasic scripts.
- `vector_canvas.gd` — Node2D-based renderer that queues vector commands.
- `vector_graphics_plugin.gd` — UI/plugin integration for the VisualGasic editor.
- `vector_shape.gd` — shared command/value definitions used by the canvas.

## Usage

1. Load the API helper and instantiate the shared API object:

```vb
Dim vg As Object
Set vg = Load("res://addons/visual_gasic/plugins/vector_graphics/vg_vector_api.gd")
If vg <> Null And vg.has_method("Get") Then
    Set vg = vg.Get()
End If
```

2. Create one or more vector canvas layers:

```vb
Dim canvas As Object
Set canvas = vg.CreateVectorCanvas()
AddChild(canvas)
```

3. Draw shapes, text, and gauges:

```vb
Call vg.Clear(canvas)
Call vg.DrawRoundedRect(canvas, Rect2(10, 10, 200, 120), 16.0, 4.0, Color8(80, 146, 220), True, Color8(10, 20, 40, 200))
Call vg.DrawTextCentered(canvas, Vector2(110, 60), "Vector UI", Color8(230, 240, 255), Null)
Call vg.DrawGauge(canvas, Vector2(110, 200), 84.0, 0.72, 6.0, Color8(80, 220, 140), Color8(80, 90, 140, 120))
Call vg.Render(canvas)
```

## Supported API methods

- `CreateVectorCanvas()`
- `Clear(canvas)`
- `Render(canvas)`
- `DrawLine(canvas, from, to, width, color)`
- `DrawRect(canvas, rect, width, color, fill, fill_color)`
- `DrawRoundedRect(canvas, rect, radius, width, color, fill, fill_color)`
- `DrawEllipse(canvas, rect, width, color, fill, fill_color, segments)`
- `DrawCircle(canvas, center, radius, color, fill, fill_color)`
- `DrawArc(canvas, center, radius, start_angle, end_angle, segments, width, color, fill, fill_color)`
- `DrawText(canvas, position, text, color, font)`
- `DrawTextCentered(canvas, position, text, color, font)`
- `DrawTextRightAligned(canvas, position, text, color, font)`
- `DrawVectorText(canvas, position, text, color, scale, width, align, spacing, font_name)`
- `DrawVectorTextCentered(canvas, position, text, color, scale, width, spacing, font_name)`
- `DrawVectorTextRightAligned(canvas, position, text, color, scale, width, spacing, font_name)`
- `RegisterVectorFont(canvas, name, glyphs, make_default)`
- `SetVectorFont(canvas, name)`
- `GetVectorFontNames(canvas)`
- `DrawGauge(canvas, center, radius, progress, width, color, bg_color, start_angle, end_angle)`

## Vector Fonts

Vector fonts are stroke-based fonts that the `VectorCanvas` can render directly. You can register custom fonts by name and then draw text using the registered font.

### Register a font

```vb
Dim fontGlyphs As Object
Set fontGlyphs = {
    "A": {"width": 10.0, "strokes": [[Vector2(0, 10), Vector2(4, 0), Vector2(8, 10)], [Vector2(2, 5), Vector2(6, 5)]]},
    "B": {"width": 10.0, "strokes": [[Vector2(0, 0), Vector2(0, 10), Vector2(5, 10), Vector2(7, 8), Vector2(7, 6), Vector2(5, 4), Vector2(0, 4)], [Vector2(5, 4), Vector2(7, 2), Vector2(7, 0), Vector2(5, 0), Vector2(0, 0)]]},
    " ": {"width": 6.0, "strokes": []}
}

Call vg.RegisterVectorFont(canvas, "retro", fontGlyphs, True)
```

`make_default` sets the registered font as the default for `DrawVectorText()` when no explicit font name is provided.

Font glyph keys are uppercased before drawing, so define glyphs with uppercase characters. Missing characters use a default blank width.

### Draw with a named vector font

```vb
Call vg.DrawVectorText(canvas, Vector2(100, 100), "HELLO", Color8(255, 255, 255), 2.0, 2.0, "left", 2.0, "retro")
Call vg.DrawVectorTextCentered(canvas, Vector2(100, 160), "WELCOME", Color8(255, 255, 255), 2.0, 2.0, 2.0, "retro")

' DrawText also supports vector font names when the font argument is a string.
Call vg.DrawText(canvas, Vector2(100, 220), "SCORE", Color8(255, 255, 255), "retro")
```

### Query registered fonts

```vb
Dim names As Array
Set names = vg.GetVectorFontNames(canvas)
```

## Notes

- `VectorCanvas` stores drawing commands until `Render()` is called.
- Use multiple canvas instances for static and dynamic layers.
- This folder is intended to be self-contained for the `vector_dashboard` project.
