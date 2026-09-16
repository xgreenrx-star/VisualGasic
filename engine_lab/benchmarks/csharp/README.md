# C# benchmark workloads (Godot .NET)

Ports of `demo/test_suites/run_benchmarks.gd` compute workloads for **VG vs C#** comparisons.

## Requirements

- **Godot 4.6.1+ .NET** editor (`Godot_v4.6.1-stable_mono_linux_x86_64` or Windows/macOS .NET build)
- **`GodotSharp/`** folder beside the Godot executable (from the full .NET zip)
- **.NET SDK 8+** (`dotnet build`)
- Visual Gasic GDExtension (`scons platform=linux target=editor`)

## Run

```bash
scripts/run_csharp_compute_benchmarks.sh | tee demo/benchmarks/csharp/bench_output.txt
scripts/run_csharp_compile_benchmarks.sh | tee demo/benchmarks/csharp/compile_bench_output.txt
```

Standard compute benchmarks (`scripts/run_compute_benchmarks.sh`) still run VG vs GD vs C++ on the **non-.NET** Godot build. C# is optional and uses the same runner (`run_benchmarks.gd`) when `CSharpScript` is available.

## Workloads

| File | Role |
|------|------|
| `BenchCompute.cs` | 12 compute microbenchmarks (checksums match GD/VG) |
| `../compile/hello.cs` | Minimal script for C# compile timing |

Published tables: [BENCHMARK_PUBLISHED_RESULTS.md](../../BENCHMARK_PUBLISHED_RESULTS.md)

## Reddit / docs talking points

- **Runtime:** On the published microbenchmark suite (Sep 2026, Linux), **VG beats Godot C# on all 12 workloads** — often by large margins on dict/interop (Godot `Dictionary` marshaling from C# is expensive).
- **C# still wins on:** tooling, ecosystem, static typing in the IDE, official Godot docs — not raw speed in this suite.
- **Compile:** C# uses **incremental MSBuild** (~1 s touch rebuild), not per-script reload like VG/GD. Compare compile separately; see compile section in published results.
