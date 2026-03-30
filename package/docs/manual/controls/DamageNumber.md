# DamageNumber

> Game UI Tier 2 control — Floating pop-up number that rises and fades.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| DamageNumber | Game UI | Label |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| Amount | int | `42` | Number displayed |
| NumberColor | Color | `(1.0, 0.3, 0.2)` | Text color |
| FontSize | int | `22` | Base font size |
| PopStyle | enum | `FloatUp` | `FloatUp`, `FloatUpRight`, `Bounce`, `ScaleDown` |
| FloatDistance | float | `60.0` | Pixels the number travels |
| Duration | float | `0.8` | Animation lifetime in seconds |
| ShowCriticalEffect | bool | `false` | 1.5× scale for critical hits |

## Signals

| Signal | Description |
|--------|-------------|
| `pop_finished` | Emitted after the animation ends |

## Methods

| Method | Description |
|--------|-------------|
| `pop(value, color)` | Trigger a new pop with optional override |

## VB6-Style Example

```vb
Sub Enemy_TakeDamage(amount)
    DamageNumber1.Position = Enemy.Position
    DamageNumber1.NumberColor = vbRed
    DamageNumber1.pop amount
End Sub

Sub CriticalHit(amount)
    DamageNumber1.ShowCriticalEffect = True
    DamageNumber1.NumberColor = vbYellow
    DamageNumber1.pop amount
End Sub
```

## Design-Time Appearance

- Color: red `(1.0, 0.3, 0.2)`
- Label: **Dmg**
- Default size: 60 × 28
