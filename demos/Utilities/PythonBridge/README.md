# Python Bridge Examples (v6.0)

These examples demonstrate VisualGasic's Python integration via the `PyBridgeFacade` class (Tier A out-of-process worker).

## Prerequisites

- **VisualGasic v6.0+** compiled with default settings
- **Python 3** installed and on `PATH`
- No `python=1` build flag required — Tier A works with any Python 3 installation

## How It Works

1. VG script creates a `New PyBridgeFacade` object
2. `InitializeBridge()` launches `python_worker.py` as a subprocess
3. The worker communicates over stdin/stdout with length-prefixed JSON frames
4. `PyImport("module")` imports a Python module and returns an opaque handle
5. `PyCall(handle, "method", args)` calls a function on that module

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
