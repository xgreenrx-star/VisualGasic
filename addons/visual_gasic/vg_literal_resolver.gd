@tool
extends RefCounted
## Detect numeric/boolean literals at the caret and format alternate representations.

const Enrich := preload("res://addons/visual_gasic/vg_literal_enrich.gd")

enum Radix {
	DECIMAL,
	HEX_VB,
	HEX_C,
	OCTAL,
	BINARY,
	FLOAT,
	BOOLEAN,
	STRING,
}


static func resolve_at_caret(source: String, line_index: int, column: int) -> Dictionary:
	if source.is_empty() or line_index < 0:
		return {}
	var lines := source.split("\n")
	if line_index >= lines.size():
		return {}
	var line: String = lines[line_index]
	if line.is_empty() or _is_comment_only_line(line):
		return {}
	var col := clampi(column, 0, maxi(line.length() - 1, 0))
	var lit := _resolve_literal_on_line(line, line_index, col)
	if not lit.is_empty():
		lit["line_text"] = line
		lit["column"] = col
		return lit
	var color := Enrich.resolve_color_call(line, col)
	if not color.is_empty():
		color["line"] = line_index
		color["line_text"] = line
		color["column"] = col
		return color
	var expr := Enrich.try_eval_expression(line, col)
	if not expr.is_empty():
		expr["line"] = line_index
		expr["line_text"] = line
		expr["column"] = col
		return expr
	return {}


static func _resolve_literal_on_line(line: String, line_index: int, col: int) -> Dictionary:
	for span in _literals_on_line(line):
		if not _column_in_span(col, span):
			continue
		return _span_to_literal(line, span, line_index)
	return {}


static func format_conversions(lit: Dictionary) -> Array:
	if lit.is_empty():
		return []
	var kind: String = lit.get("kind", "")
	var line_text: String = str(lit.get("line_text", ""))
	var column: int = int(lit.get("column", 0))
	match kind:
		"integer":
			var value := int(lit.get("value_i64", 0))
			var src_radix := str(lit.get("source_radix", "decimal"))
			var rows: Array = _integer_conversions(value, src_radix)
			rows.append_array(Enrich.bit_rows(value))
			if Enrich.is_color_hex_literal(lit):
				rows.append_array(Enrich.color_rows_from_hex(str(lit.get("source_text", "")), value))
			elif value >= 0 and value <= 127 and src_radix == "decimal":
				rows.append_array(Enrich.chr_rows(value))
			rows.append_array(Enrich.context_rows(line_text, column, float(value), kind))
			return rows
		"float":
			var fv := float(lit.get("value_f64", 0.0))
			var rows_f: Array = _float_conversions(fv, str(lit.get("source_text", "")))
			rows_f.append_array(Enrich.context_rows(line_text, column, fv, kind))
			return rows_f
		"boolean":
			return _boolean_conversions(bool(lit.get("value_bool", false)), str(lit.get("source_text", "")))
		"string":
			var raw := str(lit.get("value_str", ""))
			var rows_s: Array = Enrich.string_hint_rows(raw)
			if raw.length() == 1:
				rows_s.append_array(Enrich.asc_rows(raw))
			return rows_s
		"date":
			return Enrich.date_rows(str(lit.get("value_str", "")), str(lit.get("source_text", "")))
		"color":
			if lit.has("qb_index"):
				return Enrich.color_rows_from_qb(int(lit.get("qb_index", 0)), str(lit.get("source_text", "")))
			return Enrich.color_rows_from_rgb(
				float(lit.get("r", 0)), float(lit.get("g", 0)), float(lit.get("b", 0)),
				str(lit.get("source_text", ""))
			)
		"expression":
			return Enrich.expression_rows(str(lit.get("source_text", "")), lit.get("value"))
	return []


static func _integer_conversions(value: int, source_radix: String) -> Array:
	var rows: Array = []
	var u32: int = value & 0xFFFFFFFF
	_add_row(rows, "Decimal", str(value), "decimal", source_radix)
	_add_row(rows, "Hex (VB6)", "&H%s" % _hex_upper(u32), "hex_vb", source_radix)
	_add_row(rows, "Hex (C)", "0x%s" % _hex_lower(u32), "hex_c", source_radix)
	_add_row(rows, "Octal", "&O%s" % _to_oct(u32), "octal", source_radix)
	_add_row(rows, "Binary", "&B%s" % _to_binary(u32), "binary", source_radix)
	if value < 0 or u32 > 0xFFFF:
		_add_row(rows, "UInt32", str(u32 if u32 >= 0 else u32), "uint32", source_radix)
	if value >= 32 and value <= 126:
		_add_row(rows, "Char", "\"%s\"" % char(value), "char", source_radix)
	return rows


static func _float_conversions(value: float, source_text: String) -> Array:
	var rows: Array = []
	var dec := _trim_float(value)
	_add_row(rows, "Decimal", dec, "decimal", "float")
	if not source_text.is_empty() and source_text != dec:
		_add_row(rows, "Source", source_text, "source", "float")
	var sci := "%.6e" % value
	_add_row(rows, "Scientific", sci, "scientific", "float")
	return rows


static func _boolean_conversions(value: bool, source_text: String) -> Array:
	var rows: Array = []
	var src := source_text if not source_text.is_empty() else ("True" if value else "False")
	_add_row(rows, "Boolean", src, "boolean", "boolean")
	var i64 := -1 if value else 0
	_add_row(rows, "As Integer", str(i64), "decimal", "boolean")
	_add_row(rows, "Hex (VB6)", "&HFFFFFFFF" if value else "&H0", "hex_vb", "boolean")
	_add_row(rows, "Hex (C)", "0xffffffff" if value else "0x0", "hex_c", "boolean")
	return rows


static func _add_row(rows: Array, label: String, text: String, radix_id: String, source_radix: String) -> void:
	rows.append({
		"label": label,
		"text": text,
		"radix_id": radix_id,
		"is_current": radix_id == source_radix,
	})


static func _literals_on_line(line: String) -> Array:
	var spans: Array = []
	var i := 0
	while i < line.length():
		var ch := line[i]
		if ch == "'":
			break
		if ch == "#":
			var d := _scan_date(line, i)
			if not d.is_empty():
				spans.append(d)
				i = int(d.get("end", i + 1))
				continue
		if ch == "\"":
			var s := _scan_string(line, i)
			if not s.is_empty():
				spans.append(s)
				i = int(s.get("end", i + 1))
			else:
				i += 1
			continue
		if ch == "&" and i + 1 < line.length():
			var nxt := line[i + 1]
			if nxt == "H" or nxt == "h":
				var h := _scan_hex_vb(line, i)
				if not h.is_empty():
					spans.append(h)
					i = int(h.get("end", i + 2))
					continue
			if nxt == "O" or nxt == "o":
				var o := _scan_octal(line, i)
				if not o.is_empty():
					spans.append(o)
					i = int(o.get("end", i + 2))
					continue
			if nxt == "B" or nxt == "b":
				var b := _scan_binary(line, i)
				if not b.is_empty():
					spans.append(b)
					i = int(b.get("end", i + 2))
					continue
		if ch == "0" and i + 1 < line.length() and (line[i + 1] == "x" or line[i + 1] == "X"):
			var hx := _scan_hex_c(line, i)
			if not hx.is_empty():
				spans.append(hx)
				i = int(hx.get("end", i + 2))
				continue
		if ch == "-" and i + 1 < line.length() and line[i + 1].is_valid_int():
			var neg := _scan_decimal_or_float(line, i)
			if not neg.is_empty():
				spans.append(neg)
				i = int(neg.get("end", i + 1))
				continue
		if ch.is_valid_int() or ch == ".":
			var num := _scan_decimal_or_float(line, i)
			if not num.is_empty():
				spans.append(num)
				i = int(num.get("end", i + 1))
				continue
		if ch.is_valid_identifier() or ch == "_":
			var word := _scan_word(line, i)
			if not word.is_empty():
				var lower := str(word.get("text", "")).to_lower()
				if lower == "true" or lower == "false":
					spans.append({
						"kind": "boolean",
						"start": int(word.get("start", i)),
						"end": int(word.get("end", i)),
						"value": lower == "true",
					})
				i = int(word.get("end", i + 1))
				continue
		i += 1
	return spans


static func _span_to_literal(line: String, span: Dictionary, line_index: int) -> Dictionary:
	var start := int(span.get("start", 0))
	var end := int(span.get("end", start))
	var text := line.substr(start, end - start)
	var kind: String = span.get("kind", "")
	var out := {
		"kind": kind,
		"source_text": text,
		"start": start,
		"end": end,
		"line": line_index,
	}
	match kind:
		"integer":
			out["source_radix"] = span.get("radix", "decimal")
			out["value_i64"] = int(span.get("value", 0))
		"float":
			out["source_radix"] = "float"
			out["value_f64"] = float(span.get("value", 0.0))
		"boolean":
			out["source_radix"] = "boolean"
			out["value_bool"] = bool(span.get("value", false))
		"string":
			out["source_radix"] = "string"
			out["value_str"] = str(span.get("value", ""))
		"date":
			out["source_radix"] = "date"
			out["value_str"] = str(span.get("value", ""))
	return out


static func _scan_string(line: String, start: int) -> Dictionary:
	if line[start] != "\"":
		return {}
	var i := start + 1
	while i < line.length():
		if line[i] == "\"" and (i == 0 or line[i - 1] != "\\"):
			return {
				"kind": "string",
				"start": start,
				"end": i + 1,
				"value": line.substr(start + 1, i - start - 1),
			}
		i += 1
	return {}


static func _scan_hex_vb(line: String, start: int) -> Dictionary:
	var i := start + 2
	var val := 0
	var has := false
	while i < line.length():
		var c := line[i]
		var digit := _hex_digit(c)
		if digit < 0:
			break
		val = (val << 4) | digit
		has = true
		i += 1
	if not has:
		return {}
	if i < line.length() and (line[i] == "&" or line[i] == "%"):
		i += 1
	return {"kind": "integer", "start": start, "end": i, "value": val, "radix": "hex_vb"}


static func _scan_hex_c(line: String, start: int) -> Dictionary:
	var i := start + 2
	var val := 0
	var has := false
	while i < line.length():
		var digit := _hex_digit(line[i])
		if digit < 0:
			break
		val = (val << 4) | digit
		has = true
		i += 1
	if not has:
		return {}
	return {"kind": "integer", "start": start, "end": i, "value": val, "radix": "hex_c"}


static func _scan_octal(line: String, start: int) -> Dictionary:
	var i := start + 2
	var val := 0
	var has := false
	while i < line.length() and line[i] >= "0" and line[i] <= "7":
		val = (val << 3) | (line[i].unicode_at(0) - "0".unicode_at(0))
		has = true
		i += 1
	if not has:
		return {}
	return {"kind": "integer", "start": start, "end": i, "value": val, "radix": "octal"}


static func _scan_binary(line: String, start: int) -> Dictionary:
	var i := start + 2
	var val := 0
	var has := false
	while i < line.length() and line[i] in "01":
		val = (val << 1) | (line[i].unicode_at(0) - "0".unicode_at(0))
		has = true
		i += 1
	if not has:
		return {}
	return {"kind": "integer", "start": start, "end": i, "value": val, "radix": "binary"}


static func _scan_date(line: String, start: int) -> Dictionary:
	if line[start] != "#":
		return {}
	var i := start + 1
	while i < line.length() and line[i] != "#":
		i += 1
	if i >= line.length():
		return {}
	var body := line.substr(start + 1, i - start - 1)
	if not body.contains("/") and not body.contains(":"):
		return {}
	return {"kind": "date", "start": start, "end": i + 1, "value": body, "radix": "date"}


static func _scan_decimal_or_float(line: String, start: int) -> Dictionary:
	var i := start
	if line[i] == "-":
		i += 1
	if i >= line.length():
		return {}
	var int_start := i
	var saw_dot := false
	while i < line.length():
		var c := line[i]
		if c.is_valid_int():
			i += 1
			continue
		if c == "." and not saw_dot:
			if i + 1 < line.length() and line[i + 1].is_valid_int():
				saw_dot = true
				i += 1
				continue
		break
	if i == int_start:
		return {}
	var text := line.substr(start, i - start)
	# VB6 type suffixes: % & ! # @
	if i < line.length():
		var suf := line[i]
		if suf in "%&!@#":
			i += 1
			if suf in "!@#":
				saw_dot = true
	if saw_dot:
		return {"kind": "float", "start": start, "end": i, "value": text.to_float(), "radix": "float"}
	return {"kind": "integer", "start": start, "end": i, "value": text.to_int(), "radix": "decimal"}


static func _scan_word(line: String, start: int) -> Dictionary:
	var i := start
	while i < line.length() and (line[i].is_valid_identifier() or line[i] == "_"):
		i += 1
	if i == start:
		return {}
	return {"start": start, "end": i, "text": line.substr(start, i - start)}


static func _column_in_span(column: int, span: Dictionary) -> bool:
	var start := int(span.get("start", 0))
	var end := int(span.get("end", start))
	if column < start:
		return false
	if column < end:
		return true
	# Caret immediately after the last character still counts as "on" the literal.
	return column == end and end > start


static func _is_comment_only_line(line: String) -> bool:
	var s := line.strip_edges()
	return s.is_empty() or s.begins_with("'") or s.to_lower().begins_with("rem ")


static func _hex_digit(c: String) -> int:
	if c >= "0" and c <= "9":
		return c.unicode_at(0) - "0".unicode_at(0)
	if c >= "A" and c <= "F":
		return c.unicode_at(0) - "A".unicode_at(0) + 10
	if c >= "a" and c <= "f":
		return c.unicode_at(0) - "a".unicode_at(0) + 10
	return -1


static func _hex_upper(v: int) -> String:
	if v == 0:
		return "0"
	var hex := String.num_uint64(v & 0xFFFFFFFF, 16).to_upper()
	return hex


static func _hex_lower(v: int) -> String:
	if v == 0:
		return "0"
	return String.num_uint64(v & 0xFFFFFFFF, 16)


static func _to_oct(v: int) -> String:
	if v == 0:
		return "0"
	var n := v & 0xFFFFFFFF
	var digits := ""
	while n > 0:
		digits = str(n & 7) + digits
		n >>= 3
	return digits


static func _to_binary(v: int) -> String:
	if v == 0:
		return "0"
	var n := v & 0xFFFFFFFF
	var bits := ""
	while n > 0:
		bits = str(n & 1) + bits
		n >>= 1
	return bits


static func _trim_float(v: float) -> String:
	var s := str(v)
	if s.contains("."):
		return s
	return s + ".0" if abs(v - floor(v)) > 0.000001 else s
