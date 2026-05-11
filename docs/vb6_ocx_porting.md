# VB6 OCX (ActiveX) Porting Guide

VB6 projects often pull in MSComctlLib and other ActiveX OCX controls
(`MSCOMCTL.OCX`, `MSCHRT20.OCX`, `MSFLXGRD.OCX`, `RICHTX32.OCX`, …).
None of these have a 1:1 Godot equivalent. The importer maps the **visual
shell** to the closest built-in Godot control (e.g. `MSComctlLib.TreeView`
→ `Tree`) and tags every **runtime API call** with a structured comment so
you can find them by grep:

```
' [VB6 OCX TreeView] tv.Nodes.Add , , "k", "Hello"  ' TODO: ...
' [VB6 OCX ListView] lv.ListItems.Add , , "Row 1"   ' TODO: ...
' [VB6 OCX StatusBar] sb.Panels(1).Text = "Ready"   ' TODO: ...
```

Find every call site:

```bash
grep -rn '\[VB6 OCX' your_project/
```

## TreeView → `Tree`

VB6:
```vb
tv.Nodes.Add , , "root", "Root"
tv.Nodes.Add "root", tvwChild, "leaf", "Hello"
```

Godot:
```gdscript
var root = tv.create_item()
root.set_text(0, "Root")
var leaf = tv.create_item(root)
leaf.set_text(0, "Hello")
```

Notable mismatches:
- VB6 keys (`"root"`, `"leaf"`) → store with `set_metadata(0, "root")`.
- `Nodes.Item("key")` → walk children comparing `get_metadata(0)`.
- `NodeClick(Node)` event → connect to `Tree.item_selected` and read
  `get_selected()`.
- ImageList icon keys → load `Texture2D` and `set_icon(0, tex)` per item.

## ListView → `Tree` (multi-column mode)

VB6:
```vb
lv.ColumnHeaders.Add , , "Name"
lv.ListItems.Add , , "Alice"
lv.ListItems(1).SubItems(1) = "30"
```

Godot:
```gdscript
tree.columns = 2
tree.set_column_title(0, "Name")
tree.set_column_title(1, "Age")
var row = tree.create_item()
row.set_text(0, "Alice")
row.set_text(1, "30")
```

`Tree` works as a flat multi-column list when given a single hidden root
(set `hide_root = true`).

## StatusBar → `HBoxContainer` of `Label`s

VB6:
```vb
sb.Panels(1).Text = "Ready"
sb.Panels(2).Text = "Line " & lineNo
```

Godot:
- Replace the imported `Panel` with an `HBoxContainer` containing as many
  `Label`s as you had panels.
- Assignments become `panel_label.text = ...`.

## Toolbar / CoolBar → `HBoxContainer` of `Button`s

The importer maps `MSComctlLib.Toolbar` to `HBoxContainer`; you populate
it with `Button` children. `ButtonClick(Button)` event becomes a
per-button `pressed` signal.

## ImageList → resource lookup

`ImageList` is a glorified `Dictionary<String, Bitmap>`. Replace with:

```gdscript
const IMAGES = {
    "ok": preload("res://icons/ok.png"),
    "cancel": preload("res://icons/cancel.png"),
}
```

## RichTextBox → `RichTextLabel` (read-only) or `TextEdit`

`RICHTX32.OCX`'s `.RTF` property has no parser in Godot. Either:
- Convert RTF to BBCode at import time (manual), or
- Strip RTF and use plain `text` on a `TextEdit`.

## MSChart / MSFlexGrid

No direct port. Options:
- Use a Godot charting addon (`gd-chart`, `EasyCharts`).
- For tabular data, `Tree` in multi-column mode is the closest match.

## What the importer does NOT translate

- COM `PropertyBag.ReadProperty`/`WriteProperty` calls inside `.ctl` files —
  these need to become plain field assignments.
- Ambient/extender properties (`Extender.Name`, `Ambient.UserMode`).
- `MSComm32.OCX` serial port — use Godot's `StreamPeer`/`StreamPeerTCP`.

If you find a recurring pattern that ought to be auto-translated, file an
issue with the source snippet and the desired Godot equivalent.
