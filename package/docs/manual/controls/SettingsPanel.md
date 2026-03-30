# SettingsPanel

> Game UI Tier 2 control — Options screen with audio, video, and controls sections.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| SettingsPanel | Game UI | VBoxContainer |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| PanelTitle | String | `"Settings"` | Header text |
| ShowAudio | bool | `true` | Show Master/Music/SFX volume sliders |
| ShowVideo | bool | `true` | Show fullscreen, VSync, resolution options |
| ShowControls | bool | `true` | Show sensitivity slider, invert-Y checkbox |
| BackgroundAlpha | float | `0.9` | Panel transparency |

## Signals

| Signal | Description |
|--------|-------------|
| `settings_applied(data: Dictionary)` | Emitted when Apply is pressed |
| `settings_cancelled` | Emitted when Cancel is pressed |

## Methods

| Method | Description |
|--------|-------------|
| `apply_settings()` | Trigger apply with current values |
| `reset_defaults()` | Reset all sliders/checks to defaults |

## VB6-Style Example

```vb
Sub MenuButton_Click()
    SettingsPanel1.Visible = True
End Sub

Sub SettingsPanel1_settings_applied(data)
    AudioServer.SetBusVolume 0, data["master_volume"]
    If data["fullscreen"] Then
        DisplayServer.WindowMode = 3  ' Fullscreen
    End If
End Sub
```

## Design-Time Appearance

- Color: dark slate `(0.12, 0.12, 0.18, 0.9)`
- Label: **Set**
- Default size: 320 × 280
