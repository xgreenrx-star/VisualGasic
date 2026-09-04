🎉 **VisualGasic 5.4.0-Beta2** closes M5 with **Buffer Type** and **Optimizer Hints**, plus **Narcea Tier A/B** golden-path validation and **AST Godot type-constructor** fixes that unblock cross-module emulation code.

### Highlights

- **Buffer Type** — zero-overhead `Dim mem As Buffer` for byte-level access in emulation and I/O workloads
- **Optimizer Hints** — `@accumulator`, `@loop_counter`, `@simd_candidate` metadata for safe optimization passes
- **AST Godot type constructors fixed** — `Vector2i()` / `Rect2i()` / `Color()` no longer throw "Sub or Function not defined"
- **Narcea Tier A/B** — recorded platformer scenario + canonical scaffold validation
- **891/891** regression assertions · **57** corpus examples
- **CI hardening** — GDExtension materializes real addon tree on fresh clones

Full details: [RELEASE_NOTES_v5.4.0-beta2.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.4.0-beta2.md)

### Documentation

- [Documentation Hub](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/DOCS.md)
- [Getting Started](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/GET_STARTED.md)
- [Installation Guide](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/guides/INSTALLATION.md)
- **[Godot Programming Manual v3.0.0](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md)** — Key Sections:
  - [Chapter 1: Introduction](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md#L98)
  - [Chapter 40: Python Bridge](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md#L3924) (M7)
  - [Chapter 45: Narcea AI Pair](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md#L4101) (M5)
  - [Chapter 49: Causal Chains](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md#L4230) (M6)
  - [Chapter 51: Exception Handling & Modern Syntax](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/GODOT_PROGRAMMING_MANUAL.md#L4301) (M8)
- [Changelog](https://github.com/xgreenrx-star/VisualGasic/blob/main/CHANGELOG.md)

### Downloads

| Platform | File |
| --- | --- |
| **Linux** | `VisualGasic-Installer-v5.4.0-Beta2-x86_64.AppImage` (recommended) or `VisualGasic_v5.4.0-Beta2_linux_x86_64.zip` |
| **Windows** | `VisualGasic-Installer-v5.4.0-Beta2-x86_64.exe` (recommended) or `VisualGasic_v5.4.0-Beta2_windows_x86_64.zip` |
| **Asset Library** | `VisualGasic_AssetLibrary_v5.4.0-Beta2.zip` |

**Requires Godot 4.6.1+**

### What's Fixed

- ✅ AST Godot type-constructor dispatch — calls to `Vector2i()`, `Rect2i()`, `Color()` on bytecode-fallback paths now work
- ✅ Cross-module ByRef array access — wrapper functions pattern documented and tested
- ✅ CI GDExtension loader registration — fresh clones now materialize real addon tree, no more broken symlinks

### Known Notes

- Python `int`↔`float` on bridge return paths — partial (decode path fixed, outgoing-arg typing still pending for v6.1)
- `Callable(obj, "method")` requires same-file forwarding for cross-module methods (workaround documented)
- Causal chain visual panel deferred to 6.1; text-mode analysis available in Code Navigator
