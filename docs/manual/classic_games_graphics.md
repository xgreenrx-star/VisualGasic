# Classic games graphics (retro SCREEN profiles)

Visual Gasic is a **modern Godot-first** BASIC. This chapter is **optional**: it describes the **QuickBASIC-style framebuffer** (`SCREEN`, `PSet`, `Line`, …) and **extra SCREEN numbers** that mimic classic **resolution and layout**, not full hardware emulation.

Use this path when you want a **classic feel** (chunky pixels, few colors, split playfield + text). Use **canvas / Node2D** drawing when you want a shipping Godot game with modern features.

**Engine reference:** [QuickBASIC graphics mode (SCREEN)](qb_graphics_mode.md) — implementation in `src/visual_gasic_qb_screen.cpp`.

**Sample packs:**

- [QB ABC showcase](../../samples/showcases/qb_abc_showcase/) — press **`.`** on the main menu for **Classic systems — SCREEN mode gallery** (listed by system + mode). Full games use mode **13** by default.
- Standalone copy: [classic_screen_modes](../../samples/showcases/classic_screen_modes/) (same demos; optional separate Godot project).

---

## What we implement vs what we skip

| We provide | We do **not** emulate |
|------------|------------------------|
| Fixed-size pixel buffers, palette indices | ANTIC, copper, blitter, Apple artifact colors |
| `PSET`, `LINE`, `CIRCLE`, `PAINT`, `GET`/`PUT` | Multiple authentic bitplanes at once |
| **Split layouts** (gfx band + text band) | Exact register-level timing |
| `INKEY$`, `PLAY`, letterboxed scaling in Godot | DOS memory (`DEF SEG`, `PEEK`/`POKE`) |

Original `.BAS` files from other platforms still need **translation**; these modes make the **look** closer without claiming compatibility.

---

## SCREEN mode list

### DOS / PC (QuickBASIC and VGA)

| Mode | Size | Colors | Typical use |
|------|------|--------|-------------|
| **0** | 640×400 | 16 | Text-sized buffer (hide overlay with `SCREEN 0`) |
| **1** | 320×200 | 4 | CGA 4-color |
| **2** | 640×200 | 2 | Monochrome |
| **7** | 320×200 | 16 | EGA |
| **8** | 640×200 | 16 | EGA |
| **9** | 640×350 | 16 | EGA (Gorillas-style) |
| **12** | 640×480 | 16 | VGA 16-color |
| **13** | 320×200 | 256 | Most ABC / QB64 gallery games |
| **14** | 320×240 | 256 | VGA-style tall buffer |

### Classic profiles (100–199)

Inspired by other systems; **one framebuffer**, same drawing commands.

| Mode | Size | Colors | Inspired by |
|------|------|--------|-------------|
| **100** | 160×200 | 16 | Tandy / PCjr 160×200×16 |
| **101** | 320×200 | 16 | Tandy 320×200×16 |
| **102** | 640×200 | 4 | CGA / Tandy 640×200×4 |
| **110** | 320×192 | 256 | Atari 8-bit playfield (approx.) |
| **111** | 320×200 | 256 | **Atari-style split:** gfx rows 0–159, text band 160–199 |
| **112** | 320×200 | 256 | Split: gfx 0–175, text band 176–199 |
| **120** | 256×192 | 16 | TRS-80 Color Computer 256×192×16 |
| **121** | 128×96 | 4 | CoCo semigraphics-style (low res) |
| **130** | 280×192 | 16 | Apple II hi-res **inspired** (no artifact colors) |
| **131** | 140×192 | 16 | Apple II lo-res **inspired** |
| **140** | 320×200 | 16 | Commodore 320×200×16 feel |
| **150** | 320×256 | 256 | Amiga-ish chunky single buffer |

Unknown mode numbers in **100–199** default to 320×200×256 until we assign them. Other unknown modes behave like **13**.

Negative `SCREEN` handles remain **32-bit offscreen pages** (`_NewImage`), not classic profiles.

---

## Switching modes

Same statement as QuickBASIC:

```vb
Screen 13          ' DOS VGA256 — showcase default
Screen 100         ' Tandy narrow field
Screen 111         ' Split: draw game above the line; use PRINT in text band
Screen 0           ' Hide QB overlay (menus)
```

After `SCREEN`, use **mode width/height** for game logic (e.g. 160×200 on mode 100), not `Screen.Width` (monitor size).

### Query the active buffer (BASIC-style)

These are **functions**, not the `Screen` monitor namespace:

| Function | Returns |
|----------|---------|
| `ScreenMode()` | Active `SCREEN` number, **0** when the overlay is hidden (`Screen 0`). Offscreen `Screen img` returns the **negative** handle. |
| `GfxWidth()` | Logical buffer width in pixels |
| `GfxHeight()` | Logical buffer height in pixels |
| `GfxPlayfieldBottom()` | Last playfield row for split modes (**159** on mode **111**); full height minus one otherwise |

```vb
Screen 111
If ScreenMode() = 111 And GfxPlayfieldBottom() = 159 Then
    ' Keep sprites at y <= GfxPlayfieldBottom()
End If
```

**Project settings** (Project → Project Settings → **Vg**):

| Setting | Purpose |
|---------|---------|
| `vg/classic/enabled` | When **true**, Narcea prefers the classic SCREEN lane for this project |
| `vg/classic/clip_playfield` | When **true** (default), `PSET`/`LINE`/… cannot draw below the split line on modes **111** / **112** (use `Print` / `Locate` in the text band) |

The QB texture uploads **once per frame** during `_Process` (batched), not after every pixel op.

---

## Split-screen modes (111, 112)

On **111**, pixels **0–159** are the playfield; **160–199** are a **text band** (cleared to black, separator line drawn). You can still `PSET` anywhere, but the layout matches many **Atari BASIC** games that kept **graphics on top** and **text on the bottom**.

Example:

```vb
Sub StartAtariStyle()
    Screen 111
    Cls
    ' Stars in playfield only
    Dim i As Integer
    For i = 1 To 40
        PSet (Int(Rnd() * 318), Int(Rnd() * 158)), 15
    Next i
    Locate 21, 1
    Color 15, 0
    Print "N=North  S=Shoot  Q=Quit";
End Sub
```

Use **`Locate`** row/column so text falls in the lower band (rows map to 8-pixel cells). For new projects, **`IsKeyJustPressed`** is often easier than `INKEY$`; both work while a graphics `SCREEN` is active.

---

## Example: pick a profile for the game feel

```vb
' Narrow 160-wide shooter (Tandy feel)
Sub InitGame()
    Screen 100
    Cls
    Line (0, 0)-(159, 199), 1, BF   ' border color 1
End Sub
```

```vb
' CoCo-ish 256×192 board game
Sub InitBoard()
    Screen 120
    Cls
    Circle (128, 96), 40, 14
End Sub
```

```vb
' Back to showcase menu (QB ABC Main.vg)
Sub BackToMenu()
    Screen 0
End Sub
```

---

## Modern VG vs classic lane

| Topic | Modern (default) | Classic lane |
|--------|------------------|--------------|
| Drawing | `DrawLine`, `DrawRect`, `_Draw` | `Line`, `PSet`, `Circle` after `SCREEN` |
| Resolution | Nodes, anchors, viewport | Fixed mode table above |
| Input | Actions, `IsKeyDown` | `INKEY$` or shared keyboard |
| Docs | [Scripting](../getting_started/scripting.md), [2D rendering](2d_rendering.md) | This file + [qb_graphics_mode.md](qb_graphics_mode.md) |
| AI / Narcea | Full Godot + VG controls | Point Narcea at `.vg` ports; cite **VG CHANGES** in source |

Keep classic experiments in their own project or clearly named `.vg` files so you do not mix **`Screen 13`** sprites with **`Control.Left`** UI in one script without planning.

---

## Tests and regressions

After engine changes, rebuild the GDExtension and run:

```bash
VG_TEST_SUITE_VG_ONLY=1 ./run_test_suite.sh test_qb_screen.vg
```

Tests include standard modes and classic profile bounds (modes **100**, **111**).

---

## See also

- **[Classic porting guide](classic_porting_guide.md)** — SCREEN vs canvas, `.BAS` → `.vg` checklist, `MemoryBuffer` instead of `PEEK`/`POKE`
- [QuickBASIC graphics mode (full statement list)](qb_graphics_mode.md)
- [QB64-style subset limits](qb64_compat_roadmap.md)
- [ABC showcase notes](../showcase/QB64_SAMPLES_AND_SHOWCASE.md)
