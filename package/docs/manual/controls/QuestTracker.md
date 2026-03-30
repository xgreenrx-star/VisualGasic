# QuestTracker

> Game UI Tier 2 control — Sidebar list displaying active quests and objectives.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| QuestTracker | Game UI | RichTextLabel |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| TrackerTitle | String | `"Quests"` | Header text |
| QuestNames | String | `"Find the Key,Rescue the NPC"` | Comma-separated quest names |
| ShowObjectives | bool | `true` | Show per-quest objective lines |
| MaxVisible | int (1–20) | `5` | Max quests shown before scroll |
| TitleColor | Color | `(1.0, 0.85, 0.4)` | Header text color |
| QuestColor | Color | `(0.85, 0.85, 0.9)` | Active quest text color |
| CompletedColor | Color | `(0.4, 0.7, 0.4)` | Completed quest text color |
| BackgroundAlpha | float | `0.8` | Panel transparency |

## Signals

| Signal | Description |
|--------|-------------|
| `quest_clicked(index: int)` | Emitted when a quest entry is clicked |

## Methods

| Method | Description |
|--------|-------------|
| `add_quest(name)` | Append a quest |
| `remove_quest(index)` | Remove a quest by index |
| `complete_quest(index)` | Mark a quest as completed |

## VB6-Style Example

```vb
Sub Form_Load()
    QuestTracker1.add_quest "Find the Lost Sword"
    QuestTracker1.add_quest "Defeat the Dragon"
End Sub

Sub Dragon_Defeated()
    QuestTracker1.complete_quest 1
End Sub
```

## Design-Time Appearance

- Color: dark purple `(0.15, 0.12, 0.20, 0.9)`
- Label: **Qst**
- Default size: 200 × 160
