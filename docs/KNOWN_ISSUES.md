# VisualGasic — Known Issues & Engine Limitations

*Last updated: v5.2.0-Beta4 (May 2026)*

This document lists **confirmed** engine bugs and limitations discovered during
the automated test suite (91 VG files, 700 assertions — all passing; 289 GDScript — all passing).

---

## ~~Critical — Stub / Skeleton Classes~~ (Resolved in v3.2)

| Class | File | Status | Detail |
|-------|------|--------|--------|
| **VGGpu** | `src/visual_gasic_gpu.cpp` | ✅ **Implemented** | 19 bound methods: VectorAdd/Sub/Mul/Div, DotProduct, Length, Normalize, Scale, Sum/Min/Max/Average, Abs/Clamp/Lerp, Initialize, GetBackend, GetInfo, HasGpu. CPU fallback for headless/CI. |
| **VGEcs** | `src/visual_gasic_ecs.cpp` | ✅ **Implemented** | 18 bound methods: CreateEntity, DestroyEntity, AddComponent, GetComponent, HasComponent, RemoveComponent, SetComponent, Query, QueryExclude, Update, Clear, Serialize, Deserialize, GetDebugInfo, GetEntityInfo, RegisterComponentType, HasComponentType, GetComponentTypes. Dictionary-based components. |

> Both classes are registered in ClassDB and reachable via VG aliases
> (`VGGpu`, `VGEcs`, `Gpu`, `ECS`).

---

## ~~High — Core Language Bugs~~ (Resolved in v3.6–v4.1)

| # | Bug | Status | Fix Version |
|---|-----|--------|-------------|
| ~~1~~ | ~~Negative `For` step~~ | ✅ **Fixed** | v3.6 — Compiler now emits `>=` for negative step, `<=` for positive. Runtime branch for non-constant step. |
| ~~2~~ | ~~`Print #N` file I/O~~ | ✅ **Fixed** | v3.6 — Compiler emits `OP_PRINT_FILE`; VM looks up file handle in `open_files` map and calls `store_string()`. |
| ~~3~~ | ~~`Try/Catch` + `Err.Raise`~~ | ✅ **Fixed** | v3.8 — `OP_TRY_BEGIN`/`OP_TRY_END` with `OP_ERR_RAISE` routing to catch block via `handle_runtime_error()`. |
| ~~4~~ | ~~`On Error GoTo` + `Err.Raise`~~ | ⚠️ **Partial** | v3.8 — Works in AST interpreter mode. Bytecode VM falls back to AST for label jumps. |
| ~~5~~ | ~~`STMT_TASK_RUN` not compiled~~ | ✅ **Fixed** | v3.7 — `Task.Run`, `Parallel For`, and `Parallel Section` now emit bytecode (body compiled inline). |

---

## Medium — Runtime / VM Bugs

| # | Bug | Detail | Workaround |
|---|-----|--------|------------|
| 6 | **Dictionary `.Count` property** | In bytecode VM, `OP_MEMBER_ACCESS` on Dictionary performs a key lookup for `"Count"` instead of returning `.size()`. AST interpreter and method-call path work correctly. | Call `.Count()` with parentheses (method-call path works). |
| 7 | **Dictionary `Keys()` indexing** | `keys = d.Keys()` then `keys(i)` returns `[]` instead of the key string. The returned Godot Array is not bridged for VG `()` indexing. | Iterate with `For Each k In d.Keys()`. |
| 8 | **`ToByteArray()`** | `VGMemoryBuffer.ToByteArray()` returns a `PackedByteArray` that VG cannot consume as a VG array. Architectural limitation. | Use `PeekByte`/`PokeByte` for byte-level access. |
| 10 | **Task scope cloning** | `Task.RunAsync` deep-clones variables. Mutations in the worker are lost when the parent restores its scope. By design — VG uses isolated thread scopes. | Read results via `task.Result`; avoid shared variables. |
| 11 | **Thread + scene-tree crash** | Worker threads crash if they access Godot's scene tree (e.g. `Print`). Fundamental Godot limitation — scene tree is not thread-safe. | Do not call `Print`, node accessors, or any scene-tree API from worker threads. |

---

## ~~Low — Language Gaps~~ (Mostly Resolved)

| # | Bug | Status | Fix Version |
|---|-----|--------|-------------|
| ~~9~~ | ~~Variable shadowing~~ | ✅ **Fixed** | v3.6 — Bytecode compiler allocates local slots via `OP_SET_LOCAL`, separate from globals. |
| ~~12~~ | ~~Local `Const`~~ | ✅ **Fixed** | v3.8 — Parser's `parse_statement()` now handles `Const` inside Sub/Function bodies. |
| ~~13~~ | ~~`0x` hex literals~~ | ✅ **Fixed** | v3.6 — Tokenizer recognizes `0x` prefix in addition to `&H`. |
| ~~14~~ | ~~Inline `Sub()` lambdas~~ | ✅ **Fixed** | v3.7 — Parser recognizes `Sub` as lambda keyword; handles block `Sub(params) ... End Sub`. |
| ~~15~~ | ~~Division by zero~~ | ✅ **Fixed** | v3.6 — VM's `OP_DIV`, `OP_IDIV`, `OP_MOD` all check for zero and raise error code 11. |
| 16 | **`"Task"` reserved word** | ⚠️ Still open | `Task` is tokenized as a keyword; `Dim task As New VGTask` fails. Use a different variable name. |

---

## Summary

| Severity | Total | Fixed | Open |
|----------|:-----:|:-----:|:----:|
| Critical (stubs) | 2 | 2 | 0 |
| High (language) | 5 | 4 | 1 partial |
| Medium (runtime) | 6 | 1 | 5 |
| Low (gaps) | 5 | 4 | 1 |
| **Total** | **18** | **11** | **7** |

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
  (`test_proj/test_suite/`) — 700/700 VG assertions pass, 289/289 GDScript pass.
