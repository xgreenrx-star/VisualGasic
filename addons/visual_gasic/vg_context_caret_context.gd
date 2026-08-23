@tool
extends RefCounted
## Connect-line and symbol-at-caret context for the Context Rail.

static var _connect_re: RegEx
static var _dim_re: RegEx
static var _event_handler_re: RegEx

static var _CONTROL_PREFIX_PROPS := {
	"btn": ["Caption", "Enabled", "Visible", "Left", "Top", "Width", "Height"],
	"lbl": ["Caption", "Visible", "Left", "Top", "Width", "Height"],
	"txt": ["Text", "Enabled", "Visible", "Left", "Top", "Width", "Height"],
	"tmr": ["Interval", "Enabled", "Visible"],
	"chk": ["Caption", "Value", "Enabled", "Visible"],
	"opt": ["Caption", "Value", "Enabled", "Visible"],
	"cbo": ["Text", "ListIndex", "Enabled", "Visible"],
	"pic": ["Visible", "Left", "Top", "Width", "Height"],
	"frm": ["Caption", "Visible", "Left", "Top", "Width", "Height"],
	"img": ["Visible", "Left", "Top", "Width", "Height"],
}


static func _ensure_regex() -> void:
	if _connect_re == null:
		_connect_re = RegEx.new()
		_connect_re.compile(
			"(?i)\\bConnect\\s+(\\w+)\\s*,\\s*(?:\"([^\"]*)\"|'([^']*)')\\s*,\\s*(?:\"([^\"]*)\"|'([^']*)')"
		)
	if _dim_re == null:
		_dim_re = RegEx.new()
		_dim_re.compile("(?i)^\\s*(?:Public|Private|Friend|Static|Const|Dim|Global)\\s+(\\w+)\\s+As\\s+(\\w+)")
	if _event_handler_re == null:
		_event_handler_re = RegEx.new()
		_event_handler_re.compile("(?i)^\\s*Sub\\s+(\\w+)_(\\w+)\\s*\\(")


static func connect_at_line(source: String, line_index: int) -> Dictionary:
	_ensure_regex()
	var lines := source.split("\n")
	if line_index < 0 or line_index >= lines.size():
		return {}
	var m := _connect_re.search(lines[line_index])
	if m == null:
		return {}
	var signal_name := m.get_string(2)
	if signal_name.is_empty():
		signal_name = m.get_string(3)
	var handler := m.get_string(4)
	if handler.is_empty():
		handler = m.get_string(5)
	return {
		"node": m.get_string(1),
		"signal": signal_name,
		"handler": handler,
		"line": line_index,
	}


static func event_handler_parts(handler_name: String) -> Dictionary:
	_ensure_regex()
	var m := _event_handler_re.search("Sub %s()" % handler_name)
	if m == null:
		return {}
	return {
		"control": m.get_string(1),
		"event": m.get_string(2),
		"handler": handler_name,
	}


static func member_at_caret(source: String, line_index: int, column: int) -> Dictionary:
	_ensure_regex()
	var lines := source.split("\n")
	if line_index < 0 or line_index >= lines.size():
		return {}
	var word := _word_at_column(lines[line_index], column)
	if word.is_empty():
		return {}
	var dims := _parse_dim_table(source)
	var type_hint := str(dims.get(word, ""))
	var out := {
		"name": word,
		"type_hint": type_hint,
		"kind": "identifier",
		"properties": PackedStringArray(),
		"notes": "",
	}
	if not type_hint.is_empty():
		out["kind"] = "variable"
		out["properties"] = _properties_for_type(type_hint)
	elif _looks_like_control_name(word):
		out["kind"] = "control"
		out["type_hint"] = _guess_control_type(word)
		out["properties"] = _properties_for_control_prefix(word)
		out["notes"] = "VB6 aliases: Caption→text, Left/Top/Width/Height→position/size"
	return out


static func _parse_dim_table(source: String) -> Dictionary:
	var table := {}
	for line in source.split("\n"):
		var m := _dim_re.search(line)
		if m != null:
			table[m.get_string(1)] = m.get_string(2)
	return table


static func _word_at_column(line: String, column: int) -> String:
	if line.is_empty():
		return ""
	var col := clampi(column, 0, line.length())
	var start := col
	var end := col
	while start > 0 and _is_ident_char(line[start - 1]):
		start -= 1
	while end < line.length() and _is_ident_char(line[end]):
		end += 1
	if start >= end:
		return ""
	return line.substr(start, end - start)


static func _is_ident_char(ch: String) -> bool:
	return ch.is_valid_identifier() or ch == "_"


static func control_properties_for_name(name: String) -> PackedStringArray:
	if _looks_like_control_name(name):
		return _properties_for_control_prefix(name)
	return PackedStringArray()


static func is_control_name(name: String) -> bool:
	return _looks_like_control_name(name)


static func _looks_like_control_name(name: String) -> bool:
	var lower := name.to_lower()
	for prefix in _CONTROL_PREFIX_PROPS.keys():
		if lower.begins_with(prefix) and name.length() > prefix.length():
			return true
	return false


static func _guess_control_type(name: String) -> String:
	var lower := name.to_lower()
	if lower.begins_with("btn"):
		return "Button"
	if lower.begins_with("lbl"):
		return "Label"
	if lower.begins_with("txt"):
		return "TextBox"
	if lower.begins_with("tmr"):
		return "Timer"
	if lower.begins_with("chk"):
		return "CheckBox"
	if lower.begins_with("pic") or lower.begins_with("img"):
		return "PictureBox"
	return "Control"


static func _properties_for_control_prefix(name: String) -> PackedStringArray:
	var lower := name.to_lower()
	for prefix in _CONTROL_PREFIX_PROPS.keys():
		if lower.begins_with(prefix):
			return _CONTROL_PREFIX_PROPS[prefix]
	return PackedStringArray(["Caption", "Visible", "Enabled", "Left", "Top"])


static func _properties_for_type(type_name: String) -> PackedStringArray:
	var t := type_name.to_lower()
	match t:
		"button":
			return PackedStringArray(["Caption", "Enabled", "Visible"])
		"label":
			return PackedStringArray(["Caption", "Visible"])
		"textbox":
			return PackedStringArray(["Text", "Enabled", "Visible"])
		"timer":
			return PackedStringArray(["Interval", "Enabled"])
		"integer", "long", "single", "double":
			return PackedStringArray()
		"string":
			return PackedStringArray(["Len", "Left", "Trim"])
		_:
			return PackedStringArray()
