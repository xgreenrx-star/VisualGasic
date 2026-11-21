# Cursor and Copilot handoff: resolve observed call-evaluation bugs

## Goal and scope

Use the existing semantic harness to fix confirmed runtime bugs before expanding
random coverage. Work with Copilot through the mailbox below. Cursor is running
in Auto, so use small checkpoints, reproducible evidence, and surgical changes.
Do not claim VisualGasic is bug-free when this assignment finishes.

Work in this order:

1. Forced-AST nested ByVal argument evaluated twice.
2. Side-effecting index in an indexed ByRef argument evaluated twice.
3. If both are fixed and independently accepted, report the next recommended
   testing slice. Do not start a broad C1/C3/C4 expansion in this assignment.

The same-name imported `Twin` dispatch and same-name module scalar discrepancy
remain visible but are not part of this fix scope. The latter's intended module
namespace contract remains unsettled. Repeated ByRef alias behavior is observed,
not an approved contract.

## Coordination

Mailbox:
`/home/Commodore/.copilot/session-state/cf88c33e-98ba-4080-a9de-a8fd9e85de16/files/cursor-semantic-bugfix-coordination`

Read `PROTOCOL.md`, then `instructions-001.md` after `instructions-001.ready`
appears. Write a complete `status-001.md`, close it, and only then create
`status-001.ready`. Wait for Copilot's next numbered instruction. Do not
invent a response from Copilot or continue modifying code after signaling.
Stop when Copilot sends `DECISION: COMPLETE` or `DECISION: BLOCKED`.

## Baseline and safeguards

- Inspect `git status --short`, HEAD and binary hashes first. The harness was
  committed in `a28c81f0` as of this handoff; check rather than assuming HEAD
  or the currently loaded library matches any past evidence.
- The existing editor shared library is **already modified**. Do not overwrite
  it or other pre-existing user changes. Build and test a candidate in an
  isolated checkout/project with explicit provenance, or stop and explain if
  you cannot preserve the user's binary. Do not use shared fixed test files or
  overwrite `test_proj/current_test.txt`.
- Preserve C64 changes, movie/project settings, Android caches, generated C#
  files and videos. Do not stage, revert, format, clean, or delete unrelated
  work. Do not change releases, commit or push without separate authorization.
- Do not touch the experimental standalone IDE. Avoid broad compiler/VM
  redesign, performance work, or changes to ambiguous alias behavior.
- Run shared-resource tests serially. Clean up only explicitly identified
  files owned by your run. Report all failures and timeouts; do not make a
  known-defect gate silently green.

## First checkpoint: reproduce and investigate

Read the relevant contracts, current source and existing tests:

- [C2 contracts and hand-derived expectations](SEMANTIC_FUZZ_CONTRACTS.md).
- [Semantic testing results](SEMANTIC_FUZZ_PHASE1_RESULTS.md).
- [ByVal duplicate-evaluation repro](../../tools/semantic_fuzz/known_defects/c2_ast_byval_arg_double_eval/README.md).
- [ByRef index fixture](../../test_proj/test_suite/test_sem_c2_calls_byref.vg).
- [IR examples and lane](../../tools/semantic_fuzz/c2_ir_lane.py).
- [Known-defect gate](../../scripts/run_semantic_c2_known_defects.sh).
- Existing call evaluation/write-back and bytecode compilation paths; trace
  actual control flow rather than assuming shared root causes.

Confirm each repro against the binary actually loaded. Preserve full logs,
return values, variable types, event counts/order, path events and hashes.
For each, identify where argument/index evaluation happens, supported contract
sources and affected call forms. Report a root-cause hypothesis with evidence,
and which fix is safely bounded. Do not change C++ in this first checkpoint.

## Per-defect fix discipline after review

For each independently authorized fix:

1. Add a minimal permanent regression that fails before the fix and asserts
   once-only evaluation, exact return and mutation, untouched alternatives,
   evaluation order, types and target execution paths. Cover standalone and
   expression calls where relevant; include dynamic indices that change their
   result so writing back to the wrong slot cannot pass unnoticed.
2. Implement the root-cause fix, respecting call frame, recursion, ByRef
   copy/write-back and object lifetime. Preserve existing explicit exclusions.
3. Build the actual extension in isolation; capture source revision, dirty
   state, engine path/hash and tested extension path/hash.
4. Prove the old binary fails and the new binary passes, then exercise the
   required forced-AST, interpreter, default and Tier-3-request modes. Record
   actual executed tiers, not only requested flags.
5. Update the precise known-defect fixture, judge, lane and documentation so
   the fixed behavior is a strict regression, not an accepted known failure.
   Verify injected wrong counts/slots and path mismatches still fail.
6. Run targeted call/ByRef/import/recursion regressions, semantic selftests,
   C2 IR/fixture/campaign lanes and Phase 1 smoke. Run the full applicable
   runtime suite after the last core change; report excluded phases and
   remaining known defects separately. Do not claim GitHub Actions passed
   without an actual run.

If the contract is ambiguous or the fix requires a broad ownership/frame
redesign, stop and provide a minimized repro and options for Copilot review.
Do not alter the oracle to match incorrect behavior.
