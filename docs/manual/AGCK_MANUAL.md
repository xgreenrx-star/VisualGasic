# AGCK — Arcade Game Construction Kit

**AGCK** is a visual game construction tool built as a VisualGasic IDE plugin.  Inspired by the classic *Arcade Game Construction Kit* for the Commodore 64 (1988), it lets you build retro-style arcade games using five visual editors — no programming required.

AGCK appears as a single **🕹️ AGCK** button in the VG IDE toolbar.  Click it to enter the AGCK workspace, which contains five sub-tabs:

| Tab | Icon | Purpose |
|-----|------|---------|
| **Game Settings** | ⚙️ | Configure world physics, screen behavior, lives, controls, and effects |
| **Actors** | 👾 | Define up to 16 game characters with collision, AI, animation, and sound |
| **Sounds** | 🔊 | Compose retro sound effects with a 2-voice waveform synthesizer |
| **Levels** | 🗺️ | Paint tile-based screens, place actors, trace sentry paths |
| **Build** | 🏗️ | Assemble everything into a playable Godot game |

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Game Settings Editor](#game-settings-editor)
3. [Actor Editor](#actor-editor)
4. [Sound Editor](#sound-editor)
5. [Level Editor](#level-editor)
6. [Game Builder](#game-builder)
7. [Saving & Loading Projects](#saving--loading-projects)
8. [AGCK vs Original AGCK (C64)](#agck-vs-original-agck-c64)

---

## Quick Start

1. **Open VisualGasic** in Godot 4.
2. Click the **🕹️ AGCK** button in the toolbar.
3. You'll see five tabs.  Start with **Game Settings** to name your game and set up physics.
4. Switch to **Actors** to define your player character and enemies.
5. Use **Sounds** to create 8-bit sound effects.
6. Design screens in the **Levels** tab — paint blocks and place actors.
7. When ready, go to **Build** and click **🔨 BUILD GAME**.

To return to the normal VG IDE, click any other toolbar button (Form, Code, 3D, 2D, Sprite) or press **F7** to toggle back to the code/form view.

---

## Game Settings Editor

**Tab:** ⚙️ Game Settings

The Game Settings editor configures global properties that affect every level in your game.  This is the equivalent of the original AGCK's *Environment Editor*.

### Identity

| Setting | Default | Description |
|---------|---------|-------------|
| **Game Title** | "My AGCK Game" | Displayed on the title screen and in the window title bar |
| **Author** | "Player" | Creator credit |

### World Physics

These settings control the physical behavior of all actors in the game.

| Setting | Range | Default | Description |
|---------|-------|---------|-------------|
| **Gravity Enabled** | On/Off | On | Whether actors are affected by gravity |
| **Gravity Direction** | Up, Down, Left, Right | Down | Which direction gravity pulls.  "Up" makes a ceiling-walker game; "Left/Right" creates side-pulling physics. |
| **Gravity Strength** | 0–100 | 50 | How strong gravity pulls.  0 = floating (space game), 100 = extremely heavy. |
| **Inertia Enabled** | On/Off | On | Whether actors gradually accelerate and decelerate.  Off = instant start/stop (Pac-Man style). |
| **Friction** | 0–100 | 50 | How quickly actors slow down on surfaces.  0 = pure ice, 100 = instant stop. |
| **Elasticity** | 0–100 | 20 | How much actors bounce off walls and each other.  0 = dead stop, 100 = full ricochet. |

> **Tip:** For a space game, disable gravity and set friction to 0 for drifting momentum.  For a platformer, keep gravity on (down, strength 40–60) with moderate friction.

### Screen Behavior

| Setting | Options | Default | Description |
|---------|---------|---------|-------------|
| **Screen Edge Mode** | Wrap, Reflect, Continual | Reflect | **Wrap** = actors exit one side and reappear on the other (Asteroids-style).  **Reflect** = actors bounce off screen edges.  **Continual** = the map extends across multiple screens (scrolling). |
| **Screen Width** | 160–1920 | 320 | Viewport width in pixels |
| **Screen Height** | 120–1080 | 240 | Viewport height in pixels |
| **Map Width** | 1–20 | 5 | Number of screens wide (Continual mode only) |
| **Map Height** | 1–50 | 10 | Number of screens tall (Continual mode only) |
| **Scrolling Enabled** | On/Off | On | Smooth camera scrolling in Continual mode |

### Player

| Setting | Range | Default | Description |
|---------|-------|---------|-------------|
| **Start Lives** | 1–9 | 3 | Lives at game start |
| **Max Lives** | 1–99 | 9 | Maximum lives that can be accumulated |
| **Extra Life Score** | 0–999999 | 10000 | Points needed for a bonus life (0 = no bonus lives) |
| **Joystick Horizontal** | 0–100 | 50 | Horizontal control sensitivity |
| **Joystick Vertical** | 0–100 | 50 | Vertical control sensitivity |
| **Jump Height** | 0–100 | 50 | How high the player jumps (0 = no jump, 100 = super jump) |
| **Max Players** | 1–4 | 1 | Number of simultaneous players |

### Display

| Setting | Default | Description |
|---------|---------|-------------|
| **Actors Above Scenery** | On | Draw actors above level blocks (off = blocks can cover actors) |
| **Score Color** | White | HUD text color |
| **Background Color** | Black | Default background color |

### FX Channels

AGCK provides four effect channels (A–D) that actors can trigger.  Each channel has a configurable duration.

| Channel | Default Duration | Description |
|---------|------------------|-------------|
| **Channel A** | 50 | General-purpose effect (screen shake, flash, etc.) |
| **Channel B** | 50 | Secondary effect |
| **Channel C** | 50 | Tertiary effect |
| **Channel D** | 50 | Quaternary effect |

Duration controls how many frames the effect persists (0 = instant, 100 = very long).

---

## Actor Editor

**Tab:** 👾 Actors

The Actor Editor lets you define up to **16 game characters**.  Each actor has a type, movement parameters, collision rules, death behavior, AI settings, and sound/effects linkage.

### Layout

- **Left panel:** Actor list with Add (+), Duplicate (⧉), and Delete (✕) buttons
- **Right panel:** Scrollable detail editor for the selected actor

Three default actors are provided:
1. **Hero** (Player type)
2. **Enemy 1** (Computer type)
3. **Bullet** (Missile type)

### Actor Types

| Type | Description | Typical Use |
|------|-------------|-------------|
| **Player** | Controlled by human input (keyboard/gamepad) | Main character, vehicles |
| **Drone** | Follows a simple pattern, doesn't chase the player | Moving platforms, hazards |
| **Missile** | Projectile that moves in a straight line | Bullets, fireballs, arrows |
| **Sentry** | Follows a fixed path traced in the Level Editor | Guards, patrol enemies |
| **Computer** | AI-driven actor that chases or flees the player | Enemies, boss characters |

### Movement & Speed

| Setting | Range | Default | Description |
|---------|-------|---------|-------------|
| **Max Speed** | 0–100 | 50 | Top movement speed (0 = stationary, 100 = very fast) |

The actor's movement behavior is also affected by the global physics settings (gravity, inertia, friction) from Game Settings.

### Movement States

Actors can have animation frames for 10 movement states:

| State | Description |
|-------|-------------|
| Stand | Idle (no input) |
| Left / Right | Horizontal movement |
| Up / Down | Vertical movement |
| Jump | Rising during a jump |
| Jump Left / Jump Right | Jumping while moving horizontally |
| Fall | Descending after a jump or walking off an edge |
| Hit | Taking damage or collision |

Each state links to animation frames that can be edited in the Sprite Editor.

### Collision

| Setting | Options | Description |
|---------|---------|-------------|
| **Collision Mode** | Kill None, Kill Other, Kill Player, Kill All, Invincible | What happens when this actor touches another |
| **Detect Barrier** | On/Off | Respond to Barrier blocks (solid walls) |
| **Detect Deadly** | On/Off | Respond to Deadly blocks (lava, spikes) |
| **Detect Teleport** | On/Off | Respond to Teleport blocks (warp zones) |
| **Detect Ladder** | On/Off | Respond to Ladder blocks (climbable surfaces) |

**Collision Mode details:**

| Mode | Description |
|------|-------------|
| Kill None | Actors pass through each other (used for pickups, decorations) |
| Kill Other | This actor destroys whatever it touches |
| Kill Player | Only kills the player on contact (enemy behavior) |
| Kill All | Both actors are destroyed on contact |
| Invincible | This actor can never be killed |

### Death & Rebirth

| Setting | Options/Range | Description |
|---------|---------------|-------------|
| **Death Mode** | Stunned, Falling, Both | Visual death style.  Stunned = blink and vanish.  Falling = drop off-screen.  Both = blink then fall. |
| **Rebirth** | On/Off | Whether the actor respawns after dying |
| **Rebirth Delay** | 0–255 frames | How long to wait before respawning |
| **End of Level** | Normal, Countdown, End Level | What triggers level completion |
| **Mutate on Death** | On/Off | Transform into another actor when killed |
| **Mutate Target** | Actor index | Which actor to transform into |

### Awards

| Setting | Range | Description |
|---------|-------|-------------|
| **Award Points** | 0–9999 | Points given to the player when this actor is destroyed |
| **Award Lives** | -9 – 9 | Extra lives given (positive) or taken (negative) when destroyed |

### Entrance

| Setting | Options | Description |
|---------|---------|-------------|
| **Entrance Mode** | Immediately, After Delay, Random | When the actor first appears |
| **Entrance Delay** | 0–255 frames | Wait time for "After Delay" mode |
| **Entrance Location** | Original, Random | Where the actor spawns (placed position or random) |

### Player-Specific Settings

| Setting | Options/Range | Description |
|---------|---------------|-------------|
| **Button Mode** | Off, Jump, Shoot | What the action button does |
| **Fall Height** | 0–100 | Maximum fall distance before taking damage (0 = invulnerable to falls) |

### AI Settings (Computer Type)

| Setting | Options/Range | Description |
|---------|---------------|-------------|
| **AI Strategy** | Open, Maze | **Open** = direct pursuit in any direction.  **Maze** = navigates corridors and obstacles. |
| **AI IQ** | 0–100 | How smart the AI is.  0 = random movement, 100 = perfect tracking. |

### Auto-Shoot

| Setting | Range/Options | Description |
|---------|---------------|-------------|
| **Auto-Shoot** | On/Off | Whether this actor fires projectiles automatically |
| **Frequency** | 0–100 | How often (higher = more frequent) |
| **Aim** | At Player | Targeting behavior |

### Sound Effects

Each actor can trigger up to 6 sound effects:

| Event | Description |
|-------|-------------|
| Bounce | When the actor hits a wall or another actor |
| Death | When the actor is killed |
| Entrance | When the actor spawns |
| Jump | When the actor jumps |
| Fall | When the actor starts falling |
| Move | While the actor is moving |

Sounds link to slots defined in the Sound Editor.

### FX Scripts & Cues

Actors can trigger the four global FX channels:

| Setting | Description |
|---------|-------------|
| **FX A Script** | Effect script triggered by this actor |
| **FX B Script** | Secondary effect script |
| **FX C Cue** | Timing cue for channel C |
| **FX D Cue** | Timing cue for channel D |

---

## Sound Editor

**Tab:** 🔊 Sounds

The Sound Editor is a retro waveform synthesizer for creating 8-bit style sound effects.  It provides **8 sound slots**, each with **2 voices** and a **filter**.

### Layout

- **Left panel:** Sound slot list (1–8) with names
- **Right panel:** Bar graph note editor, waveform selector, filter controls, tempo slider

### Voices

Each sound has two independent voices plus a filter:

| Component | Color | Description |
|-----------|-------|-------------|
| **♩ Voice 1** | Green | Primary tone generator |
| **♫ Voice 2** | Blue | Secondary tone generator (for harmony or SFX layering) |
| **🎛️ Filter** | Red | Frequency filter applied to one or both voices |

Click the voice tabs to switch between editing Voice 1, Voice 2, or the Filter.

### Bar Graph Note Editor

The center of the Sound Editor is a **bar graph** representing 32 time steps.  Each bar's height sets the pitch (note value) for that step:

- **Height** = pitch (0–48, spanning 4 octaves)
- **Click and drag** to paint note values
- Vertical grid lines mark every 8 steps
- Horizontal lines mark octave boundaries

This is how you compose melodies, arpeggios, and sound effects — draw the pitch curve you want.

### Waveforms

Each voice can use one of four classic waveforms:

| Waveform | Icon | Sound Character |
|----------|------|-----------------|
| **Square** | ⬜ | Bright, buzzy — classic 8-bit tone (NES, Game Boy) |
| **Triangle** | 🔺 | Softer, rounder — bass lines, mellow tones |
| **Sawtooth** | 🔶 | Rich harmonics — brass-like, aggressive leads |
| **Noise** | 〰️ | Random — percussion, explosions, static |

### Filter

The filter modifies the tonal character of one or both voices:

| Setting | Options | Description |
|---------|---------|-------------|
| **Filter Type** | Low Pass, Band Pass, High Pass, Notch | Which frequencies to emphasize or cut |
| **Filter Q** | Zero Q, Low Q, Med Q, High Q | Resonance intensity (how sharp the filter curve is) |
| **Apply to V1** | On/Off | Whether the filter affects Voice 1 |
| **Apply to V2** | On/Off | Whether the filter affects Voice 2 |

### Tempo & Transport

| Control | Description |
|---------|-------------|
| **Tempo** slider (1–100) | Playback speed of the 32-step sequence |
| **▶ Listen** button | Preview the sound |
| **✕ Clear** button | Reset all notes in the current voice to zero |

### Default Sounds

Sound slot 1 is pre-loaded with a "Laser" effect (descending pitch on Voice 1).

---

## Level Editor

**Tab:** 🗺️ Levels

The Level Editor is a tile-based screen painter.  You can create up to **50 levels**, each consisting of a **20×12 grid** of blocks.  Place scenery blocks, position actors, and set material properties.

### Layout

- **Left panel:** Level list, block palette, and actor placement tool
- **Right panel:** Grid canvas with material sliders and a status bar

### Level List

- Each level shows a **●** (filled) or **○** (empty) indicator
- **+** = Select next empty level
- **⧉** = Duplicate the current level
- **✕** = Clear the current level
- Each level has a custom name (editable above the grid)

### Block Types

Paint blocks by selecting a type from the palette and clicking/dragging on the grid:

| Block | Icon | Color | Description |
|-------|------|-------|-------------|
| **Empty** | ⬜ | Dark | No block — actors pass freely |
| **Barrier** | 🧱 | Gray | Solid wall — blocks actor movement (if actor detects barriers) |
| **Ladder** | 🪜 | Green | Climbable surface — actors that detect ladders can move up/down |
| **Deadly** | 💀 | Red | Kills actors on contact (if actor detects deadly blocks) — lava, spikes, pits |
| **Background** | 🟦 | Blue | Visual-only decoration — no collision effect |
| **Teleport** | 🌀 | Purple | Warps actors to another location (if actor detects teleports) |
| **Switch** | ⚡ | Yellow | Special trigger block — activates game events |

### Painting Controls

| Action | Input | Description |
|--------|-------|-------------|
| Paint blocks | Left-click / drag | Place the selected block type on the grid |
| Place actor | Right-click (with actor selected) | Position an actor at the clicked cell |

### Actor Placement

1. Select an actor from the **ACTORS** dropdown (below the block palette)
2. Right-click on the grid to place that actor at the clicked position
3. Left-click still paints blocks even when an actor is selected

The actor dropdown automatically synchronizes with the Actor Editor — any actors you add, remove, or rename there will appear here.

### Material Properties

Each level has two material sliders that affect block physics:

| Property | Range | Default | Description |
|----------|-------|---------|-------------|
| **Friction** | 0–100 | 50 | Surface friction for this level's blocks (overrides global friction locally) |
| **Elasticity** | 0–100 | 50 | Bounce factor for this level's blocks |

### Sentry Paths

Sentry-type actors follow fixed paths.  To define a path:

1. Place the sentry actor on the grid
2. The path is stored as an array of grid coordinates
3. Path segments are drawn as orange lines on the grid during editing

*(Path tracing UI is a planned enhancement — currently paths are stored as coordinate arrays in the level data.)*

### Status Bar

The bottom of the Level Editor shows contextual messages:
- "Painted Barrier at (5, 3)" when placing blocks
- "Placed Hero at (10, 6)" when positioning actors
- "Block: Ladder" when selecting a palette item

---

## Game Builder

**Tab:** 🏗️ Build

The Game Builder assembles all your game data (settings, actors, sounds, levels) into a playable Godot project.

### Build Target

| Target | Description |
|--------|-------------|
| **Current Project (embedded)** | Generates scenes inside the current Godot project |
| **Standalone Scene Pack** | Exports as a reusable scene package |
| **Export Template** | Creates a ready-to-export project |

### Output Path

Set the directory where build artifacts are written (default: `res://agck_builds/`).

### Display Settings

| Setting | Options | Description |
|---------|---------|-------------|
| **Screen Mode** | Windowed, Fullscreen, Borderless Fullscreen | Initial window mode |

### Splash Screen

| Setting | Default | Description |
|---------|---------|-------------|
| **Show Splash Screen** | On | Display a splash screen before the game starts |
| **Splash Text** | "Made with AGCK + VisualGasic" | Text shown on the splash |
| **Splash Duration** | 2.0 sec | How long the splash is displayed |

### Build Options

| Option | Default | Description |
|--------|---------|-------------|
| **Include Debug Info** | Off | Add debugging symbols and logging |
| **Auto-run After Build** | On | Automatically launch the game when the build completes |

### Build Process

Click **🔨 BUILD GAME** to assemble:

1. Validate game settings
2. Compile actor definitions
3. Process sound data
4. Build level scenes (generate collision shapes from block grids)
5. Assemble the Godot project structure

The **Build Log** at the bottom shows progress with color-coded messages:
- ✔ Green = success
- ⚠ Yellow = warning
- ✖ Red = error

Click **▶ PREVIEW** to test the game in an embedded viewport *(coming soon)*.

---

## Saving & Loading Projects

AGCK projects are saved as `.agck` JSON files that contain all data from every sub-editor.

### File Format

```json
{
    "settings": {
        "game_title": "Space Blaster",
        "gravity_enabled": true,
        "gravity_strength": 50,
        "screen_edge_mode": "wrap",
        "start_lives": 3,
        ...
    },
    "actors": [
        {
            "name": "Hero",
            "type": "Player",
            "max_speed": 60,
            "collision_mode": "Kill Other",
            "button_mode": "Shoot",
            ...
        },
        ...
    ],
    "sounds": [
        {
            "name": "Laser",
            "tempo": 50,
            "voice1_waveform": 0,
            "voice1_notes": [48, 43, 38, 33, 28, 23, 18, 13, 0, ...],
            "voice2_waveform": 1,
            "voice2_notes": [0, 0, 0, ...],
            "filter_type": 0,
            "filter_q": 1,
            ...
        },
        ...
    ],
    "levels": [
        {
            "name": "Level 1",
            "grid": [
                [0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                ...
            ],
            "actors": [
                {"actor_id": 0, "x": 2, "y": 10, "path": []},
                {"actor_id": 1, "x": 15, "y": 3, "path": []}
            ],
            "material_friction": 50,
            "material_elasticity": 50
        },
        ...
    ],
    "build": {
        "target": 0,
        "screen_mode": 0,
        "splash_enabled": true,
        "splash_text": "Made with AGCK + VisualGasic",
        ...
    }
}
```

### Save/Load Methods

The main AGCK plugin (`agck_plugin.gd`) provides:

- `save_project(path: String) -> bool` — Serialize all editors to a JSON file
- `load_project(path: String) -> bool` — Restore all editors from a JSON file

---

## AGCK vs Original AGCK (C64)

The VisualGasic AGCK plugin is inspired by the 1988 Commodore 64 *Arcade Game Construction Kit* by Broderbund.  Here's how they compare:

| Feature | Original AGCK (C64) | VG AGCK |
|---------|---------------------|---------|
| **Platform** | Commodore 64 | Godot 4 (Windows, Linux, macOS) |
| **Resolution** | 160×200 (multicolor) | Configurable (320×240 default, up to 1920×1080) |
| **Colors** | 16 fixed C64 colors | Full 24-bit color |
| **Actors** | 8 maximum | 16 maximum |
| **Actor types** | 5 (Player, Drone, Missile, Sentry, Computer) | 5 (same as original) |
| **Levels** | ~25 screens | 50 levels |
| **Sound** | SID chip (3 voices) | 2 voices + filter (synthesized) |
| **Block types** | 5 (Barrier, Ladder, Deadly, Background, Teleport) | 7 (+Switch, +Empty as explicit type) |
| **Grid size** | 20×12 | 20×12 (identical) |
| **Screen modes** | Wrap, Reflect, Continual | Wrap, Reflect, Continual (identical) |
| **Physics** | Gravity, Inertia, Friction, Elasticity | Gravity (4 directions), Inertia, Friction, Elasticity |
| **AI** | Open / Maze strategy | Open / Maze strategy (identical) |
| **Collision** | 5 modes | 5 modes (identical) |
| **Save format** | Floppy disk binary | JSON (.agck file) |
| **Distribution** | "Gift Disk" tool | Godot export (executables for all platforms) |
| **Scrolling** | No (single-screen or flip-screen) | Yes (smooth camera scrolling) |
| **Multiplayer** | 2 players (alternating) | Up to 4 players |
| **Sprite editor** | Built-in (limited) | Full Piskel-style pixel art editor (VG Sprite Editor) |
| **Sound editor** | Built-in bar-graph | 2-voice + filter bar-graph synthesizer |

### What's New in VG AGCK

- **Smooth scrolling** in Continual screen mode (original was flip-screen)
- **4-direction gravity** (original was down-only)
- **Up to 4 players** (original was 2, alternating)
- **JSON project files** for easy version control and sharing
- **Cross-platform export** via Godot's export system
- **Integration with VG Sprite Editor** for animation frames
- **Switch block type** for interactive level triggers
- **Build to standalone executable** (original required the AGCK software to play)

---

## Keyboard Reference

| Key | Action |
|-----|--------|
| Click **🕹️ AGCK** toolbar button | Enter AGCK workspace |
| Click any other toolbar button | Leave AGCK, return to that view |
| **F7** | Toggle back to Code/Form view |
| Left-click (Level grid) | Paint selected block |
| Left-click drag (Level grid) | Paint continuously |
| Right-click (Level grid) | Place selected actor |
| Left-click drag (Sound bar graph) | Draw note pitches |

---

## Files Reference

| File | Lines | Description |
|------|-------|-------------|
| `plugins/agck/plugin.cfg` | — | Plugin discovery configuration |
| `plugins/agck/agck_plugin.gd` | ~200 | Main plugin: TabContainer with 5 sub-editors, save/load, data flow |
| `plugins/agck/agck_game_settings.gd` | ~384 | Game Settings: physics, screen, lives, controls, FX channels |
| `plugins/agck/agck_actor_editor.gd` | ~581 | Actor Editor: 16 actors, 5 types, collision, AI, sound, FX |
| `plugins/agck/agck_sound_editor.gd` | ~340 | Sound Editor: 8 slots, 2 voices + filter, bar-graph, 4 waveforms |
| `plugins/agck/agck_level_editor.gd` | ~400 | Level Editor: 50 levels, 20×12 grid, 7 block types, actor placement |
| `plugins/agck/agck_game_builder.gd` | ~280 | Game Builder: build targets, splash screen, build log |
