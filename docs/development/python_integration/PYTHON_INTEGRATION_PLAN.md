# VisualGasic Python Integration — Implementation Plan

**Status:** Design / planning. No code written yet.
**Source input:** `Python_Implimentation_ideas/Googles AI Said` (embedded-CPython blueprint).
**Authoring constraints (ranked):** 1) Performance, 2) Compatibility, 3) Ease of use.
**Target release window:** v6.0 (see `ROADMAP.md` v6.0 + `/memories/repo/v6.0_blockers.md`).

---

## 0. TL;DR — what we are actually building

The "Googles AI Said" document proposes a single approach: **embed CPython in-process**
inside the GDExtension, marshal via the Python C-API, and share bulk data with the
**buffer protocol** (zero-copy). That approach is the right *performance ceiling*, but on
its own it is a **compatibility and ease-of-use risk** (export size, native-wheel ABI,
GIL stalls, hard crashes, signing/notarization on macOS, no mobile/web).

**Recommendation: ship a two-tier engine with one VG-facing API.**

- **Tier A — Out-of-process worker (default, ships first).** Reuses VG's existing
  `visual_gasic_ipc.cpp` / `visual_gasic_process.cpp` / `visual_gasic_async.cpp`.
  Maximum compatibility (any Python, any wheel, isolated crashes), easiest to ship,
  safe on every export target. This is the *compatibility floor*.
- **Tier B — Embedded CPython + zero-copy buffer protocol (opt-in, performance lane).**
  Implements the Google blueprint exactly where it matters: hot data paths
  (images/audio/tensors) with `PyMemoryView_FromMemory` against `PackedByteArray`.
  This is the *performance ceiling*.

Both tiers sit behind **one identical VG syntax and one C++ facade**, so user code never
changes when the backend is swapped. Start on Tier A, add Tier B behind a project setting.

This directly satisfies the three ranked goals:
- **Performance** → Tier B zero-copy + Tier A async batching keep the frame thread free.
- **Compatibility** → Tier A is the guaranteed-portable default; Tier B is opt-in per platform.
- **Ease of use** → one syntax, one wizard, automatic backend selection, clean errors.

---

## 1. Reuse what VG already has (do not rebuild)

| Need | Existing VG module to build on |
|---|---|
| Out-of-process worker + pipes | `src/visual_gasic_ipc.cpp`, `src/visual_gasic_process.cpp` |
| Non-blocking calls / await | `src/visual_gasic_async.cpp`, `Await` (confirmed working since v4.2) |
| Raw byte buffers / zero-copy target | `src/visual_gasic_memory_buffer.cpp`, Godot `PackedByteArray` |
| Native lib loading pattern | `src/visual_gasic_ffi.cpp` + `SConstruct` libffi conditional block |
| Tokenizer / parser / compiler hooks | `visual_gasic_tokenizer.cpp`, `visual_gasic_parser.cpp`, `visual_gasic_compiler.cpp` |
| Runtime evaluation of new nodes | `visual_gasic_instance_*` (evaluate/execute/expression) |
| Error surfacing to console | `visual_gasic_error_reporter.h`, `UtilityFunctions::printerr` |

The Google doc's `PyBridgeDiagnostics` (Python traceback → Godot console) is sound and
should be adopted **for Tier B**. For Tier A, the worker serializes its own traceback
string back over IPC — no GIL/C-API needed in the engine process.

---

## 2. One VG-facing surface (identical across both tiers)

Keep the syntax minimal and VB6-flavored. Backend choice is invisible to the script.

```vb
' Import a module (resolves to whichever tier is active)
Set np = PyImport("numpy")

' Call methods with VG values
Dim s As Double
s = py.sqrt(64)                 ' module-level call via a default 'py' handle
Dim arr
Set arr = np.array(MyList)      ' object handle round-trips as an opaque PyObject ref

' Zero-copy bulk path (Tier B fast lane; Tier A falls back to a copy + transfer)
PyProcessBuffer(np, "blur_in_place", myPackedByteArray)
```

- `PyImport(name)` → returns a VG object handle wrapping a backend reference.
- `handle.method(args)` → dynamic invocation; args marshaled by the active backend.
- `PyProcessBuffer(handle, fn, buffer)` → explicit bulk/zero-copy entry point.
- `PyCallAsync(...)` / `Await` → non-blocking variant for heavy work (ML inference).

**Ease-of-use rule:** the *same* program runs on Tier A or Tier B. If Tier B is unavailable
on a platform, the call transparently routes to Tier A (with a one-time info log).

---

## 3. Tier A — Out-of-process worker (DEFAULT, ships first)

### 3.1 Topology
```
[ VG Script ] -> [ C++ PyBridge facade ] --IPC(JSON/msgpack)--> [ python_worker.py ]
                                                                  (venv interpreter)
```
- Worker is a small, shipped `python_worker.py` launched via `visual_gasic_process.cpp`.
- Protocol: length-prefixed framed messages. Control payloads = JSON; bulk payloads =
  raw binary block (msgpack/flat buffer) to avoid base64 bloat.
- Worker pool: configurable N processes; keep interpreters warm to amortize startup.

### 3.2 Performance measures (critical)
- All calls run through the async job queue (`visual_gasic_async.cpp`); **never block the
  frame thread.** `_Process`-side code uses `PyCallAsync` + `Await`.
- `call_many` batching API to amortize IPC round-trips.
- Binary payload mode for arrays/images; never JSON-encode bulk numeric data.
- Per-call telemetry: queue wait, exec time, serialize time, payload bytes.

### 3.3 Compatibility wins
- Any Python version/venv the user points at; native wheels "just work" (numpy, opencv,
  torch) because they load in a normal interpreter process.
- A crashing/segfaulting Python lib **cannot** take down Godot — worker dies, engine logs
  it and restarts the worker.
- Safe on every desktop export target; clean, typed failure on mobile/web.

### 3.4 Tradeoff
- IPC overhead (~tens of µs to low ms per call). Mitigated by batching + async + keeping
  bulk data out of the control channel. Not suitable for per-pixel-in-a-loop chatter —
  that is exactly what Tier B exists for.

---

## 4. Tier B — Embedded CPython + zero-copy (OPT-IN performance lane)

This is the Google blueprint, scoped to where it pays off. Gate behind a project setting
`vg/python/embedded_enabled` (default off) and a per-platform availability check.

### 4.1 Control path (C-API object wrap)
- Implement `PyObjectWrapper : RefCounted` (as in the doc): holds `PyObject*`,
  `Py_INCREF`/`Py_DECREF` in set/dtor, `call_method(name, Array)` marshals VG `Variant`
  → `PyObject*` tuple → `PyObject_CallObject` → back to `Variant`.
- Expand marshaling beyond INT/STRING to: FLOAT, BOOL, `Packed*Array`, `Array`→list,
  `Dictionary`→dict, and opaque `PyObjectWrapper` passthrough.

### 4.2 Data path (zero-copy buffer protocol)
- `process_godot_buffer_in_python(PackedByteArray, PyObject* fn)` using
  `PyMemoryView_FromMemory(ptrw(), size, PyBUF_WRITE)` — NumPy/OpenCV mutate Godot memory
  in place. This is the headline performance feature (no allocation, no copy).
- **Safety:** pin/own the buffer for the call duration; document that the buffer must not
  be resized while a view is live.

### 4.3 GIL + threading (mandatory, or it crashes)
- Wrap **every** C-API touchpoint in `PyGILState_Ensure()` / `PyGILState_Release()`.
- Run heavy embedded calls on a background worker thread (Godot `WorkerThreadPool` or
  VG's task system in `visual_gasic_task.cpp`), release GIL around blocking native calls,
  marshal results back to the main thread for engine mutations.

### 4.4 Diagnostics (adopt from the doc)
- `PyBridgeDiagnostics::check_and_print_python_errors()` after every C-API call:
  `PyErr_Fetch` → `traceback.format_exception` → `UtilityFunctions::printerr`. Wrap all
  invocations in `safe_execute_python_call()` so a Python exception returns an empty
  `Variant` instead of crashing the engine. **Build this FIRST in the Tier B work.**

### 4.5 Build + distribution (SConstruct)
- Mirror the existing libffi conditional in `SConstruct`:
  - linux/macos: `env.ParseConfig("python3-config --cflags --ldflags --embed")`
  - windows: `thirdparty/python-embed` include/libs, link `python3`.
  - Guard all of it behind `python=1` build flag + `CPPDEFINES=["VG_HAS_PYTHON"]` so the
    default binary is unchanged and builds without Python installed.
- Ship a **pinned, isolated** runtime next to the binary using the doc's `pythonXXX._pth`
  isolation trick so the embedded interpreter ignores the user's system Python.
- Pin one CPython minor (e.g. 3.11) for ABI stability across the matrix.

---

## 5. Compiler frontend (shared by both tiers)

Implement once; backend-agnostic. Follow the doc's pipeline but keep it small.

1. **Lexer** (`visual_gasic_tokenizer.cpp`): add `TK_PYIMPORT` ("PyImport"). Reuse the
   existing `.` token; mark member access on a Python handle at resolve time, not lex time.
2. **Parser** (`visual_gasic_parser.cpp`): add `AST_PyImportNode` (stores module name) and
   reuse the existing method/member-call node, tagging the base as a Python handle when the
   symbol resolves to a `PyObjectWrapper`/Tier-A handle. Avoid a bespoke call node if the
   existing call AST can carry a "python-dynamic" flag — less surface area.
3. **Bytecode/eval** (`visual_gasic_compiler.cpp` + `visual_gasic_instance_*`): emit calls
   into the C++ `PyBridge` facade. **Important:** ensure these compile to bytecode (do not
   silently fall back to AST — see `/memories/repo/v6.0_blockers.md` #0). Add a smoke test
   that asserts a `PyImport`-using sub stays on the bytecode path.

**Ease of use:** because both tiers share this frontend, teaching material and IntelliSense
entries (`PyImport`, `PyProcessBuffer`, `PyCallAsync`) are written once.

---

## 6. Phased rollout

| Phase | Deliverable | Tier | Goal served |
|---|---|---|---|
| 1 | Spec + `PyBridge` C++ facade + protocol contract | A | compat/ease |
| 2 | Out-of-process worker + JSON control + venv launch | A | compat |
| 3 | Async queue, batching, binary bulk payload, telemetry | A | performance |
| 4 | IDE wizard ("Enable Python"), venv create/install, diagnostics panel | A | ease |
| 5 | Desktop export packaging (Linux/Windows) + CI smoke | A | compat |
| 6 | `PyBridgeDiagnostics` + embedded build flag (`python=1`) | B | stability |
| 7 | `PyObjectWrapper` control path + full marshaling | B | performance |
| 8 | Zero-copy buffer protocol path (`PackedByteArray`) | B | performance |
| 9 | GIL/threading hardening + background execution | B | performance/stability |
| 10 | macOS embedded support + signing/notarization docs | B | compat |

Tiers A (phases 1–5) ship **before** any embedded work. Embedded (6–10) is additive and
opt-in, so it can never regress the default product.

---

## 7. Compatibility matrix (initial)

| Target | Tier A (worker) | Tier B (embedded) |
|---|---|---|
| Linux x86_64 editor/desktop | ✅ first | ✅ first |
| Windows x64 editor/desktop | ✅ first | ✅ first |
| macOS desktop | ✅ phase 5 | ⚠️ phase 10 (signing) |
| Android / iOS | ❌ typed runtime error + docs | ❌ |
| Web (wasm) | ❌ typed runtime error + docs | ❌ |

Package classes (document explicitly): pure-Python wheels = supported first; native wheels
= per OS/arch matrix; GPU/CUDA stacks = advanced profile, not baseline.

---

## 8. Performance + stability exit criteria for "v6.0-ready"

- Tier A: p99 control-call overhead < 10 ms for small payloads on reference desktop.
- Tier B: zero-copy buffer op shows **no allocation** and no per-element copy in profiler.
- No frame hitch > 4 ms attributable to Python on the benchmark scene (both tiers).
- Deterministic failure: timeout, missing package, worker crash, Python exception all
  return typed VG errors and never hard-crash Godot.
- Green Linux + Windows desktop export with documented package constraints.
- Two shipped sample apps: `data_clean.py` (pandas via Tier A) and `image_blur` (numpy
  zero-copy via Tier B).

---

## 9. Security + isolation

- Worker/embedded runs in project-scoped working-dir jail by default.
- Explicit allowlist for spawned commands; network policy off unless enabled.
- First-time approval prompts for: venv creation, package install, external binds.
- Redact secrets/tokens in IDE output and logs.

---

## 10. Non-goals for the first release

- Full mobile/web Python parity.
- One-click support for every native-wheel ecosystem.
- Making embedded CPython the default (it stays opt-in until the matrix is green).

---

## 11. Honest delta from the "Googles AI Said" document

The source doc is a good **Tier B** spec (embedded C-API + buffer protocol + GIL +
isolation + diagnostics) and we adopt it almost verbatim there. What it omits — and what
this plan adds — is the **compatibility/ease-of-use floor**: a default out-of-process tier
that ships first, can't crash the engine, works with any wheel, and reuses VG's existing
IPC/async/process/memory-buffer code. That ordering is what makes the feature safe to ship
and pleasant to use, while still reaching the embedded performance ceiling for the cases
that need it.

---

## 12. Suggested week-by-week schedule

This is the safest sequencing if performance, compatibility, and ease-of-use all matter.

### Week 1 — Build-system gate + facade skeleton
- Add `python=1` to `SConstruct` as an opt-in flag only.
- Define `VG_HAS_PYTHON` when enabled; keep default builds unchanged.
- Create `src/python_bridge/visual_gasic_py_facade.h/.cpp`.
- Add `PyBridgeFacade::initialize_bridge()`, `py_import()`, and `py_process_buffer()` stubs.
- Decide the project setting key and default behavior: `vg/python/embedded_enabled = false`.

### Week 2 — Tier A worker bootstrap
- Add `python_worker.py` and a launcher path from `visual_gasic_process.cpp`.
- Teach the facade to detect local venv/system Python and fall back cleanly.
- Implement process start/stop/restart monitoring with structured warnings.
- Define the worker startup contract and exit codes.

### Week 3 — IPC protocol and async control path
- Implement the length-prefixed framed message system.
- Wire MsgPack control messages for import/call/return/error/ping.
- Route calls through the existing async queue so the frame thread never blocks.
- Add batching support for repeated small calls.

### Week 4 — Tooling and project setup
- Add project wizard support for enabling Python.
- Detect or create a venv, install dependencies, and surface diagnostics.
- Add a simple "Python diagnostics" readout: interpreter path, packages, worker status.
- Add one small sample that proves Tier A can run a real library.

### Week 5 — Compatibility hardening
- Add Linux and Windows desktop export smoke tests.
- Ensure missing interpreter, missing package, and worker crash all fail cleanly.
- Document supported package classes: pure Python first, native wheels by platform matrix.
- Explicitly mark mobile/web as unsupported for the initial release.

### Week 6 — Embedded Tier B scaffolding
- Add `PyBridgeDiagnostics` traceback handling.
- Add `PyObjectWrapper` and the C-API import/call path behind `VG_HAS_PYTHON`.
- Add GIL wrappers around every embedded C-API boundary.
- Keep Tier B disabled by default and gated by platform availability.

### Week 7 — Zero-copy bulk data lane
- Add `PackedByteArray` buffer sharing through `PyMemoryView_FromMemory`.
- Confirm the buffer path avoids copies in profiler traces.
- Add a bulk-data sample (image or audio transform) to prove the fast lane.

### Week 8 — Finish polish and release criteria
- Add docs, examples, and upgrade notes.
- Run end-to-end validation on the supported desktop matrix.
- Lock the performance targets and error behavior contract.
- Decide whether Tier B stays opt-in or becomes partially auto-selected on trusted platforms.

---

## 13. IPC framing design for Tier A

The IPC protocol should be simple, binary-safe, and easy to debug.

### Frame layout
Use a 4-byte little-endian length prefix followed by a UTF-8 payload body.

```text
[uint32 payload_bytes][payload bytes...]
```

### Payload shape
- `kind`: one of `ping`, `import`, `call`, `call_many`, `buffer`, `shutdown`, `error`, `result`.
- `request_id`: monotonically increasing integer for correlation.
- `module` / `method`: target symbols for import and invocation.
- `args`: MsgPack array for small control payloads.
- `buffer_id`: optional token for bulk payload follow-up.
- `status`: `ok` or `error`.
- `message`: human-readable error string.

### Bulk-data rule
- Small control messages use MsgPack by default.
- Large data uses the same frame header plus a binary body section or a paired buffer frame.
- Never base64 large arrays unless there is no other option.

### Why this shape
- Easy to debug in logs.
- Easy to implement in both GDScript/C++ and Python.
- Safe for arbitrary binary payloads.
- Works with worker pools, retries, and timeouts.
- Keeps the door open for FlatBuffers later if a typed high-volume schema becomes worth the complexity.

### Minimal example
The on-wire representation is MsgPack-encoded; the logical payload looks like:

```json
{
  "kind": "call",
  "request_id": 42,
  "module": "numpy",
  "method": "sqrt",
  "args": [64]
}
```

### Recommended first worker responses
- `result`: normal return value.
- `error`: traceback string plus error code.
- `ping`: interpreter/version metadata.
- `buffer_ack`: confirms a buffer id was consumed.
- `schema_ack`: optional future signal if a FlatBuffers schema is negotiated.
