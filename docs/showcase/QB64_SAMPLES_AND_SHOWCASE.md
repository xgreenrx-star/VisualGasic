# QB64.com samples vs this showcase

The [QB64 sample gallery](https://qb64.com/samples.html) lists hundreds of `.BAS` programs. **There is no single license** for the gallery. Visual Gasic ships **original** `.vg` reimplementations in `samples/showcases/qb_abc_showcase/` — not copied `.BAS` files.

**Navigation:** main menu **Q** → hub (**G** games, **D** demos, **T** tools, **S** skipped list).

## Your requested URLs (18)

| Sample | Category | Showcase | Notes |
|--------|----------|----------|--------|
| [fire-demo](https://qb64.com/samples/fire-demo/) | Demo | **D → 1** `Q64FireDemo.vg` | Palette fire table |
| [gorillas](https://qb64.com/samples/gorillas/) | Game | **Tier B → 1** `Gorillas.vg` | Microsoft sample; not duplicated in Tier Q |
| [frostbite](https://qb64.com/samples/frostbite/) | Game | **Skipped (S)** | Large asset/`_PUTIMAGE`/audio port |
| [mandelbrot-animator](https://qb64.com/samples/mandelbrot-animator/) | Demo | **D → 2** `Q64Mandelbrot.vg` | Lite scan + palette phase |
| [matrix-effect](https://qb64.com/samples/matrix-effect/) | Demo | **D → 3** `Q64Matrix.vg` | No 32-bit alpha fade (lite columns) |
| [particle-fountain](https://qb64.com/samples/particle-fountain/) | Demo | **D → 4** `Q64Particles.vg` | ~120 particles, not 30k |
| [pipes-puzzle](https://qb64.com/samples/pipes-puzzle/) | Game | **G → 4** `Q64Pipes.vg` | Keyboard rotate; no PNG/mouse |
| [qbricks](https://qb64.com/samples/qbricks/) | Game | **G → 3** `Q64QBricks.vg` | Multi-row breakout |
| [relief-3d](https://qb64.com/samples/relief-3d/) | Demo | **D → 5** `Q64Relief3D.vg` | Isometric line scroll |
| [torus-demo](https://qb64.com/samples/torus-demo/) | Demo | **D → 6** `Q64Torus.vg` | Wireframe lite |
| [vector-field](https://qb64.com/samples/vector-field/) | Demo | **D → 7** `Q64VectorField.vg` | Draggable charge |
| [turtle-graphics](https://qb64.com/samples/turtle-graphics/) | Demo | **D → 8** `Q64Turtle.vg` | Koch snowflake |
| [tui](https://qb64.com/samples/tui/) | Tool | **Skipped (S)** | Fellippe `tui()` framework |
| [shooter](https://qb64.com/samples/shooter/) | Game | **G → 1** `Q64Shooter.vg` | Vertical shmup lite |
| [platform](https://qb64.com/samples/platform/) | Game | **G → 2** `Q64Platform.vg` | Rectangle platformer |
| [helicopter-rescue](https://qb64.com/samples/helicopter-rescue/) | Game | **Skipped (S)** | No gallery `.BAS`; full sim scope |
| [dialog-demo-box](https://qb64.com/samples/dialog-demo-box/) | Tool | **T → 1** `Q64DialogBox.vg` | Text panels on SCREEN 13 |
| [american-flag](https://qb64.com/samples/american-flag/) | Demo | **D → 9** `Q64Flag.vg` | Static stripes; no Vince warp |

Also under **G → 5–7:** Tic Tac Toe, Lights On, Life (earlier Tier Q puzzles).

## Legal rule

| Source | Approach |
|--------|----------|
| QB64 `libqb` (MIT) | Reference only; do not embed |
| Microsoft QBasic samples | Rewrite in VG (Gorillas, QBricks lineage) |
| Community `.BAS` | **Do not paste** without permission; reimplement ideas |
| Algorithms | Implement yourself |

## Engine gaps vs full QB64 samples

The QB layer now has a **subset** of `_NewImage`, `_PutImage` (1:1 only), mouse, `_SndOpen`, and `_DesktopWidth`. Stretch blit, MIDI, mouse wheel, and `$Resize` are **not** in that layer. Limits and the VG alternatives: [qb64_compat_roadmap.md](../../docs/manual/qb64_compat_roadmap.md).

Tier Q still targets **SCREEN 13** (320×200×256) unless the host HUD is Godot `DrawString`.
