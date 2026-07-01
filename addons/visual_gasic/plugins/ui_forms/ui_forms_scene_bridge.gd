@tool
## UI Forms scene bridge (experimental).
##
## Pure/near-pure logic that translates between the in-memory control model
## and on-disk artifacts:
##   * serialize_tscn()  — control model  → Godot .tscn text (Control root
##                          with the form's .vg script attached)
##   * load_form()        — .tscn text     → control model
##   * write_form()       — persists both the .tscn and (if missing) the .vg
##   * insert_event_stub() — idempotently adds a "Private Sub <name>()" to .vg
##
## Deliberately free of scene-tree / UI dependencies so it can be exercised
## headlessly.  The control model is an Array of Dictionaries shaped like:
##   { "name": String, "type": String, "rect": Rect2, "text": String }
## where "type" is the Godot class name (Button, Label, LineEdit, ...).
extends RefCounted

## Root node type used for generated form scenes.  A plain Control keeps the
## experimental designer self-contained (no Window sub-viewport quirks) and
## round-trips cleanly under headless.
const ROOT_TYPE := "Control"


# ─── VB6 naming / event conventions ─────────────────────────

## Godot class name → VB6 naming base (the prefix used for auto-names).
static func name_base_for(godot_type: String) -> String:
	match godot_type:
		"LineEdit": return "TextBox"
		"OptionButton": return "ComboBox"
		"ItemList": return "ListBox"
		"Panel": return "Frame"
		"TabContainer": return "TabStrip"
		_: return godot_type

## VB6 event suffix for a control type (Click / Change / Timer).
static func event_suffix_for(godot_type: String) -> String:
	match godot_type:
		"LineEdit", "TextEdit":
			return "Change"
		"HScrollBar", "VScrollBar", "HSlider", "VSlider", "SpinBox":
			return "Change"
		"Timer":
			return "Timer"
		_:
			return "Click"

## Returns the next unused "<base><n>" name given the names already in use.
static func next_control_name(godot_type: String, existing_names: Array) -> String:
	var base := name_base_for(godot_type)
	var n := 1
	while n < 10000:
		var candidate := base + str(n)
		if not existing_names.has(candidate):
			return candidate
		n += 1
	return base + "_x"


# ─── Serialization ──────────────────────────────────────────

## Serializes the control model to .tscn text.  form_size defines the root
## control's rect; controls is the model Array described in the file header.
func serialize_tscn(form_name: String, vg_path: String, form_size: Vector2, controls: Array) -> String:
	var out := "[gd_scene load_steps=2 format=3]\n\n"
	out += "[ext_resource type=\"Script\" path=\"%s\" id=\"1_vg\"]\n\n" % vg_path
	out += "[node name=\"%s\" type=\"%s\"]\n" % [form_name, ROOT_TYPE]
	out += "layout_mode = 3\n"
	out += "anchors_preset = 0\n"
	out += "offset_right = %s\n" % _fnum(form_size.x)
	out += "offset_bottom = %s\n" % _fnum(form_size.y)
	out += "metadata/vg_ui_forms = true\n"
	out += "script = ExtResource(\"1_vg\")\n"
	for c in controls:
		var rect: Rect2 = c.get("rect", Rect2())
		out += "\n[node name=\"%s\" type=\"%s\" parent=\".\"]\n" % [str(c.get("name", "Control")), str(c.get("type", "Control"))]
		out += "layout_mode = 0\n"
		out += "offset_left = %s\n" % _fnum(rect.position.x)
		out += "offset_top = %s\n" % _fnum(rect.position.y)
		out += "offset_right = %s\n" % _fnum(rect.position.x + rect.size.x)
		out += "offset_bottom = %s\n" % _fnum(rect.position.y + rect.size.y)
		var txt := str(c.get("text", ""))
		if txt != "":
			out += "text = \"%s\"\n" % txt.replace("\\", "\\\\").replace("\"", "\\\"")
		out += "metadata/vb6_type = \"%s\"\n" % name_base_for(str(c.get("type", "Control")))
	return out

## Parses a form .tscn (as produced by serialize_tscn, and tolerant of plain
## offset-based Control scenes) into { form_name, size: Vector2, controls }.
func load_form(tscn_path: String) -> Dictionary:
	var result := {"form_name": "Form1", "size": Vector2(640, 480), "controls": []}
	if not FileAccess.file_exists(tscn_path):
		return result
	var text := FileAccess.get_file_as_string(tscn_path)
	var node_rx := RegEx.new()
	node_rx.compile("^\\[node name=\"([^\"]+)\" type=\"([^\"]+)\"(?:\\s+parent=\"([^\"]*)\")?")
	var prop_rx := RegEx.new()
	prop_rx.compile("^([A-Za-z_][A-Za-z0-9_/]*)\\s*=\\s*(.*)$")

	var controls: Array = []
	var cur := {}          # current control block being filled
	var in_root := false
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		var nm := node_rx.search(line)
		if nm:
			# Flush the previous control block.
			if not cur.is_empty():
				controls.append(_finish_control(cur))
				cur = {}
			var node_name := nm.get_string(1)
			var node_type := nm.get_string(2)
			var parent := nm.get_string(3)
			if parent == "":
				# Root form node.
				result["form_name"] = node_name
				in_root = true
			else:
				in_root = false
				cur = {"name": node_name, "type": node_type,
					"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0, "text": ""}
			continue
		var pm := prop_rx.search(line)
		if not pm:
			continue
		var key := pm.get_string(1)
		var val := pm.get_string(2)
		if in_root:
			if key == "offset_right":
				result["size"].x = val.to_float()
			elif key == "offset_bottom":
				result["size"].y = val.to_float()
		elif not cur.is_empty():
			match key:
				"offset_left": cur["left"] = val.to_float()
				"offset_top": cur["top"] = val.to_float()
				"offset_right": cur["right"] = val.to_float()
				"offset_bottom": cur["bottom"] = val.to_float()
				"text": cur["text"] = _unquote(val)
	if not cur.is_empty():
		controls.append(_finish_control(cur))
	result["controls"] = controls
	return result


# ─── Persistence ────────────────────────────────────────────

## Writes the form to disk.  Ensures the .vg exists (creating a minimal one
## with a Form_Load stub) so the .tscn's script ext_resource is valid, then
## writes the .tscn.  Returns an Error code (OK on success).
func write_form(tscn_path: String, vg_path: String, form_name: String, form_size: Vector2, controls: Array) -> int:
	if not FileAccess.file_exists(vg_path):
		var verr := _write_initial_vg(vg_path, form_name)
		if verr != OK:
			return verr
	var tscn_text := serialize_tscn(form_name, vg_path, form_size, controls)
	var f := FileAccess.open(tscn_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(tscn_text)
	f.close()
	return OK

## Idempotently ensures "Private Sub <sub_name>(<params>)" exists in the .vg.
## Returns true if a new stub was inserted, false if it already existed (or on
## error).  Safe to call repeatedly for the same handler.
func insert_event_stub(vg_path: String, sub_name: String, params: String = "") -> bool:
	var text := ""
	if FileAccess.file_exists(vg_path):
		text = FileAccess.get_file_as_string(vg_path)
	else:
		text = "' VisualGasic Form\n"
	var rx := RegEx.new()
	rx.compile("(?im)^\\s*(?:Public\\s+|Private\\s+)?Sub\\s+" + _escape_regex(sub_name) + "\\s*\\(")
	if rx.search(text):
		return false
	if not text.ends_with("\n"):
		text += "\n"
	text += "\nPrivate Sub %s(%s)\n    \nEnd Sub\n" % [sub_name, params]
	var f := FileAccess.open(vg_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


# ─── Internal helpers ───────────────────────────────────────

func _write_initial_vg(vg_path: String, form_name: String) -> int:
	var stub := "' %s - VisualGasic Form\n\n" % form_name
	stub += "Private Sub Form_Load()\n    ' Initialization code here...\nEnd Sub\n"
	var f := FileAccess.open(vg_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(stub)
	f.close()
	return OK

func _finish_control(block: Dictionary) -> Dictionary:
	var pos := Vector2(block.get("left", 0.0), block.get("top", 0.0))
	var size := Vector2(
		block.get("right", 0.0) - block.get("left", 0.0),
		block.get("bottom", 0.0) - block.get("top", 0.0))
	return {
		"name": block.get("name", "Control"),
		"type": block.get("type", "Control"),
		"rect": Rect2(pos, size),
		"text": block.get("text", ""),
	}

func _unquote(val: String) -> String:
	var s := val.strip_edges()
	if s.length() >= 2 and s.begins_with("\"") and s.ends_with("\""):
		s = s.substr(1, s.length() - 2)
	return s.replace("\\\"", "\"").replace("\\\\", "\\")

func _escape_regex(s: String) -> String:
	var out := ""
	for ch in s:
		if "\\^$.|?*+()[]{}".contains(ch):
			out += "\\"
		out += ch
	return out

func _fnum(v: float) -> String:
	if v == floorf(v):
		return "%.1f" % v
	return str(v)
