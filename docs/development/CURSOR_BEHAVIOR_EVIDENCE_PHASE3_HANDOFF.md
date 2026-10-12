# Cursor handoff: Behavior Evidence Phase 3 (checks the AI cannot edit)

Phases 1 and 2 are committed (`4b831079`, `d8e76444`). VG can now show what code *could* do and record what it *did* do. Phase 3 makes the user's pass/fail checks trustworthy: Narcea must not be able to make a failing check pass by editing the check.

Background and evidence rules: [CURSOR_BEHAVIOR_EVIDENCE_HANDOFF.md](./CURSOR_BEHAVIOR_EVIDENCE_HANDOFF.md). Runtime ring: [CURSOR_BEHAVIOR_EVIDENCE_PHASE2_HANDOFF.md](./CURSOR_BEHAVIOR_EVIDENCE_PHASE2_HANDOFF.md). This document only covers Phase 3.

## Ground rules

- Do **not** edit, stage, or revert: `.github/copilot-instructions.md`, `samples/showcases/crystal_caverns/Caverns.vg`, `VisualEffects.vg`, `main.tscn`.
- `Caverns.vg` is the code under test. It must stay editable by Narcea. Only the checks and their machinery are protected.
- Do not commit or push. Copilot reviews first.
- Not in this phase: the evidence panel (Phase 4), the change card (Phase 5), rollback redesign, new chat personas.
- Write failing tests first.
- Enforcement must be in code. A line in Narcea's system prompt is optional and does not count as protection.

## What exists today

| Piece | Location | Fact |
|---|---|---|
| Write chokepoint | `addons/visual_gasic/vg_ai_safe_write.gd` | `is_safe()` / `write()`: project-root check, `..` rejection, `FORBIDDEN_GLOBS` (`.git`, `.godot`, `addons/visual_gasic`, audit log), audit to `user://vg_ai_audit.log` |
| Tool dispatcher | `addons/visual_gasic/vg_ai_tools.gd` | 33 `_do_*` tools. `write_file` goes through SafeWrite. Undo snapshots restore and delete files directly (`_apply_snapshot` ~288, `DirAccess.remove_absolute` ~312) |
| Editor-buffer edits | `vg_ai_tools.gd` `_do_insert_text` (~777), `_do_replace_range` (~810), `_do_replace_in_buffer` (~845) | Change the open script editor buffer. No file write, so SafeWrite never sees them. The user's next save persists them |
| Patch / code / project specs | `vg_ai_patch_spec.gd` `plan`/`apply`, `vg_ai_code_spec.gd` `apply`, `vg_ai_project_spec.gd` | Take a `safe_writer` |
| Direct writes that bypass SafeWrite | `vg_ai_help.gd` `_write_vg_file` (~3192) and inline writes (~3074, ~5471, ~5506); `vg_ai_help.gd` undo delete (~3777); `vg_ai_repair.gd` `_on_apply` (~528); `vg_ai_tools.gd` `restore_addon` (~1556) | Raw `FileAccess.open(..., WRITE)` / `DirAccess.remove_absolute` |
| Diff UI | `addons/visual_gasic/vg_ai_diff_dialog.gd`, `vg_ai_help.gd` `_show_diff_dialog` (~5887), `_ask_apply_mutations` (~7150), `_apply_mutations` (~7257) | Existing user-confirmation path |
| Existing tests | `tests/test_vg_patch_spec.gd`, `tests/test_vg_tool_write_normalization.gd`, Narcea golden Tier A/B (`scripts/run_narcea_golden.sh`) | Must keep passing |

Verify each line number before relying on it; search for any other AI-reachable `FileAccess.WRITE`, `store_string`, `store_buffer`, `DirAccess.remove*`, `rename*`, `copy*`, `ResourceSaver.save`, or editor-buffer `set_text` / `insert_text*` / `set_line` calls in the `vg_ai_*` and `vg_narcea_*` files. List every one you found in your report and say how it is guarded.

## What to build

### A. Expectation manifest

A per-project file, `res://vg_expectations.json`:

```text
{
  schema: "vg-expectations/1",
  protected: [
    { path: "res://evidence_exit_scenario.gd", sha256: "<hex>", accepted_at: "<ISO-8601>", note: "exit opens at 6 crystals" },
    ...
  ]
}
```

- Paths are `res://`-relative, compared after normalising (`ProjectSettings.globalize_path`, simplify, case-insensitive on Windows/macOS).
- `sha256` is the SHA-256 of the file bytes the user last accepted.
- The manifest itself is always protected, even if it does not list itself.
- A directory entry (path ending in `/`) protects everything under it.
- Missing manifest = nothing protected (existing projects are unaffected).

Add a small helper, `addons/visual_gasic/vg_expectations.gd` (RefCounted, no editor dependencies, usable headless):

- `load_manifest(project_root) -> Dictionary`
- `is_protected(path) -> bool`
- `status(path) -> String`: `accepted` (hash matches), `modified` (hash differs), `missing` (listed but the file is gone), `unprotected`
- `propose_change(path, new_bytes_or_text, reason) -> String` returns a proposal id. Stores the pending proposal in memory only.
- `pending() -> Array`
- `accept(proposal_id) -> Array` (`[ok, msg]`): writes the file, updates its `sha256` and `accepted_at`, saves the manifest, audits `EXPECTATION_ACCEPTED`.
- `reject(proposal_id)`
- `accept_current(path)`: the user's "I edited this by hand on purpose" action. Re-hashes and saves.

`accept`, `accept_current`, and `reject` are **user actions**. They must not be reachable from the Narcea tool dispatcher, function-calling schema, or any AI-driven apply path. A test must prove the dispatcher has no route to them.

### B. Enforcement

1. `vg_ai_safe_write.gd`: `is_safe()` refuses protected paths with the message `protected expectation: <path>`. Audit as `BLOCK_EXPECTATION`. This covers write, overwrite, and creating a protected file that does not exist yet.
2. Route every bypass found above through SafeWrite, or through `vg_expectations.is_protected()` if SafeWrite does not fit (for example `restore_addon`, which writes under the addon). Undo/restore may not write or delete a protected file.
3. Delete, rename, move, and copy-onto a protected path are refused the same way.
4. Editor-buffer tools (`insert_text`, `replace_range`, `replace_in_buffer`, and any others you find) refuse when the open buffer's path is protected. Return `[<tool>] REFUSED: protected expectation: <path>`.
5. Multi-file applies are atomic with respect to protection. If a patch, code spec, project spec, or mutation batch touches any protected path, refuse the whole batch before writing anything, and say which path caused it. Do not apply the unprotected half.
6. The refusal text returned to the model says the expectation can only be changed with `propose_expectation_change`. Do not describe or hint at any bypass.

### C. The "change the expectation" path

- Add one Narcea tool, `propose_expectation_change {path, contents, reason}`. It calls `propose_change` and returns the proposal id. It writes nothing.
- In the editor, a pending proposal opens a confirmation dialog through `vg_ai_diff_dialog.gd`, kept separate from any code-change dialog. Its title is "Change a protected expectation". It shows the reason, the path, and the full diff of that one file. Buttons: Accept / Reject. Accept calls `accept`. Reject calls `reject`.
- A code change and an expectation change are never in the same dialog or the same Accept click. If Narcea sends both in one reply, the code change goes through the normal dialog and the expectation change becomes its own pending proposal.
- Approval mode / auto-apply settings (see `_save_approval_mode`, `_auto_apply_code_spec_no_dialog`) must never auto-accept an expectation proposal.

### D. Checks report their own integrity

Both protected checks print their manifest status next to their result, and a modified check does not report a clean pass:

- `evidence_exit_scenario.gd`: before running, read the manifest. If its own status is not `accepted`, print `[EXPECTATION MODIFIED] evidence_exit_scenario.gd` and exit non-zero even if every assertion passes. `unprotected` (no manifest) keeps today's behaviour, so the repo's own CI still works without one.
- Formatter save check: move the save-behaviour fixture that Phase 1 added to `editor_regression.gd` into its own file, `samples/showcases/crystal_caverns/save_format_scenario.gd`. Put the expected bytes in that file as plain constants. `editor_regression.gd` must call it so the editor total stays **226**. Apply the same integrity rule.

### E. Protect the Crystal Caverns checks

Create `samples/showcases/crystal_caverns/vg_expectations.json` protecting:

- `res://evidence_exit_scenario.gd`
- `res://save_format_scenario.gd`
- `res://vg_expectations.json` (implicit, but list it so it is visible)

Do not protect `Caverns.vg`, `VisualEffects.vg`, `main.tscn`, or `regression.gd`.

The runtime recorder and the causal chain live under `addons/visual_gasic/`, which SafeWrite already forbids. Confirm with a test that the AI cannot write `vg_causal_chain.gd` or edit it in an open buffer while addon editing is locked. When addon editing is unlocked (`enable_addon_editing`), `vg_expectations.gd` and `vg_ai_safe_write.gd` stay refused. Unlocking the addon must not unlock the guard itself.

## Tests and acceptance

New headless suite `tests/test_vg_protected_expectations.gd`. Use a temporary project root under `user://`, never the real Caverns directory:

- SafeWrite refuses write, overwrite, and create for a protected file and for a file inside a protected directory. Unprotected files still write.
- Path tricks are refused: `res://` vs absolute, `./`, doubled slashes, a different case on case-insensitive platforms, and a symlink into a protected path where the OS supports it.
- The manifest is refused even when it does not list itself.
- Delete, rename, and undo-restore of a protected file are refused.
- Each bypass you rerouted is exercised once and refused.
- Each buffer tool refuses when the buffer path is protected. Fake the editor if needed, but test the guard function the tools call.
- A patch spec touching one protected and one unprotected file writes neither.
- `propose_expectation_change` writes nothing and creates one pending proposal. `accept` writes it and updates the hash. `reject` leaves the file unchanged.
- The tool dispatcher and function-calling schema have no route to `accept`, `accept_current`, or `reject`.
- Auto-apply / approval-mode settings do not accept a proposal.
- `status()` returns accepted / modified / missing / unprotected correctly. `accept_current` turns modified into accepted.
- `enable_addon_editing` does not unlock `vg_expectations.gd` or `vg_ai_safe_write.gd`.
- Every BLOCK and ACCEPT appears in the audit log.

Integrity checks (both Godot versions):

- With the manifest in place and untouched: `evidence_exit_scenario.gd` 32/32 and `save_format_scenario.gd` pass, and `editor_regression.gd` is still 226/226.
- Change one expected constant in a temp copy without accepting it: the scenario prints `[EXPECTATION MODIFIED]` and exits non-zero.
- After `accept_current`, it passes again.

Must still pass, unchanged:

- `tests/test_vg_behavior_ring.gd` 148/148 and `tests/test_vg_causal_chain.gd` (8/8 legacy, 30/30 evidence) on 4.6.1 and 4.7.2.
- `tests/test_vg_patch_spec.gd`, `tests/test_vg_tool_write_normalization.gd`.
- `run_test_suite.sh --vg-only`: 223 files, 1283 passed, or more if you add VG tests.
- Narcea golden Tier A and Tier B: `bash scripts/run_narcea_golden.sh --tier A` and `--tier B`.

This phase is GDScript only. If you change C++, say why and rebuild the Linux editor and template_debug libraries.

## Report back

1. Files changed and why, one line each.
2. Every AI-reachable write/delete/buffer-edit site you found, and how each is now guarded.
3. Test counts per suite, per Godot version.
4. Anything you could not guard, and why.
5. Any existing behaviour you think is a bug but did not change, with a repro.
