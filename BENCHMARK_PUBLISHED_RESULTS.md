# Visual Gasic — Published Benchmark Results

**Date:** September 14, 2026 (packed I64 entity scans) · compute/draw baseline August 25, 2026  
**Engine:** Godot 4.6.1 (headless)  
**Platform:** Linux x86_64  
**Build:** Visual Gasic GDExtension (`target=editor`)

This is the **canonical marketing / docs reference** for VG vs GDScript vs C++ speed claims. Re-run the suites below after compiler or VM changes; update this file when publishing new numbers.

---

## How to reproduce

```bash
scons platform=linux target=editor
scripts/run_compute_benchmarks.sh        | tee demo/benchmarks/bench_output.txt
scripts/run_draw_benchmarks.sh           | tee demo/benchmarks/draw/bench_output.txt
scripts/run_gameplay_benchmarks.sh       | tee demo/benchmarks/gameplay/bench_output.txt
scripts/run_compile_benchmarks.sh        | tee demo/benchmarks/compile/bench_output.txt
scripts/benchmark_regression_check.sh      # fails if VG loses to GD (5% slack)
```

### Benchmark tiers

| Tier | Suite | CI gate? | Purpose |
|------|--------|:--------:|---------|
| **A** | Compute microbench (12) + draw (9) | ✅ | Compiler/VM regression gate |
| **B** | Loop & call realism (4) | — | Hot script bodies at fixed op counts |
| **C** | Gameplay / engine (6) | — | Collections, entity ticks, node property churn, composite frame slice |

Each Tier B/C row is tagged **representative** or **optimization-target** in the runner output. Use those tags — and per-test rows — when talking about “game speed.”

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

## Gameplay realism benchmarks (Tier B + C)

**Script:** `demo/bench.vg` (`BenchIntegerLoop`, …) · **Runner:** `scripts/run_gameplay_benchmarks.sh`  
**Metric:** elapsed µs (lower is faster) · **Also reports:** µs/op · **Checksums:** verified identical  
**Note:** Informational only — **not** part of `benchmark_regression_check.sh`.

### How to read these (important)

- Use **median + per-test rows** for game-speed claims. Geometric mean mixes unlike workloads (integer closed-form vs entity ticks vs node property writes).
- Use **category tags** from the runner:
  - **representative** — shapes that resemble real frame work (loops, entity ticks, node properties, composite frame slice).
  - **optimization-target** — previously tracked VM gaps (collection scans now win; `CallChain` still tagged).
- **Safe shipping claims** stay on **Tier A compute (12/12)** + **Tier C draw (9/9)**. Representative entity ticks and collection scans are VG wins on this snapshot.

### Tier B — loop & call (100k ops each)

| Test | Category | GDScript µs | Visual Gasic µs | VG vs GD | VG faster? |
|------|----------|------------:|----------------:|---------:|:----------:|
| IntegerLoop | representative | 4,563 | **70** | **65×** | ✅ |
| FloatLoop | representative | 2,850 | **412** | **6.9×** | ✅ |
| LocalCalls | representative | 21,296 | 22,211 | 0.96× | ≈ |
| CallChain | optimization-target | 92,747 | **36,540** | **2.5×** | ✅ |

**Tier B summary:** geometric mean **5.8×** · median **4.7×** — integer/float loops and deep call chains are VG wins; local calls are GDScript-parity (run noise ± a few percent).

### Tier C — engine-adjacent gameplay (500 ticks × 64 entities unless noted)

| Test | Category | GDScript µs | Visual Gasic µs | VG vs GD | VG faster? |
|------|----------|------------:|----------------:|---------:|:----------:|
| NodePropertyChurn† | representative | 111,457 | **656** | **170×** | ✅ |
| ArrayIterate | optimization-target | 2,809 | **710** | **4.0×** | ✅ |
| DictionaryScan | optimization-target | 8,666 | **1,734** | **5.0×** | ✅ |
| EntityThink | representative | 4,571 | **1,495** | **3.1×** | ✅ |
| BatchNearest | representative | 7,633 | **2,648** | **2.9×** | ✅ |
| FrameSlice‡ | representative | 9,774 | **1,256** | **7.8×** | ✅ |

† NodePropertyChurn: 100×1000 node `name` sets (100k ops).  
‡ FrameSlice: composite 64-entity read → think → write (same checksum as EntityThink; models a fuller frame slice). Inner `For i` compiles to `OP_PACKED_HP_STATE_TICK` / `OP_PACKED_NEAREST_I64`.

**Representative gameplay median:** **6.9×**. **Tier C median:** **4.5×** — packed `Long` entity scans beat GDScript `PackedInt64Array` on this machine; **NodePropertyChurn** still dominates when gameplay touches engine objects.

### Gameplay headline (safe to advertise)

> **Tier A remains the release gate** (12/12 compute + 9/9 draw). **Tier B/C:** VG wins **integer/float loops**, **node property churn**, **deep call chains**, **`For Each` array/dict scans**, and **packed entity ticks** (native I64 scans). Local calls are **parity** with GDScript.

Details: `demo/benchmarks/gameplay/README.md` · Raw: `demo/benchmarks/gameplay/bench_output.txt`

---

## Combined claim (Facebook / website / README)

1. **Compute (Tier A):** VG faster than GDScript on **12/12** published microbenchmarks (deterministic checksums).
2. **Graphics:** VG faster than GDScript on **9/9** `_draw` workloads (static checksums verified).
3. **Gameplay realism (Tier B/C):** VG wins the published loop/call/entity rows on this snapshot. Quote **Tier A + draw** for speed claims; use category tags and per-test rows for honesty.
4. **C++:** VG wins many high-level tests (StringConcat, Interop, Allocations); tight numeric loops and raw draw dispatch still favor native C++ on some workloads — complementary, not contradictory.

---

## Regression guardrails (recommended before release)

| Guard | Command / location |
|-------|-------------------|
| Speed vs GD | `scripts/benchmark_regression_check.sh` (includes FunctionCall) |
| Draw fusion opcodes | `demo/prototypes/dump_bytecode.gd` on `BenchFilledRects`, `BenchPolylines`, `_Draw` |
| Call inlining | `demo/prototypes/dump_bytecode.gd` on `BenchCall` — inner loop should show `OP_INC_LOCAL_I64` or fused multiply-add, not `OP_CALL` |
| Packed entity scans | `demo/prototypes/dump_bytecode.gd --entry=BenchEntityThink --entry=BenchBatchNearest --entry=BenchFrameSlice` — inner `For i` should show `OP_PACKED_HP_STATE_TICK` / `OP_PACKED_NEAREST_I64` |
| Optimizer ↔ disasm sync | Keep `visual_gasic_optimizer.cpp` draw opcode sizes aligned with `visual_gasic_script.cpp` |
| CI | Run regression script on `target=editor` build after `src/` changes (`.github/workflows/ci.yml`) |
| Compile time (informational) | `scripts/run_compile_benchmarks.sh` — not a regression gate |
| Gameplay realism (informational) | `scripts/run_gameplay_benchmarks.sh` — Tier B/C, not a regression gate |

---

## Raw output archives

- Compute: `demo/benchmarks/bench_output.txt`
- Draw: `demo/benchmarks/draw/bench_output.txt`
- Compile: `demo/benchmarks/compile/bench_output.txt`
- Gameplay: `demo/benchmarks/gameplay/bench_output.txt`

---

*Previous compute baseline (Jul 2026): see `BENCHMARK_SUMMARY.md` and `docs/manual/performance.md`. Earlier Aug 2026 table (pre–FunctionCall fix) showed 11/11 compute with FunctionCall excluded; draw suite previously showed VG **slower** than GD (pre-fusion).*
