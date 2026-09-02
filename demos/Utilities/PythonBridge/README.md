# Python Bridge Examples (v6.0)

These examples demonstrate VisualGasic's Python integration via the `PyBridgeFacade` class (Tier A out-of-process worker).

## Prerequisites

- **VisualGasic v6.0+** compiled with default settings
- **Python 3** installed and on `PATH`
- No `python=1` build flag required — Tier A works with any Python 3 installation

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

With typed protocol enabled, `PyCall(builtins, "range", Array(0, 5))` works without wrapping arguments in `CInt()`. Regression: `test_proj/test_suite/test_py_msgpack_typed.vg`.

## Examples

| File | Description |
|------|-------------|
| `demo_python_bridge.vg` | Full walkthrough: import `math`/`json`, call functions, error handling, bulk data |

## Running

```bash
godot --headless --script demos/Utilities/PythonBridge/demo_python_bridge.vg
```

Or copy the `Main()` sub into any VG script and call it.

## Error Diagnostics

If the worker fails to launch:
- Check that `python3 --version` works in your terminal
- The bridge prints a descriptive error via `GetStatus()`
- Worker Python errors appear in Godot's output console (stderr is not redirected)

## Notes

- The demo avoids `PyBridgeFacade.IsAvailable()` and lets `InitializeBridge()` report startup errors directly.
- `PyProcessBuffer()` in v6 serializes a `PackedByteArray` through JSON, so the demo shows the resulting JSON byte array text.

## Reference

See `docs/python_bridge_v6_minimal_spec.md` for the full spec.

## numpy Support

The demo includes a numpy section that tests core operations through the JSON IPC:

| Operation | Example | Status |
|-----------|---------|--------|
| `numpy.array([1,2,3])` | `bridge.PyCall(npMod, "array", Array(Array(1,2,3)))` | ✅ Works |
| `numpy.dot(a, b)` | `bridge.PyCall(npMod, "dot", Array(a, b))` | ✅ Works |
| `numpy.sum(a)` | `bridge.PyCall(npMod, "sum", Array(a))` | ✅ Works |
| `numpy.linalg.norm(v)` | `bridge.PyCall(linAlgMod, "norm", Array(v))` | ✅ Works |
| `numpy.float32(x)` | `bridge.PyCall(npMod, "float32", Array(x))` | ✅ Works |
| 2D arrays | `numpy.array([[1,2],[3,4]])` → nested VG arrays | ✅ Works |

**Limitation (JSON default):** VG `Array()` stores all numbers as floats on the **JSON wire path**. Functions requiring integer arguments (e.g. `numpy.zeros(5)`, `numpy.eye(3)`, `numpy.linspace(0,1,5)`) receive `[5.0]` which numpy rejects with `TypeError: 'float' object cannot be interpreted as an integer`.

**Fix (shipped C2):** Enable **`vg/python/use_typed_protocol = true`** — msgpack preserves `Variant::INT` on encode. Alternatively wrap args with `CInt()` on the JSON path.

**Performance:** Small arrays (< 100×100 elements) are fine over JSON. Large-array binary lane (PackedFloat64Array fast path) remains planned for a future phase.
