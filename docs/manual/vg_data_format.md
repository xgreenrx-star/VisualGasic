# VG Data File Format (`.vgd`)

**Version:** 1  
**Status:** Shipped — loaded by **`DataFile "path"`** when the file begins with magic `VGD\x01`  
**See also:** [External Data Files design](../design/external_data_files.md)

---

## Purpose

`.vgd` is an on-disk wrapper for large structured data referenced from `.vg` source:

```vg
World1Tiles:
DataFile "levels/world1.vgd"
```

Small text/CSV files can stay plain CSV — the parser inlines them as classic `Data` tape values. Use `.vgd` when:

- The grid is too large for the Variant-per-cell tape (level maps, big tilesets)
- You want parse-time load into a labeled **`MemoryBuffer`** (`DataBuffer("World1Tiles")`)

Do **not** use for: inline sprites ≤32×32 (use `*Sprite:` `Data`), display PNGs (`LoadPicture`).

---

## File layout

All integers are **little-endian**. Header is **32 bytes** fixed.

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0 | 4 | magic | ASCII `V`, `G`, `D`, version byte `0x01` |
| 4 | 1 | kind | Data kind (see below) |
| 5 | 1 | flags | Bit 0: payload is UTF-8 CSV (parse on load). Bit 1–7: reserved |
| 6 | 2 | reserved | Zero |
| 8 | 4 | width | Semantic width (tiles, columns, pixels) |
| 12 | 4 | height | Semantic height (rows, pixels) |
| 16 | 1 | elem_size | Bytes per cell: 1, 2, or 4 |
| 17 | 1 | palette_id | 0=NES, 1=GameBoy, 2=C64, 3=CGA; 255=none |
| 18 | 2 | reserved | Zero |
| 20 | 4 | stride | Row stride in bytes (≥ width × elem_size) |
| 24 | 4 | payload_len | Length of payload in bytes |
| 28 | 4 | crc32 | Optional CRC32 of payload; 0 = not checked |

**Payload** follows immediately at offset 32.

---

## Kind values

| kind | Name | Payload meaning |
|------|------|-----------------|
| 0 | `raw` | Opaque bytes; width/height informational |
| 1 | `grid_u8` | Dense row-major u8 cells (tile indices, palette pixels) |
| 2 | `grid_u16` | Dense row-major u16 cells (large tile IDs) |
| 3 | `grid_f32` | Dense row-major 32-bit floats |
| 4 | `table_csv` | UTF-8 CSV text (flags bit 0 set); parsed to buffer on load if needed |

---

## Runtime access (VG code)

```vg
WorldTiles:
DataFile "levels/world.vgd"

Sub _Ready()
    Dim n As Integer
    n = DataCount("WorldTiles")           ' width × height
    Dim tile As Integer
    tile = PeekData("WorldTiles", 0)      ' flat index: row * width + col
    Dim buf As Object
    buf = DataBuffer("WorldTiles")        ' MemoryBuffer — bulk Peek/Poke
End Sub
```

Text CSV referenced by `DataFile` still uses the classic tape — `Read`, `DataToArray("Label")`, etc.

---

## Authoring workflows

| Source | Tool | Output | IDE action |
|--------|------|--------|------------|
| Tiled JSON export | [Tiled Map Editor](https://www.mapeditor.org/) | `grid_u16` | Context Rail → **Import → .vgd** |
| CSV grid | Spreadsheet / editor | `grid_u8` / `grid_u16` | **Convert → .vgd** or ship CSV |
| Hand-built fixture | `vg_vgd_writer.gd` / tests | any kind | — |

**Tiled** is not bundled. Install via Flatpak (`org.mapeditor.Tiled`), winget, or the website; set **Project Settings → Vg → Datafile → Tiled Executable**, or use **Detect Tiled** in the Data file sidecar.

Recommended: author in Tiled/CSV, import once to `.vgd` for shipping builds.

Example CSV (8×8 tile map) before conversion:

```csv
0,0,1,1,0,0,0,0
0,1,2,2,1,0,0,0
...
```

---

## Versioning

- Magic version byte increments on incompatible header changes.
- Loaders reject unknown magic version with actionable error.
- Kind values are append-only within a magic version.

---

## Example hex dump (header only)

4×4 `grid_u8` map, palette none (255), 16-byte payload:

```
56 47 44 01  01 00 00 00   # VGD\x01, kind=grid_u8, flags=0
04 00 00 00  04 00 00 00   # width=4, height=4
01 FF 00 00  04 00 00 00   # elem_size=1, palette=255, stride=4
10 00 00 00  00 00 00 00   # payload_len=16, crc32=0
... 16 bytes of tile indices ...
```

Fixture: `test_proj/test_data/sample_map.vgd`
