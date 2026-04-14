# AGCK — Arcade Game Construction Kit
## Step-by-Step Instructions

---

## 🗺️ Building a Level (WYSIWYG Tile Editor)

1. **Open AGCK** — Click the **AGCK** button in VG's plugin toolbar. The Level Editor opens as the default view.

2. **Select a tile from the palette** — The top strip shows a scrollable row of **visual tile thumbnails** grouped by block type. Each thumbnail is the actual pixel art that will appear in-game. Block types:
   - **Empty** — eraser (clears a cell)
   - **B** (Barrier) — solid walls, floors, platforms (grey outline)
   - **L** (Ladder) — climbable surfaces (green outline)
   - **D** (Deadly) — kills on contact (red outline)
   - **Bg** (Background) — decorative, no collision (blue outline)
   - **T** (Teleport) — warp points (purple outline)
   - **S** (Switch) — triggers and interactive tiles (yellow outline)

   The built-in tile library includes ~28 pre-made tiles (Brick Wall, Stone Platform, Grass & Dirt, Spikes, Lava, Portals, Levers, and more).

3. **Paint the grid** — **Left-click and drag** on the 20×12 grid canvas to paint tiles. Each cell shows the **actual tile texture** — what you see is exactly what appears in-game. A faint color-coded outline (35% alpha) around each cell indicates the block type for quick identification.

3b. **Flood fill** — Click the **🪣 Fill** button in the toolbar to toggle bucket-fill mode. In this mode, left-clicking a cell replaces all connected cells of the same type with the currently selected tile. Great for filling large areas quickly.

3c. **Search tiles** — Use the **🔍 Search** field in the tile palette header to filter tiles by name. Type "brick" to see only Brick tiles, for example.

4. **Edit tiles inline** — **Double-click any tile thumbnail** in the palette to open the built-in **Pixel Editor popup**. This editor appears as a window directly inside AGCK — you never leave the interface. Features:
   - 18×18 pixel canvas with large editing cells
   - 20-color palette including skin tones, metals, and nature colors
   - Eraser mode toggle
   - **Save** — overwrites the current tile with your edits
   - **Save As New** — keeps the original and adds your edit as a new custom tile in the same block type
   - Changes are reflected **immediately** in the level grid (WYSIWYG)

5. **Place actors** — Use the **Place:** dropdown to select an actor (e.g. "Hero"). Then **right-click** on the grid to place it. Actor markers show the actual actor sprite texture (24×24 scaled up) so you can see who's who at a glance.

6. **Set level properties** — The bottom bar has **Friction** and **Elasticity** sliders.

7. **Manage levels** — The **Level:** dropdown at top-left lets you switch between up to 50 levels. Use **+** (find next empty), **Dup** (duplicate), and **X** (clear) buttons.

8. **Name your level** — Type a name in the text field next to the level dropdown.

---

## 👾 Editing Actor Sprites (WYSIWYG)

All sprite editing happens **inside AGCK** — no need to exit to Godot or VG's Sprite Editor.

### Viewing Sprites

1. Click **Actors** in the sidebar. The Actor Gallery shows up to 16 actor cards in a 4-column grid.
2. Each card now displays a **sprite preview thumbnail** (36×36) alongside the actor's name and type. The sprite is auto-generated based on actor type (Player = blue figure, Drone = red figure, etc.).

### Editing Sprites (Double-Click)

1. **Double-click any actor card** to open the inline **Actor Sprite Editor** popup. This works exactly like the tile pixel editor but for 24×24 actor sprites.
2. The pixel editor popup provides:
   - 24×24 pixel canvas with large editing cells
   - 20-color palette (same colors as the tile editor)
   - Eraser toggle
   - **Save** — saves your edits back to the actor's sprite (all frames)
   - **Cancel** — discards changes

3. Alternatively, select an actor card and click the **"Edit Sprite"** button in the detail panel header.
4. Use the **"⧉ Duplicate"** button to copy an actor to the next empty slot — great for making variants.
5. **Right-click** on the pixel canvas to use the **eyedropper** — pick any color from the sprite.
6. **Ctrl+Z** / **Ctrl+Y** in the sprite editor for undo/redo of paint strokes.
7. Saved sprites are visible **immediately** on actor cards and in the level grid wherever that actor is placed.

### 🎞️ Frame Animation Editor

The sprite editor includes a full **frame animation toolbar** for creating multi-frame animated sprites:

| Button | Action |
|--------|--------|
| **◀** | Go to previous frame |
| **▶** | Go to next frame |
| **+ Add** | Add a new blank frame after the current one |
| **⧉ Copy** | Duplicate the current frame (great for small tweaks) |
| **✕ Del** | Delete the current frame (minimum 1 frame) |
| **👻 Onion** | Toggle onion skin — shows the previous frame as a faint ghost behind the current frame for smooth animation |

- The **Frame counter** (e.g. "Walk - Frame 2/4") shows which animation and frame you're editing.
- An **animated preview** (48×48) in the top-right cycles through all frames in real time so you can see your animation as you draw.
- Up to **32 frames** per animation.

### 🎨 Named Animations

Each actor can have **multiple named animations** (like Walk, Run, Jump, etc.). The sprite editor shows a color-coded **animation tabs row** above the frame toolbar:

| Tab / Button | Action |
|-------------|--------|
| **● Idle** / **● Walk** / etc. | Click to switch between animations — each has its own set of frames |
| **+ Add** | Add a new animation from presets: Idle, Walk, Run, Jump, Fall, Fly, Hover, Crouch, Swim, Attack, Death, Custom |
| **✏ Rename** | Rename the currently selected animation |
| **✕** | Delete the selected animation (can't delete the last one) |

Each animation tab has a **unique color** for easy identification:
- 🔵 Idle (light blue), 🟢 Walk (green), 🟡 Run (yellow), 🟣 Jump (purple)
- 🟠 Fly (orange), 🔵 Hover (cyan), 🟤 Crouch (brown), 🔵 Swim (blue)
- 🔴 Attack (red), ⚪ Death (grey), ⬜ Custom (white)

**The Animations card** in the actor detail panel shows all animation names with frame counts and speeds (read-only — edit sprite to configure).

**Typical animation workflow:**
1. Open the sprite editor — you start with a single "Idle" animation
2. Draw the Idle frames (base pose, breathing animation, etc.)
3. Click **+ Add** → select **Walk** to create a new Walk animation
4. Draw the Walk frames (use **⧉ Copy** + small changes for each step)
5. Add more animations as needed (Jump, Attack, etc.)
6. Click **Save** — all named animations are saved together

**Using animations in code:**
When an actor has multiple animations, the generated VG code includes a `PlayAnimation` helper:
```vb
' Switch to the Walk animation
Call PlayAnimation("Walk")
' Switch to Jump animation
Call PlayAnimation("Jump")
```
The `PlayAnimation` sub only changes the animation if it's different from the current one, so it's safe to call every frame.

When built, actors with multiple animations use **AnimatedSprite2D** with **SpriteFrames** containing all named animations. Each animation auto-plays at its configured speed. Single-animation actors use a simpler Sprite2D.

### Actor Properties

Select any actor card to see the detail panel with 6 property categories:

| Card | Properties |
|------|-----------|
| **Movement** | Max Speed, Gravity, Entrance Mode |
| **Combat** | Max HP, Damage, Score Value, Death Mode, Rebirth Timer |
| **Collision** | Mode (Bounce / Slide / Stop / Pass) |
| **AI Behavior** | Behavior (Chase/Patrol/Wander/Guard/Flee), Vision Range, Patrol Speed, Auto Shoot |
| **Animations** | Per-animation name, frame count, speed (edit sprite to manage) |
| **Effects** | Spawn FX, Death FX, Hit FX |

Actor types determine the generated base class:
- **Player** → CharacterBody2D (gravity + jump + movement)
- **Drone** → CharacterBody2D (AI patrol/chase/flee)
- **Missile** → RigidBody2D (straight-line projectile)
- **Sentry** → CharacterBody2D (patrol + auto-shoot)
- **Computer** → StaticBody2D (collectible/interactive object)
- **Zombie** → CharacterBody2D (shambling undead AI — patrol/chase)
- **Boss** → CharacterBody2D (large menacing enemy AI — horns & cape sprite)
- **Bat** → CharacterBody2D (flying creature AI — zero gravity, winged sprite)
- **NPC** → StaticBody2D (friendly villager — hat & tunic sprite)
- **Tank** → CharacterBody2D (armored vehicle — turret & tracks sprite)
- **Fireball** → RigidBody2D (flaming projectile — fire trail sprite)

---

## 💥 Damage & Combat System

AGCK includes a full damage system that's wired up automatically when you build:

### How It Works

| Interaction | Result |
|-------------|--------|
| **Enemy touches Player** | Player takes the enemy's `Damage` value as HP loss |
| **Player stomps Enemy** (lands on top) | Enemy takes MaxHP damage (instant kill), Player bounces, Score awarded |
| **Missile/Fireball hits any actor** | Target takes projectile's `Damage` value, projectile destroyed |
| **Player touches Deadly block** (Spikes, Lava, etc.) | Player takes Deadly Damage (configurable in Settings, default 25) |
| **Player touches Computer/collectible** | Score awarded, item collected |

### Invincibility Frames

When the Player takes damage:
1. **1.5 seconds of invincibility** — no further damage during this window
2. **Blink effect** — the player sprite rapidly toggles visibility to signal i-frames
3. After the timer expires, the player becomes solid and damageable again

### Death Modes

Each actor's `On Death` setting (in the Combat card) controls what happens when HP reaches 0:

| Mode | Player Behavior | Enemy Behavior |
|------|----------------|----------------|
| **Respawn** | HP resets to Max, `LoseLife()` called → lives decrease, game over if lives = 0 | HP resets to Max |
| **Destroy** | Actor removed from scene, `LoseLife()` called | Actor removed from scene |
| **GameOver** | Scene reloads immediately via `GameOver()` | — |

### HUD Integration

The game controller (`Main.vg`) tracks **Score** and **Lives**:
- `AddScore(points)` — called when stomping enemies or collecting items
- `LoseLife()` — called when player dies; decrements lives counter and triggers Game Over at 0
- HUD labels update automatically

### Collision Layers

| Layer | Used By |
|-------|---------|
| **1** | Player |
| **2** | Enemies (Drone, Sentry, Zombie, Boss, Bat, Tank) + Projectiles (Missile, Fireball) |
| **4** | Collectibles (Computer) + NPCs |
| **8** | Deadly blocks (Spikes, Lava, etc.) |

### Key Generated Properties

Every actor declares these combat variables in its `.vg` script:
```vb
Dim MaxHP As Integer        ' Set from Combat card → Max HP
Dim CurrentHP As Integer    ' Tracks current health
Dim Damage As Integer       ' How much damage this actor deals on contact
Dim ScoreValue As Integer   ' Points awarded when killed/collected
Dim IsInvincible As Boolean ' True during i-frames (Player only)
Dim InvincibleTimer As Single ' Countdown for i-frames (Player only)
```

---

## 🔊 Using the Sound Editor

1. **Open Sounds** — Click **Sounds** in the sidebar. You get a bar-graph synth painter with 8 sound slots.

2. **Select a sound** — Use the **Sound:** dropdown to pick one of 8 sound slots. Type a name in the **Name** field to label it (e.g., "Jump", "Explosion").

3. **Pick a voice** — Click one of the three color-coded toggle buttons:
   - **Voice 1** (green) — primary melody/SFX voice
   - **Voice 2** (blue) — harmony/secondary voice
   - **Filter** (orange) — controls filter cutoff sweep

4. **Paint notes** — **Left-click and drag** on the bar graph canvas. Vertical position = pitch (bottom = low, top = high, 48 semitones from C2 to C6). Horizontal = time (32 steps). **Right-click** to erase a bar. **Ctrl+Z** to undo, **Ctrl+Y** to redo.

5. **Choose waveforms** — The waveform row below the toolbar lets you set:
   - **V1 Wave** / **V2 Wave**: Square, Triangle, Sawtooth, or Noise
   - **Filter**: None, LowPass, HighPass, or BandPass
   - **Q** slider: filter resonance (0–100)
   - **V1 Vol** / **V2 Vol**: Per-voice volume sliders (0–100)

6. **Set tempo** — The **Tempo** slider (40–300 BPM) controls playback speed.

7. **Play** — Click the green **Play** button to hear your sound! The synth engine generates real audio:
   - Mixes all voices that have painted bars
   - Applies the selected waveform per voice
   - Applies the filter if the Filter voice has content
   - Smooths note transitions with a 5ms envelope

8. **Stop** — Click the red **Stop** button to halt playback.

9. **Layer voices** — Click Voice 2 to enable and paint it. Both voices mix together on playback.

---

## ⚙️ Game Settings

Click **Settings** in the sidebar. Configure global properties across these categories:

| Category | Settings |
|----------|----------|
| **Project** | Game Title, Author, Version |
| **Display** | Screen Width, Screen Height, Background Color |
| **Physics** | Gravity, Friction, Elasticity |
| **Gameplay** | Lives, Difficulty, Start Level, Level Order, Wrap Screen, Deadly Damage |
| **Camera** | Zoom (0.25× to 4×) |
| **Input** | Joystick, Keyboard, Touch |
| **Audio** | Music Volume, SFX Volume, FX Channels |
| **HUD** | Show Score, Show Lives, Debug Overlay, Auto Save |
| **Keyboard Shortcuts** | Reference card listing all AGCK keyboard shortcuts |

- **Deadly Damage** — configurable per-game damage from deadly blocks (default 25). This value is used by the builder backend.
- **Camera Zoom** — initial camera zoom for the game (1.0 = default, 2.0 = zoomed in).
- **Reset All Settings to Defaults** — button at the bottom resets everything back to factory settings.

---

## ✨ Shader Effects Editor

Click **Shaders** in the sidebar. The Shader Editor lets you add visual post-processing effects to your game — like retro CRT TV scanlines, pixelation, blur, and more — without writing a single line of shader code.

### How It Works

1. **Browse the shader gallery** — The left panel shows up to 8 shader cards. Click a card to see its details in the right panel.
2. **Enable a shader** — Toggle the **Enabled** switch to turn the effect on.
3. **Choose an effect** — Use the **Effect Type** dropdown to pick from 10 built-in shaders:

| Shader | Description |
|--------|-------------|
| **CRT TV** | Old television look with scanlines and curvature |
| **Pixelate** | Chunky retro pixel look |
| **Blur** | Soft Gaussian-like blur |
| **Glow** | Bright bloom/glow effect |
| **Chromatic Aberration** | RGB color fringing (lens distortion) |
| **Vignette** | Dark edges fade effect |
| **Sepia** | Warm old-fashioned photo tint |
| **Night Vision** | Green-tinted night goggles look |
| **Water Ripple** | Wavy underwater distortion |
| **Glitch** | Digital glitch/scramble effect |

4. **Adjust properties** — Each shader exposes sliders for its settings (e.g., Pixel Size for Pixelate, Strength for Blur). Move the sliders to customize the look.
5. **Set the region** — Choose where the effect is visible:
   - **Full Screen** — covers the entire game window
   - **Rectangle** — only covers a specific area (set X, Y, Width, Height in pixels)
6. **Live preview** — The detail panel shows a real-time preview of the shader effect applied to a sample texture.
7. **Remove** — Click **Remove** to clear a shader slot (a confirmation dialog prevents accidental removal).

### Tips

- Shaders are layered — you can enable multiple effects at once (CRT + Vignette for a retro TV look).
- The order of the shader cards determines the layer order (first card = back, last card = front).
- Rectangle regions are great for applying effects to specific UI areas or screen zones.
- All shader settings are saved with your AGCK project file.
- When built, each enabled shader generates a `.gdshader` file and a `CanvasLayer + ColorRect` node in the main scene.

---

## 🚀 Building Your Game

1. Fill in **Settings** — game title, screen size, physics, lives, etc.
2. Design levels in **Levels** — paint tiles visually, place actors on the grid.
3. Configure actors in **Actors** — set types, edit sprites, tweak speeds/AI/HP.
4. Create sound effects in **Sounds** — paint and audition with Play.
5. Click **Build** in the sidebar, then click **BUILD GAME**.
6. The build log shows progress. Output goes to `res://build/<GameName>/` with:

```
build/<GameName>/
├── sprites/
│   ├── tile_brick_wall.png     ← individual tile image (32×32)
│   ├── tile_stone_platform.png
│   ├── tile_spikes_up.png
│   ├── ...                     ← one PNG per tile in the library
│   ├── blocks_tileset.png      ← fallback tileset strip
│   ├── spr_hero.png            ← actor sprite (your pixel art)
│   ├── spr_enemy_1.png
│   └── spr_bullet.png
├── actors/
│   ├── Actor_Hero.tscn         ← Godot scene
│   ├── Actor_Hero.vg           ← VB6 code
│   └── ...
├── levels/
│   ├── Level_01.tscn           ← level scene with tiles + actors
│   ├── Level_01.vg             ← level controller code
│   └── ...
├── Main.tscn                   ← root scene with HUD
├── Main.vg                     ← game state controller
└── project.agck                ← JSON manifest of all AGCK data
```

7. **Edit the generated files** in VG's native editors:
   - Open any `.vg` file in the **Code Editor** to customize VB6 logic
   - Open any `.tscn` file in the **2D Editor** to rearrange nodes visually

---

## 🔨 Build Options

The Build panel offers these configuration options before building:

| Option | Description |
|--------|-------------|
| **Target** | Desktop, Web, Mobile, Console |
| **Screen** | Windowed, Fullscreen, Borderless |
| **Output** | Output directory path (default: `res://build/`) |
| **Debug** | Include debug information |
| **Auto-Run** | Automatically run after building |

---

## 🎨 The Tile Library

AGCK ships with a built-in tile library containing ~56 procedurally generated pixel art tiles across 7 block types:

| Type | Tiles |
|------|-------|
| **Barrier** | Brick Wall, Stone Platform, Grass & Dirt, Metal Plate, Ice Block, Wood Plank, Sand Block, Cobblestone, Castle Wall, Mossy Stone, Steel Girder, Concrete, Marble, Glass Block, Chain Link |
| **Ladder** | Wood Ladder, Metal Ladder, Vine, Rope, Chain, Bamboo Ladder |
| **Deadly** | Spikes Up, Lava, Electric Fence, Acid Pool, Fire, Saw Blade, Poison Gas, Thorns, Hot Coals, Laser Beam |
| **Background** | Sky, Cloud, Night Sky, Water, Cave Wall, Forest, Sunset, Mountains, Dungeon Wall, Ocean Deep, City Skyline, Moon, Storm Clouds, Starfield |
| **Teleport** | Portal, Warp Pad, Magic Door, Vortex, Star Gate, Teleport Beam |
| **Switch** | Lever, Button, Crystal, Key, Treasure Chest, Coin, Heart, Star |

All tiles are 18×18 pixels internally and scaled to fit the grid. You can:
- **Edit any tile** by double-clicking its thumbnail in the tile palette
- **Create new tiles** using "Save As New" in the pixel editor
- **Custom tiles persist** in your saved AGCK project file

Actor sprites are 24×24 pixels and follow the same edit-in-place workflow.

---

## 💡 Tips

- **Everything is WYSIWYG.** The grid shows real tile textures and actor sprites — what you see is what gets built.
- **Double-click to edit anything.** Tiles in the palette, actors in the gallery — the pixel editor opens inline every time.
- **Save As New preserves originals.** Edited a Brick Wall but want to keep both? Use "Save As New" to add your variant as a new tile.
- **Tile outlines show block type.** Even though tiles have real art, a faint color-coded border reminds you what type each cell is (grey = barrier, red = deadly, etc.).
- **Levels are non-destructive.** Rebuild any time — AGCK regenerates all files in the build folder.
- **Actor names sync everywhere.** Rename an actor in the Actor Editor and the Level Editor's placement dropdown updates automatically.
- **Sounds are painted, not programmed.** Think of the bar graph as a piano roll — height is pitch, position is time.
- **Save your AGCK project** to preserve all design data (levels, actors, sounds, shaders, settings, custom tiles) as a single JSON file.
- **Flood fill saves time.** Use the 🪣 Fill tool to paint large areas in one click instead of dragging.
- **Right-click to pick colors.** In the sprite editor, right-click any pixel to grab its color (eyedropper tool).
- **Undo everything.** Ctrl+Z works in the level editor, sprite editor, and sound editor. Ctrl+Y to redo.
- **Stack shader effects.** Combine CRT TV + Vignette + Sepia for a retro movie look, or Pixelate + Glow for a dreamy pixel art effect.
- **The unsaved dot (•) reminds you.** The level editor shows a dot when you have unsaved changes.
- **Keyboard shortcuts save time.** Ctrl+1-6 switches between tabs. See the Shortcuts card in Settings for the full list.
