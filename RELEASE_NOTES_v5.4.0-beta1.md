# VisualGasic 5.4.0-beta1 Release Notes

**Release Date:** August 30, 2026  
**Status:** Beta (Pre-release)  
**Milestone:** Performance + IDE (pre-M5)  
**Previous Release:** [5.3.0-Beta7](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.3.0-Beta7) (August 21, 2026)  
**Target Engine:** Godot 4.6.1  
**Platforms:** Linux x86_64, Windows x86_64 (desktop)

---

## Overview

VisualGasic **5.4.0-beta1** is the **full-speed beta**: VG now beats GDScript on every published compute and draw benchmark. Draw grid-loop fusion compiles hot `_Draw` paths to native C++; FunctionCall — previously VG’s weak spot — is fixed via compiler inlining and nested-loop fusion. A **CI benchmark regression gate** blocks speed regressions before they ship.

**Headline:** **12/12 compute** · **9/9 draw** · checksums verified on static workloads.

**On the road to VG6:** Public betas stay on the **5.x** train; **v6.0.0** (January 2027 target) is the first stable **VG6** release — same spirit as VB6, production-ready.

Full changelog: [CHANGELOG.md](CHANGELOG.md#540-beta1---2026-08-30) · Canonical numbers: [BENCHMARK_PUBLISHED_RESULTS.md](BENCHMARK_PUBLISHED_RESULTS.md)

---

## What's New Since 5.3.0-Beta7

### Performance — Draw Fusion (9/9 vs GDScript)

- **Grid-loop fusion** — whole `_Draw` loops emit `OP_DRAW_*_GRID_LOOP` opcodes; bypass per-primitive VM dispatch.
- **Draw batch recorder** — batches primitives before native dispatch.
- **F64 draw opcodes + color folding** — tighter numeric paths for rects, lines, circles, sprites.
- **Optimizer ↔ disassembler sync** — draw opcode operand sizes must stay aligned (`visual_gasic_optimizer.cpp` / `visual_gasic_script.cpp`).

### Performance — FunctionCall (12/12 vs GDScript)

- **Trivial helper inlining** — `Function Helper(x As Long) As Long` with body `Helper = x + 1` inlines at expression call sites.
- **Assignment fusion** — `s = Helper(s)` → `OP_INC_LOCAL_I64` / `OP_ADD_LOCAL_I64_CONST`.
- **Nested-loop closed form** — double `For` with inner `s = Helper(s)` → single multiply-add (no 50k `OP_CALL` dispatches).
- **Before/after:** FunctionCall ~294 ms–1.7 s (VG) vs ~6–10 ms (GD) → **~140 µs vs ~8,448 µs** (~60× faster than GDScript).

### CI & Regression

- **`scripts/benchmark_regression_check.sh`** in CI after editor build (compute + draw; 5% slack).
- **`test_function_call_inline.vg`** — compiler fusion regression test.

### IDE (carried from post-Beta7 `main`)

- Context rail sidecar, literal convert panel, sprite Data editor, New Level wizard.
- Track D groundwork — `.vgd` / `DataFile` sidecar, Tiled import hooks.

---

## Documentation

| Topic | Link |
| --- | --- |
| Published benchmarks | [BENCHMARK_PUBLISHED_RESULTS.md](BENCHMARK_PUBLISHED_RESULTS.md) |
| Performance guide | [docs/manual/performance.md](docs/manual/performance.md) |
| Getting Started | [docs/guides/GET_STARTED.md](docs/guides/GET_STARTED.md) |
| Changelog | [CHANGELOG.md](CHANGELOG.md) |
| Version policy | [docs/VERSIONING.md](docs/VERSIONING.md) |

---

## Installation

### Linux

**Option 1: AppImage (Recommended)**
```bash
wget https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-Installer-v5.4.0-beta1-x86_64.AppImage
chmod +x VisualGasic-Installer-v5.4.0-beta1-x86_64.AppImage
./VisualGasic-Installer-v5.4.0-beta1-x86_64.AppImage
```

**Option 2: Bootstrap Script**
```bash
curl -sSL https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/scripts/bootstrap_install.sh | bash
```

**Option 3: Godot Asset Library**

Install **VisualGasic** from the AssetLib tab inside Godot 4.6.1+, or download [`VisualGasic_AssetLibrary_v5.4.0-beta1.zip`](https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic_AssetLibrary_v5.4.0-beta1.zip).

### Windows

```powershell
Invoke-WebRequest -Uri "https://github.com/xgreenrx-star/VisualGasic/releases/download/v5.4.0-beta1/VisualGasic-Installer-v5.4.0-beta1-x86_64.exe" -OutFile installer.exe
.\installer.exe
```

### Manual (existing Godot project)

1. Extract `VisualGasic_v5.4.0-beta1_<platform>_x86_64.zip` into your project's `addons/` folder
2. Enable **VisualGasic** in Project Settings → Plugins

Download: [v5.4.0-beta1 release page](https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.4.0-beta1)

---

## Known Issues

- **MovingFilledRects checksum** — frame-count timing differs slightly from GDScript; speed-only comparison.
- **Non-trivial multi-statement helpers** — general in-VM fast call path not yet implemented; only fusion/inlining patterns covered by tests.
- **Form Designer** — known bugs; UI Forms experimental plugin is the long-term replacement.

See [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md).
