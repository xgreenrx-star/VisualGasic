# Facebook post — compute + draw performance (Aug 2026)

**Use with:** link to repo + `BENCHMARK_PUBLISHED_RESULTS.md`  
**Note:** These numbers ship in the **next Visual Gasic release this weekend** (grid-loop draw fusion + CI regression gate).

---

Visual Gasic isn't just readable — it's **fast**.

We already beat GDScript on every core compute microbenchmark. **Now we're faster on graphics too** — and it's all landing in the release **this weekend**.

Same VB6-style language. Same Godot 4.6. Code you can audit — without paying a GDScript tax.

---

## Compute (11 core tests — Visual Gasic vs GDScript)

Lower µs = faster. Checksums match — same work, less time.

| Test | GDScript | Visual Gasic | VG faster |
|------|--------:|-------------:|----------:|
| Arithmetic | 14,616 µs | **67 µs** | **218×** |
| ArraySum | 10,352 µs | **344 µs** | **30×** |
| StringConcat | 11,432 µs | **220 µs** | **52×** |
| Branching | 18,209 µs | **237 µs** | **77×** |
| ArrayDict | 14,853 µs | **2,902 µs** | **5.1×** |
| DictFastGet | 41,239 µs | **2,015 µs** | **20×** |
| DictFastSet | 21,822 µs | **2,744 µs** | **8.0×** |
| Interop | 11,619 µs | **231 µs** | **50×** |
| Allocations | 8,633 µs | **255 µs** | **34×** |
| AllocationsFast | 12,298 µs | **1,000 µs** | **12×** |
| FileIO | 10,668 µs | **650 µs** | **16×** |

**11/11** core compute benchmarks: Visual Gasic wins.

---

## Canvas draw (9 workloads — Visual Gasic vs GDScript)

Time inside `_draw` per frame. Filled rects, lines, circles, sprites, polylines, mixed scenes, vector batch canvas, moving objects.

| Workload | GDScript | Visual Gasic | VG faster |
|----------|--------:|-------------:|----------:|
| FilledRects ×2500 | 1,699 µs | **220 µs** | **7.7×** |
| OutlineRects ×2500 | 2,626 µs | **1,433 µs** | **1.8×** |
| Lines ×2000 | 2,041 µs | **571 µs** | **3.6×** |
| Circles ×1500 | 7,346 µs | **5,833 µs** | **1.3×** |
| Sprites ×2000 | 1,485 µs | **403 µs** | **3.7×** |
| Polylines ×800 | 2,539 µs | **1,284 µs** | **2.0×** |
| Mixed ×2500 | 9,489 µs | **4,641 µs** | **2.0×** |
| VectorCanvas batch ×2500 | 3,902 µs | **395 µs** | **9.9×** |
| Moving rects (avg/frame) | 238 µs | **82 µs** | **2.9×** |

**9/9** draw benchmarks: Visual Gasic wins.

Draw used to be our weak spot. Compiler grid-loop fusion now compiles hot `_Draw` loops to native C++ — no per-primitive VM tax on tile grids.

---

**Coming this weekend:** draw fusion, published benchmark docs, and a CI gate so we don't silently regress.

Open source · Godot GDExtension · reproduce: `scripts/benchmark_regression_check.sh`

https://github.com/xgreenrx-star/VisualGasic
