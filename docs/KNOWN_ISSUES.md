# VisualGasic — Known Issues & Engine Limitations

*Last updated after v3.2 stub implementation pass (GPU + ECS)*

This document lists **confirmed** engine bugs and limitations discovered during
the automated test suite (51 files, 449 assertions, 447 pass — 2 env-only
failures in `test_file_permissions.vg` symlink tests).

---

## ~~Critical — Stub / Skeleton Classes~~ (Resolved in v3.2)

| Class | File | Status | Detail |
|-------|------|--------|--------|
| **VGGpu** | `src/visual_gasic_gpu.cpp` | ✅ **Implemented** | 19 bound methods: VectorAdd/Sub/Mul/Div, DotProduct, Length, Normalize, Scale, Sum/Min/Max/Average, Abs/Clamp/Lerp, Initialize, GetBackend, GetInfo, HasGpu. CPU fallback for headless/CI. |
| **VGEcs** | `src/visual_gasic_ecs.cpp` | ✅ **Implemented** | 18 bound methods: CreateEntity, DestroyEntity, AddComponent, GetComponent, HasComponent, RemoveComponent, SetComponent, Query, QueryExclude, Update, Clear, Serialize, Deserialize, GetDebugInfo, GetEntityInfo, RegisterComponentType, HasComponentType, GetComponentTypes. Dictionary-based components. |

> Both classes are registered in ClassDB and reachable via VG aliases
> (`VGGpu`, `VGEcs`, `Gpu`, `ECS`).

---

## High — Core Language Bugs

| # | Bug | Detail | Workaround |
|---|-----|--------|------------|
| 1 | **Negative `For` step** | `For i = 10 To 1 Step -1` — loop condition doesn't flip for negative step; body may never execute. | Use `Do While` loop with manual decrement. |
| 2 | **`Print #N` file I/O** | Bytecode compiler never emits `OP_PRINT_FILE`. `Print #1, expr` goes to stdout; the file stays empty. | Use `FileSystemObject.WriteAll(path, content)` or `fso.write_all`. |
| 3 | **`Try/Catch` + `Err.Raise`** | Raising an error inside a `Try` block does not trigger the `Catch`. | Use `On Error Resume Next` + check `Err.Number` after each call. |
| 4 | **`On Error GoTo` + `Err.Raise`** | Raising an error may not jump to the error-handler label. | Use `On Error Resume Next` + manual checks. |
| 5 | **`STMT_TASK_RUN` not compiled** | `Task.Run … End Task`, `Parallel For`, and `Parallel Section` statements are parsed but the bytecode compiler falls through to the `default` case and aborts. | None — these syntax forms are non-functional in bytecode mode. |

---

## Medium — Runtime / VM Bugs

| # | Bug | Detail | Workaround |
|---|-----|--------|------------|
| 6 | **Dictionary `.Count` property** | `OP_MEMBER_ACCESS` on Dictionary performs a key lookup for `"Count"` instead of returning `.size()`. | Call `.Count()` with parentheses (method-call path works). |
| 7 | **Dictionary `Keys()` indexing** | `keys = d.Keys()` then `keys(i)` returns `[]` instead of the key string. | Iterate with `For Each k In d.Keys()`. |
| 8 | **`ToByteArray()`** | `VGMemoryBuffer.ToByteArray()` returns a `PackedByteArray` that VG cannot consume as a VG array. | Use `PeekByte`/`PokeByte` for byte-level access. |
| 9 | **Variable shadowing** | `Dim x` inside a Sub that shares a name with a module-level `x` writes to the *global* instead of creating a local. | Use distinct variable names. |
| 10 | **Task scope cloning** | `Task.RunAsync` clones the variable scope into the new thread. Mutations in the worker are lost when the parent restores its scope. | Read results via `task.Result` (if functional); avoid shared variables. |
| 11 | **Thread + scene-tree crash** | Worker threads created by `Task.RunAsync` or `Parallel For` crash if they access Godot's scene tree (e.g. `Print`). | Do not call `Print`, node accessors, or any scene-tree API from worker threads. |

---

## Low — Language Gaps

| # | Bug | Detail | Workaround |
|---|-----|--------|------------|
| 12 | **Local `Const`** | `Const X = 5` inside a `Sub` or `Function` is not supported by the parser. | Define constants at module level. |
| 13 | **`0x` hex literals** | The tokenizer does not recognise `0xFF`; only `&HFF` is valid. | Use `&H` prefix. |
| 14 | **Inline `Sub()` lambdas** | `Sub() … End Sub` as an expression is not supported. | Use `Lambda(x) expr` for single-expression lambdas; define named Subs for multi-line logic. |
| 15 | **Division by zero** | `x = 1 / 0` does not set `Err.Number`; no runtime error is raised. | Guard with `If denominator <> 0`. |
| 16 | **`"Task"` is a reserved word** | `Dim task As New VGTask` causes a parser error because "Task" is a keyword (used for `Task.Run` syntax). | Use a different variable name: `Dim myTask As New VGTask`. |

---

## Notes

- **v3.0 / v3.1 class construction** was broken because `ClassDB::can_instantiate()`
  returned `false` for GDExtension classes registered after v2.10.  
  **Fixed in v3.1** by routing all `VG*` class names through the alias
  table (bypasses `can_instantiate` check).

- **`VGCollection.Count()`** and **`VGTaskRunner.Count()`** were only registered
  as properties, not methods.  
  **Fixed in v3.1** by adding `ClassDB::bind_method(D_METHOD("Count"), …)`
  bindings.

- **VB6 `Array()` function** was not handled in the bytecode VM's `OP_CALL`
  dispatcher — it worked in AST interpreter mode but silently returned NIL
  in bytecode mode.  
  **Fixed in v3.2** by adding an `Array()` handler that returns the evaluated
  argument list as a Godot Array.

- All workarounds above are exercised by the automated test suite
  (`test_proj/test_suite/`) — 447/449 pass (2 env-only failures).
