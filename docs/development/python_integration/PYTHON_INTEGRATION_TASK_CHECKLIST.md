# VisualGasic Python Integration — Task Checklist

This checklist is derived from `PYTHON_INTEGRATION_PLAN.md` and the two source briefs in this folder.
It is ordered to keep performance, compatibility, and ease of use intact.

---

## Dependency map

1. `SConstruct` opt-in flag and facade skeleton must exist before any runtime work.
2. Tier A worker/process bootstrap must exist before IPC framing and diagnostics can be verified.
3. IPC framing must exist before async call batching and tooling can be validated.
4. Embedded Tier B work must not begin until Tier A is stable.
5. Zero-copy buffer work depends on the embedded C-API path and GIL handling.
6. Desktop export packaging and compatibility tests depend on the worker path and diagnostics.

---

## Phase 1 — Build system gate and facade skeleton

### Tasks
- Add `python=1` as an opt-in build flag in `SConstruct`.
- Define `VG_HAS_PYTHON` only when the flag is enabled.
- Keep default builds unchanged when `python=1` is absent.
- Create `src/python_bridge/visual_gasic_py_facade.h`.
- Create `src/python_bridge/visual_gasic_py_facade.cpp`.
- Add `PyBridgeFacade::initialize_bridge()`.
- Add `PyBridgeFacade::py_import(const String &module_name)`.
- Add `PyBridgeFacade::py_process_buffer(...)` placeholder.
- Add a project setting key for backend selection, defaulting to the non-embedded path.

### Acceptance criteria
- Project builds successfully with and without `python=1`.
- The new facade compiles in both modes.
- No existing engine behavior changes when Python support is disabled.

---

## Phase 2 — Tier A worker bootstrap

### Tasks
- Add `python_worker.py`.
- Add worker launch logic to `visual_gasic_process.cpp`.
- Detect local virtual environment Python first.
- Fall back to system Python when a local interpreter is unavailable.
- Add process monitoring for unexpected exits.
- Queue a restart task when the worker dies.
- Emit structured warnings through `visual_gasic_error_reporter.h`.

### Acceptance criteria
- Worker starts on Linux and Windows desktop builds.
- Worker shutdown and crash both produce readable diagnostics.
- Restart behavior is observable and does not freeze the editor.
- Missing Python produces a clean, user-facing error.

---

## Phase 3 — IPC protocol and async control path

### Tasks
- Implement the 4-byte length-prefixed frame format.
- Define MsgPack control payloads for `ping`, `import`, `call`, `call_many`, `result`, `error`, `shutdown`.
- Add request IDs for correlating responses.
- Add binary-safe handling for large payloads.
- Route calls through the existing async queue.
- Add batching for repeated small calls.

### Acceptance criteria
- Small control calls round-trip reliably.
- Bulk payloads are transmitted without corruption.
- Async calls never block the render/frame thread.
- `ping` returns worker metadata and version info.

---

## Phase 4 — Tooling and project setup

### Tasks
- Add a project wizard action for enabling Python.
- Add venv creation or detection.
- Add dependency install support.
- Add a Python diagnostics panel or readout.
- Show interpreter path, package availability, and worker status.
- Add one simple sample that exercises a real library.

### Acceptance criteria
- A user can enable Python without editing build files manually.
- Diagnostics clearly show what interpreter is active.
- The sample project runs without manual bridge configuration.

---

## Phase 5 — Compatibility hardening

### Tasks
- Smoke-test Linux desktop export.
- Smoke-test Windows desktop export.
- Validate missing package behavior.
- Validate worker crash behavior.
- Validate missing interpreter behavior.
- Document supported package classes and platform constraints.
- Mark mobile and web as unsupported for the initial release.

### Acceptance criteria
- Both desktop targets fail gracefully on misconfiguration.
- Error messages are actionable and do not crash Godot.
- Compatibility matrix is documented and matches actual behavior.

---

## Phase 6 — Embedded Tier B scaffolding

### Tasks
- Add `PyBridgeDiagnostics` traceback handling.
- Add `PyObjectWrapper` for imported Python objects.
- Add embedded import and call support behind `VG_HAS_PYTHON`.
- Wrap all C-API usage in GIL guards.
- Keep embedded mode opt-in only.

### Acceptance criteria
- Python exceptions are printed to the Godot console.
- Embedded calls return typed failures instead of hard crashes.
- Default builds still work with Python disabled.

---

## Phase 7 — Zero-copy bulk data lane

### Tasks
- Add `PackedByteArray` sharing via `PyMemoryView_FromMemory`.
- Prevent copies for large buffer operations.
- Add a bulk-data sample such as image processing or audio transforms.
- Verify profiler traces for the zero-copy path.

### Acceptance criteria
- Buffer operations mutate in place when intended.
- No hidden per-element copy appears in the hot path.
- The sample demonstrates a measurable performance gain.

---

## Phase 8 — Release polish

### Tasks
- Write user-facing docs for both tiers.
- Write upgrade notes.
- Add examples for `PyImport`, `PyCallAsync`, and buffer processing.
- Add final regression tests.
- Lock the performance and compatibility targets for release.

### Acceptance criteria
- Documentation matches the shipped behavior.
- The feature is explainable to new users in one page.
- Final regression suite passes on the supported matrix.

---

## Suggested implementation order

1. Phase 1.
2. Phase 2.
3. Phase 3.
4. Phase 4.
5. Phase 5.
6. Phase 6.
7. Phase 7.
8. Phase 8.

This order keeps the first release safe, portable, and usable before any embedded-runtime work is attempted.
