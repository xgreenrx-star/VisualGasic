# Python Bridge Examples (v6.0)

These examples demonstrate VisualGasic's Python integration via the `PyBridgeFacade` class (Tier A out-of-process worker).

## Prerequisites

- **VisualGasic v6.0+** compiled with default settings
- **Python 3** installed and on `PATH`
- No `python=1` build flag required — Tier A works with any Python 3 installation
- Optional: **`pip install numpy`** for numpy sections

## How It Works

1. VG script creates a `New PyBridgeFacade` object
2. `InitializeBridge()` launches `python_worker.py` as a subprocess
3. The worker communicates over stdin/stdout with **length-prefixed frames** (4-byte LE size + payload)
4. **Default payload:** JSON. **Opt-in (C2):** msgpack when `vg/python/use_typed_protocol = true` — preserves int vs float on the wire.
5. `PyImport("module")` imports a Python module and returns an opaque handle
6. `PyCall(handle, "method", args)` calls a function on that module

### Enabling typed msgpack (recommended for numpy integer args)

**Project → Project Settings → Vg → Python → Use Typed Protocol** (`vg/python/use_typed_protocol`, default `false`).

```ini
[vg]
python/use_typed_protocol=true
```

`test_proj/project.godot` ships with this enabled for regression tests. The run script below uses `test_proj`.

With typed protocol enabled, `PyCall(builtins, "range", Array(0, 5))` and `numpy.zeros(5)` work without `CInt()` wrappers.

## Examples

| File | Description | Typed protocol |
|------|-------------|----------------|
| `demo_python_bridge.vg` | Full walkthrough: math, json, numpy, errors, `PyProcessBuffer` | Optional (`zeros` falls back to `CInt`) |
| `demo_python_game_dev.vg` | Game-flavored math, numpy vectors, JSON config, seeded RNG | Optional |
| `demo_python_typed_protocol.vg` | **C2 showcase:** `range`, `list(range)`, `numpy.zeros` / `eye` with bare int args | **Required** |
| `demo_python_await.vg` | **`PyCallAsync`** — poll `IsRunning` / `Result` until complete (`Await pyJob` planned) | Optional |
| `demo/test_py_async.vg` | Polling `IsRunning` / `PyCallMany` / `PyEnvInfo` (in `demo/` project) | Optional |

## Running

From the repo root (recommended):

```bash
# Default: full bridge walkthrough
scripts/run_python_bridge_demo.sh

# Typed msgpack C2 (uses test_proj with use_typed_protocol=true)
scripts/run_python_bridge_demo.sh demo_python_typed_protocol.vg

# Async PyCallAsync (poll until complete)
scripts/run_python_bridge_demo.sh demo_python_await.vg

# Game dev patterns
scripts/run_python_bridge_demo.sh demo_python_game_dev.vg
```

The script copies the demo into `test_proj/demos/python/`, prepares the GDExtension, and runs headless via `run_suite.gd`.

## Error Diagnostics

If the worker fails to launch:

- Check that `python3 --version` works in your terminal
- The bridge prints a descriptive error via `GetStatus()`
- Worker Python errors appear in Godot's output console (stderr is not redirected)

## Notes

- The demos let `InitializeBridge()` report startup errors directly (no separate `IsAvailable()` preflight).
- `PyProcessBuffer()` serializes bulk bytes through the worker's binary lane; the main demo shows JSON byte-array round-trip.
- Do not name async handles `task` — **`Task` is a reserved VG keyword**; use `pyJob` instead.

## Reference

- [docs/python_bridge_v6_minimal_spec.md](../../docs/python_bridge_v6_minimal_spec.md)
- [docs/SYSTEM_INTEGRATION.md §17](../../docs/SYSTEM_INTEGRATION.md#17-python-bridge-pybridgefacade)
- Regression: `test_proj/test_suite/test_py_msgpack_typed.vg`, `test_py_range_int.vg`

## numpy Support

| Operation | Example | JSON default | With typed protocol |
|-----------|---------|--------------|---------------------|
| `numpy.array([1,2,3])` | `PyCall(np, "array", …)` | ✅ | ✅ |
| `numpy.dot` / `sum` / `linalg.norm` | float arrays | ✅ | ✅ |
| `builtins.range(0, 5)` | `Array(0, 5)` | ❌ (float args) | ✅ |
| `numpy.zeros(5)` / `eye(3)` | `Array(5)` / `Array(3)` | ❌ unless `CInt()` | ✅ |

**Performance:** Small arrays (< 100×100) are fine over JSON. Large-array binary fast path remains planned.
