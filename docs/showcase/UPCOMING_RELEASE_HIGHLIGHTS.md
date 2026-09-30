# Upcoming release — copy highlights

Draft bullets for Asset Library / GitHub release / community posts. Edit before publish.

## Windows JIT parity (important — verify before quoting numbers)

Visual Gasic’s **native JIT was built and tuned on Linux first** (primary development OS). **Windows x64** now runs the **same Tier 2** hot-function compiler (executable pages via `VirtualAlloc` / CFG, not Linux-only `mmap`). **Tier 3** call-graph fusion is also wired on Windows.

- **Default on x86-64 desktop:** hot numeric subs compile to native code after warmup unless `VG_JIT=0`.
- **Still untested in CI:** we do **not** yet publish Windows-vs-GDScript JIT benchmark tables. Linux numbers from [performance.md](../manual/performance.md) and `BENCHMARK_PUBLISHED_RESULTS.md` are **bytecode / fusion** baselines, not Win64 JIT proof.
- **Before release marketing:** run `run_test_suite.sh test_jit_tier3.vg` and gameplay/compute benches on a Windows machine with the shipping `.dll`; add measured rows or say “Windows JIT enabled — benchmarks forthcoming.”

Suggested one-liner:

> **Windows speed:** x64 Godot + Visual Gasic now ship with the same optional native JIT as Linux dev builds — hot loops and draw/math helpers can compile to machine code on **Windows x64** as well as Linux. Benchmarks on Windows are still being validated; use `VG_JIT=0` anytime you need interpreter-only behavior.

## Fast-call path (all platforms)

Documented in [performance.md](../manual/performance.md#fast-call-path): keep hot helpers on **`ByVal` + scalar `As`** types; one **`ByRef`** (or bare parameter) takes the whole procedure off the fast-call path.
