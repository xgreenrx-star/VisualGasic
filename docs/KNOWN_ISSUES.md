# VisualGasic — Known Issues & Engine Limitations

*Last updated: v5.4.0-beta1 (August 2026)*

This document lists **confirmed** engine bugs and limitations. Test baseline: **891/891** VG regression assertions passing (122 runnable `.vg` files); **332/332** Programmer's Reference examples parse-clean; **47/47** corpus examples with expected output.

See also [ROADMAP.md](../ROADMAP.md) for active development priorities.

---

## ~~Fixed in v5.4.0-beta1~~

| Item | Detail |
|------|--------|
| **FunctionCall benchmark gap** | Compiler inlining + nested-loop fusion — 12/12 compute vs GDScript. |
| **`CInt` truncated floats** | `CInt(3.7)` returned 3; now rounds to 4 (VB6 semantics). |
| **CI `.vg` test suite GDExtension load** | `scripts/prepare_ci_gdextension.sh` materializes bin dirs; CI uses Godot 4.6.1. |
| **`Boolean Or` runtime regression** | Fixed in Beta7 parser; regression test `test_boolean_or_regression.vg`. |

---

## ~~Fixed in v5.3.0-Beta7~~ (Bracket Indexing & ByRef)

| Item | Detail |
|------|--------|
| **`arr[i]` bracket subscript** | Postfix `[index]` now parses; previously `players[0]` silently returned the whole array, breaking 3D mob chase (`GlobalPosition` on Array → Nothing). |
| **ByRef array slot write-back** | Bytecode path persists writes to `arr(i)` passed ByRef. |

---

## ~~Fixed in v5.3.0-Beta6~~ (Language & Reference)

| Item | Detail |
|------|--------|
| **`End` command** | Standalone `End` now calls `SceneTree.quit()`. Previously raised `Sub or Function not defined: End` on Exit buttons. |
| **`DoEvents`, `Throw`, `LoadForm`, `ChangeScene`** | Statement/expression dispatch wired for common IDE and Narcea-generated code paths. |
| **VB6 `""` string escapes** | `"He said ""hello"""` tokenizes and runs correctly. |
| **Conversion builtins** | `CInt`, `CLng`, `CDbl`, `CSng`, `CBool` with string parsing; invalid input raises catchable type mismatch. |
| **`Deg2Rad` / `Rad2Deg`** | Math aliases available for 3D and reference examples. |
| **Godot 4.6 `OptionButton` popup** | `about_to_popup` compatibility via `VGGodotCompat.connect_popup_preshow()`. |

---

## Beta — Active Issues (v5.4.0-beta1)

These are tracked on the roadmap and may affect demos or daily use:

| Issue | Detail | Workaround |
|-------|--------|------------|
| **Unhandled errors corrupt state** | Some unhandled runtime errors can leave the app in a bad state instead of failing cleanly. | Use `Try/Catch` or `On Error` around risky blocks during development. |
| **Double-click ignores existing `.tscn` signal connections** | Form Designer double-click may not respect pre-wired Godot signals. | Wire handlers via VG naming convention (`btnOK_Click`) in `.vg` instead. |
| **Phantom button double-press on blocking async** | Blocking async calls may duplicate button press events. | Avoid long blocking work in click handlers; use `Await` patterns. |
| **Form Designer bugs** | Classic Form Designer has known UI issues; **UI Forms** replacement is experimental. | Enable UI Forms via `vg/enable_experimental_plugins` or build forms manually. |
| **MovingFilledRects checksum drift** | Draw benchmark moving workload frame count differs slightly from GDScript. | Static draw workloads use full checksum verification. |

Report new issues: [GitHub Issues](https://github.com/xgreenrx-star/VisualGasic/issues)

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
| 6 | **Dictionary `.Count` property** | ✅ **Fixed** in bytecode VM `OP_GET_MEMBER` — returns `.size()` for Dictionary.Count. | Use `.Count` or `.Count()`. |
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
| Beta7 language fixes | 2 | 2 | 0 |
| Beta6 language fixes | 6 | 6 | 0 |
| Beta active (IDE/workflow) | 5 | 0 | 5 |
| Critical (stubs) | 2 | 2 | 0 |
| High (language) | 5 | 4 | 1 partial |
| Medium (runtime) | 6 | 0 | 6 |
| Low (gaps) | 5 | 4 | 1 |
| **Total tracked** | **29** | **16** | **13** |

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

- Regression suite: `test_proj/test_suite/` and CI gates — **891/891** VG assertions pass as of v5.4.0-beta1 (122 runnable files + 1 data fixture via GDScript harness).
