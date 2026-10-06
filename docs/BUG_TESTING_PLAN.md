# VisualGasic Bug Testing Plan

## Overview

This document outlines a systematic approach to bug testing VisualGasic before declaring the project stable. Based on the v3.1 quality audit, there are specific areas that need attention before the codebase can be considered production-ready.

---

## 1. Critical Safety Pass — `ERR_FAIL_*` Guards

**Priority: 🔴 HIGHEST**

The audit found **zero** Godot `ERR_FAIL_*` / `ERR_FAIL_COND_*` null-pointer guard macros in the entire codebase. This means any null pointer dereference will **segfault** instead of printing a helpful error. This is the single highest crash-risk factor.

### Action Items

1. **`visual_gasic_instance.cpp`** (8,152 lines) — Add `ERR_FAIL_COND_V(ptr == nullptr, default)` guards at every public method entry point that accesses pointers
2. **All system modules** (`vg_system.cpp`, `vg_signal_handler.cpp`, `vg_file_permissions.cpp`, `vg_memory_buffer.cpp`, `vg_ipc.cpp`) — Guard all `fopen`, `malloc`, `mmap`, `socket` return values
3. **Networking** (`vg_socket.cpp`, `vg_http_request.cpp`) — Guard socket creation, `connect`, `bind` returns
4. **ECS/GPU** (`visual_gasic_ecs.cpp`, `visual_gasic_gpu.cpp`) — Guard entity lookups and buffer allocations

### Pattern to Apply

```cpp
// BEFORE (crash-prone):
void VGSystem::do_something(const String &path) {
    FILE *f = fopen(path.utf8().get_data(), "r");
    fread(buffer, 1, size, f);  // SEGFAULT if f is null
}

// AFTER (safe):
void VGSystem::do_something(const String &path) {
    FILE *f = fopen(path.utf8().get_data(), "r");
    ERR_FAIL_COND_MSG(f == nullptr, "Failed to open file: " + path);
    fread(buffer, 1, size, f);
}
```

### Estimated Scope
- ~50-80 guard insertions across the codebase
- Focus on public API boundaries first, then internal functions

---

## 2. Unit Tests for System Modules

**Priority: 🟡 HIGH**

Current test coverage: 30 test files with ~265 assertions — but these cover **core language** only (loops, arrays, strings, math). The system-level modules added in v3.0-3.1 have **zero automated tests**.

### Modules Needing Tests

| Module | File | Test File to Create |
|--------|------|---------------------|
| VGSystem | `vg_system.cpp` | `tests/test_vg_system.vg` |
| VGSignalHandler | `vg_signal_handler.cpp` | `tests/test_signal_handler.vg` |
| VGFilePermissions | `vg_file_permissions.cpp` | `tests/test_file_permissions.vg` |
| VGMemoryBuffer | `vg_memory_buffer.cpp` | `tests/test_memory_buffer.vg` |
| VGIPC | `vg_ipc.cpp` | `tests/test_ipc.vg` |
| VGSocket | `vg_socket.cpp` | `tests/test_socket.vg` |
| VGHttpRequest | `vg_http_request.cpp` | `tests/test_http_request.vg` |
| VisualGasicECS | `visual_gasic_ecs.cpp` | `tests/test_ecs.vg` |
| VisualGasicGPU | `visual_gasic_gpu.cpp` | `tests/test_gpu.vg` |
| Threading | `visual_gasic_thread.cpp` | `tests/test_threading.vg` |

### Test Pattern

Each test file should follow the existing pattern:
```vb
Sub Main()
    ' Test 1: Basic functionality
    Dim result = SomeFunction()
    If result = expected Then Print "PASS: test name" Else Print "FAIL: test name"
    
    ' Test 2: Edge cases
    ' Test 3: Error conditions
End Sub
```

### Test Categories Per Module

For each module, test:
1. **Happy path** — normal usage works correctly
2. **Edge cases** — empty strings, zero-length buffers, max values
3. **Error handling** — invalid inputs, missing files, permission denied
4. **Resource cleanup** — no file handles leaked, memory freed

---

## 3. Integration Tests

**Priority: 🟡 HIGH**

Test that modules work correctly **together**:

| Test | Description |
|------|-------------|
| File I/O + JSON | Write JSON to file, read back, verify |
| IPC + Threading | Multi-threaded pipe communication |
| HTTP + JSON | Fetch URL, parse JSON response |
| MemoryBuffer + FFI | Allocate, write struct, pass pointer |
| ECS + Threading | Multi-threaded system updates |
| FilePermissions + FileIO | Set permissions, verify access |

---

## 4. Stress / Fuzz Testing

**Priority: 🟠 MEDIUM**

### AST/bytecode differential checks

Run `scripts/run_ast_bytecode_diff.sh --all` for the full suite, or pass one
or more quoted basename globs for targeted tests. The runner accepts a test
resource path after `--`, avoiding the shared `current_test.txt` selector.
The harness requires a successful process exit, a runner completion marker,
nonempty assertions and matching passing assertions. Timeouts, unhandled VG
runtime errors, identical failing assertions and empty runs are failures, not
evidence of parity. Raw logs remain in the reported artifact directory.

The default path may fall back to AST when compilation is unsupported; matching
results alone do not prove that bytecode executed. For newly fixed compiler
features, also inspect compilation or bytecode execution directly.

Mutation stress is a crash check, not a correctness or hang-freedom check.
Its accepted timeouts require separate triage. Repeat with multiple seeds and
both default and `VG_FORCE_AST=1` modes, preserve reproducers, and use
ASan/UBSan builds before release to find memory faults that do not hard-crash.

#### Differential triage, October 6, 2026

The first full run with strict execution checks covered 210 tests: 181 matched
passing runs, 2 matched failing runs, 7 divergences, 7 runs without assertions
and 13 execution failures. This is a triage baseline, not a release pass.
Some error fixtures intentionally log runtime errors before catching them;
network timeouts, Windows-only fixtures and helper modules also need explicit
classification rather than being counted as engine defects or passing tests.

Subsequent targeted regression checks verified these fixes:

| Test area | Passing assertions per path |
|---|---:|
| Enum methods, keyword members, flags and handled invalid calls | 31 |
| Collection auto-instantiation, element-type constraints and explicit Nothing | 11 |
| Tween execution, all options, aliases and single target evaluation | 11 |
| Runtime property aliases (including Rotation in degrees) | 65 |
| File permissions after `On Error GoTo 0` | 13 |
| Collection integration after `Exit For` | 10 |
| QB framebuffer suite with isolated sprite samples | 46 |
| QB sprite copy/XOR without console-overlay interference | 1 |
| For Each exits and `On Error GoTo 0` control flow | 4 |
| Fast parameters and recursion through `SumTo(350)` | 14 |
| v2.10 features, including `Err.Raise`/`Err.Clear` | 16 |

QB `GET`/`PUT` worked on both paths in an isolated reproducer. The original
test's sample overlapped the text overlay drawn by earlier `Print` assertions;
it now uses freshly drawn pixels away from that overlay. Do not classify this
as an unimplemented AST sprite blitter.

The optimizer incorrectly treated `OP_THROW` as an unconditional exit and
removed statements that `On Error Resume Next` must execute. Retaining that
fall-through fixes the missing `Err.Raise`/`Err.Clear` assertions.

The deep-recursion crash was a native-stack overflow caused by an inlined
stack-trace print inside the VM's frequently instantiated `push_value` lambda.
An out-of-line reporter reduces the optimized VM frame from approximately
23 KB to 4.6 KB without increasing stack limits or reducing the test depth.
The 350-level test passes with tracing/profiling enabled too. Deep recursion
on Windows and worker threads still needs validation against their smaller
native stacks; this does not remove the runtime's dependence on native recursion.

The final full run covered 212 tests: **189 matched passes, 2 matched failures,
2 divergences, 7 runs without assertions and 12 execution failures**. There
were no native crashes in that run. Additional mutation checks (40 cases at
seed 7 on the default path and 40 at seed 2026 with forced AST) had no crashes
or timeouts.

The next pass fixed two additional defects:

- `Kill` in the folder fixture is parsed as a statement-style call, not
  `STMT_KILL`. Its AST call handler lacked wildcard support even though the
  separate statement handler already supported it. All three execution
  surfaces now call one file-deletion helper. The folder test passes 16
  assertions per path, including hidden matches, retained nonmatching files
  and directories, missing-match error 53, and execution after a handled
  error. A separate five-assertion fixture verifies live/dangling/directory
  symlinks, directory rejection and missing-folder error 76.
- Vector3 arithmetic with `Nothing` caused a bytecode bailout without a
  runtime error, followed by AST replay of the partially executed Sub.
  This duplicated earlier output and could repeat side effects. Invalid
  `+`, `-` and `*` operations involving `Nothing` now propagate `Nothing`
  as the AST evaluator does, without replay. Eight assertions per path cover
  both operand orders and verify the Sub executes only once; bytecode dumps
  confirm these tests compile.

The follow-up full run of the original 212 fixtures reports **191 matched
passes, 2 matched failures, 1 divergence, 7 runs without assertions and 11
execution failures**, with no native crashes. The new symlink/path fixture
was run separately and passes on both paths. Another 20 mutants at seed 11
(default) and 20 at seed 12 (forced AST) had no crashes or timeouts. Basename
filters now select only `.vg` files, not Godot-generated `.vg.uid` metadata.

The remaining divergence is AST `Await`, still a no-op statement. Its fix
requires explicit continuation frames for nested AST blocks, saved local
scopes and task-completion integration; saving only a statement index or
blocking the main thread is insufficient. No Await implementation was
changed during this follow-up.

The next targeted pass resolves the ByRef-import and queued-canvas failures:

- AST ByRef target detection rejected multidimensional array elements even
  though the assignment helper already supported them. It now accepts
  nonempty array-index lists while preserving the single-key restriction for
  dictionaries, packed arrays and memory buffers. The call-expression
  assignment path also stores the modified innermost array before rebuilding
  its parents. The import regression passes four assertions on each path,
  covering scalar, statement-call and expression-call write-back, plus
  temporary arguments that must not become assignment targets.
- `VGVectorCanvas2D.GetCommandCount()` counted dictionary-backed commands
  but omitted identity-transform lines stored in the optimized primitive
  buffer. It now counts those lines without double-counting dictionary
  commands. Five assertions per path verify mixed primitives, redraw
  scheduling, Clear, fast lines and overlay-backed lines.
- `GetDelta()` returned an owner delta without setting its dispatch-found
  flag, causing the caller to report an undefined function. The flag is now
  set before returning; case-insensitive dispatch is also tested. The
  expression-compatibility fixture passes nine assertions per path.
- The `IsVisible` fixture was attached to a plain `Node`, not a `CanvasItem`.
  It now declares `Extends Node2D` and verifies visible/hidden/restored states
  instead of only printing a success line. No visibility-runtime change was
  needed; seven assertions pass per path.

All 14 targeted ByRef, array, canvas and owner-helper fixtures pass on both
paths. Another 20 mutations at seed 13 (default) and 20 at seed 14 (forced
AST) had no crashes or timeouts.

The complete follow-up run covers 213 fixtures: **196 matched passes, zero
matched failures, one divergence, seven assertionless runs and nine execution
failures**. No native crashes occurred. The only assertion divergence in this
generic suite remains AST Await; the dedicated input runner exposes an
additional physical-key parity failure described below.

Additional fixture triage used the dedicated runners instead of counting
assertionless runs as passes:

| Fixture group | Classification / verified outcome |
|---|---|
| `test_error_handling`, `test_try_cross_module` | Deliberately raised/caught errors; raw logs contain five and two passing assertions respectively, but the strict differential harness still flags the error log. |
| `test_import_error_line`, `test_include_error_line` | Deliberate subscript errors; assertions verify error 9 and source line 3. These still require explicit expected-error validation in the harness. |
| `test_declare_ffi_windows` | Uses `ucrtbase.dll` and `kernel32.dll`; must run on Windows, not be treated as a Linux pass. |
| `test_benchmark_suite` | Workload benchmark; the forced-AST run exceeds the default 20-second budget. No hang-freedom conclusion. |
| `test_http_request`, `test_socket` | Blocking connection attempts to `192.0.2.1`; timed out. Need deterministic local networking tests and timeout checks. |
| `test_import_grid_helpers_lib`, `test_try_raise_helper` | Imported helpers without standalone assertions. |
| `test_step_lines`, `test_step_loop` | Dedicated `tools/run_step_trace.gd` passes all three checks: exact source-line trace, three loop-body pauses and shallow debugger values. |
| `test_sprite_data_resolver`, `test_vector_data_resolver` | Data-only fixtures. Dedicated resolver suites initially failed because assertions expected unindented rows although sync deliberately indents Data for folding. Tests now verify both indentation and content: sprite 37/37, vector 50/50; no sync-runtime change. |
| `test_input_key_edge_press` | Requires `run_input_key_edge_inject.gd`. Default path passes, but forced AST fails the physical-only KEY_Y fallback check. This newly exposed parity bug remains open and is invisible to the generic assertionless run. |
| `test_road_seg_data_import` | Unresolved `RoadProject.vg` import; still an open execution failure. |

Retain raw logs and reproducers; these counts are not a release sign-off.
Remaining work includes AST Await, physical-only input handling, the sample
import, deterministic network coverage, explicit expected-error/helper/platform
classification and sanitizer/smaller-native-stack validation.

#### Continuation and networking follow-up, October 6, 2026

The previously divergent ordinary-procedure Await cases now use explicit AST
continuation frames. Await no longer runs synchronously or replays the procedure:
numeric zero yields a frame, signal/task callbacks resume the correct invocation,
and nested ordinary loops, `With`, and `Try`/`Finally` retain their state.
Python and VG tasks expose a deferred main-thread `completed` signal.

New tests exposed two additional VM defects: resumption restored a stale snapshot
of every module variable, and compiler-generated For limit/step slots were lost.
The VM now saves exact local slots, operand-stack contents, block scopes, exception
handlers, With contexts, and the original compiled function. Callback IDs replace
LIFO resumption. Await-bearing chunks are excluded from fast-parameter/in-VM call
dispatch, so caller-native frames are not mistaken for resumable coroutine frames.
Task failure/cancellation and invalid waits raise recoverable errors.

The overlapping-call fixture verifies opposite completion order, preserved local
parameters, live module updates, signal Await, and a suspended With context.
The nested-control fixture verifies actual yielding, no replay, For/If,
Do/While, For Each, and Finally. The harness requires all expected assertions
for these fixtures, not merely a runner completion marker.

Additional corrections:

- Catch introduces its exception variable under `Option Explicit` in both
  ordinary AST execution and the continuation runner. Tests verify the bound
  exception number with and without suspension, including yielding in Catch
  and Finally.
- AST object member reads use the same native property helper as bytecode,
  including physical-keycode fallback. The dedicated injected-input runner is
  now selected automatically for its fixture in the differential harness.
- The road sample import path and the expected normalized curve value are fixed.
- Network fixtures use numeric loopback refusal rather than an external
  non-routable address, and check failure state/error text rather than only
  printing unconditional success.
- `VGSocket.connect_to` / `Connect` accept an optional timeout (30000 ms default).
  Connection polling is bounded after OS DNS resolution. The dedicated
  `tools/run_socket_timeout.gd` saturates a private loopback listener backlog to
  require a real 25 ms timeout, checks elapsed time and disconnected state, and
  verifies rejection of negative timeouts.
- Intentional error fixtures require the exact expected error-code, Sub,
  source-line, and source-file multiset. Additional/missing/differently located
  runtime errors fail; this is not a blanket error whitelist.
- Helpers, data-only fixtures, debugger fixtures, the heavy workload benchmark,
  and Windows-only DLL fixtures are explicitly excluded from generic differential
  totals and are never counted as passes. Use their dedicated runners/platform.
- Speed-test wrappers preserve child exit status and reject incomplete runs,
  runtime errors, missing benchmark data, and mismatched checksums.

Scope limitations remain: unmanaged AST special-loop/worker/class-method Await
contexts report errors rather than silently doing nothing; this is not complete
expression-form async support. The Windows and macOS implementations still need
native validation, and DNS resolution is not covered by the socket poll timeout.
The campaign report records final test counts, sanitizer coverage, and measured
speed results separately; these results are not proof that every possible bug
has been eliminated.

The existing `scons platform=linux target=editor asan=1` configuration builds,
but the official Godot 4.6.1 executable loads extensions with `RTLD_DEEPBIND`.
AddressSanitizer rejects that loader flag before the smoke fixture can execute.
The official executable has no supported toggle to disable it. Sanitizer
execution therefore remains a release gate requiring a sanitizer-compatible
Godot build; an instrumented library build alone is not a passing sanitizer
test. Restore ordinary libraries before correctness/performance runs and pushes.

The post-push mutation campaign (forced AST, seed 16, mutant 17) exposed a
duplicated `Sub _Ready()` header. The parser accepted it as statements inside
the outer procedure, causing recursive `_Ready` execution until native stack
exhaustion. Nested procedure declarations now produce a parse diagnostic at
their original source line. Procedures with parse errors are discarded rather
than executed as partial bodies; healthy sibling procedures remain runnable,
preserving the existing per-module error-recovery behavior. The dedicated
`tools/run_parser_procedure_regressions.gd` verifies duplicated Subs, nested
Functions, a procedure inside If, valid separate module procedures, and actual
reload rejection of the malformed procedure plus healthy-sibling execution.
Preserve the original mutation seed and source
alongside the native backtrace; rerun that seed after the fix.

The speed-test correctness gate subsequently exposed a hot-call JIT arithmetic
failure: `BenchArithmetic(200, 1000)` returned a negative checksum instead of
`298300000`, despite the interpreter returning the correct result. Tier 2
lowered constant arithmetic as a local-slot load instead of consuming the
VM's `[operand, literal]` stack pair. The lowering now matches the VM contract.
The emitter's GP/XMM scratch registers are excluded from allocation, spilled
floating results no longer destroy live inputs, and spills are placed below
callee saves and outside host-call scratch storage. The new
`test_jit_scratch_registers.vg` exercises hot calls, exact benchmark output,
changing/empty bounds, integer spills, and floating spills across host calls.

Benchmark wrappers use a temporary minimal host, without modifying the demo's
music-plugin autoloads or suppressing startup errors. The compute interop
workload now frees its created node. Compile timing forces VG reload rather
than measuring the unchanged-resource early return; it measures tokenization
and parsing, not lazy bytecode generation. Report this distinction and the
nonidentical medium-workload sources with the results.

The draw review also found that moving-workload checksum comparisons had been
explicitly bypassed, allowing 121 VG samples versus 120 in the other lanes.
Moving fixtures now use identical integer-tenths motion, gate each simulation
step on completion of its draw, and reject duplicate/final redraws. All lanes
must report exactly 120 measured frames and an identical checksum. Six direct
result-validation tests reject mismatches, extra/missing frames, missing
checksums and negative timings. These revised timings must not be compared
with the earlier unchecked floating-motion run.

### Memory Stress Tests
```vb
' Allocate/free in tight loop — detect leaks
For i = 1 To 10000
    Dim buf As New VGMemoryBuffer
    buf.Allocate 1024
    buf.PokeByte 0, 42
    buf.Free
Next i
```

### String Stress
```vb
' Build huge strings — detect overflow
Dim s As String
For i = 1 To 100000
    s = s & "x"
Next i
Print Len(s)  ' Should be 100000
```

### Array Stress
```vb
' ReDim Preserve in tight loop — detect memory corruption
Dim arr() As Integer
For i = 1 To 10000
    ReDim Preserve arr(i)
    arr(i) = i
Next i
```

### Concurrent Access
```vb
' Multiple threads hitting Dictionary simultaneously
' Should either work with mutex or fail gracefully (not crash)
```

---

## 5. Platform-Specific Testing

**Priority: 🟠 MEDIUM**

| Test Area | Linux | Windows | Notes |
|-----------|-------|---------|-------|
| File paths | `/tmp/test` | `C:\Temp\test` | Separator handling |
| IPC pipes | Unix domain sockets | Named pipes | API differences |
| File permissions | chmod/chown | ACLs | Unix-only features should no-op on Windows |
| Signal handling | SIGINT/SIGTERM | Limited | Graceful degradation |
| Socket paths | Standard | Winsock init | WSAStartup required |
| Locale | POSIX | Win32 | Encoding differences |

---

## 6. Regression Test Suite

**Priority: 🟢 ONGOING**

### Running Existing Tests
```bash
# Run the full test suite
./run_test_suite.sh

# Or use the Makefile
make -f Makefile.tests test
```

### Adding to CI (Future)
```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Build
        run: scons platform=linux target=editor -j$(nproc)
      - name: Run Tests
        run: ./run_test_suite.sh
```

---

## 7. Known Issues to Investigate

From the audit, these specific items need verification:

| # | Issue | Severity | Area |
|---|-------|----------|------|
| 1 | LSP is dead code (Position type conflict) | 🟡 Medium | `register_types.cpp` |
| 2 | Package `publish`/`upload` are stubs | 🟡 Medium | Package manager |
| 3 | JIT only handles loops | 🟡 Low | `visual_gasic_jit.cpp` |
| 4 | `visual_gasic_instance.cpp` is 8,152 lines | 🟡 Debt | Architecture |
| 5 | ~~Some "100%" claims in docs for stub features~~ ✅ Fixed | 🟢 Done | Documentation |
| 6 | No valgrind/ASAN memory testing done | 🟠 High | Memory safety |

---

## 8. Testing Workflow

### Phase 1: Safety Pass (1-2 days)
1. Add `ERR_FAIL_*` guards to all public C++ methods
2. Rebuild and verify no regressions
3. Run existing test suite

### Phase 2: System Module Tests (2-3 days)
1. Write test `.vg` files for each system module
2. Add to `run_test_suite.sh`
3. Target: 100+ new assertions

### Phase 3: Integration Tests (1-2 days)
1. Cross-module test scenarios
2. File I/O round-trips
3. Networking smoke tests (localhost only)

### Phase 4: Stress Testing (1 day)
1. Memory leak detection (large loops)
2. String/array boundary tests
3. Concurrent access tests

### Phase 5: Platform Testing (1 day)
1. Run full suite on Linux
2. Run full suite on Windows
3. Document any platform-specific failures

### Phase 6: Documentation Audit (0.5 day)
1. ~~Remove "100%" claims for stub features~~ ✅ Done
2. Mark LSP as "experimental / in progress"
3. Ensure all demos in README match actual files

---

## 9. Bug Report Template

When filing bugs, use this format:

```markdown
### Bug Title

**Module:** (e.g., VGMemoryBuffer)
**Severity:** Critical / High / Medium / Low
**Platform:** Linux / Windows / Both

**Steps to Reproduce:**
1. Step one
2. Step two

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happens

**Test Code:**
```vb
' Minimal reproduction
Sub Main()
    ' ...
End Sub
```

**Stack Trace / Error:**
(paste any error output)
```

---

## 10. Definition of "Ready for v3.2"

The project can be considered ready for a stable v3.2 release when:

- [ ] All `ERR_FAIL_*` guards are in place (zero raw nullptr access)
- [ ] Each system module has at least 5 automated test assertions
- [ ] Total test assertions ≥ 400 (currently ~265)
- [ ] Full test suite passes on both Linux and Windows
- [ ] No known crashes or segfaults
- [ ] Documentation accurately reflects feature status
- [ ] All 20+ demos execute without errors
- [ ] Memory stress tests pass (no leaks on 10K iterations)
