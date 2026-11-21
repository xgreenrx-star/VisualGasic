# Semantic fuzz Phase 1 contracts

Independent reference rules for `tools/semantic_fuzz/`. Each rule cites a
repository language source. Hand-worked boundary examples are checked by
`tools/semantic_fuzz/oracle_selftest.py` before any campaign result is trusted.

## Domain (Phase 1)

In scope: bounded `Integer` arithmetic (`+ - * \ Mod`), comparisons in `If`,
locals/module Integer variables, counted `For` loops, small helpers, sparse
`Select Case` with `Case Else`, ordered `Print` observations.

Out of scope (explicit exclusions, never silently regenerated as coverage):
division by zero, overflow outside the documented safe range, floating-point,
mixed Variant/`Nothing`, ByRef, arrays/UDTs, short-circuit `AndAlso`/`OrElse`
as random features (one fixed fallback-contract fixture only), filesystem/OS/FFI,
(Resolved during Phase 1: `Case -N` parse error — fixed in parser via
`parse_unary` for Case values; regression `test_select_case_negative.vg`.)

Safe intermediate range: every modeled Integer stays in `[-1000000, 1000000]`.
Generator rejection of an out-of-range IR is a generation failure, not a pass.

## Rules

### R1 Integer addition / subtraction / multiplication

- Source: [VisualGasic_Language_Reference.md](../VisualGasic_Language_Reference.md)
  operators section; suite `test_operators.vg`.
- Semantics: exact Integer arithmetic within the safe range.
- Boundaries: `7 + 3 = 10`, `7 - 3 = 4`, `7 * 3 = 21`, `3 - 7 = -4` (noncommutative).

### R2 Integer division `\`

- Source: `test_operators.vg` (`10 \ 3 = 3`); VB6-style truncate toward zero after
  Integer operands (Phase 1 uses Integer literals/variables only).
- Boundaries: `10 \ 3 = 3`, `-10 \ 3 = -3`, `10 \ -3 = -3`, `-10 \ -3 = 3`.
- Exclude divisor `0`.

### R3 `Mod`

- Source: `test_operators.vg` (`10 Mod 3 = 1`); definition
  `a Mod b = a - (a \ b) * b` with the same `\` as R2.
- Boundaries: `10 Mod 3 = 1`, `-10 Mod 3 = -1`, `10 Mod -3 = 1`.
- Exclude modulus `0`.

### R4 Comparisons and `If` truth

- Source: language reference control-flow / Boolean use in conditions.
- Phase 1: comparison expressions used only as `If` conditions. Zero / False
  take the false branch; nonzero / True take the true branch.
- Boundaries: `5 > 3` true branch; `3 > 5` false branch; `4 = 4` true.

### R5 Sparse `Select Case`

- Source: language reference Select Case; Case lists and `Case Else`.
- Match the first Case whose value equals the selector; else `Case Else`.
- Boundaries: selector equals min Case, max Case, a hole → Else, and an interior hit.

### R6 Counted `For` loops

- Source: language reference `For` / `Next`; suite `test_for_loop.vg`.
- Phase 1: `For i = lo To hi` with step `+1`, body runs while `i <= hi`,
  inclusive. `lo > hi` runs zero times.
- Boundaries: `1 To 3` yields three iterations; `5 To 4` yields zero.

### R7 Helper calls and side effects

- Source: language reference procedures; observation order must match call order.
- Pure helpers return Integer; impure helpers may mutate a module Integer and
  that mutation is an ordered observation.
- Arguments evaluate left-to-right once before entry (Phase 1: Integer exprs only).

### R8 Operand order

- Literal-left and literal-right forms of noncommutative `-` and `\` must both
  appear so an operand-swap bug cannot hide.

## Mode requests (not implementation claims)

| Request | Environment | Required evidence when tagged required-path |
|---|---|---|
| Forced AST | `VG_FORCE_AST=1` | Target fn path=`ast` |
| Interpreter | `VG_JIT=0`, AST force unset | Target fn path=`bytecode` |
| Default | overrides unset | Record observed path (bytecode and/or native) |
| Tier-3 request | `VG_JIT=3`, AST force unset | Record `native_t3` or explicit decline |

Path lines are emitted only when `VG_SEM_PATH=1` (opt-in test instrumentation).
Compile-success log lines alone are not execution proof.

## Phase 2 C1 — Numeric / Variant (fixtures first)

Random generator domain remains Phase 1 Integer-only until these rules are
modeled in `reference.py`. Deterministic fixture:
`test_proj/test_suite/test_sem_c1_numeric_variant.vg`. Independent oracle helpers:
`tools/semantic_fuzz/vb_round.py` + `oracle_selftest` / `phase2_c1_selftest`.

### R9 Banker's rounding (`CInt` / Integer assign)

- Source: language reference `CInt`; suite `test_vb_integer_rounding.vg`.
- Halves round to nearest even: `CInt(2.5)=2`, `CInt(3.5)=4`,
  `CInt(-2.5)=-2`, `CInt(-3.5)=-4`. Non-ties round away from the midpoint
  (`CInt(3.7)=4`, `CInt(-3.7)=-4`). Values just above a positive tie round up
  (`CInt(2.5000001)=3`).
- Assigning a fractional value to `As Integer` uses the same rule.

### R10 Double / Variant type retention

- A `Double` (or Variant holding a float) keeps the fraction until an explicit
  integer conversion or typed Integer assignment.
- `CInt` on a Variant yields Integer type after conversion.

### R11 Numeric strings via conversion builtins

- `CInt("42")` / `CDbl("3.14")` parse decimal strings.
- **Exclusion (not yet modeled):** bare `3 + "2"` / `"2" + 3` currently yield
  `Nothing` under Godot 4.6.1 editor builds — do not treat as VB6 Val-coerce
  until a language contract and suite fixture are locked.

### R12 Dictionary missing keys

- `d("missing")` is `Nothing` (`VarType` 1); `Err.Number` stays 0.
- Typed numeric accumulation `s = s + d("missing")` coerces Nothing like 0
  (language reference; `test_jit_string_dict_globals.vg` SumMiss).

### R13 Nothing arithmetic (asymmetric; Variant vs typed destination)

Source: `vg_evaluate_vb_numeric` in `src/visual_gasic_godot_ctors.h`; suite
`test_sem_c1_numeric_variant.vg`. Operand order matters:

- **Left Nothing:** `Nothing + 1` / `Nothing - x` / `Nothing * x` → `Nothing`
  (undeclared AccNoValue; Nothing±Vector).
- **Numeric left + Nothing right:** coerce right like 0 → numeric result
  (`1 + Nothing` → `1`; `s = s + d("missing")` → unchanged when missing is 0).
- **Typed Integer/Double destination:** `x = Nothing` coerces to `0` and keeps
  the declared numeric type (AST must match bytecode).
- **Typed Single/Double left + Nothing:** coerces Nothing like 0. Observed:
  after `Dim s As Single: s = s + Nothing`, `TypeName(s)` may report `Double`
  — assert value `0`, not a Nothing result.
- Object/Vector Nothing arithmetic remains covered by vector suite tests, not
  this numeric fixture.

### C1 exclusions (pairwise matrix not yet claimed)

ByRef, arrays/UDT, short-circuit side effects, overflow/NaN/div0, random
Variant generation, and bare string↔number `+` without `CInt`/`CDbl`.

## Phase 2 C2 — Calls / ByRef / imports

Sources: language reference [ByRef](../VisualGasic_Language_Reference.md#byref) /
[ByVal](../VisualGasic_Language_Reference.md#byval); suites listed below.
Primary same-file fixture: `test_proj/test_suite/test_sem_c2_calls_byref.vg`.
Mode lane: `scripts/run_semantic_c2_fixtures.sh`.

**Evidence layout (`SEM_C2_OUT`):** root has `latest_run.txt`, mirrored
`c2_fixture_summary.txt` / `gate_status.txt` (invalidated to `fail` at start of
each invocation). Per-run files live under `run_<id>/` (`*.log`, `*.paths`,
`*.judge.err`, summary/status). Godot `user_*` caches are not CI artifacts.
CI upload patterns must include the nested run files (see `.github/workflows/ci.yml`).

**Checkpoint status (harness corrections before CP4):**

| CP | Claim | Status |
|---|---|---|
| CP1 | Deterministic same-file ByRef/ByVal fixture + hardened log gate | **Done** (fail-closed shell+judge: nonzero exit, script/runtime errors, empty/malformed/forged verdicts, exact PASS identities + `C2_SUMMARY`, exact known index `2`, no `current_test.txt` writes; shell probes in `c2_fixture_shell_selftest`) |
| CP2 | Module-qualified path evidence for selected fixtures | **Mostly done** — `mod="<percent-encoded res://…>"`; strict allowed-tier sets (AST-only / bytecode-only never absorb extras); `path_enabled()` guards note sites; dual-import same-name Twin is an explicit known-defect lane (`scripts/run_semantic_c2_known_defects.sh`), not a green assert. Same-basename different dirs: `test_sem_c2_alt_basename.vg`. Tier-3 request ≠ native_t3. |
| CP3 | Independent Integer call / ByRef model | **Partial** — `byref_model.py` has Locations, frames, ByRef/ByVal binding, return slot, recursive frame restore + ordered write-back. Detector negatives go through `compare_observations`. Not yet a general VG call oracle; no CP4 generators on this model until frames/bindings stay green under review. |
| CP4 | Generated ByRef cases | **Blocked** until CP1–CP3 harness corrections above are accepted |

**Default parameter mode:** a bare `param As Integer` is **ByRef** (lang ref).
`test_byref_byval.vg` and C2 fixture `StandaloneDefault` prove this. Do not
assume ByVal-default from other BASIC dialects.

**Fixture observations:** use `AssertObs(ByVal actual As Variant, …)` so
`TypeName` is checked before numeric compare (no Integer-parameter coercion
hiding a wrong type). Nested order uses an event string
(`outer_enter;inner;outer_exit`), not a numeric sum of deltas.

**Fixture gate:** `tools/semantic_fuzz/c2_fixture_gate.judge_c2_log` — a log
with `SCRIPT ERROR` + completion marker + exit 17 + zero `PASS:` is **FAIL**,
not PASSED. Primary fixture asserts indexed ByRef once (`gIdxEvals=1` and
slot `105`). A `C2_KNOWN_FAIL index_evals=` line is rejected.

### Prior-art map (existing fixtures)

| Rule | Proving fixture(s) |
|---|---|
| Standalone ByRef mutates caller | `test_byref_byval.vg` IncrementByRef; C2 `StandaloneByRef` |
| Explicit ByVal leaves caller | `test_byref_byval.vg` IncrementByVal; C2 `StandaloneByVal` |
| Expression ByRef return + mutation | `test_byref_byval.vg` DoubleAndReturn; C2 `ExprByRef` |
| Two distinct ByRef args | `test_byref_byval.vg` SwapValues; `test_call_byref_scalar.vg` swap_pair |
| Indexed slot write-back | `test_byref_array_slot.vg`; `test_byref_computed_index.vg` |
| Import same-module ByRef hot path | `test_byref_import.vg` + helper |
| AST caller → imported ByRef | `test_byref_ast_import.vg` + helper |
| Caller import string ByRef | `test_byref_caller_import.vg` |
| JIT/project multi-ByRef outs | `test_byref_project.vg` |

### Hand tables (Integer; model + fixture)

Notation: `caller` state → call → return / final caller.
Independent model: `tools/semantic_fuzz/byref_model.run_hand_tables`.

1. **Standalone ByRef** — `x=3` → `StandaloneByRef(x)` → `x=4`
2. **Expression ByRef** — `x=3` → `r=ExprByRef(x)` → `r=10`, `x=5`  
   (`x:=x+2` → 5; return `5*2`)
3. **ByVal control** — `x=3` → `ExprByVal(x)` → `r=10`, `x=3`
4. **Default bare = ByRef** — `x=10` → `StandaloneDefault(x)` → `x=11`
5. **Two distinct** — `x=5,y=3` → `TwoDistinct` → `x=6,y=13`
6. **Alias same var twice — OBSERVED, not language-locked** — `x=3` →  
   `AliasTwice(x,x)` → final **`x=13`** under copy-in / ordered write-back on
   the current runtime (AST and bytecode agree). This is **observed behavior**,
   not a sufficient language contract for the random oracle. Keep the probe;
   do not treat `f(x,x)→13` as a locked law until specified separately from
   “AST/bytecode agreement.”
7. **Nested** — `x=0` → events `outer_enter;inner;outer_exit`, final **`x=111`**
8. **Recursive ByRef + Optional default depth=2** — `x=0` → `RecAdd(x)` →  
   `r=6`, `x=2` (levels bump `n` then `return RecAdd(n,d-1)+n`)

### Unresolved / out of random oracle

| Topic | Evidence | Action |
|---|---|---|
| Side-effecting index evaluated once | `BumpSlot(arr(IdxSide()))` writes slot `105` and `IdxSide` runs once. History: before the AST freeze, the same call wrote the right slot only because `IdxSide` always returned 1, while the index ran twice. That `index_evals=2` line is history, not a pass. | Gate requires the once assertion and the slot assertion. A `C2_KNOWN_FAIL index_evals=` record (including 2) fails `judge_c2_log`. Wrong slot, wrong count, and a wrong IdxSide tier fail the same entry point. Impure indexes still decline bytecode; `_Ready` may stay on the AST walker. No random indexed-ByRef oracle. |
| Indexed ByRef captures an index, not a container | `test_ast_byref_index_edges.vg` `ReDim` during a later argument. The index is evaluated once. Write-back resolves the variable name again and stores into the replacement array. The array object from before `ReDim` is not pinned. | Unresolved container-identity contract. Do not describe the frozen index as a pinned location. No random oracle. |
| Named-argument order across tiers | Forced AST evaluates named call arguments in source order. Bytecode modes can differ because the compiler rewrites the live AST in place, and a later bail leaves that rewritten tree. | Observation only. `obs-order-gate` is a diagnostic of the measured shapes (below). It is not a language contract and it is not a CI job. |
| MemoryBuffer indexed ByRef write-back | `Call Bump(buf(NextSlot()))` raises error 5 `Unsupported array assignment base: buf (type Object)`. The callee runs, the index runs once, and the bytes stay unchanged. Direct `buf(i) = n` still stores. | Known limitation. `test_ast_byref_index_edges.vg` prints `KNOWN_LIMITATION kind=buffer_byref_writeback` and asserts the current error. When write-back is implemented, update those asserts to error 0, byte 0 = 110, byte 1 unchanged, one index, and one callee, and remove the limitation note. A future fix fails this fixture until that edit. |
| Alias `f(x,x)→13` | Observed copy-in/write-back; AST/bytecode agree | Probe only; **not** oracle-locked language law |
| Overlapping alias live-sharing | Do not model shared-cell without new evidence | Model remains copy-in/write-back |
| Dual-import same-name `Module.Twin()` | When both `c2_path_mod_a` and `c2_path_mod_b` are imported, bare/`qualified` Twin binds the first import (observed). | Visible known-defect lane `scripts/run_semantic_c2_known_defects.sh` (`ok_known_defects_visible`). Single-import fixtures `test_sem_c2_twin_{a,b}_only.vg` prove each module alone. Dual-import fixture covers EntryA/EntryB/CallBoth module tags only. Engine fix out of this harness exchange. |
| Same-name module scalar across files | `Import` currently shares one `Dim` namespace. The language reference separates module environments. | Generator exclusion `multi_file_same_name_module_scalar`. Not a green assert and not a settled namespace contract. |
| Tier-3 request versus executed tier | `VG_JIT=3` asks for native Tier 3. Eligible kernels in the Phase 1 smoke have been observed as `native_t2`. `native_t3=0` means Tier 3 did not execute. | `scripts/run_semantic_ci_smoke.sh` records `native_tier_counts.txt` and requires `native_t2`, not `native_t3`. Do not report a tier-3 request as a tier-3 execution. |
| Import path attribution | `VG_SEM_PATH … mod="res://…"` on instrumented builds | Path-verified for fixtures with `path_requirements` in the manifest; others remain assertion / request-lane |

### Observational order diagnostic

`python3 -m tools.semantic_fuzz obs-order-gate` reruns three fixtures under
four requested modes and checks `VG_SEM_PATH` shapes inside marked windows.
The shapes encode today's split: the AST walker evaluates named arguments in
source order, and the compiler can mutate the live AST before a bytecode
bail. That split is not an approved language contract. `.github/workflows/ci.yml`
does not run this diagnostic. Correctness stays on the VG suite and on
`judge_c2_log` / the C2 path requirements.

Update the diagnostic when the live-AST mutation is fixed and both tiers share
one order: change `EXPECT` in `tools/semantic_fuzz/obs_order_gate.py` to that
order, and keep the docstring stating it is observational until a language
rule exists. Do not add the current BAN-versus-ABN table to CI as a required
semantic check. The gate entry `run_gate` is fail-closed for a nonzero child,
a runtime error, a missing or repeated completion, a bad summary, and a path
event from the wrong module. Those process checks are harness hygiene. They
do not promote the recorded order to a contract.

### Remaining fuzz exclusions

Phase 1 smoke is `scripts/run_semantic_ci_smoke.sh` (selftest, then seed 42,
count 20, modes `forced_ast,interpreter,default,tier3`). The bounded C2
campaign is `scripts/run_semantic_c2_campaign.sh` (count 14, one case per
`C2_FAMILIES` entry, same four modes, family-coverage gate). Neither generator
emits impure indexed ByRef, repeated ByRef alias, nested ByVal call-argument
side effects, dual-import same-name procedures, or same-name module scalars.

### C2 exclusions (generator)

Random ByRef IR, indexed ByRef with impure indices, multi-module generated
imports, ParamArray, object ByRef, and undocumented alias cell-sharing.
CP4 generators stay blocked until CP1–CP3 review.

## Phase 2 C3 — Collections (deterministic slice)

The focused fixtures `test_sem_c3_array_slot.vg` and
`test_sem_c3_dict_keys.vg` check array element ByVal isolation and ByRef
write-back, once-only indexed evaluation, dictionary missing-key reads, and
present-key updates. They assert values, types, and unchanged neighbors.
The dictionary fixture captures `Err.Number` immediately after the missing-key
read as a Variant.

Run the local, path-checked gate against an isolated test project:

```bash
python3 -m tools.semantic_fuzz c3-fixture-gate \
  --project /absolute/path/to/test_proj --godot /absolute/path/to/godot \
  --out /absolute/path/to/new-gate-output
```

The output directory must be new, empty, or previously owned by this gate.
The gate checks exact assertion labels and counts, process errors, completion,
and module-qualified paths. `python3 -m tools.semantic_fuzz selftest` includes
gate negative and positive checks. The C3 fixture gate itself is not a CI
step; its selftests run as part of the existing semantic smoke selftest.
Requested Tier 3 is not proof of Tier 3 execution.

Deterministic fixtures remain the path-checked gate baseline. A **bounded**
generated C3 IR slice (`domain=c3`) covers fixed-size Integer arrays (literal
indices only) and Dictionary present-key read/write plus missing-key probes
(`DictMissCheck` → VarType 1 / Is Nothing / Err.Number 0 per R12). Expected
observations come from `reference.evaluate_program`, not another VG run.

Still outside the C3 oracle: missing-key ByRef write-back, container identity
after replacement or `ReDim`, MemoryBuffer indexed ByRef, impure indexed ByRef,
alias, and named-argument order.

### C3b — nested containers, UDT copy, iteration

Fixtures: `test_sem_c3b_nested.vg`, `test_sem_c3b_udt_copy.vg`,
`test_sem_c3b_iterate.vg`. The C3 gate runs these with the two C3 fixtures:
5 fixtures × 4 modes = **20** runs.

```bash
python3 -m tools.semantic_fuzz c3-fixture-gate \
  --project /absolute/path/to/test_proj --godot /absolute/path/to/godot \
  --out /absolute/path/to/new-gate-output
```

| Topic | Contract |
|---|---|
| Nested Dictionary/Array | **OBSERVED** Godot reference semantics: assigning the inner container shares that object, so a write through one name is visible through the other. Neighbors of the written slot stay unchanged. |
| UDT assignment | VB6 value copy. Mutating the copy, a `ByVal` parameter, or a function return does not change the source. A default/`ByRef` parameter mutates the caller. |
| `Dictionary.Remove` of a missing key | **OBSERVED**: `Err.Number` stays 0 and `Count` is unchanged. Capture `Err.Number` immediately. |
| `For Each` | Array elements and `Dictionary.Keys` in insertion order are in the iterate fixture. Mutating the collection during `For Each` is excluded. |

Generated C3b families (`c3b_nested_dict_array`, `c3b_udt_copy`) follow the same
rules. Nested and UDT shapes may still compile to AST when bytecode cannot
emit them; the gate records that path rather than treating it as a value bug.

## Phase 2 C4 — Short-circuit and Finally

Fixtures: `test_sem_c4_shortcircuit.vg`, `test_sem_c4_errors.vg`,
`test_sem_c4_finally_exit.vg`, `test_sem_c4_const_logic.vg`.
4 fixtures × 4 modes = **16** runs.

```bash
python3 -m tools.semantic_fuzz c4-fixture-gate \
  --project /absolute/path/to/test_proj --godot /absolute/path/to/godot \
  --out /absolute/path/to/new-gate-output
```

| Topic | Contract |
|---|---|
| `AndAlso` / `OrElse` | Short-circuit. Left is evaluated first. A false `AndAlso` left or a true `OrElse` left does not evaluate the right. |
| `And` / `Or` | **OBSERVED**: both sides run, left first. Excluded from the `c4_shortcircuit` generator (`non_shortcircuit_and_or`). |
| `Finally` | Runs once, innermost first, when `Exit` `Sub`/`Function`, `Return`, `Exit` `For`/`Do`, or `Continue` leaves `Try` or `Catch`. The function return value is kept. Fall-through `Finally` also runs. |
| Constant fold | Constant `AndAlso` / `OrElse` / `Not` fold to Boolean (VarType 11) with the short-circuit value, including `0 OrElse 5` and `Not (True AndAlso False)`. |
| Errors | `Resume Next`, `GoTo` handler, and `Try`/`Catch`/`Finally` order are deterministic fixtures only. Random error boundaries are excluded. |

Exclusions: `GoTo` that jumps out of `Try` (not required to run `Finally`), and
errors raised inside `Finally` (current AST semantics, not a separate oracle).
There is no separate `Exit Property` bytecode kind.

## Replay / reduction provenance (shared)

Module: `tools/semantic_fuzz/provenance.py` (used by both `replay` and `reduce`).

| Check | Behavior |
|---|---|
| `schema_version` / `generator_version` / `reference_version` | Hard refuse (`replay refused:` / `reduce refused:`) |
| `binary_hash` (VG `.so`) | Soft label `changed_environment_rerun:binary_hash_changed` |
| `engine_hash` (Godot sha256) | Soft label `…:engine_hash_changed`; if path unchanged also `engine_replaced_same_path` |
| `engine_path` | Soft label `…:engine_path_changed` when the path string differs |

Bundles (`failure.json` / `program.json`) persist `binary_hash`, `engine_hash`, and
`engine_path` with the version fields. A changed-environment label means the
rerun is not identical historical reproduction — never silent.