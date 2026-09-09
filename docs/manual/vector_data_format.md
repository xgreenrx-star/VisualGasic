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

Top-left `(x1,y1)`, bottom-right `(x2,y2)`.

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

- **Context Rail → Vector data** — live preview while the caret is inside the block
- Point handles: drag vertices, Shift+click to append a vertex, right-click to remove
- Mouse wheel zoom; middle-drag pans the preview
- Edits debounce-write back to the `Data` lines in the source editor

## Limits (inline editor)

| Limit | Value |
|-------|-------|
| Max shapes per block | 32 |
| Max points per polyline | 32 |
| Max view size | 1024 × 1024 |

Larger art: use external **`.vgv`** files via `DataFile "ship.vgv"` (see `demos/Graphics/VGVector/`).

## External `.vgv` files

The standalone [VGVector demo](../../demos/Graphics/VGVector/VGVector.vg) uses the `VGV1` text format. The IDE vector file panel opens `.vgv` paths referenced by `DataFile` for the same point editing workflow.
