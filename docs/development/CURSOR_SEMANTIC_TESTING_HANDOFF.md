# Cursor handoff: find core VG bugs before games do

## Assignment

Build an automated semantic-testing system that catches incorrect results,
not just crashes. Implement it, run it, fix confirmed core bugs with permanent
regressions, and return reproducible evidence. A plan or a large collection of
generated files alone is not completion.

The primary goal is language/runtime correctness. Speed is secondary: never
change expected semantics, weaken checks, or remove realistic work to improve
performance numbers. Do not promise that passing this system proves VG is
bug-free.

Complete Phase 1 end-to-end before expanding to subsequent phases. If the
full assignment exceeds the session, deliver the working first phase and
explicitly identify what remains; do not mark placeholders complete.

## Baseline and safety

- Inspect HEAD and `git status --short` before editing. The released
  `v5.8.0-beta.1` binaries came from
  `f1ab95f4dcd7aa43bbc1cb6facf09eb72a2602dc`; main has subsequent publication
  updates and may have advanced further.
- Preserve unrelated edits, particularly C64 emulator source/project settings,
  race recording settings, Android caches, generated C# files, and videos.
  Do not format or stage those files.
- Do not move release tags, replace released assets, or cut another release.
- Do not expand the experimental standalone IDE or UI Forms.
- Run generated projects in dedicated temporary directories. Do not overwrite
  `current_test.txt`, test fixtures, or the user's projects to run a campaign.
- Bound source size, loops, recursion, frames, output, subprocess duration,
  campaign duration, and reducer attempts. Treat generated source as code:
  no arbitrary filesystem, network, OS, shell, FFI, or process operations.
- Shared checkout gates use fixed paths/ports. Do not run conflicting suites
  concurrently. Preserve logs before cleaning only your temporary files.
- Do not commit or push without a follow-up instruction. Return the scoped
  diff and exact commands/results for review.

## Read and reuse existing infrastructure

Read these before designing a new harness:

- [Release hardening](../../scripts/run_release_hardening.sh): ten Linux
  headless gates; records provenance, runs suites serially.
- [AST/bytecode differential](../../scripts/run_ast_bytecode_diff.sh): runs
  existing fixtures in default and forced AST modes; compares assertion lines
  and validates completion/errors. Default execution is not proof of bytecode
  or native execution.
- [Malformed-source mutation stress](../../scripts/run_parser_mutation_stress.sh)
  and [its self-tests](../../scripts/test_parser_mutation_stress.sh): the
  release gate currently uses count 40, seed 42 in default and AST modes.
  Its source pool is sorted and truncated to the first 80 files. This is
  useful robustness testing, not a valid-program correctness oracle.
- [Suite runner](../../test_proj/run_suite.gd): honors script base type and
  lifecycle frames, but its completion marker alone does not assert results.
- [ClassDB generator](../../tools/classdb_fuzzer.py): API coverage with
  deliberate exclusions; not language-combination coverage.
- [Current CI](../../.github/workflows/ci.yml) and
  [release workflow](../../.github/workflows/release.yml).
- [Compiler](../../src/visual_gasic_compiler.cpp),
  [VM](../../src/visual_gasic_instance_bytecode_vm.cpp),
  [Tier 2](../../src/visual_gasic_jit_tier2.cpp), and
  [Tier 3](../../src/visual_gasic_jit_tier3.cpp).
  Verify current dispatch, warmup thresholds, environment-variable behavior,
  and fallback paths rather than inferring them from names.
- Existing fixtures under [test suite](../../test_proj/test_suite), especially
  ByRef, mixed Variant, jump-table, UDT, and JIT branch-join regressions.
- [Previous correctness handoff](CURSOR_5_8_CORE_CORRECTNESS_HANDOFF.md).

Search for existing helpers and instrumentation first. Extend shared
infrastructure where appropriate, but do not change the malformed-mutation
gate into a different kind of test or weaken existing gates.

## Phase 1: a trustworthy semantic campaign

### A. Small typed generator and independent reference model

Suggested implementation location: `tools/semantic_fuzz/`, with thin shell
entry points under `scripts/` and harness self-tests in the repository's
existing test convention. Prefer standard-library dependencies.

Generate a structured, typed intermediate representation (IR), then:

1. Evaluate it using a small independent reference model.
2. Emit equivalent valid VG source.
3. Execute VG and compare typed observations with the reference.

The reference must not obtain its answer by executing the emitted VG, copying
the production evaluator, or assuming Python/GDScript semantics equal VB6.
Use explicit rules for integer division, rounding, truth values, conversion,
overflow domain, and evaluation order.

Start with bounded integer arithmetic, conditions, locals/globals, counted
loops, small helper functions, and sparse `Select Case`. Choose values whose
intermediate results stay exactly within a documented safe range. Exclude
division by zero, overflow, and ambiguous behavior from the initial domain.
Do not silently regenerate unsupported cases and count them as coverage.

For every modeled rule, record its repository language-contract/reference
source and hand-calculated boundary examples. Where documentation and runtime
disagree, report a contract question; do not silently bless current output
or invent a new language behavior.

Required initial case families:

- Literal-left and literal-right arithmetic with variable/expression operands;
  include noncommutative operators so an operand-order bug cannot hide.
- Sparse `Select Case`: widely separated values, holes, minimum/maximum,
  and `Case Else`; use actual executed outputs to check dispatch.
- Nested conditions/loops and observable helper-call side effects.
- Module/local values, changing inputs, and repeated calls spanning warmup.

Add metamorphic checks only with proven preconditions: renaming locals,
extracting a pure expression to a helper, or adding unreachable code must not
change observations. Do not apply floating-point reassociation or arbitrary
algebraic identities to mixed Variants.

### B. Machine-readable observations and strict failure handling

Use a versioned result schema and a unique completion marker. Observe values
and their types, ordered side effects, and relevant mutated state; a single
sum/checksum is insufficient. Compare observation sequence and count.

At minimum retain:

- schema/generator/reference-model versions, seed and case index;
- feature tags, typed inputs, expected observations and actual observations;
- source revision/worktree status, engine version, binary hashes and mode;
- process exit, timeout, completion status, runtime diagnostics;
- target-function execution-path evidence.

Encode integers exactly (for example decimal strings with an explicit type)
instead of accidentally rounding through JSON floating-point storage.
Reject missing/duplicate/malformed results, unexpected types, extra output
records, runtime errors, crashes, timeouts, and incomplete execution.
Do not suppress failures with `|| true`, broad catches, or successful empty
campaigns. An expected language-error test must specify its error contract
and is distinct from a valid-program campaign.

### C. Prove the path actually executed

Run the same cases with clean, explicit environments:

| Requested mode | Required evidence |
|---|---|
| Forced AST (`VG_FORCE_AST=1`) | Target function actually executes via AST |
| Interpreter (`VG_JIT=0`, AST force unset) | Target function executes bytecode, not AST fallback |
| Default runtime (overrides unset) | Record observed bytecode/native/fallback path |
| Tier-3 request (`VG_JIT=3`, AST force unset) | On supported builds, record actual selected tier or explicit decline |

These are requests, not assertions about the implementation. Verify current
flag meanings and supported platforms before wiring the matrix.

`VG_JIT_LOG` has compile-attempt/success/decline messages, but a successful
compile alone does not prove a native entry executed. Reuse existing
execution counters if sufficient; otherwise add minimal opt-in test
instrumentation at actual AST, VM, and native-entry dispatch points.

Identify script and function; attribute counts to the requested target,
including callees where the case requires it. Counters/traces must distinguish
compilation from execution and Tier 2 from Tier 3. No default logging, public
API expansion, or material hot-path cost when disabled.

Separate:

- **Required-path cases:** known-supported shapes; fail if expected path
  was never entered.
- **Fallback-contract cases:** unsupported shapes; assert the documented
  decline and correct fallback result without calling it native coverage.
- **Platform exclusions:** explicitly enumerate and report, never count as
  executed or let missing required coverage pass.

Exercise startup, threshold crossing, and post-warmup calls. Reset case state
after warmup when needed. Use known native-eligible kernels to prove the native
lane runs; do not force every generated feature through unsupported JIT code.
Include a short-circuit expression-join case that currently must safely
decline rather than undoing the release's correctness guard.

### D. Reproduction and reduction

Every failure saves original source/IR, expected/actual typed observations,
mode, seed, engine/binary identity, logs, and a one-command replay.

Implement a bounded IR-aware reducer: remove statements/branches/helpers and
shrink literals while preserving valid source, the same failure class, and
the relevant execution path. A wrong-result failure must not reduce into a
parse error, timeout, or unintended AST fallback. If reduction cannot proceed,
retain the original and report that fact.

Provide three working operations (exact CLI names are your choice):

- generate/run a deterministic seed and bounded case count;
- replay a saved case without generating a new one;
- reduce a saved failure within attempt/time limits.

Replay must recompute expectations from the retained IR/reference model and
check retained provenance/version compatibility, not just trust a saved
"expected" string.

### Phase 1 acceptance gate

- Fixed-seed output is reproducible; identifiers/paths do not change program
  content nondeterministically.
- At least 100 distinct generated programs for a pinned smoke seed; not 100
  executions of one template with no meaningful structural variation.
- Forced AST and bytecode coverage are verified; supported native kernels
  demonstrably execute after warmup. Explicitly report each path's counts.
- Independent hand-worked oracle tests cover operator boundaries and case
  dispatch before trusting campaign results.
- Self-tests demonstrate detection of wrong value, wrong type, reordered or
  missing effects, fallback masquerading as native, malformed/missing result,
  nonzero exit, timeout, crash classification, and empty campaign.
- Use a fake runner or test-only observation corruption for negative tests;
  do not leave a production runtime defect enabled to prove detection.
- The reducer demonstrably shrinks a seeded synthetic failing case while
  preserving failure identity/path.
- Every discovered real bug gets a minimal failing permanent fixture, a
  root-cause fix, and passing targeted regression plus relevant existing gates.
- Publish actual command, generated count, distinct cases, mode/path counts,
  elapsed time, failures and explicit exclusions. No invented measurements.

## Phase 2: interaction coverage that resembles real VG programs

Extend the model and deterministic fixtures incrementally, not with one
unreviewable generator rewrite:

1. Integer/Double conversions and VB-style rounding, especially negative ties;
   type preservation and explicitly chosen floating-point tolerances.
2. Mixed Variants: numeric strings, `Nothing`, operand-order asymmetry, Boolean
   conversion, and Dictionary missing-key behavior. Follow the established
   contract; `Nothing + n` and `n + Nothing` cannot be assumed equivalent.
3. ByRef/ByVal, expression-level calls, recursion, defaults, aliases, and
   imported modules; observe caller state and evaluate indexed arguments once.
4. Arrays, nested Dictionaries, UDT copies, and indexed member write-back;
   distinguish value copies from intended aliases.
5. Short-circuit calls with side effects, nested error handlers,
   `Try`/`Finally`, and fallback boundaries.

Use a pairwise feature matrix to ensure interactions are selected deliberately.
Add higher-order combinations based on actual bug clusters. A tag in the
manifest is not proof that the corresponding runtime operation executed.

Keep the supported random domain explicit. For features too complex for the
independent model initially, add hand-derived deterministic contract fixtures
and metamorphic checks instead of a misleading random oracle.

## Phase 3: deterministic game-shaped integration scenarios

Extract small standalone scenarios rather than launch whole games and call
"no crash" success. Use existing scene/test patterns and synthetic assets.

- **C64 CPU/memory:** an original synthetic instruction sequence with known
  intermediate registers, flags, PC and memory writes, covering sparse opcode
  dispatch, branches, addressing and wrapping. No copyrighted ROMs or boot
  timing as an oracle. Exercise the pure-VG CPU path, not native substitution.
  If testing the actual emulator requires changing user-edited files, stop
  and request coordination rather than overwrite them.
- **Spawn/update/remove:** fixed inputs and fixed simulation deltas over
  hundreds of steps; verify projectile/enemy counts, collisions, damage,
  iteration/removal behavior and destruction.
- **Lifecycle:** signals, timers, callbacks, scene transitions, disconnects,
  freed owners, and reload; assert event order and bounded cleanup. Use frame
  or fixed-step control, not fragile wall-clock sleeps.
- **Rendering:** a small real-renderer lane using a procedural framebuffer or
  image with known pixels/regions. Detect blank/uniform output and incorrect
  placement. Headless logic passing is not rendered-output proof.

Reuse `run_crystal_caverns_regression.sh` and existing editor/lifecycle helpers
where applicable. Do not hand-format damaged game source or change game speed
to make tests pass. Clean up all owned objects and test resources.

## Phase 4: CI, sanitizers, coverage, and sustained campaigns

### Fast gate

Add a bounded deterministic semantic smoke job/step that uses the correctly
built addon, explicit engine and binary provenance, no debugger, and a
supported platform matrix. Keep existing gates intact. Measure its real
duration before selecting PR/release budgets; slow long campaigns do not
belong on every edit.

### Nightly and manual campaigns

Add a scheduled and manually dispatchable workflow with configurable seed,
case count, and duration caps. Derive and record rotating nightly seeds;
retain fixed regression seeds too. Persist summaries and failure/reducer
artifacts even when the job fails. Propagate campaign failure to job status.

Do not silently test a stale bundled library. Avoid conflicting artifact
paths and use isolated job workspaces; run shared-state gates serially.

### Sanitizer lane

`SConstruct` already contains AddressSanitizer flag handling. Inspect its
actual option and compatibility before extending it. Reuse it for a bounded
native-memory lane; evaluate UBSan separately rather than assume it works
with the JIT/toolchain. Arrange correct sanitizer loading into Godot and
record exclusions.

Prove instrumentation is active with a controlled harness self-test outside
production code. Unexpected findings fail. Do not globally disable leak checks
or add broad engine suppressions; document any narrowly justified suppression.
Keep sanitizer results separate from timing claims.

### Honest coverage

Report modeled contract rules, feature pairs, observed execution paths,
fallback reasons, case counts, and exclusions. If collecting C++ line/branch
coverage, call it that; it does not measure native JIT machine-code coverage.
Use coverage gaps to drive new generator families, not a single misleading
"percent bug-free" score.

## Fix discipline and validation

1. Reproduce before patching; save the failing seed and minimized fixture.
2. Establish the language contract. Agreement between two buggy paths is not
   enough; a GDScript mismatch is not automatically a VG bug.
3. Fix the producer/root cause, not the sample, expected output, or fallback
   settings. Never relax a correctness gate to clear a release.
4. Run the smallest targeted tests covering the change, then relevant
   differential/regression gates. Use full hardening for final integration
   when runtime/compiler changes warrant it.
5. Rebuild the binaries actually loaded by tests and record hashes. Do not
   validate changed C++ against old shared libraries.
6. Preserve new regressions even when they expose a second unrelated defect;
   report remaining failures clearly.

## Required final handoff back

- Files changed, system architecture, supported semantic domain and exclusions.
- Runnable smoke, seeded campaign, replay, and reducer commands.
- Counts by family and actual path; oracle and harness negative-test results.
- Each real defect: minimal reproducer, root cause, fix and regression result.
- Existing regression/hardening results with exact commands and provenance.
- Measured CI duration, nightly limits and artifact locations.
- Explicit completion status for each phase and next unimplemented task.

Success means a repeatable system that discovers and explains wrong behavior
before a user encounters it in a game, not a claim of exhaustive correctness.
