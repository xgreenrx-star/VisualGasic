# Zork I: The Great Underground Empire

A faithful VisualGasic reimplementation of the classic Infocom text adventure by Marc Blank, Dave Lebling, Bruce Daniels, and Tim Anderson.

## Features

- **All 110 rooms** from the original game with correct connections
- **55+ objects** including all 19 treasures, key items, and NPCs
- **Natural language parser** — understands commands like `take lamp`, `put sword in case`, `attack troll with sword`
- **Full combat system** — fight the troll, thief, and cyclops
- **Light/dark mechanics** — manage your lamp carefully, beware the grue!
- **Scoring system** — collect treasures and place them in the trophy case (350 points max)
- **Text-to-Speech** — toggle with the `TTS` command to hear the game narrated aloud
- **Classic puzzles** — exorcism, coal machine, rainbow, maze, and more

## Setup

1. Copy the `addons/visual_gasic/` folder into this project directory (or create a symlink):
   ```bash
   ln -s ../../../addons/visual_gasic addons/visual_gasic
   ```

2. Open this project in Godot 4.5+

3. Enable the VisualGasic plugin in Project → Project Settings → Plugins

4. Press F5 to run!

## Commands

| Command | Description |
|---------|-------------|
| `north`, `south`, `east`, `west` (or `n`, `s`, `e`, `w`) | Move in a direction |
| `up`, `down`, `in`, `out` | Other movement |
| `look` (or `l`) | Describe current room |
| `inventory` (or `i`) | List carried items |
| `take [item]` / `drop [item]` | Pick up or put down items |
| `open [item]` / `close [item]` | Open or close doors/containers |
| `examine [item]` (or `x [item]`) | Look closely at something |
| `read [item]` | Read text on an object |
| `turn on [item]` / `turn off [item]` | Activate/deactivate (e.g., lamp) |
| `attack [enemy] with [weapon]` | Fight an enemy |
| `put [item] in [container]` | Place item in a container |
| `unlock [item] with [key]` | Unlock something |
| `say [word]` | Say something aloud |
| `wave [item]` | Wave an item |
| `dig` | Dig (requires shovel) |
| `tie [item] to [object]` | Tie something |
| `pray` | Pray |
| `inflate [item] with [tool]` | Inflate something |
| `climb [item]` | Climb something |
| `eat [item]` | Eat something |
| `score` | Show current score and rank |
| `verbose` / `brief` | Toggle room description mode |
| `tts` | Toggle text-to-speech |
| `quit` | End the game |

## Credits

- **Original Zork**: Marc Blank, Dave Lebling, Bruce Daniels, Tim Anderson (Infocom, 1980)
- **ZIL Source**: [historicalsource/zork1](https://github.com/historicalsource/zork1) (MIT License)
- **VG Implementation**: Built with VisualGasic for Godot 4
