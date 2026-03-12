# ConfirmDialog

> Game UI Tier 2 control — Animated "Are you sure?" popup with Yes/No buttons.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| ConfirmDialog | Game UI | AcceptDialog |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| DialogTitle | String | `"Confirm"` | Title bar text |
| Message | String | `"Are you sure?"` | Body message |
| YesText | String | `"Yes"` | Confirm button label |
| NoText | String | `"No"` | Cancel button label |
| ShowAnimation | enum | `PopBounce` | `FadeIn`, `ScaleUp`, `PopBounce`, `None` |
| TransitionSpeed | float | `0.25` | Animation duration in seconds |
| DimBackground | bool | `true` | Darken area behind dialog |

## Signals

| Signal | Description |
|--------|-------------|
| `confirmed` | Emitted when Yes is pressed |
| `cancelled` | Emitted when No is pressed |

## Methods

| Method | Description |
|--------|-------------|
| `show_dialog()` | Show with animation |
| `hide_dialog()` | Dismiss with fade-out |

## VB6-Style Example

```vb
Sub QuitButton_Click()
    ConfirmDialog1.Message = "Quit to main menu?"
    ConfirmDialog1.show_dialog
End Sub

Sub ConfirmDialog1_confirmed()
    SceneTree.ChangeScene "res://MainMenu.tscn"
End Sub

Sub ConfirmDialog1_cancelled()
    ' Player changed their mind
End Sub
```

## Design-Time Appearance

- Color: dark slate `(0.12, 0.12, 0.18, 0.95)`
- Label: **Cfm**
- Default size: 280 × 140
