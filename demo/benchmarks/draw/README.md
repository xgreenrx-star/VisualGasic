# Draw Benchmarks

Live, reusable **CanvasItem `_draw`** benchmarks comparing **Visual Gasic**, **GDScript**, and **C++** with matched workloads.

## Workloads

| Name | What it measures |
|------|------------------|
| `FilledRects` | Many small filled rectangles (tile-like) |
| `OutlineRects` | Rectangle outlines |
| `Lines` | Diagonal line segments |
| `Circles` | Filled circles on a grid |
| `Sprites` | `draw_texture_rect` with an 8×8 texture |
| `Polylines` | Closed 4-segment polylines |
| `Mixed` | Combined rects + lines + circles + sprites |
| `VectorCanvasUniformRects` | Build rect buffer then one `DrawRectsUniform` on `VGVectorCanvas2D` |
| `MovingFilledRects` | **500** objects with moving positions; reports **average `_draw` µs** over **120** frames (after warmup) |

Shared layout constants live in `draw_bench_config.gd` and are mirrored in `bench_draw.vg` and `VisualGasicDrawBenchmark` (C++).

**Metric:** microseconds spent inside `_draw` per frame (lower is faster). Checksums verify all three implementations issue the same draw workload.

## Headless runner

From the repo root (requires built GDExtension):

```bash
scripts/run_draw_benchmarks.sh
```

Or manually:

```bash
GODOT=./Godot_v4.6.1-stable_linux.x86_64
$GODOT --headless --path demo -s res://benchmarks/draw/run_draw_benchmarks.gd
```

After changing `src/visual_gasic_draw_benchmark.cpp`, rebuild the extension and restart Godot.

## Live scene (editor / windowed)

Open `demo/benchmarks/draw/draw_bench_live.tscn` and run the scene (F6). Results stream into the on-screen panel as each language completes each workload.

## Files

| File | Role |
|------|------|
| `draw_bench_config.gd` | Shared counts and colors |
| `draw_bench_workloads.gd` | GDScript draw implementations |
| `draw_bench_canvas_gd.gd` | GDScript Node2D runner |
| `draw_bench_moving_gd.gd` | GDScript moving-object runner |
| `bench_draw.vg` | VG Node2D draw runner |
| `bench_draw_moving.vg` | VG moving-object runner |
| `bench_draw_vector.vg` | VG `VGVectorCanvas2D` batch-rect runner |
| `draw_bench_vector_gd.gd` | GDScript vector-canvas runner |
| `run_draw_benchmarks.gd` | Headless 3-way orchestrator |
| `draw_bench_live.tscn` | Interactive benchmark scene |
| `src/visual_gasic_draw_benchmark.*` | C++ Node2D runner (registered ClassDB) |
| `src/visual_gasic_vector_draw_benchmark.*` | C++ `VGVectorCanvas2D` batch runner |

## Node2D draw vs VGVectorCanvas2D

**`DrawRect` / `DrawLine` on a plain `Node2D`** are CanvasItem builtins: the compiler emits `OP_CALL` (or dedicated `OP_DRAW_RECT` / `OP_DRAW_LINE` opcodes) and the VM calls Godot `CanvasItem::draw_*` on the script owner. One VM dispatch per primitive.

**`VGVectorCanvas2D`** is a separate native node (`src/visual_gasic_vector_canvas.cpp`) used by the vector-graphics plugin. Its `DrawRectsUniform` / `DrawLines` APIs append to a **command buffer**; `ExecuteQueuedCommands()` (or the native `_draw` when no VG `_Draw` handler is attached) replays that buffer in one pass. VG scripts with `_Draw` must call `ExecuteQueuedCommands()` after queuing — the VG draw hook replaces Godot's native `_draw` notification.

Use **`VectorCanvasUniformRects`** in this suite to compare batch vector-canvas rendering against per-call `FilledRects` on `Node2D`.

## Sample results (Linux, Godot 4.6.1 headless, Aug 2026)

All static workloads: checksums match across GDScript / VG / C++. **VG is much slower on draw dispatch** than compute benchmarks suggest.

| Workload | GDScript (µs) | Visual Gasic (µs) | C++ (µs) | VG vs GD |
|---|---:|---:|---:|---:|
| FilledRects ×2500 | ~1600 | ~120000 | ~150 | ~75× slower |
| Lines ×2000 | ~500 | ~50000 | ~160 | ~100× slower |
| Mixed ×2500 | ~3200 | ~160000 | ~1200 | ~50× slower |
| MovingFilledRects ×500 | ~135 avg/frame | ~9000 avg/frame | ~20 avg/frame | ~67× slower |

C++ wins every draw test (native `CanvasItem::draw_*`). GDScript beats VG on all draw workloads tested. Use this suite to track improvements as draw builtins and `_Draw` dispatch are optimized.


- Scripts must be attached to **Node2D** (or other `CanvasItem`) so draw builtins target the correct canvas.
- These benchmarks measure **draw-call dispatch + Godot canvas recording**, not GPU fill rate alone. VG overhead shows up strongly when many small primitives are issued from script.
- Re-run after VM/compiler optimizations; keep this suite as the regression baseline for drawing performance.
