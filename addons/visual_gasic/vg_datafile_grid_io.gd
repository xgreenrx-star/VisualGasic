@tool
extends RefCounted
## Load/save numeric tile grids for DataFile CSV and .vgd files.

const VgdWriter := preload("res://addons/visual_gasic/vg_vgd_writer.gd")

static var _vgd_magic: PackedByteArray = PackedByteArray([0x56, 0x47, 0x44, 0x01])


static func load_path(abs_path: String) -> Dictionary:
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		return {"ok": false, "error": "File not found"}
	var ext := abs_path.get_extension().to_lower()
	if ext == "vgd" or _is_vgd_file(abs_path):
		return load_vgd(abs_path)
	return load_csv(abs_path)


static func save_csv(abs_path: String, width: int, height: int, cells: PackedByteArray) -> bool:
	var dir_path := abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(csv_text_from_cells(width, height, cells))
	f.close()
	return true


static func save_vgd_u8(abs_path: String, width: int, height: int, cells: PackedByteArray) -> bool:
	return VgdWriter.write_grid_u8(abs_path, width, height, cells)


static func load_csv(abs_path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_bytes(abs_path)
	if raw.is_empty():
		return {"ok": false, "error": "Empty file", "width": 0, "height": 0, "cells": PackedByteArray(), "format": "csv"}
	if is_vgd_bytes(raw):
		return load_vgd(abs_path)
	if _bytes_contain_nul(raw):
		return {"ok": false, "error": "Binary file — use .vgd or a text CSV", "width": 0, "height": 0, "cells": PackedByteArray(), "format": "csv"}
	return parse_csv_text(raw.get_string_from_utf8())


static func parse_csv_text(txt: String) -> Dictionary:
	var out := {"ok": false, "error": "", "width": 0, "height": 0, "cells": PackedByteArray(), "format": "csv"}
	var rows := txt.strip_edges().split("\n")
	var grid_rows: Array = []
	for row in rows:
		if str(row).strip_edges().is_empty():
			continue
		grid_rows.append(str(row))
	if grid_rows.is_empty():
		out["error"] = "Empty CSV"
		return out
	var grid_w := 0
	var values: Array = []
	for row in grid_rows:
		var parts := str(row).split(",")
		grid_w = maxi(grid_w, parts.size())
		for p in parts:
			var s := str(p).strip_edges()
			values.append(int(s) if s.is_valid_int() else 0)
	var grid_h := grid_rows.size()
	var cells := PackedByteArray()
	cells.resize(grid_w * grid_h)
	for i in mini(values.size(), cells.size()):
		cells[i] = int(values[i]) & 0xFF
	out["ok"] = true
	out["width"] = grid_w
	out["height"] = grid_h
	out["cells"] = cells
	return out


static func csv_text_from_cells(width: int, height: int, cells: PackedByteArray) -> String:
	var lines: PackedStringArray = []
	for y in height:
		var parts: PackedStringArray = []
		for x in width:
			var idx := y * width + x
			var v := int(cells[idx]) if idx < cells.size() else 0
			parts.append(str(v))
		lines.append(",".join(parts))
	return "\n".join(lines) + "\n"


## Copy existing cells into a larger/smaller grid; pad with fill or crop bottom-right.
static func resize_cells(
	cells: PackedByteArray,
	old_w: int,
	old_h: int,
	new_w: int,
	new_h: int,
	fill: int = 0
) -> PackedByteArray:
	new_w = maxi(1, new_w)
	new_h = maxi(1, new_h)
	old_w = maxi(1, old_w)
	old_h = maxi(1, old_h)
	var out := PackedByteArray()
	out.resize(new_w * new_h)
	for i in out.size():
		out[i] = fill & 0xFF
	for y in mini(old_h, new_h):
		for x in mini(old_w, new_w):
			var src := y * old_w + x
			var dst := y * new_w + x
			if src < cells.size() and dst < out.size():
				out[dst] = cells[src]
	return out


static func load_vgd(abs_path: String) -> Dictionary:
	var out := {"ok": false, "error": "", "width": 0, "height": 0, "cells": PackedByteArray(), "format": "vgd", "elem_size": 1}
	var raw := FileAccess.get_file_as_bytes(abs_path)
	if raw.size() < 32 or raw.slice(0, 4) != _vgd_magic:
		out["error"] = "Not a .vgd file"
		return out
	var w := _u32(raw, 8)
	var h := _u32(raw, 12)
	var elem := int(raw[16])
	if elem <= 0:
		elem = 1
	var payload_len := _u32(raw, 24)
	if w <= 0 or h <= 0:
		out["error"] = "Invalid grid dimensions"
		return out
	if raw.size() < 32 + payload_len:
		out["error"] = "Truncated .vgd payload"
		return out
	var payload := raw.slice(32, 32 + payload_len)
	var cells := PackedByteArray()
	cells.resize(w * h)
	for i in w * h:
		var off := i * elem
		if off >= payload.size():
			break
		var v := int(payload[off])
		if elem >= 2 and off + 1 < payload.size():
			v = int(payload[off]) | (int(payload[off + 1]) << 8)
		cells[i] = v & 0xFF
	out["ok"] = true
	out["width"] = w
	out["height"] = h
	out["cells"] = cells
	out["elem_size"] = elem
	return out


static func is_vgd_bytes(raw: PackedByteArray) -> bool:
	return raw.size() >= 4 and raw.slice(0, 4) == _vgd_magic


static func read_text_file(abs_path: String) -> String:
	var raw := FileAccess.get_file_as_bytes(abs_path)
	if raw.is_empty() or is_vgd_bytes(raw) or _bytes_contain_nul(raw):
		return ""
	return raw.get_string_from_utf8()


static func _bytes_contain_nul(raw: PackedByteArray) -> bool:
	for b in raw:
		if b == 0:
			return true
	return false


static func _is_vgd_file(abs_path: String) -> bool:
	var head := FileAccess.get_file_as_bytes(abs_path)
	return is_vgd_bytes(head)


static func _u32(b: PackedByteArray, off: int) -> int:
	if off + 4 > b.size():
		return 0
	return b[off] | (b[off + 1] << 8) | (b[off + 2] << 16) | (b[off + 3] << 24)
