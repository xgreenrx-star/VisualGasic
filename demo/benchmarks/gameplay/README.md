# Gameplay realism benchmarks (Tier B + C)

Script-local loops/calls and engine-adjacent gameplay shapes — **VG vs GDScript only**.

Complements the Tier A microbench suite (`demo/bench.vg`) and draw benchmarks (`demo/benchmarks/draw/`).

Workload implementations live in **`demo/bench.vg`** so they share the same bytecode compiler path as the published microbench suite.

## Tiers & categories

| Tier | Focus | Workloads |
|------|--------|-----------|
| **B** | Hot script bodies | `IntegerLoop`, `FloatLoop`, `LocalCalls`, `CallChain` |
| **C** | Gameplay / engine | `NodePropertyChurn`, `ArrayIterate`, `DictionaryScan`, `EntityThink`, `BatchNearest`, **`FrameSlice`** |

Each workload is tagged in runner output:

| Tag | Meaning |
|-----|---------|
| **representative** | Typical frame-work shapes (safe to discuss alongside Tier A claims) |
| **optimization-target** | Previously tracked VM gaps (collection scans now win; `CallChain` still tagged) |

The runner prints **representative median** separately from optimization-target rows. Use **median + per-test rows** for game-speed claims; geometric mean mixes unlike workloads.

## Run

From repo root (after `scons platform=linux target=editor`):

```bash
scripts/run_gameplay_benchmarks.sh
scripts/run_gameplay_benchmarks.sh | tee demo/benchmarks/gameplay/bench_output.txt
```

## CI

Tier B/C are **informational** — they do not gate releases. Tier A compute + draw remain the regression gate (`scripts/benchmark_regression_check.sh`).

Published tables: [BENCHMARK_PUBLISHED_RESULTS.md](../../../BENCHMARK_PUBLISHED_RESULTS.md)
