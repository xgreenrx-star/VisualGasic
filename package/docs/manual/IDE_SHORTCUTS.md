# VisualGasic IDE Keyboard Shortcuts & Features

A quick-reference card for every keyboard shortcut and IDE convenience feature in the Visual Gasic IDE, Properties panel, and Code Editor.

---

## Visual Gasic IDE Canvas

| Shortcut | Action |
|----------|--------|
| **Click control** | Select control |
| **Ctrl+A** | Select All controls |
| **Delete** | Delete selected control(s) |
| **Ctrl+C / Ctrl+V** | Copy / Paste control(s) |
| **Ctrl+Z / Ctrl+Y** | Undo / Redo (with status-bar feedback) |
| **Arrow keys** | Move selected control by grid size |
| **Ctrl+Arrow** | **Nudge** selected control by 1 pixel |
| **Shift+Ctrl+Arrow** | Nudge by grid size (fine + coarse) |
| **Ctrl+Scroll** | **Zoom** canvas in/out (10% steps, 25%–400%) |
| **Double-click control** | Jump to event handler code |
| **Right-click control** | Context menu (Cut, Copy, Delete, Bring to Front, Send to Back, Lock Position) |
| **Drag control edge** | Resize control |
| **Drag form edge handles** | **Resize the form** (8 handles: corners + edges) |

### Status Bar

The bottom status bar shows real-time information:

```
  Form1 *  |  600 x 400  |  Grid: 8 px  |  Zoom: 100%
```

| Element | Meaning |
|---------|---------|
| `Form1` | Current form name |
| `*` | **Dirty indicator** — unsaved changes exist |
| `600 x 400` | Form dimensions (updates during resize) |
| `Grid: 8 px` | Current snap grid size |
| `Zoom: 100%` | Current canvas zoom level |

---

## Menus

### File Menu

| Menu Item | Shortcut | Action |
|-----------|----------|--------|
| New Form | — | Create a form from templates |
| Open Form | Ctrl+O | Open an existing .tscn form |
| Save Form | Ctrl+S | Save current form |
| **Save All** | **Ctrl+Shift+S** | Save form + code editor together |

### Edit Menu

| Menu Item | Shortcut | Action |
|-----------|----------|--------|
| Undo | Ctrl+Z | Undo last change (flashes "Undo" in status bar) |
| Redo | Ctrl+Y | Redo last undone change (flashes "Redo") |
| Cut | Ctrl+X | Cut selected control(s) |
| Copy | Ctrl+C | Copy selected control(s) |
| Paste | Ctrl+V | Paste control(s) |
| Delete | Delete | Remove selected control(s) |
| Select All | Ctrl+A | Select all controls on form |
| **Find…** | **Ctrl+F** | Open Find dialog in code editor |
| **Replace…** | **Ctrl+H** | Open Find & Replace dialog in code editor |
| **Comment Block** | **Ctrl+'** | Comment selected lines with `'` prefix |
| **Uncomment Block** | **Ctrl+Shift+'** | Remove `'` comment prefix from selected lines |
| **Indent** | **Ctrl+]** | Indent selected lines one tab stop |
| **Outdent** | **Ctrl+[** | Outdent selected lines one tab stop |
| **Bookmarks →** | | Submenu for bookmark navigation |
| &nbsp;&nbsp;Toggle Bookmark | Ctrl+F2 | Toggle a bookmark on the current line |
| &nbsp;&nbsp;Next Bookmark | F2 | Jump to the next bookmark |
| &nbsp;&nbsp;Previous Bookmark | Shift+F2 | Jump to the previous bookmark |
| &nbsp;&nbsp;Clear All Bookmarks | — | Remove all bookmarks |

### Format Menu

| Menu Item | Action |
|-----------|--------|
| Align Lefts / Rights | Align selected controls horizontally |
| Align Tops / Bottoms | Align selected controls vertically |
| Center Horizontally / Vertically | Center selected controls relative to each other |
| Make Same Width / Height / Both | Match dimensions |
| **Space Equally Horizontal** | Distribute 3+ controls with even horizontal spacing |
| **Space Equally Vertical** | Distribute 3+ controls with even vertical spacing |
| **Size to Grid** | Snap selected control positions and sizes to the grid |
| **Center in Form Horizontal** | Center selected controls horizontally within the form |
| **Center in Form Vertical** | Center selected controls vertically within the form |
| **Bring to Front** | Move selected control to top of Z-order |
| **Send to Back** | Move selected control to bottom of Z-order |
| **Lock Controls** | Prevent accidental moves on locked controls |

### Context Menu (Right-Click)

| Menu Item | Action |
|-----------|--------|
| Cut / Copy / Paste / Delete | Standard clipboard operations |
| **Bring to Front** | Z-order: move to top |
| **Send to Back** | Z-order: move to bottom |
| **Lock Position** ✓ | Toggle position lock (check mark when active) |

---

## Debug Menu

| Menu Item | Shortcut | Action |
|-----------|----------|--------|
| **Start** | — | Run main scene with debugger |
| **Start Current** | — | Run current scene with debugger |
| **Break** | **Pause** | Pause execution at next statement |
| **Stop** | — | Stop the running scene |

### Debug Toolbar (Immediate Window)

| Button | Shortcut | Action |
|--------|----------|--------|
| **▶ Continue** | F5 | Resume execution |
| **⏸ Break** | Pause | Pause at next statement |
| **⏩ Step Over** | F10 | Execute line, skip into calls |
| **⬇ Step Into** | F11 | Execute line, enter calls |
| **⬆ Step Out** | Shift+F11 | Run until current procedure returns |
| **■ Stop** | — | End the program |
| **Yellow arrow drag** | — | Set Next Statement (move execution point) |

For full debugging documentation, see [Debugging Guide](debugging.md).

---

## Properties Panel

### Filter & Search

Type in the **🔍 Filter** box at the top of the Properties panel to instantly filter properties by name. Clear the box to show all properties again.

### Tooltips

Hover over any property **label** to see a tooltip description explaining what the property does. No need to memorize — the descriptions are always a hover away.

### Zebra Striping

Alternating rows use a subtle warm background tint for easier visual scanning across wide property grids.

### View Modes

| Tab | Description |
|-----|-------------|
| **Alphabetic** | All properties sorted A–Z (no section headers) |
| **Categorized** | Properties grouped by category (Appearance, Behavior, Font, Position, etc.) |

### Numeric Fields

| Shortcut | Action |
|----------|--------|
| **Up / Down** | Increment / decrement by 1 |
| **Shift+Up / Shift+Down** | Increment / decrement by 10 (or 100 for Interval) |

### Color Properties

Click any color swatch to open a full **ColorPicker** dialog with alpha channel support.

---

## Code Editor

| Shortcut | Action |
|----------|--------|
| **Ctrl+G** | **Go To Line** — opens a dialog to jump to any line number |
| **Ctrl+Space** | IntelliSense autocomplete |
| **Ctrl+Click** / **F12** | Go to Definition |
| **Ctrl+R** | Rename refactoring (scope-aware) |
| **F9** | **Toggle Breakpoint** on current line |
| **Ctrl+Shift+F9** | **Conditional Breakpoint** — set/edit a condition expression |
| **Type `(`** | Parameter hint for built-in functions |
| **Type `}`** | Smart bracket completion (closes blocks) |

### Automatic Features

| Feature | Description |
|---------|-------------|
| **Procedure Separator Lines** | A horizontal rule is drawn above each `Sub` / `Function` / `Property` header — the classic VB6 blue separator line |
| **Parameter Info Popup** | When typing inside function call parentheses, a tooltip shows the function signature with the current parameter highlighted |
| **Pretty Listing** | On save, keywords are auto-capitalized, operators are spaced, and indentation is normalized (VB6-style auto-format) |

### Go To Line Dialog

Press **Ctrl+G** to open a small popup showing the valid line range (1–*N*). Type a line number and press Enter or click **Go** to jump there. The caret moves to the target line and the editor scrolls to center it.

---

## Visual Gasic IDE Workflow Tips

1. **Resize the form first** — drag the small black squares on the form edges before placing controls.
2. **Use the grid** — snap-to-grid keeps controls aligned without pixel-counting.
3. **Nudge for precision** — after snapping, use **Ctrl+Arrow** to adjust by exactly 1 pixel.
4. **Lock finished controls** — right-click → Lock Position to prevent accidental moves.
5. **Filter properties** — with 20+ properties per control, the 🔍 filter saves scrolling.
6. **Shift+Arrow for numbers** — in numeric property fields, Shift+Up/Down jumps by 10.
7. **Save All often** — **Ctrl+Shift+S** saves both the form layout and the code file.
8. **Watch the status bar** — the `*` dirty indicator tells you when there are unsaved changes.
9. **Z-order matters** — use Bring to Front / Send to Back when controls overlap.
10. **Zoom in for detail** — **Ctrl+Scroll** to zoom the canvas up to 400%.
