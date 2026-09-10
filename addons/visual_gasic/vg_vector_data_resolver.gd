@tool
extends RefCounted
## Locates labeled *Vector Data blocks in .vg source for the inline vector editor.

const MAX_VIEW := 1024
const MAX_SHAPES := 32
const MAX_POLY_POINTS := 32

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


static func is_vector_label(label_name: String) -> bool:
	return label_name.to_lower().ends_with("vector")


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
	if not is_vector_label(label_name):
		return {}

	var header := _parse_header(lines, label_line + 1)
	if header.is_empty():
		return {}
	var body := _collect_shape_lines(lines, header["header_line"] + 1)
	if body.is_empty():
		return {}
	if caret_line < label_line or caret_line > body["end_line"]:
		return {}

	return {
		"label": label_name,
		"view_w": header["view_w"],
		"view_h": header["view_h"],
		"grid_step": header["grid_step"],
		"label_line": label_line,
		"header_line": header["header_line"],
		"data_start_line": body["data_start_line"],
		"data_end_line": body["data_end_line"],
		"shapes": body["shapes"],
		"shape_line_indices": body["shape_line_indices"],
	}


static func enumerate_blocks(source: String) -> Array:
	var lines := source.split("\n")
	var out: Array = []
	var i := 0
	while i < lines.size():
		var m := _label_rx().search(lines[i])
		if m != null and is_vector_label(m.get_string(1)):
			var label_line := i
			var header := _parse_header(lines, label_line + 1)
			if not header.is_empty():
				var body := _collect_shape_lines(lines, header["header_line"] + 1)
				if not body.is_empty():
					out.append({
						"label": m.get_string(1),
						"label_line": label_line,
						"header_line": header["header_line"],
						"end_line": body["end_line"],
					})
					i = body["end_line"] + 1
					continue
		i += 1
	return out


static func format_header_line(view_w: int, view_h: int, grid_step: int) -> String:
	return "Data %d, %d, %d" % [view_w, view_h, grid_step]


static func format_shape_line(shape: Dictionary) -> String:
	var typ: String = str(shape.get("type", "LINE")).to_upper()
	var pts: PackedVector2Array = shape.get("points", PackedVector2Array())
	var parts: PackedStringArray = PackedStringArray()
	parts.append(typ)
	if typ == "POLYLINE":
		parts.append(str(pts.size()))
	for p in pts:
		parts.append(_num_str(p.x))
		parts.append(_num_str(p.y))
	parts.append(str(int(shape.get("stroke_r", 255))))
	parts.append(str(int(shape.get("stroke_g", 255))))
	parts.append(str(int(shape.get("stroke_b", 255))))
	parts.append(str(int(shape.get("stroke_a", 255))))
	parts.append(_num_str(float(shape.get("stroke_w", 1.0))))
	return "Data " + ", ".join(parts)


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
		var nums := _parse_number_list(dm.get_string(1))
		if nums.size() < 3:
			return {}
		var vw := int(nums[0])
		var vh := int(nums[1])
		if vw < 1 or vh < 1 or vw > MAX_VIEW or vh > MAX_VIEW:
			return {}
		return {
			"view_w": vw,
			"view_h": vh,
			"grid_step": maxi(0, int(nums[2])),
			"header_line": i,
		}
	return {}


static func _collect_shape_lines(lines: PackedStringArray, start: int) -> Dictionary:
	var shapes: Array = []
	var shape_line_indices: Array = []
	var data_start := -1
	var data_end := -1
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
		var shape := _parse_shape_tokens(_split_csv(dm.get_string(1)))
		if shape.is_empty():
			break
		if data_start < 0:
			data_start = i
		shapes.append(shape)
		shape_line_indices.append(i)
		data_end = i
		if shapes.size() >= MAX_SHAPES:
			break
	if shapes.is_empty() or data_start < 0:
		return {}
	return {
		"shapes": shapes,
		"shape_line_indices": shape_line_indices,
		"data_start_line": data_start,
		"data_end_line": data_end,
		"end_line": data_end,
	}


static func _parse_shape_tokens(tokens: PackedStringArray) -> Dictionary:
	if tokens.is_empty():
		return {}
	var typ := tokens[0].strip_edges().to_upper()
	if typ in ["LINE", "RECT"]:
		# TYPE + x1,y1,x2,y2 + r,g,b,a + width — see format_shape_line().
		if tokens.size() < 10:
			return {}
		var pts := PackedVector2Array([
			Vector2(float(tokens[1]), float(tokens[2])),
			Vector2(float(tokens[3]), float(tokens[4])),
		])
		return _make_shape(typ, pts, tokens, 5)
	if typ == "POLYLINE":
		if tokens.size() < 8:
			return {}
		var n := int(tokens[1])
		if n < 2 or n > MAX_POLY_POINTS:
			return {}
		var need := 2 + n * 2 + 5
		if tokens.size() < need:
			return {}
		var pts := PackedVector2Array()
		var ti := 2
		for _i in n:
			pts.append(Vector2(float(tokens[ti]), float(tokens[ti + 1])))
			ti += 2
		return _make_shape(typ, pts, tokens, ti)
	return {}


static func _make_shape(typ: String, pts: PackedVector2Array, tokens: PackedStringArray, color_start: int) -> Dictionary:
	if color_start + 4 >= tokens.size():
		return {}
	return {
		"type": typ,
		"points": pts,
		"stroke_r": int(float(tokens[color_start])),
		"stroke_g": int(float(tokens[color_start + 1])),
		"stroke_b": int(float(tokens[color_start + 2])),
		"stroke_a": int(float(tokens[color_start + 3])),
		"stroke_w": float(tokens[color_start + 4]),
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


static func _split_csv(part: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for chunk in part.split(","):
		var s := chunk.strip_edges()
		if not s.is_empty():
			out.append(s)
	return out


static func _parse_number_list(part: String) -> Array:
	var out: Array = []
	for chunk in part.split(","):
		var s := chunk.strip_edges()
		if s.is_empty():
			continue
		if not _is_number_token(s):
			return []
		out.append(float(s) if s.contains(".") else int(s))
	return out


static func _is_number_token(s: String) -> bool:
	if s.is_valid_int():
		return true
	if s.is_valid_float():
		return true
	return false


static func _num_str(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return str(v)
