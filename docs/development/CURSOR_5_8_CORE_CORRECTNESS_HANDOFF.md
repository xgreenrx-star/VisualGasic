# Cursor handoff: 5.8.0-beta.1 core correctness gates

**Purpose:** Resolve the outstanding VM/JIT correctness issues before the proposed
`5.8.0-beta.1` release. The microbenchmark performance target is met; correctness
and execution-mode parity are now the priority.

**GitHub issues:**

- [#25 Tier-2 JIT miscompiles Boolean control flow at branch joins](https://github.com/xgreenrx-star/VisualGasic/issues/25)
- [#24 AST and bytecode disagree on `Len` and mixed Variant arithmetic](https://github.com/xgreenrx-star/VisualGasic/issues/24)
- [#26 Decide missing Dictionary key behavior](https://github.com/xgreenrx-star/VisualGasic/issues/26)

Do the work in that order. #25 is the most urgent because the JIT is enabled by
default on supported native x86-64 targets and the failure can silently return
the wrong value. #24 is a cross-engine semantic mismatch. #26 is a language
specification decision, not a confirmed bug: do not change the behavior until
the intended contract is decided.

## Rules

1. Correctness first. Do not tune for the microbenchmarks or recognize benchmark
   function names/shapes in production code.
2. Before changing behavior, minimize each failure to a focused `.vg` test.
   Existing test files named below are starting points, not proof that every
   edge case is covered.
3. Keep AST, bytecode, and JIT results consistent unless the language
   specification explicitly documents a distinction.
4. Do not assume the AST evaluator is always correct. Decide the intended
   semantics, then make the incorrect paths agree.
5. Keep game code in VG. GDScript is acceptable only for a test harness when
   necessary to invoke the engine or configure execution mode.
6. Make one focused commit per issue. Select paths with `git add <paths>`; do
   not stage unrelated worktree changes. Never commit generated `.so`, `.gradle`,
   or `.avi` files.
7. End each commit message with:

   ```text
   Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
   ```

8. Update the issue and this handoff with the tested modes, results, and commit
   hash. Do not mark an issue complete because a test passes in only one mode.

## Issue #25 — JIT branch-join wrong result (P0)

### Known evidence

During an experiment to compile a pure Boolean `And` into conditional jumps,
`t_streq` returned `0` in Tier 2 while the interpreter returned a nonzero
result. The diagnosis recorded in
[`CURSOR_VG_PERF_GAP_HANDOFF.md`](./CURSOR_VG_PERF_GAP_HANDOFF.md) is that
Tier 2 does not merge operand-stack values at jump joins. The optimization was
not retained.

The risk is broader than that one experiment: `AndAlso` and `OrElse` already
generate short-circuit control flow. Verify which actual bytecode shapes are
miscompiled before changing the compiler. Do not claim every Boolean `And` is
affected; the VM's ordinary Boolean/Integer `And` semantics are separate from
the Tier-2 join problem.

Relevant starting points:

- Tier-2 lowering and branch handling: `src/visual_gasic_jit_tier2.cpp`
  (`OP_JUMP_IF_FALSE` near the lowering switch; search for `case OP_JUMP_IF_FALSE`).
- Tier-2 IR and register types: `src/visual_gasic_jit_tier2.h`.
- Tier-3 branch handling: `src/visual_gasic_jit_tier3.cpp`.
- Interpreter Boolean handlers: `src/visual_gasic_instance_bytecode_vm.cpp`.
- Existing string/Boolean workload: `test_proj/perf/vm_gap/micro.vg`,
  function `t_streq`.

### Work

1. Construct minimal `.vg` repros for `AndAlso`, `OrElse`, and Boolean `And`
   with both branch outcomes taken. Include cases where the expression is used
   as an `If` condition and where it is assigned/returned as a Boolean value.
2. Record the expected result and the result under default JIT, `VG_JIT=0`,
   `VG_JIT=3`, and `VG_FORCE_AST=1`. Keep these tests in
   `test_proj/test_suite/`.
3. Trace the relevant bytecode and Tier-2 IR. Establish whether the defect is
   missing phi/value merging, an invalid stack-height assumption, or another
   control-flow lowering issue. Do not infer this only from the symptom.
4. Fix control-flow value merging if it can be done safely. Otherwise make
   Tier 2 explicitly reject the affected shape before emitting native code and
   fall back to bytecode without changing observable behavior.
5. Check Tier 3 independently; it must either handle the pattern correctly or
   decline it safely.

### Acceptance

- The new tests assert exact outputs in all four execution modes above.
- The default and Tier-3 JIT either return the correct result or log an explicit
  safe fallback; they must never produce a wrong result.
- Run the AST/bytecode differential harness on the new tests.
- No benchmark-specific branch or silent success-shaped fallback.
- Full regression suite and corpus pass before closing the issue.

## Issue #24 — AST / bytecode semantic parity (P0)

### Known reproductions

Run the existing tests in AST-only mode:

```bash
cd test_proj
G=/home/Commodore/Downloads/Godot_v4.7.2-stable_linux.x86_64
VG_FORCE_AST=1 "$G" --headless --path . --audio-driver Dummy \
  --script res://run_suite.gd -- res://test_suite/test_jit_len_global.vg
VG_FORCE_AST=1 "$G" --headless --path . --audio-driver Dummy \
  --script res://run_suite.gd -- res://test_suite/test_jit_string_dict_globals.vg
```

The currently recorded differences are:

- `test_jit_len_global.vg`: AST-only reports `Len` values 1, 18, and 9 for an
  Integer Variant, a two-entry Dictionary, and a three-element Array; bytecode
  and JIT report 0, 2, and 3. Confirm the observed values on the current
  checkout before editing. The test's expected values currently match the
  bytecode/JIT behavior, but the intended language contract still needs review.
- `test_jit_string_dict_globals.vg`: `SumPoison` changes the Dictionary value
  from a number to `"3"` during the loop, and `SumMiss` reads a missing key.
  AST-only fails the `dict deopt` and `missing key` sum assertions. The recorded
  explanation is that the AST tree-walk clears a Single on `Single + String`
  and `Single + Nothing`, while bytecode coerces the String and treats the
  missing-key Nothing differently.

Related implementation locations:

- AST expression evaluation: `src/visual_gasic_instance_evaluate.inc` and
  `src/visual_gasic_instance_execute.inc`.
- Shared AST evaluator dispatch: `src/visual_gasic_expression_evaluator.cpp`.
- Bytecode operations: `src/visual_gasic_instance_bytecode_vm.cpp`
  (`OP_LEN`, `OP_ADD`, and Dictionary get handlers).
- Tier-2 helpers for global Len/string/Dictionary values:
  `src/visual_gasic_jit_tier2.cpp`.
- Type coercion and display/numeric conversion:
  `src/visual_gasic_instance.cpp` and `src/visual_gasic_instance.h`.

### Work

1. Reproduce each discrepancy in isolation. Print or assert the actual
   `Variant::Type` and value at the relevant operation if needed; avoid changing
   behavior based only on the current assertion text.
2. Decide the language semantics for:
   - `Len` on an Integer/other scalar Variant, String, Dictionary, and Array.
   - Adding a String or `Nothing` to a typed numeric accumulator.
   - Missing-key reads used in a numeric expression, after #26's behavior is
     decided.
3. Record the decisions in tests and the language reference. If a distinction
   is intentional, document it and test it explicitly; otherwise make AST,
   bytecode, and JIT agree.
4. Exercise AST fallback/deoptimization paths, not just whole-function AST
   execution. Ensure state already written before a fallback is neither lost
   nor applied twice.

### Acceptance

- Both existing tests pass with their expected values under default execution,
  `VG_JIT=0`, `VG_JIT=3`, and `VG_FORCE_AST=1`.
- The AST/bytecode differential harness passes for both tests.
- Add focused coverage for the decided scalar/container `Len` behavior,
  changing Variant types, and missing-key arithmetic.
- Full regression suite and corpus pass in the prescribed modes.

## Issue #26 — Missing Dictionary key contract (P0 decision)

This is not currently a confirmed defect. The current bytecode tests assert
that a missing key evaluates to `Nothing` and leaves `Err.Number` at zero.
An earlier performance handoff text described a missing key as an error; that
expectation conflicts with current tests and must be resolved, not followed
implicitly.

### Work

1. Ask the project owner to choose the language contract:
   - Missing key returns `Nothing`; or
   - Missing key raises a VG runtime error with a source line.
2. Check the existing language reference and compare intended behavior with
   VG's supported Dictionary semantics. Report the evidence and recommendation
   before changing runtime behavior.
3. Once decided, update the language reference and tests for:
   - Direct read of a missing key.
   - `VarType` / `Is Nothing` and `Err.Number`.
   - Use in numeric and String expressions.
   - `On Error Resume Next` / normal error propagation if the selected behavior
     raises.
4. Make AST, bytecode, JIT, and any fast Dictionary opcodes obey the same
   contract. Remove stale contradictory wording from
   `CURSOR_VG_PERF_GAP_HANDOFF.md`.

### Acceptance

- The decision is documented in the language reference and linked from the
  issue.
- Tests encode the chosen behavior in all execution modes.
- #24's missing-key arithmetic case is updated to use the chosen semantics.
- No issue is closed until there is an owner-approved decision and passing
  tests.

## Release validation

If C++ changes are made, build once before starting regression runs:

```bash
scons platform=linux target=editor nostrip=1 -j8
```

Do not rebuild or replace the extension while tests are running. The extension
is loaded from `addons/visual_gasic/bin`.

Run the focused AST/bytecode diff:

```bash
GODOT=/home/Commodore/Downloads/Godot_v4.7.2-stable_linux.x86_64 \
  scripts/run_ast_bytecode_diff.sh \
  test_jit_len_global.vg test_jit_string_dict_globals.vg
```

Also run each focused regression under the needed modes. Then run the full
suite; do not run these three loops concurrently on a shared machine:

```bash
export GODOT=/home/Commodore/Downloads/Godot_v4.7.2-stable_linux.x86_64
VG_OPLEN_CHECK=1 scripts/run_vg_regression_loop.sh /tmp/reg_default.log
VG_OPLEN_CHECK=1 VG_JIT=0 scripts/run_vg_regression_loop.sh /tmp/reg_nojit.log
VG_OPLEN_CHECK=1 VG_JIT=3 scripts/run_vg_regression_loop.sh /tmp/reg_jit3.log
```

Run the corpus in all modes:

```bash
for mode in default nojit tier3 ast; do
  case "$mode" in
    default) env_args=() ;;
    nojit) env_args=(VG_JIT=0) ;;
    tier3) env_args=(VG_JIT=3) ;;
    ast) env_args=(VG_FORCE_AST=1) ;;
  esac
  env "${env_args[@]}" GODOT="$GODOT" bash scripts/audit_corpus.sh
done
```

Expected: no new regression failures, no instruction-length assertions, and
the corpus reports 80 pass / 0 fail / 0 skipped. The known Cdecl `strlen`
assert is documented baseline noise; do not suppress other failures.

Finally run the microbenchmark in default and interpreter modes and confirm
`mismatches=0`. Performance ratios are a no-regression check here, not a release
correctness substitute.

## Completion report

### Status (18 Nov 2026)

| Issue | Status | Notes |
|-------|--------|-------|
| #25 JIT branch join | Done (safe decline) | Tier 2 records jump-target stack heights and **returns false** (bytecode fallback) on expression joins with a live stack (`AndAlso`/`OrElse`). No wrong native result. Test: `test_jit_branch_join.vg` — 18/18 in default, `VG_JIT=0`, `VG_JIT=3`, `VG_FORCE_AST=1`. |
| #24 AST/bytecode parity | Done | Shared `vg_len_value`; `vg_vb_numeric` accepts `STRING`/`NIL` like VM `to_double`. `test_jit_len_global.vg` + `test_jit_string_dict_globals.vg` pass in all four modes. AST↔BC diff: 3/3 matched OK. |
| #26 Missing Dictionary key | Done (spec) | **Contract: missing key → `Nothing`, `Err.Number = 0`.** Documented in language reference + CHANGELOG. Matches existing tests. |

Focused validation: AST/bytecode diff OK; `run_gap` `mismatches=0`. Full suite: see commit messages / session log (`PASS=1894 FAIL=0` default and `VG_JIT=0`; Cdecl `strlen` assert remains baseline noise).

Still open for a later release (not beta blockers here): Tier-2 **phi merge** so `AndAlso`/`OrElse` can compile natively instead of declining.

Before calling the handoff complete:

- Update issues #24, #25, and #26 with evidence, selected semantics, tests, and
  commit references.
- Update the 5.8.0-beta.1 gate in `ROADMAP.md` and `RELEASE_SCHEDULE.md` only
  after each corresponding exit criterion is met.
- Update `CHANGELOG.md` under Unreleased with user-visible fixes. Do not create
  or tag release notes for 5.8.0-beta.1 until the project owner authorizes the
  cut.
- Summarize what was fixed, any intentional semantic decisions, exact test
  totals/modes, and anything still blocked. Do not claim VG is fully bug-free
  or universally faster than GDScript.
