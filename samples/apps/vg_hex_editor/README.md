# VG Hex Editor (standalone)

A **binary file viewer/editor** written in Visual Gasic — the standalone counterpart to the IDE's GDScript hex panel (`addons/visual_gasic/vg_hex_editor.gd`).

## Run

```bash
scripts/sync_addons.sh convert
# Open samples/apps/vg_hex_editor in Godot 4.6 with Visual Gasic enabled, then F5
scripts/ci_smoke.sh samples/apps/vg_hex_editor
```

Try opening `sample_data/hello.bin`, edit a byte in the hex or ASCII column, and Save As to a new path.

Fully quit Godot after rebuilding `addons/visual_gasic/bin/` so the editor loads the new extension.

## Project map

| File | Role |
|------|------|
| `scenes/Main.tscn` | Window form — toolbar / find bar / status (Form Designer) |
| `scenes/Main.vg` | Form code-behind (extra tools, text panel, scrollbar) |
| `scripts/HexCanvas.vg` | Hex + ASCII rendering, keyboard, mouse, context menu |
| `scripts/HexModel.vg` | File buffer, cursor, selection, bookmarks, highlights, compare |
| `scripts/FileDialogs.vg` | Native Open / Save As pickers |
| `scripts/FileOps.vg` | Load / save via `MemoryBuffer` |
| `scripts/SearchOps.vg` | Hex / ASCII find + replace |
| `scripts/UndoOps.vg` | Overwrite / insert / delete undo |
| `scripts/CompareOps.vg` | Second-file diff |
| `scripts/HashOps.vg` | CRC-32 / MD5 / SHA-1 / SHA-256 |
| `scripts/BookmarkOps.vg` | Named offsets, F2 cycle |
| `scripts/HighlightOps.vg` | Colour-coded byte patterns |
| `scripts/RecentOps.vg` | Last 10 files (`user://vg_hex_recent.txt`) |
| `scripts/CopyOps.vg` | Hex / C / Python copy + fill |

## Features

Matches the IDE hex editor:

- Open / Save / Save As / Close (native `CommonDialog`)
- Recent files menu (persisted)
- Files up to **256 MB**
- 8 / 16 / 32 bytes per row
- Click + drag selection; arrows; Page Up/Down; Tab (hex ↔ ASCII)
- Type hex nibbles or ASCII to overwrite; Insert toggles INS/OVR (Delete/Backspace change size)
- Find (hex or ASCII), F3 / Shift+F3, Replace / Replace All
- Go To offset; Ctrl+C / Ctrl+V hex clipboard
- Right-click: copy hex / C array / Python bytes, paste, fill, bookmark, go to
- Compare two files (diff highlight) + Clear Diff
- Hash dialog: CRC-32, MD5, SHA-1, SHA-256 (report copied to clipboard)
- Highlight patterns; Bookmarks (Ctrl+B, F2 / Shift+F2)
- Text side panel (sliding ASCII window); vertical scrollbar
- LE/BE data inspector (int/uint/float); dirty-byte colouring
- Status bar + INS/OVR

## Docs

- IDE hex manual: [`docs/manual/HEX_EDITOR_MANUAL.md`](../../../docs/manual/HEX_EDITOR_MANUAL.md)
- Memory buffers: [`samples/demos/System/MemoryBuffer/`](../../demos/System/MemoryBuffer/)
