# Pong with Whenever - Reactive Game Programming Demo

This example demonstrates Visual Gasic's **Whenever** feature for reactive game programming. It shows how game logic can be declaratively defined to respond to state changes automatically.

## What is Whenever?

`Whenever` is Visual Gasic's reactive programming system. Instead of manually checking conditions in your game loop, you declare what should happen when a variable meets certain conditions. The system automatically monitors these variables and triggers callbacks when conditions are met.

## Features Demonstrated in This Example

### 1. Score Change Reactions (Changes Operator)
```vb
Whenever Score1 Changes
    Print "Player 1 scored! Score: " & Str(Score1)
    Paddle1.color = Color(0, 1, 0)  ' Bright green flash
End Whenever

Whenever Score2 Changes
    Print "Player 2 scored! Score: " & Str(Score2)
    Paddle2.color = Color(0, 0, 1)  ' Bright blue flash
End Whenever
```
These sections trigger automatically whenever either player's score changes, providing visual feedback by flashing the paddle.

### 2. Game Point Announcements (Exceeds Operator)
```vb
Whenever Score1 Exceeds 4
    Print "*** GAME POINT for Player 1! ***"
End Whenever

Whenever Score2 Exceeds 4
    Print "*** GAME POINT for Player 2! ***"
End Whenever
```
Automatically announce when a player reaches game point.

### 3. Victory Detection (Exceeds Operator)
```vb
Whenever Score1 Exceeds 5
    Print "PLAYER 1 WINS!"
End Whenever

Whenever Score2 Exceeds 5
    Print "PLAYER 2 WINS!"
End Whenever
```
Automatically detect and announce when a player wins (first to 6 points).

## How It Works

The Whenever system:
1. **Monitors** the specified variable each frame
2. **Compares** the current value against the condition
3. **Triggers** the block when the condition is first met
4. **Resets** when the condition is no longer true (for re-triggering)

## Using the Immediate Window

1. Run the game
2. Open the Immediate Window (bottom panel)
3. Click the **Whenever** tab
4. See all active Whenever sections with their:
   - **Condition**: What triggers the section
   - **Status**: Active ✓ or Paused ⏸
   - **Callbacks**: Which procedures are called
   - **Scope**: Global or Local

### Pause/Resume Sections

Right-click any section in the Whenever tab to:
- **Pause**: Temporarily disable a section
- **Resume**: Re-enable a paused section
- **Go to Definition**: Jump to the code

Try pausing `Player1Wins` to make Player 1 never win, or pause `HotRally` to disable the visual effects!

## Suspend/Resume in Code

You can also control Whenever sections from your VG code:

```vb
' Pause scoring after game ends
Suspend Whenever Player1Scores
Suspend Whenever Player2Scores

' Resume later
Resume Whenever Player1Scores
```

## Controls

- **Player 1**: W (up) / S (down)
- **Player 2**: ↑ (up) / ↓ (down)
- **Quit**: ESC

## Running the Example

1. Open `pong_whenever.tscn` in Godot
2. Press F5 to run
3. Watch the Whenever tab in the Immediate Window to see sections trigger in real-time!

## Whenever Operators

This example uses several Whenever operators:

| Operator | Description | Example |
|----------|-------------|---------|
| `Changes` | Triggers when value changes at all | `Score1 Changes` |
| `Exceeds` | Triggers when value goes above threshold | `Score1 Exceeds 4` |
| `Becomes` | Triggers when value equals target | `RallyCount Becomes 5` |
| `Below` | Triggers when value drops below threshold | `Health Below 30` |
| `Between...And` | Triggers when in range | `Health Between 1 And 10` |
| `Contains` | For strings | `Username Contains "admin"` |

## Benefits of Reactive Programming

1. **Cleaner Code**: No more scattered `If` checks throughout your game loop
2. **Debuggable**: See all conditions in the Immediate Window
3. **Pausable**: Disable features without changing code
4. **Declarative**: State what should happen, not how to check for it
5. **Automatic**: The system handles monitoring and triggering

Enjoy reactive game programming with Visual Gasic! 🏓
