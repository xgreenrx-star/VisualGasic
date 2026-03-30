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
