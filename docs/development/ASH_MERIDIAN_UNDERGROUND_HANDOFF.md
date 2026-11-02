# Ash Meridian: underground levels and route consolidation

Prepared October 31, 2026. Planning handoff, not a shipped feature.

## 1. Direction and authority

User-approved progression: **all three underground levels are available before
the Trace Cycle; the laboratory has optional FEB-only secrets on a later visit.**

This document supersedes conflicting route/underground recommendations in
[the Trace Vault handoff](ASH_MERIDIAN_TRACE_VAULT_HANDOFF.md), not its model
attachment contracts. Consolidate the game rather than adding another parallel
campaign. No gameplay or save migration was performed for this planning delivery.

- Assistant owns original art, materials, model contracts and story planning.
- Cursor owns VG gameplay, interaction, collision, saves and tests.
- New game-owned executable code/tests are VG. Native scenes/materials/shaders
  are allowed; do not introduce GDScript or copy Vector Crypt's renderer.
- Preserve current uncommitted work, media and saves. Do not commit/push or
  launch paid agents unless requested.
- Build and review one increment at a time; do not implement three levels and
  a campaign migration in one pass.

## 2. Verified current state, not intended state

These are source findings on October 31, not new playtest results.

| Surface | What exists now | Consequence |
|---|---|---|
| Surface lifts | [backlight_yard.vg](../../samples/games/ash_meridian_part1/backlight_yard.vg) registers damaged/jammed lifts; building index 7 is the working transit depot | One working local lift route; the broken lifts do not currently function |
| Current Play lift | [start_lift / finish_lift](../../samples/games/ash_meridian_part1/backlight_exploration.vg) accepts a five-digit address and sets `floor_code` | Local destinations are not yet a curated three-level campaign |
| Old FEB chamber | [backlight_interiors.vg](../../samples/games/ash_meridian_part1/backlight_interiors.vg) calls `_pod` for `floor_code = FEB_CODE` (`14242`); exploration still has its coupler, alarm and chamber retry path | **Yes, the old chamber remains reachable in Play** |
| New FEB facility | [trace_cycle_test.vg](../../samples/games/ash_meridian_part1/trace_cycle_test.vg) has the far dock, lift, native vault/stasis/FEB and return chase | Keep this as the sole FEB encounter in the consolidated route |
| Local lift contract | [trace_route.vg](../../samples/games/ash_meridian_part1/trace_route.vg) rejects `14242` at the yard lift and permits `11111`, `22222`, `33333` | Correct direction, but an isolated contract is not Play integration |
| “Combined” preview | [build_trace_vault.mjs](../../samples/games/ash_meridian_part1/tools/build_trace_vault.mjs) still instances `yard_proxy` in the field; the combined scene wraps that field | Earlier “combined” wording overstated the merge. Real yard gameplay is not unified by this preview |
| Second yard | `FarYardDock` is currently a marker/alias at the existing `VaultCradle`; only additional silhouettes were added | The full second yard was not actually moved there. Preserve it as a distinct later-game district, not a renamed FEB dock |
| Hidden translator | The field contains a visual `TranslatorHideout` and `TranslatorPost` | This does not prove pickup through a real building interior. The hideout's `DoorFrame` is a solid visual slab, not a usable doorway |
| Save/tests | [campaign.vg](../../samples/games/ash_meridian_part1/campaign.vg) is version 1 with 32 fields; [test_trace_route.vg](../../samples/games/ash_meridian_part1/test_trace_route.vg) explicitly expects Play's old chamber access | Removing the chamber requires an intentional route/save/test transition, not just deleting the pod |

There are existing uncommitted edits to the yard, exploration, campaign tests,
README and project settings. Inspect and preserve them before implementation.
Historical pass counts in the older handoff are not a fresh baseline.

## 3. One coherent expedition

```text
Ash landing / real Backlight Yard
  ├─ Existing surface salvage and archives
  ├─ Hidden Interface Translator in an existing archive building
  ├─ Working transit-depot lift
  │    ├─ Storage: salvage, cargo puzzles, optional surface shortcut
  │    ├─ Maintenance: power-routing puzzles and cycle diagnostics
  │    └─ Laboratory: containment puzzles and FEB research, no FEB occupant
  └─ End-of-road cycle dock → void relays → far dock / FEB facility
       → existing coupler event and return chase → Ash departure

Later return with FEB → optional high-script laboratory annex
Later-game travel → preserved second yard with its own cycle dock
```

Each local level is independently enterable once its address is learned.
Players may leave and return; do not force a three-level sequence or require
all optional rooms before riding. A later level must not require a consumable
or unique part that can be sold or lost on another floor.

The local lift never reaches the FEB facility. The laboratory may contain
research diagrams or empty equipment, but no duplicate FEB, usable FEB pod,
departure coupler or first-visit escape trigger. Keep the FEB facility's exact
existing dock/lift arrangement for the first consolidation increment.

Keep `11111` / `22222` / `33333` as development addresses only. Place discoverable
destination records and translated signage before selecting final numbers.
Keep the four-digit cycle release code (`2741`, development placeholder)
separate from the legacy five-symbol archive sequence and local lift addresses.
Do not let either old sequence silently unlock unrelated routes.

## 4. Vector Crypt: what to borrow

References:
[README](../../samples/apps/vector_crypt/README.md),
[design sketch](../../samples/apps/vector_crypt/DESIGN.md), and
[Main.vg](../../samples/apps/vector_crypt/Main.vg).

The implemented reference has distinct named chambers, room-specific hints,
plate/switch gates, a crate plate, timed piston passage, a temporary bridge,
gravity-assisted routes and room checkpoints. `RememberSpawn` explicitly keeps
checkpoints out of closing door slabs. Port the **principles**, not the
coordinate arrays, story, characters or entire renderer/controller.

Loop: **read the room → understand the mechanism → try safely → solve →
collect something meaningful → open a shortcut → choose the next room.**

- Show the objective, mechanism state and result together where possible.
- Teach a mechanism without damage before combining it with danger.
- Connect halls to rooms, loops and side branches, not identical random boxes.
- Combat is secondary. First release uses environmental hazards and one
  avoidable patrol type, not a new gun/ammunition system.
- Gravity inversion, portals and mandatory precision jumping are deferred.
  Backlight currently uses planar `position_xz` movement; those mechanics
  require a separate controller decision and cannot be faked with decorations.
- Temporary bridge puzzles use horizontal crossings with a visible alternate
  safe route or reset. No need for a new jump mechanic in the first slice.

## 5. Shared Backlight art and interaction language

Keep dark filled panels, stepped silhouettes, depth-tested occlusion, luminous
circuit edges, restrained bloom, readable silhouettes and the established HUD.
This is an underground extension of Backlight, not a wireframe Crypt reskin.

- Cyan: stable routes/power. Amber: interactable or caution. Red: active hazard.
  Add symbols, moving parts and audio so color is never the only cue.
- Every damaging surface has visible geometry and a warning state; collision
  and art must agree. Never invisible walls, invisible pits or hidden hitboxes.
- Default authored scale targets: 3–4 m clear corridors, 2 m clear doors,
  4–6 m ceilings; service/cargo spaces may be larger. Review with the actual
  camera/player radius before locking dimensions.
- Narcean interface/numerals use the existing translator contract. Only
  interface text is glossed. High script stays unreadable until a genuine FEB
  companion capability is implemented; a `feb_alive` flag is not that capability.
- Exit icons, mechanical motion and emergency safety pictograms remain
  understandable without translation. Do not strand an untranslated player.
- Ship and cycle cockpit HUDs remain separate; do not import the bike dashboard
  into walking interiors.

## 6. Three authored levels

Names, room counts and timings below are proposed authoring targets, not lore
or performance claims. Target 6–8 meaningful spaces per floor and roughly
15–25 minutes on a first visit; adjust after a playtest.

### U1 — Storage / Cargo Registry

**Feel:** broad loading halls, low rack aisles, amber manifests, cyan inventory
lanes, quiet dead conveyors. Open geometry and sparse danger teach the rules.

```text
Arrival safe lobby → Registry hall → Cargo routing room → Salvage bay
                         └─ Rack maze → Empty stores ─────────┘
Salvage bay → Dispatch hub → Return lift
                    └─ Optional service spur → repaired surface lift
```

- **Registry:** translate a manifest to identify the live cargo lane; glyph
  markings correspond to racks, not random keypad brute force.
- **Cargo routing:** move one reusable cargo unit between two plate/track
  positions. The first position demonstrates gate activation; the second
  opens the salvage route. Reset returns it to a known reachable location.
  Start with constrained track movement, not general physics crate simulation.
- **Rack maze:** environmental navigation and one optional salvage branch;
  journal/map marks searched rooms and empty racks.
- **Danger:** one timed sweep/conveyor gate with a safe observation recess.
  Red preview lasts at least 1 s before damage; the first demonstration is safe.
- **Finds:** finite appraisal salvage and a registry record explaining the
  maintenance/laboratory destination panels. Do not duplicate surface regulator
  or ignition pickups under different IDs.
- **Shortcut:** optional reusable fuse powers a service ascent, emerging at one
  specifically registered broken surface lift. Record its stable ID.

### U2 — Maintenance / Containment Works

**Feel:** taller service halls, exposed conduits, alternating amber work lights,
cyan power spines, piston housings and intermittent red containment arcs.

```text
Arrival → Diagnostic gallery → Power distributor → Piston hall → Bridge control
                    └─ Service loop ────────────────┘             │
Return lift ← Restored bypass ← Cycle diagnostic station ←────────┘
```

- **Power distributor:** rotate/select conduit links to connect source and
  destination. Physical segment lighting previews power flow; controls can
  always undo. Wrong routing trips a resettable breaker, not a permanent lock.
- **Piston hall:** watch a full cycle from safety, cross in the raised interval,
  then find a manual bypass for return trips. Collision follows the piston pose.
- **Bridge control:** a temporary power bridge teaches timing. Proposed starter
  tuning: at least 8 s for a crossing designed to take at most 4 s at normal
  walking speed. Tune with the actual controller; never impose sprint-only timing.
  If it expires, use a telegraphed fall/retry or visible safe recovery, not
  an invisible support plane that contradicts the bridge.
- **Finds:** cycle containment/drain explanation, relay recharge instructions,
  a non-consumable diagnostic record, limited repair salvage. These explain
  the cycle; no new mandatory repair gate in the first increment.
- **Shortcut:** restoring the distributor opens the service loop permanently.
  A second surface ascent can be proposed after U1's endpoint contract works.

### U3 — Laboratory / Pattern Annex

**Feel:** clean white-cyan isolation halls, violet instrument light, dark
observation glass, asymmetric test rooms and restrained red lockdown strips.
It suggests stasis research without housing the FEB encounter.

```text
Arrival → Observation hall → Signal test rooms → Isolation gate → Records vault
                  └─ Containment loop / patrol route ───────────────┘
Return lift ← Decontamination bypass ← Records vault
Records vault ── [FEB high-script capability, later] → Optional sealed annex
```

- **Signal tests:** observe a repeating three-channel pulse, set a route through
  instrument panels, and verify feedback before committing. Use learnable rules,
  not a new arbitrary code hunt.
- **Isolation gate:** two resettable interlocks must agree before a safe door
  opens. Failure visibly resets the test; it does not start the FEB escape timer.
- **Danger:** short-lived containment beams and, after the environmental slice
  is stable, one predictable security patrol with visible detection indication,
  cover and a bypass. No unavoidable combat or new weapon dependency.
- **Finds:** stasis research, FEB protocol foreshadowing and finite instrument
  salvage; no departure coupler, occupied FEB chamber or duplicated awakening.
- **Later annex:** high-script records and a distinct optional discovery.
  Leave this sealed with explicit feedback until companion translation exists.
  Its contents and story reveal require a later authored decision.

## 7. Translator and surface shortcuts

Hide the translator in **one existing archive interior**, not a new exposed
outdoor shed or an inaccessible mesh. Proposed host: archive building index 1
(`YARD ARCHIVE 2`); the current visual hideout near `(39, 0, 40)` is only a proxy.
Use a stable building ID in new state, not just a fragile array index.

- Put it on a reachable side shelf behind cargo/racks. A service pictogram,
  lens glint and inspect prompt help discovery without an English floating label.
- Pickup sets `inventory.translator` once and hides the prop on return/load.
- Main consolidated play starts without it; isolated tests may explicitly
  enable start-owned mode. Do not change a global default to bypass the puzzle.
- The translator must be obtainable without translated text, and no underground
  return lift may require owning it.

Surface ascents are graph links, not “return to generic surface” teleports.
Define `lift_id`, source level, destination surface lift ID, repair/unlock
state and a safe exit pose. U1's restored ascent must support descent again.
Keep all other jammed lifts visibly broken. Arrival collision is checked before
transfer; loading/retrying cannot leave the player inside a door or shaft.

## 8. Technical boundaries and state

Do not grow another all-in-one controller. Proposed new VG responsibilities:

- `underground_levels.vg`: immutable level/room/connection definitions and IDs.
- `underground_controller.vg`: current room, interactions, puzzle/hazard state,
  lift transitions and checkpoint restoration.
- `underground_builder.vg`: assemble approved modular scenes/greybox geometry.
- Existing exploration/HUD: walking integration, prompts and translated panels.
- Existing campaign: persistence and high-level progression.

Reuse the existing walking/rendering path initially. Static geometry builds on
entry; switches/doors/hazards update without rebuilding the entire floor each
frame. Trigger ranges, geometry/collision and puzzle state share stable IDs.
Keep new state scoped to the controller and use deliberate integration hooks.

Per-level checkpoint state needs: layout revision, level/room/checkpoint ID,
solved puzzle IDs, collected unique pickup IDs, repaired lift IDs and journal
records. Snapshot at safe points only. On restore, reset hazard phases and
transient moving cargo to safe known states while restoring durable solves.
Restore opens any gate needed to leave the checkpoint. Define which cargo state
is transient versus solved before implementing each puzzle.

Keep existing inventory item identity and single-owner rules. Retries cannot
duplicate salvage or erase a previously committed pickup; no essential quest
item may be sold. No new alarm/timer state shared with the FEB facility.

**Save rollout:** design and test a versioned consolidated schema before
changing Play. Do not quietly insert underground state into v1's exact field
set or claim migration is complete.

- Preserve v1 files byte-for-byte. Save the new route in a separate versioned
  file until explicit promotion.
- Classify old saves: clean surface salvage; arbitrary old underground address;
  active/completed old FEB escape; old coupler possession; malformed state.
- Only migrate states with a demonstrably equivalent checkpoint. Refuse the
  others with an explicit explanation; never teleport an old FEB save into the
  laboratory, delete items or overwrite its file.
- A legacy save must remain recoverable. If a legacy compatibility loader is
  retained, isolate it as non-canonical; it must not leak the old encounter into
  the new route. Decide its UI/retention before promotion, not ad hoc.

## 9. Phased delivery and acceptance

### Phase 0 — route truth and consolidation contract

1. Report current baseline for campaign, yard, trace-route, cycle, yard-field
   and model suites; do not rewrite tests to disguise an existing failure.
2. Trace Play, Continue, development destinations and every lift entry path.
   Write an explicit state/scene graph and save compatibility matrix.
3. Define the consolidated route gate and versioned state. In that route:
   yard lift `14242` and arbitrary unknown addresses are refused with feedback;
   only the three local destinations/return links are valid.
4. Gate/remove old local `_pod`, coupler pickup, awakening, retry, prompts and
   completion shortcuts from the consolidated route, not just its mesh.
   Preserve the far-dock native FEB facility and existing chase.
5. Specify the real yard merge: one authoritative surface, buildings,
   inventory, player pose and time/state ownership; stop drawing/controlling
   the proxy on top of it. Boarding and dismounting transfer pose/state, not
   start a separate game. Preserve the complete second yard separately.
6. Give that second yard its own stable district/dock ID and charge-reachable
   travel plan; leave it a later-game destination until approved. Do not equate
   it with the FEB facility or expand ride bounds without recharge validation.

Stop for review: no default Play switch yet. The contract must show how removal
and integration happen together so Play never loses its only completion route.

### Phase 1 — Storage vertical slice

Deliver an isolated underground development entry using the real Backlight
walking/art path. Build arrival lobby, connected halls, cargo routing puzzle,
salvage room, one telegraphed hazard, checkpoint/retry and both lift exits.
Place the translator in the existing archive interior in the consolidated test
route. Prove start-without-translator → pickup → local lift → puzzle → return.

Cursor may assemble explicitly temporary greybox primitives but must not
generate final art or rewrite the supplied model kit. Label greybox status.
Assistant's first art batch should cover corridor junctions, room/door frames,
racks, cargo track/plate, service lift controls and hazard emitter housings.

### Phase 2 — Maintenance

Reuse proven modules, add circuit routing and piston/bridge mechanisms one at
a time. Demonstrate different layout/lighting/objectives, persistent bypass,
cycle diagnostics and return safety. No copied Storage puzzle with new colors.

### Phase 3 — Laboratory

Add signal/interlock puzzles first, then containment hazards and a bounded
patrol. Verify research-only FEB foreshadowing. Keep later high-script annex
sealed until its actual companion capability is implemented.

### Phase 4 — promote one campaign

After review, wire underground + real yard + cycle + sole far-dock FEB facility
into Play/Continue using the tested migration policy. Update objectives,
destination labels, documentation and regression expectations together.
Archive/reference destinations must be explicitly non-canonical, not advertised
as alternative ways to obtain the campaign coupler.

### Required tests (add as each increment becomes real)

- Consolidated local lift rejects `14242`, malformed/unknown addresses and
  remains usable for all three locals plus valid return endpoints.
- Legacy chamber tests remain only in a deliberate compatibility context;
  new-route tests prove no local FEB/pod/coupler/alarm/completion shortcuts.
- Translator pickup is reachable without translation and occurs once;
  high script is never glossed by translator-only inventory.
- Every room exit/shortcut is reachable; checkpoint poses are outside closed
  doors, solids and hazards; threshold seams have continuous walkable support.
- Cargo reset cannot trap the puzzle; solves and unique pickups survive
  leave/re-enter and save/load without duplication.
- Hazard damage occurs only in active visible states, respects cooldown and
  behaves consistently across 30/60/120 Hz simulation steps.
- Timed crossings meet the authored timing margin with the actual walker.
- Each ascent lands at its exact repaired surface lift; return descent works;
  unpaired/jammed lifts remain blocked with feedback.
- New saves round-trip and malformed/unsupported ones refuse without mutation;
  v1 save bytes survive every attempted adoption/refusal.
- End-to-end new route: real yard → translator → local floor → surface →
  cycle → far dock → only FEB encounter → return/ship completion.
- Manual frames/playthrough show connected rooms, readable mechanisms,
  Backlight materials, no duplicate yard overlay and no invisible collisions.

Suggested suite split: `test_underground_route.vg`,
`test_underground_storage.vg`, then maintenance/laboratory suites and a save
suite. Names are proposals, not existing files. Also run directly affected
existing suites; add new assertions before reporting new feature completion.

## 10. Copyable Cursor prompt — first increment only

```text
Ash Meridian: consolidate route truth before authoring underground gameplay.

Read docs/development/ASH_MERIDIAN_UNDERGROUND_HANDOFF.md.
It supersedes conflicting route recommendations in the Trace Vault handoff.
All three local floors are available BEFORE the cycle/FEB; laboratory has
optional FEB-only secrets later. The sole canonical FEB is at the far-dock
facility after riding the cycle. Preserve the full second yard for later,
separate from the FEB dock. Current combined preview still uses yard_proxy.

Do Phase 0 ONLY:
- Inspect/preserve existing dirty work; do not change other sample games/media.
- Run/report the current affected-suite baseline.
- Trace Play/Continue/dev destinations and all yard/deep lift paths.
- Produce the concrete consolidation state/scene graph, proposed gated route
  API and versioned save compatibility matrix; record them in the handoff.
- Identify every old local chamber/pod/coupler/alarm/retry/prompt/completion
  hook to gate/remove in the new route and the tests that currently assert it.
- Define a single real-yard/player/inventory ownership model for walking,
  lift transitions and boarding/dismounting; do not call a proxy wrapper a merge.
- Specify the paired Storage service ascent to one existing broken surface lift.
- Identify migration refusals; preserve v1 bytes and its recoverability.
Do not flip default Play, remove its completion route, overwrite saves, create
models, implement all floors, add GDScript, commit/push or launch paid agents.
Stop with the contract and bounded Phase 1 implementation checklist for review.
```

## 11. Phase 0 contract (31 Oct 2026)

Planning delivery only. Default Play still completes through the old yard-lift
chamber. No Play switch, no save-file writes, no new floors.

### 11.1 Dirty work preserved (not committed)

Left untouched except this handoff:

| Path | Notes |
|---|---|
| `samples/games/ash_meridian_part1/backlight_yard.vg` | Damaged north/tower lift faces |
| `samples/games/ash_meridian_part1/backlight_exploration.vg` | `dead_lifts`, E-inspect, working building 7 unchanged |
| `samples/games/ash_meridian_part1/test_backlight_yard.vg` | 46/46 including dead-lift inspect |
| `samples/games/ash_meridian_part1/test_campaign.vg` | 63/63 including north-lift inspect, still 32 v1 fields |
| `samples/games/ash_meridian_part1/README.md` | Damaged-lift wording |
| `samples/games/ash_meridian_part1/project.godot` | Pre-existing local settings |
| `docs/development/ASH_MERIDIAN_TRACE_VAULT_HANDOFF.md` | Pre-existing |
| `samples/apps/vector_crypt/project.godot` | Other sample; not edited |
| `samples/games/ash_meridian_part1/ash_meridian1.avi` | User media; not staged |

### 11.2 Affected-suite baseline (headless, this machine, 31 Oct 2026)

| Suite | Result | Meaning for consolidation |
|---|---|---|
| `test_campaign.vg` | 63/63 | Play v1: building 7 + `14242` + coupler + 255 s + save 32 fields |
| `test_backlight_yard.vg` | 46/46 | Real yard dest; dead lifts inspect; 8 enterable halls |
| `test_trace_route.vg` | 64/64 | Isolated contract already rejects yard `14242`; Play checks still **require** it |
| `test_trace_models.vg` | 317/317 | `yard_proxy` is visual-only; combined preview is not the live yard |
| `test_art_direction.vg` | 10/10 | Boot splash / concept resources |
| `test_trace_yard.vg` | 67/67 | TRACE YARD dest; translator dest-owned; `FarYardDock` aliases vault cradle |
| `test_trace_cycle.vg` | 181/181 | Far-dock native FEB/coupler/chase; dest does not write campaign |

Do not rewrite any of these assertions to look like the new route until Phase 4.

### 11.3 Entry graph (what actually runs today)

```text
Title
  PLAY  → intro → landing rings → StartCampaign
          → presentation.campaign_yard (yard_mode + campaign_mode)
          → phase PH_BACKLIGHT_YARD
  CONTINUE → LoadCampaign(campaign_yard) if v1 file validates
             else stay on title with last_error (file unchanged)

F10 (from a dest, if campaign.city exists) → ResumeCampaign
  (same campaign_yard instance; dest mutations must not stick)

Dev dests (WarpDev → StartRun, campaign_active False):
  3 YARD / 4 ELEVATOR / 5 FEB / 6 CANYON / 8 INSTALL / 9 REFLECT
      legacy chapter phases (PH_GROUND / PH_DOWN / PH_CHAMBER / …)
  13 BACKLIGHT CITY     → backlight_city_cache, 24 buildings, same lift logic
  14 BACKLIGHT YARD     → backlight_yard, independent of campaign_yard
  16 TRACE CYCLE        → trace_cycle_test mode=dev (void_crossing)
  18 VAULT              → same controller, far_dock
  19 TRACE YARD         → same controller, yard_void_field + yard_proxy
  15/17 BLACK CHANNEL   → unrelated flight dests
```

Save dispatch (`SaveRun`):

- Campaign Play at `PH_BACKLIGHT_YARD` → `user://ash_meridian_campaign.cfg` v1.
- Dest 14/13/16/15 → demo message, no campaign write.
- Legacy chapter dests → `user://ash_meridian_save.txt` (untouched by v1 campaign).

### 11.4 Lift paths

| ID (proposed, stable) | What exists now | Play today | Consolidated route |
|---|---|---|---|
| `depot.transit` | Building index 7, door ≈ `(39, 319)` | Five-digit keypad; **`14242` reaches `_pod`** | Only locals + surface + valid return; refuse `14242` |
| `surface_lift.north_head` | Damaged 8 m cube, door `(0, 397.8)` | E inspects, no travel | **U1 paired service ascent** after Storage fuse |
| `surface_lift.tower.*` | 24 sealed silhouette doors | E inspects, stay jammed | Stay jammed |
| `city.gate.*` / `city.kiosk.*` | City dest only | Inspect | Non-canonical dest |
| `cycle.far_lift` | `FarLift` / `deep_lift_lobby` on void crossing | TRACE CYCLE / VAULT dest only | Sole path to FEB facility after outbound dock |
| Local `11111`/`22222`/`33333` | `trace_route.allow_yard_lift` only | Not wired into `start_lift` | Dev addresses until signage; then U1/U2/U3 |

`start_lift` / `finish_lift` currently accept **any** five-digit string and stamp
`floor_code`. Unknown addresses still generate a procedural floor. That is the
Play completion hole: `14242` builds `_pod` and `take_coupler`.

### 11.5 Old local-chamber hooks to gate on the new route

Keep the native far-dock facility (`trace_cycle_test.vg` coupler/timer/chase).
Gate or bypass these **only** when `route_id = consolidated` (Phase 4). Until
then they remain Play's completion path.

| Hook | File | Tests that assert it today |
|---|---|---|
| `start_lift("14242")` / `submit_sequence` | `backlight_exploration.vg` | `test_trace_route.play_yard_lift_still_reaches_chamber_code`; `test_campaign` lift save |
| `finish_lift` → `floor_code = FEB_CODE` | same | `play_default_lift_still_uses_chamber_address` |
| `_pod` when `floor_code = FEB_CODE` | `backlight_interiors.vg` | campaign coupler pickup; GDScript `test_backlight_exploration.gd` |
| `take_coupler` / `awakening` / 255 s audio | `backlight_exploration.vg` | `campaign_coupler_wakes_feb_not_orac` |
| HUD PURGE / `ORAC: RUN!` / `ZEN: RUN!` | `backlight_exploration_hud.vg` | exploration GDScript Zen line |
| `retry_escape` back to chamber | exploration | `campaign_retry_restores_pre_pickup_checkpoint` |
| Q scan “military chamber” | exploration tick | — |
| `campaign.stage` `first_escape` via `awakening` | `campaign.vg` | campaign escape save |
| Launch complete with coupler from this chamber | exploration `use_object` at `SHIP` | `campaign_coupler_alone_enables_first_departure` |
| Archive dests 4/5, `DrawLevel14242` | `part1.vg` | `legacy_feb_chamber_is_archived` (keep as ARCHIVE) |
| Orac scan “FREIGHT LIFT TO 14242” | `part1.vg` | — |
| `can_adopt_expedition` refuse awakening/completed/coupler | `trace_route.vg` | `v1_escape_is_rejected…` — **keep this policy** |

GDScript copies (`backlight_exploration.gd` / interiors / HUD / tests) are
migration leftovers, not Play. Do not add more GDScript. Do not treat them as
the consolidated route.

### 11.6 Ownership model (one real yard)

There are **three** live yard-like instances today. That is not a merge.

| Instance | Owner | Inventory / pose | When visible |
|---|---|---|---|
| `presentation.campaign_yard` | Play / Continue / F10 | `campaign.city`; v1 snapshot | Canonical expedition |
| `presentation.backlight_yard` | dest 14 | Independent `reset()` | Dev demo |
| `trace_cycle` on `yard_void_field` | dest 16/18/19 | Cycle inventory, dest translator flag | Proxy scenery (`yard_proxy`), not `campaign_yard` |

**Consolidated rule (Phase 4, not now):**

1. `campaign_yard` is the only surface simulation: buildings, dead lifts,
   inventory, time, buggy, translator pickup.
2. TRACE CYCLE boarding copies pose/heading/inventory into the cycle
   controller and hides `campaign_yard`; it does not spawn `yard_proxy` on top
   of it.
3. Dismount / far-dock return writes pose/inventory back onto `campaign_yard`
   at the matching dock ID (`yard_dock` or later a real second-yard dock).
4. Dest 14 stays a disposable copy. Dest 19 stays an isolated field review.
5. `FarYardDock` is **not** the second yard. Give later-game district ID
   `yard.east` with its own dock/charge plan. Until then it remains a marker
   alias and must not be used as the FEB facility.

### 11.7 U1 service ascent pairing

Use the already-inspectable north head, not a new outdoor shed.

| Field | Value |
|---|---|
| `lift_id` | `storage.service_ascent` |
| Source | Storage optional spur after the reusable fuse |
| Destination surface ID | `surface_lift.north_head` |
| Surface door | `(0, 397.8)` |
| Safe exit pose | `(0, 394)`, heading `PI` (south, clear of `Rect2(-4, 398, 8, 8)`) |
| Reverse | Same pair; descent returns to Storage lobby checkpoint, not generic surface |
| Repair state | `repaired_lifts` contains `surface_lift.north_head` |
| All other dead lifts | Stay jammed with current inspect feedback |

Collision is checked **before** transfer. Load/retry must not spawn inside the
cube.

### 11.8 Translator host

Proposed host (handoff §7): archive building index 1, label `YARD ARCHIVE 2`,
stable ID `archive.2`, door ≈ `(39, 37)` — same bay the TRACE YARD hideout
visually occupies at `(39, 0, 40)`.

- Pickup lives on a reachable interior shelf, not `TranslatorHideout`'s solid
  `DoorFrame`.
- Sets `inventory.translator` once; hide prop on return/load.
- Play / consolidated start **without** it. TRACE YARD dest may keep
  `start_owned_in_dest`.
- Return lifts never require it.

v1 snapshot fields do **not** include translator (`test_trace_yard` already
asserts this). v2 inventory may add the key without stretching the 32-field
exact set.

### 11.9 Proposed gated lift API

New VG module `underground_levels.vg` (Phase 1), consulted by exploration
**only** when `route_mode = "consolidated"` or an isolated underground dest is
active. Play stays on today's `start_lift` until Phase 4.

```text
allow_depot_lift(target) -> Boolean
  "surface"                         OK (returns to depot.transit interior)
  "11111" / STORAGE_CODE            OK if address learned (dev: always in dest)
  "22222" / MAINTENANCE_CODE        OK if address learned
  "33333" / LABORATORY_CODE         OK if address learned
  "14242" / FEB_CODE / DEEP_CODE    REJECT with Orac local-only line
  malformed / unknown               REJECT "Unknown local stratum."
  paired repaired IDs               OK only if repaired_lifts has that ID

allow_far_lift(target)              unchanged: outbound_complete + vault/return
allow_surface_dead_lift(lift_id)    inspect unless repaired and paired
```

Do not let cradle code `14242` or cycle release `2741` unlock a local floor.

### 11.10 Save compatibility matrix

Keep v1 bytes recoverable forever. New route uses a **separate** file until
explicit promotion.

| Class | Detection | Adopt into consolidated? | File |
|---|---|---|---|
| Clean surface salvage | v1, `place` surface/building, no coupler, not awakening/completed | Yes, to `yard_archives` / current pose | Read v1, write **v2 file only** after player confirms Continue on new route |
| Arbitrary old `floor_code` (not 14242) | v1 `place` floor/lift, code ≠ FEB | Refuse: no equivalent room | v1 unchanged |
| Old FEB floor / awakening / countdown | `awakening` or `floor_code=14242` | Refuse (already in `can_adopt_expedition`) | v1 unchanged, Play legacy loader |
| Coupler possession | `inventory.coupler` | Refuse | v1 unchanged |
| Completed old departure | `completed` | Refuse | v1 unchanged |
| Malformed / wrong version | validate fail | Refuse, no mutation | original bytes |
| TRACE dest / riding | no campaign write today | N/A | — |
| Legacy `ash_meridian_save.txt` | chapter format | Never | untouched |

Proposed v2 file: `user://ash_meridian_campaign_v2.cfg`.
v1 path stays `user://ash_meridian_campaign.cfg`.
`campaign.load_game` continues to reject version ≠ 1 until Phase 4 promotion
decides Continue UI (legacy Play vs new route). No silent insert into the
32-field exact set.

v2 payload (separate section, not v1 `expedition` keys): `route_id`,
`layout_revision`, `level_id`, `room_id`, `checkpoint_id`, `solved_puzzles`,
`unique_pickups`, `repaired_lifts`, `journal`, plus a copy of compatible
surface fields. Hazard phases and cargo positions are **not** persisted;
restore to known-safe.

### 11.11 How Play keeps a completion route until promotion

Until Phase 4:

- PLAY/CONTINUE remain v1 chamber completion (`depot.transit` → `14242` →
  coupler → Ash).
- Isolated dests review cycle/vault/translator/dead lifts.
- Phase 1 underground dest reviews Storage without removing the chamber.

Phase 4 must land **together**: lift gate, translator host, cycle board/dismount
on `campaign_yard`, far-dock as sole FEB, v2 Continue, and test expectation
flip. Removing `_pod` before that would leave Play with no coupler.

## 12. Phase 1 implementation checklist (Storage slice only)

Stop again for review after this slice. Do not start U2/U3 or Play promotion.

1. Add dest **UNDERGROUND STORAGE** (or `start_trace_cycle_as`-style mode) that
   uses `campaign_yard` walking/art, not Crypt renderer, not `yard_proxy`.
2. New VG only: `underground_levels.vg`, `underground_controller.vg`,
   `underground_builder.vg`. Greybox primitives must be labelled temporary.
3. In that dest only, depot keypad uses `allow_depot_lift`; `14242` and junk
   addresses notify and stay in the lobby.
4. Build: arrival lobby, registry hall, cargo two-plate track, salvage bay,
   return lift, optional fused spur to `surface_lift.north_head`.
5. One telegraphed conveyor/sweep: ≥1 s red preview; first demo deals no damage.
6. Checkpoint pose outside doors/solids; retry restores durable solves, resets
   cargo to the known reachable plate.
7. Place translator pickup in `archive.2` interior for this dest's yard
   instance; start-without → pickup → lift → puzzle → return.
8. Tests: `test_underground_route.vg` (gate + refuse `14242` in dest mode;
   v1 file bytes unchanged) and `test_underground_storage.vg` (rooms, cargo
   reset, hazard, both exits, translator once). Re-run §11.2 suites; they must
   still match the baseline until Phase 4.
9. Assistant art batch: junctions, door frames, racks, cargo plate, service
   lift controls, hazard housings. Cursor does not invent final models.

Open decisions for the review, not blocked for greybox: final numeric
addresses; whether dest 14 shares the new keypad or stays legacy; Continue UI
copy when both v1 and v2 files exist.
