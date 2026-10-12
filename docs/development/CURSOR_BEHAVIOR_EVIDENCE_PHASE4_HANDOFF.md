# Cursor handoff — Behavior evidence Phase 4: the evidence panel

Phases 1–3 are committed on `main`:

- `4b831079` Phase 1: source-linked Whenever chains (`vg_causal_chain.gd` `analyze()`).
- `d8e76444` Phase 2: opt-in runtime ring (`src/visual_gasic_evidence.{h,cpp}`, `join_runtime()`).
- `5625690e` Phase 3: protected expectations (`vg_expectations.gd`, `vg_expectations.json`).

Read `CURSOR_BEHAVIOR_EVIDENCE_HANDOFF.md` (direction and rules) and
`CURSOR_BEHAVIOR_EVIDENCE_PHASE2_HANDOFF.md` (event kinds, `behavior-run/1`,
join statuses) before starting.

This phase delivers **one panel** in Godot's editor. Put the caret on a
`Whenever Section` line in a `.vg` file. The panel shows the static chain on the
left and what a real game run recorded on the right, with risk marks. No model
text, no new chat persona, no change card (that is Phase 5).

Do not commit or push. Do not touch `.github/copilot-instructions.md`,
`samples/showcases/crystal_caverns/Caverns.vg`, `VisualEffects.vg`, or `main.tscn`
(user edits in progress). Do not edit the protected files listed in
`samples/showcases/crystal_caverns/vg_expectations.json`.

## Task 0 — Phase 2 defects found in review (fix first)

Both block a real editor run from producing evidence.

1. **Capacity setting is never read.** `src/visual_gasic_evidence.cpp`
   `load_project_defaults()` (~line 354) looks up
   `"vg/evidence/runtime_rinstate().capacity"`, a search-and-replace accident.
   The registered setting is `vg/evidence/runtime_ring_capacity`
   (`visual_gasic_plugin.gd` ~11885). Fix the key. Clamp to 64–4096 as the
   setting hint says. Add a test that sets the project setting, starts the
   recorder with no explicit capacity, and asserts the snapshot `capacity`.
2. **`vg/evidence/runtime_ring` does nothing.** Nothing in C++ or GDScript reads
   it. Recording only happens when code calls
   `VisualGasicLanguage.vg_evidence_start()`, which only tests do. Add:
   when the game process starts with the setting `true` **and**
   `EngineDebugger::is_active()` (launched from the editor), start the recorder
   once, before the first VG script instance runs its module init, using the
   project capacity and `vg/evidence/watch`. Never auto-start in an exported or
   non-debug run. Record that in `limitations` when it applies.
   Test: with the setting `false`, no instance creation starts a recording. With
   it `true` but no debugger, still nothing. Test the decision function directly
   if the debugger cannot be faked headless.

Rebuild the Linux `editor` and `template_debug` libraries after C++ changes.

## Task A — Editor ↔ game transport

The ring lives in the game process and is wiped when the scene tree exits. The
panel lives in the editor. Use the existing `visualgasic:` debugger channel. The
profiler shows the pattern: `src/visual_gasic_language.cpp` ~281–300 (game side)
and `addons/visual_gasic/vg_debugger_plugin.gd` `_capture` ~260 (editor side).

- Editor → game: `visualgasic:evidence_snapshot` with no arguments. The game
  replies `visualgasic:evidence_data` with `[snapshot]` (the exact
  `vg_evidence_snapshot()` dictionary).
- Best effort: in `vg_evidence_on_scene_quit()`, before wiping, send one final
  `visualgasic:evidence_data` if `EngineDebugger` is active. Then wipe as today.
  If the send fails, do nothing else.
- Editor side: `vg_debugger_plugin.gd` emits a new
  `evidence_data_received(snapshot: Dictionary)` signal.
- Keep the last received snapshot **in editor memory only**. Clear it when the
  next debug session starts, on editor exit, or on the panel's Clear button.
  Never write it to disk. Mark it `running` while the session is active and
  `ended` after `session.stopped`.
- Poll every 1000 ms only while the panel is visible and a session is active.
  Also add a manual Refresh button. No polling when the recorder setting is off.

## Task B — Pure view model (testable without UI)

New file `addons/visual_gasic/vg_evidence_view.gd`:

```text
build_view(static_report: Dictionary, run: Dictionary, run_state: String) -> Dictionary
```

- `static_report` is `VGCausalChain.analyze(text, [section], source_path)` for
  the section under the caret.
- `run` is the last snapshot, or `{}`.
- `run_state` is `none`, `running`, or `ended`.

It returns rows. It does not render. Each row has:

| Field | Meaning |
|---|---|
| `step_id`, `kind`, `text`, `file`, `line`, `location_known` | Copied from the static step. `line` is 1-based. |
| `risks` | Copied from the static step (`state write`, `early-return guard`, `external effect`, `unresolved target`). |
| `runtime` | One status for this row (rules below). |
| `seqs` | Matching event `seq` values. |
| `detail` | Facts only, e.g. `crystals 5 → 6`, `reason=reentrant`. Never prose. |

Header fields:

- `section`
- `root_status` from `join_runtime()`
- `fire_count`
- `run_state`
- `recording`
- `dropped`
- `capacity`
- `watch`
- `stale` (bool)
- `limitations`: the static limitations followed by the run limitations, with
  the source of each kept.

Runtime status per row:

- **Root row:** exactly `join_runtime()`'s status (`observed`, `not_observed`,
  `unknown`, `stale`, `unresolved`). If the root has `whenever_suppressed`
  events, add them to `detail` with their reason (`reentrant`, `debounce`). A
  suppression is not a fire.
- **Callback rows:** `observed` if a `whenever_fired` for this section lists the
  callback and no `callback_missing` event names it. `missing` if a
  `callback_missing` event names it. Otherwise inherit the root's status.
- **Write rows:** `observed` if a `watched_write` matches variable (case-folded),
  procedure (case-folded), and line. If the variable is not in `watch`, the
  status is `not_recorded`. It is never `not_observed`, because the ring could
  not see it.
- **Every other row** (guards, plain calls): `not_recorded`. The ring has no
  procedure-entry or branch events in this phase. Do not infer them.
- **Stale or unknown root:** every row is `stale` or `unknown`. No row may say
  `observed` from a run whose hash does not match.

These rules exist so an empty or partial run never looks like success.

## Task C — The panel

Put it in the **Code Navigator** dock (`addons/visual_gasic/code_navigator.gd`).
It already reads the Script editor's current `CodeEdit` and has
`navigate_to_line(file, line)` (1-based). Do **not** use `vg_context_rail.gd`.
That rail lives in the embedded editor of the experimental IDE, which is out of
scope for v6.0.

- Add a collapsible **Behavior evidence** section. It updates on caret change,
  debounced about 250 ms like the rail.
- Active only when the caret line is a `Whenever Section` line. Otherwise show
  one line: `Put the caret on a Whenever Section line.`
- Two columns:
  - **Left:** static steps, indented by parent. Each row shows `file:line`;
    clicking it calls `navigate_to_line`. Show risk marks as short tags, e.g.
    `[write]`, `[guard]`, `[external]`, `[unresolved]`.
  - **Right:** the row's runtime status as a word plus `detail`. Do not use
    colour alone; the word must be present.
- Header line shows section name, root status, fire count, run state, and
  `dropped/capacity`. Show `stale` in the header when the hashes differ.
- Explicit empty states, each as plain text:
  - `Recording off. Enable vg/evidence/runtime_ring and run the game.`
  - `No run yet.`
  - `Source changed since this run (stale).`
  - `Events dropped (N). Raise vg/evidence/runtime_ring_capacity.`
- Controls:
  - **Record runs** checkbox, bound to `vg/evidence/runtime_ring`. Save
    `project.godot` with `ProjectSettings.save()`.
  - **Watch `<variable>`** button for the caret section's variable, if not
    already watched. It appends to `vg/evidence/watch` and saves.
  - **Refresh**, **Clear**, and **Copy** (copies the view model as JSON, not
    prose).
- No Narcea calls, no AI text, no network access in this panel.
- Do not change the existing Show Causal Chain button or dialog.

## Tests

1. `tests/test_vg_evidence_view.gd` (headless, both engines where it runs
   VG). Build static reports with `analyze()`. Take runs from real
   `vg_evidence_start` / `snapshot` on small inline fixtures, not hand-written
   dictionaries, except for the stale and dropped cases. Cover:
   - observed root, observed callback, observed watched write with the right line;
   - write to an unwatched variable gives `not_recorded`;
   - recorder off gives `unknown` everywhere;
   - dropped events give `unknown`;
   - edited source gives `stale` on every row;
   - suppressed `reentrant` shows in root `detail` and is not counted as a fire;
   - missing callback gives `missing`;
   - a guard row is always `not_recorded`;
   - all rows carry `file` and `line > 0` or `location_known: false`.
2. Transport routing: call `vg_debugger_plugin.gd`'s `_capture` with
   `"visualgasic:evidence_data"` and a snapshot. Assert the signal fires with
   the same dictionary. Assert the in-memory copy clears on a simulated session
   start.
3. Panel smoke (headless): instantiate the Code Navigator section with a fake
   source and caret on `Caverns.vg`'s line 71 equivalent, in an **inline copy**
   of the Whenever block. Assert:
   - the header text;
   - the four empty states;
   - that no row shows `observed` when the run is `{}`.
4. Task 0 tests (above).
5. Crystal Caverns check: extend **a new file**
   `samples/showcases/crystal_caverns/evidence_panel_scenario.gd`. Do not edit
   the protected `evidence_exit_scenario.gd`. Drive six real pickups, as the exit
   scenario does, with `crystals` and `exitOpen` watched. Assert `build_view()`
   for `UnlockExit` gives:
   - root `observed`, `fire_count` 1;
   - callback `OnUnlockExit` `observed`;
   - the `exitOpen = True` write row `observed` at its real line;
   - `PlayCue`-style calls `not_recorded`.

   Both engines.

## Acceptance

On Godot 4.6.1 and 4.7.2, exit 0:

- the new tests;
- `tests/test_vg_behavior_ring.gd` (148);
- `tests/test_vg_protected_expectations.gd` (63);
- `tests/test_vg_causal_chain.gd` (8/8 + 30/30);
- Crystal Caverns `evidence_exit_scenario.gd` (32, still `expectation=accepted`),
  `save_format_scenario.gd` (11), and `editor_regression.gd` (226);
- `./run_test_suite.sh --vg-only` (1283 or more, 0 failed).

Also do one manual run, and describe it in your report rather than claiming it:

1. Open Crystal Caverns in the editor.
2. Enable Record runs and watch `crystals` and `exitOpen`.
3. Play, collect six crystals, and stop the game.
4. With the caret on line 71, report what the panel showed while running and
   after stopping.

Report anything that did not match.

With recording off, performance must not change: no polling and no extra
allocation on the assignment path. Run `scripts/benchmark_regression_check.sh`
once and report the numbers. It is noisy; do not chase run-to-run swings.

## Known behavior to show, not fix

**Re-entrant Whenever skip.** An assignment made inside a Whenever callback does
not evaluate other sections, and those sections keep a stale `last_value`. The
panel must display the `whenever_suppressed reason=reentrant` events honestly.
Do not change that runtime behavior in this phase; it is tracked in issue #23.

`Throttle` is parsed and ignored. If the caret section uses it, list that under
limitations.

## Explicitly excluded

Change card, rollback, and Narcea integration (Phase 5); per-procedure entry
events; branch events; writing snapshots to disk; cross-file callback
resolution; the experimental IDE or Context Rail; colour-only status;
natural-language summaries; release packaging.
