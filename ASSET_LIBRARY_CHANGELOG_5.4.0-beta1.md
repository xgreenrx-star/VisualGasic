# VisualGasic 5.4.0-beta1 — Full Benchmark Wins

**Release date:** August 30, 2026  
**Requires:** Godot 4.6+  
**Platforms:** Linux, Windows, macOS (GDExtension binaries included)

---

## What's New Since 5.3.0-beta7

### Performance — 12/12 Compute + 9/9 Draw

Visual Gasic now beats GDScript on **every published compute and draw benchmark** — including FunctionCall (previously ~8× slower; now ~60× faster via compiler inlining and nested-loop fusion).

- Draw grid-loop fusion (`OP_DRAW_*_GRID_LOOP`)
- CI benchmark regression gate
- Canonical numbers: [BENCHMARK_PUBLISHED_RESULTS.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/BENCHMARK_PUBLISHED_RESULTS.md)

### Fixed — CInt Rounding

`CInt(3.7)` now returns **4** (VB6-style rounding), not truncated 3.

### IDE (carried from post-Beta7)

- Context rail sidecar, literal convert, sprite Data editor, Track D `.vgd` groundwork

---

## Quality

- **891/891** regression assertions (122 runnable `.vg` files; 1 data fixture skipped — tested via GDScript harness)
- **12/12 + 9/9** published benchmarks vs GDScript

---

## Links

- [Documentation Hub](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/DOCS.md)
- [Full Release Notes](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.4.0-beta1.md)
