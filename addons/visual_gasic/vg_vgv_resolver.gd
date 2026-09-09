@tool
extends RefCounted
## Read/write single-frame .VGV vector files (VGVector demo format, frame 0 only).

const HEADER := "VGV1"


static func load_file(abs_path: String) -> Dictionary:
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		return {}
	return parse_text(FileAccess.get_file_as_string(abs_path))


static func save_file(abs_path: String, model: Dictionary) -> bool:
	if abs_path.is_empty() or model.is_empty():
		return false
	var text := serialize(model)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	return true


static func parse_text(text: String) -> Dictionary:
	var lines := text.split("\n")
	if lines.is_empty() or lines[0].strip_edges() != HEADER:
		return {}
	if lines.size() < 5:
		return {}
	var dim := _parse_nums(lines[1])
	if dim.size() < 2:
		return {}
	var view_w := int(dim[0])
	var view_h := int(dim[1])
	var shapes: Array = []
	var i := 0
	while i < lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("SHAPE "):
			var parsed := _parse_shape_line(line)
			if parsed.is_empty():
				i += 1
				continue
			if i + 1 < lines.size():
				var next := lines[i + 1].strip_edges()
				if next.begins_with("POINTS "):
					var pts := _parse_points_line(next)
					if not pts.is_empty():
						parsed["points"] = pts
					i += 1
			shapes.append(parsed)
		i += 1
	if shapes.is_empty():
		return {}
	return {
		"view_w": view_w,
		"view_h": view_h,
		"grid_step": 8,
		"shapes": shapes,
		"path": "",
	}


static func serialize(model: Dictionary) -> String:
	var view_w: int = int(model.get("view_w", 320))
	var view_h: int = int(model.get("view_h", 240))
	var shapes: Array = model.get("shapes", [])
	var out: PackedStringArray = PackedStringArray()
	out.append(HEADER)
	out.append("%d,%d" % [view_w, view_h])
	out.append("1,12")
	out.append("FRAMES")
	out.append("FRAME 0")
	for shape in shapes:
		var lines := _shape_to_vgv_lines(shape)
		for ln in lines:
			if not ln.is_empty():
				out.append(ln)
	out.append("ENDFRAME")
	out.append("ENDVGV")
	return "\n".join(out) + "\n"


static func _parse_shape_line(line: String) -> Dictionary:
	var body := line.substr(6).strip_edges()
	var tokens := _split_csv(body)
	if tokens.is_empty():
		return {}
	var typ := tokens[0].to_upper()
	if typ in ["LINE", "RECT", "ELLIPSE"] and tokens.size() >= 14:
		return {
			"type": typ,
			"points": PackedVector2Array([
				Vector2(float(tokens[1]), float(tokens[2])),
				Vector2(float(tokens[3]), float(tokens[4])),
			]),
			"stroke_r": int(float(tokens[5])),
			"stroke_g": int(float(tokens[6])),
			"stroke_b": int(float(tokens[7])),
			"stroke_a": int(float(tokens[8])),
			"stroke_w": float(tokens[9]),
		}
	if typ in ["POLYLINE", "POLYGON"] and tokens.size() >= 14:
		var pts := PackedVector2Array([
			Vector2(float(tokens[1]), float(tokens[2])),
			Vector2(float(tokens[3]), float(tokens[4])),
		])
		return {
			"type": typ,
			"points": pts,
			"stroke_r": int(float(tokens[5])),
			"stroke_g": int(float(tokens[6])),
			"stroke_b": int(float(tokens[7])),
			"stroke_a": int(float(tokens[8])),
			"stroke_w": float(tokens[9]),
		}
	return {}


static func _parse_points_line(line: String) -> PackedVector2Array:
	var body := line.substr(7).strip_edges()
	var tokens := _split_csv(body)
	if tokens.is_empty():
		return PackedVector2Array()
	var n := int(tokens[0])
	if n < 2 or tokens.size() < 1 + n * 2:
		return PackedVector2Array()
	var pts := PackedVector2Array()
	var ti := 1
	for _j in n:
		pts.append(Vector2(float(tokens[ti]), float(tokens[ti + 1])))
		ti += 2
	return pts


static func _shape_to_vgv_lines(shape: Dictionary) -> PackedStringArray:
	var typ: String = str(shape.get("type", "LINE")).to_upper()
	var pts: PackedVector2Array = shape.get("points", PackedVector2Array())
	var r := int(shape.get("stroke_r", 255))
	var g := int(shape.get("stroke_g", 255))
	var b := int(shape.get("stroke_b", 255))
	var a := int(shape.get("stroke_a", 255))
	var w := float(shape.get("stroke_w", 1.0))
	var out: PackedStringArray = PackedStringArray()
	if pts.size() < 2:
		return out
	var x1 := pts[0].x
	var y1 := pts[0].y
	var x2 := pts[pts.size() - 1].x
	var y2 := pts[pts.size() - 1].y
	if typ in ["LINE", "RECT", "ELLIPSE"]:
		x2 = pts[1].x
		y2 = pts[1].y
	out.append(
		"SHAPE %s,%.4f,%.4f,%.4f,%.4f,%d,%d,%d,%d,%.4f,0,0,0,0"
		% [typ, x1, y1, x2, y2, r, g, b, a, w]
	)
	if typ in ["POLYLINE", "POLYGON"] and pts.size() >= 2:
		var parts: PackedStringArray = PackedStringArray(["POINTS", str(pts.size())])
		for p in pts:
			parts.append("%.4f" % p.x)
			parts.append("%.4f" % p.y)
		out.append(", ".join(parts))
	return out


static func _parse_nums(line: String) -> Array:
	var out: Array = []
	for chunk in line.split(","):
		var s := chunk.strip_edges()
		if s.is_valid_float() or s.is_valid_int():
			out.append(float(s) if s.contains(".") else int(s))
	return out


static func _split_csv(part: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for chunk in part.split(","):
		var s := chunk.strip_edges()
		if not s.is_empty():
			out.append(s)
	return out
