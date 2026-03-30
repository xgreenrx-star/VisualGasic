# AmmoCounter

> Game UI Tier 3 control — Clip / reserve ammo display like "30 / 120".

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| AmmoCounter | Game UI | Label |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| CurrentAmmo | int | `30` | Rounds in current clip |
| MaxClip | int | `30` | Maximum clip capacity |
| ReserveAmmo | int | `120` | Total reserve rounds |
| ShowIcon | bool | `true` | Show bullet icon |
| AmmoColor | Color | `(1, 1, 1)` | Normal ammo text color |
| LowAmmoColor | Color | `(1.0, 0.3, 0.2)` | Color when ammo is low |
| LowAmmoThreshold | float | `0.25` | Fraction below which color turns red |
| FontSize | int | `16` | Text size |
| IconText | String | `"⊕"` | Icon character |

## Signals

| Signal | Description |
|--------|-------------|
| `ammo_changed(current, reserve)` | Emitted on any ammo change |
| `ammo_empty` | Emitted when current ammo hits 0 |

## Methods

| Method | Description |
|--------|-------------|
| `fire(rounds)` | Decrease current ammo |
| `reload()` | Refill clip from reserve |

## VB6-Style Example

```vb
Sub FireButton_Click()
    AmmoCounter1.fire 1
End Sub

Sub AmmoCounter1_ammo_empty()
    PlaySound "click_empty"
End Sub

Sub ReloadButton_Click()
    AmmoCounter1.reload
End Sub
```

## Design-Time Appearance

- Color: white `(1.0, 1.0, 1.0)`
- Label: **Amo**
- Default size: 110 × 28
