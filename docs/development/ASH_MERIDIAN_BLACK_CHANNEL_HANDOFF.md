# Black Channel: art delivery and Cursor implementation handoff

## Ownership and hard constraints

Requested October 21, 2026. This handoff covers **Black Channel**, the industrial
canyon flight encounter inspired by the movement and depth of *No Trace Back*.
It does not implement the separate trace-cycle feature.

The [unified approval draft](ASH_MERIDIAN_APPROVAL_DRAFT.md) places this encounter
in the full story. Use it to preserve the first/second-visit distinction.

**The assistant owns model creation and visual design. Cursor owns gameplay
implementation using the supplied assets.**

- All new executable game logic and game tests must be VisualGasic (`.vg`).
  **No new GDScript, including helper controllers or test scripts, without
  explicit user approval.** Existing project infrastructure is not permission
  to add GDScript.
- Native Godot scenes, meshes, materials and GPU shaders are art resources,
  not alternative gameplay implementations.
- Do not create, regenerate, replace, simplify or redesign the models.
  Do not substitute primitives or procedural meshes for them.
- Do not edit the art generator or run it to change geometry. Report any
  required art, collision or attachment-point changes to the assistant.
- Keep supplied scene hierarchies and material resources intact. Instantiate
  them from a new VG-controlled encounter scene. Movement, turret articulation
  and authored gate animation are expected; reshaping assets is not.
- Do not modify the Elite or Vector Crypt reference projects.
- Preserve unrelated working-tree changes. Do not commit or push unless asked.
- Do not modify, import into the game, or overwrite the user's recorded AVI.
- The reference video is inspiration only. No video frames, music, meshes,
  character designs, logos or dialogue from it are shipped in this kit.

## Delivered versus remaining work

**Delivered:** original external GLB models, Godot assembly scenes, material
resources, approximately 13.06 km of assembled canyon, collision proxies, named
attachment points, route samples and event markers, dialogue data, two static
preview scenes, asset tests and this integration specification.

**Current playable status:** the VG controller, HUD and enemy controllers now
provide an isolated **BLACK CHANNEL - FLIGHT TEST** developer destination,
flight input, telegraphed enemy lasers, moving gate, pause and checkpoint retry. Campaign
transition and later-survey integration remain pending. The original asset
delivery did not include gameplay; the subsequent controller work is separate.

The previews remain static art inspection scenes, not gameplay recordings.

**Reference-inspired visual revision:** exposed, triangulated causeways and
industrial skylines now alternate with cliff cuts and the short covered section.
Diagonal lattice gantries establish foreground depth; the original Ash flight
mesh replaces the visible placeholder sphere. Cyan/amber Backlight accents
remain primary, with violet structural accents. Speed-dependent FOV, twin
red/orange exhaust and screen-edge slipstream streaks emphasize acceleration without
copying the reference game's assets or turning the encounter into a race.

The exhaust reuses `shaders/landing_flame.gdshader` from the opening ship,
on crossed flame surfaces at the Ash's two engine markers, with red nozzle
faces. Do not restore the previous solid cyan trail bars. A single GPU canvas
pass adds perspective linework, dust fragments and thin edge mist. It uses
travelled distance rather than wall-clock time, freezes when paused and fades
away during ascent. The ship, navigation marker and warning text remain clear.

The offline `.mjs` files generate and validate the assistant-authored art; they
are development tools, not runtime dependencies. The game loads shipped
resources directly and must not invoke Node.js.

### Landing cockpit performance boundary

The October 22 low-FPS screenshot was the campaign arrival cockpit, not Black
Channel. Its optimization retains static cockpit canvas commands, shares two
landing-ring meshes, and avoids repeated visibility, environment and transform
changes across the full staged yard. Do not remove canyon effects to address
that separate landing bottleneck. Ring geometry, flight/collision rules,
clouds, instruments and damage effects remain.

`test_landing_performance.vg` checks rendered campaign arrival, with optional
`ASH_LANDING_PROFILE=intro` or `live`, and a caller-supplied
`ASH_LANDING_BUDGET_MS`. On the local Intel compatibility renderer, warmed
landing frame cost fell from approximately 58 ms to 17-18 ms p95. Intro checks
passed 14/14 and normal moving landing 15/15, including captures and a
33.34 ms p95 wall-clock budget; speech was disabled. This is not a cross-machine
60 FPS guarantee. The Black Channel view/transition rerun passed 119/119.
The existing broad `test_part1.gd` run returned 82/89: its seven failures concern
options/menu/speech assertions, not landing alignment, controls, retry or clean
course completion. Those unrelated shared-worktree issues were not changed.
After the dialogue change, a short intro profile initially exceeded the
33.34 ms budget at 33.73 ms p95; reruns measured 29.90 ms for intro and 33.16 ms
for moving landing, passing 12/12 and 13/13 without captures. Frame timings
remain load-sensitive; do not treat the earlier 17-18 ms run as a fixed rate.

### Opening dialogue timing

The campaign's opening no longer starts flight on a fixed 44-second timer.
Seven shorter Orac/Jason exchanges share one subtitle/audio source, and the
subtitle follows actual playback rather than a prefetched synthesis job.
The orange-gate briefing, Jason's acknowledgment and final control handoff
finish before landing movement begins. Space/Enter/click skips only the early
story exchange; the briefing remains mandatory. Pause freezes the sequence.
Muted or failed speech uses text-length caption dwell instead.

The fixed opening uses original, locally generated Kokoro WAVs in
`assets/opening_voice`, checked against the script through `dialogue.json`.
This avoids multi-second generation stalls and works without an installed TTS
backend. Missing/stale recordings are logged and shown visibly, then fall back
to live speech/subtitles. Dynamic gameplay dialogue remains live TTS.
See the game README for local model provenance and the developer-only
`tools/bake_opening_voice.vg` regeneration/import commands. Re-bake whenever
opening text or speakers change; do not silently reuse mismatched recordings.

`test_intro_dialogue.vg` covers queue ordering, Jason's voice mapping, subtitle
alignment, pause/mute/error handling and mandatory briefing on skip.
With `ASH_SPEECH_LIVE=1`, it runs the normal campaign loop using actual decoded
recordings while deliberately disabling the TTS backend, verifies every line
and final handoff, and enforces a 1.5-second maximum inter-line gap.
The final rendered campaign run passed 62/62, including the caption capture,
with a measured maximum inter-line gap of 29 ms. Deterministic checks passed
29/29. Playback tests use the dummy audio driver; subjective voice quality
and Windows/macOS execution still need listening/platform checks.

### Copyable Cursor assignment

```text
Continue the Black Channel flight encounter using the existing assistant-made
asset kit. First read docs/development/ASH_MERIDIAN_BLACK_CHANNEL_HANDOFF.md.
Use VG for all new gameplay, AI, UI and game tests. No new GDScript without
explicit user approval. Do not create, regenerate, replace or redesign models,
materials or the authored route. Request art changes from the assistant.
Preserve the isolated BLACK CHANNEL - FLIGHT TEST dev-console destination.
The later post-alliance campaign stage does not exist yet; do not force this
encounter into the first escape or invent completed campaign stages.
Preserve current unrelated edits and campaign saves. Read the known baseline
test failures below before reporting regressions. Implement and verify the
handoff's acceptance criteria. Do not commit or push unless asked.
```

## Story integration

### Flight speech and hull-loss presentation

Flight voice is enabled by default independently of the older Orac-only option.
Press **V** during Black Channel to toggle it; the preference is appended to the
existing options file, preserving older six/seven-line files. The HUD shows
`VOICE ON` / `VOICE OFF`. Subtitles and directional markers remain available.

`flight_speech.vg` supplies a local, non-blocking speech queue:

- Crew dialogue is spoken when its subtitle becomes active; caption dwell time
  accounts for text length when voice is enabled.
- Safety dialogue can interrupt optional crew banter. Short directional
  obstacle calls have higher priority, and hull-loss/retry instructions have
  the highest priority. Each nearest authored obstacle is called once per run,
  with at least 650 m or four seconds of speed-dependent warning distance.
- Pause/developer menus pause playback. Muting, restoring, retrying and leaving
  cancel queued speech; retry resets obstacle-call bookkeeping.
- Installed local Kokoro is preferred on supported platforms; its persistent
  daemon avoids loading model weights for each line. Orac maps to `bm_george`,
  Jason to `am_adam`, and Rob to `am_michael`. One ready audio clip may be
  prefetched, but cannot be overwritten by another generation job.
- Black Channel's 24 fixed crew, hazard, failure and orbital lines are recorded
  locally in `assets/black_channel/voice`, using the opening's model provenance.
  They bypass synthesis even when Kokoro is installed. A live-synthesis repro
  heard Orac at 14.9 seconds and Jason at 20.1 seconds, but Rob was still
  generating at 45 seconds; the caption had already vanished. Recorded playback
  removes that dependency. Dialogue captions now wait for completion, and
  safety warnings defer/replay interrupted crew lines instead of losing them.
  `test_channel_dialogue.vg` verifies the exact entry exchange and urgent-warning
  interruption with the TTS backend disabled. The README documents re-baking.
  Recorded channel playback passed 21/21, including Rob's full reply and its
  restart after an urgent bridge call. Shared live speech passed 16/16,
  gameplay passed 73/73, and the opening playback rerun passed 61/61 without
  capture (17 ms maximum gap). These validate decoded playback state with
  dummy audio, not subjective listening quality.
- Without Kokoro, Linux tries `/usr/bin/espeak-ng`, then `/usr/bin/espeak`, generating
  a uniquely named WAV in the user's application-data directory through
  `OS.create_process`. It polls completion without `OS.execute`, decodes the
  WAV using Godot's loader, and removes it after loading. Workers are terminated
  on cancellation and bounded by a 30-second timeout.
- Without Kokoro, Windows/macOS use Godot's native `DisplayServer` TTS with an installed English
  voice. Linux without eSpeak can also try the native backend. Project TTS is
  enabled. Missing voices/failed generation are logged as
  `FLIGHT_SPEECH_ERROR` and shown as `VOICE UNAVAILABLE`; subtitles remain.
- Optional ProjectSettings keys `ash/flight_speech/linux_voice` (eSpeak name,
  default `en-gb`) and `ash/flight_speech/native_voice` (exact installed Godot
  voice ID) allow later voice selection without changing encounter logic.
  Character names are mapped to valid backend voice IDs, not passed directly
  to system/eSpeak speech. No cloud service is used.

The user's October 21 stopped-flight screenshot showed `HULL 0` after needle
damage, not an impassable bridge. Hull loss now takes precedence over dialogue
and damage captions, displays a central panel with the cause, checkpoint and
**Enter/Space retry** instruction, clears laser effects, sets displayed speed to
zero and lets the damage flash expire. A fatal beam hit exits its update
before touching the beam objects that failure cleanup has freed.

`test_flight_speech.vg` checks priority, pause, once-per-obstacle calls, muting,
cleanup and injected-key retry, plus prepared-reply retention and eSpeak
role-to-voice resolution. With `ASH_SPEECH_LIVE=1`, a rendered Linux run
also verifies a real asynchronous local worker, decoded WAV playback through
the dummy audio driver and temporary-file cleanup (**16/16** without capture
using installed Kokoro).
This verifies audio generation/playback state, not subjective voice quality.
Windows/macOS execution and voice quality still need platform testing.

### Placement

Use this encounter at the **end of the Narcean repair-item hunt**, after the
orbital ambush, EVA rescue and Jason/Rob alliance. Jason is flying the Ash;
Orac and Rob are both available. All other repair items have already been
recovered. This pickup supplies the last missing item, not an intermediate
component followed by another mandatory salvage trip.

The crew restores a distribution installation to release a component needed for
the Ash's repairs. Taking it triggers the installation's surviving local
security. High-altitude batteries reactivate, making a direct climb unsafe.

Rob identifies a maintenance channel beneath the batteries' tracking coverage.
Jason must fly through it to reach a safe ascent point. The final installation
requires isolating and depressurizing the exterior drive housing, so it must
take place in vacuum rather than on the surface. The crew climbs into local
orbit and prepares an EVA repair. This is a later repair operation, not a
replay of the first orbital rescue.

This is not the first-visit chamber escape, a race, an attack in slipspace or a
resurrection of the master planetary AI. The defenses are autonomous equipment.
Destroying them does not kill Rob or another organic character.

The component's exact inventory identifier must be chosen when the repair
survey is implemented. Do not invent an item in the existing first-visit
inventory, conflate it with the coupler or consume the EVA core reserve.

### Dramatic roles

- **Jason:** flies an overloaded, imperfect salvage hauler.
- **Orac:** calls navigation and visible threats; stays online.
- **Rob:** recognizes security behavior and requests a service-gate opening.
  He cannot simply disable the entire network.

Success means reaching the safe ascent point with the component. No kills are
required. Failure restores a local checkpoint, not the chamber or orbital fight.
The first-visit 255-second countdown never runs here.

### Dialogue

`encounter.json` contains original dialogue keyed to route event IDs. Queue
lines rather than playing all lines for a beat simultaneously. Safety warnings
take priority; optional banter may be skipped if it would cover the next warning.

Opening:

> Orac: "Good news: the distribution grid is working."
>
> Jason: "And the bad news?"
>
> Rob: "It has recognized an unauthorized removal. Stay below the rim.
> The upper batteries cannot track us in the channel."

Completion:

> Rob: "Clear of the batteries. You can climb."
>
> Jason: "Next time we take something that is already unplugged."

Read the JSON for the bridge, sentinel, covered-channel and gate warnings.
The gate-clear line is conditional on physical clearance, not merely distance.

## Resource locations

All paths in this section are relative to
`samples/games/ash_meridian_part1/`.

| Resource | Purpose |
|---|---|
| `assets/black_channel/models/*.glb` | External original models; independently reusable |
| `assets/black_channel/scenes/canyon_straight.tscn` | Open-ended 96 m canyon module with cliff/floor collision |
| `assets/black_channel/scenes/covered_roof.tscn` | Ceiling module and rib collision |
| `assets/black_channel/scenes/service_bridge.tscn` | Overhead bridge and supports |
| `assets/black_channel/scenes/security_gate.tscn` | Gate frame and two articulated doors |
| `assets/black_channel/scenes/needle_drone.tscn` | Enemy body, visual, collision and weapon/engine markers |
| `assets/black_channel/scenes/wall_sentinel.tscn` | Turret base, yaw/pitch assembly and muzzle markers |
| `assets/black_channel/scenes/relay_pylon.tscn` | Environmental landmark with signal attachment |
| `assets/black_channel/scenes/black_channel_route.tscn` | Full static route, gate and event/spawn markers |
| `assets/black_channel/scenes/preview.tscn` | Static canyon composition with two drones and a sentinel |
| `assets/black_channel/scenes/asset_gallery.tscn` | Static model inspection composition |
| `assets/black_channel/materials/` | Backlight palette and compatibility-mode distance-haze shader |
| `assets/black_channel/route.json` | Arc-distance samples, safe envelope, event distances, speed contract |
| `assets/black_channel/encounter.json` | Story gate, dialogue, proposed waves and checkpoint IDs |
| `assets/black_channel/manifest.json` | Mesh bounds, triangle counts and model SHA-256 fingerprints |
| `test_black_channel_assets.vg` | Godot load, instantiate, attachment, material and collision checks |
| `tools/test_black_channel.mjs` | Offline binary/data contract tests |
| `tools/build_black_channel.mjs` | Assistant-owned reproducible art source |

Use the `.tscn` wrappers, not bare GLBs, for gameplay. Wrappers provide the
material overrides, collision and attachment points.

There are twenty original model GLBs: canyon straight, covered roof, service
bridge, gate frame, gate leaf, needle drone, sentinel base, sentinel head, relay
pylon, open causeway, lattice arch, industrial spire, Ash flight model and broken
baffle and altitude wreckage (three variants each), and power arc.
Nineteen additional GLBs batch the placed static route visuals; these are
generated assemblies of the same art, not replacement models.

The October 22 gantry correction completes the lattice arch's rear structural
frame at local Z=-24, adds depth ties and visible joint plates, and retains
the crossed diagonal bracing. Previously those braces ended in empty space
because only the front arch was modeled. All route batches are regenerated
from the corrected model. Collision proxies and the flight envelope are
unchanged. `channel-gantry.png` captures the corrected assembly at 2233 m.

The preview environment reuses the game's existing
`shaders/backlight_yard_sky.gdshader`. No reference-project runtime resources
are used. Surface haze is implemented in the supplied spatial shader so it
does not depend on Forward+ bloom or volumetric fog.

## Spatial and collision contract

- Units: metres. Up: +Y. Model forward: -Z. Right: +X.
- Keep the assembled route at identity transform for the first implementation.
  JSON positions and scene marker positions are in the same coordinate system.
- Individual canyon modules are 96 m long, with entry at Z=+48 and exit at Z=-48.
  Nominal local floor height is -14; the inner cliff begins around X=+/-45.
- Full-route modules are positioned relative to the flight center: module origin
  Y is approximately flight-center Y minus 10. **Read the route data instead of
  assuming every floor or flight height is Y=0.**
- Solid scenery uses collision layer **1**, mask **0**.
- Reserve layer **2** for the player hull; collide with scenery and enemy
  bodies as required by the controller.
- Enemy bodies use layer **4**. Needle drones have mask **1**; the controller
  must explicitly decide whether enemy-enemy collision is appropriate.
- Lasers raycast scenery and obstacle layers **1 + 8** (mask **9**), excluding
  enemy bodies and cosmetic effects. Their clipped segment is checked against
  the six-metre player hull separately.
- Model collision proxies intentionally omit thin decorative light strips.
  Use visible body collision, not luminous trails, for these flight enemies.
- The **6 m spherical player clearance proxy** is separate from the visible
  Ash flight mesh. Its authored hull fits that envelope; engine trails are
  cosmetic and have no collision. Keep that separation when revising the ship.
- Lateral sample `half_width` describes the corridor boundary. Subtract the
  clearance radius to obtain maximum center offset. The ordinary half-width is
  40 m; it contracts to 20 m around the service gate.
- `min_height` and `max_height` are permitted **center offsets** relative to the
  sampled flight center, already chosen for a 6 m clearance proxy. Do not
  subtract the radius from these offsets a second time.

Route bounds are navigation limits, not an excuse to draw invisible collision
walls. Use instruments, warning cues and a controlled return toward the safe
lane before an altitude deviation would trigger off-route defenses.

### Needle drone

Root: `CharacterBody3D`. Instantiate the supplied scene and attach a VG
controller, or control it from the VG encounter manager.

Stable paths:

- `Visual/needle_drone/Mesh`
- `HullCollision`, `WingCollision0`, `WingCollision1`
- `MuzzleLeft`, `MuzzleRight`
- `EngineLeft`, `EngineRight`
- `AimPoint`

The muzzles point down -Z; engine markers are behind the hull at +Z. Emit
lasers from marker global transforms, not guessed offsets. Do not aim at
the decorative wing tips.

### Wall sentinel

Stable paths:

- `Yaw`: rotate around local Y.
- `Yaw/Pitch`: articulated `AnimatableBody3D`; rotate around local X.
- `Yaw/Pitch/MuzzleLeft`, `Yaw/Pitch/MuzzleRight`
- `Yaw/Pitch/AimPoint`

The supplied base is horizontal, with the head facing -Z. The route's sentinel
spawn markers orient it toward the incoming ship. It is a ledge-mounted sentinel,
not a model intended to be rotated 90 degrees into a vertical wall.
The pitch body's `sync_to_physics` is disabled: its parent yaw and own pitch
are moved by the VG controller. Enabling physics synchronization can snap the
barrels back toward the origin after mounting/aiming and break the line of fire.

Limit aiming to a readable forward arc. Show a tracking cue, then a committed
charge, then fire toward the committed aim point. It must not snap a charged
shot onto the player after the dodge has begun.

### Implemented laser combat

Needles now fire lasers, not travelling projectile spheres. Their predicted
aim point is fixed when the **0.8-second amber warning** begins. The red burst
lasts **0.24 seconds**, with a 3.8-second needle firing interval. Wall turrets
track for 0.8 seconds, charge for 1.15 seconds, then expose a **0.9-second amber
committed line**, burst and cool down for 2.8 seconds.

The beam origin follows its enemy muzzle, but its committed target never homes.
Solid scenery, gate doors and wreckage clip both the visible beam and its damage
segment every update. Moving off the line or behind cover avoids the hit.
Each hit causes **22 hull damage**, with the existing 0.55-second hurt cooldown
preventing frame-by-frame repeat damage. At most four beam effects coexist.
Hull loss, retry, enemy removal and encounter exit release those effects.
The HUD shows a separate laser-lock warning alongside the obstacle cue.

Four wall turrets occupy ledges at **2450, 2750, 9400 and 11100 m**; the final
two are the added late-course threats. The Ash remains unarmed: evasion,
altitude changes, throttle and cover are the intended responses.

### Service gate

Paths relative to the full route:

- `ServiceGate/LeftDoor`
- `ServiceGate/RightDoor`
- `ServiceGate/Approach`
- `ServiceGate/Clearance`

Each door is an `AnimatableBody3D`. Local Y=14, Z=0.

| State | Left door X | Right door X |
|---|---:|---:|
| Closed | -13 | +13 |
| Fully open | -39 | +39 |

The art preview starts open. The gameplay controller must initialize the
appropriate closed or checkpoint-restored state **before enabling player
movement**. Animate the actual body positions; do not hide the mesh while
leaving collision closed.

Request opening at 2150 m. The gate is at 4150 m. A six-second opening leaves
more than two seconds of margin at the 240 m/s maximum speed. The earlier
request is intentional; do not restore the old 3650 m trigger.

Do not declare the gate clear until the whole hull fits the actual aperture.
If opening is delayed, provide an explicit slowdown/hold behavior upstream of
the gate rather than pushing the player into it. Never close it onto the ship
or behind a checkpoint-restored player.

## Route and encounter specification

The route is approximately 13061 m long. At 90 m/s nominal speed, traversal takes
about 145 seconds before dialogue holds or failure/retry; sustained top speed
takes about 55 seconds, followed by the 24-second ascent.
Throttle is player-controlled, not a forced speed-up.

| Span | Presentation |
|---|---|
| 0-1100 m | Exposed causeway, vector floor lattice and industrial spires |
| 1100-1750 m | Narrower-looking cliff cut within the existing safe envelope |
| 1750-2100 m | Covered maintenance section |
| 2100-3000 m | Open relay expanse with lattice arches |
| 3000-4350 m | Service-lock canyon and articulated gate |
| 4350-6500 m | Exposed freight causeway and first staggered baffles |
| 6500-8200 m | Baffle cut; relay checkpoint at entry |
| 8200-10000 m | Broken-grid causeway |
| 10000-11200 m | Last cliff cut |
| 11200 m-end | Exposed breakout causeway and safe ascent point |

`route.json` is authoritative. Interpolate its densely sampled positions by
distance; do not treat negative Z as total progress or advance one sample per
frame. Use the tangent for heading and the local lateral frame for offsets.

| Event ID | Distance | Intended action |
|---|---:|---|
| `entry` | 0 m | Intro and initial checkpoint |
| `first_pursuit` | 650 m | Two needles establish a visible firing line |
| `bridge_warning` | 1350 m | Warn before the 1450 m service bridge |
| `covered_channel` | 1750 m | Second checkpoint; begin covered section |
| `gate_warning` | 2150 m | Early opening request; center before the service lock |
| `sentinel_warning` | 2250 m | Warn before ledge turrets at 2450/2750 m |
| `service_gate` | 4150 m | Physical gate passage; conditional clear dialogue |
| `relay_checkpoint` | 6500 m | Late checkpoint and baffle warning |
| `breakout` | 11200 m | Final stretch; remain below rim |
| `exit` | Route end | Finish once, climb transition and return to survey |

There is also a passive entry bridge at 180 m, plus bridges at 2050, 2900 and
3300 m. The covered roof occupies approximately 1750-2100 m.

`Markers/<event_id>` contains world positions and distance metadata.
`EnemySpawns/Needle0..2` contains optional drone attachment transforms.
`SentinelSpawns/Sentinel0..3` contains turret attachment transforms.
The third needle marker is reserved for later tuning; it is not permission
to silently increase the agreed initial two-drone wave.

### Initial controls and handling target

- W/S or up/down: pitch/lift within the safe envelope.
- A/D or left/right: bank and move laterally.
- Q/E throttle: bounded 32-240 m/s, default 90 m/s, adjustment 80 m/s per
  second. HUD displays both m/s and km/h (864 km/h maximum).
- Camera FOV widens from 68 degrees at 45 m/s or below to 92 at top speed.
  Camera banking remains restrained; no automatic barrel rolls.
- Hull collision uses sphere sweeps along route subsegments no longer than
  12 m, including lateral/height changes. Endpoint checks alone are not safe
  at the new cap or after a long frame.
- Escape: pause, with simulation, warning timers and dialogue timers frozen.
- Optional existing view-switch binding: cockpit/chase view if both are
  implemented; avoid claiming a second view exists before it does.

The Ash must feel heavy: restrained roll, damped corrections and no compulsory
barrel rolls. Forward movement may be route-guided, but lateral movement,
altitude and collision must be real. Do not repackage this as another ring
scoring course.

### Extended course and local-orbit ending

The October 21 extension adds nine alternating half-width baffles from 5200 to
12300 m, spaced at least 800 m apart. They are real solid obstacles, not arches
above an unobstructed center lane. `route.json.obstacles` records each distance,
blocked side and safe lateral offset (+/-22 m). The HUD gives a left/right cue
up to 950 m in advance; the navigation marker projects the actual open side.
Debug autopilot follows those same dodge offsets rather than ignoring collision.

Baffles use scenery-hazard layer **8**. Player sphere queries and enemy
line-of-sight queries include layers 1 and 8. The ordinary scenery-envelope test
uses layer 1; separate obstacle tests verify solid collision and a six-metre
safe gap. Do not weaken or remove hazard collision to restore a center-lane test.
There are ten service bridges, including new spans at 5800, 7200, 9100, 10800
and 11900 m. A relay checkpoint at 6500 m avoids repeating the entire escape;
retrying beyond the service gate preserves the opened passage.

The balanced challenge pass preserves the opening, existing checkpoint distances
and enemy damage. Six full-width altitude shutters at 7350, 8250, 9150, 10050,
10950 and 11850 m interleave with the lateral baffles. Alternating low barriers
require climbing to approximately +9 m; hanging barriers permit a low passage
around -1 m. These offsets are relative to the route center, not sea level.
Each altitude wreckage assembly occupies an approximately 82 x 20 m envelope.
Low assemblies are centered at -12 m and hanging ones at +22 m. Its six-metre-hull safe
gap is tested against both hazard and scenery collision. A fixed-altitude run
is no longer a valid traversal of the later course.

The former box baffles and shutters are now fractured machinery. Each family
cycles three original silhouettes, with uneven torn plates, exposed bent
reinforcing girders, seams, amber remnants and a damaged mechanical hub on the
second variant. Per-shard convex collision follows the physical plates, girders
and hub; there is no single invisible box covering the whole assembly.
Thin decorative strips remain non-colliding. Route IDs retain `baffle`/`shutter`
for compatibility; player-facing cues call them wreckage or fallen spans.

The HUD selects the nearest upcoming lateral or altitude obstacle, with
`CLIMB ABOVE` / `DIVE BELOW` instructions for shutters. The projected navigation
cue includes altitude, and the developer/test autopilot uses the same authored
safe-height schedule. W/S remains manual altitude control in normal play.
Shutters are spaced 900 m apart (3.75 seconds at maximum speed); the existing
throttle lets the player slow down. Do not tighten their gaps or increase
damage as a substitute for difficulty tuning.

Eye-candy includes shader-driven travelling power pulses on emissive surfaces,
original jagged power-arc assemblies outside the flight envelope, and restrained
distant amber and blue industrial flashes on three independent slow cycles.
World-coordinate drifting shader fog banks and richer slipstream edge mist
add depth without hiding the flight corridor. All effects fade during ascent.
Arcs and sky flashes are decorative, not
invisible damage volumes or security-beam gameplay. These use batched meshes
and shader animation, not per-frame VG particle or light spawning. No rapid
full-screen flashes are used.

At the route end, player-controlled canyon flight changes to a 24-second
automatic ascent: clouds thin, stars emerge and Narcea's curved, blue-edged
mechanical surface appears below. This reaches **local orbit**, not system
departure. The last repair item is now aboard; the remaining work is exterior
installation and commissioning in orbit, not another surface-item search.
Quarantine clearance remains a separate departure condition and is not granted
by completing this flight.
The scene remains in orbital hold with crew dialogue; it no longer automatically
cuts to the title screen. In the isolated developer encounter, Enter opens the
developer menu over the orbital view. Escape pauses both flight and ascent.
The optional `ascent_time` snapshot field restores the transition; old version-1
dev snapshots without it start ascent at zero.

Static route visuals are baked offline into 700 m GLB batches, retaining the
original models and separate collision-only assembly wrappers. Distance culling
keeps far batches out of the frame. Binary-search sampling takes at most nine
comparisons for this route; hull queries reuse a shape and query object.
Gate bodies are updated only when the opening fraction changes. These reduce
render and allocation overhead without changing collision or reducing the art.
Route positions and centered per-knot headings are cached at entry. Headings
interpolate continuously across sample boundaries instead of snapping to the
next segment (the old maximum instantaneous step was approximately 8.48 degrees).
The sampled centerline and solid obstacles are unchanged.

Do not add a weapon to the Ash without establishing it in the campaign.
The first implementation may be entirely evasive. If a defensive weapon is
added later, bind it to an existing installed-tool state.

## Proposed VG integration surfaces

These are work assignments, not existing callable APIs.

Suggested new game-owned files:

- `black_channel.vg`: encounter lifecycle, event queue and route movement.
- `black_channel_needle.vg`: drone state machine.
- `black_channel_sentinel.vg`: turret tracking/charge/fire logic.
- `black_channel_hud.vg`: controls, navigation and warnings.
- `test_black_channel.vg`: gameplay and persistence regression.

Suggested manager methods:

- `start_encounter(mode, context)`: explicit dev versus campaign ownership.
- `tick(delta)`: physics-safe simulation; no advance while paused.
- `snapshot()` / `restore(state)`: validated persistent state.
- `retry_checkpoint()`: rebuild deterministic local encounter state.
- `finish_encounter()`: one-time completion and transition.
- `dispose()`: release scene, effects, audio, timers and signal connections.

Expose explicit running/completed/failed state. If resources or state validation
fail, show an actionable error and leave the prior campaign state intact.
No catch-all reset, silent fallback art or fake successful completion.

### Existing files to inspect before editing

- `part1.vg`: `PageCount`, `MainScene`, `SceneAt`, `DevLabel`, `WarpDev`,
  pause handling and current campaign return behavior.
- `presentation.vg`: `SpawnVg`, `prepare_campaign_yard`,
  `activate_campaign_yard`, viewport/rendering ownership and cleanup.
- `campaign.vg`: `stage`, `fields`, `validate`, save/load and inventory ownership.
- `test_campaign.vg`, `test_part1.gd`: existing behavior and dev-menu assertions.

The production controller and its test currently have unrelated uncommitted
edits. Inspect and preserve those changes before adding the new dev entry.

**Important:** the existing campaign currently reaches first departure, not the
post-alliance survey. `rob_allied`, `distribution_component_secured` and the other
story gates in `encounter.json` are proposed future state, not existing fields.
Do not fabricate a post-alliance completion in today's campaign or call this
from `first_escape`.

### Dev-console integration first

Add **BLACK CHANNEL - FLIGHT TEST** to the current/main dev destination list,
not the archive. Choose an unused scene/phase identifier after inspecting the
current code; do not assume the historical Canyon identifier is free.

The hidden terminal is opened with:
Up, Up, Down, Down, Left, Right, Left, Right, B, A, B, A.

Launch an isolated encounter with its own fixture context. Returning to the
campaign must restore the previous location, cargo, parked buggy, objective,
Orac state and timers. The dev encounter must not grant mission items, advance
the campaign, save over the campaign file or consume its countdown.

Use the existing campaign-resume mechanism where appropriate. Do not replace
the first landing, original canyon reference or main Play route.

### Campaign integration later

When the post-alliance survey actually exists:

1. Gate entry on allied Rob, online Orac, all other repair items already aboard
   and the final distribution component pickup. Do not trigger it mid-hunt.
2. Record the survey return context before switching scenes.
3. On success, retain the already recovered component and mark completion once.
4. On failure, restore the encounter checkpoint without rerunning the pickup.
5. Hold in local orbit and hand off to the exterior drive repair/EVA stage.
   Do not automatically send the player back to another salvage district.
6. Complete installation and commissioning before permitting departure; enforce
   the separately established quarantine clearance as well.

The playable developer encounter currently supplies the orbital holding scene
and dialogue, not the EVA repair mechanics. Future completion must consume the
final part once, set the repaired-system state once and preserve the orbital
return context across saves.

Do not make repairs or salvage rewards repeatable by retrying or revisiting.

### Persistence

Save a validated encounter version, entry mode, checkpoint ID, route distance,
player offsets/speed/hull state, gate progress, fired-event IDs, encounter
completion, deterministic enemy state and the survey return context.

Either serialize active laser warnings/bursts correctly or explicitly restore a safe
checkpoint without them. Do not resume a nominally exact mid-shot save while
silently removing its danger.

Use the repository's atomic-save pattern. Introduce schema migration or an
explicit unsupported-version message when needed; do not append unvalidated
fields to the current strict first-visit save schema.

## Acceptance criteria for Cursor

### Required playable behavior

- Main dev terminal reaches the encounter without playing the campaign.
- The provided external models are visible and unchanged.
- The route is traversable at both 32 and 240 m/s.
- Camera banking does not move an aiming/navigation marker away from its real
  projected flight path.
- The actual player hull clears bridges, roof seams and the opened gate.
- Gate mesh and collision move together; a late gate never creates a forced hit.
- Drones do not spawn inside the player, fire from behind invisible scenery or
  damage the ship before a readable warning.
- Turrets respect occlusion and their charge/committed-shot sequence.
- No kills are required to complete the route.
- Hull contact, lasers and effects do not cause damage once per render frame.
- Pause freezes simulation and timers; retry clears old enemies/lasers.
- Finish fires once and returns to the intended context.
- Dev play leaves the campaign snapshot and save file unchanged.
- Save/load and checkpoint retry cannot duplicate pickups or completion rewards.
- Repeated entry/exit releases all encounter nodes, audio and timers.

### Required implementation evidence

- New controller/HUD/AI/tests are VG, with no new `.gd` files.
- Asset fingerprints and `--check` remain unchanged.
- New gameplay regression includes failure, retry, pause, gate timing,
  maximum-speed clearance, save/load and dev isolation.
- Existing campaign and relevant presentation regressions still pass.
- At least one rendered completion is checked, not only a state-driven autopilot.
- A manual or recorded run verifies that geometry and warnings are readable at
  the target viewport size.

### Existing asset validation commands

Run from the repository root; run Godot tests sequentially.

```bash
node samples/games/ash_meridian_part1/tools/build_black_channel.mjs --check
node --test samples/games/ash_meridian_part1/tools/test_black_channel.mjs

./Godot_v4.6.1-stable_linux.x86_64 --headless \
  --path samples/games/ash_meridian_part1 \
  --script "$PWD/test_proj/run_suite.gd" \
  -- res://test_black_channel_assets.vg
```

The `.gd` runner above is existing repository test infrastructure; the new test
it loads is VG. Do not add a new GDScript runner.

The gameplay camera orientation regression is `test_black_channel_view.vg`.
Run it with the same runner, using OpenGL compatibility rendering under
`xvfb-run -a` when no display is available. It checks forward route alignment,
ship heading, a non-mirrored camera and actual screen-space target projection
at the entry, covered section and both turn directions. Set
`ASH_CHANNEL_CAPTURE` to an existing absolute directory to save entry and
covered-section PNGs. Camera direction checks use `to_global()` rather than
assuming the layout of a Basis property.
It also advances the real encounter tick and checks that the ship travels
camera-forward, a fixed landmark approaches, and that landmark expands outward
on screen rather than receding. It verifies world-up projection and the camera's
up vector, then exercises the normal game process near 152 m. Rendered checks
inspect the final root viewport (including the HUD composition), requiring the
amber floor markings below rather than above the horizon. Captures also include
`channel-composite.png`, `channel-live.png`, `channel-moving.png` and
`channel-fast.png`, `channel-obstacle.png`, `channel-ascent.png` and
`channel-orbit.png`.

The October 21 upside-down/backward playable view was reproduced after calling
the earlier flight presentation before rendering Black Channel. That path leaves
a reflected transform on the shared camera; `Node3D.look_at()` preserves its
negative scale. Direct developer entry on a fresh camera did not reproduce it,
which is why the original checks missed the transition.

`BlackChannel.AimCamera` now resets the camera transform before positioning,
aiming and banking it. The regression covers both fresh entry and the inherited
legacy reflection, as well as normal game processing and final composition.
No texture-flipping changes are required. The rendered view suite has reached
**119/119** with optional capture enabled on Godot 4.7.2. The final laser/wreckage
rerun returned **118/119**: the previously observed intermittent
`normal_game_loop_advances_along_route` check failed while the game clock advanced.
An intervening diagnostic run passed 119/119; this is not a consistently green
suite, and the remaining loop-advance issue is not resolved by this art/combat pass.
The test now logs route distance, phase, menu/developer state, running/failure
state and game clock to make the failure observable. Camera, projection, image
composition and orbit checks passed.
The ending check injects Enter through the running game callback and verifies
that the developer menu retains the same encounter in orbital hold. Completion
and failure retry are mutually exclusive; menu activation uses the shared
consumable key taps so opening the menu cannot also activate its selected scene.
Gameplay regression passes **73/73**, including hull-loss recovery, fatal-beam
cleanup, full 240 m/s traversal, early gate opening,
late-checkpoint restoration, ascent pause/restore and a sweep against a 0.2 m
obstacle. Route collision/resource checks pass **105/105**, including all nine
baffle gaps and all six shutters' safe/blocked altitudes; offline model/data
checks pass **12/12**, including rear gantry-frame attachment geometry and
distinct wreckage variants with convex shard collision.

`test_black_channel_lasers.vg` passes **28/28** with captures, checking harmless
charge, committed aim, evasion, damage/cooldown, cover clipping, moving muzzle
attachment, cleanup, and actual mobile-needle and late-wall-turret controllers.
Both added turrets must also acquire and fire from their actual canyon mounts,
not just an unobstructed isolated fixture.
Captures are `channel-laser-lock.png`, `channel-laser-burst.png` and
`channel-fractured-bridge.png`, `channel-wreckage-machinery.png`,
`channel-wreckage-plates.png` and `channel-wall-turret.png`.
The slower 60 m/s gameplay traversal isolates geometry by removing enemies;
the separate evasive 240 m/s traversal keeps combat enabled and requires no
kills. The developer autopilot's beam avoidance is test assistance, not a new
automatic evasion feature in normal manual flight.

`test_black_channel_flight.vg` performs a continuous rendered top-speed run through
the full obstacle course and into orbit, advancing simulation 0.1 s per rendered
frame. Its checks pass **6/6**. It reports p95 tick and frame times and the maximum draw-call count.
These are diagnostics, not a hardware-independent FPS guarantee. The earlier Intel GPU
run measured 71 maximum draw calls across the course (36 at entry). The ending
test checks visible stars above and blue planet pixels below, not just state
flags. All game tests remain VG.

After the laser/wreckage pass and turret articulation correction, both flight
modes passed **6/6**. The full combat run reached orbital hold with 78 hull.
Local Intel GPU measurements were p95 tick 3.44 ms / frame 16.67 ms, maximum
93 draw calls for the accelerated full route, and 3.31 ms / 16.67 ms with
84 maximum draw calls for the separate 20-second real-time profile. These
individual runs do not establish a locked frame rate or eliminate every hitch.
Speech queue, hazard wording and actual-key retry regression passed **10/10**
with captures and without live voice generation.

The motion regression checks every interior route-sample boundary for heading
continuity (tangent dot product above 0.999999), reads the shared opening flame
shader from the exhaust mesh, counts visible slipstream pixels at the screen
edges and requires those pixels to move when travelled distance changes. The
effect must be absent in orbital hold and freeze when paused.

Set `ASH_CHANNEL_REALTIME=1` for a separate 20-second variable-frame-time flight
profile through the service gate. This is a frame-pacing smoke test, not an
assertion that a non-evasive center-following autopilot survives the full combat
encounter. The default run still tests the entire route and ascent at 0.1 s
simulation steps with enemy and obstacle collisions enabled.

After the motion pass, both flight modes passed **6/6** with captures enabled.
On the local Intel GPU, repeated accelerated runs measured p95 frame times
between approximately 18.1 and 26.1 ms; the final 20-second real-time profile
measured 27.5 ms and 72 maximum draw calls. These measurements still show frame
time variability; they are not evidence of a locked 60 FPS or elimination of
every hitch.

After the balanced challenge pass, full-course and real-time flight checks
still pass **6/6** each. The local real-time profile measured approximately
31.3 ms p95 and 72 maximum draw calls; the full-course profile reached 75 draw
calls. These are additional measurements, not a performance improvement claim.
`channel-altitude-challenge.png` captures the climb warning and low shutter.

The rendered resource-instantiation suite also reports four GLES texture cleanup
warnings on exit. The gameplay, view and continuous-flight runs do not report
those warnings; the resource-suite renderer cleanup is not yet resolved.

Static preview:

```bash
./Godot_v4.6.1-stable_linux.x86_64 \
  --path samples/games/ash_meridian_part1 \
  --rendering-method gl_compatibility --windowed \
  --scene res://assets/black_channel/scenes/preview.tscn
```

Use `asset_gallery.tscn` instead to inspect the vehicle, turret, pylon and gate.

## Validation at art delivery

Initial asset-delivery validation, before the visual/speed revision, used
Godot 4.6.1 and OpenGL compatibility rendering on October 21, 2026:

- Generated resources match the offline art source (`--check`).
- Offline GLB/data contract tests: **7/7**.
- VG resource/material/collision tests: **46/46**.
- A 6 m sphere is swept along the route at its center, lateral limits and
  upper/lower height limits. The open route clears these tests.
- Gate ray tests confirm that the open aperture is clear and that moving
  the door bodies closes the physical passage.
- Canyon and model-gallery scenes render without resource or shader errors.
  The virtual-display driver reports only an unsupported V-Sync-setting warning.
- Static rendered images are included in the kit's `previews/` directory.

### Existing campaign baseline is not green

The existing campaign regression currently reports **50/61**, not 61/61.
The same eleven failures reproduce in an isolated copy of the current tracked
game files with **none of the new Black Channel files present**.

The first failing assertion is `campaign_coupler_wakes_feb_not_orac`.
Other failures cover active-escape saves/timing, departure, contextual scanning
and Continue/cold-load restoration. Their root cause has not been diagnosed
as part of this art delivery. Do not assume that all eleven are independent bugs.

No campaign controller, production presentation code, main game controller or
existing gameplay test was edited for this asset delivery. Resolve or explicitly
track these baseline failures before claiming the whole campaign is validated.
