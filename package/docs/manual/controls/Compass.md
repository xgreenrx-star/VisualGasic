# Compass

> Game UI Tier 3 control — Horizontal strip compass showing N/S/E/W bearings.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| Compass | Game UI | Control |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| Bearing | float (0–360) | `0.0` | Current heading in degrees (0 = North) |
| StripWidth | float | `200.0` | Width of the compass strip |
| StripHeight | float | `28.0` | Height of the compass strip |
| BackgroundColor | Color | `(0.08, 0.08, 0.12, 0.85)` | Strip background |
| TickColor | Color | `(0.6, 0.6, 0.7)` | Minor tick and label color |
| CardinalColor | Color | `(1.0, 0.9, 0.4)` | N/S/E/W label color |
| CenterMarkerColor | Color | `(1.0, 0.3, 0.2)` | Center indicator color |
| ShowMarkers | bool | `true` | Show center triangle marker |

## Signals

| Signal | Description |
|--------|-------------|
| `bearing_changed(degrees)` | Emitted whenever bearing updates |

## Methods

| Method | Description |
|--------|-------------|
| `set_bearing(degrees)` | Set heading (wraps 0–360) |

## VB6-Style Example

```vb
Sub _Process(delta)
    Compass1.Bearing = Player.Rotation * 180 / 3.14159
End Sub
```

## Design-Time Appearance

- Color: dark `(0.08, 0.08, 0.12, 0.85)`
- Label: **Cmp**
- Default size: 200 × 28
