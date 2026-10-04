# Inline Vector Data (`*Vector:` blocks)

Labeled `Data` blocks store coordinate-based vector art (lines and polylines), parallel to `*Sprite:` pixel blocks.

## Label rule

- Label name must end with **`Vector`** (case-insensitive), e.g. `ShipOutlineVector:`, `IconArrowVector:`

## Header row

```vb
ShipOutlineVector:
Data 320, 240, 8    ' viewW, viewH, gridStep (0 = no snap)
```

| Field | Meaning |
|-------|---------|
| `viewW`, `viewH` | Document/viewBox size in world units |
| `gridStep` | Grid snap step; `0` disables snap |

## Shape rows

One `Data` line per shape. Trailing fields are always stroke color and width: `R, G, B, A, strokeW`.

### LINE

```vb
Data LINE, x1, y1, x2, y2, R, G, B, A, strokeW
```

### RECT

```vb
Data RECT, x1, y1, x2, y2, R, G, B, A, strokeW
```

Top-left `(x1,y1)`, bottom-right `(x2,y2)`. In the IDE preview, `strokeW = 0` draws a **filled** rectangle (hull panels); any positive width draws an outline.

### POLYLINE

```vb
Data POLYLINE, pointCount, x1, y1, x2, y2, …, R, G, B, A, strokeW
```

`pointCount` is the number of vertices (minimum 2). The polyline is **open** (not closed).

## Example

```vb
ArrowVector:
Data 64, 64, 4
Data LINE, 4, 32, 60, 32, 255, 255, 255, 255, 2
Data POLYLINE, 3, 44, 20, 60, 32, 44, 44, 255, 200, 80, 255, 2
```

## IDE support

- **Vector Editor** (center toolbar) — full editor with SELECT / LINE / RECT / POLYLINE / DELETE tools, stroke color/width, grid snap, New/Open/Save. Opens from:
  - Context Rail → **Edit in Vector Editor…**
  - Code context menu → **Edit Vector Data as Image…**
  - Vector chips / gutter click in the code editor
  - Code Navigator → **(Vectors)** → ✏ Edit…
  - Path menu on `.vgv` literals → **Open in Vector Editor**
- **Data mode** — editing a `*Vector:` block; **Save Data** writes shapes back into the open `.vg` buffer
- **Context Rail → Vector data** — live mini-canvas while the caret is inside the block (drag / Shift+append / right-click remove)
- **New Vector…** in the Context Rail inserts a labeled block (optional open in Vector Editor)

## Limits (inline editor)

| Limit | Value |
|-------|-------|
| Max shapes per block | 32 |
| Max points per polyline | 32 |
| Max view size | 1024 × 1024 |

Larger art: use external **`.vgv`** files via `DataFile "ship.vgv"` (see `demos/Graphics/VGVector/`).

## External `.vgv` files

The standalone [VGVector demo](../../demos/Graphics/VGVector/VGVector.vg) uses the `VGV1` text format. Open `.vgv` in the **Vector Editor** (or edit in the Context Rail vector file panel).
