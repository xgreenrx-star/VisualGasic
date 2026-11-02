# Ash Meridian: Trace Cycle, vault and return chase

> **October 31 route/underground direction:** use
> [Underground levels and route consolidation](ASH_MERIDIAN_UNDERGROUND_HANDOFF.md)
> for the current plan. It supersedes conflicting progression guidance below.
> The older combined preview still uses the yard proxy; the actual Play merge
> and removal of its old local FEB chamber are not implemented.

## Status and ownership

The November 1 [AI face opening handoff](ASH_MERIDIAN_AI_FACE_HANDOFF.md)
(v2: holographic alien face → mouth tunnel → title menu) defines a separate
animation task for the opening and later FEB AI display.
It does not replace the FEB character model or alter the campaign route.

Prepared October 23, 2026 at the user's request to split work with Cursor.
This includes the first script-free 3D model kit and an implementation handoff.
The art is available for isolated integration; the new campaign route has not shipped.

- **Assistant:** visual concepts, original models/materials, scenery assembly,
  story/dialogue, asset contracts and art fixes.
- **Cursor:** VG controllers, collision, AI, interaction, state/save migration,
  campaign wiring and tests. Do not create or replace models.
- All new game-owned executable code and tests must be VG. Native Godot
  resources/shaders are allowed. Do not add GDScript or modify other sample games.
- Preserve concurrent worktree edits, the existing campaign, Black Channel,
  voice work, user media and saves. Do not commit/push unless requested.
- Implement in small reviewed increments; do not delegate or run additional
  paid agents automatically.

### What actually exists

| Surface | Current evidence | Readiness |
|---|---|---|
| Cycle | Original [player model](../../samples/games/ash_meridian_part1/assets/trace_vault/scenes/trace_cycle.tscn), red remote variant and [concept sheet](../../samples/games/ash_meridian_part1/assets/trace_vault/concepts/trace_cycle.png) | First-pass 3D art ready for isolated VG integration |
| FEB and stasis cradle | Separate articulated model and mechanical cradle in the kit; [concept](../../samples/games/ash_meridian_part1/assets/trace_vault/concepts/feb_vault.png) | Awakening pivots authored, no walking animation or active effects |
| Underground interaction | [backlight_exploration.vg](../../samples/games/ash_meridian_part1/backlight_exploration.vg) has lifts, coupler removal, awakening, 255-second escape and retry | Must be adapted, not duplicated |
| Campaign state/save | [campaign.vg](../../samples/games/ash_meridian_part1/campaign.vg), save version 1, validated exact field set | New stages require explicit migration |
| Cycle route, docks, chase | Static field kit plus isolated `trace_cycle_test.tscn` / VG controller now present | Playable prototype; void presentation, cockpit and navigation feedback need the October 25 revision below; not accepted final gameplay |
| Isolated route state | [trace_route.vg](../../samples/games/ash_meridian_part1/trace_route.vg) and its tests | Stage/save contract exists; not selected by Play |
| Music boot credit | User-selected Lucid sketch copied into game-owned branding assets; credit added separately | Project boot splash configured |

The PNG concept sheets remain references, not geometry. The actual model kit
is in `assets/trace_vault/scenes` with shared native materials. Review the
rendered previews before treating this first pass as approved final art.
Cursor must use these scenes, not generate replacement models.

### Validation of this delivery

The two original SVG sheets render to 1600x1000 PNGs and import in Godot.
`test_art_direction.vg` passes 10/10 checks for the custom boot settings,
minimum display time, splash decoding/dimensions and both concept resources.
An isolated rendered startup capture confirms the actual engine boot shows
the user's selected sketch and **Music by Lucid nod**, without the default
engine logo. The original sketch is preserved byte-for-byte. The splash
configuration uses Godot 4.7's `boot_splash/stretch_mode=1` (Keep).
The new `test_trace_models.vg` checks all 15 scenes, recursive script-free
geometry/materials/collision shapes, marker paths, independent articulation,
unit-scale roots, collision dimensions and field height. It passes 128/128.
The deterministic offline generator passes `--check`. Native OpenGL previews
were rendered and visually reviewed; a reversed cradle presentation was
corrected before delivery. These checks do not validate movement, trails, AI,
walking animation, balance or chase performance.

Regression reruns also pass `TRACE_ROUTE=64/64`, `CAMPAIGN_RESULT=61/61`
and `ART_DIRECTION=10/10`. The isolated route test still reports six ObjectDB
instances and three resources retained at process exit; its cleanup diagnostics
are not resolved by this model-only delivery. The new model suite emits no
runtime errors or resource-leak diagnostics.

Local review captures:
[cycles](../../build/ash_meridian/trace-cycle_preview.png),
[vault and FEB](../../build/ash_meridian/trace-vault_preview.png),
[kit gallery](../../build/ash_meridian/trace-asset_gallery.png),
[crossing overview](../../build/ash_meridian/trace-crossing_preview.png).

The original user-supplied FEB/pod image was not located in the checked
Downloads, Pictures or project scratch images. The new sheet is a proposal,
not a recovered reference. If the user supplies the original, reconcile it
before approving the FEB's final visual design. This first-pass model follows
the new concept, not that missing image.

## Naming and diagnostic purpose

Use **Trace Cycle** for the maintenance vehicle and **TRACE ON / TRACE OFF**
for its field-diagnostic mode. Do not use film titles, logos, copied sounds,
character likenesses or other direct franchise references in game assets/UI.

The historical nod is execution tracing in older BASIC dialects; some used
`TRON`/`TROFF`, and syntax differed by dialect. This is inspiration, not a claim
that all old BASIC implementations had a command spelled `TRACE ON`.

The cycle is a mobile probe for a failed bridge support network. Outbound,
Jason traces three relay connections to locate a broken power route. His
trace carries a diagnostic containment field, visualized as a tall ribbon.
Completing the links opens the far platform's service access.

The cycle operates only inside surviving magnetic support infrastructure;
it cannot fly across arbitrary terrain. TRACE OFF is the dock/service state,
not a player-controlled escape from trail collision.

Suggested short dialogue, pending final recordings:

- Orac: "The bridge is dark. Its support field isn't."
- Jason: "And that thing can ride it?"
- Orac: "It's a maintenance probe. Trace the relay links and we can reach the lift."
- Jason: "What does the wall do?"
- Orac: "Marks the live circuit. Don't cross your own work."

## Campaign sequence

Follow the newer [approval draft](ASH_MERIDIAN_APPROVAL_DRAFT.md), sections 6-9,
rather than the earlier proposal's optional-crossing wording:

1. **Backlight Yard:** archives yield five ordered symbols for the cycle cradle.
   The existing local transit lift remains available, but cannot bypass the
   crossing into the deep FEB chamber.
2. **Outbound crossing:** no opponent. Teach movement, one deliberate turn,
   then relay linking and self-wall avoidance. Dock automatically at the far
   platform. Clear trace state only after docking is safely complete.
3. **Deep lift / vault:** separate from the yard lift. The route leads through
   service spaces into the FEB chamber. Jason collects portable cores, then
   removes the compatible coupler from an isolation service socket.
4. **Awakening:** coupler removal breaks isolation. Amber pulses, clamp release,
   low vent mist, head/hand movement, and a visible/audible 255-second warning.
   Orac remains online. The timer covers escape from the underground facility,
   not the full chase, buggy journey or launch.
5. **Return crossing:** checkpoint at the far dock, after facility escape.
   A red unmanned enforcement cycle activates through the restored network.
   Escape to the near dock; an opponent kill is optional.
6. **Near dock / Ash:** return by buggy, install the coupler, preserve protected
   core reserve for the later rescue, then use the campaign's departure flow.

The physical FEB remains underground during the cycle chase. The enemy's
apparent rider is a sealed control housing. Destroying this vehicle does not
kill/resurrect the FEB. Do not call him Rob yet. The EMP and physical spacecraft
ambush remain second-visit events; Black Channel remains post-alliance.

## Original visual direction

### Cycle

Proposed dimensions: 4.2 m long, 1.35 m wide, 1.55 m high.
Enclosed canopy, graphite armor, recessed mechanical wheel drums, cyan seam
lights, amber manual latches, offset work lamp, separate rear split projector.
No exposed rider and no uninterrupted glowing wheel discs. The red remote
unit shares this maintenance chassis with a sealed canopy insert and red
status light; it is not a second unrelated vehicle design.

### Vault and FEB

The FEB is now a ~1.88 m human in a pale original-Tron-style suit: cyan circuit
lines (chest V, belt, legs, arms), shoulder rings, back disc ring, chest core,
helmet with brim and ear guards, and an amber wrist cuff on the thermal arm.
The former 2.65 m robot guardian is kept unchanged as `greg.tscn` and is
reserved for a later part of the game. Do not use Greg in the vault.

The stasis cradle uses an opaque crown, base, mechanical clamps and separated
protective panels. Keep the figure readable; do not put it behind a stack of
transparent cylinders. Use amber for the console/coupler socket and cyan for
standby. The return exit must be visible from the pickup position. Mist stays
low and does not obscure the countdown, interaction target or exit.

### Delivered asset contract

All scene paths below are relative to `res://assets/trace_vault/scenes/`.
Marker paths are relative to each scene root. Pivots are Node3D;
interaction/pose anchors are Marker3D unless noted.

| Resource | Required authored attachment points / movable pieces |
|---|---|
| `trace_cycle.tscn` | `VisualRoot`; `VisualRoot/CanopyPivot`, `VisualRoot/FrontWheelPivot`, `VisualRoot/RearWheelPivot`; root `TraceEmitter`, `Seat`, `ExitPoint`, `CameraTarget` |
| `security_cycle.tscn` | Same movement/emitter contract, sealed control housing |
| `cycle_cradle.tscn` | `DockPose`, `ApproachStart`, `ApproachEnd`, `ExitPoint`, `Console`, `ClampLeft`, `ClampRight` |
| `relay_pylon.tscn` | `LinkSocket`, `StatusAnchor`; `StatusLamp` is the visible torus mesh; static collision |
| `vault_room.tscn` | `Entrance`, `Exit`, `Console`, `CoreBank`, `StasisMount`; walkable static collision |
| `stasis_cradle.tscn` | `FigureMount`, `ClampPivots`, `VentSockets`, `CouplerSocket`, `WarningPanel`; `Capsule/LidLeft`, `Capsule/LidRight` (hinge pivots, each with `Seam`), `Capsule/Fog/{CrackFog,BaseFogLeft,BaseFogRight}` (CPUParticles3D, idle) |
| `feb.tscn` | `VisualRoot/HeadPivot`, `VisualRoot/ServiceArmPivot`, `VisualRoot/ThermalArmPivot`, `ThermalSocket`, `CameraTarget`; human, no full locomotion rig |
| `greg.tscn` | The old robot rig with the same pivot names. Reserved; not placed in the vault |
| `core_bank.tscn` | `Core0`, `Core1`, `Core2`, each with `Pickup`; hide the collected prop, not the whole cabinet |
| `power_coupler.tscn` | `Grip`; insert root using the cradle's `CouplerSocket` transform |
| `deep_lift_lobby.tscn` | `Entrance`, `LiftPose`, `Console`, `Cabin`; separate deep-service landing, not one of the local yard rooms |
| `void_crossing.tscn` | `NearCradle`, `FarCradle`, `Relay0`-`Relay2`, `DeepLiftLobby`; `PlayerSpawn`, `SecuritySpawn`, `NearExit`, `FarLift` |
| Preview scenes | `cycle_preview.tscn`, `asset_gallery.tscn`, `vault_preview.tscn`, `crossing_preview.tscn`; static review cameras, not game destinations |

Metres, +Y up, forward -Z, unit-scale roots, floor-contact origins. Individual
visual pivots must be independent of collision/movement roots. Models contain
no runtime scripts. The cycles have CharacterBody3D roots, one box proxy each,
layer 2/mask 1. Static scenery uses layer 1/mask 0. Bank `VisualRoot` only:
the emitter and hull collision remain on the movement root. The FEB has no
gameplay collider; Cursor must choose an interaction/hurt proxy if needed.
Materials are shared resources: duplicate the relevant material before changing
one instance's status color, rather than recoloring every cyan/amber asset.

The vault has separate floor, wall, lintel and console collisions, not a
solid convex hull across its interior. Its 4.4 m doorway faces +Z. Place the
cradle using `StasisMount` including its 180-degree rotation; apply that
rotation to the FEB too, with its floor at `FigureMount`. `vault_preview`
demonstrates the assembly, including the separately removable coupler.

The cradle opens toward local -Z. Approach markers face +Z into the dock;
`DockPose` faces -Z for launch. The far cradle is rotated 180 degrees.
Use the markers' world transforms rather than hard-coded directions.
The field support surface is Y=0, X=-80..80, Z=-120..120. Its boundary
collisions are an authoring aid, not a substitute for maximum-speed sweeps
or a visible crash/retry response. `FarLift` is the lobby threshold; then use
`DeepLiftLobby/LiftPose`. The static `Cabin` is intended for a transfer/fade;
do not animate StaticBody3D collision as though it were a moving lift body.

`manifest.json` records scene roles, nominal dimensions, marker paths and
SHA-256 hashes. `route.json` records field bounds, dock positions and relay
order; it is an art layout, not approved gameplay balance. Rebuild/check:

```bash
node samples/games/ash_meridian_part1/tools/build_trace_vault.mjs
node samples/games/ash_meridian_part1/tools/build_trace_vault.mjs --check
```

The generator is an offline Node art source, not a game runtime dependency.
Ask the assistant for model revisions; do not hand-edit generated scenes or
regenerate them from Cursor. The local Storage/Maintenance/Laboratory interiors
are still unauthored; the deep-lift lobby does not fill that scope.

## Confirmed isolated save contract

- Play stays on campaign save version 1 with its exact 32-field expedition.
- Local `11111`/`22222`/`33333` remain development placeholders for Storage
  (finite salvage/empty racks), Maintenance (bridge diagnostics) and Laboratory
  (stasis/FEB foreshadowing). Final clues wait for authored rooms/signage.
- A v1 salvage save may adopt the new route. Active old-chamber escape,
  completed old-route state or existing coupler possession refuses adoption.
  Leave the original file unchanged and explicitly explain that it remains
  playable on the legacy Play route.
- First release is checkpoint-only: a mid-ride save records `near_cradle`,
  `vault` or `far_dock`, not the exact crossing, two vehicles or trail state.
  Tell the player which checkpoint will be restored.
- Bind initially unbound controller references using `Is Nothing`, never
  `<> Nothing`. An absent controller cannot read/write the yard escape state.
  Qualify that field as `Me.failed`; do not rename it or reintroduce the
  bare-name collision with VG's error flag.
- Next: isolated TRACE CYCLE destination using this kit. Campaign version 2
  with an explicit `trace_route` section comes later, after isolated acceptance.

## October 26 evening: corners, trace toggle, night sky

- **Gap-free corners.** Turns pivot the bike around `TraceEmitter` (`PivotOnEmitter`), so the old and new trail segments share one corner point. Trail segments arm only after the hull no longer covers them (`HullCovers`), because `body_test_motion` ignores shapes the hull already overlaps.
- **Trace Off (T).** Pressing T starts `SHUTTING DOWN TRACE 5…1`. During the 5 s countdown the trace stays live, so the toggle cannot be used to dodge a crash. At zero, every trail is erased, unfinished relays reset to 0, and `TRACE OFF  FIELD RESET` shows for 2.4 s. The trace then resumes and the rider must link beacon 1 again. Retry clears both states.
- **Powered trace.** Trails use `trace_glow.gdshader`: an energy wave runs along each wall, with a fast hum, so the wall reads as live. `TracePowerFor` drives `power`: 1 while on, dimming to 0.75 over the first 3 s of shutdown, then a stutter that speeds up through the last 2 s before the walls blink out at the wipe.
- **Goal clarity after the relays.** A gold `OBJECTIVE` line under the glass label is set every frame from `Objective()`: link relay n → ride into the far dock → press E for the deep lift → take the core and coupler → leave → ride back to the near dock. Linking relay 3 sets `field_open_t = 4`, which pulses the banner and shows `ALL 3 LINKED  FAR DOCK OPEN`. The hint then reads `FAR DOCK nm DIR`, with `ENTER FROM SOUTH` when the rider is north of the approach.
- **Dock beacons.** Thin 140 m tapered beams (`MakeDockBeacons` / `TickBeacons`, `trace_glow` at energy 1.3). The amber beam stands over the far dock after 3 links until the rider docks or enters the lobby. The green beam stands over the near dock during the return chase.
- **Lift crash naming.** Hitting `DeepLiftLobby` walls used to report `UNKNOWN`. It now reports reason `lift`, with the advice "deep-lift building - park in the FAR dock, then walk". The dock is entered from the south, at about z=-102, heading north.
- **Sky depth and bloom.** `trace_sky.gdshader` now has four star layers: rare 4× HDR stars that bloom, two mid layers with warm/cool colour, and a dust layer packed into the nebula band. Star radius scales with layer density so dense layers do not go sub-pixel. A 700-star `StarField` MultiMesh at 220–900 m adds parallax. Glow: intensity 1.5, strength 1.3, bloom 0.1, HDR threshold 0.95, levels 5–6 on. Trail energy is 3.6.
- **No pale floor at the horizon.** `abyss_floor.gdshader` is now `fog_disabled` and fades into the sky's below-horizon colour from 700 to 2600 m. The pink sheet seen looking north was specular sheen on `FarLand` from the pink rim light. Both banks now use a matte `bank_rock` material (roughness 1, metallic 0). Storm flashes tint the fog at 0.15 instead of 0.35.
- **Visuals.** `trace_sky.gdshader` adds stars, a nebula band, and pale and amber moons. Environment glow and depth/height fog are on, and trails use HDR materials so they bloom. `AbyssFloor` (Y=-460, `abyss_floor.gdshader`) shows distant land with glowing canyon rivers and city lights. Three `AbyssFlash` omni lights flicker storm light into the fog. The project uses the `gl_compatibility` renderer, so there is no volumetric fog.
- **Cursor follow-ups:** a shutdown and trace-off sound or flash; enemy AI awareness of the trace-off state; a performance pass on low-end GPUs.

## October 26: Trace-On relay handshake

Relays are no longer a solid pylon next to a capture ring. In this design, the
rider earns the link by entering the lane.

- Art (`relay_pylon`): a flush `HandshakePad` with a cyan `PadRing`. `Mast`
  (Foot, `BaseCollision`, Column, `ColumnCollision`, seams, Crown, StatusLamp)
  sinks into `MastWell`. The `Lane` group has cyan rails at x=±1.8 and amber
  chevrons along local Z on both sides. `LinkSocket` sits at the pad centre.
  route.json adds `relay_capture_radius` 2.0, `relay_lane_half_width` 1.8 and
  `relay_lane_axis` "local Z".
- Rules (`trace_cycle_test.vg`):
  - Only the next relay arms, and only while `InRelayLane(i)` is true. The
    rider must be within ±1.8 m laterally and within 30 m along the lane, with
    heading parallel to the lane and approaching the pad.
  - `UpdateRelayMasts` sinks the mast at 3.6 m/s, 4.7 m deep, and turns its
    collision off. The mast rises at half rate if the rider leaves the lane
    and moves more than 7 m away.
  - A captured mast stays down. `reset_run` raises all masts.
- Capture needs the relay armed and the rider within 2.0 m of the pad.
- The HUD shows `LINK n ... USE LANE` within 45 m, `TRACE ON  HOLD LANE Xm`
  while armed, and `TRACE ON  LINK n OK` for 1.6 s after capture.
- The tactical map draws each relay as a lane strip.
- A crash into any `Relay*` collider now reports `pylon`, not `unknown`.
- Tests: TRACE_CYCLE 141/141 (goal clarity: objective text, far beacon, enter-from-south hint, lift crash name, starfield; new lane-handshake, max-speed link, retry,
  cross-lane pylon-crash and out-of-order checks). TRACE_MODELS 146/146.
  TRACE_ROUTE 64/64.
- Evidence: `build/ash_meridian/trace-on-handshake-approach.png` and
  `trace-on-handshake-linked.png`.

Cursor follow-ups:
1. Keep the remote AI cycle out of relay lanes, or treat raised masts as
   hazards in its steering.
2. Add capture feedback: a chime, a pad-ring flash and a brief windscreen
   pulse on `trace_on_t`.
3. Optional: a lane-entry tick sound when the relay arms.

Do not create or edit models. Request art changes from the assistant.

## October 26 layout: bottom instrument cluster

The two dashboard screens no longer float across the top of the view. They are one bike instrument cluster at the bottom centre: `MakeClusterHousing()` draws the dash body, `ext_frame` is at (186, 372) and `map_frame` is at (488, 372), each 286 x 160 on the 960 x 540 canvas, with `EXTERNAL` / `TACTICAL` titles. `MAP_W` / `MAP_H` are now 262 / 136. The top two thirds of the screen are clear for riding, and part1's FPS overlay no longer covers the map.

In the art, the windscreen is raised so the HUD sits at eye level. The grips are moved out to the lower screen corners, outside the cluster, and the side cowls are now slim fairing edges. Keep this layout. Do not move the screens back to the top. The exterior chase camera is closer (6.4 m back, 2.3 m up), so the cycle reads on the small screen. Evidence: `build/ash_meridian/bike-cockpit-cluster.png`. TRACE_MODELS=146/146, TRACE_CYCLE=109/109, TRACE_ROUTE=64/64.

## October 25 evening fix: mirrored yaw, bike cockpit and map heading

This section takes precedence over the corrective handover below for the four
items it covers. The user reported: no windscreen/HUD, a blue block after a
right turn, crashes into invisible objects and a map line ahead of the cycle.

**Root cause of the turn defects (fixed):** `trace_cycle_test.vg` moved along
`ForwardOf(h) = (sin h, 0, -cos h)` but set `rotation.y = h`, which in Godot
faces `(-sin h, 0, -cos h)`. Straight runs at 0/180 degrees matched; after any
90-degree turn the model, hull collision, emitter and cockpit camera faced the
opposite way from travel. The 4.1 m hull swept sideways into fresh trail/relay
geometry (UNKNOWN crashes), the rear emitter sat beside the camera (cyan
block), and the map trail ran ahead of the marker. All seven player/remote
yaw writes now use `0.0 - heading`. `HeadingOf()` now derives forward with
`to_global(Vector3(0, 0, -1))`, because VG's `basis.z` returns a Basis row,
not GDScript's column vector. Five regression checks fail on the old code and
pass now (`right_turn_*`, `left_turn_*`, `heading_of_round_trips_node_yaw`).
Real-frame capture: launch, right turn, two left turns, no crash or block.

**Bike cockpit (assistant art, wired):** `scenes/trace_cockpit.tscn` is
mounted under the cycle `CameraTarget` on render layer 3 (bitmask 4).
It includes a raked clear windscreen with a cyan-lit rim, a reticle/horizon
glass HUD with `HudSpeed`, `HudTrace` and `HudHint` Label3D anchors, a cowl,
a central binnacle, bars, grips and control pods. The ride camera uses
`1 + COCKPIT_LAYER`; the exterior/inspect/on-foot cameras use
`NO_COCKPIT_MASK`. `RefreshHud` writes the three glass labels. The full-width
dark dashboard backing is now transparent, so the binnacle shows between the
exterior display (left) and the tactical map (right).

**Map:** The 12 m heading ray has been replaced by a 9 px chevron on the
marker.

Evidence: `build/ash_meridian/bike-cockpit-right-turn.png`,
`bike-cockpit-multi-turn.png`.
Suites: TRACE_MODELS 146/146, TRACE_CYCLE 100/100, TRACE_ROUTE 64/64,
CAMPAIGN 61/61; generator `--check` is clean.

**Cursor still owns:**
1. A `MoveSwept` diagnostic that names the real collider instead of `unknown`.
   Keep it even though the root cause is fixed.
2. Showing binnacle content in 3D instead of the 2D strip, if wanted. Use the
   `ExteriorScreen` and `TacticalScreen` markers; do not create models.
3. A playtest pass over the remote cycle's turns, now that both cycles share
   the corrected yaw.

## October 25 corrective handover: latest playtest

This section takes precedence over earlier delivery status and acceptance
counts. The user reported an unknown collision, a cyan rectangle after turning,
an inverted/empty tactical display and an opaque floor. The subsequent request
clarifies that the abyss must have barely visible distant structures and haze,
not be pure black.

### Fixed in this assistant increment

- Removed the generated `SupportField` mesh and all world-space grid strips
  from `void_crossing.tscn`. The field is no longer a rendered solid platform.
  Its invisible `SupportCollision` remains at Y=0 on collision bit value 4,
  excluded from the cycle's obstacle mask 1 at the resource level. Do not
  restore the old mesh or mask it only in the cockpit: the monitor must also
  show the void.
- Added two cliff banks and small dock aprons, with open space between them.
  Near/far dock, relay, lift and spawn transforms remain unchanged. Nominal
  bank edges are Z=+100/-100 with irregular broken rock extending below.
- Added non-colliding `AbyssDepth` scenery: distant ruined structures well below
  the riding plane, subdued light details, and patchy shader haze at Y=-30,
  -54 and -78. There is no walkable rendered surface across the gap. Haze
  planes are translucent scenery deep below, not an opaque replacement floor.
  Shader source is `assets/trace_vault/abyss_haze.gdshader`; no new runtime
  script or renderer dependency was added.
- Fixed a concrete controller initialization bug: `EnsureWorld` called
  `MakeDashboard` and `MakeRelayGuides`, then reset `map_relays`, `map_docks`,
  `relay_rings` and `relay_nums` to empty arrays. Their nodes existed, but
  updates lost the handles; the `map_docks.size() >= 2` guard then skipped all
  relay/dock placement. Removed those four resets.
- Fixed `MapPoint`'s vertical projection. With fixed north/-Z up, outbound
  motion must travel from the near dock at the bottom toward the far dock
  at the top. Y projection is now `(world_z + 120) * MAP_H / 240 - 3`, not
  `(120 - world_z) * MAP_H / 240 - 3`. This is a screen-space reversal, not
  a request to mirror the world or view it from below.

Verification: `TRACE_MODELS=135/135`, `TRACE_CYCLE=84/84`,
`TRACE_ROUTE=64/64`, `CAMPAIGN_RESULT=61/61`; deterministic generator `--check`
passes. The route suite still emits its existing six-object/three-resource
shutdown diagnostics. Rendered OpenGL review confirms distant ruins/haze,
open crossing and placed relay/dock markers:
[abyss overview](../../build/ash_meridian/void-depth-preview.png),
[actual outbound dashboard](../../build/ash_meridian/void-map-fixed.png).
The rendered view has not yet gained the pending authored cockpit shell.

### Cursor follow-up: do not call the remaining defects fixed

**P0: identify and fix the unknown collision.** Changing WALL to UNKNOWN
made the message honest but did not solve the player's stop. Reproduce with
real frames: launch, travel straight off the near bank, then single left/right
turns and a short zigzag at 32 and 64 m/s. Include returning toward an old trail.
Do not rely only on `Drive()` looping many `tick()` calls inside one process
frame: newly created/armed physics shapes need actual physics synchronization.
The passing 84 checks are not evidence that this reported collision is fixed.

The current `MoveSwept` casts a hull, then tries `intersect_shape` at the safe
fraction (which can correctly still be separated from the obstacle), followed
by a centre ray. Neither guarantees the collider that stopped the full hull.
Capture evidence from the actual swept body/shape collision; do not infer it
from an unrelated centre ray or proximity to a trail. Record start/end hull
transform, motion, safe/unsafe fractions, obstacle mask/excluded RIDs, collider
RID/path and collision point/normal when available. Test initial overlap after
turning separately. Preserve the physics contact point, not just the player's
centre, for tactical impact feedback. No blanket support/trail immunity and no
success-shaped fallback when a query fails.

**P0: trace the cyan rectangle after turning.** The supplied screenshot alone
does not prove which mesh it is. Inspect `DrawGrow`, `CommitTrail`, `last_emit`
and the rear-emitter transform across a snapped turn. Turning rotates the
offset emitter immediately while the old endpoint remains; verify that the
new segment does not bridge across the cockpit/hull or stretch between
unrelated positions. Record segment endpoints, node path, bounds and armed
state. Also check camera clipping/cull layers. Do not hide all cyan geometry
or disable old-trail collision: a genuinely dangerous wall ahead must remain
visible. Freeze/capture the failing frame in both forward and exterior views.
If a transient self-emission visual needs cockpit-only handling, distinguish
that immediate clearance segment from all committed dangerous walls.

**P1: finish the tactical display, not just its projection.**

- Keep the near dock at the bottom and far dock at the top on every retry.
  X remains left/right; player heading must agree with world movement.
- Add numbered relay symbols with capture regions and distinct completed/
  current/pending states; labelled near/far docks, deep-lift access, field
  boundary and the two land edges. Mark physical obstacles from the same scene,
  not a separate invented layout. Keep player/enemy heading indicators and
  an impact marker with a legend readable at 960x540.
- Render actual segment endpoints and the growing segment from gameplay
  data. Current `RefreshTactical` joins trail-body centres into one `Line2D`;
  this omits true ends and can draw fictional connecting diagonals. Store/
  expose real endpoints and separate disconnected paths. Do not merge trails
  across retries, actors or discontinuities.
- Instrument text must not cover the symbols. Verify all three relays and
  both docks are on-screen in the rendered monitor, not merely that their
  nodes exist. The retained-marker regression now protects initialization.

Preserve the shared-world external monitor, current campaign behavior, saves
and original models. Keep both dashboard views visible together. Do not
regenerate assistant art or put a large plane back at riding height. Deliver
rendered evidence of the previously failing turn and collision sequence,
relay acquisition and clean retry, plus real-frame physics regressions.
Request art corrections from the assistant if new scenery needs adjustment.

## October 25 revision: void crossing and cockpit dashboard

This user-requested revision supersedes the earlier third-person main-view
proposal and solid test-platform presentation. It applies to the existing
isolated destination, not a replacement controller or campaign integration.
The playable scene now exists; extend it and preserve its working behavior.
Previously recorded test counts describe the art delivery, not acceptance of
these new requirements.

### Main riding view and original cockpit art

**Latest reference clarification (October 25, 20:06): motorcycle, not spacecraft.**
The current first-person camera plus rectangular dashboard feeds is not the
requested finished cockpit. No Trace Cycle windscreen/handlebar/HUD surround
asset has been delivered yet. Do not reuse the Ash cockpit or call the current
bare camera view completed cockpit art.

The latest supplied image supersedes the earlier racing-car reference for
interior composition. Use an original compact bike arrangement:

- A curved, mostly clear windscreen with a slender graphite rim and restrained
  cyan edge lighting. The arch frames the forward view without a roof beam,
  thick car pillars, broad spacecraft canopy or opaque blue glass panel.
- Visible handlebars, grips and small control pods in the lower foreground.
  A compact central instrument binnacle shows speed, trace status and relay
  progress; the viewpoint must read as a seated rider behind the bars.
- A restrained windscreen HUD for the next relay's bearing/capture cue and
  urgent warnings. Functional HUD information is allowed; decorative letters,
  branding, copied text and windshield banners are not. Keep the centre clear
  and avoid opaque rectangles across the road/void sightline.
- The live exterior and flat tactical feeds are physical-looking dashboard
  instruments, visible together at all times while riding. The reference's
  stacked side displays are a composition reference, not an instruction to
  copy its UI, racing score, vehicle silhouettes or environment. The earlier
  left/right layout remains provisional: fit both screens to the bike's narrow
  cockpit without replacing it with a ship-width console.
- Rider hands/gloves may be a later assistant-authored addition; they are not
  delivered and must not block initial windscreen/handlebar integration.
  Do not introduce a rig or copied character art as a shortcut.

Assistant delivers the original windscreen/frame, bars and dashboard surround
with rider-eye, instrument and HUD anchors; Cursor wires live VG instruments
and existing feeds to that contract. Do not substitute generated cockpit
geometry from Cursor. Review the actual combined render before calling this
requirement complete. The bike reference does not change the approved open
void route into a solid neon racing track.

The primary riding view is **first-person inside the enclosed Trace Cycle**.
Use the latest motorcycle reference for the composition above; the earlier
racing-cockpit image is secondary. Author an original maintenance-cycle interior in Backlight's
graphite/cyan/amber visual language. Do not copy the reference vehicle's
geometry, logos, manufacturer lettering, windshield banner, racing HUD,
leaderboard, lap counter or other image assets.

- No decorative lettering, branding or decals on the canopy, windshield,
  cockpit shell or controls. Functional instrument text belongs inside the
  dashboard displays; keep the forward glass clear.
- Assistant owns the cockpit shell, dashboard surround, materials and authored
  camera/display anchors. Cursor must not make replacement cockpit models.
  Request missing art/anchors rather than guessing a camera position inside
  the opaque exterior canopy. No new cockpit model is delivered by this
  documentation revision.
- The interior needs clear forward visibility, modest peripheral framing and
  enough lower-dashboard space for both displays below. Do not simply place
  a first-person camera inside the existing exterior mesh and accept clipping.
  Hide the exterior shell only for the cockpit camera using render layers;
  retain the complete vehicle in the external monitor.
- Camera origin remains tied to the movement root, not the banking visual
  mesh. Keep horizon roll restrained; do not let camera lag point down the
  previous heading after a 90-degree turn. Any turn/shock effects are visual
  only and cannot change collision, input timing or relay capture.
- Cockpit is the default riding presentation, not a toggle. Docked model
  inspection remains separate and must not become necessary to see either
  dashboard view.

### Two simultaneous dashboard views

Both views below are built into the dashboard and visible **at the same time
as the forward cockpit view**. They are not selectable camera modes, tabs,
full-screen overlays or alternating feeds.

1. **Live exterior monitor:** a rear-quarter/elevated chase view showing the
   actual player cycle, its immediate surroundings, trail and turns, similar
   in purpose to the Ash flight-deck monitor. It must show motion in the real
   scene, not a prerecorded loop or static model thumbnail.
2. **Flat tactical display:** an abstract top-down schematic inspired by the
   supplied flat-grid reference. Draw a dark background, subtle reference
   grid, direction-marked player and enemy icons, their distinct colored
   trails, numbered relays, current target and both docks. The schematic grid
   is an instrument aid, **not a physical floor in the world**. Keep a fixed
   orientation with a direction indicator so sharp turns stay understandable.
   Distinguish completed/current/pending relays and show the next target's
   distance and capture region. Include the whole bounded field, with readable
   symbols at the game's default 960x540 canvas.

Proposed layout: exterior feed in the lower-left dashboard, tactical display
in the lower-right, speed/trace status and relay progress in the central
instrument strip. Keep forward sightlines clear. Do not reproduce the large
opaque debug panel across the upper windshield; verbose diagnostics belong
behind an explicit debug setting, with a compact actionable crash message.

The tactical display reads the same player/enemy positions, relay state and
committed/growing trail data as collision and gameplay. Never simulate a
separate map state or remove still-dangerous walls from the map. Before enemy
activation show no phantom enemy; after a crash retain the impact location.

Cursor should inspect the existing `landing_deck.vg` and presentation viewport
setup for prior art. Use a shared-world SubViewport for the external feed,
with its own camera; do not duplicate the physics world. Maintain one current
camera **per viewport**, not one camera globally. Render cockpit-only art
only in the main view; exclude the dashboard/UI from the exterior feed to
avoid recursive screens. Prefer VG 2D drawing for the tactical display rather
than a third full 3D render. Cache static panel/grid artwork and update moving
symbols independently. Pause freezes gameplay and instrument state; a paused
inspection camera is not permission to advance the simulation.

### Void scenery, relay guidance and crash truthfulness

- Assistant revises the art to show land ending at the near dock, a far
  landing and empty space below the crossing. No opaque continuous floor
  across the void. An invisible support plane may remain as a physics aid;
  it must not be presented as land. Docks and relays need visible structural
  support/field cues and clear playable limits.
- Cursor must not globally hide every floor or disable collisions by name:
  preserve walkable dock/lobby/vault surfaces. Coordinate scene contracts
  with the assistant's art revision. The current `SupportField` test-platform
  mesh is not an approved final void environment.
- Relays are proximity links, not targets to ram. Show a non-solid capture
  ring, ordered number, next-target bearing/distance and a brief confirmation
  when linked. The current implementation samples the cycle centre within
  3.5 m of the next `LinkSocket`; validate swept capture at maximum speed so
  passing through a capture region between frames does not miss it. Capture
  and marker art must agree about the socket's world position and radius.
- Retain the actual collider node path, impact point and collision category.
  Do not turn an unidentified sweep hit into a confident "WALL" diagnosis.
  Show an honest unknown-obstacle message if identification fails, retain the
  diagnostic evidence and mark the impact on the tactical display. Reproduce
  the reported straight-line crash before claiming it fixed; do not suppress
  valid wall/trail collisions to make the symptom disappear.

### Ownership, order and acceptance

1. Assistant supplies original cockpit/display framing with documented
   camera/render-layer/anchor contracts; that cockpit art is still pending.
   The cliff/abyss/haze revision is now delivered as described in the latest
   corrective handover above.
2. Cursor diagnoses the existing crash and implements relay guidance, swept
   capture, shared dashboard state and viewport plumbing in VG. Reuse the
   working isolated scene; keep Play/Continue and saves untouched.
3. Integrate assistant art, then deliver a runnable F6/dev-destination scene.
   Do not present placeholder cockpit geometry as final assistant-authored art.

Acceptance must include a rendered capture showing forward cockpit view,
live exterior feed and flat tactical display simultaneously; no decorative
cockpit letters, opaque void floor or clipped canopy. Show that both displays
track turns, relay capture, trail growth, crash, pause and retry correctly.
Verify exterior visibility despite cockpit-only shell hiding, no recursive
monitor output, correct cameras in F6 and the host viewport, and cleanup on
repeated entry/exit. Measure actual frame times/draw calls with the monitor
enabled during active trails and pursuit; report hardware, resolution and
renderer rather than claiming performance from an empty-scene test.

## Proposed gameplay defaults for review

These close open questions for the first prototype; they are not user-approved
balance or an instruction to change the released campaign without review.

- First-person cockpit with simultaneous exterior and flat tactical dashboard
  displays, as specified above. A/D or Left/Right requests a 90-degree
  heading change; W/S changes speed. No free steering or jumping.
- Proposed speed 24-64 m/s, starting at 32 m/s. Heading snaps exactly, while
  only `VisualRoot` banks briefly. Do not rotate collision gradually into walls.
- Buffer a single turn briefly; reject repeated held-key turns. Tune spacing
  to the cycle's length and swept collision, not frame count.
- Tall collidable walls remain until the crossing ends or a retry resets it.
  Both the player's and enemy's older walls are dangerous to both actors.
  Only the immediate uncommitted rear segment has clearance; no global
  immunity to an entire self-owned trail.
- Merge collinear travel into one growing segment. Append a segment at turns,
  not every frame. Use bounded spatial queries and chunked drawing. Do not
  silently delete older collidable walls to meet a rendering budget.
- Clearly mark support-field boundaries. A boundary breach crashes with a
  short explanation and retry, not an invisible soft lock or endless falling.
- Dock entry requires the correct approach direction and a clear approach.
  Disable new trail emission, run the short parking transition, then enable
  dismount. Re-entry cannot trigger duplicate dock rewards/state transitions.
- First checkpoint: near cradle before outbound. Second: vault before pickup.
  Third: far dock after escaping lockdown. Chase retries do not replay the
  vault or restore a consumed timer.
- One remote enemy initially. Telegraph activation; use a readable interception
  route, not perfect prediction or teleporting turns. It obeys the same bounds,
  turns and walls. Always preserve at least one escape opportunity.

## Cursor implementation order and acceptance

### Immediate handoff: playable model-test scene

Original October 24 milestone, now implemented in the isolated prototype.
The October 25 cockpit/void revision above takes precedence over its camera
and presentation wording. Preserve existing work; do not recreate this scene.
Do not start campaign version 2.

Create `trace_cycle_test.tscn` with a VG controller `trace_cycle_test.vg` in the
game root. It must run directly with Godot's **Run Current Scene (F6)** and
also be reachable through a **TRACE CYCLE** development destination using the
existing destination/return conventions. Keep normal Play and Continue on
their current campaign route.

Use the delivered `void_crossing.tscn`, not a replacement arena. Instance
`trace_cycle.tscn` at `NearCradle/DockPose` using its world transform.
Keep `trace_route.vg` as the isolated route/state authority; do not create
another campaign/save schema. The test scene must never load, overwrite or
delete the player's campaign save.

First runnable acceptance:

1. Start safely docked with a readable control overlay and the cycle visible.
   E boards/launches after a brief instruction; W/S adjusts speed, A/D requests
   deliberate 90-degree turns. Display current speed, riding/docked/crashed
   state and relay progress. These are scene-local controls; preserve the
   game's existing pause and development-destination return conventions.
2. Use the October 25 cockpit presentation; the elevated follow camera belongs
   in the live dashboard monitor, not the main view. Rotate wheel pivots from actual distance
   travelled; bank only `VisualRoot`. Show canopy opening when parked and
   closing before launch. Do not move the hull proxy or emitter when banking.
3. Implement maximum-speed swept collision, visible support boundaries,
   persistent self-trails and a clear crash/retry response. R retries the
   isolated run, clearing old trails, buffered input, speed and relay state.
   The cycle must not fall forever, cross a thin wall between frames or crash
   immediately into its newly emitted rear segment.
4. Support the quiet outbound relay order from `route.json`, then approach and
   dock at the far cradle. Stop emission before parking/dismount. Reset/retry
   must also work after docking. Do not activate an enemy on this first pass.
5. Provide a clearly labelled **Model inspection** mode while docked: orbit/
   zoom around the cycle, then inspect the red remote cycle and the assembled
   `vault_preview.tscn` without starting the campaign, facility timer or chase.
   Controls must be shown on screen. Inspection pauses riding; returning
   restores the same safe dock. Keep exactly one current camera per viewport.
6. Use the original art unchanged. Report clipping, orientation, unreadable
   lighting, bad attachment points or model proportions to the assistant.
   Do not replace the models with boxes or make new models/material variants.
   Preview lighting may be reused, but static preview cameras must not
   override the active ride/inspection camera.
7. Add VG tests for boarding/docking/retry, pause, edge-triggered turns,
   30/60/120 Hz movement consistency, maximum-speed thin-wall/boundary sweeps,
   old-self-trail collision versus rear clearance, and repeated scene cleanup.
   Rerun model, route and campaign regressions. Report failures and process-exit
   leak diagnostics explicitly; exit code alone is not sufficient evidence.

Deliver the runnable scene, the development destination and a short list of
controls/test results. The user will review models in that working scene.
Full enemy pursuit, facility gameplay, final effects/audio, authored local
lift rooms and campaign migration are subsequent increments, not prerequisites
for this model-test milestone. Do not label the test scene a completed chase.

1. Inspect current yard/lift/campaign code and report concrete wiring points.
   Add stage/state tests first. Keep existing Play behavior until an explicit
   development destination or feature setting selects this unfinished route.
2. After model delivery, build an isolated TRACE CYCLE dev destination:
   boarding, turns, movement, trails, crashes, docking and repeatable retry.
3. Add quiet outbound relay progression and the separate far lift.
4. Wire the vault using the existing pickup/interlock logic; add authored
   awakening transforms and the facility-only timer boundary.
5. Add isolated return-chase checkpoint and enemy logic, then campaign
   integration and save migration.

Required automated VG checks:

- No deep-lift bypass from the local yard lift; five-symbol activation is
  ordered and cannot be completed through partial/incorrect entry.
- Equivalent turns/distances at 30/60/120 Hz; collision sweep at maximum speed
  crosses neither a thin wall nor an arena boundary between frames.
- Rear clearance does not kill a freshly boarded rider; returning across an
  older self-wall does. Enemy walls and own walls follow identical rules.
- Pause freezes movement, enemies, trails, timer and audio. Held input does not
  issue repeated turns. Docks stop emission before dismount.
- Every retry clears old trails/enemies/input state and restores the correct
  stage, inventory and timer. Repeated entry/exit frees owned nodes/resources.
- Coupler pickup is idempotent; cores and coupler are distinct; protected
  reserve cannot be sold. Timer starts only at the interlock transition and
  stops at the facility boundary, not at an arbitrary scene timer.
- Return-cycle destruction leaves the physical FEB alive. Escape without a
  kill succeeds. No first-visit EMP or premature Rob dialogue.
- Save versions, exact validated fields and migration are explicit; no silent
  reset. Test the confirmed checkpoint-only riding save policy and refusal cases.
- Frame-time and draw-call measurements include active trails and pursuit, not
  an empty arena. Report actual hardware, renderer and p95 timing.
- Fixed spoken instructions have matched captions/recordings, do not stall
  gameplay waiting for synthesis, and precede the required player action.

## Copyable Cursor prompt

```text
Read docs/development/ASH_MERIDIAN_TRACE_VAULT_HANDOFF.md and the newer unified
campaign draft. Read "October 25 evening fix" first: the mirrored-yaw root
cause, the bike cockpit and the map chevron are done; do not revert them.
Then follow "October 25 corrective handover: latest playtest".
The assistant removed the visible floor/grid, added cliff banks plus distant
ruins/haze, retained invisible layer-4 support, fixed the bottom-to-top map
projection and removed array resets that erased relay/dock/guide handles.
Do not undo those changes. Diagnose/fix UNKNOWN collisions and the cyan turn
rectangle using real-frame physics evidence, not just a renamed message.
Finish the tactical display with labelled relays/capture regions, docks/lift,
boundaries, true trail endpoints and heading/impact symbols. The handoff gives
concrete code findings and acceptance requirements. 84 passing controller
checks do not prove the reported collision/artifact fixed.
Then follow "October 25 revision: void crossing and cockpit dashboard";
it supersedes the third-person main view and opaque test-platform floor.
Extend the existing isolated scene; do not rebuild it or alter Play/saves.
Main riding view is an original unbranded cockpit. A live exterior feed AND a
flat top-down tactical view are simultaneously visible inside the dashboard,
not optional modes. No decorative letters/logos on the cockpit or windshield.
Assistant owns cockpit/void art and anchors; void art is revised, cockpit art
is still pending.
Do not create replacement models. Implement VG dashboard/viewport plumbing,
relay guidance and swept capture, and diagnose the straight-line crash with
actual collider/impact evidence. Preserve one current camera per viewport.
Integrate assistant art when supplied and verify the three views together.
The following describes the earlier milestone; preserve its working features:
The user wants to inspect the supplied models in a working scene, not another
plan or static gallery. Deliver trace_cycle_test.tscn + trace_cycle_test.vg,
runnable with F6 and an isolated TRACE CYCLE development destination. Include
boarding, ride camera, wheel/canopy articulation, crisp turns, speed controls,
swept collision, persistent self-trails, crash/retry, outbound relays and
far-dock parking. Add a docked model-inspection mode for the player cycle,
red remote variant and assembled vault/FEB. Display all controls.
No enemy chase or campaign-v2 wiring in this first bounded delivery.
The first script-free model kit is delivered under
samples/games/ash_meridian_part1/assets/trace_vault/scenes. Inspect manifest.json,
route.json, the four previews and test_trace_models.vg. Keep trace_route.vg's
existing stage/save contract and the campaign's current version-1 Play route.
Do not touch the campaign save from this test scene. After the user reviews
the playable model-test scene, continue with the separate far lift, vault and
return chase as reviewed follow-up increments.
Use VisualRoot/... paths for the wheel/canopy/FEB pivots. Apply marker world
transforms, including rotations, when assembling docks and vault props.
The assistant owns models, materials, art revisions and route art. Do not make,
replace or regenerate those assets. Report art problems for assistant fixes.
Implement controls, trails/collision, AI, interactions, checkpoints/save
migration and tests in VG, with no new GDScript. Keep unfinished work isolated
behind a dev destination or explicit feature setting. Preserve existing game
behavior, voice work, saves and unrelated edits. Do not commit/push or launch
other agents without instruction. Report tests and any decisions needed.
```

## Tron lobby, lift controls, human FEB and stasis capsule

Art (assistant):
- `assets/trace_vault/trace_panel.gdshader`: a world-space triplanar grid with
  a glossy black base and antialiased cyan lines. The materials `trace_floor`
  and `trace_wall` use it on the deep-lift lobby and on both dock aprons.
- `deep_lift_lobby`:
  - a white portal frame, a ShaftHead tower with an amber chevron, and cyan
    outline edges;
  - a lit cabin with a deck ring, handrails, pocketed doors and a ceiling light;
  - a `Cabin/ControlPanel`: screen "LEVEL -04", 4x2 floor buttons with -04 lit,
    a Stop button and a key slot;
  - indicators outside ("v -04") and inside ("ISOLATION 04"), plus a call panel.
  - Collision is unchanged at 7.
- FEB: a human in a Tron suit (see above). Greg keeps the robot.
- `stasis_cradle`:
  - a glass capsule with two hinged front lids and a white crack seam;
  - three idle fog emitters;
  - the clamps are shortened.
  - Collision is unchanged at 5.

Controller (`trace_cycle_test.vg`):
- `take_coupler` starts the pod sequence instead of posing the FEB at once.
- `TickPod` drives `PosePod(t)`:
  - clamps retract at 0–0.7 s;
  - the seam flickers from 0.5 s and holds from 1.4 s;
  - fog runs from 1.0 to 9.0 s;
  - the lids crack 0.14 rad at 1.2–2.6 s, then swing 1.6 rad by 6.0 s;
  - the FEB stirs at 3–5 s.
- `RestoreVaultProps` reseals the pod.

Cursor rules:
- Do not add collision to `Capsule/*`.
- Drive the lids only through `PosePod`.
- Fog must stay CPUParticles3D, which keeps compatibility rendering cheap.

Tests: TRACE_MODELS=178/178, TRACE_CYCLE=181/181, TRACE_ROUTE=64/64.

Evidence in `build/ash_meridian/`: `lobby-trace-exterior.png`,
`lift-interior-controls.png`, `feb-sealed-pod.png`, `pod-cracking-fog.png`,
`pod-open-fog.png`.

## October 27 direction: Trace Cycle moves into the Backlight yard

User direction: the Trace Cycle is part of the Backlight yard. At the end of the road, the player sees the cycle parked. Taking it lets the rider leave the yard and ride out over the void on every side.

The cycle has a decent but limited **charge**. Charge powers containment, so if it runs out, the cycle explodes. This bounds the exploration area and leaves room for more docks later. The old 160 x 240 m crossing is too small and is replaced by a large open field around the yard. The rider needs tools to find relays and docks.

Status: these are proposed defaults. The user may retune them. Play stays on campaign version 1, and the isolated contract above still applies.

### World frame

All new coordinates are in Backlight yard space: +Z north, Y=0 deck. This replaces the crossing's local frame for the new field.

| Item | Position (x, z) | Notes |
|---|---|---|
| Yard deck | x -118..118, z -12..420 | Existing. The landing pad is at the south end; the road runs north along x=0. |
| Lift head | x -4..4, z 398..406 | Existing; the end of the road. |
| **Yard dock** (`yard_dock`) | (14, 414), exit heading +Z | Beside the lift head. The parked cycle is visible from the road. The apron overhangs the yard edge. |
| Vault relays (ordered chain) | R0 (40, 520), R1 (180, 640), R2 (300, 760) | The existing Trace-On handshake, in order. They unlock the vault dock. |
| **Vault dock** (`vault`) | (360, 860) | The FEB vault and deep lift. It is the old far dock and vault merged. |
| Free relays (recharge only) | West (-420, 200), South (0, -360), East (520, 120) | Unordered. They let the rider explore the far side of the yard. |
| Future dock slots | West (-640, 210), South (0, -480) | Empty markers only. Authored later. |
| Field boundary | x -760..760, z -560..980 | A hard containment edge, kept as a safety net. Charge should end most trips first. |

- **Yard rim:** a lit 1.2 m containment rail runs around the yard perimeter, with a gate at the yard dock only.
  - Hitting the rail crashes with the reason `yard rim`.
  - The cycle never drives onto the walking deck.

### Charge and containment

- Capacity is 100.
- Drain per second while riding is `0.6 + speed^2 / 1800`: 0.92 at 24 m/s, 1.49 at 40 m/s and 2.88 at 64 m/s. Trace ON adds 0.25 per second.
  - That gives about 2.5 km at cruise speed. The yard-to-vault route is about 600 m and costs about 25 charge.
  - A full lap around the yard needs at least one free relay.
- **Relay capture** (the existing lane handshake) adds 40, up to the cap of 100.
  - The relay is then spent for 45 s: its lamp dims and its beacon shrinks. This blocks charge farming on loops.
- **Docking** refills to 100 over 2 s while parked.
- **Warning thresholds:**
  - **30, LOW:** amber containment bar and a chime.
  - **15, CRITICAL:** red bar, flickering HUD, sputtering trail, and top speed capped at 40.
- **At 0, containment failure:**
  - A 2.5 s countdown runs, with glitching cockpit lines and the text `CONTAINMENT FAILURE`.
  - Reaching a dock or capturing a relay inside that window saves the cycle.
  - Otherwise the cycle explodes. Reuse `cycle_breakup.gdshader` with the crash reason `containment`.
- **After an explosion:** the rider respawns at the last safe dock with full charge (this matches the checkpoint-only rule).
  - Trails clear.
  - Vault-chain order resets the same way a crash retry does now.
- **Range readout:** the HUD shows `RANGE n m`, computed as charge ÷ drain at the current speed × speed.
  - When the nearest dock or available relay is more than 90% of that range away, show `NO RETURN`.

### Finding relays and docks

The commands are named after BASIC, in the same spirit as the Trace-On cycle.

1. **Beacon columns.**
   - Every dock and relay has a tall light column, visible within 600 m.
   - Colours: cyan for an available relay, dim for a spent relay, white for a dock, amber for the vault once unlocked.
   - Beyond 600 m, items show only after discovery.
2. **`LIST` scan (Q).**
   - Sends a ping ring with a 900 m radius and costs 4 charge.
   - Every relay and dock inside the ring becomes permanently discovered on the map.
   - Items also self-discover within 250 m.
3. **Flat view becomes the field radar.**
   - The view covers a 400 m radius around the cycle and keeps the current heading behaviour.
   - It draws the yard outline and rim gate, discovered relays and docks, and the current `RANGE` circle.
   - Off-screen discovered items show as edge chevrons with distance.
4. **`GOTO` target (Tab).**
   - Cycles the windscreen target between the next vault relay, the nearest dock and the nearest available relay. The HUD reads, for example, `GOTO LINK 2  184 m`.
   - A compass ribbon at the top of the windscreen carries the target mark.
5. **`RETURN` override.**
   - At LOW charge, the target switches automatically to the nearest reachable charge source.
   - If that source is the yard dock, the HUD reads `RETURN YARD  m`.

### Ownership and order

**A. Assistant art kit (next).** Add to `build_trace_vault.mjs`:
- `yard_dock` (apron, cradle and gate) and `relay_beacon` (a cheap additive column plus a ground ring);
- `yard_rim` rail segments;
- a low-poly `yard_proxy` silhouette for the isolated dest;
- empty dock-slot markers;
- `yard_void_field.tscn`, laid out with the table above, with the abyss and haze scaled to the field;
- `route.json` gains a `yard_field` section (version 2 of the art contract only, not the campaign).

Cursor must not create models.

**B. Cursor, isolated dest `TRACE YARD`.** The existing crossing dest stays as it is. Use the new field, then add:
- charge, containment and explosion, as above;
- `LIST`, `GOTO` and `RETURN`;
- the radar map, beacons and rim crash;
- yard-dock checkpoint saves. The dock names become `yard_dock` and `vault`. The old `near_cradle` reads as `yard_dock`, and the old `far_dock` reads as `vault`.

Tests to add:
- drain rate at 24, 40 and 64 m/s;
- relay +40 and the spent cooldown;
- dock refill;
- LOW and CRITICAL thresholds and the speed cap;
- containment failure saved by a relay inside the window;
- explosion respawn at the last dock;
- LIST reveals only items within 900 m and charges 4;
- the GOTO cycle order;
- RETURN switching at LOW;
- the rim crash name;
- boundary crash.

**C. Later, needs user approval.** Merge into the real Backlight yard:
- the parked cycle at the end of the road;
- E boards the cycle, and the yard's walking controller hands over the camera.

This needs campaign version 2 and an explicit `trace_route` section. Do not start it from this note.

Keep the return chase: the security cycle spawns at the vault dock on departure. The enemy ignores charge.

Performance: the field is about 1.5 x 1.5 km.
- Keep collinear trail merging and chunked drawing.
- Beacons are unshaded additive meshes with no lights.
- Trace OFF still clears trails.

### Art kit delivered (phase A)

All scenes are generated by `tools/build_trace_vault.mjs` into `assets/trace_vault/scenes/`. The machine-readable layout is [`yard_field.json`](../../samples/games/ash_meridian_part1/assets/trace_vault/yard_field.json) (art contract version 2). The old `route.json` and the existing crossing dest are unchanged.

| Scene | Contents | Collision |
|---|---|---|
| `relay_beacon` | `Beam` (160 m additive cone), `Halo`, `GroundRing`, `Top` | None |
| `yard_dock` | Origin is `DockPose`; the void lies on local +Z. Contains `Apron`, a `Cradle` rotated 180°, gate posts, `GateBeam`, a "TRACE DOCK" label, amber out-chevrons, a `RoadSign` reading "TRACE CYCLE >" and `ChargeTotem`/`ChargeBar`. Markers: `DockPose`, `BoardPoint`, `GatePose`, `ChargeDisplay`. | Only the cradle's 3 shapes |
| `yard_proxy` | A low-poly silhouette of `backlight_yard.vg`: deck at y 0, towers, press halls, silos, gate arches, road lines, `LiftHead` | None |
| `yard_void_field` | The full field in yard coordinates (see the table below) | Support, rim and boundary |
| `yard_field_preview` | The field, with a cycle parked at the yard dock and a high camera | — |

`yard_void_field` node contract:

- **`SupportCollision`**
  - The invisible ride surface: 1520 x 0.2 x 1540, on **layer 4**, centred at (0, -0.1, 210).
  - Keep the cycle's ground ray on layer 4. Every layer-1 body counts as an obstacle.
  - Visually there is no floor: only the abyss, at 9000 m.
- **`YardRim`**
  - Holds the segments `RimSouth`, `RimWest`, `RimEast`, `RimNorthWest` and `RimNorthEast`.
  - Each has a `*Collision` body on layer 1. Report crashes whose name starts with `Rim` as `yard rim`.
  - The only gap is the dock gate, at x 7..23 on z 420.
- **`YardDock`**
  - At (15, 0, 414), with `YardDockBeacon`.
- **Vault**
  - `VaultCradle` sits at (360, 0, 860), unrotated, so you approach heading +Z.
  - `DeepLiftLobby` and the `VaultLift` marker are at (375, 0, 862.8). The `VaultBeacon` sits beside them.
- **Relays**
  - `Relay0`, `Relay1` and `Relay2` form the ordered vault chain.
  - `RelayWest`, `RelaySouth` and `RelayEast` are free recharge relays.
  - Each has a `<name>Beacon` child plus `Suspension` and `Anchor` nodes.
  - Lane rotation is 0 or 90, so lanes stay world-axis aligned because turns snap to 90°.
- **Future dock slots**
  - `DockSlotWest` and `DockSlotSouth` are markers only.
- **Boundary rails**
  - Four rails run along x ±760 and z -560..980.
  - The rail nodes are `BoundaryX-1`, `BoundaryX1`, `BoundaryZ-1` and `BoundaryZ1`.
  - Their collision bodies are `BoundaryXCollision±1` and `BoundaryZCollision±1`.
  - Report a crash whose name starts with `Boundary` as `field boundary`.
- **Spawn markers**
  - `PlayerSpawn` (heading +Z out of the gate), `BoardPoint` and `SecuritySpawn`.

**Beacon states.** Set `material_override` on both `Beam` and `Halo`:

| State | Material |
|---|---|
| Available | `beacon_cyan` |
| Spent | `beacon_dim` |
| Dock | `beacon_white` |
| Vault unlocked | `beacon_amber` |

Beacons are additive and unshaded, with no lights. Hide them until discovered beyond 600 m.

Review frames are in `build/ash_meridian/`:

- `yard-field-overview.png`
- `yard-road-end-dock.png`
- `yard-void-ride-view.png`
- `yard-from-void.png`

Tests: TRACE_MODELS=246/246, TRACE_CYCLE=181/181, TRACE_ROUTE=64/64.

### Copyable Cursor prompt (phase B)

> Build the isolated dest `TRACE YARD` in `samples/games/ash_meridian_part1`. Do not change Play, the `TRACE CYCLE` dest, the campaign save version or any model. Load `assets/trace_vault/scenes/yard_void_field.tscn` and read every coordinate and tuning value from `assets/trace_vault/yard_field.json`; do not hard-code them. Spawn the cycle at `PlayerSpawn` inside `YardDock`. Reuse the existing `trace_cycle_test.vg` controller, cockpit, dashboard views, Trace-On relay handshake and trace toggle.
>
> Add:
> - charge, with the drain, relay +40 and 45 s spent state, dock refill, LOW/CRITICAL thresholds, the 40 m/s cap, the 2.5 s containment-failure window, an explosion that reuses `cycle_breakup.gdshader` with reason `containment`, and respawn at the last dock;
> - `RANGE` and `NO RETURN` readouts;
> - `LIST` on Q: a 900 m scan that costs 4 charge;
> - self-discovery within 250 m;
> - the 400 m radar in the flat view, with the yard outline, gate, discovered items, range circle and edge chevrons;
> - `GOTO` on Tab;
> - `RETURN` switching automatically at LOW;
> - beacon material states;
> - crash reasons `yard rim` and `field boundary`;
> - checkpoint-only saves with docks named `yard_dock` and `vault`. Legacy `near_cradle` maps to `yard_dock`, and `far_dock` to `vault`.
>
> Keep the security chase spawning at the vault on departure. The enemy ignores charge.
>
> Add a `test_trace_yard.vg` suite covering every item in the phase B test list above. Keep `TRACE_MODELS`, `TRACE_CYCLE` and `TRACE_ROUTE` passing.

## October 27 direction: Interface Translator

User direction: Narcean is not English. The player must find an **Interface Translator** before they can read displays, lifts and signs. It does not translate everything: harder text waits for the FEB later. Example: before the Trace Cycle can be ridden, the player enters a release code they have found, and that code cannot be read until it is translated. For testing, the translator starts in the player's possession.

Status: these are proposed rules and the user may change them. Play stays on campaign version 1 and is not wired yet.

### Three kinds of Narcean text

| Kind | Examples | Without translator | With translator | Later, FEB (Rob) |
|---|---|---|---|---|
| **Numeral glyphs** | Keypad buttons, the lift address, floor codes | The existing 10 stroke glyphs. They can be shape-matched, so the lift puzzle still works. | Each glyph also shows a small digit gloss | — |
| **Interface script** | Control labels, status words, short signs, dock and relay names, spelled-out codes, cycle readouts | Stroke words only | An English gloss | — |
| **High script** | Directives, Commit text, Latch-era records, FEB and mast inscriptions, the mast serial | Stroke words only | Stroke words stay. A gloss bar reads `HIGH SCRIPT · NEEDS A READER`, and any interface words inside are glossed in brackets. | Full translation |

Rules:

- **Words, not cipher letters.** Interface and high script are drawn per word, not per letter.
  - Each word maps to a deterministic stroke cluster from a hash of the upper-case word.
  - The same word always looks the same, but the script cannot be decoded as a letter cipher.
  - Words share a top bar, so they never look like numeral glyphs.
- **Numbers in documents are spelled out.** Documents write numbers as interface-script words, for example `TWO SEVEN FOUR ONE` (dev code 2741). Keypads use the numeral glyphs.
  - So a code found on a tag cannot be shape-matched to the keypad: the translator is required.
  - This is what makes the cradle code unreadable until it is translated.
- **The translator is passive.** It glosses any Narcean text within 6 m in view, or any open panel. There is no new key; Q stays as the scan.
  - **Decode effect:** the strokes flicker for 0.4 s, then a cyan gloss line appears beneath them with a small translator mark.
- **Orac:** the translator is what gives Orac its "partial translations" (consistent with the approval draft).
  - First link line: *"Interface lexicon linked. I can read their labels. Their prose is beyond it."*
  - That line points the player toward the FEB.

### Trace Cycle release code

- The yard dock cradle (`yard_dock/Cradle`) gets a **release lock**: 4 numeral glyphs, entered on a glyph keypad.
  - The keypad behaves like the lift keypad: 0–9 select, Backspace erases, Enter confirms, F cancels.
  - Digit glosses appear only while the translator is held.
- The code is printed on a **service tag** in the yard, as an interface-script line: `CRADLE RELEASE · <four number words>`.
  - Without the translator, the HUD reads `NARCEAN SCRIPT`.
  - With it, the line reads `CRADLE RELEASE: TWO SEVEN FOUR ONE`. 2741 is a development placeholder; the controller reads it from `yard_field.json` `translation.cradle_code_dev`.
- The tag sits at the road-end lift head, facing the road, so it is found on the way to the cycle. **Proposed placement; open for the user.**
- **Wrong code:** the cradle stays clamped. A red flash appears, and the gloss line (when translated) reads `CLAMP HOLD`. Retries are unlimited.
- **Correct code:** the clamp opens and E boards the cycle. Remember the release per save so you never re-enter it.
- **Dev placeholder code:** `2741`, alongside the lift placeholders `11111`, `22222` and `33333`. Final digits wait for signage.

### Where the translator is found (open)

For testing it starts in the player's inventory (`inventory.translator`).

Proposed story placement: in the yard, before the road end, at a dead maintenance post near the landing pad. This is open for the user.

**Save rule:** store the translator as an inventory entry, like `regulator`, `ignition` and `coupler`. It must not add a new expedition save field: the 32-field set is unchanged. Store the cradle release flag in the isolated trace save until campaign version 2.

### Art (assistant)

Generator additions, none of which have been built yet:

- **Translator model** `interface_translator`:
  - a handheld or wrist slate in Narcean metal, with a cyan lens and a small stroke readout;
  - a pickup scene plus an equipped view model.
- **`narcean_sign` scene** with three children:
  - `Script`: stroke-word meshes generated by the same word-hash algorithm as the HUD;
  - `Gloss`: a Label3D in English, hidden by default;
  - metadata `text_kind` = `interface` or `high`.
- **Sign conversion:** existing art signs ("TRACE DOCK", "TRACE CYCLE >", lift and lobby labels) become `narcean_sign` instances.
- **Cradle additions:** a `ReleaseLock` keypad on the cradle and a `ServiceTag` sign at the lift head.
- **`yard_field.json`** gains a `translation` section: sign list, kinds, glosses, `cradle_code_dev` and the word-hash fixtures.
- **Word-hash spec:**
  - The hash is FNV-1a 32-bit over the upper-case ASCII word.
  - The word has `max(1, ceil(len/2))` cells. Cell `i` uses the 6-bit stroke pattern `(hash >> (i*5 % 27)) & 63`; a pattern of 0 is replaced by 42.
  - The cell paths are the same six as `glyph`, plus the shared top bar.
  - The fixtures list the patterns for `TRACE`, `DOCK`, `CRADLE`, `RELEASE` and `SEVEN`, so the VG HUD and the JavaScript generator are proved identical.

### Cursor (after the art kit)

In the isolated `TRACE YARD` dest:

- **HUD drawing:** add `narcean_word` and `narcean_line` to the HUD, implementing the word-hash spec.
- **Gloss logic:** show 3D sign `Gloss` nodes and HUD glosses only when `inventory.translator` is present and the text is in range or on an open panel. High script shows the `NEEDS A READER` bar.
- **Cockpit:** the cockpit HUD stays English (it is interface script read through the translator). It cannot be reached without the translator anyway, because the release code needs it.
- **Code lock:** the cradle release lock, service tag, wrong and right code behaviour, and the per-save release flag.
- **Dev flag:** `translator_start_owned` (default `true` in the dest).
- **Play is untouched:**
  - Play keeps its current lift-panel digit hints until campaign version 2.
  - When it is wired, those hints become translator-gated. The shape-matching lift puzzle still works without the translator.

Tests to add (`test_trace_yard.vg`):

- the word hash matches the fixtures;
- interface text is glossed only with the translator and only in range;
- high script is never glossed by the translator;
- keypad digit glosses are hidden without the translator;
- the tag is unreadable without the translator and reads the code with it;
- the cradle refuses a wrong code and releases on the right one;
- the release persists across a checkpoint save;
- the translator adds no expedition save field.

### Interface Translator art kit delivered

Generated by `tools/build_trace_vault.mjs`. `test_trace_models.vg` is 317/317. TRACE_CYCLE 181/181 and TRACE_ROUTE 64/64 are unchanged. Review in `translator_preview.tscn`. Its frames are in `build/ash_meridian/translator-*.png`.

**Sign contract.** Every Narcean sign is a `Node3D` with:

- metadata `text_kind` (`interface` or `high`), `script` and `gloss`;
- `Script`: stroke boxes `S0..`, readable from local +Z;
- `Gloss`: a `Label3D`, `visible = false`, whose text equals the `gloss` metadata, placed under the script.

The controller only toggles `Gloss.visible`; it never builds sign geometry.

**New scenes.**

| Scene | Nodes for the controller |
|---|---|
| `interface_translator` | `Slate`, `Screen`, `Readout` (LEXICON strokes), `LensGlass`, markers `LensPoint` and `Grip`. Hand-held prop, no collision. |
| `translator_post` | `Translator` (instance), `PickupPoint`, sign `PostLabel` ("LEXICON SERVICE"), `DeadScreen`, `ShelfGlow`. No collision. |
| `release_lock` | `Face/Key0..9` (each `Cap`, `Glyph` numeral strokes, hidden `Gloss` digit), `Face/Entry0..3` (empty groups: add the entered numeral glyphs there), `Face/Slot0..3` frames, `Face/ClampLight` (red; set it cyan on release), markers `UsePoint` and `DisplayPoint`. No collision. |
| `service_tag` | signs `Line0` "CRADLE RELEASE" (amber) and `Line1` "TWO SEVEN FOUR ONE". |

**Placed in existing scenes.** Existing node paths are unchanged. The `yard_dock` collision count is still 3.

- `yard_dock`:
  - `GateSign` and `RoadSign` are now Narcean signs, with the same names.
  - New `ReleaseLock` and `ReleasePoint`, beside the boarding side and facing the road.
  - New high-script `Directive` on a post, with `DirectivePanel` and `DirectivePost`. Its gloss is "NO BODY LEAVES THE YARD UNCOMPILED", and the translator must never reveal it.
- `yard_void_field`:
  - `ServiceTag` on the lift head's road face at (2.6, 1.7, 397.95).
  - `TranslatorPost` hidden in `TranslatorHideout` near the archive doorway at (39, 0, 40), with `TranslatorPoint` in front of the entrance.
  - `FarYardDock` marker for the far secondary dock (keeps existing `VaultCradle` paths for compatibility).
- `deep_lift_lobby`: `Sign`, `Cabin/IndicatorOut`, `Cabin/IndicatorIn` and `Cabin/ControlPanel/ScreenText` are now Narcean signs, with the same paths.

**`yard_field.json` `translation` section**:

- `cradle_code_dev`: "2741";
- `cradle_lock`, `code_clue`, `translator_post`;
- `signs`: paths under the field root;
- `word_hash`: the spec and the glyph paths;
- `numeral_patterns` and `number_words`;
- `fixtures`: for example `TRACE` hashes to 746199118, giving cells [14, 2, 6].

`test_trace_models.vg` includes `narcean_hash` and `narcean_cell`, a working VG port. It shows the spec runs in VG; Cursor can lift it into the HUD.

### Copyable Cursor prompt (translator behaviour)

```
Ash Meridian — Interface Translator behaviour (isolated TRACE YARD dest only; Play and campaign v1 untouched).
Read docs/development/ASH_MERIDIAN_TRACE_VAULT_HANDOFF.md sections "October 27 direction: Interface Translator" and "Interface Translator art kit delivered".
Do NOT create or regenerate models; tools/build_trace_vault.mjs and assets/trace_vault/ are art-owned. You are already building test_trace_yard.vg — extend it.
1. Load yard_field.json "translation". Owned flag: inventory.translator; dest default translator_start_owned = true. No new expedition save field.
2. Gloss pass (every ~0.1 s): for each sign path in translation.signs (plus ReleaseLock Key*/Gloss), if text_kind = "interface" AND translator owned AND sign within gloss_range_m (6 m): 0.4 s flicker then Gloss.visible = True; else False. text_kind = "high" never shows its Gloss (HUD may show "NEEDS A READER").
3. Release lock: at YardDock/ReleasePoint, open a keypad; keys are numeral glyphs. Write each entered digit's glyph into Face/Entry0..3 (reuse the numeral strokes; Entry groups are empty). Correct = cradle_code_dev → ClampLight cyan, set cradle_released in the isolated trace save, allow boarding. Wrong → clear entries, red flash. Boarding is refused until released.
4. HUD: port narcean_hash / narcean_cell from test_trace_models.vg into the HUD as narcean_word/narcean_line for 2D script; cockpit HUD stays English.
5. Tests in test_trace_yard.vg: fixture hashes match; interface gloss only with translator and in range; high never glossed; keypad digit glosses hidden without translator; tag unreadable without / reads TWO SEVEN FOUR ONE with; wrong code refused, 2741 releases; release persists across checkpoint save; expedition save field count unchanged.
Run test_trace_models, test_trace_cycle, test_trace_route and test_trace_yard; report counts. Do not commit.
```

### October 27 follow-up: combined Backlight yard + cycle field

Implemented in art:

- Added [backlight_cycle_combined.tscn](../../samples/games/ash_meridian_part1/assets/trace_vault/scenes/backlight_cycle_combined.tscn) as the ground-level combined playspace preview (Backlight yard + cycle).
- Kept the old remote area as a far secondary dock for later campaign use:
  - existing node `VaultCradle` remains in place;
  - new marker `FarYardDock` points to that dock;
  - [yard_field.json](../../samples/games/ash_meridian_part1/assets/trace_vault/yard_field.json) adds `docks.far_yard` as an alias.
- Moved translator pickup into a building bay:
  - `TranslatorPost` now sits inside `TranslatorHideout` at the yard archive strip;
  - `TranslatorPoint` is a walk-up marker just outside the doorway.

Compatibility retained:

- Existing runtime/test paths continue to work: `YardDock`, `VaultCradle`, `DeepLiftLobby`, `TranslatorPost`, `ServiceTag`.
- Current suites still pass after regeneration (`TRACE_MODELS 317/317`, `TRACE_CYCLE 181/181`, `TRACE_ROUTE 64/64`, `TRACE_YARD 63/63`).
