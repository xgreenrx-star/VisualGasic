# Compile benchmarks

Headless **script reload** timing: tokenize/parse + compile (+ VG optimizer passes).  
Compares median `Script.reload()` microseconds — models save-and-reload in the editor, not cold project import.

## Run

```bash
scripts/run_compile_benchmarks.sh | tee demo/benchmarks/compile/bench_output.txt
```

Runner: `demo/test_suites/run_compile_benchmarks.gd`

## Workloads

| Workload | VG source | GD source | ~lines |
|----------|-----------|-----------|-------:|
| HelloWorld | `benchmarks/compile/hello.vg` | `benchmarks/compile/hello.gd` | 4 / 3 |
| BenchCompute | `bench.vg` (real compute suite) | synthetic ~340-line GD mirror | 339 / 340 |
| SyntheticLarge | generated `.vg` | generated `.gd` | ~1800 / ~1576 |

## Results (Linux, Godot 4.6.1 headless, Sept 2026)

Median reload µs (lower is faster):

| Workload | Visual Gasic µs | GDScript µs | VG vs GD |
|----------|------------------:|--------------:|---------:|
| HelloWorld | 33 | 21 | 1.57× slower |
| BenchCompute | 6,034 | 3,219 | 1.87× slower |
| SyntheticLarge | 25,225 | 15,705 | 1.61× slower |

### Headline (safe to advertise)

> **GDScript compiles faster on reload** for typical script sizes in this suite (~1.6–1.9×). Visual Gasic pays extra compile cost for bytecode generation and optimizer passes; runtime microbenchmarks are where VG wins.

This matches day-to-day iteration: normal game scripts feel fine; very large files or heavy recompile sessions are where VG compile cost shows up most.
