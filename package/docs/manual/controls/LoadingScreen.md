# LoadingScreen

> Game UI Tier 2 control — Full-screen overlay with progress bar and tip text.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| LoadingScreen | Game UI | ColorRect |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| TipText | String | `"Press SPACE to jump"` | Hint displayed below the bar |
| ProgressLabel | String | `"Loading..."` | Text above the progress bar |
| Progress | float (0.0–1.0) | `0.0` | Current load fraction |
| BarColor | Color | `(0.2, 0.7, 1.0)` | Progress bar fill color |
| BackgroundColor | Color | `(0.05, 0.05, 0.08, 1.0)` | Full-screen backdrop |
| ShowSpinner | bool | `true` | Show animated spinner |
| ShowTip | bool | `true` | Show tip text |

## Signals

| Signal | Description |
|--------|-------------|
| `loading_finished` | Emitted when `Progress` reaches 1.0 |

## Methods

| Method | Description |
|--------|-------------|
| `set_progress(value)` | Set load fraction 0.0–1.0 |

## VB6-Style Example

```vb
Sub Form_Load()
    LoadingScreen1.Visible = True
    LoadingScreen1.TipText = "Generating terrain..."
End Sub

Sub LoadTimer_Timer()
    LoadingScreen1.Progress = LoadingScreen1.Progress + 0.05
End Sub

Sub LoadingScreen1_loading_finished()
    LoadingScreen1.Visible = False
    StartGame
End Sub
```

## Design-Time Appearance

- Color: near-black `(0.05, 0.05, 0.08, 1.0)`
- Label: **Lod**
- Default size: 320 × 180
