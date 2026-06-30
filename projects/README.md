# VisualGasic Game Projects

This folder contains complete, ready-to-play game projects made with VisualGasic for Godot 4.5.

Each project is a standalone Godot project with the VisualGasic addon included. You can open any of these projects directly in Godot and run them.

## Projects

### 1. Defender Clone (`defender/`)
A Defender-style side-scrolling space shooter with enemies, bullets, and scrolling gameplay.

**Features:**
- Side-scrolling camera system
- Enemy AI that chases the player
- Bidirectional shooting (player and enemies)
- Starfield parallax background
- Lives and scoring system

**Controls:** Arrow keys to move, Space to shoot

---

### 2. Asteroids Clone (`asteroids/`)
Classic Asteroids arcade game with rotating ship physics and asteroid splitting.

**Features:**
- Momentum-based ship physics
- Asteroid splitting (large → medium → small)
- Screen wrapping
- Progressive difficulty
- Invulnerability frames after hits

**Controls:** Left/Right to rotate, Up to thrust, Space to shoot

---

### 3. 3D Racing Game (`racing_3d/`)
A simple 3D racing game with an oval track, checkpoints, and lap timing.

**Features:**
- Full 3D graphics and camera
- Realistic car physics
- Checkpoint and lap system
- Track boundaries with collision
- Race timer

**Controls:** Arrow keys to drive (Up: accelerate, Down: brake, Left/Right: steer)

---

### 4. 2D Platformer (`platformer_2d/`)
Classic platformer with jumping, enemies, coins, and platform traversal.

**Features:**
- Gravity and jump physics
- Collectible coins
- Patrolling enemies (jump on them to defeat)
- Multiple platform layouts
- Camera following
- Lives system

**Controls:** Arrow keys to move, Space to jump

---

## How to Use

1. Open Godot 4.5 (or later)
2. Select "Import" and navigate to one of the project folders
3. Open the project
4. Click the "Play" button (or press F5) to run the game

Each project contains:
- `project.godot` - Godot project configuration
- `main.tscn` - Main scene to run
- `*.vg` - VisualGasic game script
- `addons/visual_gasic/` - VisualGasic language support (GDExtension)
- `README.md` - Project-specific instructions

## VisualGasic

All games are written entirely in VisualGasic, a BASIC-like language that compiles to bytecode for the Godot engine. The game logic demonstrates:

- Object management and arrays
- Physics and collision detection
- Input handling
- UI updates
- Game state management
- Camera control
- 2D and 3D positioning

## Requirements

- Godot Engine 4.5 or later
- Linux, Windows, or macOS (precompiled libraries included for all platforms)

## Learning from These Projects

These games are designed as learning examples. You can:
- Study the `.vg` files to see VisualGasic syntax
- Modify values to experiment (speeds, scores, spawn rates, etc.)
- Add new features (power-ups, more levels, sound effects)
- Use them as templates for your own games

## Notes

- All games use simple ColorRect nodes for graphics (easy to replace with sprites)
- Game logic is self-contained in single `.vg` files
- Projects are optimized for clarity and learning

Have fun playing and modding these games!
