# Cursor handoff: Ash Meridian pure-VG migration and asset pack

## User direction

Migrate Ash Meridian Part 1 to VisualGasic. The user is developing a VG game
to exercise VG itself and expose language/runtime bugs. Do not introduce more
GDScript without explicit user permission. Renaming extensions, hiding
GDScript behind a VG wrapper, or baking gameplay into an external helper does
not meet this requirement.

Also finish the pending requests:

1. Direct developer-terminal access to the different Backlight areas/states.
2. Reusable Godot scenes/resources, with VG sources and an asset inventory,
   so Cursor can build on the artwork without reconstructing it.

This document is a handoff, not an implementation report. The migration,
additional shortcuts, and reusable exports have **not** been implemented.
The current external assets are procedural GDScript generators; screenshots
are not reusable scene exports.

## Scope and boundaries

- Project: [Ash Meridian Part 1](../../samples/games/ash_meridian_part1/).
- Preserve the original chapter and all four district destinations:
  Bleed City, Bleed City 2, Bleed City 3, and Backlight City.
- All game-owned executable code, including presentation, cockpit drawing,
  input adapters, mesh generation, procedural floors, and export tools, must
  be VG. Do not migrate only the Backlight leaf while leaving its base classes
  or presentation adapter in GDScript.
- Godot `.tscn`, `.tres`, mesh/texture/audio resources, and `.gdshader` files
  are valid native assets. Shader language is not a GDScript gameplay helper.
- VisualGasic's engine extension and existing addon/editor/debug infrastructure
  are platform dependencies, not game code. Do not rewrite the VG addon or
  remove its debug autoload merely to remove every `.gd` string from the
  project configuration. Describe this boundary accurately in the README.
- Existing GDScript tests may serve as the migration baseline. Add the new
  regression coverage in VG and migrate game-owned test runners to VG before
  declaring the game folder GDScript-free. Do not create new GDScript test or
  export helpers without permission.
- No unrelated refactors, commits, or pushes unless requested.

## Starting state and worktree safety

At handoff preparation, the entire game directory is untracked. Preserve it;
do not clean untracked files. Other dirty work exists in the root Copilot
instructions, the Ash Meridian proposal, and Crystal Caverns. Do not overwrite
or stage those changes. Recheck the worktree before editing.

Read the [game README](../../samples/games/ash_meridian_part1/README.md)
for controls and existing validation commands. Treat the current rendered
appearance and behavior as the baseline, not as disposable prototype code.

## Dependency inventory

The current non-test GDScript totals approximately 3,460 lines. This is a real
port, not an extension change.

All paths in this table are relative to the game directory:

| Current source | Responsibility / migration concern |
|---|---|
| `part1.vg` | Already VG: chapter, menus, terminal, phase dispatch, save protection |
| `main.tscn` | Root uses `part1.vg`; Presentation child currently uses `presentation.gd` |
| `presentation.gd` | Native viewports/camera, mesh batching/cache, sampled input, clouds, cockpit and district adapters |
| `bleed_city.gd` | Original Bleed City geometry |
| `bleed_city_2.gd` | City 2 geometry, movement, collision substeps, buggy, pickups, optical effects |
| `bleed_city_3.gd` | Cursor's scaffold city; preserve its deliberate open/wireframe look |
| `backlight_city.gd` | Inherits City 2; satin/opaque geometry, lighting, materials, sky, bloom/composite |
| `backlight_exploration.gd` | Inherits Backlight City; expanded surface, interiors, inventory, lift, FEB, turrets, alarm, escape, ship launch |
| `backlight_interiors.gd` | Interior/floor geometry, cabin/doors, FEB pod/figure/mist |
| `backlight_exploration_hud.gd` | Glyphs, journal, keypad, timer, prompts and result overlays |
| `backlight_cockpit.gd` | Earlier alternate dashboard; determine whether still needed rather than silently changing the preferred cockpit |
| `buggy_art.gd`, `cockpit_art.gd` | Cached opaque cockpit artwork |
| `cockpit_instruments.gd`, `cockpit_stars.gd` | Live gauges and ship starfield |

Search all game source and scene/resource references, including dynamically
constructed paths, `load`, `preload`, and `set_script`. Remove hidden runtime
dependencies as well as direct scene attachments. Preserve adapter method
names where practical so the existing VG chapter does not need a large rewrite.

## Phase 1: establish evidence and prove VG APIs

1. Run the existing focused baseline tests sequentially. Save logs and captures
   outside tracked source. Tests share save/options locations: do not run them
   concurrently.
2. Inspect repository examples and VG API documentation before designing the
   replacements. Do not assume GDScript inheritance, `.new()`, `super`, typed
   arrays, closures, or static class dispatch translate directly to VG.
3. Write small VG smoke tests for the operations this port actually needs:
   - Instantiate/attach VG scripts to Node, Node2D, and Node3D; invoke methods
     and callbacks across script instances.
   - Create packed vertex/color/normal/index arrays, build an ArrayMesh, and
     retain winding, normals, colors, and multiple materials.
   - Create cameras/SubViewports, draw cockpit/HUD layers, load shaders, set
     shader parameters, and manage environment/render-target properties.
   - Instantiate a PackedScene and save/reload a generated scene/resource.
     Verify the VG equivalents of PackedScene packing and ResourceSaver;
     check return/error values, not merely output-file existence.
   - Seed deterministic RNG and construct/play the alarm audio resource.
4. Fix reproducible VG blockers at their source with focused regressions.
   Do not silently fall back to GDScript or swallow constructor/dispatch errors.
   If a blocker cannot be resolved, report the failing VG repro and stop short
   of claiming the port works.

## Phase 2: migrate the presentation and districts

Use VG scripts, script-free baked resources, and composition as appropriate.
Do not invent unsupported VG inheritance to copy the current GDScript chain.
Static scenery may be exported once, but source generation/export must remain
available in VG. Procedural floors and gameplay must remain executable VG.

Port in dependency order: geometry/material utilities and cockpit layers,
presentation adapter, older districts, Backlight geometry/interiors/HUD,
then exploration gameplay. Wire each replacement into the live scene and
remove the old reference when that slice passes. Do not keep both simulations
running or leave runtime-loaded legacy code as an undocumented fallback.

Preserve these easily regressed details:

- Input is sampled once per frame. A held Enter must not confirm Options and
  immediately return to the main menu. Pause-menu Options returns to pause.
- Keep native depth-tested solid faces and cached meshes. Do not restore
  expensive per-edge software projection or rebuild a district every frame.
- Ship cockpit stars remain behind the canopy; gauges change while driving
  and animate appropriately at idle. Keep the user's preferred earlier buggy
  cockpit, not the superseded Backlight dashboard.
- Keep the open original-style buggy, opaque Backlight buildings, and solid
  turrets. Pod glass and intentional effects may be transparent. City 3's
  intentional scaffold openings are not an opacity bug.
- Preserve the 28-ring landing, interpolated gate crossing, clouds, and retry.
- Backlight is opaque and has its own environment. Other areas must regain
  their prior transparency/environment, with optical passes and audio stopped.
- Preserve positive reverse-Z ribbon bias, currently
  `POSITION.z += 0.00002 * POSITION.w`.
- Downsample TextureRects must ignore texture minimum size and use linear
  filtering; otherwise the glow viewport crops instead of downsampling.
- Backlight medium/high uses 320x180 blur passes, 960x540 composite and 2x MSAA;
  low disables optical passes/MSAA without removing opaque geometry/collision.
- Do not toggle unchanged environment/MSAA properties every frame.
- Preserve 0.25-unit movement substeps, safe buggy parking/exits, collision
  reachability, mesh reuse, and cleanup on scene/node destruction.

Exploration parity includes 24 enterable buildings, five ordered clue archives,
regulator and ignition stores, elevator building at index 7, five-symbol
addresses, deterministic non-FEB floors, and the fixed FEB address `14242`.
Retain the separate-room lifecycle rather than allocating all possible floors.
Preserve the pod's local-coordinate figure/pivot, coupler pickup, slow revival,
fog/flashes, 255-second alien-glyph countdown, on-screen Zen “RUN!”, synthesized
alarm, turret line-of-sight/damage cooldown, both failure/retry paths, surface
return, three-part repair, and ship lift-off. No recorded Zen voice exists.
Pause must freeze the countdown. Demo saves must not modify the chapter save.

## Phase 3: developer-terminal shortcuts

Existing terminal sequence: Up, Up, Down, Down, Left, Right, Left, Right,
B, A, B, A. Existing indices 0–13 must keep their destinations and order;
Backlight City is index 13 / phase 17.

Extend `TickDev`, `DevLabel`, `WarpDev`, and `DrawDev` together. The current
14-row layout is already full: add paging or scrolling, a visible selection,
and position/count feedback at 960x540. Keep keyboard wrap/confirm/cancel.
Derive bounds from one destination count instead of spreading magic numbers.

Add labelled presets for at least:

| Shortcut | Required usable starting state |
|---|---|
| Backlight surface | Normal fresh session, buggy accessible |
| Backlight overview | Expanded district visible; can return to street view |
| Archive interior | At a clue bench, can examine and exit |
| Repair workshop | Regulator pickup available, can exit |
| Ignition store | Ignition pickup available, can exit |
| Empty building | Representative useless-salvage interior, can exit |
| Elevator keypad | All five clues available; correct cabin/panel context |
| Procedural floor | Fixed documented non-FEB seed/address; ascent works |
| FEB dormant | At the pod with surface parts acquired; coupler not taken |
| FEB awakening | Coupler acquired through normal awakening logic; full 255 seconds; exit reachable |
| Surface escape | Alarm active, all three parts, buggy reachable, enough timer to return |
| Ship repair | Near ship with all parts; normal repair/launch interaction available |

These are presets within the existing Backlight simulation, not duplicate
levels with divergent rules. Centralize preset initialization in VG and reuse
normal room transitions and awakening APIs. Reset old room/cabin state,
keypad, pending transitions, camera/view mode, inventory, timer, fog, audio,
failure/completion flags, and vehicle placement coherently. Test switching
between presets repeatedly, including from a failed or completed run.
Do not trigger the destination's E interaction with the Enter used to warp.

## Phase 4: reusable, script-free asset exports

Create an organized `assets/backlight/` pack in the game directory, with a VG
builder/export entry point and repeatable export instructions. Suggested
subdirectories: `scenes/`, `meshes/`, `materials/`, `shaders/`, `textures/`,
`audio/`. Document actual paths after implementation; these paths do not
exist yet merely because they are proposed here.

Export reusable assets, not just one giant frozen city mesh:

- Original-style buggy with separately addressable wheels and steering pivots.
- Turret with base, yaw/pitch pivots, emitter, and muzzle/beam origin.
- Building variants, entry/door modules, portal/gate, transit plinth/ring.
- Carrier and repairable ship with a stable launch root.
- Charge cell, regulator, ignition component, reflector coupler.
- FEB pod, separately animated figure, glass, lights/mist, and part socket.
- Lift cabin, separate sliding doors, and surface/interior modules.
- Shared satin/light materials, environment, optical shaders, and cockpit art.

Give roots/children stable names, meaningful origins, documented axes/scale,
and interaction sockets. Retain collision/door footprints, either as native
collision shapes or explicit metadata consumed by the VG collision system.
Share immutable meshes/materials; duplicate per-instance warning/animation
material state only when needed so one instance does not flash every other
instance unintentionally. Pack owned children correctly so they survive save.

Integrate the exports into the real game, avoiding a second independent asset
implementation. Keep procedural layout in VG with reusable visual modules.
Verify every exported scene instantiates in a fresh scene with no game
singleton, source generator, GDScript, missing resource, or absolute machine
path dependency. Show multiple independent instances and animate the documented
pivots from VG.

## Phase 5: validation and completion

Baseline runners currently exist as:
`test_part1.gd`, `test_bleed_city2.gd`, `test_bleed_city3.gd`,
`test_backlight_city.gd`, and `test_backlight_exploration.gd`.
Run them before migration, then retain their behavioral coverage in the VG
tests. Update checks that inspect old script filenames without weakening
actual interaction, geometry, route, save, or rendering assertions.

Example existing baseline command, from repository root:

```bash
./Godot_v4.6.1-stable_linux.x86_64 --headless \
  --path samples/games/ash_meridian_part1 --script test_backlight_exploration.gd
```

Also validate with the installed Godot 4.7.2 engine where available.
Use a real display or `xvfb-run -a` without `--headless` for rendering checks.
Existing capture variables are `ASH_BACKLIGHT_CAPTURE` and
`ASH_EXPLORE_CAPTURE`, pointing to existing output directories.
Allow several rendered frames after changing scenario/camera before reading
pixels. Compare restored buggy/cockpit, expanded district, archive, empty
store, keypad, procedural floor, dormant/awakening pod, turrets, and launch.

Required new checks:

- Exercise every terminal preset through actual keyboard navigation, including
  scrolling/wrap and transition out again. Verify all rows fit the viewport.
- Demonstrate normal progression still works without shortcuts; presets are
  not substitutes for testing the five-clue/lift/part/escape path.
- Preserve menu, landing, old districts, pause, failure/retry, and save bytes.
- Reload exported assets from disk and verify children, materials, collisions,
  pivots, independent instances, and no attached game GDScript.
- Audit the complete runtime resource graph, not just `main.tscn`; launch with
  all superseded game GDScript removed. Do not remove platform addon scripts.
- Run focused VG/compiler regressions for any engine changes.
- Compare cold build and warmed frame costs with the baseline on the same
  machine/settings. Report measurements and investigate material regressions;
  software OpenGL/Xvfb timings are not hardware-GPU FPS guarantees.
- Repeatedly enter/leave districts and interiors; check errors, leaked nodes,
  stale audio, accumulating viewports, and orphan resources.

Prior exploration results were 151/151 headless on both engines, 165/165
rendered with captures on 4.6.1, and 152/152 rendered without captures on
4.7.2. Other prior headless results were chapter 64/64, City 2 48/48,
City 3 15/15, and Backlight 63/63. These are historical evidence, **not a
current-run guarantee**; establish the local baseline before relying on them.

## Deliverables to report

1. Working VG-only game-owned runtime; old GDScript dependencies removed.
2. Working paged/scrolled terminal and documented preset list.
3. Reusable exported scenes/resources plus VG generation/export sources.
4. Asset inventory with exact paths, node/pivot/socket contracts, usage from
   VG, and a small VG instantiation demonstration.
5. Updated game README with honest language/platform boundaries and exact
   test/export commands; no obsolete GDScript-adapter claims.
6. Test logs, rendered comparisons, performance measurements, and any VG
   bugs found/fixed, with reproductions.

If anything remains incomplete, name it explicitly. Do not claim “100% VG”
while a game presentation, asset builder, HUD, or simulation helper still
executes GDScript.
