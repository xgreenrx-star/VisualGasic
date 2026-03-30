# SkillTree

> Game UI Tier 3 control — Node-based skill/talent tree with unlock paths.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| SkillTree | Game UI | GraphEdit |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| NodeCount | int (3–20) | `9` | Total number of skill nodes |
| Columns | int (1–6) | `3` | Grid columns |
| NodeRadius | float | `16.0` | Circle radius per node |
| SkillNames | String | `"Slash,Block,Heal,..."` | Comma-separated skill labels |
| UnlockedColor | Color | `(0.3, 0.85, 0.4)` | Unlocked node color |
| LockedColor | Color | `(0.4, 0.4, 0.5)` | Locked node color |
| LineColor | Color | `(0.3, 0.35, 0.45)` | Connection line color |
| SelectedIndex | int | `-1` | Currently selected node |

## Signals

| Signal | Description |
|--------|-------------|
| `skill_selected(index)` | Emitted on node click |
| `skill_unlocked(index)` | Emitted when a node is unlocked |

## Methods

| Method | Description |
|--------|-------------|
| `unlock_skill(index)` | Unlock a skill node |
| `select_skill(index)` | Highlight a node |

## VB6-Style Example

```vb
Sub SkillTree1_skill_selected(index)
    If Player.SkillPoints > 0 Then
        SkillTree1.unlock_skill index
        Player.SkillPoints = Player.SkillPoints - 1
    End If
End Sub
```

## Design-Time Appearance

- Color: dark navy `(0.10, 0.12, 0.18, 0.9)`
- Label: **Skl**
- Default size: 240 × 240
