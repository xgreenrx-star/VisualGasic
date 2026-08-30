# VisualGasic 5.4.0-beta1 — Asset Library Changelog

Copy the **BBCode block** below into the Godot Asset Library version changelog field.

---

## BBCode (paste into Asset Library)

```
[b]VisualGasic 5.4.0-beta1[/b] — August 30, 2026 · Requires Godot 4.6+ · Linux / Windows / macOS binaries included

[b]Performance — 12/12 compute + 9/9 draw vs GDScript[/b]
Every published compute and draw benchmark now beats GDScript, including FunctionCall (~60× faster via compiler inlining and nested-loop fusion). Draw grid-loop fusion for hot [code]_Draw[/code] paths. CI benchmark regression gate.

[b]Fixed[/b]
[code]CInt(3.7)[/code] now returns [b]4[/b] (VB6-style rounding), not truncated 3.

[b]IDE (since Beta7)[/b]
Context rail sidecar, literal convert panel, sprite Data editor, Track D [code].vgd[/code] / DataFile groundwork.

[b]Beta Showcase (repo — not in this zip)[/b]
Full ~6-minute release tour: Backrooms hub → shader reel → About VG → Squash tease → Neon Runner → Vector Storm.
[url=https://youtu.be/FUw8zgbn_tU]Watch on YouTube[/url] · [url=https://github.com/xgreenrx-star/VisualGasic/tree/main/projects/vg_beta_showcase]Open project[/url]

[b]Quality[/b]
891/891 regression assertions · 12/12 + 9/9 published benchmarks

[url=https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.4.0-beta1.md]Full release notes[/url] · [url=https://github.com/xgreenrx-star/VisualGasic/blob/main/BENCHMARK_PUBLISHED_RESULTS.md]Benchmark tables[/url]
```

---

## Plain Markdown (reference)

**Release date:** August 30, 2026  
**Requires:** Godot 4.6+  
**Platforms:** Linux, Windows, macOS (GDExtension binaries included)

### Performance — 12/12 Compute + 9/9 Draw

Visual Gasic now beats GDScript on **every published compute and draw benchmark** — including FunctionCall (previously ~8× slower; now ~60× faster via compiler inlining and nested-loop fusion).

- Draw grid-loop fusion (`OP_DRAW_*_GRID_LOOP`)
- CI benchmark regression gate
- Canonical numbers: [BENCHMARK_PUBLISHED_RESULTS.md](https://github.com/xgreenrx-star/VisualGasic/blob/main/BENCHMARK_PUBLISHED_RESULTS.md)

### Fixed — CInt Rounding

`CInt(3.7)` now returns **4** (VB6-style rounding), not truncated 3.

### IDE (carried from post-Beta7)

- Context rail sidecar, literal convert, sprite Data editor, Track D `.vgd` groundwork

### Beta Showcase (repo)

- `projects/vg_beta_showcase/` — full tour demo (not inside this AssetLib zip; clone the repo)
- [Watch on YouTube](https://youtu.be/FUw8zgbn_tU)

### Quality

- **891/891** regression assertions
- **12/12 + 9/9** published benchmarks vs GDScript

### Links

- [Documentation Hub](https://github.com/xgreenrx-star/VisualGasic/blob/main/docs/DOCS.md)
- [Full Release Notes](https://github.com/xgreenrx-star/VisualGasic/blob/main/RELEASE_NOTES_v5.4.0-beta1.md)
