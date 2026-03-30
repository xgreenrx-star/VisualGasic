# XPBar

> Game UI Tier 3 control — Segmented experience bar with level badge.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| XPBar | Game UI | ProgressBar |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| CurrentXP | int | `350` | Current experience points |
| MaxXP | int | `1000` | XP needed for next level |
| Level | int | `5` | Current player level |
| Segments | int (1–20) | `10` | Number of bar segments |
| BarHeight | float | `20.0` | Bar height in pixels |
| BarWidth | float | `220.0` | Bar width in pixels |
| FillColor | Color | `(0.3, 0.75, 1.0)` | Filled portion color |
| EmptyColor | Color | `(0.15, 0.15, 0.22)` | Empty portion color |
| SegmentBorderColor | Color | `(0.08, 0.08, 0.12)` | Divider line color |
| ShowLevel | bool | `true` | Show circular level badge |
| LevelBadgeColor | Color | `(1.0, 0.85, 0.3)` | Badge outline/text color |

## Signals

| Signal | Description |
|--------|-------------|
| `level_up(new_level)` | Emitted when XP exceeds MaxXP (auto-increments level) |
| `xp_changed(current, max)` | Emitted on any XP change |

## Methods

| Method | Description |
|--------|-------------|
| `add_xp(amount)` | Add experience (auto level-up) |

## VB6-Style Example

```vb
Sub Enemy_Defeated(xp_reward)
    XPBar1.add_xp xp_reward
End Sub

Sub XPBar1_level_up(new_level)
    GamePopup1.PopupTitle = "Level Up!"
    GamePopup1.BodyText = "You reached level " & new_level
    GamePopup1.show_popup
End Sub
```

## Design-Time Appearance

- Color: cyan `(0.30, 0.75, 1.0)`
- Label: **XPB**
- Default size: 260 × 20
