@tool
extends RefCounted
## Static analysis for the VG Context Rail — region, procedure, sprite, keyword, chain teaser.

const Resolver := preload("res://addons/visual_gasic/vg_sprite_data_resolver.gd")
const EditorAssist := preload("res://addons/visual_gasic/vg_editor_assist.gd")

static var _sub_re: RegEx
static var _func_re: RegEx
static var _end_sub_re: RegEx
static var _event_re: RegEx
static var _summary_re: RegEx


static func _ensure_regex() -> void:
	if _sub_re == null:
		_sub_re = RegEx.new()
		_sub_re.compile("(?i)^\\s*(?:Public|Private|Friend|Static|)\\s*Sub\\s+(\\w+)")
	if _func_re == null:
		_func_re = RegEx.new()
		_func_re.compile("(?i)^\\s*(?:Public|Private|Friend|Static|)\\s*Function\\s+(\\w+)")
	if _end_sub_re == null:
		_end_sub_re = RegEx.new()
		_end_sub_re.compile("(?i)^\\s*End\\s+(Sub|Function)")
	if _event_re == null:
		_event_re = RegEx.new()
		_event_re.compile("(?i)^\\s*Sub\\s+(\\w+)_(Click|Change|Load|Shown|KeyDown|KeyUp|Timer|Closed|Open|Resize|Paint|GotFocus|LostFocus|MouseDown|MouseUp)")
	if _summary_re == null:
		_summary_re = RegEx.new()
		_summary_re.compile("(?i)^\\s*'\\s*@VG-Summary\\s*(.*)$")


static func analyze(source: String, caret_line: int) -> Dictionary:
	_ensure_regex()
	var lines := source.split("\n") if not source.is_empty() else PackedStringArray()
	var out := {
		"caret_line": caret_line,
		"line_count": lines.size(),
		"region_kind": "module",
		"region_title": "Module level",
		"region_detail": "",
		"procedure": {},
		"sprite": {},
		"is_event_handler": false,
		"event_label": "",
		"chain_roots": [],
		"outline": [],
	}
	if lines.is_empty():
		return out

	out["outline"] = _build_outline(lines)
	var proc := _procedure_at_line(lines, caret_line)
	if not proc.is_empty():
		out["procedure"] = proc
		out["region_kind"] = "procedure"
		out["region_title"] = str(proc.get("kind", "Sub")) + " " + str(proc.get("name", ""))
		out["region_detail"] = "Lines %d–%d" % [int(proc.get("start_line", 0)) + 1, int(proc.get("end_line", 0)) + 1]
		if proc.get("is_event", false):
			out["is_event_handler"] = true
			out["event_label"] = _event_user_action(str(proc.get("name", "")))
			out["chain_roots"] = [proc.get("name", "")]

	var sprite := Resolver.resolve_at_line(source, caret_line)
	if not sprite.is_empty():
		out["sprite"] = sprite
		if out["region_kind"] == "module":
			out["region_kind"] = "sprite_data"
		out["region_title"] = "%s  (%d×%d)" % [sprite.get("label", "Sprite"), sprite.get("w", 0), sprite.get("h", 0)]
		out["region_detail"] = "Indexed pixel Data — edit below"

	return out


static func _build_outline(lines: PackedStringArray) -> Array:
	var outline: Array = []
	for i in lines.size():
		var line := lines[i]
		var sm := _sub_re.search(line)
		var fm := _func_re.search(line) if sm == null else null
		if sm != null:
			outline.append({"kind": "sub", "label": "Sub " + sm.get_string(1), "line": i})
		elif fm != null:
			outline.append({"kind": "function", "label": "Function " + fm.get_string(1), "line": i})
		else:
			var lm := Resolver._label_rx().search(line)
			if lm != null and Resolver.is_sprite_label(lm.get_string(1)):
				outline.append({"kind": "sprite", "label": lm.get_string(1), "line": i})
	return outline


static func _procedure_at_line(lines: PackedStringArray, caret_line: int) -> Dictionary:
	for p in _parse_procedures(lines):
		if caret_line >= p["start_line"] and caret_line <= p["end_line"]:
			return p
	return {}


static func _parse_procedures(lines: PackedStringArray) -> Array:
	var out: Array = []
	for i in lines.size():
		var sm := _sub_re.search(lines[i])
		var fm := _func_re.search(lines[i]) if sm == null else null
		if sm == null and fm == null:
			continue
		var name := sm.get_string(1) if sm else fm.get_string(1)
		var kind := "Sub" if sm else "Function"
		var start := i
		var end := lines.size() - 1
		for j in range(i + 1, lines.size()):
			if _end_sub_re.search(lines[j]) != null:
				end = j
				break
		var em := _event_re.search(lines[start])
		out.append({
			"name": name,
			"kind": kind,
			"start_line": start,
			"end_line": end,
			"signature": lines[start].strip_edges(),
			"summary": _summary_above(lines, start),
			"is_event": em != null,
		})
	return out


static func _summary_above(lines: PackedStringArray, proc_line: int) -> String:
	for j in range(proc_line - 1, maxi(proc_line - 6, -1), -1):
		var m := _summary_re.search(lines[j])
		if m != null:
			return m.get_string(1).strip_edges()
		var s := lines[j].strip_edges()
		if s.begins_with("'") and not s.to_lower().contains("@vg-"):
			return s.substr(1).strip_edges()
		if not s.is_empty() and not s.begins_with("'"):
			break
	return ""


static func _event_user_action(handler_name: String) -> String:
	var parts := handler_name.split("_")
	if parts.size() >= 2:
		return "User %s on [%s]" % [parts[parts.size() - 1].to_lower(), parts[0]]
	return "Event: " + handler_name
