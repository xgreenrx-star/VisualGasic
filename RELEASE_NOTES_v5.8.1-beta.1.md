# VisualGasic 5.8.1 Beta 1

Correctness bug-fix beta. This remains a public beta, not stable VG6.
Back up projects, close Godot, and replace the entire `addons/visual_gasic/`
folder when upgrading. These fixes are in the native runtime and require the
new binaries.

All fixes below were found by the new semantic fuzzer, which runs the same
generated program under the AST interpreter, the bytecode interpreter
(`VG_JIT=0`), the default runtime, and Tier-3 JIT, and fails when any mode
disagrees with an independent reference model.

## Fixed

- **`Exit` / `Return` / `Continue` inside `Try` now run `Finally` on bytecode.**
  `Exit Sub`, `Exit Function`, `Exit For`, `Exit Do`, `Return`, and
  `Continue For` jumped out of the protected region and skipped `Finally`
  (the AST interpreter was already correct). Nested `Try` blocks run each
  `Finally` innermost first. Regression: `test_sem_c4_finally_exit.vg`.
- **Constant `AndAlso` / `OrElse` fold to Boolean.** Expressions with only
  constant operands, such as `True AndAlso True` or `(1 < 2) AndAlso (2 < 3)`,
  evaluated to `Nothing` under bytecode. Regression: `test_sem_c4_const_logic.vg`.
- **Call arguments are evaluated once (AST).** A ByVal argument with side
  effects, for example `F(Counter())`, ran twice when the procedure executed
  on the AST interpreter. Regression: `test_ast_byval_arg_once.vg`.
- **Indexed ByRef subscripts are evaluated once.** For `Bump arr(NextIdx())`
  the write-back recomputed the index and could update a different element.
  Regression: `test_ast_byref_index_once.vg`.
- **Named ByRef arguments write back in parameter order.** Named-argument
  reordering and ByRef write-back now use the same mapping. Regression:
  `test_named_byref_writeback.vg`.
- **`Case -N` parses.** Negative literals and ranges in `Select Case` arms
  (`Case -1`, `Case -5 To -1`) were a parse error. Regression:
  `test_select_case_negative.vg`.
- **Negative Integer literals stay Integer on bytecode/JIT.**
  `Dim r As Integer : r = -1000` produced a `Double` under bytecode/JIT and an
  `Integer` under AST. Regression: `test_neg_integer_literal.vg`.

## Testing tools

- Semantic fuzzer and reference oracle under `tools/semantic_fuzz/`
  (`python3 -m tools.semantic_fuzz selftest`), with fail-closed fixture gates for
  calls/ByRef (C2), collections, nested containers and UDT copy (C3), and
  short-circuit evaluation and error boundaries (C4).
- Language contracts the fuzzer checks:
  [`docs/development/SEMANTIC_FUZZ_CONTRACTS.md`](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/development/SEMANTIC_FUZZ_CONTRACTS.md).
  Findings: [`docs/development/SEMANTIC_FUZZ_PHASE1_RESULTS.md`](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/development/SEMANTIC_FUZZ_PHASE1_RESULTS.md).

## Known limitations

- `GoTo` out of a `Try` block still skips `Finally`.
- `Tween` has no AST-interpreter implementation (bytecode only).
- `Enum.Parse` / `.ToString` / `.Values` / `.HasFlag` and typed-collection
  auto-instantiation are AST-only; bytecode raises "Method call on Null object".
- Nested containers share the inner `Array`/`Dictionary` (Godot reference
  semantics), not VB6 copy semantics.

## Validation

Local, Linux x86-64, Godot 4.6.1, editor build `a515e15b`:

- Runtime suite: 307 files, 2,393 assertions passed, zero failures.
- C3 fixture gate 20/20 and C4 fixture gate 16/16 across forced-AST,
  interpreter, default, and Tier-3 JIT.

The [tagged release workflow](https://github.com/xgreenrx-star/VisualGasic/actions/runs/44910359646)
passed for source revision `0a48bb1d79b274ecea8a0908a07d2150567e7761`:
CI gates, Linux/Windows/macOS/Web builds, packaging, and the packaged
Asset Library archive smoke test. All downloaded assets passed SHA-256
verification and every ZIP passed integrity checks.
