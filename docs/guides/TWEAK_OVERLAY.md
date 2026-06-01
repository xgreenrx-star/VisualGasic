# Tweak Overlay — Live Runtime Editing

**Current version:** 5.2.0-Beta2  ·  **Godot target:** 4.5 / 4.6

The Tweak Overlay is a HUD that lives **inside your running game**. It
lets you select on-screen elements — nodes, controls, `VectorCanvas`
draw commands — and edit their visual properties in real time. Changes
either persist as a side-car JSON tweak bag, or get written back into
the originating `.vg` source.

---

## What it is

A toggleable in-game panel (`Ctrl+Shift+T` by default) that:

1. Enumerates **live tweak targets** discovered in the running scene —
   any `Node2D`, `Control`, or `VectorCanvas` draw command queued at
   runtime.
2. Shows an **inspector** for the selected target driven by a schema
   the target declares (`get_schema()` returns
   `{property: {type, min, max, default, ...}}`).
3. Applies edits **immediately** to the live object via
   `set_tweak_override(prop, value)` so you see the result in motion.
4. Persists the override stack on demand — either as JSON or back to
   `.vg` source.

The overlay is implemented in
[addons/visual_gasic/vg_tweak_overlay.gd](../../addons/visual_gasic/vg_tweak_overlay.gd)
with adapters in
[addons/visual_gasic/vg_tweak/vg_tweak_adapters.gd](../../addons/visual_gasic/vg_tweak/vg_tweak_adapters.gd).

---

## Quick Start

1. Run any VG project that uses `vg.Draw*` calls or has tweak-aware
   nodes (most do — the canvas adapter is automatic).
2. Press `Ctrl+Shift+T` to summon the overlay.
3. Pick a target from the **Target:** dropdown (or click directly on
   one in the viewport — selection mode toggle on the toolbar).
4. Edit any property in the inspector — colour swatch, vector spinner,
   text field. The change applies on the next frame.
5. Hit a save button:
   - **Save** — write all current overrides to the JSON tweak bag
     (`user://vg_tweaks.json` + `res://.vg_tweaks.json`).
   - **Save Sel** — only the selected target(s).
   - **→ Source** — for properties the patcher supports (colour today),
     rewrite the originating `.vg` source file.
   - **Reset** — drop the override for the selected target.
   - **Close** — hide the overlay (tweaks remain live until reload).

### Keyboard & mouse cheatsheet

#### Mouse

| Action                       | Result                                                            |
|------------------------------|-------------------------------------------------------------------|
| `LMB` click                  | Pick the topmost target under the cursor                          |
| `Alt+LMB` click              | Pick one individual draw command inside a `BeginGroup`            |
| `Shift+LMB` click            | Toggle the picked target in/out of the current multi-selection    |
| `LMB`-drag on a target       | Move (translate) the current selection                            |
| `LMB`-drag on empty space    | Rubber-band — selects every target whose bbox intersects the box  |
| `Shift`+rubber-band          | Add the rubber-band hits to the current selection                 |
| `RMB`                        | Picks under cursor (if needed) and opens the context menu         |

#### Keyboard

| Shortcut                     | Result                                                            |
|------------------------------|-------------------------------------------------------------------|
| `Ctrl+Shift+T`               | Toggle the overlay (show ↔ hide)                                  |
| `Esc`                        | Cancel place-mode → rubber-band → selection (in that order)       |
| `Tab` / `Shift+Tab`          | Cycle primary target forwards / backwards through `_targets`      |
| `Arrow keys`                 | Nudge the selection by 1 px                                       |
| `Shift+Arrow`                | Nudge the selection by 10 px                                      |
| `Ctrl+Z`                     | Undo the last edit (drag, nudge, inspector change)                |
| `Ctrl+Shift+Z` / `Ctrl+Y`    | Redo                                                              |
| `Ctrl+D`                     | Duplicate the selected runtime draw command (place-mode siblings) |
| `Delete`                     | Remove the selected runtime draw command (place-mode only)        |

#### Toolbar buttons

| Control      | Action                                                            |
|--------------|-------------------------------------------------------------------|
| `Pause` / `Resume` | Freeze physics + script `_process` while you tweak          |
| `Refresh`    | Re-enumerate tweak targets (after spawning new entities)          |
| `Save`       | Persist every override to JSON                                    |
| `Save Sel`   | Persist only the currently-selected target(s)                     |
| `→ Source`   | Write supported overrides back into the source `.vg` file         |
| `Reset`      | Clear overrides for the selected target                           |
| `Close`      | Hide the overlay (same as `Ctrl+Shift+T`)                         |
| `Snap` + #   | Round drag and arrow-nudge deltas to a multiple of this grid size |
| `Canvas:`    | Limit picking + place-mode to the chosen `VectorCanvas`           |
| Place row    | Toggle palette to add new `rect`/`ellipse`/`line`/`text` commands |

When a clicked draw command sits inside a `BeginGroup`/`EndGroup` pair —
e.g. an asteroid built from a fill polygon plus an outline polyline —
the overlay selects the **whole group**. Dragging then moves every
member command together so you never end up with a sibling lagging
behind at its original position. Hold `Alt` while clicking to address
exactly one of the sibling commands (handy for recoloring just the
outline without touching the fill).

The on-canvas status line near the bottom of the control panel always
shows a one-line summary of the active modifiers and shortcuts so you
don't have to keep this guide open while you work.

Context menu on a target adds: Copy colour / fill / position, paste,
duplicate command, delete command, **Edit source** (jumps to the
producing `.vg` line in your editor).

---

## Why it beats a "basic WYSIWYG 2D editor" for certain tasks

A traditional WYSIWYG editor (Godot's 2D editor, Inkscape, the
Unity scene view) is excellent at **authoring static layouts**. The
Tweak Overlay isn't trying to replace that — it solves a class of
problems WYSIWYG editors can't touch:

### 1. It operates on a **running** game, not a paused scene file
You're tuning while gravity, physics, animation, AI, networking, and
data-driven content are all live. A muzzle flash you only ever see for
80 ms can be colour-picked while it flickers. A particle that's wrong
in a 5-second window of one boss phase can be tweaked **in that 5
seconds**, then accepted.

### 2. It tunes things that **don't exist at edit time**
- `vg.DrawRect(...)` calls queued procedurally in `_process` — there's
  no node in the editor tree to right-click.
- Entities spawned at runtime by AI, networking, or scripted level
  generation.
- UI bound to live data (chatbox lines, score numbers, ammo HUD).
- VectorCanvas draw stacks that change every frame.

The overlay enumerates **the queued draw commands themselves**, stamped
with `__src_file/__src_line/__src_ord` from
[vector_canvas.gd::_queue_command](../../addons/visual_gasic/plugins/vector_graphics/vector_canvas.gd),
so each is individually addressable.

### 3. Persistence has **two tiers** with different commitment
- **JSON tweak bag** (Save / Save Sel) — non-destructive overlay file,
  survives across runs, never touches your `.vg` source. Perfect for
  "I'm not sure yet, but the muzzle flash needs to read like this."
- **Source write-back** (→ Source) — promotes a tweak to a permanent
  source-code edit. The colour change you spent ten minutes nailing
  becomes a single literal change in your `.vg` file — diff-reviewable,
  commitable, no manual transcription.

A WYSIWYG editor only offers tier 2: every edit is permanent the moment
you save the scene. The overlay gives you a fast iteration loop and a
considered commit step.

### 4. **Multi-canvas aware**
A VG game can have several `VectorCanvas` instances (HUD, world,
minimap). The overlay's status bar names the current canvas; the
**Place** row creates new draw commands directly into the active
canvas at runtime — try moving a HUD element while watching it
interact with the live game state.

### 5. **Editor-grade ergonomics, inside the running app**
- Colour history palette (eyedropper-friendly).
- Alignment guides + grid snap that respect the canvas transform.
- Multi-select with shared inspector (edit ten enemies' modulate at
  once).
- Undo stack (64 deep — see `UNDO_LIMIT` in the overlay).
- Copy/paste of property values between targets via context menu.

### 6. **Bridges play-test to source code**
The hardest gap in any creative tool is "I got the value right while
playing — now I have to remember it, stop the game, find the file,
type it in, and check I got it right." The **→ Source** button collapses
that loop. The runtime literal becomes the source literal in one click.

---

## Persistence model

Tweaks are stored in a JSON dictionary keyed by
`vg:<canvas_path>:<raw_id>`. Special key `vg:<canvas_path>:__runtime_cmds__`
holds the merged runtime command list so place-mode additions survive
restarts. Files written:

- `user://vg_tweaks.json` — primary, per-user
- `res://.vg_tweaks.json` — committed-with-project tweak bag

Tags inside each entry:

| Tag  | Meaning                          |
|------|----------------------------------|
| `v2` | Vector2 — `[x, y]`               |
| `v3` | Vector3 — `[x, y, z]`            |
| `r2` | Rect2 — `[x, y, w, h]`           |
| `c`  | Color — `[r, g, b, a]`           |
| `t2` | Transform2D — flattened matrix   |

See
[addons/visual_gasic/vg_tweak/vg_tweak_persistence.gd](../../addons/visual_gasic/vg_tweak/vg_tweak_persistence.gd).

---

## D3 source write-back — what's supported today

The **→ Source** button writes back the following properties:

| Property         | Source pattern matched                            |
|------------------|---------------------------------------------------|
| `color`          | `Color(...)` constructor, `Color.NAME` constant   |
| `fill_color`     | same                                              |
| `modulate`       | same                                              |
| `self_modulate`  | same                                              |

For any other property, the overlay falls back to the JSON tweak bag —
your runtime edit is **not lost**; it just isn't written into source.

Implementation:
[vg_tweak_source.gd::patch_property](../../addons/visual_gasic/vg_tweak/vg_tweak_source.gd)
uses a per-prop regex to locate the literal on the line stamped by
the runtime command attribution, then replaces it via
`_format_literal(new_value)`.

### Why colour-only first?

The runtime carries `__src_file` and `__src_line` for every queued
command but **not** per-argument column ranges (the AST doesn't yet
carry token spans). Colour literals are unambiguous on a line because
they always start with the token `Color`. Position/size/width
arguments are bare numeric literals interleaved with other numerics —
distinguishing "the third arg to `DrawRect`" from "the first arg to
`DrawCircle` on the same line" requires source spans. That's the next
milestone — see `/memories/repo/vg_2d_ide_audit_jun2026.md` for the
plan.

### Known limitations

- One colour per source line is assumed. Lines with multiple `Color`
  literals will patch the first match only.
- The source file must be the one VG compiled — if you've edited the
  `.vg` since launch, line numbers may have drifted. Press the IDE's
  **Reload** before write-back.
- Runtime-only commands (added via the Place palette during this run)
  have `__src_file = "runtime"` and are stored in the JSON bag only —
  source write-back skips them.

---

## Related docs

- [Get Started](GET_STARTED.md) — first project walkthrough.
- [Modern Features](MODERN_FEATURES.md) — full feature index.
- [System Integration](../SYSTEM_INTEGRATION.md) — how the overlay,
  IDE, and runtime layers fit together.
