# TabPanel

> Game UI Tier 3 control — Game-styled tab container with selectable pages.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| TabPanel | Game UI | TabContainer |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| TabNames | String | `"Inventory,Skills,Map"` | Comma-separated tab labels |
| ActiveTab | int | `0` | Currently selected tab index |
| TabHeight | int (20–60) | `28` | Height of tab buttons |
| ActiveColor | Color | `(0.2, 0.55, 0.9)` | Selected tab background |
| InactiveColor | Color | `(0.2, 0.2, 0.28)` | Unselected tab background |
| PanelAlpha | float | `0.9` | Overall panel transparency |

## Signals

| Signal | Description |
|--------|-------------|
| `tab_changed(index)` | Emitted when a different tab is selected |

## Methods

| Method | Description |
|--------|-------------|
| `set_tab(index)` | Switch to a tab programmatically |

## VB6-Style Example

```vb
Sub TabPanel1_tab_changed(index)
    Select Case index
        Case 0: ShowInventory
        Case 1: ShowSkills
        Case 2: ShowMap
    End Select
End Sub
```

## Design-Time Appearance

- Color: dark `(0.08, 0.08, 0.12, 0.9)`
- Label: **TPn**
- Default size: 300 × 200
