# Cursor handoff: semantic CI gate and Phase 2 interactions

## Assignment and stop boundary

The Phase 1 semantic harness has passed targeted independent review of its
previously reported blockers. Next:

1. Make a bounded semantic smoke campaign an automatic CI/release gate.
2. Expand correctness coverage to realistic language interactions.
3. Keep the harness's negative tests and path evidence trustworthy.

Implement and validate, not just propose. Finish CI integration before
expanding the semantic domain. Return scoped changes and reproducible evidence.
Do not commit, push, move tags, replace released downloads, or cut a release
without explicit follow-up approval.

This is not authorization to rewrite the compiler, redesign the JIT, expand
the standalone IDE, or edit the user's games. Long-running nightly campaigns,
sanitizer infrastructure, and rendered game scenarios remain later phases
unless specifically needed to reproduce a new defect.

## Read first

- [Original assignment](CURSOR_SEMANTIC_TESTING_HANDOFF.md)
- [Current results](SEMANTIC_FUZZ_PHASE1_RESULTS.md)
- [Semantic contracts](SEMANTIC_FUZZ_CONTRACTS.md)
- [Harness](../../tools/semantic_fuzz/)
- [Self-test entry](../../scripts/test_semantic_fuzz.sh)
- [Campaign entry](../../scripts/run_semantic_fuzz.sh)
- [CI workflow](../../.github/workflows/ci.yml)
- [Release workflow](../../.github/workflows/release.yml)
- [Existing differential gate](../../scripts/run_ast_bytecode_diff.sh)

Inspect HEAD, the dirty worktree, and actual files before editing. The harness,
parser/negation regressions, opt-in path instrumentation, and rebuilt Linux
editor library are still uncommitted at the time of this handoff. Preserve
them and integrate with them; do not rebuild Phase 1 from scratch.

Unrelated dirty files include C64 source/project/breakpoint changes, race movie
settings, Android caches, generated C# files, and videos. Do not stage, format,
revert, or modify those. The published 5.8.0-beta.1 assets must stay unchanged.

## Verified baseline and limits

Independent checks completed on Linux/Godot 4.6.1:

- Fresh seed `20261120`: 100 programs, 36 reported shapes, four requested
  modes, 400 runs, zero reported failures before the final path-order fix.
- After that fix, seed `20261121`: 20 programs, 15 reported shapes, four
  requested modes, 80 runs, zero failures, about 30 seconds locally.
- Harness self-tests pass. Direct and reducer-predicate probes reject
  native Tier 2 + AST and native Tier 3 + AST, while accepting legitimate
  bytecode warmup followed by native execution.
- Four focused fixtures matched AST/default: 37 assertions per mode
  (operators, integer negation, existing Select Case, negative Case).
- Actual Tier 2 native entry was observed. Actual Tier 3 entry was NOT
  demonstrated; requesting `VG_JIT=3` is not proof of Tier 3 execution.

These are bounded observations, not full runtime certification. Do not expand
the completion claims beyond the evidence.

## Task A: automatic semantic smoke gate

### Integrate with the build that CI actually tests

Use the existing Linux build-and-test job after its extension preparation and
smoke load. Run serially relative to other shared-checkout tests.
The release workflow calls this CI workflow, so use that existing dependency
rather than add an independent release path that can skip the gate.

Required steps:

1. Run the oracle/harness self-tests.
2. Run a fixed-seed campaign with count 20 and explicit modes
   `forced_ast,interpreter,default,tier3` on the supported Linux x86-64 build.
3. Fail the job on harness, process, observation, path, or generation failure.
   Do not use `continue-on-error` or `|| true` on the semantic gate.
4. Upload campaign evidence with `if: always()` and a unique artifact name.
   Preserve top-level summaries, provenance, all failure bundles and enough
   successful evidence to audit path totals. Missing required evidence must
   not be silently treated as a successful test.
5. Apply a bounded step timeout with reasonable headroom over measured
   duration. Keep startup/runtime failures distinct from time-budget expiry.

Set `GODOT` explicitly to the CI-downloaded engine. Confirm that recorded
extension hashes identify the binaries prepared in that job, not a stale
tracked editor library. Record engine version/hash and full source revision
where absent; report provenance failures explicitly.

Do not claim an unsupported native tier is covered. For the Tier-3 request
lane, report actual Tier 2 / Tier 3 / decline counts separately. Native
coverage requires a known eligible target to execute natively, not an
unrelated helper or compile-success log.

Do not add this campaign to both CI and the hardening script if that would
run it twice in the same release without a deliberate, documented reason.
Do not parallelize gates using fixed test paths/ports.

### Prove CI failure propagation

Add harness/workflow-oriented tests that demonstrate:

- self-test failure stops the gate;
- wrong output and path mismatch yield a nonzero campaign exit;
- missing extension/instrumentation cannot produce a green run;
- failure evidence is written before exit and retained for upload;
- modes are explicitly selected, not inherited from a user's environment.

Prefer fake subprocesses or test-only observation corruption. Do not damage
the production runtime or push a deliberately broken commit to prove a gate.
Distinguish local workflow validation from an actual GitHub Actions run; do
not say CI passed unless it really ran.

## Task B: protect Phase 1 guarantees while extending it

Keep all previous negative probes passing:

- observed runtime types, one evaluation per observation;
- strict result parsing, completion identity/count, ordered observations;
- timeout bytes/None handling and nonzero exit/error classification;
- authoritative saved-mode replay and path validation on replay;
- exact reduction failure class and target execution-path contract;
- conflicting paths rejected before native-alternative success;
- legitimate bytecode warmup followed by native execution accepted;
- honest distinct-program and structural-diversity reporting.

Strengthen tests where they only inspect helper return values instead of
exercising the actual runner/campaign/replay/reduction wiring.

Two edge cases deserve explicit handling rather than overclaiming:

1. An original `path_mismatch` failure cannot both preserve that mismatch
   and satisfy the same path contract. Either support reduction by preserving
   its precise violation signature, or explicitly mark this failure class as
   non-reducible and retain the original bundle.
2. Replay/reduction must reject incompatible schema/model versions or clearly
   identify a new-environment rerun. Do not silently describe a run on a
   different engine/binary as identical historical reproduction.

Do not let these hardening improvements balloon into a generic framework
rewrite.

## Task C: Phase 2 contract fixtures, then generated interactions

Implement incrementally. For each family:

1. Establish documented semantics and hand-derived boundary expectations.
2. Add deterministic contract fixtures.
3. Extend the typed IR/reference model/emitter only where independently
   specified semantics can be modeled reliably.
4. Add seeded cases and explicit execution-path expectations.
5. Record covered feature pairs and explicit exclusions.

Do not use the VG evaluator to calculate its own expected output. Do not
assume GDScript or Python semantics are VB6 semantics. When the contract is
unclear, surface the ambiguity before changing runtime behavior.

### C1. Numeric and Variant interactions

- Integer/Double assignments, conversions, unary operators and type retention.
- Positive/negative midpoint rounding and values immediately around a tie.
- Literal-left/right operand orders and noncommutative operations.
- Numeric strings and `Nothing` on either side, with explicit expected value
  and type. Follow the established asymmetric Nothing arithmetic contract.
- Missing Dictionary keys: `Nothing`, unchanged `Err.Number`, and surrounding
  arithmetic where the contract specifies behavior.

Do not use one broad float epsilon. Define exact comparisons where possible,
and per-operation absolute/relative tolerances where necessary. Keep overflow,
NaN and division-by-zero outside the random domain until specified.

### C2. ByRef/calls/imports

- Standalone calls versus calls inside expressions.
- ByRef and ByVal caller-state observations.
- Indexed arguments evaluated once, aliases and nested calls.
- Recursion and default arguments.
- Imported modules and transitions between compiled and AST paths.

The Phase 1 independent model excludes ByRef. Do not merely emit default
ByRef parameters and call that modeled alias coverage. Make parameter passing
and alias identity explicit in the IR/reference semantics.

Mixed-path interaction fixtures may intentionally use fallback in a callee.
Specify expected paths per relevant function; do not disable strict path
checking globally to accommodate them.

### C3. Collections and records

- Generic Array versus packed-array paths where supported.
- Nested Dictionary/Array reads and writes.
- Indexed member write-back and single evaluation of indices.
- UDT value copies versus intended reference aliases.
- Return values and collection iteration/removal interactions.

Observe individual fields/elements, types, mutation order and alias effects,
not only a sum that can hide compensating errors.

### C4. Short-circuit effects and error boundaries

- `AndAlso` / `OrElse`: RHS executed exactly when required.
- Side effects distinguish evaluation order and duplicate execution.
- Current unsupported expression joins retain safe native decline; do not
  implement native phi merge as an incidental test-enablement change.
- Nested handlers and `Try`/`Finally`: exact side-effect order and error
  propagation. Expected-error fixtures are distinct from valid-program runs.

### Diversity and measurement

Use a bounded pairwise feature matrix across these families. Count observed
coverage, not just attached tags. Expose which pairs remain unsupported.
Random literal changes do not equal new control-flow shapes; report both.

Keep deterministic fixtures separate where independent random modeling would
be unreliable. A small trustworthy domain is better than a broad false oracle.

## Fix discipline

When a case finds a real defect:

1. Save original seed, IR/source, expected/actual observations and provenance.
2. Produce a minimal reproducer and establish the language contract.
3. Add a permanent failing regression before the runtime fix.
4. Fix the root cause without weakening the harness or changing the game.
5. Rebuild the binaries actually loaded by tests; record their hashes.
6. Run targeted regression and relevant AST/VM/JIT checks.
7. Escalate to full regression/hardening for final integration when core
   runtime/compiler changes warrant it.

Do not make speculative cross-tier fixes without a reproducer. Preserve
unrelated user changes and released binaries. Performance validation is
separate from correctness and must run without path tracing/debugger overhead.

## Acceptance and final report

Task A is complete only when:

- the bounded gate is wired into existing CI/reusable release gates;
- self-tests and a fresh 20-case four-mode smoke pass locally;
- injected failures fail the gate and save inspectable evidence;
- actual binary provenance and path counts are reported;
- workflow changes validate using available existing tooling;
- docs explain how to run and interpret the gate.

Task C is complete only for families actually implemented and tested. Do not
mark all Phase 2 complete after adding a handful of fixtures from one family.
For each completed family, provide independent oracle examples, negative
harness probes, deterministic fixtures and seeded execution evidence.

Return:

- changed files and exact runnable commands;
- baseline/final binary identities and source/worktree provenance;
- case/run counts, distinct shapes and observed paths per mode;
- coverage by feature pair and explicit exclusions;
- measured durations and chosen CI timeout;
- failures found, minimized regressions and root-cause fixes;
- existing test results, including any failures not resolved;
- which tasks are complete, partial or not started.

Do not commit or push until reviewed. The next priority after this handoff is
scheduled longer campaigns and deterministic game-shaped integration tests,
not another performance headline.
