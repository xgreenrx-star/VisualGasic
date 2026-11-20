# Known defect: forced_ast double-evaluates nested ByVal call args

- Case: `c2_byval_once` (`TakeVal(Side())` with `Side` bumping module `hits`)
- Independent oracle: `byval_r=4`, `byval_hits=1`
- Observed:
  - `forced_ast`: `byval_hits=2` (Side runs twice)
  - `interpreter` / `default` / `tier3`: matches oracle (`hits=1`)
- Not fixed in CP3 (no C++ authorized). Keep visible; do not warp oracle.
