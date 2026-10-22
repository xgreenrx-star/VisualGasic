# Ash Meridian — Part 1

Jason scavenges Narcea with Orac, the Ash's onboard assistant. The campaign
uses Backlight Yard's buildings, materials, distance fog and sky. Orac remains
online throughout this first expedition and helps Jason locate salvage and
the power coupler needed for a loaded departure. Removing that coupler from
the underground chamber breaks its isolation interlock and awakens the FEB
(Field Enforcement Body).

## Play

Open this folder in Godot 4.6 with Visual Gasic enabled and press F5.

```bash
./Godot_v4.6.1-stable_linux.x86_64 --path samples/games/ash_meridian_part1
```

### Current campaign increment

**Play** starts with Orac's approach warning, then the landing rings. The
landing is flown from the Ash's flight deck. The green marker in the centre of
the canopy is exactly where the hull will cross; keep it inside the orange ring
as the ring reaches you. The canopy shakes with speed,
cloud banks and hull strikes, and the dashboard carries Orac's descent scope
(upcoming rings), an external chase-camera monitor (no clouds), hull-stress and
thrust traces, glide altitude, the gate counter and status lamps. Strikes crack
the canopy and fill the monitors with static. When the bay opens, the buggy
rolls out into Jason's Backlight Yard expedition with Orac online. Search the depot consoles for five ordered alien
symbols, enter the address in the transit depot, explore underground, and
recover the chamber's power coupler. Escape to the Ash before the 255-second
alarm expires. The campaign launch gate requires the coupler, not the
prototype's additional regulator and ignition parts.

| Control | Campaign action |
|---|---|
| W / S, Up / Down | Walk or accelerate/brake/reverse the buggy |
| A / D, Left / Right | Turn |
| F | Enter/leave the buggy; cancel the lift keypad |
| E | Enter/leave a depot, examine consoles, collect parts, use a lift or board the Ash |
| Q | Ask Orac for a location-sensitive scan or escape hint |
| 0–9, Backspace, Enter | Enter, correct and submit a five-symbol lift address |
| V | Cycle street, district and buggy-inspection views |
| Esc | Pause; resume, save, return to title or change options |
| F10 | Resume the current campaign after visiting a dev destination |

Campaign **Save** writes a validated, versioned
`user://ash_meridian_campaign.cfg` through an adjacent temporary file and
atomic replacement. **Continue** restores the expedition, including the
parked buggy, interior/lift position, inventory, journal and remaining alarm
time. Invalid or unsupported saves show an explanation rather than silently
starting over. Legacy `user://ash_meridian_save.txt` saves are untouched and
are not automatically migrated. Dev Backlight Yard is a separate instance;
its reset, pickups and save command cannot alter the campaign expedition.

This increment ends at the first-departure overlay. It does **not** start
the old reflection encounter or restart the prototype. Finite saleable cargo,
protected mission inventory, new underground gates/checkpoints, flight,
station trading, the matched-component return contract and the return-only
EMP/FEB encounter remain planned. Stacy remains Jason's partner.
See the current [campaign revision](../../../docs/development/ASH_MERIDIAN_PROPOSAL.md).

### Opening dialogue and control handoff

The opening uses seven shorter Orac/Jason exchanges, including the orange-gate
briefing and Jason's acknowledgment. Subtitles follow the line actually playing,
not a separate scene timer or the next synthesis job. The ship stays stationary
until the final control-handoff line finishes. Space/Enter/click can skip the
initial story exchange, but not the gate briefing. Pausing freezes the sequence;
with speech disabled or unavailable, each caption gets a text-length reading
interval before advancing.

The fixed opening uses the locally generated original WAV recordings in
`assets/opening_voice`, so it does not require an installed TTS engine or wait for
voice generation between replies. Dynamic gameplay dialogue still uses the
shared live-speech queue. The manifest is checked against the script's exact
speaker/text pairs; missing or stale assets produce an `INTRO_VOICE_ERROR` log
and an on-screen warning, with live speech/subtitles as fallback.

The recordings were generated locally using Kokoro `kokoro-en-v0_19`, with
`bm_george` for Orac and `am_adam` for Jason. The installed model distribution
carries the Apache-2.0 license and references
[hexgrad/Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M).
Only generated dialogue audio is included here, not model weights or a runtime.
The dialogue is original; no audio from the reference video is used.

After editing `ResetIntro` in [part1.vg](part1.vg), regenerate the matching
recordings with the developer-only [baking tool](tools/bake_opening_voice.vg).
This requires the existing local Kokoro tools:

```bash
ASH_SPEECH_LIVE=1 "$GODOT" --headless --max-fps 60 \
  --path samples/games/ash_meridian_part1 \
  --script "$PWD/test_proj/run_suite.gd" -- res://tools/bake_opening_voice.vg
"$GODOT" --headless --editor --import --path samples/games/ash_meridian_part1
```

Run [test_intro_dialogue.vg](test_intro_dialogue.vg) through the VG suite runner
for deterministic queue, subtitle, pause, mute, fallback and safe-skip checks.
Set `ASH_SPEECH_LIVE=1` for actual recorded playback through the normal campaign
game loop, including all seven voices, no synthesis worker, a maximum 1.5-second
inter-line gap and the final flight handoff. This test deliberately disables
the TTS backend to verify that the recordings are self-contained. Use
`ASH_CHANNEL_CAPTURE` with an existing directory to capture the gate caption.

### Landing cockpit performance

The landing/arrival cockpit retains its static canopy, bezels, scope grid,
scanlines and labels as cached canvas commands. Live instruments, cloud
reflections, cracks and interference still update. Landing rings share two
cached meshes instead of rebuilding their ribbon geometry each frame. The
staged yard is no longer hidden, shown and repositioned every frame.

On the local Intel OpenGL compatibility renderer, the campaign landing profile
improved from approximately 58 ms frames to 17-18 ms p95 frames. The screenshot's
intro cockpit and normal moving landing both passed a 33.34 ms p95 smoke budget.
These are short warmed runs with speech disabled, not a universal 60 FPS
guarantee or a measurement of voice generation.

Run [test_landing_performance.vg](test_landing_performance.vg) through the existing
VG suite runner with rendering enabled. Set `ASH_LANDING_PROFILE=intro` to
profile the campaign intro cockpit or `ASH_LANDING_PROFILE=live` for the normal
moving game loop. Optional `ASH_LANDING_BUDGET_MS` enforces a machine-specific
p95 wall-clock frame budget; without it, timings are diagnostic. Set
`ASH_CHANNEL_CAPTURE` to an existing absolute directory for normal and damaged
cockpit captures. The test also verifies mesh reuse, ring progression, retained
art, damage state and ring cleanup on scene exit.

### Black Channel flight encounter

The [Black Channel asset kit](assets/black_channel/README.md) supplies original
external canyon/security models, an assembled route and static preview scenes.
It is playable through **BLACK CHANNEL - FLIGHT TEST** in the main developer
terminal. Campaign integration is still pending: the intended setting is the
end of the post-alliance Narcean repair-item hunt, not the first escape.
The route alternates exposed causeways, industrial spires, diagonal gantries
and enclosed cuts. The visible Ash reuses the opening ship's red/orange flame
shader at both engines, not solid cyan bars. Camera FOV, perspective slipstream
lines, passing dust fragments and thin edge mist reinforce motion without
covering the flight path. Q/E throttle spans **32-240 m/s**
(864 km/h maximum), starting at 90 m/s. W/S controls lift and A/D banks laterally.
The extended course is **13.06 km**, with nine alternating wreckage obstacles,
left/right hazard cues, ten service bridges and a late checkpoint at 6500 m.
After that checkpoint, six fractured spans alternate climb-over and
dive-under passages between the lateral wrecks. HUD warnings and the navigation
cue identify the safe altitude; W/S controls it. The early course, checkpoints
and enemy damage remain unchanged. Three original variants per wreckage family
use torn plates, bent girders and per-shard convex collision, not solid boxes.
Needles now fire amber-telegraphed lasers with short red bursts. Four ledge
turrets include two new late threats at 9400 and 11100 m; evade the committed
line or use solid cover. Animated power pulses, additional distant industrial
flashes, drifting shader fog and electrical arcs outside the flight lane add
visual activity.
Flight speech reads every crew line and gives priority to short directional
hazard warnings. Options **SPEECH** (and **V** in Black Channel) turns all
dialogue on or off; subtitles stay on. Kokoro keeps the voice model loaded so
lines start quickly; Orac stays measured while Jason and Rob tighten up in the
channel. Missing voices are reported visibly and in the log.
Black Channel's fixed crew exchanges, obstacle calls, hull-loss instruction
and orbital dialogue use bundled, locally generated recordings with the same
Kokoro model/voice provenance as the opening. This includes Rob's answer to
Jason's "And the bad news?" Subtitles wait for actual playback, and urgent
warnings defer an interrupted crew line rather than dropping it. Flight itself
does not wait for optional banter.

To re-bake these 24 lines, use the opening bake command above with
`ASH_BAKE_CHANNEL_VOICES=1`, then import the project. Do not set
`ASH_BAKE_RESUME=1` when changing dialogue: it is only for resuming an interrupted,
unchanged bake. The exact speaker/text pair selects each clip; unrecorded
dynamic text still uses live TTS.
Run [test_channel_dialogue.vg](test_channel_dialogue.vg) with
`ASH_SPEECH_LIVE=1` to verify actual Orac/Jason/Rob playback with the TTS backend
disabled, caption alignment and Rob's reply resuming after a safety warning.
At zero hull, a central **HULL LOST** panel explains the stop and shows
**Enter/Space to retry the last checkpoint**.
At the end, a **24-second automatic ascent** passes through clouds into a
starfield, revealing Narcea below. The ship holds in local orbit while the
crew prepares to fit the last recovered repair item in the isolated,
depressurized exterior drive housing. Repairs finish in space, not on another
salvage trip; this holding scene is not yet system departure or a playable EVA.
Enter opens the developer menu over the orbital scene. Static scenery is
batched and distance-culled; flight sampling and physics queries avoid repeated
linear scans and shape allocation. Cached, interpolated headings remove the
old orientation steps at route-sample boundaries. Slipstream animation follows
travelled distance, freezes on pause and fades away during ascent.
The [Cursor handoff](../../../docs/development/ASH_MERIDIAN_BLACK_CHANNEL_HANDOFF.md)
specifies story, integration, ownership and acceptance tests. Cursor implements
gameplay in VG; model creation and visual revisions remain with the assistant.
The [unified approval draft](../../../docs/development/ASH_MERIDIAN_APPROVAL_DRAFT.md)
includes the proposed full campaign and Black Channel story placement.

Run the VG campaign regression (it uses a process-specific test save):

```bash
./Godot_v4.6.1-stable_linux.x86_64 --headless \
  --path samples/games/ash_meridian_part1 \
  --script /absolute/path/to/VisualGasic/test_proj/run_suite.gd \
  -- res://test_campaign.vg
```

For rendered captures, create an output directory, set `ASH_CAMPAIGN_CAPTURE`
to its absolute path, omit `--headless`, and add
`--rendering-method gl_compatibility` (or run under `xvfb-run -a`).

### Legacy chapter / dev reference

The original chapter remains accessible through the dev terminal for reference.
The following table documents that **superseded Jonah/Zen storyline**, not
the default Play campaign. Its landing, canyon and reflection beats have not
been connected to the revised campaign.

| Beat | What you do |
|---|---|
| Menus | The yard wakes, then Play, Options, and Exit. Esc in play opens Continue, Save, Quit, and Options. Continue shows on the title after a save. |
| Cockpit | The reflector coupler burns out. Zen's search ends at Narcea. Space continues after she names it. |
| Landing | A/D steer, W/S lift. Clear 28 rings through the cloud banks. The closest ring ahead is orange, and that is the one to fly through. Later rings stay blue until they become the next gate. A missed ring gives a hull strike and sets you back just short of that same ring. Two strikes lose the approach; Enter or Space retries the whole course. |
| Bay | She sets down, the bay opens, and the buggy rolls out. |
| Yard | You are in the buggy, looking out the glass. The road pitches. A and D turn, W and S drive. F leaves the buggy where it is. Walk back and press F to drive again. Q scans. E takes a part. |
| Press hall | The energy cell is inside. The buggy will not enter. The east door is the way in. |
| Lift | North end of the road. E with the cell rides it under the yard. |
| Chamber | Feb is in the glass. E takes the coupler. Lights and alarms come up. Zen says run. E rides back up. |
| Canyon | South, in the buggy, through the orange rings. A/D. A wall scrape slows you. |
| Keel | A short vector climb. Space skips to the cockpit. |
| Install | Space only while the tick is in the gate. Three seats before Feb's bar empties. |
| Reflect | The beam returns. Space replays the chapter. |

During installation, miss the gate and the bar drops. Let the bar empty and the hull is hit; the three seats start over without ending the chapter.

The pilot is Jonah Hale. The Ludo ring runner is only the canyon beat.

## Bleed City 2: reference-art district

The dev terminal keeps the live scenes on the first list. Older destinations,
including **BLEED CITY** (Cursor's original), **BLEED CITY 2**, and **BLEED CITY 3**,
are under **ARCHIVE**. The chapter yard and
the earlier cities are unchanged. City 3 is the open scaffold district:
see-through halls, a dark road with cyan rails, grid silos, and magenta
searchlights.
To open the existing hidden terminal, tap Up, Up, Down, Down, Left, Right,
Left, Right, B, A, B, A. Open **ARCHIVE**, select **BLEED CITY 2**, and press Enter.

This is an independent, explorable art/asset demo, not a replacement chapter.
The visual references are catalogued in [reference/ludo/README.md](reference/ludo/README.md).
The images inform the shapes and palette; they are not used as flat scenery:

- Magenta halls have opaque walls, open doorways, roof trusses, and braced frames.
- Cyan raised roads have junction curves, underside ducts, and support piers.
- Capped refinery tanks have collars, ladders, connected pipes, and service gantries.
- The central shaft has an annular rim, pit walls, and a pulsing white beam.
- The docking spur has a solid ship and an amber crane.
- The buggy has an exposed cage, seats, four rotating wheels, suspension coils,
  an air bottle, and cyan hoses. The cockpit uses live speed and heading.
- Three separate air-bottle meshes can be collected on foot.

| Control | City 2 action |
|---|---|
| W / S, Up / Down | Walk or accelerate/brake/reverse the buggy |
| A / D, Left / Right | Turn |
| F near the buggy | Enter; press again to park and exit |
| E near an air bottle | Collect it on foot |
| V | Cycle street view, district overview, and buggy inspection |
| Esc | Normal pause menu |

Movement stops at walls, refinery tanks, the shaft, and district bounds. Hall
doors are open; movement is subdivided to prevent tunnelling through walls on a
slow frame. Inspection views freeze movement. City meshes are built once and
reused; wheel transforms and the beam pulse update without rebuilding the city.
Only this destination enables a small neon-bloom composite and MSAA (2x at
medium detail, 4x at high). Low detail disables those effects without removing
opaque geometry or collision.
Street view respects the view-distance option; inspection views extend the far
plane to show the whole district.

Re-entering from the terminal resets the demo. Saving here reports that it is a
dev demo and leaves the existing chapter save untouched. City 2's native
presentation/movement adapter is `bleed_city_2.gd`; VG retains the terminal,
phase selection, pause menu, and chapter logic.

Run its focused regression:

```bash
./Godot_v4.6.1-stable_linux.x86_64 --headless \
  --path samples/games/ash_meridian_part1 --script test_bleed_city2.gd
```

To capture street, overview, buggy, driving, shaft, dock, and terminal views,
create an output directory and set `ASH_CITY2_CAPTURE` to its absolute path.
Run the same script with a real display or `xvfb-run -a` instead of `--headless`.
The test exercises the actual hidden terminal sequence, driving, parking,
pickups, collisions, pause/resume, return to Cursor's city, and mesh reuse.

## Rendering and regression checks

### Backlight Yard

The hidden terminal keeps **BACKLIGHT YARD** on the main scene list (phase 18).
Open it with Up, Up, Down, Down, Left, Right, Left, Right, B, A, B, A, move to
**BACKLIGHT YARD**, then Enter. **BACKLIGHT CITY** is in **ARCHIVE**. The original
yard and every existing city remain separate.

This district combines the chapter yard's stepped tower profiles and industrial
press-hall architecture with Backlight's opaque satin shells, cyan circuit
insets, amber door frames, violet horizon and restrained glow. It includes
24 stepped towers, eight enterable pitched-roof depots, overhead service
gantries, capped tanks, the north lift head, six turrets, and the restored buggy.
The tower silhouette is shared with the original yard rather than redrawn as
a different building. Geometry is cached between visits.

Depot entries have solid, illuminated two-leaf doors that slide into the walls
as you approach; E still enters their separate interiors. Tower and north
lift-head doors are sealed scenery. Blue-violet distance fog starts beyond
28 units and grows denser with distance, including on luminous surfaces, without
obscuring nearby geometry. It is disabled inside depots and does not affect
the original Backlight City.

The yard-only procedural sky includes twinkling stars, blue/violet nebula
clouds, two shaded moons and a brief shooting star approximately every
19 seconds. These are shader effects, not additional per-star nodes or
downloaded textures, and remain available at low detail.

W/S moves, A/D turns, F enters/exits the buggy, E interacts and V cycles views.
Five archives, the pressure workshop, ignition press hall and deep-transit
depot reuse the existing exploration/interior and FEB escape systems with
independent session state. Re-entry resets progress without rebuilding the
district; saving never overwrites the chapter save.

The layout source is `backlight_yard.vg`; it uses the existing VG Backlight
mesh/material helpers and simulation. No new GDScript game code is required.
Run the VG integration fixture from the repository root:

```bash
./Godot_v4.6.1-stable_linux.x86_64 --headless \
  --path samples/games/ash_meridian_part1 \
  --script "$PWD/test_proj/run_suite.gd" -- res://test_backlight_yard.vg
```

The shared test launcher is existing infrastructure; the fixture itself is VG.
For rendered previews, remove `--headless`, use a display or `xvfb-run -a`, and
set `ASH_YARD_CAPTURE` to an existing output directory.

The live scene uses `presentation.vg`; city generation, exploration, cockpit
artwork, gauges, and stars run in VG. The older `.gd` implementations remain
as migration references, and the existing regression runners are GDScript.
The VisualGasic addon/debug infrastructure also remains an engine dependency.
Native `.gdshader` resources supply the optical effects. References below to
the former GDScript adapters describe their VG replacements' responsibilities.

### Backlight City: exploration prototype

**BACKLIGHT CITY** is a fourth, independent destination at the bottom of the
same hidden terminal. The three Bleed cities and the chapter yard remain
available. It explores a photographed, backlit-film treatment rather than a
wireframe treatment, using original architecture and vehicles:

- Opaque blue-gray shells have directional satin shading, black recesses,
  fine panel seams, circular light insets, and luminous circuit strips.
- A violet horizon, tiled blue pavement, and warm portal lights establish
  depth without making every polygon edge glow.
- A transit court has four numbered plinths, floating amber ring markers,
  and a clear central driving lane.
- The buggy uses an open cage, exposed suspension, seats, a rear air tank,
  illuminated wheel rings, and the earlier buggy cockpit with live gauges.
  A separate hovering district carrier is a scenery vehicle, not drivable.
- Three charge cells are collectible on foot.

Use W/S or Up/Down to move, A/D or Left/Right to turn, F near the buggy to
drive or park/exit, E to interact, and V to cycle street, district, and
buggy inspection views. Escape opens the normal pause menu. Buildings,
portal columns, transit plinths, the parked carrier, and six turret plinths
block movement. The surface is now 236 by 432 units, over five times the
original district's footprint, with 24 enterable buildings.

Park before entering a building. E at a recessed doorway loads a separate
interior; E at the entry inside returns outdoors. The buggy stays parked.
Most interiors have only dead consoles, empty storage, or incompatible scrap.
The five archives each preserve one symbol, copied in order into the descent
journal when examined at the rear bench. The pressure workshop and ignition
store contain the first two ship-repair components. These are prototype
placements, not a finished loot economy.

The eighth building, **DEEP TRANSIT / ELEVATOR**, has the lift control at its
rear. E near that panel opens ten original alien glyphs. Keyboard 0-9 (or the
numeric keypad) selects the corresponding button; Backspace erases, Enter
confirms exactly five symbols, and F cancels. Small keyboard hints are not
translations of the in-world script. The journal remains visible beside the
panel. The fixed FEB address is assembled from the five archives. Other
addresses seed repeatable procedural floors with a connected central corridor
and side rooms; they do not randomly award the critical part. Floors are
generated on arrival and regenerated identically on return, not retained as
100,000 live scenes. E beside the underground entry calls an emergency ascent.
The cabin has closing/opening doors and a timed journey in both directions.

The FEB floor contains a cylindrical stasis cradle inspired by the supplied
pod reference: magenta crown/base rings, cyan supports and diagnostics, clear
glass, and an upright articulated figure. The reflector coupler is in its
external service socket. Taking it:

1. Removes the coupler and starts a **255-second** purge, displayed in the
   same alien glyph alphabet.
2. Starts slow FEB movement, low mist, flashing warning light, and a
   synthesized audible alarm.
3. Brings Zen back with an urgent on-screen **RUN!** (text, not a recorded
   voice performance).
4. Activates the surface turrets. They aim, fire visible pulses, damage the
   suit, and slow the buggy. Solid buildings block their line of fire.

Return to the lift, ascend, leave the lobby, and reach the Ash at the south
end of the city. E near the ship installs all three components and starts its
lift-off. The pressure regulator and ignition cell can be found before taking
the coupler. Ascent and inspection consume purge time; normal pause freezes
it. Timer expiry or suit breach offers Enter to retry from the FEB chamber
with surface repair finds and the parked buggy preserved. A completed escape
offers Enter to start a fresh prototype.

Dev-terminal re-entry resets this prototype without rebuilding the city.
Saving here explicitly leaves the chapter save unchanged. Progress is
session-only; it is not yet a replacement for the original chapter campaign.

The scenery is solid mesh geometry, not pasted reference images.
`backlight_city.gd` supplies the material/optical layer.
`backlight_exploration.gd` reuses City 2's driving, collision substeps, and
safe vehicle exit logic while providing exploration state and the enlarged
city. `backlight_interiors.gd` constructs one disposable interior at a time;
`backlight_exploration_hud.gd` draws the journal, keypad, and purge glyphs.
The restored cockpit reuses `buggy_art.gd` and `cockpit_instruments.gd`.
The satin/light-spill shading is an approximation, not ray-traced reflection
or physical backlit photography.

Medium and high detail add a thresholded, separable glow at 320x180, followed
by a 960x540 composite with restrained grain and vignette. High increases glow;
both use 2x MSAA. Low disables the three optical passes and MSAA, retaining
opaque surfaces, collision, and the horizon. These effects and the environment
are isolated to this destination and stop when it is left.

Run the keyboard, save-safety, geometry, collision, and effect-lifecycle checks:

```bash
./Godot_v4.6.1-stable_linux.x86_64 --headless \
  --path samples/games/ash_meridian_part1 --script test_backlight_city.gd
./Godot_v4.6.1-stable_linux.x86_64 --headless \
  --path samples/games/ash_meridian_part1 --script test_backlight_exploration.gd
```

For rendered opacity/glow/dashboard checks and previews, create an output
directory, set `ASH_BACKLIGHT_CAPTURE` to its absolute path, and run the same
script with a display or `xvfb-run -a`, without `--headless`. Captures include
street, district, courier, carrier, driving, boulevard, and transit-court views,
plus raw and glow-pass comparisons. Software-rendered timings are not hardware
GPU performance guarantees.

Set `ASH_EXPLORE_CAPTURE` to an existing directory for the exploration test's
building, restored buggy/cockpit, keypad, generated floor, FEB, turret, and
ship-repair previews. It exercises real interaction/keypad inputs and checks
collision-grid reachability, deterministic floor generation, pause, both
failure/retry paths, repair completion, and chapter-save isolation. Tests use
positioned scenarios to reach interactions quickly; they are not a continuous
human playthrough.

### Chapter rendering

Gameplay and chapter state remain in `part1.vg`. `presentation.gd` batches the
world into opaque, depth-tested faces and neon edges in a private 3D viewport.
The yard mesh is cached: moving the camera does not regenerate the buildings.
Picking up an item, parking the buggy, or changing detail refreshes that cache.
Low detail still draws solid surfaces; it only reduces decoration.

`cockpit_art.gd` and `buggy_art.gd` draw each vehicle's opaque frame, consoles,
and controls once into cached textures. Their windscreens contain no decorative
flight rings; the landing and canyon rings remain actual world objects.
`cockpit_instruments.gd` supplies the live layer: buggy speed and motor load
follow velocity, and heading and lift range follow world position. The telemetry
trace animates even at idle. The ship's opening cinematic uses simulated flight
readings, a sweeping radar, and a fluctuating coupler-fault display.
`cockpit_stars.gd` moves a sparse starfield behind the ship's canopy.

The precision approach is roughly 33 seconds on a clean run, with speed rising
from 16 to just over 20 world units/second (formerly 5.4). Rings alternate
laterally and vertically; small crosswinds require corrections. The drawn ring
is the gate: a center inside its 2.15-unit radius clears it.
Crossings use interpolated positions rather than end-of-frame positions, so a
slow frame does not let the ship jump over an unchecked ring. Cloud geometry is
cached separately and appears only during landing.

Menu input is sampled once per game frame in the presentation adapter. The VG
menu handlers consume those samples directly, so holding Enter cannot activate
the next screen, and pause-menu Options returns to the paused game.

Run the focused checks from the repository root:

```bash
./Godot_v4.6.1-stable_linux.x86_64 --headless \
  --path samples/games/ash_meridian_part1 --script test_part1.gd
```

For rendered occlusion checks and a screenshot, use a real display or Xvfb:

```bash
ASH_VIEW=turret ASH_CAPTURE=/tmp/ash-turret.png xvfb-run -a \
  ./Godot_v4.6.1-stable_linux.x86_64 \
  --path samples/games/ash_meridian_part1 \
  --rendering-method gl_compatibility --script test_part1.gd
```

`ASH_VIEW` accepts `cockpit`, `landing`, `turret`, or `city`; with `landing`, `ASH_LAND_Z` moves the ship along the course (for example `188` is inside a cloud bank) and `ASH_LAND_HURT` (for example `0.8`) captures an active hull strike; unset it for the buggy's yard
view. The checks restore the options file to its original bytes and do not
write a game save. `YARD_FRAME_US` measures warmed redraws; `GAMEPLAY_FRAME_US`
includes real process callbacks while holding W to drive the buggy. Neither
headless timing nor software-OpenGL timing guarantees FPS on another machine.
The regression also keyboard-steers the entire landing course and checks hull
strikes, retry, bay entry, and (with a display) changing gauge and star pixels.
