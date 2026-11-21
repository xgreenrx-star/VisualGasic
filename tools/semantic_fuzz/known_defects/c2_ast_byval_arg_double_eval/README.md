# Fixed: forced_ast nested ByVal arg double evaluation

**Status:** Fixed in semantic bugfix checkpoint 002 (AST expression path).

## Historical defect

- Case: `c2_byval_once` (`TakeVal(Side())` with `Side` bumping module `hits`)
- Independent oracle (unchanged): `byval_r=4`, `byval_hits=1`
- Observed before fix:
  - `forced_ast`: `byval_hits=2` (Side ran twice)
  - `interpreter` / `default` / `tier3`: matched oracle (`hits=1`)
- Root cause: `call_builtin_expr` evaluated arguments while probing builtins;
  `evaluate.inc` then evaluated them again for the user call. Builtins that
  handled the call were once-only; unhandled user Subs were double-evaluated.

## Fix

- Evaluate expression-call arguments once, in source order, then pass that
  Array into `call_builtin_expr` (no internal re-eval). Builtins that handle
  the call win before any named-argument bind. If they do not, already-evaluated
  values are bound onto the user Sub without a second evaluation.
- Permanent VG regression: `test_proj/test_suite/test_ast_byval_arg_once.vg`
- IR example `c2_byval_once` is a strict oracle match in all modes.

## Not fixed here

- Indexed ByRef once-eval is fixed separately (`test_ast_byref_index_once.vg`, C2 slot and count asserts). The old `index_evals=2` record is history.
- Dual-import same-name Twin and unsettled module scalar namespace — out of scope.

`results.json` retains pre-fix observations for history.
