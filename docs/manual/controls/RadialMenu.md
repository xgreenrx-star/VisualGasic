# RadialMenu

> Game UI Tier 2 control — Pie/wheel menu for ability or weapon selection.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| RadialMenu | Game UI | GraphEdit |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| ItemCount | int (2–12) | `6` | Number of wedge segments |
| Radius | float | `90.0` | Outer radius in pixels |
| CenterRadius | float | `25.0` | Dead zone at the center |
| ItemLabels | String | `"Attack,Defend,Magic,Item,Flee,Wait"` | Comma-separated wedge labels |
| NormalColor | Color | `(0.2, 0.25, 0.35, 0.85)` | Default wedge fill |
| HoverColor | Color | `(0.3, 0.5, 0.8, 0.9)` | Highlighted wedge fill |
| BorderColor | Color | `(0.5, 0.55, 0.65, 0.6)` | Wedge outline |
| SelectedIndex | int | `-1` | Currently highlighted wedge (-1 = none) |

## Signals

| Signal | Description |
|--------|-------------|
| `item_clicked(index: int)` | Emitted when a wedge is clicked |
| `item_hovered(index: int)` | Emitted when cursor enters a wedge |

## Methods

| Method | Description |
|--------|-------------|
| `show_menu()` | Display the radial menu |
| `hide_menu()` | Hide the radial menu |
| `select_item(index)` | Programmatically select a wedge |

## VB6-Style Example

```vb
Sub Form_KeyDown(KeyCode, Shift)
    If KeyCode = vbKeyTab Then
        RadialMenu1.show_menu
    End If
End Sub

Sub RadialMenu1_item_clicked(index As Integer)
    Select Case index
        Case 0: Player.Attack
        Case 1: Player.Defend
        Case 2: OpenMagicMenu
    End Select
End Sub
```

## Design-Time Appearance

- Color: dark blue `(0.12, 0.14, 0.22, 0.9)`
- Label: **Rad**
- Default size: 200 × 200
