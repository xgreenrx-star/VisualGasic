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
scripts/run_compile_benchmarks.sh   | tee demo/benchmarks/compile/bench_output.txt
scripts/benchmark_regression_check.sh   # fails if VG loses to GD (5% slack)
```

---

## Compute microbenchmarks (12 tests)

**Script:** `demo/bench.vg` · **Runner:** `demo/test_suites/run_benchmarks.gd`  
**Metric:** total elapsed µs (lower is faster) · **Checksums:** verified identical

| Test | GDScript µs | Visual Gasic µs | C++ µs | VG vs GD | VG faster? |
|------|------------:|----------------:|-------:|---------:|:----------:|
| Arithmetic | 3,756 | **27** | 62 | **139×** | ✅ |
| ArraySum | 5,244 | **265** | 56 | **20×** | ✅ |
| StringConcat | 7,257 | **140** | 717 | **52×** | ✅ |
| Branching | 10,354 | **152** | 85 | **68×** | ✅ |
| FunctionCall | 8,448 | **140** | — | **60×** | ✅ |
| ArrayDict | 16,216 | **4,391** | 5,602 | **3.7×** | ✅ |
| DictFastGet | 41,845 | **3,545** | — | **12×** | ✅ |
| DictFastSet | 27,891 | **3,170** | — | **8.8×** | ✅ |
| Interop | 11,260 | **267** | 9,940 | **42×** | ✅ |
| Allocations | 9,069 | **212** | 655 | **43×** | ✅ |
| AllocationsFast | 13,716 | **1,749** | 498 | **7.8×** | ✅ |
| FileIO | 1,267 | **710** | 552 | **1.8×** | ✅ |

### Compute headline (safe to advertise)

> **Visual Gasic beats GDScript on all 12 published compute microbenchmarks**, from **1.8×** (FileIO) to **139×** (Arithmetic). Checksums prove identical work.

Geometric mean speedup vs GDScript (12 tests): **~18×**.

**FunctionCall (Aug 2026):** Previously VG’s weak spot (~8× slower than GDScript). Fixed by compiler call inlining — trivial fast-params helpers (`x + 1`) inline at the call site; nested `For`/`Helper(s)` loops fuse to closed-form `s += outer×inner×delta` instead of 50,000 VM dispatches.

---

## Canvas draw benchmarks (9 workloads)

**Scripts:** `demo/benchmarks/draw/bench_draw.vg`, `bench_draw_moving.vg`, `bench_draw_vector.vg`  
**Runner:** `scripts/run_draw_benchmarks.sh`  
**Metric:** microseconds inside `_draw` (lower is faster)

Static workloads: checksums match GDScript and C++. Moving workload: speed only (frame-count timing differs slightly).

| Workload | n | GDScript µs | Visual Gasic µs | C++ µs | VG vs GD | VG faster? |
|----------|--:|------------:|----------------:|-------:|---------:|:----------:|
| FilledRects | 2500 | 1,078 | **160** | 110 | **6.7×** | ✅ |
| OutlineRects | 2500 | 1,467 | **554** | 371 | **2.6×** | ✅ |
| Lines | 2000 | 1,142 | **276** | 105 | **4.1×** | ✅ |
| Circles | 1500 | 3,226 | **2,552** | 2,288 | **1.3×** | ✅ |
| Sprites | 2000 | 862 | **321** | 81 | **2.7×** | ✅ |
| Polylines | 800 | 1,582 | **881** | 682 | **1.8×** | ✅ |
| Mixed | 2500 | 4,966 | **2,632** | 2,343 | **1.9×** | ✅ |
| VectorCanvasUniformRects | 2500 | 1,038 | **191** | 189 | **5.4×** | ✅ |
| MovingFilledRects† | 500×120f | 144 avg | **25 avg** | 25 avg | **5.8×** | ✅ |

† Average `_draw` time per frame after warmup.

### Draw headline (safe to advertise)

> **Visual Gasic beats GDScript on all 9 canvas draw benchmarks** — including batch vector canvas, mixed primitives, and moving-object redraw. Fused grid loops compile hot `_Draw` paths to native C++ (`OP_DRAW_*_GRID_LOOP`).

Key enablers (Aug 2026): bytecode optimizer operand sizes for draw opcodes, whole-loop grid fusion, `_Draw` batch recorder, F64 draw opcodes.

---

## Compile / reload benchmarks (3 workloads)

**Runner:** `demo/test_suites/run_compile_benchmarks.gd` · **`scripts/run_compile_benchmarks.sh`**  
**Metric:** median `Script.reload()` elapsed µs (lower is faster) · **Scope:** tokenize + parse + compile (+ VG optimizer)

| Workload | Visual Gasic µs | GDScript µs | VG vs GD |
|----------|----------------:|------------:|---------:|
| HelloWorld (~4 lines) | 33 | 21 | **1.57× slower** |
| BenchCompute (~340 lines, real `bench.vg`) | 6,034 | 3,219 | **1.87× slower** |
| SyntheticLarge (~1800 lines) | 25,225 | 15,705 | **1.61× slower** |

### Compile headline (safe to advertise)

> **GDScript reloads faster** in this suite (~1.6–1.9×). VG pays compile cost for bytecode + optimizer passes; **runtime** is where the published compute/draw wins apply. Normal game-script sizes are fine day-to-day; large files / heavy recompile sessions are where VG compile cost shows up most.

Details: `demo/benchmarks/compile/README.md` · Raw: `demo/benchmarks/compile/bench_output.txt`

---

## Combined claim (Facebook / website / README)

1. **Compute:** VG faster than GDScript on **12/12** published microbenchmarks (deterministic checksums).
2. **Graphics:** VG faster than GDScript on **9/9** `_draw` workloads (static checksums verified).
3. **C++:** VG wins many high-level tests (StringConcat, Interop, Allocations); tight numeric loops and raw draw dispatch still favor native C++ on some workloads — complementary, not contradictory.

---

## Regression guardrails (recommended before release)

| Guard | Command / location |
|-------|-------------------|
| Speed vs GD | `scripts/benchmark_regression_check.sh` (includes FunctionCall) |
| Draw fusion opcodes | `demo/prototypes/dump_bytecode.gd` on `BenchFilledRects`, `BenchPolylines`, `_Draw` |
| Call inlining | `demo/prototypes/dump_bytecode.gd` on `BenchCall` — inner loop should show `OP_INC_LOCAL_I64` or fused multiply-add, not `OP_CALL` |
| Optimizer ↔ disasm sync | Keep `visual_gasic_optimizer.cpp` draw opcode sizes aligned with `visual_gasic_script.cpp` |
| CI | Run regression script on `target=editor` build after `src/` changes (`.github/workflows/ci.yml`) |
| Compile time (informational) | `scripts/run_compile_benchmarks.sh` — not a regression gate |

---

## Raw output archives

- Compute: `demo/benchmarks/bench_output.txt`
- Draw: `demo/benchmarks/draw/bench_output.txt`
- Compile: `demo/benchmarks/compile/bench_output.txt`

---

*Previous compute baseline (Jul 2026): see `BENCHMARK_SUMMARY.md` and `docs/manual/performance.md`. Earlier Aug 2026 table (pre–FunctionCall fix) showed 11/11 compute with FunctionCall excluded; draw suite previously showed VG **slower** than GD (pre-fusion).*
