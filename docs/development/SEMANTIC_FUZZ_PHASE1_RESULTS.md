# Semantic fuzz Phase 1 results (review, not committed)

## Architecture

| Piece | Location |
|---|---|
| Contracts | `docs/development/SEMANTIC_FUZZ_CONTRACTS.md` |
| IR / reference / emitter / generator | `tools/semantic_fuzz/` |
| Campaign / replay / reduce CLI | `python3 -m tools.semantic_fuzz {run,replay,reduce,selftest}` |
| Shell entry | `scripts/run_semantic_fuzz.sh`, `scripts/test_semantic_fuzz.sh` |
| Path evidence (`VG_SEM_PATH=1`) | `src/visual_gasic_sem_path.h` + hooks in call.inc / bytecode VM / JIT entry |

Domain: bounded Integer arith (`+ - * \ Mod`), `If`, `For`, sparse `Select Case`, helpers with ordered observations, warmup native kernels, one AndAlso fallback-contract fixture.

## Commands

```bash
# Harness + oracle negative tests (no Godot)
python3 -m tools.semantic_fuzz selftest

# Seeded campaign (isolated staging under test_proj/sem_fuzz_*; artifacts in --out)
unset GODOT  # or absolute path
python3 -m tools.semantic_fuzz run --seed 42 --count 100 \
  --modes forced_ast,interpreter,default --out /tmp/vg-sem-phase1

# Replay a saved case dir (recomputes expectations from IR)
python3 -m tools.semantic_fuzz replay /tmp/vg-sem-phase1/<case_id>/interpreter

# Reduce a saved failure (attempt/time bounded)
python3 -m tools.semantic_fuzz reduce /tmp/vg-sem-phase1/<case_id>/<mode>
```

## False-pass corrections (review round)

| Finding | Fix |
|---|---|
| Hardcoded `type=Integer` | Emitter uses `TypeName(_sem_obs)` after a single evaluation |
| Path check accepts wrong function | `path_target` required; only that fn’s counts count; fallback still validates bytecode decline |
| Timeout TypeError | `classify_timeout_output` normalizes bytes/None |
| `failure_code: null` on compare fails | Bundle writes explicit compare/`path_mismatch` code |
| Replay flips to interpreter | Mode from `program.json` / dirname; path checks on replay |
| Malformed OBS / duplicate DONE ignored | Strict `parse_log` fails the run |
| Salt fake distinctness | Salt removed; `distinct` + `distinct_shapes` reported; batch draws until N distinct |
| Reduction class drift | `identity.preserves_failure_identity` requires exact `failure_code` + path contract |
| Interpreter AST on bytecode target | `check_required_path` rejects AST events when bytecode is required |
| Native/bytecode → AST fallback in reduce | Rejected by identity predicate; selftests prove wrong_value≠wrong_type and AST reject |

## Acceptance evidence (seed 42, count 100)

Measured run (`/tmp/vg-sem-phase1-fixed`):

| Metric | Value |
|---|---|
| generated / distinct / distinct_shapes | 100 / 100 / **36** |
| modes | forced_ast, interpreter, default |
| failures | 0 |
| elapsed_ms | 115371 (~1.9 min) |
| families | arith_lit_left/right 12, noncomm 12, select_sparse 12, nested_cond_loop 10, helper_side_effect 11, module_local_warmup 13, metamorphic_pure_extract 12, fallback_andalso 6 |

Path totals (execution, not compile-only):

| Function | ast | bytecode | native_t2 |
|---|---:|---:|---:|
| SemMain | 100 | 200 | 0 |
| KernelNative | 13 | 26 | 52 |
| ShortJoin | 6 | 12 | 0 (decline / fallback contract) |
| PureAdd | 12 | 24 | 0 |
| Bump | 32 | 30 | 0 |

Provenance: git `14f6ed39…` (dirty worktree), Godot 4.6.1, binary sha256 `cc3e54d0…` after unary-minus Integer fix.

Selftest: `SELFTEST PASS` including timeout handler, wrong-function path reject, fallback path enforce, malformed/duplicate DONE, failure_code preservation, replay mode, no salt, runtime TypeName.

## Real defects found and fixed

| Item | Detail |
|---|---|
| Bug | `Case -N` parse error |
| Root cause | Case values used `parse_factor()` |
| Fix | `parse_unary()` for Case values/ranges |
| Regression | `test_select_case_negative.vg` |

| Item | Detail |
|---|---|
| Bug | `Dim r As Integer : r = -1000` → **Double** under bytecode/JIT, Integer under AST |
| Root cause | `eval_constant_expr` unary `-` always did `-((double)v)`; infer_type still VT_INT so Integer coercion skipped |
| Fix | Preserve INT64 in constant-fold; OP_NEGATE keeps INT |
| Regression | `test_neg_integer_literal.vg` (BC + AST) |
| Caught by | Runtime `TypeName` observations (the hardcoded-type false pass would have missed this) |

**Note:** This chat is on Auto while editing C++ parser/VM instrumentation; a follow-up on the pinned parser/VM model is recommended before merge if you want cross-tier review.

## CI semantic smoke gate (Task A)

Wired into `.github/workflows/ci.yml` after GDExtension smoke load. Release
reuses this job via `workflow_call` (not duplicated in `release.yml` or
`run_release_hardening.sh`).

```bash
export GODOT=/abs/path/to/Godot_v4.6.1-stable_linux.x86_64
./scripts/run_semantic_ci_smoke.sh
# selftest → seed=42 count=20 modes=forced_ast,interpreter,default,tier3
# fails hard on harness/campaign/path/provenance; step budget 180s (CI 5m)
```

Evidence: `campaign_summary.txt`, `campaign_report.json` (includes
`godot_sha256`, `binary_sha256`, `git_rev`), `native_tier_counts.txt`,
`gate_status.txt`. `native_t3=0` is reported honestly (VG_JIT=3 is a request).

Local acceptance (dirty worktree, Linux x86-64), final post-C1 binary
`87c744a679…`: smoke elapsed ≈ **23.5–31s**, generated=20 distinct=20
shapes=15, failures=0, KernelNative `native_t2=16` `native_t3=0`. CI gate
selftests cover injected selftest fail, wrong-output/path_mismatch campaigns
(fake runner), missing instrumentation, missing GODOT, schema refusal,
path_mismatch non-reducible, shared replay/reduce provenance, engine_hash in
bundles, `changed_environment_rerun:` labels (including engine replaced at the
same pathname).

Phase 2 C1 fixture `test_sem_c1_numeric_variant.vg`: **31/31** under
default, forced_ast, and interpreter. Defects found and fixed while landing
C1 (AST Integer←Nothing coerce; bytecode/compiler fold of `1 + Nothing`
via `vg_evaluate_vb_numeric`).

## Phase 2 defects found by the semantic campaign

Each row is a real cross-mode bug. Status is the source fix on `main`
(`48283c24`). The editor `.so` in the main tree was not rebuilt for that commit.

| Bug | Reproducer | Root cause | Status |
|---|---|---|---|
| Forced-AST ByVal argument evaluated twice | `test_proj/test_suite/test_ast_byval_arg_once.vg` (dispatch shape in `test_ast_byval_dispatch_probe.vg`) | `call_builtin_expr` in `src/visual_gasic_builtins.cpp` evaluated call arguments before the builtin dispatch. The caller now passes the already-evaluated argument array. | Fixed |
| Indexed ByRef subscript evaluated twice | `test_proj/test_suite/test_ast_byref_index_once.vg`; also `test_sem_c2_calls_byref.vg` (`indexed ByRef index once`) | ByRef write-back re-evaluated the index. `freeze_byref_lvalue` in `src/visual_gasic_instance_call.inc` / `src/visual_gasic_instance_evaluate.inc` snapshots the index once. | Fixed |
| Named ByRef write-back followed source order, not parameter order | `test_proj/test_suite/test_named_byref_writeback.vg` | Named-argument reorder and ByRef write-back did not share one parameter order (`src/visual_gasic_named_args.h`, call/evaluate). | Fixed |
| BUG-C4-1: `Exit` / `Return` / `Continue` inside `Try` skipped `Finally` on bytecode | `test_proj/test_suite/test_sem_c4_finally_exit.vg` | `STMT_EXIT`, `STMT_RETURN`, and `STMT_CONTINUE` in `src/visual_gasic_compiler.cpp` jumped out of the protected region. Finally is now an exit-code dispatch, innermost first. | Fixed |
| BUG-C4-2: constant `AndAlso` / `OrElse` folded to Nothing on bytecode | `test_proj/test_suite/test_sem_c4_const_logic.vg` | `compile_expression` folded a constant `BINARY_OP` before the short-circuit emit, and `eval_constant_expr` had no `AndAlso`/`OrElse` arm, so it returned `Variant()`. | Fixed |

## Phase completion

| Phase | Status |
|---|---|
| 1 Semantic campaign | **Complete** for acceptance gates above |
| 2 Interaction coverage | **Partial** — C1 done; C2 CP1 done, CP2 four-mode *request* lane (not verified path coverage), CP3 call-frame model partial; CP4 blocked. C3 gate is 20 runs and C4 gate is 16 runs. BUG-C4-1 and BUG-C4-2 are fixed in source. |
| 3 Game-shaped scenarios | **Not started** |
| 4 CI semantic smoke | **Wired** (local proof; GitHub Actions not claimed) |

## Not done / next

1. Phase 2 C1: model Variant/Double in IR/reference only after fixtures stay green; pairwise matrix.
2. C2 harness corrections landed (gate, Variant/order asserts, bounded call model, detector negatives, contracts). CP4 ByRef generators stay blocked until review. Indexed ByRef once-eval is a strict fixture assert (the old `C2_KNOWN_FAIL index_evals=2` line is history). C3 and C4 deterministic gates are in place; `GoTo` out of `Try` and errors raised inside `Finally` are still exclusions.
3. Longer scheduled campaigns / game-shaped integration (next handoff priority).
4. Do not commit until review (per assignment).

## Scoped diff (expected)

- `tools/semantic_fuzz/**`, `tools/__init__.py`
- `scripts/run_semantic_fuzz.sh`, `scripts/test_semantic_fuzz.sh`, `scripts/run_semantic_ci_smoke.sh`
- `.github/workflows/ci.yml` (semantic smoke + artifact upload)
- `docs/development/SEMANTIC_FUZZ_CONTRACTS.md`, this results file, handoff already present
- `src/visual_gasic_sem_path.h`, hooks in `visual_gasic_instance*.cpp/.inc`, Case parse fix
- `test_proj/test_suite/test_select_case_negative.vg`, `test_sem_c1_numeric_variant.vg`
- Rebuilt `addons/visual_gasic/bin/libvisualgasic.linux.editor.x86_64.so` (local; do not commit `.so` unless that is your release practice)
