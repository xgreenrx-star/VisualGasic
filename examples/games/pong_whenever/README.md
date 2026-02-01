# Pong with Whenever - Reactive Game Programming Demo

This example demonstrates Visual Gasic's **Whenever** feature for reactive game programming. It shows how game logic can be declaratively defined to respond to state changes automatically.

## What is Whenever?

`Whenever` is Visual Gasic's reactive programming system. Instead of manually checking conditions in your game loop, you declare what should happen when a variable meets certain conditions. The system automatically monitors these variables and triggers callbacks when conditions are met.

## Features Demonstrated

### 1. Score Monitoring
```vb
Whenever Section Player1Scores Score1 Changes OnPlayer1Score
Whenever Section Player2Scores Score2 Changes OnPlayer2Score
```
These sections trigger callbacks whenever either player's score changes.

### 2. Victory Conditions
```vb
Whenever Section Player1Wins Score1 Exceeds 4 OnPlayer1Victory
Whenever Section Player2Wins Score2 Exceeds 4 OnPlayer2Victory
```
Automatically detect when a player wins (first to 5 points).

### 3. Rally System
```vb
Whenever Section HotRally RallyCount Exceeds 9 OnHotRally
Whenever Section MegaRally RallyCount Exceeds 19 OnMegaRally
```
Track exciting rallies - the ball changes color as rallies get longer!

### 4. Speed Warnings
```vb
Whenever Section SpeedWarning BallSpeed Exceeds 500 OnBallTooFast
Whenever Section InsaneSpeed BallSpeed Exceeds 700 OnInsaneSpeed
```
Visual feedback when the game gets intense.

### 5. Power-Up Trigger
```vb
Whenever Section PowerUpCheck RallyCount Becomes 5 ActivatePowerUp
```
Activate a power-up after 5 consecutive hits.

## Using the Immediate Window

The real power of Whenever is visible in the **Immediate Window**:

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
