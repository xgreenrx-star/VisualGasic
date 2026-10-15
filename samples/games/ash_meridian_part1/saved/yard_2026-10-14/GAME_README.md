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

## Rendering and regression checks

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
