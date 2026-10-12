# Cursor handoff: Behavior Evidence Phase 2 (runtime "did-happen" ring)

Phase 1 is committed (`4b831079`). It answers "what *could* happen" from source. Phase 2 answers "what *did* happen" during one run, so a reviewer can compare the two instead of trusting a narrative.

Read [CURSOR_BEHAVIOR_EVIDENCE_HANDOFF.md](./CURSOR_BEHAVIOR_EVIDENCE_HANDOFF.md) first for the overall direction, the evidence rules, and the exclusions. This document only covers Phase 2.

## Ground rules

- Do **not** edit, stage, or revert these user-owned files: `.github/copilot-instructions.md`, `samples/showcases/crystal_caverns/Caverns.vg`, `samples/showcases/crystal_caverns/VisualEffects.vg`, `samples/showcases/crystal_caverns/main.tscn`. If the scenario cannot be written without changing them, stop and report.
- Do not commit or push. Copilot reviews first.
- Do not build the panel, the change card, Narcea integration, file protection, or editor transport. Those are Phases 3–5.
- Write the failing tests first, then implement.
- If a fact cannot be observed, record it as unknown. Never fill a gap with a guess (line `0` + `location_known: false`, not a nearby line).

## Where the runtime hooks are

There is one choke point for variable-watch `Whenever` sections and one for expression sections. Both engines already reach them:

| Path | Location |
|---|---|
| AST assignment | `VisualGasicInstance::assign_variable` in `src/visual_gasic_instance_call.inc` (~line 2099), which ends by calling `check_whenever_conditions(name, val)` then `check_expression_conditions()` |
| Bytecode store | `src/visual_gasic_instance_bytecode_vm.cpp` ~line 2452: "Trigger Whenever system (must match assign_variable behavior)" |
| Variable-watch evaluation | `check_whenever_conditions` (`visual_gasic_instance_call.inc` ~2219): `Changes`, `Becomes`, `Exceeds`, `Below`, `Between`, `Contains`, debounce, re-entrancy guard, callback loop |
| Expression evaluation | `check_expression_conditions` (~2328): edge-triggered false→true |
| Section struct | `WheneverSection` in `src/visual_gasic_instance.h` (~214). It has **no source line** today |
| Bytecode registration | `OP_REGISTER_WHENEVER` (VM ~7453) reads a Dictionary built by the compiler (`src/visual_gasic_compiler.cpp` ~8566) |
| Fast-path caveat | `needs_var_sync` (`visual_gasic_instance.h` ~241). When false, bytecode `SET_LOCAL`/`GET_LOCAL` skip the `variables[]` sync, so a plain watched write may never reach a hook |

Phase 1 already put a 1-based `line` on the `Whenever` AST statement. Carry it into `WheneverSection` (AST registration) and into the compiler's section Dictionary (bytecode registration) so a fire can point back to its declaration in both modes.

## What to build

### A. Recorder

One recorder per game process, shared by all VG script instances, so `Caverns.vg` and `VisualEffects.vg` events land in one ordered stream.

- **Off by default.** When off, the hot path cost is a single boolean check. No string building, no allocation.
- **Project settings** (register next to the `vg/narcea/live_debug_capture*` settings in `visual_gasic_plugin.gd` ~11871):
  - `vg/evidence/runtime_ring` — bool, default `false`
  - `vg/evidence/runtime_ring_capacity` — int, default `512`, range `64,4096`
  - `vg/evidence/watch` — `PackedStringArray`, default empty (module-level variable names, case-insensitive)
- **Script API** on `VisualGasicLanguage`, following the `vg_analyze_causal_graph` pattern used by `vg_causal_chain.gd` (~702):
  - `vg_evidence_start(config: Dictionary) -> String` returns the new `run_id`. Config may override capacity and watch list (tests use this instead of project settings).
  - `vg_evidence_snapshot() -> Dictionary` returns the current record (format below). Does not clear.
  - `vg_evidence_stop()` stops recording **and wipes** the buffer.
  - Game exit, scene quit, and recorder restart also wipe. Nothing is written to disk.
- **Ring semantics:** fixed capacity, keeps the newest events. Every event gets a monotonic `seq`. Track `dropped` (count of evicted events) so gaps are visible and never silent.
- **Value capture:** bounded and non-invasive. Scalars as-is. Strings truncated to 120 chars with a `truncated: true` flag. Arrays/Dictionaries as `{type, size}` only. Objects as `{class, instance_id}`. Never call user code (no `ToString`, no getters) to describe a value.

### B. Events

Exactly these kinds. Do not add others in this phase.

| `kind` | When | Fields beyond the common ones |
|---|---|---|
| `watched_write` | A module-level variable in the watch list is assigned | `variable`, `old`, `new` |
| `whenever_fired` | A section's condition is met. Callbacks run now, or after the current callback when `deferred` is true. | `section`, `variable` (or `""` for expression sections), `operator`, `target`, `old`, `new`, `declared_line`, `callbacks: [{name, resolved}]`, `deferred` |
| `whenever_suppressed` | A section matched the variable but did not run callbacks | `section`, `reason`: `debounce` or `chain_limit` |
| `callback_missing` | `call_internal` returned `found = false` for a callback | `section`, `callback` |

Common fields on every event: `seq`, `kind`, `engine` (`ast` or `bytecode`), `script_path`, `script_hash`, `procedure` (current Sub/Function, `""` at module level), `line`, `location_known`, `ticks_msec`.

Notes the tests must lock down:

- **Re-entrant detection is a deferred fire.** Issue #23 detects the condition and updates `last_value` immediately. The fire event is recorded at detection with `deferred: true`. Callbacks run after the current callback. `reason=reentrant` is not produced. A chain that dispatches more than 1000 callbacks records `whenever_suppressed reason=chain_limit`.
- **Debounce** skips also become `whenever_suppressed reason=debounce`.
- A `Becomes` re-assignment to the same value (6 → 6) is not a transition. It produces a `watched_write` (if watched) and no `whenever_fired`.
- Module-initialisation assignments run under `whenever_init_suppress`. Record them as `watched_write` only if they pass through the hook; do not invent `whenever_fired` for them.
- **Line source:** use the real executing line in both engines. Verify `debug_state.current_line` is actually maintained in bytecode mode. If it is not, either derive the line from the chunk's line table or emit `line: 0, location_known: false`. Do not reuse the AST line for a bytecode event unless you proved they match.
- **Fast path:** a watched variable with *no* `Whenever` section must still produce `watched_write` in bytecode mode. Either force the sync path for watched names while recording, or report the variable under `limitations` as `unobservable_in_bytecode`. A test must cover this case in both engines.
- Only module-level variables are watched in this phase. A local that shadows a watched name is ignored; say so in `limitations`.

### C. Snapshot format (schema `behavior-run/1`)

```text
{
  schema: "behavior-run/1",
  run_id, started_ticks_msec, vg_version, godot_version,
  recording: bool, capacity, dropped, next_seq,
  watch: [names],
  scripts: [{path, content_hash, engine}],   # content_hash = SHA-256 of exact source text as UTF-8, same as Phase 1
  events: [...],
  limitations: [strings]
}
```

`content_hash` must match what Phase 1 `analyze()` computes for the same text. That equality is how a static report and a run are tied together.

### D. Static × runtime join (small, GDScript)

Add `join_runtime(static_report: Dictionary, run: Dictionary) -> Dictionary` to `addons/visual_gasic/vg_causal_chain.gd`. Scope: `Whenever` roots and their direct callbacks only. Per root, one status:

| Status | Rule |
|---|---|
| `observed` | At least one matching `whenever_fired` |
| `not_observed` | Recorder was on for the whole run, hashes match, `dropped == 0`, and no fire |
| `unknown` | Recorder off, or `dropped > 0`, or the script was not loaded in the run |
| `stale` | `content_hash` differs between the static report and the run |
| `unresolved` | Callback is unresolved in the static report; runtime cannot upgrade it |

Include the fire count and the `seq` list of matching events. No prose summary; the panel (Phase 4) renders this.

### E. The exit scenario (first behavioral check)

New file: `samples/showcases/crystal_caverns/evidence_exit_scenario.gd`, run headless like `editor_regression.gd`. It runs the real `Caverns.vg` in **both** engines (AST and bytecode), with `crystals`, `exitOpen`, `health` watched.

The `crystals` value must rise through the game's normal pickup path (`crystals = crystals + 1` in the move/collect procedure, `Caverns.vg` ~385). Find how `regression.gd` drives movement and reuse it. Setting `crystals` directly from GDScript, or calling `OnUnlockExit` directly, does **not** count and must not appear in the test. The scenario must not depend on the player spawn position (the user moved it).

Positive check:

1. `crystals` reaches `GEM_TARGET` (6) by pickup.
2. Exactly one `whenever_fired` for `UnlockExit`, `declared_line` 71, callback `OnUnlockExit` resolved.
3. A `watched_write` of `exitOpen` False → True after that fire, `procedure = OnUnlockExit`.
4. `join_runtime` reports `UnlockExit` as `observed`.

Negative checks (each in both engines):

- Stop at 5 crystals: no `UnlockExit` fire; `join_runtime` says `not_observed`.
- Recorder off: snapshot is empty and `join_runtime` says `unknown`, not `not_observed`.
- Tiny capacity (64) with enough writes to overflow: `dropped > 0` and status becomes `unknown`.
- Edited source (hash mismatch between static report and run): `stale`.
- After `vg_evidence_stop()`, a snapshot has no events.

Phase 3 will later protect this file from AI edits. Write it so its expectations are plain constants at the top, easy to diff.

## Tests and acceptance

New suite `tests/test_vg_behavior_ring.gd` with small inline `.vg` fixtures (not `Caverns.vg`), run in both engines:

- Every operator (`Changes`, `Becomes`, `Exceeds`, `Below`, `Between`, `Contains`) fires once on its transition and not on a non-transition.
- Expression section fires on false→true only.
- Multiple callbacks, including one missing → `callback_missing`.
- Re-entrant assignment → `whenever_fired` with `deferred: true`. A chain past 1000 callbacks → `whenever_suppressed reason=chain_limit`.
- Debounce → `whenever_suppressed reason=debounce`.
- Watched variable with no section (bytecode fast path).
- Two scripts in one run share one ordered `seq` stream.
- Recorder off → no events and no allocations on the assignment path (assert the buffer stays empty and the counters stay 0).
- AST and bytecode produce the same sequence of `(kind, section, variable, old, new)` for the same fixture.

Must still pass, unchanged expectations:

- `tests/test_vg_causal_chain.gd`: 8/8 legacy, 30/30 evidence, on Godot 4.6.1 and 4.7.2 (run with `--path samples/showcases/crystal_caverns --script <absolute path>`).
- `test_proj/test_causal_chain.gd`.
- Crystal Caverns `editor_regression.gd`: 226/226 on both Godot versions.
- Full `run_test_suite.sh` regression: same pass count as before your change.
- `scripts/benchmark_regression_check.sh`: no regression beyond noise with the recorder **off**. Report the numbers.

Rebuild the Linux editor and template_debug libraries so the tests exercise the new C++.

## Report back

1. Files changed and why (one line each).
2. Test counts per suite, per engine, per Godot version.
3. Benchmark numbers before/after with the recorder off.
4. Whether bytecode line numbers are real, derived, or reported unknown, and the evidence.
5. Anything in `limitations`, and any existing behavior you think is a bug (with a repro) but did not change.
