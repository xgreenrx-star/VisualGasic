# VG Hex Editor — User Manual

The VG Hex Editor is a fully-featured binary file editor built into the VisualGasic IDE.
It lets you view, edit, search, compare, and analyse any file at the byte level without
leaving Godot.

---

## Opening the Hex Editor

| Method | Action |
|--------|--------|
| **VG Tools menu → Hex Editor...** | Opens the editor empty; use 📂 Open to pick a file |
| **Right-click a file in the VG File Browser → Open in Hex Editor** | Opens that file immediately |
| **Godot Tools menu → Visual Gasic Hex Editor...** | Same as the VG Tools menu entry |

The window is created lazily — it has no startup cost and only appears when you first invoke it.

---

## The Interface

```
┌──────────────────────────────────────────────────────────────────────────┐
│  [📂 Open ▾] [💾 Save] [Save As] | [↩ Undo] [↪ Redo] | [Go To...]       │
│  | [⇔ Compare] [✕ Diff] | [# Hash] | [🎨 Highlight] | [🔖 Bookmarks ▾]   │
│  | Cols: [16 ▾] | path/to/file.bin           ● Modified                  │
├──────────────────────────────────────────────────────────────────────────┤
│  Find: [__________________] [Hex ▾] [Search] [◀] [▶]     3 / 17         │
│  Replace: [__________________]          [Replace]  [Replace All]         │
├─────────┬──────────────────────────────────────────────────────┬─────────┤
│  Offset │  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  │ ASCII   │
│  00000000│  FF D8 FF E0 00 10 4A 46  49 46 00 01 01 00 00 01  │ ÿØÿà..JF│
│  …       │                                                     │         │
├──────────────────────────────────────────────────────────────────────────┤
│  Offset: 0x00000004 (4)  Value: 0x00  Dec: 0  Size: 14.2 KB  Sel: 4 bytes│
│  int8: 0  uint8: 0  int16LE: 0  uint16LE: 0  float32LE: 0  [LE]         │
└──────────────────────────────────────────────────────────────────────────┘
```

### Colour coding (hex panel)

| Colour | Meaning |
|--------|---------|
| Dark grey `#3A3A3A` | Null byte (0x00) |
| Orange `#CE9178` | Printable ASCII range (0x20–0x7E) |
| Blue `#9CDCFE` | High byte (0x80–0xFF) |
| Light grey `#D4D4D4` | Control / other byte |
| Red `#FF6B6B` | Byte modified since last save |
| Gold bar on left | Bookmark at this offset |
| Dark red background | Byte differs from compare file |
| User colour | Matches a Highlight Pattern |

---

## Navigation

| Key | Action |
|-----|--------|
| Arrow keys | Move cursor one byte |
| `Home` / `End` | Start / end of current row |
| `Ctrl+Home` / `Ctrl+End` | Start / end of file |
| `Page Up` / `Page Down` | Jump one screen |
| `Tab` | Switch between Hex panel and ASCII panel |
| `Scroll wheel` | Scroll 3 rows at a time |
| **Left-click** | Place cursor |
| **Left-drag** | Select a range of bytes |
| `Shift+click` | Extend selection to clicked byte |
| `Shift+Arrow` | Extend selection with keyboard |

---

## Editing

| Key / Action | Effect |
|---|---|
| Type **two hex digits** (hex panel) | Overwrite byte at cursor |
| Type any **printable character** (ASCII panel) | Overwrite byte |
| `Insert` | Toggle **Insert** / **Overwrite** mode |
| `Delete` (Insert mode) | Delete byte at cursor |
| `Backspace` (Insert mode) | Delete byte before cursor |
| `Ctrl+Z` / `Ctrl+Y` | Undo / Redo |
| `Ctrl+S` | Save |

> **Insert mode** changes the file size; **Overwrite mode** (default) replaces bytes without changing size.

---

## Selection

| Action | Result |
|--------|--------|
| `Ctrl+A` | Select entire file |
| Left-drag | Select dragged range |
| `Shift+Arrow` | Extend selection |
| `Shift+Click` | Extend to clicked byte |

When a selection is active the status bar shows **Sel: N bytes (0xStart–0xEnd)**.

---

## Copy Formats

Right-click → choose a format, or use `Ctrl+C` for plain hex.

| Menu item | Output example |
|-----------|---------------|
| **Copy as Hex** (`Ctrl+C`) | `FF D8 FF E0` |
| **Copy as C Array** | `{ 0xFF, 0xD8, 0xFF, 0xE0 }` |
| **Copy as Python bytes** | `b"\xff\xd8\xff\xe0"` |

If no selection is active, the single byte at the cursor is copied.

---

## Find & Replace

1. Press `Ctrl+F` (or click the Find bar) to focus the search field.
2. Type a hex pattern (e.g. `FF D8 FF`) or ASCII text; choose the mode with the drop-down.
3. Press **Search** or `Enter`. Results count shown on the right.
4. `F3` / `▶` — next result. `Shift+F3` / `◀` — previous result.
5. To **replace**, type the replacement hex bytes in the **Replace** field.
6. **Replace** — replaces the current match and advances. **Replace All** — replaces every match at once.

> The replace field always expects hex bytes (e.g. `00 00` to zero out a pattern).

---

## Go to Offset

- `Ctrl+G` or the **Go To...** toolbar button.
- Enter a decimal offset (e.g. `1024`) or a hex offset prefixed with `0x` (e.g. `0x400`).

---

## File Compare

1. Click **⇔ Compare** in the toolbar and pick a second file.
2. Bytes that **differ** between the two files are highlighted with a dark-red background and light-red text.
3. Bytes past the end of the shorter file are also highlighted.
4. Click **✕ Diff** to clear the comparison.

---

## Hash / Checksum

1. Optionally **select** a range of bytes to hash only that region; otherwise the whole file is hashed.
2. Click **# Hash** in the toolbar.
3. A dialog shows **CRC-32**, **MD5**, **SHA-1**, and **SHA-256**.
4. Each value has a **Copy** button for quick clipboard access.

---

## Highlight Patterns

Highlight patterns let you permanently colour-code byte sequences (e.g. a magic number, a known header).

1. Click **🎨 Highlight** in the toolbar.
2. Enter a hex pattern in the text field (e.g. `FF D8 FF E0`).
3. Pick a colour with the colour picker button.
4. Optionally give it a label.
5. Click **Add**. All matching byte sequences in the file will be highlighted in that colour.
6. To remove a pattern click **✕** next to it in the list.

Multiple patterns can be active at once; they are applied in order.

---

## Bookmarks

Bookmarks mark named offsets so you can jump back to them quickly.

| Action | How |
|--------|-----|
| **Add bookmark** | `Ctrl+B`, right-click → *Add Bookmark*, or **🔖 Bookmarks → Add Bookmark Here** |
| **Jump to bookmark** | **🔖 Bookmarks** menu → click the name |
| **Cycle forward** | `F2` |
| **Cycle backward** | `Shift+F2` |
| **Clear all** | **🔖 Bookmarks → Clear All Bookmarks** |

Bookmarks are gold bar ticks on the left edge of the hex column at their offset.
They are stored in memory only — they do not persist between sessions.

---

## Data Inspector

The second status bar row shows numeric interpretations of the bytes at the cursor.

Click the **LE** / **BE** button (bottom-right of the status bar) to toggle between
**Little-Endian** and **Big-Endian** interpretation for all multi-byte types.

| Field | Description |
|-------|-------------|
| `int8` / `uint8` | Signed / unsigned single byte |
| `int16` / `uint16` | 16-bit integer |
| `int32` / `uint32` | 32-bit integer |
| `float32` | IEEE 754 single-precision float |
| `float64` | IEEE 754 double-precision float |

---

## Column Width

The **Cols** selector in the toolbar controls how many bytes per row are shown.

| Value | Best for |
|-------|----------|
| 8 | Narrow window, 8-byte aligned structures |
| **16** (default) | General use |
| 32 | Wide monitors, dense data |

---

## Keyboard Reference

| Shortcut | Action |
|----------|--------|
| `Ctrl+O` | Open file |
| `Ctrl+S` | Save |
| `Ctrl+Z` | Undo |
| `Ctrl+Y` | Redo |
| `Ctrl+A` | Select all |
| `Ctrl+C` | Copy selection as hex |
| `Ctrl+V` | Paste hex |
| `Ctrl+F` | Focus Find bar |
| `Ctrl+G` | Go to offset |
| `Ctrl+B` | Add bookmark at cursor |
| `F2` | Next bookmark |
| `Shift+F2` | Previous bookmark |
| `F3` | Next search result |
| `Shift+F3` | Previous search result |
| `Insert` | Toggle Insert / Overwrite |
| `Escape` | Close window |
| `Tab` | Switch Hex ↔ ASCII panel |

---

## Recent Files

Click the **▾** arrow on the **📂 Open** button to see the 10 most recently opened files.
The list is persisted to `user://vg_hex_recent.txt` between sessions.
