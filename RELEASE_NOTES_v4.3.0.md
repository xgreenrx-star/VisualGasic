# VisualGasic v4.3.0 Release Notes — v4.0 Roadmap Complete 🎉

**Release Date**: March 21, 2026  
**Previous Version**: 4.2.0-beta6  
**Milestone**: All v4.0 Roadmap features implemented (7 of 9 items — #1 skipped, #9 deferred)

---

## 🏆 Overview

v4.3.0 marks the completion of the entire **v4.0 "Next Generation" roadmap**. Six major features ship in this release:

| # | Feature | Tests |
|---|---------|-------|
| 2 | Multi-Module Compilation | ✅ Pass |
| 3 | Visual Form Debugger | ✅ Pass |
| 4 | Database Controls (Data, DBGrid, DBCombo) | 13 pass |
| 5 | Package Manager | 11 pass |
| 7 | macOS Universal Binary | CI ✅ |
| 8 | JIT Tier 3 (Call Graph Compilation) | 10 pass |

Items #1 (Live Animation) was skipped — static preview is sufficient. Item #6 (Migration Wizard v2) was completed earlier. Item #9 (WebAssembly Validation) is deferred to a future release.

---

## ✅ Feature #2 — Multi-Module Compilation

Cross-file `Import` statements now resolve symbols across the entire project.

### What's New
- **`Import <ModuleName>`** parsed in tokenizer/parser
- **Project-wide symbol table** built at compile time across all `.vg` files
- **Cross-file Go-to-Definition** and Find-All-References
- **Circular import detection** with clear error messages
- **IntelliSense autocomplete** includes imported module members

### Usage
```vb
' MathHelpers.vg
Public Function Square(x As Double) As Double
    Square = x * x
End Function

' Main.vg
Import MathHelpers

Sub Main()
    Print Square(5)  ' 25
End Sub
```

### Test File
- `tests/test_multi_module.vg` — all assertions pass

---

## ✅ Feature #3 — Visual Form Debugger

Click any control on a running form → jump to its event handler source.

### What's New
- **Controls Inspector panel** — tree view of all form controls
- **Click-to-source** — click a control in the inspector → jumps to its event handler
- **Live property values** — hover a control to see its current property values
- **Debugger integration** — inspect `Me.Controls` tree during breakpoints

### New Files
- `addons/visual_gasic/vg_controls_inspector.gd` — Controls Inspector panel implementation

---

## ✅ Feature #4 — Database Controls (Data, DBGrid, DBCombo)

VB6's killer feature: data-bound controls backed by SQLite.

### What's New
- **VGRecordset** — Full C++ class with ADODB.Recordset-compatible API
  - `MoveFirst`, `MoveNext`, `MovePrevious`, `MoveLast`
  - `AddNew`, `Update`, `Delete`
  - `EOF`, `BOF`, `RecordCount`, `AbsolutePosition`
  - Field access via `Fields("name").Value`
- **Data control** — SQLite-backed data source with SQL query property
- **DBGrid** — Read/write data grid bound to a Data control
- **DBCombo** — Dropdown populated from a query column
- Design-time column layout in Form Designer

### New Files
- `src/visual_gasic_recordset.h` — VGRecordset class header
- `src/visual_gasic_recordset.cpp` — VGRecordset implementation (~466 lines)

### Test Files
- `tests/test_db_controls.vg` — **13 tests pass** (Recordset CRUD, navigation, field access)
- `tests/test_rs_minimal.vg` — **1 test pass** (minimal smoke test)

---

## ✅ Feature #5 — Package Manager

`vg pkg install <package>` pulls `.vg` libraries from a GitHub-backed registry.

### What's New
- **`vg.json` project manifest** with dependencies, version constraints
- **`vg pkg` CLI commands**: `install`, `update`, `remove`, `publish`, `search`
- **GitHub-backed registry** — JSON index + tagged releases
- **GUI Package Browser** — Tools menu panel for browsing, installing, removing packages
- **`vg_modules/` resolution** — Imports resolve from local module folder

### New Files
- `addons/visual_gasic/vg_pkg_cli.gd` — Package Manager CLI helper
- `addons/visual_gasic/vg_package_browser.gd` — GUI Package Browser panel

### Test File
- `tests/test_pkg_manager.vg` — **11 tests pass** (install, remove, search, version resolution, manifest parsing)

---

## ✅ Feature #7 — macOS Universal Binary

Fat binary (x86_64 + arm64) for complete macOS support.

### What's New
- **`scripts/build_macos_universal.sh`** — Build script using `lipo` to combine architectures
- **`.github/workflows/macos-universal.yml`** — CI workflow for automated macOS builds
- Builds on `macos-14` (ARM) runner with cross-compilation for x86_64
- Code-signing support for Gatekeeper compliance
- Integrates with existing release pipeline

### New Files
- `scripts/build_macos_universal.sh` — Universal binary build script
- `.github/workflows/macos-universal.yml` — macOS CI workflow

---

## ✅ Feature #8 — JIT Tier 3 (Call Graph Compilation)

Extends the JIT from hot function bodies to entire call graphs with function inlining.

### What's New
- **Call graph profiling** — identifies hot call chains across functions
- **Inline candidate selection** — size threshold + call frequency heuristics
- **Callee IR lowering** — inlined function bodies merged into caller IR
- **Fused compilation** — entire call graph compiled as single x86-64 unit
- **Inter-procedural register allocation** — shared registers across inlined calls

### Complete JIT Architecture

| Tier | Name | Trigger | Scope |
|------|------|---------|-------|
| 0 | Interpreter | First call | Statement-by-statement AST walk |
| 0.5 | Loop JIT | Hot loop (100+ iters) | Single loop body → x86-64 |
| 1 | AST JIT | Warm function (50+ calls) | Full AST → machine code |
| 2 | Function Body JIT | Hot function (200+ calls) | Bytecode → optimized x86-64 |
| 3 | Call Graph JIT | Hot call chain (500+ calls) | Multi-function → fused x86-64 with inlining |

### New Files
- `src/visual_gasic_jit_tier3.h` — JIT Tier 3 header (~170 lines)
- `src/visual_gasic_jit_tier3.cpp` — JIT Tier 3 implementation (~630 lines)

### Test File
- `tests/test_jit_tier3.vg` — **10 tests pass** (call graph detection, inlining, compilation, execution)

---

## 📊 v4.0 Roadmap Final Status

| # | Feature | Status | Version |
|---|---------|--------|---------|
| 1 | Live Animation | ⏭️ Skipped | — |
| 2 | Multi-Module Imports | ✅ Complete | v4.3.0 |
| 3 | Visual Form Debugger | ✅ Complete | v4.3.0 |
| 4 | Database Controls | ✅ Complete | v4.3.0 |
| 5 | Package Manager | ✅ Complete | v4.3.0 |
| 6 | Migration Wizard v2 | ✅ Complete | v4.2.0 |
| 7 | macOS Universal | ✅ Complete | v4.3.0 |
| 8 | JIT Tier 3 | ✅ Complete | v4.3.0 |
| 9 | WASM Validation | 🔲 Deferred | — |

**7 of 9 items complete. 1 skipped. 1 deferred.**

---

## 🧪 Test Summary

| Test File | Assertions | Pass |
|-----------|-----------|------|
| test_db_controls.vg | 13 | 13 ✅ |
| test_pkg_manager.vg | 11 | 11 ✅ |
| test_jit_tier3.vg | 10 | 10 ✅ |
| test_multi_module.vg | All | ✅ |
| test_rs_minimal.vg | 1 | 1 ✅ |

---

## 📁 New Files in This Release

### Source (C++)
- `src/visual_gasic_recordset.h` — VGRecordset class header
- `src/visual_gasic_recordset.cpp` — VGRecordset implementation
- `src/visual_gasic_jit_tier3.h` — JIT Tier 3 header
- `src/visual_gasic_jit_tier3.cpp` — JIT Tier 3 implementation

### GDScript (Addon)
- `addons/visual_gasic/vg_pkg_cli.gd` — Package Manager CLI
- `addons/visual_gasic/vg_package_browser.gd` — GUI Package Browser
- `addons/visual_gasic/vg_controls_inspector.gd` — Controls Inspector

### Build & CI
- `scripts/build_macos_universal.sh` — macOS universal binary build
- `.github/workflows/macos-universal.yml` — macOS CI workflow

### Tests
- `tests/test_db_controls.vg` — Database Controls tests (13)
- `tests/test_pkg_manager.vg` — Package Manager tests (11)
- `tests/test_jit_tier3.vg` — JIT Tier 3 tests (10)
- `tests/test_multi_module.vg` — Multi-Module compilation tests
- `tests/test_rs_minimal.vg` — Recordset minimal smoke test

---

## ⬆️ Upgrade Instructions

1. Rebuild from source:
   ```bash
   scons target=editor -j$(nproc)
   ```
2. Copy updated `.so` to your project:
   ```bash
   cp test_proj/addons/visual_gasic/bin/libvisual_gasic.linux.editor.x86_64.so \
      your_project/addons/visual_gasic/bin/
   ```
3. Restart Godot Editor
4. New features available immediately — no migration needed

---

## 🔮 What's Next

With the v4.0 roadmap complete, the remaining items are:
- **WebAssembly Export Validation** (#9) — verify HTML5 export compatibility
- **Asset Library submission** — awaiting Godot team review
- **Calculator tutorial screenshots** — real screenshots for documentation placeholders

---

*Full changelog: [CHANGELOG.md](CHANGELOG.md) · Roadmap: [ROADMAP.md](ROADMAP.md) · Project Status: [PROJECT_STATUS.md](PROJECT_STATUS.md)*
