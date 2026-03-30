# ChatBox

> Game UI Tier 3 control — Scrollable chat log with message input field.

## Toolbox

| Label | Tab | Icon |
|-------|-----|------|
| ChatBox | Game UI | RichTextLabel |

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| MaxLines | int (10–500) | `100` | Maximum lines before oldest are removed |
| ShowInput | bool | `true` | Show the text input field |
| PlaceholderText | String | `"Type a message..."` | Input placeholder |
| ChatTitle | String | `"Chat"` | Header label |
| BackgroundAlpha | float | `0.85` | Panel transparency |
| SystemColor | Color | `(0.6, 0.6, 0.7)` | System message color |
| PlayerColor | Color | `(0.3, 0.8, 1.0)` | Default player name color |

## Signals

| Signal | Description |
|--------|-------------|
| `message_sent(text)` | Emitted when user presses Enter |

## Methods

| Method | Description |
|--------|-------------|
| `add_message(sender, text, color)` | Append a player message |
| `add_system_message(text)` | Append a system notice |

## VB6-Style Example

```vb
Sub ChatBox1_message_sent(text)
    Network.SendChat PlayerName, text
    ChatBox1.add_message PlayerName, text
End Sub

Sub Network_ChatReceived(sender, text)
    ChatBox1.add_message sender, text, vbGreen
End Sub
```

## Design-Time Appearance

- Color: dark charcoal `(0.08, 0.08, 0.12, 0.85)`
- Label: **Cht**
- Default size: 260 × 180
