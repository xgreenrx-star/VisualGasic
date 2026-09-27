# BASIC-256 sample ports (QB ABC Showcase)

## Source

| Item | Detail |
|------|--------|
| Repository | [oonap0oo/BASIC-256](https://github.com/oonap0oo/BASIC-256) |
| Author (`.kbs` headers) | K Moerman (2026) |
| Language | [BASIC-256](https://basic256.org/) (not QuickBASIC) |

## License / redistribution

The GitHub repository **does not include a LICENSE file** (checked 2026-09-27). Under default copyright, the `.kbs` sources are not explicitly licensed for redistribution.

**What we ship:** Visual Gasic **transliterations** in `samples/showcases/qb_abc_showcase/games/B256*.vg` — same dimensions, loops, and subroutine structure as the `.kbs` files, with thin shims (`_NewImage`, `_Display`, `_TextAt`, `_RGBA32` fade). We do **not** copy `.kbs` files into the repo.

**Credit:** Algorithm and demo ideas from the repository above; external references cited in each original file (Wikipedia Barnsley fern, Hrvoje’s Minsky circle blog, USyd double-pendulum notes, etc.) remain credited in showcase intro text and in this document.

If the upstream author adds a permissive license, we can link it here and optionally ship closer transliterations.

## In the showcase

Main menu **`,` (comma)** → **Tier B256** (four demos). Intro screen shows credit before play (same pattern as other showcase games).

| Key | VG module | Upstream `.kbs` | Notes |
|-----|-----------|-----------------|-------|
| 1 | `B256Minsky.vg` | `minsky.kbs` | **Transliteration** — same `w/h/hw/hh`, loop, `plots`, `puttext`; `_NewImage(1168×700)` + `_Display` per `refresh` |
| 2 | `B256NonPeriodic.vg` | `non-periodic.kbs` | **Transliteration** — 500×500, `while True` body per tick, `f(t2)` vs `f(t1)` |
| 3 | `B256Swirl.vg` | `swirl2.kbs` | **Transliteration** — 580×580, nested `while`, `penwidth` → filled plot squares |
| 4 | `B256Julia.vg` | `julia.kbs` | **Transliteration** — 600×700, `N=512`, `calccolors`, column `refresh` |

## Not ported (performance / scope)

| Upstream | Reason |
|----------|--------|
| `test256.kbs` | Full-screen timing benchmark (~900×600); use engine benchmarks instead |
| `barnsley_fern2.kbs` | `w×h` iterations (millions of `plot` calls) |
| `double_pendulum.kbs` | `dt=1e-6` physics loop unsuitable for interpreted VG |
| `non-periodic_polar.kbs` | Optional future; similar to #2 |
| `swirl3D.kbs` | Heavier variant of swirl |

If a demo is too slow on a machine, reduce work in the `.vg` `Tick` batch constants or remove it from the menu (see comments in each file).
