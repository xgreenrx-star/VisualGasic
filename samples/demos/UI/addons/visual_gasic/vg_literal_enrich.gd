@tool
extends RefCounted
## Bit masks, VB6 color, date, line context, and string constant hints for the Convert panel.

static var _qb_palette: Array[int] = [
	0, 8388608, 32768, 8421376, 128, 8388736, 32896, 8421504,
	12632256, 255, 65280, 65535, 16711935, 16711680, 16776960, 16777215,
]

static func _char_constants() -> Array:
	return [
		{"bytes": "\r\n", "name": "vbCrLf", "desc": "Carriage return + line feed"},
		{"bytes": "\r", "name": "vbCr", "desc": "Carriage return"},
		{"bytes": "\n", "name": "vbLf", "desc": "Line feed"},
		{"bytes": "\t", "name": "vbTab", "desc": "Tab"},
		{"bytes": String.chr(0), "name": "vbNullChar", "desc": "Null character"},
		{"bytes": "\b", "name": "vbBack", "desc": "Backspace"},
		{"bytes": "\f", "name": "vbFormFeed", "desc": "Form feed"},
		{"bytes": "\v", "name": "vbVerticalTab", "desc": "Vertical tab"},
	]


static func bit_rows(value: int) -> Array:
	var rows: Array = []
	var u32: int = value & 0xFFFFFFFF
	var pop := _popcount(u32)
	rows.append({"label": "Set bits", "text": str(pop), "radix_id": "bits", "is_current": false})
	if pop > 0 and pop <= 16:
		var names: PackedStringArray = []
		for b in 32:
			if u32 & (1 << b):
				names.append(str(b))
		rows.append({"label": "Bit indices", "text": ", ".join(names), "radix_id": "bitidx", "is_current": false})
	if u32 <= 0xFFFF:
		rows.append({"label": "High nibble", "text": "&H%X" % ((u32 >> 12) & 0xF), "radix_id": "nib_hi", "is_current": false})
		rows.append({"label": "Low nibble", "text": "&H%X" % (u32 & 0xF), "radix_id": "nib_lo", "is_current": false})
	if value < 0:
		rows.append({"label": "Int16", "text": str(value & 0xFFFF if (value & 0x8000) else value), "radix_id": "i16", "is_current": false})
	return rows


static func date_rows(body: String, source_text: String) -> Array:
	var rows: Array = []
	var quoted := "#%s#" % body
	rows.append({"label": "VB6 date", "text": quoted, "radix_id": "date", "is_current": true})
	rows.append({"label": "DateSerial", "text": _date_serial_call(body), "radix_id": "dateserial", "is_current": false})
	if body.contains(":"):
		rows.append({"label": "Time portion", "text": _time_part(body), "radix_id": "timepart", "is_current": false})
	else:
		rows.append({"label": "Date portion", "text": body, "radix_id": "datepart", "is_current": false})
	return rows


static func color_rows_from_hex(source_text: String, u32: int) -> Array:
	var rows: Array = []
	var imp_path := "res://addons/visual_gasic/vb6_importer.gd"
	var color := Color.WHITE
	if ResourceLoader.exists(imp_path):
		var imp = load(imp_path)
		if imp and imp.has_method("vb_color_to_godot"):
			color = imp.vb_color_to_godot(source_text)
	var r8 := int(round(color.r * 255.0))
	var g8 := int(round(color.g * 255.0))
	var b8 := int(round(color.b * 255.0))
	rows.append({"label": "VB6 BGR hex", "text": source_text, "radix_id": "color_hex", "is_current": true})
	rows.append({"label": "RGB 0–255", "text": "%d, %d, %d" % [r8, g8, b8], "radix_id": "color_rgb8", "is_current": false})
	rows.append({"label": "Color()", "text": "Color(%.3f, %.3f, %.3f)" % [color.r, color.g, color.b], "radix_id": "color_gd", "is_current": false})
	rows.append({"label": "Decimal BGR", "text": str(u32 & 0xFFFFFF), "radix_id": "color_dec", "is_current": false})
	rows.append({"label": "Preview", "text": "#%02X%02X%02X" % [r8, g8, b8], "radix_id": "color_preview", "is_current": false, "color": color})
	return rows


static func color_rows_from_rgb(r: float, g: float, b: float, source_text: String) -> Array:
	var rows: Array = []
	var r8 := int(round(clampf(r, 0.0, 1.0) * 255.0))
	var g8 := int(round(clampf(g, 0.0, 1.0) * 255.0))
	var b8 := int(round(clampf(b, 0.0, 1.0) * 255.0))
	var bgr := (b8 << 16) | (g8 << 8) | r8
	rows.append({"label": "Color()", "text": source_text, "radix_id": "color_gd", "is_current": true})
	rows.append({"label": "VB6 BGR", "text": "&H%06X" % bgr, "radix_id": "color_hex", "is_current": false})
	rows.append({"label": "RGB 0–255", "text": "%d, %d, %d" % [r8, g8, b8], "radix_id": "color_rgb8", "is_current": false})
	rows.append({"label": "Preview", "text": "#%02X%02X%02X" % [r8, g8, b8], "radix_id": "color_preview", "is_current": false, "color": Color(r, g, b)})
	return rows


static func color_rows_from_qb(index: int, source_text: String) -> Array:
	var rows: Array = []
	var idx := clampi(index, 0, 15)
	var dec := _qb_palette[idx]
	rows.append({"label": "QBColor", "text": source_text, "radix_id": "qbcolor", "is_current": true})
	rows.append({"label": "Palette index", "text": str(idx), "radix_id": "qbidx", "is_current": false})
	rows.append({"label": "Decimal BGR", "text": str(dec), "radix_id": "color_dec", "is_current": false})
	rows.append({"label": "VB6 BGR", "text": "&H%06X" % (dec & 0xFFFFFF), "radix_id": "color_hex", "is_current": false})
	if ResourceLoader.exists("res://addons/visual_gasic/vb6_importer.gd"):
		var imp = load("res://addons/visual_gasic/vb6_importer.gd")
		if imp:
			var c: Color = imp.vb_color_to_godot(str(dec))
			rows.append({"label": "Preview", "text": "#%02X%02X%02X" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)], "radix_id": "color_preview", "is_current": false, "color": c})
	return rows


static func chr_rows(code: int) -> Array:
	var rows: Array = []
	if code >= 32 and code <= 126:
		rows.append({"label": "Character", "text": "\"%s\"" % char(code), "radix_id": "char", "is_current": false})
	rows.append({"label": "Chr()", "text": "Chr(%d)" % code, "radix_id": "chr", "is_current": false})
	rows.append({"label": "Hex byte", "text": "&H%02X" % (code & 0xFF), "radix_id": "hexbyte", "is_current": false})
	for hint in _vb_char_hints_for_code(code):
		rows.append(hint)
	return rows


static func asc_rows(ch: String) -> Array:
	var code := ch.unicode_at(0) if not ch.is_empty() else 0
	var rows: Array = []
	rows.append({"label": "Asc()", "text": str(code), "radix_id": "asc", "is_current": false})
	rows.append({"label": "Chr()", "text": "Chr(%d)" % code, "radix_id": "chr", "is_current": false})
	rows.append({"label": "Hex byte", "text": "&H%02X" % (code & 0xFF), "radix_id": "hexbyte", "is_current": false})
	return rows


static func string_hint_rows(raw: String) -> Array:
	var rows: Array = []
	rows.append({"label": "String data", "text": raw, "radix_id": "stringdata", "is_current": true})
	var utf8 := raw.to_utf8_buffer()
	rows.append({"label": "Length", "text": str(raw.length()), "radix_id": "length", "is_current": false})
	rows.append({"label": "UTF-8 bytes", "text": str(utf8.size()), "radix_id": "bytes", "is_current": false})
	var hints := _vb_concat_hints(raw)
	for h in hints:
		rows.append(h)
	return rows


static func context_rows(line: String, column: int, value: float, kind: String) -> Array:
	var rows: Array = []
	var lower := line.to_lower()
	if kind in ["integer", "float"] and lower.contains("interval"):
		var ms := value
		rows.append({"label": "Timer (sec)", "text": "%.3f s" % (ms / 1000.0), "radix_id": "timer_s", "is_current": false})
		rows.append({"label": "Timer (ms)", "text": str(int(ms)), "radix_id": "timer_ms", "is_current": false})
	if kind in ["integer", "float"] and _line_has_angle_fn(lower):
		var deg := value
		var rad := deg * PI / 180.0
		if lower.contains("atn") or lower.contains("asin") or lower.contains("acos"):
			rad = deg
			deg = rad * 180.0 / PI
		rows.append({"label": "Degrees", "text": "%.4f" % deg, "radix_id": "deg", "is_current": false})
		rows.append({"label": "Radians", "text": "%.4f" % rad, "radix_id": "rad", "is_current": false})
	return rows


static func try_eval_expression(line: String, column: int) -> Dictionary:
	var expr := _expression_at_column(line, column)
	if expr.is_empty():
		return {}
	var val = _eval_simple_expr(expr.get("text", ""))
	if val == null:
		return {}
	return {
		"kind": "expression",
		"source_text": expr.get("text", ""),
		"start": int(expr.get("start", 0)),
		"end": int(expr.get("end", 0)),
		"value": val,
	}


static func expression_rows(text: String, val: Variant) -> Array:
	return [
		{"label": "Expression", "text": text, "radix_id": "expr", "is_current": true},
		{"label": "Result", "text": str(val), "radix_id": "result", "is_current": false},
	]


static func resolve_color_call(line: String, column: int) -> Dictionary:
	var col := clampi(column, 0, maxi(line.length() - 1, 0))
	for rx in [
		{"re": _rx("(?i)Color\\(\\s*([0-9.+-]+)\\s*,\\s*([0-9.+-]+)\\s*,\\s*([0-9.+-]+)\\s*\\)"), "kind": "color_rgb"},
		{"re": _rx("(?i)QBColor\\(\\s*([0-9]+)\\s*\\)"), "kind": "color_qb"},
	]:
		var m: RegExMatch = rx.re.search(line)
		while m != null:
			var s: int = m.get_start()
			var e: int = m.get_end()
			if col >= s and col < e:
				if rx.kind == "color_rgb":
					return {
						"kind": "color",
						"source_text": m.get_string(),
						"start": s, "end": e,
						"r": m.get_string(1).to_float(),
						"g": m.get_string(2).to_float(),
						"b": m.get_string(3).to_float(),
					}
				return {
					"kind": "color",
					"source_text": m.get_string(),
					"start": s, "end": e,
					"qb_index": m.get_string(1).to_int(),
				}
			m = rx.re.search(line, e)
	return {}


static func is_color_hex_literal(lit: Dictionary) -> bool:
	if lit.get("kind") != "integer":
		return false
	var src: String = str(lit.get("source_text", "")).to_upper()
	if not src.begins_with("&H"):
		return false
	var body := src.substr(2).trim_suffix("&").trim_suffix("%")
	return body.length() >= 4 or int(lit.get("value_i64", 0)) > 255


static func _vb_concat_hints(raw: String) -> Array:
	var rows: Array = []
	var i := 0
	while i < raw.length():
		var matched := false
		for entry in _char_constants():
			var b: String = entry.bytes
			if raw.substr(i, b.length()) == b:
				rows.append({
					"label": "Use instead",
					"text": ' & %s' % entry.name,
					"radix_id": "vbconst",
					"is_current": false,
					"hint": entry.desc,
				})
				i += b.length()
				matched = true
				break
		if not matched:
			var cp := raw.unicode_at(i)
			if cp < 32 or cp == 127:
				var one := char(cp)
				for entry in _char_constants():
					if entry.bytes == one:
						rows.append({
							"label": "Use instead",
							"text": ' & %s' % entry.name,
							"radix_id": "vbconst",
							"is_current": false,
							"hint": entry.desc,
						})
						break
			i += 1
	return rows


static func _vb_char_hints_for_code(code: int) -> Array:
	for entry in _char_constants():
		if entry.bytes.length() == 1 and entry.bytes.unicode_at(0) == code:
			return [{"label": "VB constant", "text": entry.name, "radix_id": "vbconst", "is_current": false, "hint": entry.desc}]
	if code == 13:
		return [{"label": "VB constant", "text": "vbCr", "radix_id": "vbconst", "is_current": false}]
	if code == 10:
		return [{"label": "VB constant", "text": "vbLf", "radix_id": "vbconst", "is_current": false}]
	return []


static func _popcount(v: int) -> int:
	var n := v & 0xFFFFFFFF
	var c := 0
	while n > 0:
		c += n & 1
		n >>= 1
	return c


static func _date_serial_call(body: String) -> String:
	var parts := body.split(" ")
	var date_part := parts[0]
	if not date_part.contains("/"):
		return "TimeSerial(...)"
	var d := date_part.split("/")
	if d.size() < 3:
		return "DateSerial(...)"
	return "DateSerial(%s, %s, %s)" % [d[2], d[0], d[1]]


static func _time_part(body: String) -> String:
	if body.contains(" "):
		return body.split(" ", false, 1)[1]
	return body


static func _line_has_angle_fn(lower_line: String) -> bool:
	for fn in ["sin(", "cos(", "tan(", "atn(", "asin(", "acos("]:
		if lower_line.contains(fn):
			return true
	return false


static func _expression_at_column(line: String, column: int) -> Dictionary:
	var col := clampi(column, 0, maxi(line.length() - 1, 0))
	var start := col
	var end := col + 1
	while start > 0 and _is_expr_char(line[start - 1]):
		start -= 1
	while end < line.length() and _is_expr_char(line[end]):
		end += 1
	var text := line.substr(start, end - start).strip_edges()
	if text.is_empty() or not _looks_like_expr(text):
		return {}
	if col < start or col > end:
		return {}
	return {"text": text, "start": start, "end": end}


static func _is_expr_char(ch: String) -> bool:
	return ch.is_valid_int() or ch in "+-*/(). "


static func _looks_like_expr(text: String) -> bool:
	if not text.contains("+") and not text.contains("-") and not text.contains("*") and not text.contains("/"):
		return false
	return text.replace(" ", "").is_valid_float() == false


static func _eval_simple_expr(text: String) -> Variant:
	var safe := text.strip_edges()
	if safe.is_empty():
		return null
	if safe.contains("\"") or safe.contains("'"):
		return null
	for i in safe.length():
		var c := safe[i]
		if not (c.is_valid_int() or c in "+-*/(). "):
			return null
	if not ("+" in safe or "-" in safe or "*" in safe or "/" in safe):
		return null
	var expr := Expression.new()
	if expr.parse(safe) != OK:
		return null
	var val = expr.execute([], null, false)
	if expr.has_execute_failed():
		return null
	return val


static func _rx(pattern: String) -> RegEx:
	var r := RegEx.new()
	r.compile(pattern)
	return r
