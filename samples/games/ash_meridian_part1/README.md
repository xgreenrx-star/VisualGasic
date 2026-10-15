# Ash Meridian — Part 1

Jonah Hale brings the Ash down on Narcea. Zen fails on the way in. The coupling the ship needs is in a stasis chamber under the yard, with Feb still shut down inside it. Taking it brings Zen back, and the yard guns with her.

## Play

Open this folder in Godot 4.6 with Visual Gasic enabled and press F5.

```bash
./Godot_v4.6.1-stable_linux.x86_64 --path samples/games/ash_meridian_part1
```

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

The dev terminal has separate **BLEED CITY** (Cursor's original),
**BLEED CITY 2**, and **BLEED CITY 3** destinations. The chapter yard and
the earlier cities are unchanged. City 3 is the open scaffold district:
see-through halls, a dark road with cyan rails, grid silos, and magenta
searchlights.
To open the existing hidden terminal, tap Up, Up, Down, Down, Left, Right,
Left, Right, B, A, B, A. Select **BLEED CITY 2** and press Enter.

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

`ASH_VIEW` accepts `cockpit`, `landing`, `turret`, or `city`; unset it for the buggy's yard
view. The checks restore the options file to its original bytes and do not
write a game save. `YARD_FRAME_US` measures warmed redraws; `GAMEPLAY_FRAME_US`
includes real process callbacks while holding W to drive the buggy. Neither
headless timing nor software-OpenGL timing guarantees FPS on another machine.
The regression also keyboard-steers the entire landing course and checks hull
strikes, retry, bay entry, and (with a display) changing gauge and star pixels.
