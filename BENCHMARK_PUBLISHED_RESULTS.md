# Visual Gasic — Published Benchmark Results

**Date:** August 25, 2026  
**Engine:** Godot 4.6.1 (headless)  
**Platform:** Linux x86_64  
**Build:** Visual Gasic GDExtension (`target=editor`)

This is the **canonical marketing / docs reference** for VG vs GDScript vs C++ speed claims. Re-run the suites below after compiler or VM changes; update this file when publishing new numbers.

---

## How to reproduce

```bash
scons platform=linux target=editor
scripts/run_compute_benchmarks.sh   | tee demo/benchmarks/bench_output.txt
scripts/run_draw_benchmarks.sh    | tee demo/benchmarks/draw/bench_output.txt
scripts/benchmark_regression_check.sh   # fails if VG loses to GD (5% slack)
```

---

## Compute microbenchmarks (11 core + FunctionCall)

**Script:** `demo/bench.vg` · **Runner:** `demo/test_suites/run_benchmarks.gd`  
**Metric:** total elapsed µs (lower is faster) · **Checksums:** verified identical

| Test | GDScript µs | Visual Gasic µs | C++ µs | VG vs GD | VG faster? |
|------|------------:|----------------:|-------:|---------:|:----------:|
| Arithmetic | 14,616 | **67** | 144 | **218×** | ✅ |
| ArraySum | 10,352 | **344** | 87 | **30×** | ✅ |
| StringConcat | 11,432 | **220** | 1,354 | **52×** | ✅ |
| Branching | 18,209 | **237** | 135 | **77×** | ✅ |
| ArrayDict | 14,853 | **2,902** | 5,047 | **5.1×** | ✅ |
| DictFastGet | 41,239 | **2,015** | — | **20×** | ✅ |
| DictFastSet | 21,822 | **2,744** | — | **8.0×** | ✅ |
| Interop | 11,619 | **231** | 10,517 | **50×** | ✅ |
| Allocations | 8,633 | **255** | 590 | **34×** | ✅ |
| AllocationsFast | 12,298 | **1,000** | 182 | **12×** | ✅ |
| FileIO | 10,668 | **650** | 444 | **16×** | ✅ |
| FunctionCall* | 9,646 | 83,751 | — | 0.12× | ❌ ongoing |

\* **FunctionCall** is tracked separately — pure call/return overhead is VG’s remaining weak spot (~8.7× slower than GDScript on this micro-test). It is **not** included in the “11/11” headline.

### Compute headline (safe to advertise)

> **Visual Gasic beats GDScript on all 11 core compute microbenchmarks**, from **5×** (ArrayDict) to **218×** (Arithmetic). Checksums prove identical work.

Geometric mean speedup vs GDScript (11 core tests): **~32×**.

---

## Canvas draw benchmarks (9 workloads)

**Scripts:** `demo/benchmarks/draw/bench_draw.vg`, `bench_draw_moving.vg`, `bench_draw_vector.vg`  
**Runner:** `scripts/run_draw_benchmarks.sh`  
**Metric:** microseconds inside `_draw` (lower is faster)

Static workloads: checksums match GDScript and C++. Moving workload: speed only (frame-count timing differs slightly).

| Workload | n | GDScript µs | Visual Gasic µs | C++ µs | VG vs GD | VG faster? |
|----------|--:|------------:|----------------:|-------:|---------:|:----------:|
| FilledRects | 2500 | 1,699 | **220** | 129 | **7.7×** | ✅ |
| OutlineRects | 2500 | 2,626 | **1,433** | 596 | **1.8×** | ✅ |
| Lines | 2000 | 2,041 | **571** | 249 | **3.6×** | ✅ |
| Circles | 1500 | 7,346 | **5,833** | 3,981 | **1.3×** | ✅ |
| Sprites | 2000 | 1,485 | **403** | 132 | **3.7×** | ✅ |
| Polylines | 800 | 2,539 | **1,284** | 1,085 | **2.0×** | ✅ |
| Mixed | 2500 | 9,489 | **4,641** | 5,059 | **2.0×** | ✅ |
| VectorCanvasUniformRects | 2500 | 3,902 | **395** | 494 | **9.9×** | ✅ |
| MovingFilledRects† | 500×120f | 238 avg | **82 avg** | 45 avg | **2.9×** | ✅ |

† Average `_draw` time per frame after warmup.

### Draw headline (safe to advertise)

> **Visual Gasic beats GDScript on all 9 canvas draw benchmarks** — including batch vector canvas, mixed primitives, and moving-object redraw. Fused grid loops compile hot `_Draw` paths to native C++ (`OP_DRAW_*_GRID_LOOP`).

Key enablers (Aug 2026): bytecode optimizer operand sizes for draw opcodes, whole-loop grid fusion, `_Draw` batch recorder, F64 draw opcodes.

---

## Combined claim (Facebook / website / README)

1. **Compute:** VG faster than GDScript on **11/11** published microbenchmarks (deterministic checksums).
2. **Graphics:** VG faster than GDScript on **9/9** `_draw` workloads (static checksums verified).
3. **C++:** VG wins many high-level tests (StringConcat, Interop, Allocations, Mixed draw); tight numeric loops and raw draw dispatch still favor native C++ — complementary, not contradictory.

**Do not claim** “faster on every possible test” until FunctionCall overhead is addressed.

---

## Regression guardrails (recommended before release)

| Guard | Command / location |
|-------|-------------------|
| Speed vs GD | `scripts/benchmark_regression_check.sh` |
| Draw fusion opcodes | `demo/prototypes/dump_bytecode.gd` on `BenchFilledRects`, `BenchPolylines`, `_Draw` |
| Optimizer ↔ disasm sync | Keep `visual_gasic_optimizer.cpp` draw opcode sizes aligned with `visual_gasic_script.cpp` |
| CI (suggested) | Run regression script on `target=editor` build after `src/` changes |

---

## Raw output archives

- Compute: `demo/benchmarks/bench_output.txt`
- Draw: `demo/benchmarks/draw/bench_output.txt`

---

*Previous compute baseline (Jul 2026): see `BENCHMARK_SUMMARY.md` and `docs/manual/performance.md`. Draw suite previously showed VG **slower** than GD (pre-fusion); Aug 2026 results supersede `demo/benchmarks/draw/README.md` sample table.*
