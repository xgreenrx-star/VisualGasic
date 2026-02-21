# Pong Demo

A complete two-player Pong game written in VisualGasic.

## Controls

| Player | Up | Down |
|--------|-----|------|
| Player 1 (Left) | W | S |
| Player 2 (Right) | ↑ | ↓ |

- **Enter** - Start/Restart game
- **Escape** - Pause

## Features Demonstrated

- Game loop with `_Process()` and `_Draw()`
- Input handling with `Input.IsActionPressed()`
- Constants for configuration
- Collision detection
- Score tracking
- Game states (playing, paused, game over)
- Drawing primitives (`DrawRect`, `DrawString`)
- Math functions (`Cos`, `Sin`, `Rnd`, `Clamp`, `Abs`)

## How to Run

1. Open this folder in Godot 4.5+
2. Make sure the VisualGasic addon is enabled
3. Run the project (F5)

## Screenshot

```
    3                    5
    
         ┌──────────────┐
         │              │
    ██   │      ██      │   ██
    ██   │              │   ██
         │              │
         └──────────────┘
```

First to 11 points wins!
