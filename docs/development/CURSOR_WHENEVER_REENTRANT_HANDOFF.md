# Cursor handoff: fix re-entrant Whenever (issue #23)

## Assignment and stop boundary

Fix GitHub issue #23. A watched assignment made inside a `Whenever` callback is
ignored by every other section. Those sections also keep a stale `last_value`,
so they later fire when nothing changed or miss a real change.

Write failing tests first, implement the fix in both engines, validate, and
return a scoped diff with exact test results. Do not commit or push. Do not
start Phase 5 (change card and rollback), release packaging, or unrelated
Whenever features such as `Throttle`.

## Baseline and user work

Handoff baseline: `3e0856e1` on main (Phase 4 evidence panel), recorded
October 12, 2026. Check HEAD and the worktree again before editing.

These files contain user edits. Do not revert, stage, or rewrite them:

- `.github/copilot-instructions.md`
- `samples/showcases/crystal_caverns/Caverns.vg`
- `samples/showcases/crystal_caverns/VisualEffects.vg`
- `samples/showcases/crystal_caverns/main.tscn`

Do not edit protected expectations (`evidence_exit_scenario.gd`,
`save_format_scenario.gd`, `addons/visual_gasic/vg_expectations.json`).
If a protected scenario fails, report it. Do not change it.

## Repro (current behavior, both engines)

```vb
Dim a As Integer
Dim b As Integer
Dim c As Integer
Dim bFires As Integer
Dim cFires As Integer

Whenever Section WatchA a Changes OnA
Whenever Section WatchB b Becomes 1 OnB
Whenever Section WatchC c Changes OnC

Sub OnA()
    b = 1
    c = 5
End Sub

Sub OnB()
    bFires = bFires + 1
End Sub

Sub OnC()
    cFires = cFires + 1
End Sub

Sub _Ready()
    a = 1
    Print "A bFires=" & bFires & " cFires=" & cFires
    b = 1
    Print "B bFires=" & bFires
    c = 0
    Print "C cFires=" & cFires
End Sub
```

Today: `A bFires=0 cFires=0`, `B bFires=1`, `C cFires=0`.
Required: `A bFires=1 cFires=1`, `B bFires=1`, `C cFires=2`.

## Cause

`src/visual_gasic_instance_call.inc`:

- `check_whenever_conditions` (~line 2237) returns at once while
  `whenever_evaluating` is true. It records `whenever_suppressed reason=reentrant`
  and touches nothing else.
- `check_expression_conditions` (~line 2381) returns at once on the same flag.
- The flag is set around the callback loop (~2355 and ~2373, ~2424 and ~2442).

Both engines go through these two functions: the AST through
`assign_variable` (~2231), and bytecode through `OP_SET_GLOBAL` in
`src/visual_gasic_instance_bytecode_vm.cpp` (~2472).

## Required design: detect now, dispatch later

This is option A from #23, with one refinement: detection happens at the
moment of the assignment, and only callback dispatch is deferred.

1. **Detect immediately, even while a callback is running.** Run the normal
   per-section comparison (Changes, Becomes, Exceeds, Below, Between,
   Contains, expression conditions) and **always update `last_value`**,
   exactly as in the non-re-entrant path. Honor `is_active` *at assignment
   time*. This keeps the documented pattern in
   `docs/VisualGasic_Language_Reference.md` (~line 2995) working:
   `Suspend Whenever X` → assign → `Resume Whenever X` must not fire `X`.
2. **Defer dispatch.** If a condition is met while `whenever_evaluating` is
   true, do not call the callbacks. Push a pending entry (section index plus the
   callback names captured now) onto a FIFO queue on the instance. Apply debounce
   and `has_fired`/`last_trigger_time` at detection time, the same as today's
   fire path.
3. **Drain at the outermost level.** The outermost call (the one that set
   `whenever_evaluating`) runs its own callbacks, then drains the queue in
   FIFO order with the flag still set. Assignments made by drained callbacks
   enqueue more entries, and they drain in the same loop. Clear the flag only
   when the queue is empty.
4. **Chain limit.** Infinite chains are possible, for example
   `x Changes` → `x = x + 1`. Stop after a fixed limit (suggested: 1000
   dispatched callbacks per outermost drain). On hitting the limit:
   - clear the queue;
   - raise a clear VG runtime error that names the section and says the
     Whenever chain limit was reached, with the line of the assignment;
   - record `whenever_suppressed reason=chain_limit`.

   Pick the constant, document it, and test it.
5. **Error safety.** If a callback raises a runtime error, or an `Exit`/`End`
   unwinds through the dispatch, the flag must not stay stuck at `true` and the
   queue must not leak into the next assignment. Check how `call_internal`
   reports errors in both engines, and test one erroring callback followed by a
   normal watched assignment.
6. Keep `whenever_init_suppress` behavior exactly as it is.

Do not add nested immediate dispatch (option C). Do not implement option B
alone.

## Evidence ring changes

`src/visual_gasic_evidence.{h,cpp}` and the call sites above:

- A re-entrant detection that queues a dispatch records `whenever_fired` at
  detection time, with the assignment's line and engine. Add `deferred: true`
  to that event. Non-deferred fires either omit the field or set it to false;
  pick one and keep it consistent.
- Callback-missing events are recorded when a dispatch actually runs.
- `reason=reentrant` is no longer produced. `reason=chain_limit` is new.
  `debounce` is unchanged.
- Update `docs/development/CURSOR_BEHAVIOR_EVIDENCE_PHASE2_HANDOFF.md` only
  if the event table there is the canonical schema reference. Otherwise
  document the schema change where `behavior-run/1` is described.
  Keep schema `behavior-run/1`; the new field and reason are additive.
- `addons/visual_gasic/vg_evidence_view.gd`: a deferred fire is a fire.
  `chain_limit` appears in `detail` the way `reentrant` did. Keep the status
  words; do not add colour-only meaning.

## Tests (write first, confirm they fail)

1. **New VG regression file** `test_proj/test_suite/test_whenever_reentrant.vg`
   using the repro above plus:
   - a Becomes transition inside a callback fires once, not again on a plain
     same-value assignment;
   - Suspend/assign/Resume inside a callback does not fire the suspended
     section;
   - a self-feeding chain (`x Changes` → `x = x + 1`) hits the chain limit,
     raises the error, and a later unrelated watched assignment still fires
     normally;
   - FIFO order: `OnA` sets `b` then `c`, so the `OnB` effect is visible before
     the `OnC` effect (record order in a string);
   - an expression-condition section triggered from inside a callback.
   Run with `VG_FORCE_AST=0` and `VG_FORCE_AST=1`; output must match.
2. **`tests/test_vg_behavior_ring.gd`**: the `REENTER` case (~line 170)
   currently locks in the bug. Change it to require that `WatchB` fires once
   with `deferred: true`, has no `reentrant` suppression, and has a known line.
   Add a `chain_limit` case. Both engines.
3. **`tests/test_vg_evidence_view.gd`** (~line 86): replace the `reentrant`
   detail check with a deferred-fire row that is `observed`, plus a
   `chain_limit` detail check.
4. Check the existing Whenever files still pass unchanged:
   `tests/test_whenever.vg`, `tests/test_whenever_enhanced.vg`,
   `tests/test_multitasking.vg`.

## Validation (report exact counts)

Run on Godot 4.6.1 (`./Godot_v4.6.1-stable_linux.x86_64`) and 4.7.2
(`/home/Commodore/Downloads/Godot_v4.7.2-stable_linux.x86_64`).
Rebuild the Linux editor and template_debug libraries first.

- New regression file, both engines.
- `tests/test_vg_behavior_ring.gd` (was 148/148).
- `tests/test_vg_evidence_view.gd` (128), `test_vg_evidence_panel.gd` (9),
  `test_vg_evidence_autostart.gd` (13).
- `tests/test_vg_evidence_transport.gd` with `--headless --editor` (9).
- `tests/test_vg_protected_expectations.gd` (63).
- `tests/test_vg_causal_chain.gd` (legacy 8, evidence 30).
- In `samples/showcases/crystal_caverns`: `evidence_exit_scenario.gd`
  (32, accepted), `evidence_panel_scenario.gd` (18),
  `save_format_scenario.gd` (11, accepted), `editor_regression.gd` (226/0).
- `./run_test_suite.sh --vg-only` (baseline 223 files, 1283 passed; the count
  rises by your new assertions).
- `bash scripts/run_narcea_golden.sh --tier A` and `--tier B`.
- `scripts/benchmark_regression_check.sh` once, recorder off. The fast path
  with no Whenever sections must cost no more than one branch. The script is
  noisy; if one workload fails, rerun once before reporting.

Template for a single file:
`$G --headless --path test_proj -s run_suite.gd -- res://test_suite/test_whenever_reentrant.vg`

## Docs

- `docs/VisualGasic_Language_Reference.md`, Whenever safety guidelines
  (~line 2990): state that assignments inside a callback are detected
  immediately and their callbacks run after the current callback finishes,
  in order. Name the chain limit. Keep the Suspend/Resume advice.
- Do not edit `docs/VisualGasic_Language_Reference_legacy.md`.

## Report back

- Files changed and why, one line each.
- The chain-limit constant and the exact error text.
- Every count from Validation, per Godot version.
- Any behavior you found and left as-is, with a repro.
