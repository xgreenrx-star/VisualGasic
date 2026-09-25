# Colors in Visual Gasic

Godot stores colors as **floating-point channels from 0.0 to 1.0**. Visual Gasic exposes two constructors so you can write code in either Godot style or classic BASIC / HTML style (0–255).

## Color — normalized (0.0–1.0)

```vb
Dim c As Color
c = Color(1, 0, 0, 1)       ' opaque red
c = Color(0.5, 0.5, 0.5)      ' mid gray
DrawRect 0, 0, 640, 480, Color(0.1, 0.12, 0.16), True
```

Use **`Color`** when values are fractions of full intensity, or when you use named constants such as `Color.White` / `Color.Red`.

Values **greater than 1.0** are allowed (HDR) but on a normal 2D game viewport they often **clip to white**. Do not pass HTML-style 0–255 values to `Color()` — `Color(255, 255, 255)` is not “white at byte 255”; it saturates the screen.

## Color8 and RGB — byte channels (0–255)

```vb
DrawRect 0, 0, 960, 600, Color8(12, 18, 32), True
DrawString "Hello", 24, 28, Color8(200, 220, 255), 24
Dim sky As Color
sky = RGB(0, 128, 255)
```

- **`Color8(r, g, b)`** or **`Color8(r, g, b, a)`** — divides each argument by 255.
- **`RGB(r, g, b)`** — same 0–255 range (VB6-style name).

Use **`Color8`** / **`RGB`** for UI copied from hex palettes, QB ports, and any time you think in “0–255 per channel”.

## Quick reference

| Intent | Use | Example background |
|--------|-----|--------------------|
| Godot / shader style | `Color(0–1)` | `Color(0.05, 0.07, 0.12)` |
| Web / QB / VB palette | `Color8(0–255)` | `Color8(12, 18, 32)` |
| VB6 name | `RGB(0–255)` | `RGB(12, 18, 32)` |

## Canvas draw vs QuickBASIC SCREEN

- **`DrawRect` / `DrawString` / `DrawLine`** on a `Node2D` **`_Draw`** use Godot `Color` values (prefer **`Color8`** for 0–255).
- After **`SCREEN 13`**, **`PSET` / `LINE` / `CIRCLE`** use **palette indices** (0–255), not `Color8`. See [QuickBASIC graphics mode](qb_graphics_mode.md).

## See also

- [Visual Gasic Language Reference — Color / Color8 / RGB](../VisualGasic_Language_Reference.md)
- [2D Rendering](2d_rendering.md)
