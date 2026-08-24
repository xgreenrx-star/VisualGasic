# External Data Files — Design & Reference

**Status:** Shipped (Track D core — **v5.4.0-beta1**)  
**Last updated:** August 24, 2026

---

## Where we are (read this first)

### Three layers — don't mix them up

| Layer | What | Status |
|-------|------|--------|
| **1. Source** | `.vg` text: `Data …`, `DataFile "path"`, labeled sections | Shipped |
| **2. Runtime** | Classic DATA tape + flat literal cache (E1); labeled `.vgd` → `MemoryBuffer` (E2) | Shipped |
| **3. Sidecar (IDE)** | Inline sprite grid ≤32×32; **Data file** panel for `DataFile` paths | Shipped |

### `DataFile` keyword

```vg
World1Tiles:
DataFile "levels/world1.vgd"

SpawnTable:
DataFile "data/spawns.csv"

PlayerSprite:
Data 8, 8, 0, 0
Data 0,0,1,1,...
```

- **Parse time only** — opens the file when the module is compiled.
- **Text / CSV** — body parsed as comma-separated `Data` values; merged onto the DATA tape (same as inline `Data`).
- **Binary `.vgd`** — magic sniff (`VGD\x01`); loaded into a labeled **`MemoryBuffer`** section (not one Variant per cell on the tape).
- **`LoadData`** — **runtime** append of a text file onto the DATA tape (dynamic path).

Documented in [`VisualGasic_Language_Reference.md`](../VisualGasic_Language_Reference.md) (`DataFile`, `DataBuffer`, `LoadData`, `PeekData`, `DataCount`). Binary spec: [`vg_data_format.md`](../manual/vg_data_format.md). Demos: `demo/test_suites/test_datafile.vg`, `test_proj/test_suite/test_datafile_vgd.vg`.

### Runtime access

| API | Use |
|-----|-----|
| `Read` / `Restore` | Classic sequential tape (inline `Data`, CSV `DataFile`, `LoadData`) |
| `DataCount()` | Total items on tape |
| `DataCount("Label")` | Items in labeled section (`.vgd` grid: width × height) |
| `PeekData(index)` | Absolute tape index without advancing pointer |
| `PeekData("Label", offset)` | Cell in labeled section (tape or `.vgd`) |
| `DataBuffer("Label")` | `MemoryBuffer` when label’s `DataFile` was binary `.vgd` |
| `DataToArray("Label")` | Flat array (cache once in `_Ready` for sprites/small tables) |

### How inline `Data` is stored (and why large maps need `.vgd`)

Each tape value is an **`ExpressionNode*`** (usually `LiteralNode` → Godot **`Variant`**). Every `Read` / `PeekData` / `DataToArray` cell on the classic path calls `evaluate_expression()`.

**E1 (shipped):** all-literal sections are **flattened once** at init — faster `Read` / `PeekData` / `DataToArray` with no syntax change.

**E2 (shipped):** binary `.vgd` sections skip the tape entirely → **`MemoryBuffer`**.

Fine for piano notes and 8×8 sprites; **not** for 64×64+ level maps on the unflattened tape path — use **`DataFile` + `.vgd`**.

---

## Sidecar + editors

| Tier | Size | Source | Sidecar | Editor |
|------|------|--------|---------|--------|
| Inline sprite | ≤32×32 | `Data` rows | Pixel grid | Context Rail |
| Tables / small grids | medium | `Data` / `DataFile` CSV | Text preview | Spreadsheet, VS Code |
| Large levels | large | `DataFile` → `.vgd`/CSV | Grid meta + actions | **Tiled** (optional) |
| Display art | any | PNG + `LoadPicture` | File panel | Sprite Editor |

**Context Rail → Data file** (caret on `DataFile "path"` or label):

- Preview: CSV snippet, `.vgd` dimensions, PNG thumb, hex for raw
- **Convert → .vgd** (CSV), **Import → .vgd** (Tiled JSON)
- **Detect Tiled** / **Install Tiled…** / **Open in Tiled**
- Reveal in file manager, copy path

Project setting: **`vg/datafile/tiled_executable`**.

Tiled is **not bundled** — users install via Flatpak, winget, or [mapeditor.org](https://www.mapeditor.org/download.html).

---

## Phased delivery

### Shipped in 5.4.0-beta1

- [x] **D0** — `vg_datafile_resolver.gd`, preview panel, outline landmarks, `tests/test_datafile_resolver.gd`
- [x] **E1** — Flat literal sections (`data_flat_cache`); fast `Read` / `PeekData` / `DataToArray`
- [x] **D1/E2** — Binary `.vgd` sniff in `parse_data_file()`; `DataBuffer`, labeled `PeekData` / `DataCount`
- [x] **D2** — CSV → `.vgd`, Tiled JSON → `.vgd`, grid preview metadata, Tiled install/detect
- [x] Docs — Language Reference, command help, this plan, `vg_data_format.md`, IDE tools, Narcea knowledge

### Follow-ups (5.5+)

- [ ] Image payload `.vgd` sections (indexed PNG → grid)
- [ ] CSV bulk export from sidecar
- [x] Narcea knowledge regression — `tests/test_narcea_datafile_knowledge.gd` (prompt cites `DataFile` for large tilemaps)

---

## File map

```
docs/manual/vg_data_format.md
docs/design/external_data_files.md     # This document

addons/visual_gasic/
  vg_datafile_resolver.gd
  vg_datafile_preview_panel.gd
  vg_datafile_sniff.gd
  vg_vgd_writer.gd
  vg_tiled_import.gd
  vg_tiled_install.gd
  vg_context_analyzer.gd / vg_context_rail.gd

src/visual_gasic_vgd_loader.cpp
src/visual_gasic_parser.cpp            # DataFile binary sniff
src/visual_gasic_instance.cpp          # E1 flatten + buffer registry
```

---

## Success criteria (5.4)

1. Sidecar previews **`DataFile`** paths in `.vg` source. ✅
2. Sprite / numeric **`DataToArray`** uses flat cache where possible. ✅
3. Large level data has a **binary path** that does not allocate Variants per tile. ✅
4. Language Reference documents **`DataFile`** vs **`LoadData`**. ✅
