# Same-name module scalar (VG Import)

**Status:** measured mismatch — unsupported pair `multi_file_same_name_module_scalar`.

The reference `Env.module_stores` model treats per-module Dim cells as distinct.
That is an **independent intended semantics for the oracle**, not a settled VG
language/engine contract. Measured Godot Import currently shares one Dim
namespace for the same name.

## Reference expectation (`Env.module_stores`)

Caller `x` and library `x` are distinct cells.

| Observe | Value |
|---------|-------|
| r | 10 |
| x (caller) | 5 |
| lib_x (library peek) | 8 |

See `expected_reference.json` from `hand_same_name_module_ns()`.

## Measured Godot (interpreter)

Command (repo root, `GODOT` set):

```bash
python3 - <<'PY'
from pathlib import Path
from tools.semantic_fuzz.generator_c2 import hand_same_name_module_ns
from tools.semantic_fuzz.runner import run_program
p = hand_same_name_module_ns()
rr = run_program(p, mode="interpreter", work_root=Path("/tmp/vg-same-name-measure"), timeout_secs=45)
print(rr.ok, rr.observations)
PY
```

Measured actual (`godot_actual.json` / `MEASUREMENT.json`):

| Observe | Value |
|---------|-------|
| r | 10 |
| x | 5 |
| lib_x | **5** (shared Dim / ByRef alias; not 8) |

`match: false`. Campaign families use distinct lib scalar `lx` until engine module namespaces exist.
