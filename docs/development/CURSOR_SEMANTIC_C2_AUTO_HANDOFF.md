# Cursor Auto handoff: C2 calls, ByRef and imports

## Paste-in assignment

Implement the bounded C2 testing slice below. Cursor is currently running in
Auto; do not assume access to an advanced reasoning model. Work in small,
independently validated steps. Do not redesign runtime semantics to make a
test pass. Stop and report contract ambiguities rather than guessing.

Do not commit, push, change release tags or replace published assets.
Preserve all unrelated user changes. Return implementation and actual test
evidence, not a plan alone.

## Current state: preserve, do not redo

Read:

- [Original semantic-testing assignment](CURSOR_SEMANTIC_TESTING_HANDOFF.md)
- [CI and Phase 2 assignment](CURSOR_SEMANTIC_CI_PHASE2_HANDOFF.md)
- [Contracts](SEMANTIC_FUZZ_CONTRACTS.md)
- [Phase 1 results](SEMANTIC_FUZZ_PHASE1_RESULTS.md)
- [Harness](../../tools/semantic_fuzz/)
- [CI smoke entry](../../scripts/run_semantic_ci_smoke.sh)

Phase 1, local CI integration, and the reported provenance corrections have
been independently checked. Latest local gate: seed 42, 20 programs across
four requested modes, 80 runs, zero failures, 15 shapes, about 32.5 seconds.
Tier 2 actually executed; Tier 3 did not. A Tier-3 request is not coverage of
Tier 3. No GitHub Actions run of the new gate has been verified.

The current full suite previously passed 1,930 assertions across 287 files.
That is historical evidence for the then-current working binary, not a
substitute for rebuilding after new C++ changes.

C1 has deterministic numeric/Variant fixtures and rounding-oracle checks,
but random Variant/Double IR and its feature-pair matrix are incomplete.
Bare numeric-string arithmetic remains a recorded gap, not a newly approved
language exclusion. Do not silently mark C1 or all Phase 2 complete.

Most of this testing work and core fixes are still uncommitted. Inspect
`git status --short` and HEAD. Protect C64 source/project/breakpoint changes,
race recording settings, Android caches, generated C# files, and videos.
Do not stage, format, or revert them.

## Scope and order

Complete these checkpoints in order:

1. Establish C2 contracts and deterministic multi-file fixtures.
2. Wire fixtures into repeatable mode-aware validation.
3. Implement a small independent reference model for scalar call semantics.
4. Generate bounded interaction cases and verify replay/reduction support.

Finish a checkpoint before moving on. If time or reasoning limits prevent
completion, deliver the working checkpoint and clearly mark the rest pending.
Do not add C3/C4, nightly jobs, sanitizer infrastructure, JIT phi merge, or
unrelated optimizations in this assignment.

## Checkpoint 1: contract inventory and deterministic fixtures

Read existing prior art before adding anything:

- [ByRef/ByVal fixture](../../test_proj/test_suite/test_byref_byval.vg)
- [Expression/scalar calls](../../test_proj/test_suite/test_call_byref_scalar.vg)
- [Indexed ByRef](../../test_proj/test_suite/test_byref_array_slot.vg)
- [Computed index](../../test_proj/test_suite/test_byref_computed_index.vg)
- [Imported calls](../../test_proj/test_suite/test_byref_import.vg)
- [AST/import calls](../../test_proj/test_suite/test_byref_ast_import.vg)
- [Caller/import fixture](../../test_proj/test_suite/test_byref_caller_import.vg)
- [Project/helper fixture](../../test_proj/test_suite/test_byref_project.vg)
- Language reference and current call-binding/write-back implementation.

Record which existing fixture proves each rule. Extend existing tests where
appropriate instead of duplicating them.

For each new scenario write a hand-derived table:

`initial caller state -> call order -> callee changes -> return -> final caller state`

Cover:

| Scenario | Required observations |
|---|---|
| Standalone ByRef call | caller before/after, callee input/output |
| Expression-level ByRef function | return AND caller mutation |
| ByVal control | return and unchanged caller |
| Two distinct reference arguments | separate write-backs |
| Same variable passed twice | alias behavior, after contract verification |
| Nested calls | ordered effects and caller restoration |
| Recursive ByRef with default argument | each level's state, final caller/result |
| Indexed argument with side-effecting index | index evaluated once, correct slot write-back |
| Imported helper | same results as equivalent same-file call |
| Intentional compiled/AST boundary | documented fallback and preserved mutations |

Use explicit `ByRef` and `ByVal`. Separately test the language's default
parameter-passing rule rather than assume it. Do not infer alias/write-back
semantics from another BASIC implementation without repository evidence.

Some combinations, especially repeated aliases and argument evaluation order,
may have an unclear contract. Report those as unresolved and keep them out
of the random oracle until decided. An AST/VM disagreement proves a divergence,
not which path is correct.

Assertions must check types and exact values, individual state fields, event
order/count, and return values. Do not compare only `CStr` or an aggregate sum.
Make helper failures observable in the caller, not just printed optimistically.
Avoid nondeterministic time, engine input, network or filesystem effects.

## Checkpoint 2: reliable execution and path attribution

Run the C2 deterministic fixtures in:

- forced AST;
- interpreter-only;
- default runtime;
- Tier-3-request mode where supported, with actual path reporting.

The existing differential runner compares default versus AST; it does not
by itself verify interpreter-only or native execution. Reuse it for what
it proves, and add narrowly scoped mode-aware checks where needed.

For mixed-path fixtures, specify expected paths per relevant caller/callee.
Identify functions by script/module plus function name when imports could
have the same name. The existing function-name-only path events may need
extension; inspect and reuse existing instrumentation first.

Do not:

- count a sibling function's execution as coverage of the target;
- turn off strict path validation globally;
- require native compilation for a shape unsupported by current JIT;
- count compilation attempts as executed native code;
- relax safe short-circuit fallback;
- assume every `VG_JIT=3` run uses Tier 3.

Distinguish required-path fixtures, explicitly allowed mixed-path fixtures,
and documented unsupported paths. Demonstrate fallback where claimed; do
not copy an old source comment as proof that imports always use AST.

Add a bounded C2 fixture lane to the existing semantic CI flow only after
measuring it. Keep the four-mode Phase 1 smoke intact, avoid duplicate full
suites, preserve failure artifacts, and propagate nonzero status.

## Checkpoint 3: independent scalar call model

Keep the initial model small:

- bounded Integer values only;
- explicit parameter modes;
- local/module scalar storage locations;
- functions/Subs and bounded nested calls;
- explicit return values and ordered side effects.

Represent caller storage identity separately from stored values. ByRef must
refer to a modeled location; ByVal gets an independent value. Account for
callee locals, parameters, return slots and restoration across recursion.
Choose shared-cell versus copy-in/write-back behavior only after establishing
the VG contract, especially when aliases overlap.

Hand-calculate oracle examples first, including:

- `x=3`, mutate ByRef to `x+2`, return twice the changed value;
- the same function called in an assignment expression;
- ByVal counterpart leaving `x` unchanged;
- two different locations with distinguishable writes;
- a short bounded recursive example with distinct per-level state.

The model must not execute emitted VG to obtain expected results or port
production write-back code. Do not assume Python argument semantics equal VG.

If indexed locations or imports cannot yet be modeled reliably, keep them
as deterministic fixtures and report that limit. Do not claim random indexed
ByRef coverage from an emitter template without independent expectations.

## Checkpoint 4: generated pairs, bundles and reduction

Generate a bounded pairwise matrix:

- ByRef/ByVal x standalone/expression call;
- local/module variable x direct/nested call;
- distinct/alias arguments x call order, where specified;
- recursive/default arguments x caller-state preservation;
- same-file/imported helpers x allowed execution paths.

Start with 20 distinct supported C2 programs for a fixed seed; expand to 100
for a local acceptance campaign once stable. Report distinct shapes separately
from literal diversity. Count only implemented, observed pairs; unsupported
pairs need explicit reasons.

Run typed observations in all requested modes. Preserve one evaluation per
observed expression and compare event sequence/count. Do not warm up impure
calls without resetting their modeled state before measured observations.

A multi-file case bundle must contain:

- every source module and its relative path/content;
- typed IR, inputs and independently computed expectations;
- schema/generator/reference versions;
- engine and VG library hashes, engine identity and source provenance;
- mode and per-function path contracts;
- logs, typed actual observations and exact failure class;
- a one-command replay that reconstructs the isolated module layout.

Reuse shared provenance checks for replay AND reduction. Refuse incompatible
models before creating outputs; label changed engine/library environments,
including an engine replaced at the same path. Never import from the user's
mutable project as an undeclared part of a replay bundle.

Reduction must preserve source/module validity, the exact failure class,
alias relationships needed to reproduce it, and relevant path contracts.
If a new case class is not reducible, say so and keep its original bundle.
Do not replace an import bug with a parse error or a different fallback.

## Mandatory negative tests

Exercise actual runner/campaign/replay/reduction wiring with fake runners or
test-only observation corruption. Demonstrate rejection of:

- correct return but missing caller write-back;
- correct caller mutation but wrong return;
- wrong type with numerically equal value;
- duplicated indexed-expression evaluation;
- reversed or missing call effects;
- caller state corrupted by nested/recursive calls;
- same-name helper in the wrong module satisfying path coverage;
- unexpected AST fallback satisfying a native/bytecode requirement;
- replay missing a module or using modified module content;
- reduction changing alias identity, failure class or execution path.

Keep all Phase 1 negatives green: strict result parsing, completion checks,
timeout bytes/None, missing binary/instrumentation, exact failure identity,
mode preservation and schema/runtime provenance.

Do not add deliberate defects to shipping runtime code for these tests.

## Runtime bug policy for Auto mode

Tests/harness first. Only make a C++ change after:

1. A small valid reproducer fails.
2. Expected behavior is grounded in an established contract.
3. The exact binding/dispatch/write-back path is traced.
4. A permanent regression exists.

Keep fixes surgical. Rebuild the library actually loaded by tests and record
its hash. Validate AST, bytecode and relevant native modes. Re-run existing
ByRef/import regressions and full suite/hardening when the change affects core
call frames or ownership.

If the fix requires redesigning frame storage, introducing unsafe ownership
assumptions, or choosing undocumented alias semantics, STOP with the minimized
reproducer, exact traces and contract question. Do not improvise a broad fix
because Auto cannot resolve it. Do not weaken tests to complete the task.

## Final report and acceptance

Provide a checkpoint table: complete / partial / not started.

For completed work include:

- changed files and exact run/replay/reduce commands;
- baseline and final engine/library identities;
- oracle examples and negative-test evidence;
- fixture assertions, generated cases, shapes and observed feature pairs;
- paths per script/function and requested mode;
- real defects, minimized reproductions, fixes and regression results;
- measured CI duration and timeout choice;
- explicit exclusions and unresolved contract questions.

Minimum useful delivery: checkpoint 1 plus a working mode-aware validation
lane from checkpoint 2, all existing gates preserved. Full C2 completion also
requires the independent model, generated interactions and replayable cases;
fixtures alone are not all of C2.

No commit/push until reviewed. Do not claim Actions passed unless it actually
ran. Do not claim Tier 3 coverage without native Tier 3 entry evidence.
