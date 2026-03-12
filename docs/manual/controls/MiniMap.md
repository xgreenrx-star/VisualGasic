# MiniMap

> Game UI Tier 2 control — Corner viewport showing a top-down overview.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| MiniMap | Game UI | SubViewport |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| MapSize | int (60–400) | `120` | Width and height of the map area |
| MapShape | enum | `Square` | `Square` or `Round` |
| ShowBorder | bool | `true` | Draw outer border ring |
| ShowPlayerDot | bool | `true` | Draw player indicator in center |
| PlayerDotColor | Color | `(0.2, 0.8, 1.0)` | Player marker color |
| BorderColor | Color | `(0.4, 0.45, 0.55, 0.7)` | Border outline color |
| BackgroundAlpha | float | `0.85` | Panel transparency |

## Signals

| Signal | Description |
|--------|-------------|
| `map_clicked(position: Vector2)` | Emitted on click with normalized coords |

## Methods

| Method | Description |
|--------|-------------|
| `add_marker(id, position, color)` | Place a named marker |
| `remove_marker(id)` | Remove a named marker |
| `clear_markers()` | Remove all markers |

## VB6-Style Example

```vb
Sub Form_Load()
    MiniMap1.MapShape = 1  ' Round
    MiniMap1.ShowPlayerDot = True
End Sub

Sub MiniMap1_map_clicked(pos)
    Player.MoveTo pos.x * WorldWidth, pos.y * WorldHeight
End Sub
```

## Design-Time Appearance

- Color: dark green `(0.10, 0.15, 0.10, 0.9)`
- Label: **Map**
- Default size: 140 × 140
