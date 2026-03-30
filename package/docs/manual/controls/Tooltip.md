# Tooltip

> Game UI Tier 2 control — Hover popup showing icon, title, and description.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| Tooltip | Game UI | PopupPanel |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| Title | String | `"Tooltip"` | Bold heading text |
| Description | String | `"Description text"` | Body text shown below title |
| IconPath | String | `""` | Optional `res://` path to icon texture |
| ShowDelay | float | `0.3` | Seconds before tooltip appears |
| HideDelay | float | `0.1` | Seconds before tooltip disappears |
| FollowMouse | bool | `false` | Reposition to mouse cursor each frame |
| ShowAnimation | enum | `FadeIn` | `FadeIn`, `ScaleUp`, `SlideDown`, `None` |
| TransitionSpeed | float | `0.2` | Animation duration in seconds |

## Signals

| Signal | Description |
|--------|-------------|
| `tooltip_shown` | Emitted after show animation completes |
| `tooltip_hidden` | Emitted after hide animation completes |

## Methods

| Method | Description |
|--------|-------------|
| `show_tooltip()` | Begin show animation |
| `hide_tooltip()` | Begin hide animation |

## VB6-Style Example

```vb
' Show tooltip on mouse-over
Sub EnemyPortrait_MouseMove(Button, Shift, X, Y)
    Tooltip1.Title = "Goblin King"
    Tooltip1.Description = "Level 12 Boss  HP: 5000"
    Tooltip1.show_tooltip
End Sub

Sub EnemyPortrait_MouseLeave()
    Tooltip1.hide_tooltip
End Sub
```

## Design-Time Appearance

- Color: dark slate `(0.15, 0.15, 0.20, 0.95)`
- Label: **Tip**
- Default size: 180 × 60
