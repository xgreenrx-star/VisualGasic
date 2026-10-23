# Ash Meridian: Trace Cycle, vault and return chase

## Status and ownership

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
| Cycle route, docks, chase | Static 160x240 m support field, two cradles, three relays, separate deep-lift landing and route manifest | Art layout only; controller, trails and chase remain Cursor work |
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

The FEB proposal is a 2.65 m heavy guardian with asymmetrical tools: one service
hand and one integrated thermal emitter. Opaque layered armor, limited exposed
mechanisms, restrained cyan standby channels and a narrow amber optical sensor.
Avoid transparent wireframe bodies and a uniformly glowing humanoid.

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
| `stasis_cradle.tscn` | `FigureMount`, `ClampPivots`, `VentSockets`, `CouplerSocket`, `WarningPanel` |
| `feb.tscn` | `VisualRoot/HeadPivot`, `VisualRoot/ServiceArmPivot`, `VisualRoot/ThermalArmPivot`; no full locomotion rig |
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

## Proposed gameplay defaults for review

These close open questions for the first prototype; they are not user-approved
balance or an instruction to change the released campaign without review.

- Elevated third-person chase camera. A/D or Left/Right requests a 90-degree
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
campaign draft. The first script-free model kit is delivered under
samples/games/ash_meridian_part1/assets/trace_vault/scenes. Inspect manifest.json,
route.json, the four previews and test_trace_models.vg. Keep trace_route.vg's
existing stage/save contract and the campaign's current version-1 Play route.
Build the isolated TRACE CYCLE dev destination next: boarding, precise turns,
swept movement, persistent trails, crashes, docking and clean retry, then quiet
outbound relay progression, separate far lift, vault and return chase.
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
