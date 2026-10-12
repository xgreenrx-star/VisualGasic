# Cursor handoff: behavior evidence, Phase 5 (change card and rollback)

## Assignment and stop boundary

After Narcea applies a change, show the user one **change card** that answers:

1. What did Narcea say it did? (model text, unverified)
2. Which files did it actually touch? (facts from the write path)
3. What can the changed code now do? (static Whenever chain, before vs after)
4. What has been observed since the change? (runtime ring)
5. Do my protected expectations still pass? (user-owned scenarios)
6. How do I undo it without losing my own later edits? (rollback)

Write failing tests first, implement, validate, and return a scoped diff with
exact test results. Do not commit or push.

Not in this phase:
- pilot measurement;
- release packaging;
- a new chat persona;
- changes to the standalone VG IDE shell or Context Rail;
- AI-written explanations of the diff;
- replacing the legacy Undo buttons (see "Legacy undo").

## Baseline and user work

Handoff baseline: `fbd52e34` on main (Whenever re-entrancy fix, #23), recorded
October 12, 2026. Check HEAD and the worktree again before editing.

These files contain user edits. Do not revert, stage, or rewrite them:

- `.github/copilot-instructions.md`
- `samples/showcases/crystal_caverns/Caverns.vg`
- `samples/showcases/crystal_caverns/VisualEffects.vg`
- `samples/showcases/crystal_caverns/main.tscn`

Do not edit the protected scenarios (`evidence_exit_scenario.gd`,
`save_format_scenario.gd`) or `samples/showcases/crystal_caverns/vg_expectations.json`.
If a test needs a protected manifest, build one in a temp project.

## What exists today (read before designing)

- **Single write chokepoint:** `addons/visual_gasic/vg_ai_safe_write.gd`.
  It exposes `write`, `remove`, `rename_path`, and `copy_onto`, each gated by
  `is_safe`. `write()` takes a `String` only, so binary assets cannot pass
  through it today. This file is a guard script and is protected from
  Narcea, not from you.
- **Two unrelated undo stacks, both lossy:**
  - `vg_ai_help.gd` `_undo_capture` / `_on_undo_last_edit` (~3730–3800) is
    used by Make code, Make patch, Make test, and WN graph. It snapshots text
    with `get_as_text()`, and an empty `old` is treated as "did not exist", so
    an empty file that existed gets deleted on undo. It overwrites whatever is
    on disk, including the user's later edits.
  - `vg_ai_tools.gd` `execute_mutation_with_undo` / `_snapshot_for`
    (~266–440) covers buffer tools and `save_file` only. `write_file`,
    `build_form`, and scene loaders get no snapshot.
- **Apply points that write without either undo:** `_on_make_project`
  (~5739), the raw fallback `_write_vg_file` (~3187, writes with
  `FileAccess` directly after an expectations check),
  `vg_ai_project_spec.gd` (~784), and `restore_addon` (`vg_ai_tools.gd`
  ~1552–1590, writes with `FileAccess` directly).
- **Static chain:** `vg_causal_chain.gd` `analyze(text, roots, source_path,
  force_engine)` returns evidence schema 1 (Phase 1).
- **Runtime evidence:** `vg_debugger_plugin.gd` keeps the last
  `behavior-run/1` snapshot in editor memory. `vg_evidence_view.gd`
  `build_view()` turns it into rows with status words (Phase 4).
- **Expectations:** `vg_expectations.gd` loads `vg_expectations.json`
  (`vg-expectations/1`, entries with `path`, `sha256`, `note`). Scenario
  scripts print one result line, e.g.
  `[PASS] evidence_exit_scenario.gd (32/32, both engines) expectation=accepted`
  or `[FAIL] … expectation=…`.

## Task A: change-set recorder (rollback foundation)

New `addons/visual_gasic/vg_change_set.gd`. Add it to the guard-script list
that SafeWrite and `restore_addon` refuse (same as `vg_expectations.gd`), and
add a test for that.

1. **Open and close:** `begin(label, source)` returns an id; `end()` freezes
   the set. `source` is one of `make_code`, `make_patch`, `make_project`,
   `make_test`, `wn_graph`, `tool_approval`, `raw_fallback`, or `restore_addon`.
   Calls made outside an open set are not recorded. Report every apply point
   you could not wrap.
2. **Record at the chokepoint.** While a set is open, SafeWrite (or a thin
   wrapper it calls) records each mutation **before** performing it:
   - `write`: `path`, `existed`, pre-bytes (`FileAccess.get_file_as_bytes`),
     pre SHA-256. After the write, record the post SHA-256.
   - `remove`: `existed=true`, pre-bytes and hash, post `deleted`.
   - `rename_path`: both paths, plus the pre-bytes of an overwritten target.
   - `copy_onto`: as `write` for the target.
   - Directories created by `write`: record them so rollback can remove them
     when they are empty.
   Record by **bytes**, never by text, so `.png`, `.wav`, `.res`, `.scn`, and
   `.tscn` round-trip exactly. Add `write_bytes(path, PackedByteArray)` to
   SafeWrite (same gating and audit) so binary assets can go through the
   chokepoint.
3. **Route the bypasses:** `_write_vg_file` raw fallback and
   `vg_ai_project_spec.gd` must write through SafeWrite (or record into the
   open set before their direct write). Apply the same to `restore_addon`'s
   file writes. List anything that still writes outside SafeWrite inside a
   Narcea apply (for example C++ form-designer `ResourceSaver` saves) in the
   report and on the card as `not tracked`.
4. **Persistence:** store each set in
   `user://vg_change_sets/<id>/manifest.json` plus `pre/<n>.bin`. Keep the
   last 10 sets and prune older ones. Never write inside `res://`. A set
   survives an editor restart.
5. **Rollback** `rollback(id) -> Dictionary`:
   - Process entries in reverse order.
   - **Conflict check first, for every entry, before touching anything.** The
     current file must match the recorded post-state (same SHA-256, or still
     absent for a delete). If any entry conflicts, change nothing and return
     `status: "conflict"` with every conflicting path and the reason
     (`edited after change`, `deleted after change`, `recreated after change`).
     Do not offer a partial rollback in this phase.
   - An open editor tab with unsaved changes to a touched path is a
     conflict (`unsaved editor changes`).
   - Restore pre-bytes, delete files that did not exist, reverse renames, and
     remove recorded directories only if they are empty.
   - Writes go through SafeWrite with `set_root("res://")`. A protected path
     refusal is reported, not bypassed.
   - Rescan the filesystem and reload open scripts that changed.
   - A rolled-back set is marked `rolled_back` and cannot be rolled back
     again.
6. **What rollback does not reverse** (shown on the card, verbatim facts):
   game runs, `user://` data, network calls, external tools, editor
   buffer-only edits, and anything listed as `not tracked`.

## Task B: change card model

New `addons/visual_gasic/vg_change_card.gd` with a pure
`build_card(change_set, inputs) -> Dictionary`, testable headless like
`vg_evidence_view.gd`. `inputs` carries:
- the model's reply text;
- before and after text of changed `.vg` files (from the set's pre-bytes and
  the current disk);
- the current evidence snapshot;
- the expectation results.

Sections stay separate and each carries its `source` label. Never merge or
paraphrase across sections.

| Section | `source` | Content |
|---|---|---|
| `claim` | `model` | Narcea's reply summary, verbatim, truncated at 600 chars. Label: "Narcea says (not verified)". |
| `files` | `write_path` | One row per path: `created` / `modified` / `deleted` / `renamed` / `not tracked`, byte size before and after, `binary` flag, line delta for text. |
| `static` | `compiler` | For each changed `.vg`, run `vg_causal_chain.analyze` on before and after. Compare Whenever roots by section name: `added`, `removed`, `trigger changed` (variable, operator, target), `callbacks changed`, `writes changed` (variable, procedure), `unchanged`. Carry `engine` and the possible-behavior limitation. |
| `observed` | `runtime` | For each changed `.vg`: `not run since change` when the snapshot's script hash ≠ the after-hash or no snapshot exists; otherwise a summary from `build_view()` (fires, writes, suppressions) with the run id. |
| `expectations` | `user` | One row per protected scenario: `not run`, `running`, `pass`, `fail`, `incomplete`, or `stale` (run happened before the change was applied, or the scenario's hash ≠ manifest). Show the scenario's `note`. |
| `rollback` | `write_path` | `available`, `conflict` (with paths and reasons), `rolled_back`, or `unavailable` (the reason, e.g. set pruned), plus the "does not reverse" list. |

Card-level rules:
- No overall "safe" or "success" verdict. With no expectations, the
  expectations section says `No protected expectations in this project.`
  and nothing else.
- If any file is `not tracked`, the rollback section says rollback is
  incomplete and names the files.
- Status words, never colour-only meaning.

## Task C: running expectations

`vg_change_card.gd` (or a small runner next to it) runs each protected
scenario headless in a **separate process**:
- binary: `OS.get_executable_path()`;
- arguments: `--headless --path <project> --script <scenario>`;
- use `OS.execute_with_pipe` and poll `OS.is_process_running` from a timer,
  so the editor never blocks.
- Parse the last `[PASS] <name>` or `[FAIL] <name>` line.
- No result line, a crash, or a 120 s timeout is `incomplete`. Kill the
  process on timeout.
- Run the scenarios one at a time.
- Cap captured output at 64 KB per scenario. Keep the last 40 lines for the
  card's detail view.
- Never pass the model's text or any AI-generated argument to the process.
  The scenario list comes only from the manifest.

## Task D: UI

- In the Code Navigator dock, below the Behavior evidence panel, add a
  collapsible **Last change** section that renders `build_card()` for the
  most recent change set. Controls:
  - Run checks (Task C);
  - Roll back (Task A, with a confirm dialog listing every path);
  - Copy (plain text of the card);
  - Previous / Next (browse the 10 stored sets).
- In the Narcea chat, after each apply, append one line with a
  `[url=vg_change_card]Review change[/url]` link that opens and focuses that
  section. Keep the existing Undo / Keep links working.
- After rollback, the card re-renders from disk and shows `rolled_back`.
- Nothing on the card calls a model.

## Legacy undo

Do not remove or rewrite the existing Undo buttons. Apply one change to both
legacy file-undo paths (`_on_undo_last_edit` and `_apply_snapshot` kind
`file`): if a change set also covers that path and its current hash ≠ the
recorded post-hash, refuse with `Refused: <path> was edited after the change.
Use Roll back in Code Navigator to see conflicts.` Buffer-only undo is
unchanged.

## Tests (write first, confirm they fail)

1. `tests/test_vg_change_set.gd` (headless, temp project under `user://`):
   - text write, binary write (bytes with `\0` and invalid UTF-8), create,
     delete, rename, overwrite-by-rename, `copy_onto`, created dir;
   - rollback restores bytes exactly (compare SHA-256), deletes created
     files, and removes the empty created dir but keeps a non-empty one;
   - an empty file that existed before is restored as empty, not deleted;
   - conflict: user edits one file after the change → nothing changes and every
     conflicting path is reported; same for deleted-after and
     recreated-after;
   - a second rollback is refused;
   - persistence: reload the manifest from disk and roll back from it;
   - pruning keeps 10;
   - a protected path inside a set is reported, not bypassed;
   - `vg_change_set.gd` is refused as a write target (guard script).
2. `tests/test_vg_change_card.gd`: `build_card()` on inline fixtures:
   - `claim` is verbatim and labeled `model`;
   - the static diff reports `added`, `removed`, and `trigger changed`
     (for example `Becomes GEM_TARGET` → `Becomes 5`), `callbacks changed`,
     and `writes changed`;
   - observed is `not run since change` on a hash mismatch;
   - expectation statuses `not run`, `pass`, `fail`, `incomplete`, `stale`;
   - no-expectations text;
   - `not tracked` makes rollback incomplete;
   - no "safe" or "success" wording anywhere in the output.
3. `tests/test_vg_change_runner.gd`: run a tiny passing scenario, a failing
   one, one that never prints a result line, and one that hangs (shorten the
   timeout through a test hook). Check pass / fail / incomplete / incomplete,
   and that the hung process is gone.
4. `samples/showcases/crystal_caverns/change_card_scenario.gd`, using a temp
   copy of the game, not the real files:
   - Open a set, apply a SafeWrite change to the copy's `Caverns.vg` that
     rewrites line 71 from `crystals Becomes GEM_TARGET OnUnlockExit` to
     `crystals Becomes 5 OnUnlockExit`, and close the set.
   - The card shows `trigger changed` for `UnlockExit` (target
     `GEM_TARGET` → `5`), observed `not run since change`, and the copied
     exit scenario as `fail` after Run checks. If the scenario still passes,
     report that rather than changing the scenario.
   - Roll back: the file is byte-identical to before and the scenario passes
     again.
   - Repeat with a user edit after the change and expect `conflict`, with
     the file unchanged.
   If the copied scenario cannot run outside its project, build a minimal
   temp project with its own manifest instead. Do not change the protected
   originals.
5. Legacy undo refusal: one check for each of the two legacy paths.

## Validation (report exact counts)

Run on Godot 4.6.1 (`./Godot_v4.6.1-stable_linux.x86_64`) and 4.7.2
(`/home/Commodore/Downloads/Godot_v4.7.2-stable_linux.x86_64`). No C++
change is expected; if you make one, rebuild the Linux editor and
template_debug libraries and say why.

- The new tests above.
- Earlier suites, unchanged counts:
  - `tests/test_vg_behavior_ring.gd` 160;
  - `test_vg_evidence_view.gd` 134;
  - `test_vg_evidence_panel.gd` 9;
  - `test_vg_evidence_autostart.gd` 13;
  - `test_vg_evidence_transport.gd` with `--headless --editor`, 9;
  - `test_vg_protected_expectations.gd` 63;
  - `test_vg_causal_chain.gd` 8 + 30.
- In `samples/showcases/crystal_caverns`, unchanged counts:
  - `evidence_exit_scenario.gd` 32, accepted;
  - `evidence_panel_scenario.gd` 18;
  - `save_format_scenario.gd` 11, accepted;
  - `editor_regression.gd` 226/0.
- `./run_test_suite.sh --vg-only` (baseline 1295 passed).
- `bash scripts/run_narcea_golden.sh --tier A` and `--tier B`.
- `git status` showing the user's four files and `vg_expectations.json` were
  not modified by your work.

## Manual check (describe what you saw; the user cannot test now)

1. Open Crystal Caverns in the editor.
2. Ask Narcea for a one-line change to a copy of a `.vg` file, approve it,
   and click Review change.
3. Click Run checks, then Roll back.
4. Report what each section showed.

If you cannot run the editor UI, say so plainly. Do not describe it as done.

## Report back

- Files changed and why, one line each.
- Every apply point and whether it is wrapped, and every path that is still
  `not tracked`.
- Every count from Validation, per Godot version.
- The exact text of the card for the Crystal Caverns scenario
  (Copy output), before and after rollback.
- Behavior you found and left as-is, with a repro.
