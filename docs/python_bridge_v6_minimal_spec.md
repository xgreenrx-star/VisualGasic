# VisualGasic v6 Python Bridge Minimal Spec

Status: Draft
Owner: VisualGasic core
Scope: v6.0 baseline for Python library integration

## 1. Goals
1. Provide a small, stable API for using Python libraries from VG scripts.
2. Keep VG language surface minimal (no large Python-specific keyword expansion).
3. Support robust worker lifecycle, clear errors, and predictable behavior.
4. Keep performance reasonable with batch and binary data lanes.

## 2. Non-Goals (v6)
1. Full Python object model in VG syntax.
2. Embedded CPython as the default path.
3. Zero-copy transfer for all types.
4. Package manager UX beyond basic environment checks.

## 3. Architecture
1. Default backend: Tier A out-of-process worker.
2. Optional backend: Tier B embedded CPython (feature-gated by build flag).
3. Single C++ facade API used by VG runtime regardless of backend.
4. Worker protocol: length-prefixed frames on stdout/stdin.
   - **Default:** JSON payload.
   - **Opt-in C2:** msgpack payload when `vg/python/use_typed_protocol = true` (preserves int/float; same framing).
5. Diagnostics channel: stderr only (not mixed into protocol channel).

## 4. Public VG Surface (Minimal)
These are runtime-callable functions exposed via the existing bridge class and VG binding layer.

1. PyImport(module_name As String) As Variant
Behavior:
- Imports a Python module and returns a handle.
- Handle is opaque to VG code. In Tier A it may be the module name string.

2. PyCall(handle As Variant, method As String, args As Array) As Variant
Behavior:
- Synchronous call to module method/function.
- Returns JSON-safe Variant value.

3. PyCallAsync(module As String, method As String, args As Array) As Variant
Behavior:
- Non-blocking call path.
- Returns task/handle compatible with VG async system.
- v6 fallback may execute synchronously with explicit status note if async queue path is not yet available.

4. PyProcessBuffer(handle As Variant, method As String, buffer As PackedByteArray) As Variant
Behavior:
- Explicit lane for large payloads.
- v6 baseline may serialize through JSON if binary lane is not yet implemented.
- Must preserve byte order and length exactly.

5. PyGetStatus() As String
Behavior:
- Returns current backend and health summary.

6. shutdown() As Void
Behavior:
- Graceful worker shutdown and bridge cleanup.

## 5. Optional v6.1 Additions (Not required for v6.0)
1. PyCallMany(calls As Array) As Array
- Batch multiple calls in one IPC roundtrip.

2. PyLastError() As Dictionary
- Returns latest structured error with traceback and call context.

3. PyEnvInfo() As Dictionary
- Interpreter path, version, worker backend, basic capability flags.

## 6. C++ Facade Contract
Class: PyBridgeFacade

Required behavior:
1. initialize_bridge()
- Reads project setting vg/python/embedded_enabled.
- Selects backend and validates startup via ping.

2. send_request()
- Serializes full request-response transaction for thread safety.
- Must guard against interleaved calls on shared pipes.

3. write_to_worker()/read_from_worker()
- Must use framing-safe helpers (write_all/read_exact).
- Enforce payload max size guard.

4. launch_worker()/kill_worker()/check_worker_alive()/queue_restart()
- Launch and monitor worker process.
- Preserve import cache across restart.
- Surface actionable status messages.

5. Error normalization
- Return a Dictionary with status=error and message when IPC/runtime failures occur.

## 7. Worker Protocol v1
Frame format:
- [uint32_le payload_len][UTF-8 JSON bytes]

Request schema:
{
  "kind": "ping" | "import" | "call" | "call_many" | "shutdown",
  "request_id": <int>,
  "module": <string optional>,
  "method": <string optional>,
  "args": <array optional>,
  "calls": <array optional>
}

Response schema:
{
  "kind": "result" | "error",
  "request_id": <int>,
  "status": "ok" | "error",
  "value": <json optional>,
  "message": <string optional>
}

Protocol rules:
1. request_id must be echoed in response.
2. Unknown command returns structured error response.
3. EOF on stdin exits worker cleanly.
4. Worker never writes non-framed protocol data to stdout.

## 8. Type Mapping Rules (v6)
Python to VG (response):
1. None -> Null Variant
2. bool/int/float/str -> corresponding Variant scalar
3. bytes -> UTF-8 string with replacement fallback (v6 baseline)
4. list/tuple -> Array
5. dict -> Dictionary (keys stringified)
6. numpy scalar/array -> item()/tolist() fallback
7. unsupported objects -> string representation

VG to Python (request args):
1. Variant scalars -> native Python scalars
2. Array -> list
3. Dictionary -> dict
4. PackedByteArray -> array of ints for v6 baseline unless binary lane is active

## 9. Error Model
Every failure path must be actionable.

Return shape:
{
  "status": "error",
  "message": "human-readable summary",
  "request_id": <id when applicable>,
  "details": {
    "backend": "tier_a" | "tier_b",
    "module": "...",
    "method": "...",
    "traceback": "..."
  }
}

Rules:
1. Do not throw generic panics into VG script runtime.
2. Include traceback for Python exceptions.
3. Include exact operation context (module/method/request_id).
4. Keep status string stable for caller-side branching.

## 10. Project Settings
Required:
1. vg/python/embedded_enabled (bool, default false)

Recommended:
1. vg/python/use_typed_protocol (bool, default false) — when true, C++ facade and worker use msgpack instead of JSON; preserves Variant::INT on the wire. Worker CLI: `--typed-protocol`.
2. vg/python/worker_timeout_ms (int, default 5000)
3. vg/python/max_payload_bytes (int, default 1048576)
4. vg/python/auto_restart (bool, default true)

## 11. Build and Packaging
1. Include src/python_bridge/*.cpp in SConstruct sources.
2. Register PyBridgeFacade in register_types.cpp.
3. Bundle addons/visual_gasic/python_worker.py with plugin artifacts.
4. If python=1 build arg is passed, define VG_HAS_PYTHON when toolchain support exists.

## 12. Performance Baseline
1. p50 call latency for trivial call <= 2x local script call in same environment.
2. No main-thread stutters from long Python operations when async path is used.
3. Payload safety cap enforced.
4. Worker restart recovers from crash without editor restart.

## 13. Security and Safety Baseline
1. No shell command execution in worker protocol.
2. Module/method dispatch only from explicit request fields.
3. Reject oversized payloads.
4. Never mix stderr logs into framed protocol stream.

## 14. v6 Acceptance Checklist
1. Bridge initializes and ping succeeds on Linux/macOS.
2. PyImport and PyCall work for stdlib module examples.
3. Structured error returned for bad module and bad method.
4. Worker crash triggers restart and module cache recovery.
5. Concurrent calls do not cross-wire responses.
6. Protocol framing survives partial read/write conditions.
7. SConstruct includes python_bridge sources.
8. Register_types includes facade registration and project setting.
9. Python worker is packaged and discoverable at runtime.

## 15. Suggested Starter Test Matrix
1. Unit: framing helpers read_exact/write_all.
2. Integration: ping/import/call/shutdown happy path.
3. Integration: Python exception returns traceback.
4. Integration: timeout path returns error status.
5. Integration: restart path after forced worker termination.
6. Integration: large payload rejected at cap.
7. Integration: async path does not block main thread contract.

## 16. Implementation Notes for DeepSeek
1. Preserve existing class and method names where already wired.
2. Keep changes minimal and additive.
3. Do not broaden VG syntax in v6; use bridge functions first.
4. Prioritize correctness and error quality before performance tuning.
5. If async queue is not fully ready, keep behavior explicit in status/error messaging.
