@tool
extends RefCounted
## Locates labeled *Sprite Data blocks in .vg source for the inline editor.

const MAX_INLINE_W := 32
const MAX_INLINE_H := 32

static var _label_re: RegEx
static var _data_re: RegEx


static func _label_rx() -> RegEx:
	if _label_re == null:
		_label_re = RegEx.new()
		_label_re.compile("^\\s*([A-Za-z_]\\w*)\\s*:\\s*(?:'.*)?$")
	return _label_re


static func _data_rx() -> RegEx:
	if _data_re == null:
		_data_re = RegEx.new()
		_data_re.compile("^\\s*Data\\s+(.+)$")
	return _data_re


static func is_sprite_label(label_name: String) -> bool:
	return label_name.to_lower().ends_with("sprite")


static func resolve_at_line(source: String, caret_line: int) -> Dictionary:
	if source.is_empty() or caret_line < 0:
		return {}
	var lines := source.split("\n")
	if caret_line >= lines.size():
		return {}
	var label_line := _find_enclosing_label_line(lines, caret_line)
	if label_line < 0:
		return {}
	var label_m := _label_rx().search(lines[label_line])
	if label_m == null:
		return {}
	var label_name: String = label_m.get_string(1)
	if not is_sprite_label(label_name):
		return {}

	var header := _parse_header(lines, label_line + 1)
	if header.is_empty():
		return {}
	var w: int = header["w"]
	var h: int = header["h"]
	if w < 1 or h < 1 or w > MAX_INLINE_W or h > MAX_INLINE_H:
		return {}

	var grid := _collect_grid_lines(lines, header["header_line"] + 1, h, w)
	if grid.is_empty():
		return {}

	var end_line: int = grid["end_line"]
	if caret_line < label_line or caret_line > end_line:
		return {}

	return {
		"label": label_name,
		"w": w,
		"h": h,
		"transparent": header["transparent"],
		"palette_id": header["palette_id"],
		"label_line": label_line,
		"header_line": header["header_line"],
		"data_start_line": grid["data_start_line"],
		"data_end_line": grid["data_end_line"],
		"pixels": grid["pixels"],
	}


## All valid labeled *Sprite blocks in source (for editor background tint).
static func enumerate_blocks(source: String) -> Array:
	var lines := source.split("\n")
	var out: Array = []
	var i := 0
	while i < lines.size():
		var m := _label_rx().search(lines[i])
		if m != null and is_sprite_label(m.get_string(1)):
			var label_line := i
			var header := _parse_header(lines, label_line + 1)
			if not header.is_empty():
				var w: int = header["w"]
				var h: int = header["h"]
				if w >= 1 and h >= 1 and w <= MAX_INLINE_W and h <= MAX_INLINE_H:
					var grid := _collect_grid_lines(lines, header["header_line"] + 1, h, w)
					if not grid.is_empty():
						out.append({
							"label": m.get_string(1),
							"label_line": label_line,
							"header_line": header["header_line"],
							"end_line": grid["end_line"],
						})
						i = grid["end_line"] + 1
						continue
		i += 1
	return out


static func _find_enclosing_label_line(lines: PackedStringArray, caret_line: int) -> int:
	for i in range(caret_line, -1, -1):
		var m := _label_rx().search(lines[i])
		if m != null:
			return i
	return -1


static func _parse_header(lines: PackedStringArray, start: int) -> Dictionary:
	for i in range(start, lines.size()):
		var line := lines[i].strip_edges()
		if line.is_empty() or line.begins_with("'"):
			continue
		if _is_block_boundary(line):
			return {}
		var dm := _data_rx().search(lines[i])
		if dm == null:
			return {}
		var nums := _parse_int_list(dm.get_string(1))
		if nums.size() < 4:
			return {}
		return {
			"w": nums[0],
			"h": nums[1],
			"transparent": nums[2],
			"palette_id": nums[3],
			"header_line": i,
		}
	return {}


static func _collect_grid_lines(lines: PackedStringArray, start: int, h: int, w: int) -> Dictionary:
	var pixels: PackedInt32Array = PackedInt32Array()
	pixels.resize(w * h)
	var data_start := -1
	var data_end := -1
	var row := 0
	for i in range(start, lines.size()):
		var raw := lines[i]
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("'"):
			continue
		if _is_block_boundary(line):
			break
		var dm := _data_rx().search(raw)
		if dm == null:
			break
		if data_start < 0:
			data_start = i
		var nums := _parse_int_list(dm.get_string(1))
		if nums.is_empty():
			break
		for c in nums.size():
			if row >= h:
				break
			var col := c
			if col >= w:
				break
			pixels[row * w + col] = nums[c]
		data_end = i
		row += 1
		if row >= h:
			break
	if row < h or data_start < 0:
		return {}
	return {
		"pixels": pixels,
		"data_start_line": data_start,
		"data_end_line": data_end,
		"end_line": data_end,
	}


static func _is_block_boundary(line: String) -> bool:
	if _label_rx().search(line) != null:
		return true
	var low := line.to_lower()
	if low.begins_with("sub ") or low.begins_with("function ") or low.begins_with("end sub"):
		return true
	if low.begins_with("property ") or low.begins_with("class "):
		return true
	return false


static func _parse_int_list(part: String) -> Array:
	var out: Array = []
	for chunk in part.split(","):
		var s := chunk.strip_edges()
		if s.is_empty():
			continue
		if not s.is_valid_int():
			return []
		out.append(int(s))
	return out
