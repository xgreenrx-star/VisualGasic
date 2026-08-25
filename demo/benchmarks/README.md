# Benchmarks

Performance test suite for VisualGasic runtime optimization and JIT validation.

## Overview

This directory contains `.vg` scripts designed to measure and profile VisualGasic execution performance under various workloads. Used to validate JIT compiler effectiveness, identify hotspots, and track performance regression.

## Key Files

| File | Purpose |
|------|---------|
| `bench.vg` | Comprehensive performance suite (nested loops, type stress, memory allocation) |
| `bench_data_vs_array.vg` | Comparison: Dictionary vs Array performance for indexed access patterns |
| `bench_dict_simple.vg` | Baseline dictionary operation performance (insertion, lookup, iteration) |
| `loop_shapes.vg` | Nested loop pattern analysis (rectangular, triangular, irregular nesting) |
| `parallel.vg` | Multi-threaded workload benchmark (requires Thread support) |
| `jit_*.vg` | JIT-specific optimizations: `jit_simple.vg`, `jit_intonly.vg`, `jit_loop.vg`, `jit_simple2.vg` |
| `draw/` | **CanvasItem draw benchmarks** — VG vs GDScript vs C++ (`run_draw_benchmarks.gd`, live scene) |
| `bench_output.txt` | Sample results from previous benchmark run (reference) |

## Running Benchmarks

From repo root (after `scons platform=linux target=editor`):

```bash
scripts/run_compute_benchmarks.sh
scripts/run_draw_benchmarks.sh
scripts/benchmark_regression_check.sh   # CI-style: fail if VG loses to GD
```

Or open a `.vg` benchmark in Godot and run via the script debugger.

**Published tables:** [BENCHMARK_PUBLISHED_RESULTS.md](../../BENCHMARK_PUBLISHED_RESULTS.md)

## Typical Workflow

- `bench.vg` for full suite (5–10 sec)
- `jit_*.vg` for targeted JIT validation (quick feedback loop)
- `bench_data_vs_array.vg` when evaluating data structure performance trade-offs

## Notes

- Benchmarks assume ~1GHz+ CPU; adjust loop counts if running on slower hardware
- Results are machine-dependent; use `bench_output.txt` as a reference baseline only
- JIT benchmarks require Phase 3 runtime (automatic in v5.3+)
