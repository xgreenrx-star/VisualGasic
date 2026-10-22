# Black Channel asset kit

Original Narcean canyon and security models for Ash Meridian. The assistant
creates and maintains the art; Cursor implements gameplay **in VG only**.
Do not replace or regenerate these models during gameplay implementation.

## Start here

Read the [story and Cursor handoff](../../../../../docs/development/ASH_MERIDIAN_BLACK_CHANNEL_HANDOFF.md)
for ownership, attachment paths, collision, route events, dialogue, campaign
placement and required gameplay tests.

- [Canyon preview](scenes/preview.tscn): static art scene, not a playable encounter.
- [Asset gallery](scenes/asset_gallery.tscn): static model inspection scene.
- [Full route](scenes/black_channel_route.tscn): approximately 13.06 km of scenery.
- [Model manifest](manifest.json): external GLBs, mesh bounds and fingerprints.
- [Route contract](route.json): sampled flight path, boundaries and events.
- [Encounter contract](encounter.json): story gates, dialogue and intended waves.
- [Canyon image](previews/channel.png) and [model image](previews/gallery.png):
  rendered static previews, not gameplay captures.

## Delivery

Twenty original GLBs provide the canyon module, covered ceiling, service bridge, gate
frame and leaf, needle drone, sentinel base and head, relay pylon, exposed
causeway, diagonal lattice arch, industrial spire, Ash flight model and broken
baffle and altitude wreckage (three variants each), and power arc.
Nineteen more GLBs batch placed scenery into 700 m sections, reducing
draw calls while preserving the original meshes and separate collision wrappers.
Game-facing native scenes add collision, stable markers and Backlight materials.
Use the scene wrappers, not bare meshes, when implementing gameplay.

The route alternates exposed vector-grid causeways and industrial skylines with
cliff cuts, a short covered section, overhead bridges and an articulated service
gate. Preview enemy instances are static. The asset scenes contain no game
controllers. The separate VG encounter is playable from the developer terminal;
campaign integration remains pending.

Flight speeds are 32-240 m/s, with a 90 m/s starting cruise and 80 m/s per second
throttle adjustment. The 240 m/s cap is 864 km/h. The gate opening request is
at 2150 m, giving more than eight seconds before the 4150 m gate at top speed.
The VG controller sweeps the six-metre hull along route subsegments to prevent
high-speed tunnelling, and widens the camera FOV from 68 to 92 degrees as speed
rises. Twin red/orange flames reuse the opening ship's exhaust shader. GPU
perspective streaks, dust fragments and thin edge mist add motion cues while
leaving the ship and navigation area clear. Cached, continuously interpolated
headings avoid camera snaps at route-sample boundaries.

Nine alternating wreckage obstacles require left/right dodges, with HUD warnings
and safe-gap markers. Ten overhead bridges break up the route. A relay checkpoint
at 6500 m supplements the entry and covered-section checkpoints.
Six fractured altitude wrecks from 7350 to 11850 m alternate climb-over and
dive-under passages between the baffles. Advance HUD warnings and the projected
navigation cue include the required altitude. Torn plates, bent girders and
damaged machinery vary across three silhouettes per family; per-shard convex
collision replaces the old solid box proxies.
Needles and four ledge-mounted wall turrets use committed lasers: amber
warnings precede short red bursts, with solid cover clipping both visual and
damage segments. Two new turrets guard the late cut at 9400 and 11100 m.
Existing 22-point enemy damage and checkpoint positions are preserved.
Original electrical arcs sit outside the flight corridor; travelling emissive
power pulses, three distant industrial flash cycles, drifting shader fog banks
and layered edge mist are decorative shader effects.

Completion plays a 24-second cloud ascent into a starfield with Narcea below,
then holds in local orbit for crew dialogue. This remains part of the repair
survey's final pickup, not an intermediate recovery: the last item is aboard,
and installation in the isolated exterior drive housing must finish in vacuum.
The EVA repair stage is not yet implemented. This is not system departure.
Enter opens the developer menu without
an automatic black/title cut. Escape pauses the ascent.

Materials use opaque dark surfaces, selected luminous edges and shader-based
distance haze that works with the OpenGL compatibility renderer. The preview
reuses the existing Backlight Yard sky resource.

All game logic and new game tests must be `.vg`. The dependency-free Node.js
art source and binary tests are offline tooling only. No new GDScript is
included.

## Verify

From the repository root:

```bash
node samples/games/ash_meridian_part1/tools/build_black_channel.mjs --check
node --test samples/games/ash_meridian_part1/tools/test_black_channel.mjs
```

Import with Godot if opening a fresh checkout. Run the VG resource/collision
test through the existing repository runner as documented in the handoff.
