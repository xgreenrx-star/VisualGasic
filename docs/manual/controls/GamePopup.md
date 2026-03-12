# GamePopup

> Game UI Tier 3 control — Animated modal popup with title, body, and close button.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| GamePopup | Game UI | PopupPanel |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| PopupTitle | String | `"Notice"` | Header text |
| BodyText | String | `"Something happened!"` | Multi-line body text |
| ShowCloseButton | bool | `true` | Show the OK/Close button |
| CloseButtonText | String | `"OK"` | Close button label |
| ShowAnimation | enum | `ScaleUp` | `FadeIn`, `ScaleUp`, `SlideDown`, `None` |
| AnimationSpeed | float | `0.25` | Animation duration |
| TitleColor | Color | `(1.0, 0.85, 0.4)` | Title text color |

## Signals

| Signal | Description |
|--------|-------------|
| `popup_closed` | Emitted after close animation completes |

## Methods

| Method | Description |
|--------|-------------|
| `show_popup()` | Show with animation |
| `close_popup()` | Dismiss with fade-out |

## VB6-Style Example

```vb
Sub LevelComplete()
    GamePopup1.PopupTitle = "Level Complete!"
    GamePopup1.BodyText = "You earned 500 XP and a Rare Sword."
    GamePopup1.show_popup
End Sub

Sub GamePopup1_popup_closed()
    LoadNextLevel
End Sub
```

## Design-Time Appearance

- Color: dark violet `(0.10, 0.10, 0.16, 0.95)`
- Label: **Pop**
- Default size: 260 × 160
