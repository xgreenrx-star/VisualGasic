# Cursor handoff: behavior evidence, in-editor UI check and pilot materials

## Assignment and stop boundary

Two deliverables:

1. **A repeatable in-editor UI check.** One command opens the real windowed
   Godot editor on a virtual display. It drives the Behavior evidence panel and
   the Last change card, asserts on what they show, saves screenshots, and exits
   non-zero on any mismatch.
2. **Pilot measurement materials** (master plan, "Pilot measurement"). Write
   the protocol, tasks, answer keys, and recording sheets. Do not recruit or run
   participants.

Write the failing checks first, implement, validate, and return a scoped diff
with exact results. Do not commit or push.

Not in this phase:
- new evidence features or panel redesign;
- release packaging;
- screenshot pixel comparison (the master plan excludes it). Screenshots are
  saved for a human to look at; assertions read widget text and state;
- running the pilot with people;
- changes to the standalone VG IDE shell or Context Rail.

## Baseline and user work

Handoff baseline: the commit that adds this file, on main (after `4f13f0c6`,
Phase 5). Check HEAD and the worktree again before editing.

These files contain user edits. Do not revert, stage, or rewrite them:

- `.github/copilot-instructions.md`
- `samples/showcases/crystal_caverns/Caverns.vg`
- `samples/showcases/crystal_caverns/VisualEffects.vg`
- `samples/showcases/crystal_caverns/main.tscn`

Do not edit `evidence_exit_scenario.gd`, `save_format_scenario.gd`, or
`samples/showcases/crystal_caverns/vg_expectations.json`.

The UI check must never write into `samples/showcases/crystal_caverns`. It works
on a temp copy, as the existing probe does.

## What exists today

A manual probe already ran successfully in the real editor (Godot 4.6.1, Xvfb,
`--rendering-driver opengl3`). Its sources are in `tools/editor_ui_probe/`:

- `zz_dump.gd`: a headless `SceneTree` script, adapted from `play()` in
  `evidence_panel_scenario.gd`. It runs six real crystal pickups on bytecode with
  the ring on and writes the `behavior-run/1` snapshot to JSON. This step is
  needed because the VG game scripts are not tool scripts and cannot run inside
  the editor.
- `plugin.cfg` and `probe.gd`: an `EditorPlugin`. It waits 12 s, then gets the
  navigator through base-control meta `visual_gasic_plugin_instance` →
  `_code_navigator`, and opens `Caverns.vg` at line 71. It makes the navigator and
  its parents visible, then steps through:
  1. evidence panel;
  2. SafeWrite change inside `CS.begin/end`, with an AI claim;
  3. `show_last_change()`;
  4. Run checks;
  5. rollback, confirmed;
  6. a byte-identity check;
  7. a conflict case.

  It saves `*_nav.png` and `*_full.png` and writes `probe_log.txt`.

The manual recipe it was run with:

```
cp -r samples/showcases/crystal_caverns /tmp/vg_ui_probe/game
# replace /tmp/vg_ui_probe/game/addons/visual_gasic with an absolute symlink to the repo addon
# set config/name to "VG UI Probe" so user:// does not collide with Crystal Caverns
# put zz_dump.gd in game/, run it headless -> /tmp/vg_ui_probe/snapshot.json
# put probe files in game/addons/zz_probe/, enable the plugin in project.godot
xvfb-run -a -s "-screen 0 1600x1000x24" $G --editor --path /tmp/vg_ui_probe/game \
  --rendering-driver opengl3 --resolution 1600x1000
```

The probe hardcodes `/tmp/vg_ui_probe/...` and only logs. It does not assert.

What the first runs found, now fixed and committed with this handoff:

- After rollback, the card re-read the restored file as "after". It then
  credited the pre-change run to the change ("run run-1: fires 0"), and static
  showed every section as unchanged. The navigator now passes "after" only when
  the disk hash equals the change's `post_hash`. Observed matches runs against
  `post_hash`.
- Observed fires came from an arbitrary section's header. It now counts
  `whenever_fired` events.
- If a run was loaded while the recorder setting was off, the banner said
  "Enable … and run the game." It now says "Recording off. Showing the last
  captured run; new runs are not recorded."
- `tests/test_vg_change_card.gd` (28) and `tests/test_vg_evidence_panel.gd` (10)
  cover these.

Seen in the run and not addressed yet (Task A must cover these):

- The rollback `ConfirmationDialog` is not in the screenshot. It is a separate
  window, not part of the editor's main viewport. Its text was read from
  `dialog_text`.
- With "after" withheld, the card shows an empty `engine:` line under Static.
  Decide whether to print `engine: not available` and test it, or leave it and
  say so in the report.
- Run checks took 44–47 s in the editor. That is under the 120 s runner
  timeout. Record the time in the report.

## Task A: `scripts/run_editor_ui_probe.sh`

1. Move the probe to a committed, parameterized form: keep `tools/editor_ui_probe/`
   or move it under `tests/editor_ui/`, and say which. Paths come from an env var
   or a generated config file in the temp project, not `/tmp` literals.
2. The script:
   - takes the Godot binary as `$1` (default `./Godot_v4.6.1-stable_linux.x86_64`);
   - builds the temp project with `mktemp -d`, using the symlinked addon and the
     renamed project, then generates the snapshot headless;
   - launches the editor under `xvfb-run` with `opengl3`, behind an overall
     `timeout`;
   - copies screenshots and the log to an output dir. The default is an
     untracked path such as `build/editor_ui_probe/<godot-version>/`; check
     `.gitignore`;
   - deletes the temp project. It also deletes the temp project's `user://`
     dir (`~/.local/share/godot/app_userdata/VG UI Probe`) at the start and the
     end;
   - exits 0 only if the probe printed its pass line and every assertion held.
3. Turn the logged facts into assertions. Each failure prints the step and the
   value it saw. At minimum:
   - **Panel:** the header begins with `UnlockExit`, contains `observed` and
     `fires 1`, and dropped is 0. The UnlockExit root row and the
     `exitOpen = True` write row are `observed`. The guard and `Exit Sub` rows
     are `not_recorded`. The banner text matches the recorder setting in the
     temp project. Pick a setting on purpose, and test both states if it's
     cheap.
   - **Card before checks:**
     - the claim label is `Narcea says (not verified)`;
     - the Files row says `modified`, `line delta 0`;
     - the Static row reads `UnlockExit | trigger changed | target GEM_TARGET -> 5`;
     - Observed reads `not run since change`;
     - both expectations read `not run`;
     - rollback reads `available`.
   - **After Run checks:** `evidence_exit_scenario.gd | fail`,
     `save_format_scenario.gd | pass`, and `_change_running` is false.
   - **Rollback:** the dialog text lists the changed path. After confirm, the
     file is byte-identical to the original. The card shows rollback
     `rolled_back`, Observed `not run since change`, and Static
     `file no longer matches this change`. No row says `removed`, and there is
     no `line delta`.
   - **Conflict:** `status: conflict` and `edited after change`. The file is
     left as the user edited it.
   - **Editor log:** no `SCRIPT ERROR`.
   - **Card output:** no `safe` or `success` substring (same rule as
     `test_vg_change_card.gd`). The claim text is excluded, because the claim
     quotes the model.
4. Screenshot the confirmation dialog. Grab the dialog window's own viewport
   texture (`_change_confirm.get_texture().get_image()`) while it is open, or
   another method that works, and describe it.
5. Run it on Godot 4.6.1 and 4.7.2
   (`/home/Commodore/Downloads/Godot_v4.7.2-stable_linux.x86_64`). Then look at
   every screenshot yourself and describe what each one shows. Do not just
   report that the files exist.
6. Add a short "In-editor UI check" note to `docs/TESTING.md` or the closest
   existing testing doc: the command, the requirements (`xvfb-run`, Mesa
   `opengl3`), and the output location.

Do not add this script to `run_test_suite.sh` (it needs a display stack and
takes minutes). Document it as a manual or pre-release check.

## Task B: pilot measurement materials

Create `docs/development/BEHAVIOR_EVIDENCE_PILOT.md`. It contains:

1. **Purpose and limits.** The pilot is a usability check of the evidence
   workflow, not proof of productivity. One outside user is a smoke test.
2. **Conditions.**
   - Baseline: the normal editor. Code Navigator and Causal Chain text are
     allowed. The Behavior evidence panel and the Last change card are not.
   - Evidence: the panel and the card are allowed.
   - Name the settings that switch the conditions.
3. **Tasks and equivalent variants.** Each task needs two variants of about the
   same difficulty, so a participant never repeats the same question across
   conditions.
   - Task A, "what opens the exit": variant A1 is the Caverns `UnlockExit`
     chain. A2 is another Whenever chain in the project with a similar depth (a
     guard, a write, a call). Check the Whenever sections in `Caverns.vg`
     (`ClockCounter`, `Hurry`, `OutOfTime`, `Crushed`) and justify the choice,
     or build a small fixture if none fits.
   - Task B, "evaluate a small change": present a prepared Narcea change (claim
     plus actual diff) where the claim and the diff disagree in one checkable
     way. Variant B1 is the GEM_TARGET → 5 change, with a claim that says
     "Everything else is unchanged" while an expectation fails. B2 is a change
     of the same size on the other chain.
4. **Counterbalancing.** A 2×2 table of condition order × variant order, with
   participant slots assigned in rotation.
5. **Answer keys.** Each fact in each key comes from a source you ran, with the
   command or test that shows it: the trigger and line, the guard, the writes,
   what the run observed, and which expectation fails. Mark observation versus
   explanation.
6. **Measures and sheet.**
   - Time to answer.
   - A correctness rubric with points per key fact.
   - An observation-vs-explanation item: participants label statements as
     "seen in a run", "possible from code", or "the AI said so".
   - A confidence rating.
   - A short free-text question about what was confusing.

   Provide the sheet as a CSV template in `docs/development/pilot/` plus a
   printable Markdown version.
7. **Facilitator script.** Setup steps (which project, which settings, how to
   reset `user://` change sets between participants), exact wording for each
   prompt, what the facilitator may and may not say, and stop times.
8. **Outside-user smoke script.** A 15-minute version of one evidence task, with
   three questions afterward.
9. **Dry run.** Run every setup step yourself from a clean temp copy and check
   that each answer-key fact matches what the panel and card show (Task A's
   probe output is acceptable evidence). Report any step that did not work
   as written.

The pilot docs must not claim results, and they must not use "safe", "proven",
or "verified" about the code under test.

## Tests and validation

Run on Godot 4.6.1 and 4.7.2 unless noted:

- `scripts/run_editor_ui_probe.sh` (both binaries)
- `tests/test_vg_change_card.gd` (28), `tests/test_vg_change_set.gd` (68),
  `tests/test_vg_change_runner.gd` (10)
- `tests/test_vg_evidence_panel.gd` (10), `tests/test_vg_evidence_view.gd` (134),
  `tests/test_vg_evidence_autostart.gd` (13),
  `tests/test_vg_evidence_transport.gd` (9, `--headless --editor`)
- `change_card_scenario.gd` (15), `evidence_panel_scenario.gd` (18) from the
  Crystal Caverns dir
- `./run_test_suite.sh --vg-only` (4.6.1, expect 1295/1295)

Headless runs use `$G --headless --path samples/showcases/crystal_caverns
--script $PWD/tests/<t>.gd`.

## Report back

- Files added or changed, with one line on each.
- Exact pass counts for every command above, per Godot version.
- For each screenshot, one sentence on what it shows. Include the dialog
  screenshot.
- Editor Run-checks duration on each version.
- The Task B variant choices, with the reason for each and the dry-run result.
- Anything that did not work as written in this handoff, and what you did
  instead.
- Confirm that the four user files and the three protected files are untouched
  (`git status --short`), and that no temp project or `user://` probe dir is left
  behind.
