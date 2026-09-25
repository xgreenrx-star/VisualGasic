# QuickBASIC graphics mode (SCREEN)

Visual Gasic includes **engine-level** QuickBASIC-style graphics commands for porting classic `.BAS` games and teaching QBasic-era syntax. They are **not** an IDE plugin: new language keywords are implemented in the GDExtension (`src/visual_gasic_qb_screen.cpp`) and wired through the normal builtin dispatcher.

**Import** adds Subs and Functions from other `.vg` files; it does **not** register new statement keywords. **IDE plugins** (`PLUGIN_SDK.md`) add editors, panels, and menu commands only.

The following are **not** implemented (DOS memory / native code / disk images): `DEF SEG`, `PEEK`/`POKE`, `CALL ABSOLUTE`, `INTERRUPT`, `BSAVE`, `BLOAD`.

---

## How it differs from VB6 `Screen` and canvas drawing

| Feature | QuickBASIC `SCREEN` | VB6-style |
|--------|---------------------|-----------|
| Logical resolution | `SCREEN 13` → 320×200 buffer | `Screen.Width` / `Screen.Height` = **monitor** size (pixels) |
| Drawing | `PSET (x,y), c`, `LINE`, `CIRCLE`, … | `PSet x, y, Color(...)`, `DrawLine`, … in `_Draw` on a `CanvasItem` |
| Clear | `CLS` clears the **QB buffer** when active | `CLS` clears dynamic nodes / queues redraw on canvas |
| File I/O | `Get #1, …` / `Put #1, …` unchanged | Same |
| Text input | `Line Input #n, var` unchanged | Same |

Until the first `SCREEN` statement runs, there is no QB framebuffer; `Screen.Width` still reports the display size.

When `SCREEN` is active, the buffer is shown as a **Sprite2D** child (`QbScreen`): **nearest-neighbor** scaling, **letterboxed** inside the Godot viewport. The project window size is not changed.

---

## SCREEN modes

### DOS / PC (QuickBASIC)

| Mode | Size (pixels) | Colors | Notes |
|------|---------------|--------|--------|
| 0 | 640×400 | 16 | Text-sized buffer (80×25 cells at 8×16); `PRINT` still goes to the debug console |
| 1 | 320×200 | 4 | CGA-style 4-color palette |
| 2 | 640×200 | 2 | Monochrome |
| 7 | 320×200 | 16 | EGA |
| 8 | 640×200 | 16 | EGA |
| 9 | 640×350 | 16 | EGA |
| 12 | 640×480 | 16 | VGA |
| 13 | 320×200 | 256 | Default for most ABC archive games |
| 14 | 320×240 | 256 | VGA-style tall buffer |

### Classic profiles (100–199)

Extra modes for **retro feel** (Tandy, Atari layout, CoCo, Apple-inspired, C64-ish, Amiga-ish). Not hardware-accurate. Full table, split-screen behavior, and examples: **[Classic games graphics](classic_games_graphics.md)**. Demos: `samples/showcases/classic_screen_modes/`. Query active buffer: `ScreenMode()`, `GfxWidth()`, `GfxHeight()`, `GfxPlayfieldBottom()` (not `Screen.Width`).

| Mode | Size | Colors | Summary |
|------|------|--------|---------|
| 100 | 160×200 | 16 | Tandy / PCjr |
| 101 | 320×200 | 16 | Tandy |
| 102 | 640×200 | 4 | CGA / Tandy wide |
| 110 | 320×192 | 256 | Atari playfield (approx.) |
| 111 | 320×200 | 256 | Atari-style **split** (gfx 0–159, text 160–199) |
| 112 | 320×200 | 256 | Split gfx 0–175 |
| 120 | 256×192 | 16 | Color Computer |
| 121 | 128×96 | 4 | CoCo low / semigraphics feel |
| 130 | 280×192 | 16 | Apple II hi-res inspired |
| 131 | 140×192 | 16 | Apple II lo-res inspired |
| 140 | 320×200 | 16 | Commodore-style |
| 150 | 320×256 | 256 | Amiga-ish chunky buffer |

Unknown modes in **100–199** default to 320×200×256 until assigned. Other unknown modes default to **mode 13** behavior.

**32-bit pages (QB64-style):** `_NewImage` returns a **negative** handle (so it never collides with mode `13`). `SCREEN handle` displays that page. Colors on a 32-bit page are `_RGB32` / `_RGBA32` (`&HAARRGGBB`), not palette indexes.

```vb
Dim img As Integer
img = _NewImage(_DesktopWidth, _DesktopHeight, 32)
Screen img
PSet (10, 10), _RGB32(255, 40, 40)
```

`_DesktopWidth` / `_DesktopHeight` are the primary monitor size (if the OS reports 0×0, the Godot viewport size is used, then 640×480). Parentheses are optional on these zero-argument names (same for `_MouseX`, `_MouseY`, `_MouseInput`, `_Width`, `_Height`). The buffer is still **letterboxed** inside the Godot viewport (nearest-neighbor); it does not force the OS window to that size.

**Syntax:** `SCREEN modeNumber` or `SCREEN imageHandle`

**Example:**

```vb
Screen 13
PSet (160, 100), 15
```

---

## Coordinates and colors

- Origin **top-left**; **Y increases downward** (same as QBasic screen coordinates).
- Color arguments are **integer palette indices** (0 … `ncolors-1`), not Godot `Color` objects.
- Default drawing color is **15** (white) when modes support it.
- Mode **13** uses EGA indices 0–15, a 6×6×6 color cube for 16–231, and grayscale 232–255.

Read a pixel back with **`Point(x, y)`** (returns index, or **-1** off-screen).

---

## Drawing statements

### PSET

```vb
PSET (x, y) [, color]
```

Parentheses form only. This writes the **QB buffer**.

Canvas form **`PSet x, y, color`** (no parentheses) still calls **DrawPixel** during `_Draw` and is unchanged.

### LINE

```vb
LINE (x1, y1)-(x2, y2) [, color] [, {B | BF}]
```

- **`B`** — box outline (hollow rectangle).
- **`BF`** — filled box.

Color may be omitted (uses current color).

### CIRCLE

```vb
CIRCLE (x, y), radius [, color]
```

Outline only (QB-style midpoint circle).

### PAINT

```vb
PAINT (x, y) [, fillColor [, borderColor]]
```

Flood fill from `(x, y)`. If `borderColor` is omitted, fill stops at pixels that differ from the seed color.

### CLS

When a QB screen is **active**, `CLS` clears the framebuffer to color **0**. Otherwise behavior is the existing canvas `CLS`.

---

## GET and PUT (graphics)

These use **parenthesized** coordinates and an **array**. They do **not** replace file **`Get #`** / **`Put #`**.

### GET

```vb
GET (x1, y1)-(x2, y2), arrayName
```

The array is resized/filled as:

| Index | Meaning |
|-------|---------|
| `arr(0)` | Width in pixels |
| `arr(1)` | Height in pixels |
| `arr(2)` … | Row-major color indices |

### PUT

```vb
PUT (x, y), arrayName [, action]
```

| `action` | Effect |
|----------|--------|
| *(default)* / `XOR` | XOR source with destination |
| `PSET` | Copy source pixels |
| `PRESET` | Copy with inverted indices |
| `AND` | Bitwise AND |
| `OR` | Bitwise OR |

**Example:**

```vb
Dim tile(0) As Integer
Get (0, 0)-(7, 7), tile
Put (100, 50), tile, PSET
```

---

## INKEY$

```vb
Dim k As String
k = InKey$    ' also: Inkey(), InKey$
```

Returns **one** waiting token, or **`""`** if none. Keys are queued from `_Input` / `_UnhandledInput` on the script owner (up to 64 tokens) **only while a graphics `SCREEN` is active**. The queue is **cleared** when you call **`SCREEN 0`** (hide overlay / return to menu) and when you open graphics mode again after it was off — so held arrow keys do not carry into the next game run.

Printable keys are one character. Arrow / extended keys use the classic QBasic **two-call** pattern: first `InKey$` returns `Chr(0)`, second returns the scan byte (72=Up, 75=Left, 77=Right, 80=Down).

Godot `String` cannot hold U+0000 (Godot logs “Unexpected NUL character”). VG maps **`Chr(0)`** and that prefix to an internal sentinel code point; **`Asc`**, **`= Chr(0)`**, and **`vbNullChar`** behave like QBasic. Do not rely on the raw Unicode value of `Chr(0)`.

```vb
k = InKey$
If k = Chr(0) Then
    k = InKey$
    sc = Asc(k)   ' 72 / 75 / 77 / 80
End If
```

For new Godot-style games, **`IsKeyJustPressed`** / input actions are usually clearer; `INKEY$` is for QBasic ports.

### Godot Output: “Unexpected NUL character”

While arrow keys and other extended keys are queued, Godot’s Output panel may print many lines like **Unexpected NUL character**. That comes from Godot’s UTF-8 `String` handling around QBasic-style `Chr(0)` prefixes — **not** a Visual Gasic crash. Input and your game keep working; **you can ignore those messages**. They are documented here so you do not need to treat them as a fatal error.

---

## PLAY

```vb
Play "T120 O3 L4 C D E"
```

Maps QB-style note strings to the existing **SiON / Music.Play** path (MML). If **SiONDriver** is not available, the statement **succeeds silently** (no second sound engine).

Requires the vgmusic / GDSiON setup documented in [Bosca Ceoil Manual](BOSCA_CEOIL_MANUAL.md) for audible output.

---

## Pages, palette, text, and motion

| Statement | Behavior |
|-----------|----------|
| `SCREEN mode [, [colorSwitch] [, [activePage] [, visualPage]]]` | `SCREEN 0` still **hides** the overlay (showcase menus). Modes 1–13 keep two pages (0 and 1). Same mode again only switches pages. |
| `PCOPY source, dest` | Copy one page onto the other. |
| `PALETTE` | Restore the default palette. |
| `PALETTE index, &HBBGGRR` | One entry. Channels are 0–63 (DAC) or 0–255. |
| `PALETTE index, r, g, b` | Same entry as a long: low byte red, then green, then blue (0–255). |
| `PALETTE USING array` | `array(0)` … recolors indexes. `PaletteColor(i)` reads the value last assigned. |
| `LOCATE row, column` | Text cursor (1-based). `CsrLin()` and `Pos(0)` read it back. |
| `COLOR foreground [, background]` | Text cell colors for the next `PRINT`. |
| `PRINT` | Always goes to the Godot console. After `LOCATE` or `COLOR`, the same text is also drawn in 8×8 cells on the active page (public-domain 8×8 font). `CLS` turns that mirror off until the next `LOCATE` / `COLOR`. |
| `VIEW (x1,y1)-(x2,y2) [, fillColor]` | Pixel clip (and optional fill). `VIEW` alone clears the clip. |
| `WINDOW [SCREEN] (x1,y1)-(x2,y2)` | Logical coordinates. Without `SCREEN`, Y increases upward. `WINDOW` alone turns mapping off. |
| `CIRCLE (x,y), r [, color [, start [, end [, aspect]]]] [, F]` | `start`/`end` are radians (negative = radius line). Trailing `F` fills the ellipse. |
| `LINE [STEP] (x1,y1)-[STEP] (x2,y2)` and `LINE -STEP (x,y)` | `STEP` is relative to the graphics cursor (second `STEP` is relative to the line start). |
| `DRAW "command"` | `U D L R E F G H`, `M`, `B`, `N`, `C`, `A`, `TA`, `S`, `P`. Scale default `S4`. |
| `PUT …, TRANS` | Skip palette index 0 (DirectQB-style transparent blit). |
| `SCROLL dx, dy` or `SCROLL (x1,y1)-(x2,y2), dx, dy` | Move pixels; vacated cells become 0. |
| `SOUND frequency, ticks` / `BEEP` | Short tone (`ticks` / 18.2 seconds, capped). |
| `WAIT …` | Accepted and ignored (no VGA port). |
| `LoadPcx(path)` | 8-bit one-plane PCX → array shaped like `GET` (`(0)` width, `(1)` height, then indexes). |
| `_NewImage(w, h, 32)` | Offscreen page; **negative** handle. `32` = RGBA. |
| `_LoadImage(path)` | PNG/JPG/WebP → 32-bit page (0 if load fails). |
| `_FreeImage handle` | Release a page. |
| `_Dest handle` / `_Source handle` | Draw / `Point` target (`0` = palette `SCREEN`). |
| `_PutImage (x, y), source` | 1:1 blit onto `_Dest`. |
| `_Display` | Present the visual page. |
| `_Width` / `_Height` | Visible size, or `_Width(handle)`. |
| `_DesktopWidth` / `_DesktopHeight` | Primary monitor pixels. |
| `_RGB32(r,g,b)` / `_RGBA32(r,g,b,a)` | 0–255 channels, `&HAARRGGBB`. |
| `_MouseX` / `_MouseY` | Cursor in QB buffer space. |
| `_MouseButton(n)` | `1` left, `2` right, `3` middle; **-1** down, **0** up. |
| `_MouseInput` | **-1** if the mouse moved or clicked since the last call, else **0**. |
| `_SndOpen(path)` | Load WAV/OGG; **0** on failure. |
| `_SndPlay` / `_SndStop` / `_SndClose` | Play, stop, release. |
| `_SndPlaying(h)` | **-1** while playing. |

---

## QB64 subset — limits

`_NewImage`, mouse, `_SndOpen`, and `_DesktopWidth` are a **small** QB64-shaped set. They do not stretch `_PutImage`, play MIDI, report the mouse wheel, or resize the OS window (`$Resize`). Those stay out of this layer unless a port actually needs them. Canvas drawing, `_Input`, and Godot audio already cover them.

Full list: [QB64-style layer — limits](qb64_compat_roadmap.md).

---

## Porting tips

Full workflow: **[Classic porting guide](classic_porting_guide.md)** (SCREEN vs canvas, checklist, `VGMemoryBuffer`).

1. Call **`SCREEN 13`** (or the mode the listing expects) before graphics.
2. Replace **`DEF SEG` / `PEEK` / `POKE`** with VG variables or **`VGMemoryBuffer`** — not supported on the QB layer.
3. Use **`Point(x, y)`** in tests instead of screenshots.
4. Keep **`Screen.Width`** for layout only when you mean the **monitor**; use **`GfxWidth()` / `GfxHeight()`** for game logic after `SCREEN`.
5. Regression tests: `test_proj/test_suite/test_qb_screen.vg` (`VG_TEST_SUITE_VG_ONLY=1 ./run_test_suite.sh test_qb_screen.vg`).

---

## See also

- [Classic games graphics — retro SCREEN profiles (isolated from modern VG)](classic_games_graphics.md)
- [QB64-style layer — what is in, and what is left out](qb64_compat_roadmap.md)
- [VisualGasic Language Reference — QuickBASIC Graphics Mode](../VisualGasic_Language_Reference.md#quickbasic-graphics-mode-screen)
- [Builtin Functions Reference — QuickBASIC graphics](../reference/BUILTIN_FUNCTIONS_REFERENCE.md#quickbasic-graphics-screen)
- [keywords.md](keywords.md) — keyword summary table
