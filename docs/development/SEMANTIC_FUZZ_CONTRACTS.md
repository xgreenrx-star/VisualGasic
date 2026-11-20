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
not PASSED. Primary fixture also requires an explicit
`C2_KNOWN_FAIL index_evals=N want=1` line (N≠1).

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
| Side-effecting index evaluated once | `BumpSlot(arr(IdxSide()))`: write-back OK (`105`), but `IdxSide` runs **twice** (bind + write-back) on forced_ast, interpreter, default, and tier3-request | Gate requires **exactly one** `C2_KNOWN_FAIL index_evals=2 want=1` (documented defect). Rejects 0/1/3/999, duplicates, malformed, and missing records. Count `1` → `index_once_unexpectedly_fixed_update_contracts` (must update contracts, not silent waive). **Not** silent green. No random indexed-ByRef oracle until once-eval is fixed in engine. |
| Alias `f(x,x)→13` | Observed copy-in/write-back; AST/bytecode agree | Probe only; **not** oracle-locked language law |
| Overlapping alias live-sharing | Do not model shared-cell without new evidence | Model remains copy-in/write-back |
| Dual-import same-name `Module.Twin()` | When both `c2_path_mod_a` and `c2_path_mod_b` are imported, bare/`qualified` Twin binds the first import (observed). | Twin identity proven via single-import fixtures `test_sem_c2_twin_{a,b}_only.vg`. Dual-import fixture covers EntryA/EntryB/CallBoth module tags only. Engine fix out of this harness exchange. |
| Import path attribution | `VG_SEM_PATH … mod="res://…"` on instrumented builds | Path-verified for fixtures with `path_requirements` in the manifest; others remain assertion / request-lane |

### C2 exclusions (generator)

Random ByRef IR, indexed ByRef with impure indices, multi-module generated
imports, ParamArray, object ByRef, and undocumented alias cell-sharing.
CP4 generators stay blocked until CP1–CP3 review.

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