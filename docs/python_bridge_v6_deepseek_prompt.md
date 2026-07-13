# DeepSeek Implementation Brief: VisualGasic v6 Python Bridge

Use this as the exact implementation brief.

## Objective
Implement the v6 minimal Python bridge for VisualGasic with correctness-first behavior, minimal VG surface expansion, and robust IPC lifecycle.

Reference spec:
- docs/python_bridge_v6_minimal_spec.md

## Hard Constraints
1. Keep VG language changes minimal. Do not add broad new Python-specific keywords.
2. Preserve existing public names already wired where possible.
3. Prioritize correctness, clear errors, and lifecycle stability before optimization.
4. Do not mix worker stderr into protocol stdout.
5. Keep edits scoped and additive.

## Required Deliverables
1. C++ bridge facade behavior finalized.
2. Python worker protocol compliance finalized.
3. Build and registration wiring complete.
4. Basic tests or verification scripts for acceptance checklist.

## Implementation Tasks

### A. Bridge API Surface (v6 minimal)
Implement and/or validate:
1. PyImport(module_name)
2. PyCall(handle, method, args)
3. PyCallAsync(module, method, args)
4. PyProcessBuffer(handle, method, buffer)
5. PyGetStatus
6. shutdown

Notes:
1. If async queue is not fully ready, keep explicit fallback messaging.
2. Keep return values JSON-safe and consistent.

### B. C++ Facade Correctness
1. Ensure initialize_bridge selects backend by project setting vg/python/embedded_enabled.
2. Ensure send_request is request-response serialized for shared pipe safety.
3. Ensure framing-safe I/O helpers are used (read_exact/write_all).
4. Enforce payload cap and timeout handling.
5. Ensure restart preserves imported module cache and re-imports after relaunch.
6. Ensure status strings remain actionable.

### C. Worker Protocol Compliance
1. Use framed protocol: [uint32_le length][UTF-8 JSON payload].
2. Implement request kinds: ping, import, call, call_many, shutdown.
3. Echo request_id in responses.
4. Return structured error payloads on all failures.
5. Exit cleanly on EOF or shutdown.
6. Keep stdout protocol-only; diagnostics on stderr.

### D. Type Mapping (v6 baseline)
1. Python None/bool/int/float/str -> VG Variant equivalents.
2. list/tuple -> Array.
3. dict -> Dictionary with string keys.
4. bytes -> UTF-8 string fallback.
5. numpy scalar/array via item/tolist fallback.
6. Unsupported values -> string fallback.
7. PackedByteArray lane may use JSON fallback in v6 if binary lane not complete.

### E. Error Model
Every failure must return structured details:
1. status=error
2. message summary
3. request_id when applicable
4. operation context: backend/module/method
5. traceback for Python exceptions

### F. Build + Packaging
1. Ensure SConstruct compiles src/python_bridge/*.cpp.
2. Ensure register_types registers PyBridgeFacade and project setting.
3. Ensure addons/visual_gasic/python_worker.py is packaged and discoverable at runtime.
4. Honor python=1 build flag behavior for VG_HAS_PYTHON.

## Acceptance Criteria
All must pass:
1. Bridge initializes and ping succeeds on Linux and macOS.
2. PyImport and PyCall succeed for stdlib examples.
3. Invalid module/method returns structured errors.
4. Forced worker death triggers restart and recovers imports.
5. Concurrent calls do not cross-wire responses.
6. Partial I/O conditions do not break framing.
7. Build wiring includes python_bridge sources.
8. Worker script is present in runtime package path.

## Suggested Validation Set
1. Happy path: ping/import/call/shutdown.
2. Error path: bad import and bad method.
3. Timeout path.
4. Restart path after kill.
5. Concurrency stress with multiple simultaneous calls.
6. Large payload cap rejection.

## Output Format Expected From DeepSeek
1. File-by-file patch summary.
2. Any API behavior changes called out explicitly.
3. Acceptance criteria checklist with pass/fail per item.
4. Known limitations deferred to v6.1+.
