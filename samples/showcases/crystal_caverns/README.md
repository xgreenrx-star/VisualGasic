# Crystal Caverns

An original single-screen digging game showcasing **inline sprite `Data`**,
**cave layout `Data`**, and **`Whenever Section` reactions**. No classic game's
art, cave layouts or sounds are copied. This is a small playable showcase, not
a full Boulder Dash implementation.

## Run

Open `project.godot` in Godot 4.6.1 with the VG extension installed, then press
F5. In a repository checkout, `addons/visual_gasic` links to the canonical addon.
For a standalone copy, replace that link with the built addon directory.
Let Godot finish its first import before launching the game.

The project enables the VG editor plugin. Edit `Caverns.vg` in Godot's Script
workspace or the replacement VG editor. The game runs independently of which
editor view you use.

No AI provider, external artwork, network service or optional music library is
required. The HUD uses native Godot Label controls.

| Input | Action |
| --- | --- |
| Arrows / WASD | Move and dig; hold to repeat |
| P / Escape | Pause or resume |
| R | Restart from the original cave Data, including after victory or defeat |
| N / Next cave button | After victory, advance to the next cave; after cave three, start again |
| F11 / Fullscreen button | Toggle fullscreen/windowed; preserved when restarting or changing caves |
| F8 / Effects switch | Toggle shaders, transitions and CRT; preserved across cave restarts |
| F9 / Sound switch | Mute/unmute sound independently; preserved across cave restarts |

Collect all six crystals, then reach the exit at the lower right. Digging
removes dirt. Rocks fall straight down when the cell beneath becomes empty;
falling onto the miner ends the run. Push rocks horizontally into empty cells,
but not while they are airborne. Crystals do not fall. The time limit is 120
simulation seconds in the first cave; pausing freezes the whole simulation.
The three caves are **First Light** (120 seconds), **Stone Galleries** (100)
and **The Deep Vault** (90). Each has six crystals and distinct authored terrain.
Restart retries the current cave, not the whole expedition. Finish a cave to
unlock the next one.

## Visual effects

The Compatibility renderer uses seven original canvas shaders. The linked
GodotShaders examples below are visual inspirations, not copied implementations.
No downloaded shader package, HDR pipeline or external textures are required.

| Effect | Behavior | Inspiration |
| --- | --- | --- |
| Miner entrance | 0.8-second swirl reveal on starting/restarting a cave | [Swirl Sink](https://godotshaders.com/shader/swirl-sink/) |
| Cave completion | Wave for 1.1 seconds, then swirl away until 2 seconds | [Aetherial Flow](https://godotshaders.com/shader/aetherial-flow/) |
| Defeat | Miner breaks into its own DATA-colored pixels for 1.15 seconds | [Pixel Explosion](https://godotshaders.com/shader/playwithfurcifers-sprite-pixel-explosion-shader/) |
| Unlocked exit | Cyan/purple rotating vortex around the door | [Wormhole / Blackhole](https://godotshaders.com/shader/wormhole-blackhole/) |
| Walking and cave treatment | Subtle miner pulse, scanlines and vignette | [Animal Well-inspired CRT](https://godotshaders.com/shader/animal-well-inspired-crt-effect/) |
| Rocks | Small wobble, stronger while falling | [Wobble / Shake](https://godotshaders.com/shader/wobble-shake-with-adjustable-speed-and-amplitude/) |
| Crystals and pickups | Moving highlights, expanding glow ring and a brief, small slice distortion | [Weird Glitch](https://godotshaders.com/shader/weird-glitch-shader/) |

Effects are confined to the cave: the title, timer, messages and buttons are
not distorted. Pause freezes animation clocks. **F8** or the **Effects** switch
disables the shader treatment and transitions for a plain, nearest-neighbor
DATA-art view; there is no continuous glitch or full-screen flash.
The setting lasts for this run, not across application launches.

`VisualEffects.vg` is a VG **presentation-only** child. It loads the seven
shader resources, creates ShaderMaterials and drives uniforms with `Shader.Param`.
It reads the game's cached textures and gameplay state, with pooled tiles and
pixel fragments. All game-specific CPU scripting is VG; the GPU programs remain
Godot `.gdshader` resources. GDScript files in this sample are regression drivers,
not gameplay or presentation dependencies.
The game rules, DATA decoding, collision, timer and Whenever callbacks remain
in `Caverns.vg`. `visualEpoch` identifies every cave reset, including a restart
of the same cave. VG keeps its original draw path until the child is ready.
The animations do not delay gameplay or gate input: **N**, the next-cave button,
and **R** may interrupt a transition immediately.

## Sound and a beginner's reading guide

`SoundEffects.vg` synthesizes ten original short cues from `CueRecipes` DATA:
cave entrance, walking, digging, pushing, rock landing, crystal pickup, exit
unlock, victory, defeat and the low-time warning. No recordings, audio downloads,
music library or optional plugin are needed. Four reusable AudioStreamPlayers
allow cues to overlap without allocating a new node for every footstep.
The level is deliberately conservative (-12 dB per player).
**F9** or **Sound** mutes and stops active cues. Pause freezes ongoing sounds;
restart stops old sounds before playing the new entrance. Both sound and visual
preferences last for this run, not across application launches.

Each sound's DATA row is **seconds, start Hz, end Hz, noise mix**. Hertz is pitch:
larger numbers sound higher. The last value blends a pure tone (0) with noise (1).
For example, `Data 0.16, 880, 1760, 0.0` makes a short rising crystal chirp.
The builder validates editable values, creates a signed 16-bit mono sample
buffer at 8000 Hz with `VGMemoryBuffer`, and applies a fade to avoid clicks.
Game actions call the named `SFX_*` constants; pickup/unlock/warning/defeat cues
also demonstrate Whenever callbacks. Blocked moves and stationary rocks are
silent, and simultaneous landings produce at most one landing cue per tick.

The source now includes instructional comments at each gameplay procedure,
important algorithm step, sprite block, effects stage and sound routine. Start
reading in this order:

1. `Caverns.vg`: `_Ready`, `LoadArt`, `RestartCave` show how DATA becomes a game.
2. `TileAt`, `TryMove`, `StepCave` explain grid indexing, digging and gravity.
3. Whenever declarations and their `On*` callbacks explain reactive state.
4. `AdvanceFrame` and `_Input` separate timed simulation from key events.
5. `VisualEffects.vg` shows cached nodes, shader uniforms and visual clocks.
6. `SoundEffects.vg` shows DATA recipes, sample generation, bounded voices and mute.

Godot invokes VG's `Form_Unload` when the sound node leaves the scene; it stops
playback and detaches streams. The test drivers observe audio-resource release
with a bounded deadline because the mixer runs separately from game frames.

## Source-defined art and cave

All twelve original 8x8 images are labeled `*Sprite` blocks in `Caverns.vg`:
floor, wall, dirt, rock, two crystal frames, three miner poses and three door
states. Each header is `Data 8, 8, 0, 2`: width, height, transparent index,
and C64 palette identifier. Eight rows of eight palette indices follow.
For example, `Data 8, 8, 0, 2` means width 8, height 8, palette index 0
transparent, and palette ID 2 (C64). Pixel rows run top to bottom; values in
each row run left to right. These are palette indices, not RGB components.
Single-digit values are space-padded so pixel columns line up in a monospace
font. Spaces change neither the image nor the runtime Data values.
Sprites become cached textures once at startup, then draw at 4x scale with
nearest-neighbor filtering. `ArtLabels` determines their runtime slots.

`CaveRows`, `CaveRows2` and `CaveRows3` each contain twelve strings, twenty
characters wide. `CaveNames` and `CaveTimes` provide the corresponding metadata:

| Character | Tile |
| --- | --- |
| `#` | Solid wall |
| `.` | Diggable dirt |
| `O` | Rock |
| `*` | Crystal |
| `E` | Exit |
| `@` | Miner starting location |
| Space | Empty cell |

The source validates row dimensions, boundary walls, known tile characters,
one miner, one exit and exactly six crystals. Invalid layouts raise explicit
errors rather than becoming silently empty cells. Preserve those constraints
when editing the cave; rerun the gameplay regression to verify reachability.

Demonstration: change a sprite's Data pixels, restart the application to rebuild
its cached textures, then change a cave row and show the new layout. Sprite
editing in Godot's VG integration is optional; the source is independently
editable. Do not promise live texture rebuilding: this sample caches art at
startup.

### Finding sprites and watchers in the replacement editor

Click the dropdown currently showing **(General)** above the code, and choose
**(Sprites)**. Select a sprite in the right dropdown. These are dropdown entries,
not separate tabs or panels. This jumps to its Data label and activates the contextual
Sprite preview/editor. Cave-map strings are not sprite blocks, so placing the
caret in `CaveRows2`, for example, does not display a sprite preview.
The Sprite panel explains the selected header and pixel order. Use **Align Data
grid** to pad an existing sprite's pixel columns; this is an explicit source edit
with one-step Undo. Painting, creating a sprite and saving from the full Sprite
Editor use the same column spacing. Merely moving the caret does not align source.
In the floating assist panel, clicking **Help**, **Sprite** or **Vector** keeps
that tab selected; later caret updates do not override that choice.
**Edit in Sprite Editor** opens the full editor in a visible floating workspace
panel. **Save Data** writes pixels back to the bound code buffer; the back arrow
or panel close button returns to the still-open code view. **New Sprite** opens
a compact 420x320 dialog, and its default “Open in Sprite Editor” option uses the
same floating editor after creation.

**Indent Data** repairs rows that are not deeper than their label, preserving
existing label indentation and pixel values, then collapses the blocks.
It is an idempotent source edit, not a toggle. Use the separate **Collapse Data /
Expand Data** button to toggle all Sprite/Vector blocks without repeatedly
indenting source. With the default fold policy, recognized Data blocks collapse
on opening the file; placing the caret inside a block keeps it accessible while
editing. The policy remains configurable as `vg/editor/sprite_data_fold`.
The assist text and floating-panel contents use explicit matching foreground and
background themes rather than inheriting white text from Godot's dark theme.

If the native Godot Script tab and the VG Code Editor contain different unsaved
buffers, the older copy shows a nonmodal warning. Typing never opens a refresh
dialog or automatically overwrites the other buffer. Use **Refresh** on the older
copy only when you want to replace it with the other editor's text; preserve any
edits you need from both copies first. **Dismiss** stays dismissed while the same
editor continues editing and rearms after buffers match or editing authority switches.

Choose **(Whenever)** in the left dropdown to list the six watcher declarations
and jump to their source. This is source navigation; the existing
**Immediate window → Whenever** tab provides the separate runtime monitor when
connected to a running VG instance.

## Reactive state

The game uses six single-line watchers:

- `crystals Changes` updates the visible crystal counter.
- `crystals Becomes GEM_TARGET` unlocks the exit once per run.
- `secondsLeft Changes` updates the visible clock.
- `secondsLeft Below 11` enables the ten-second warning on threshold crossing.
- `secondsLeft Becomes 0` ends the run on timeout.
- `health Becomes 0` ends the run after crushing.

Callbacks are deliberately small. They do not depend on another watcher firing
from inside a callback: VG's watcher reentrancy guard suppresses nested
evaluation. Restart resets gameplay state, visible labels and callback counters;
tests verify that the threshold watchers rearm on the next run.

## Simulation rules

`StepCave` advances at 8 Hz. Each step clears moved flags, applies one cardinal
movement, then updates rocks bottom-up. A moved flag prevents a pushed rock
from falling in the same step and prevents double updates. Stationary supported
rocks clear their falling flag. The clock decrements once per eight completed
steps. `AdvanceFrame` caps incoming frame time at 0.25 seconds, allowing at most
two catch-up steps per normal call rather than an unbounded backlog.

There are three authored caves, no rolling rocks, enemies, destructive explosions, scrolling,
persistence, procedural generation or music. Those are intentionally
outside this showcase's scope. This showcase does not certify the whole VG
runtime or resolve the separate release-blocking editor/import investigations.

## Regression checks

The full workspace probe runs inside Godot's actual editor, not just a standalone
CodeEdit. Its 118 checks cover Sprite-help contrast, inherited floating-panel text,
toolbar states, real repeated typing without modal dialogs or lost keyboard focus,
nonmodal warnings, dismissal, explicit refresh in both directions, bounded New
Sprite dialog sizing/validation, creation, full-editor visibility/save/back/reopen,
nearest-neighbor pixels, default folding and repeated Collapse/Expand:

```sh
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a bash scripts/run_editor_workspace_regression.sh
```

Run this probe separately from other full-editor probes; it creates an isolated
project and editor settings and never edits the open showcase.
The timeout budget is 300 seconds for cold system-font discovery; errors and
timeouts still fail the run.

From the repository root:

```sh
bash scripts/run_crystal_caverns_regression.sh
GODOT=/absolute/path/to/Godot_v4.7.2 bash scripts/run_crystal_caverns_regression.sh

GODOT=/absolute/path/to/Godot LIBGL_ALWAYS_SOFTWARE=1 RENDER_MODE=graphical \
  xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' \
  bash scripts/run_crystal_caverns_regression.sh
```

The runner creates an isolated project, checks replacement-editor navigation
and sprite panel/thumbnail data, executes both default and forced-AST
modes, rejects errors/crashes/timeouts/leaks, and retains logs. Default execution
may use AST fallback; passing both modes does not prove every Sub runs bytecode.
Missing optional GDSiON is explicitly excluded in the isolated addon copy.
The same runner executes `effects_regression.gd` in both modes. Its deterministic
checks cover renderer ownership, cached DATA textures, transition timing, pause,
pickup/unlock/death, reset, the checkbox/F8 and unchanged simulation state.
Graphical checks compile and render all shaders, compare actual pixels for
entrance, pickup, vortex rotation, explosion and CRT, verify exact opaque
rock pixels in plain mode, and check cave/HUD separation and fullscreen/resizing.
Captures are saved under `default-effects/` and `ast-effects/`.
`sound_regression.gd` adds 95 checks per mode: exact format/duration,
non-silent bounded waveforms, frequency/noise/envelope samples within one PCM
unit, deterministic generation, real AudioServer mixer output, action/watcher
cues, mute, pause, F9, bounded voices, unchanged gameplay and resource release.
Ten generated WAVs per mode are retained under `default-sound/` and `ast-sound/`
for listening. Automated runs use Godot's Dummy audio driver; mixer capture
proves routed samples, not the listener's speakers or subjective sound quality.

The 179 editor checks include header guidance, an explicit grid-alignment edit and
undo, a real Help-tab click followed by Sprite/Vector context updates, actual
folded-label thumbnail drawing and enlarged
hover previews for all twelve sprites, the actual Object dropdown entries and
workspace control refreshes. Real pointer input expands and collapses every
sprite block without opening the full Sprite Editor or modifying the source.
The small sprite-edit affordance has its own gutter; the fold arrow only folds.
Errors and Unicode diagnostics fail the run.

`regression.gd` checks digging, blocked/vertical/airborne pushing, single-step
falling, support, crushing, locked/open exit behavior, watcher transitions,
pause/restart, actual held input, bounded frame catch-up and two identical
complete playthroughs of every cave, keyboard/button level progression and
fullscreen/windowed round trips. The pathfinding driver avoids rocks and collects all
six real pickups without injecting victory or replacing the authored cave.
Graphical checks also inspect rendered cave/HUD pixels and save screenshots.
Headless runs explicitly leave rendering untested.

### Verified October 9, 2026

Linux Godot 4.6.1 and 4.7.2 each passed default and forced-AST runs in both
headless and OpenGL Compatibility/Xvfb modes: **eight successful combinations**.
After adding three caves and fullscreen, each headless run completed 79 checks;
each graphical run completed 87 checks
including saved visual evidence. No parser/runtime errors, crashes, timeouts or
shutdown leak diagnostics were reported. Physical keyboard ergonomics, manual
gameplay polish, Windows/macOS execution and packaged exports still need review.
The enabled editor plugin also completed an isolated Godot 4.7.2 headless import
without parser or script errors; this is not graphical editor shutdown certification.

After converting the effects controller to VG, both engines again passed
default/forced-AST headless and graphical runs: **277 effects checks per headless
run** and **302 per graphical run**, alongside the existing 179 editor and
79/87 gameplay checks. The actual
Godot workspace probe also passed all 118 checks on both engines with the new
scene/resources. The effects suite also checks that both attached controllers
are VG scripts and sends real F8 input through the VG unhandled-input callback.
All 24 deterministic 4.6.1 captures (twelve per execution mode) match the previous
GDScript controller's PNGs byte-for-byte. Explosion checks verify all fragment
velocity vectors and rendered motion near the miner, excluding distant shimmer.
Linux OpenGL rendering is verified; Windows/macOS, other renderers, low-end GPU
performance and packaged exports are not certified by these runs.

After sound and instructional comments, the matrix passes **95 sound checks,
278/303 effects checks and 80/88 gameplay checks per headless/graphical mode**,
plus 179 editor checks. The extra gameplay/effects check observes audio cleanup.
The 24 earlier byte-identical captures predate the new Sound switch, which now
appears in the HUD. The actual workspace probe still passes 118 checks on both
engines. Physical speaker playback and listening balance still need manual review.

### October 10 release candidate

The first cave now starts the miner at the bottom-left, with revised rock/miner
pixels. Default/forced-AST Linux 4.6.1 checks pass headless and graphical:
81/89 gameplay, 278/303 effects, 95 sound and 179 editor checks.
The added assertion verifies the DATA starting position; pixel-effect checks
derive their region from that position rather than assuming the old start.

The editor suite now has 190 checks. Eleven new indentation checks cover folded
procedures/DATA, unchanged statement text and line count, deferred callbacks,
valid parsing, exact Undo, repeated formatting, inline watchers, mixed-case
keywords/comments, and selection boundaries/nesting across blank lines.
Fix Indentation edits only leading whitespace using explicit line positions;
it never replaces hidden statements through a visible-caret selection.
