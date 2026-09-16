@tool
extends AcceptDialog
## Documentation Generator — parses .vg files and emits Markdown / HTML reference.

signal docs_generated(output_path: String)

# ── Config controls ──────────────────────────────────────────────────────
var _output_dir_edit: LineEdit
var _browse_btn: Button
var _format_option: OptionButton      # Markdown / HTML / Both
var _include_private_chk: CheckBox
var _include_event_handlers_chk: CheckBox
var _status_label: Label

# ── Parsed data model ────────────────────────────────────────────────────
class DocModule:
	var file_path: String
	var module_name: String            # Attribute VB_Name or filename stem
	var module_type: String            # "Form", "Module", "Class"
	var description: String            # Top‑level ''' block before first declaration
	var options: PackedStringArray     # Option Explicit, etc.
	var constants: Array               # [{name, type, value, doc}]
	var variables: Array               # [{name, scope, type, doc}]
	var enums: Array                   # [{name, members:[{name, value}], doc}]
	var types: Array                   # [{name, fields:[{name, type}], doc}]
	var subs: Array                    # [{name, params:[{name, type, modifier}], doc, tags:{}}]
	var functions: Array               # [{name, params, return_type, doc, tags:{}}]

# ── Lifecycle ─────────────────────────────────────────────────────────────
func _init() -> void:
	title = "Generate Documentation"
	min_size = Vector2i(520, 340)
	exclusive = true
	_build_ui()

func _build_theme() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.91, 0.84)          # VB6 cream
	sb.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", sb)

func _build_ui() -> void:
	_build_theme()

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)

	# ── Title ──
	var title_lbl := Label.new()
	title_lbl.text = "Generate API Documentation"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color.BLACK)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title_lbl)

	# ── Output directory ──
	var dir_hb := HBoxContainer.new()
	var dir_lbl := Label.new()
	dir_lbl.text = "Output Folder:"
	dir_lbl.add_theme_color_override("font_color", Color.BLACK)
	dir_hb.add_child(dir_lbl)
	_output_dir_edit = LineEdit.new()
	_output_dir_edit.text = "res://docs/api"
	_output_dir_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_dir_edit.add_theme_color_override("font_color", Color.BLACK)
	var le_sb := StyleBoxFlat.new()
	le_sb.bg_color = Color.WHITE
	le_sb.set_border_width_all(1)
	le_sb.border_color = Color(0.5, 0.5, 0.5)
	le_sb.set_corner_radius_all(0)
	_output_dir_edit.add_theme_stylebox_override("normal", le_sb)
	dir_hb.add_child(_output_dir_edit)
	_browse_btn = Button.new()
	_browse_btn.text = "Browse..."
	_browse_btn.pressed.connect(_on_browse)
	dir_hb.add_child(_browse_btn)
	vb.add_child(dir_hb)

	# ── Format ──
	var fmt_hb := HBoxContainer.new()
	var fmt_lbl := Label.new()
	fmt_lbl.text = "Format:"
	fmt_lbl.add_theme_color_override("font_color", Color.BLACK)
	fmt_hb.add_child(fmt_lbl)
	_format_option = OptionButton.new()
	_format_option.add_item("Markdown (.md)", 0)
	_format_option.add_item("HTML (.html)", 1)
	_format_option.add_item("Both", 2)
	_format_option.selected = 0
	fmt_hb.add_child(_format_option)
	vb.add_child(fmt_hb)

	# ── Checkboxes ──
	_include_private_chk = CheckBox.new()
	_include_private_chk.text = "Include Private members"
	_include_private_chk.add_theme_color_override("font_color", Color.BLACK)
	_include_private_chk.button_pressed = false
	vb.add_child(_include_private_chk)

	_include_event_handlers_chk = CheckBox.new()
	_include_event_handlers_chk.text = "Include event handlers (e.g. btn1_Click)"
	_include_event_handlers_chk.add_theme_color_override("font_color", Color.BLACK)
	_include_event_handlers_chk.button_pressed = true
	vb.add_child(_include_event_handlers_chk)

	# ── Status ──
	_status_label = Label.new()
	_status_label.text = "Click OK to scan all .vg files and generate docs."
	_status_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_status_label)

	add_child(vb)
	confirmed.connect(_on_generate)

# ── Browse ────────────────────────────────────────────────────────────────
func _on_browse() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.dir_selected.connect(func(path: String):
		_output_dir_edit.text = path
		fd.queue_free()
	)
	fd.canceled.connect(func(): fd.queue_free())
	add_child(fd)
	fd.popup_centered(Vector2i(500, 400))

# ── Main entry: scan → parse → emit ──────────────────────────────────────
func _on_generate() -> void:
	var out_dir: String = _output_dir_edit.text.strip_edges()
	if out_dir.is_empty():
		out_dir = "res://docs/api"
	var fmt: int = _format_option.selected   # 0=md, 1=html, 2=both
	var inc_private: bool = _include_private_chk.button_pressed
	var inc_events: bool = _include_event_handlers_chk.button_pressed

	# Ensure output dir
	DirAccess.make_dir_recursive_absolute(out_dir)

	# Collect .vg files
	var vg_files: PackedStringArray = _find_vg_files("res://")
	if vg_files.is_empty():
		_status_label.text = "No .vg files found in the project."
		return

	# Parse each
	var modules: Array[DocModule] = []
	for path in vg_files:
		var m := _parse_file(path)
		if m:
			modules.append(m)

	# Sort by name
	modules.sort_custom(func(a, b): return a.module_name.naturalnocasecmp_to(b.module_name) < 0)

	# Filter
	if not inc_private:
		for m in modules:
			m.variables = m.variables.filter(func(v): return v.get("scope", "Dim") != "Private")
			m.subs = m.subs.filter(func(s): return s.get("scope", "") != "Private")
			m.functions = m.functions.filter(func(f): return f.get("scope", "") != "Private")
	if not inc_events:
		for m in modules:
			m.subs = m.subs.filter(func(s): return not _is_event_handler(s["name"]))

	# Generate output
	var count := 0
	if fmt == 0 or fmt == 2:
		count += _emit_markdown(modules, out_dir)
	if fmt == 1 or fmt == 2:
		count += _emit_html(modules, out_dir)

	_status_label.text = "Done — %d files generated in %s" % [count, out_dir]
	docs_generated.emit(out_dir)

# ── File discovery ────────────────────────────────────────────────────────
func _find_vg_files(root: String) -> PackedStringArray:
	var results: PackedStringArray = []
	var dir := DirAccess.open(root)
	if not dir:
		return results
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := root.path_join(entry)
		if dir.current_is_dir():
			if entry != "." and entry != ".." and entry != "addons":
				results.append_array(_find_vg_files(full))
		elif entry.get_extension() == "vg":
			results.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return results

# ── Parser ────────────────────────────────────────────────────────────────
func _parse_file(path: String) -> DocModule:
	var fa := FileAccess.open(path, FileAccess.READ)
	if not fa:
		return null
	var src := fa.get_as_text()
	fa.close()

	var m := DocModule.new()
	m.file_path = path
	m.module_name = path.get_file().get_basename()

	# Detect module type from Attribute or filename convention
	if src.contains("Attribute VB_Name"):
		var rx := RegEx.new()
		rx.compile('Attribute\\s+VB_Name\\s*=\\s*"([^"]+)"')
		var rm := rx.search(src)
		if rm:
			m.module_name = rm.get_string(1)
	if path.ends_with(".frm") or src.contains("Form_Load"):
		m.module_type = "Form"
	elif src.contains("Class_Initialize") or src.contains("Implements "):
		m.module_type = "Class"
	else:
		m.module_type = "Module"

	var lines := src.split("\n")
	var i := 0
	var pending_doc := ""     # Accumulated ''' lines

	# Grab top-level doc (''' lines before any Sub/Function/Dim/Enum/Type/Option)
	var top_doc := ""
	while i < lines.size():
		var lt := lines[i].strip_edges()
		if lt.begins_with("'''"):
			top_doc += _strip_doc_prefix(lt) + "\n"
			i += 1
		elif lt.begins_with("'") and top_doc != "":
			# Regular comment following doc block — stop
			break
		elif lt == "" and top_doc != "":
			top_doc += "\n"
			i += 1
		else:
			break
	m.description = top_doc.strip_edges()
	# Reset — re-parse from 0 for declarations
	i = 0
	pending_doc = ""

	while i < lines.size():
		var line := lines[i]
		var lt := line.strip_edges()

		# Accumulate ''' doc-comments
		if lt.begins_with("'''"):
			pending_doc += _strip_doc_prefix(lt) + "\n"
			i += 1
			continue

		# Option
		if lt.begins_with("Option "):
			m.options.append(lt)
			pending_doc = ""
			i += 1
			continue

		# Attribute (skip)
		if lt.begins_with("Attribute "):
			pending_doc = ""
			i += 1
			continue

		# Const
		if _match_const(lt):
			var c := _parse_const(lt, pending_doc)
			if c:
				m.constants.append(c)
			pending_doc = ""
			i += 1
			continue

		# Dim / Public / Private variable
		if _match_variable(lt):
			var v := _parse_variable(lt, pending_doc)
			if v:
				m.variables.append(v)
			pending_doc = ""
			i += 1
			continue

		# Enum
		if _match_enum(lt):
			var e := _parse_enum(lines, i, pending_doc)
			if e:
				m.enums.append(e["enum"])
				i = e["end_line"]
			pending_doc = ""
			i += 1
			continue

		# Type
		if _match_type(lt):
			var t := _parse_type(lines, i, pending_doc)
			if t:
				m.types.append(t["type"])
				i = t["end_line"]
			pending_doc = ""
			i += 1
			continue

		# Sub
		if _match_sub(lt):
			var s := _parse_sub(lt, pending_doc)
			if s:
				m.subs.append(s)
			pending_doc = ""
			# Skip to End Sub
			i += 1
			while i < lines.size() and not lines[i].strip_edges().begins_with("End Sub"):
				i += 1
			i += 1
			continue

		# Function
		if _match_function(lt):
			var f := _parse_function(lt, pending_doc)
			if f:
				m.functions.append(f)
			pending_doc = ""
			i += 1
			while i < lines.size() and not lines[i].strip_edges().begins_with("End Function"):
				i += 1
			i += 1
			continue

		# Anything else — clear pending doc
		if lt != "" and not lt.begins_with("'"):
			pending_doc = ""
		i += 1

	return m

# ── Doc-comment helpers ───────────────────────────────────────────────────
func _strip_doc_prefix(line: String) -> String:
	var s := line.strip_edges()
	if s.begins_with("'''"):
		s = s.substr(3)
	if s.begins_with(" "):
		s = s.substr(1)
	return s

func _parse_doc_tags(raw_doc: String) -> Dictionary:
	## Returns { "description": String, "params": [{name, text}], "return": String, "example": String }
	var result := {"description": "", "params": [], "return": "", "example": ""}
	var in_example := false
	var example_lines := PackedStringArray()
	for ln in raw_doc.split("\n"):
		var t := ln.strip_edges()
		if t.begins_with("@example"):
			in_example = true
			continue
		if in_example:
			if t.begins_with("@"):
				in_example = false
			else:
				example_lines.append(ln)
				continue
		if t.begins_with("@param"):
			var rest := t.substr(6).strip_edges()
			var sp := rest.find(" ")
			if sp > 0:
				result["params"].append({"name": rest.substr(0, sp), "text": rest.substr(sp + 1).strip_edges()})
			else:
				result["params"].append({"name": rest, "text": ""})
		elif t.begins_with("@return"):
			result["return"] = t.substr(7).strip_edges()
		else:
			result["description"] += t + "\n"
	result["description"] = result["description"].strip_edges()
	result["example"] = "\n".join(example_lines).strip_edges()
	return result

# ── Matchers ──────────────────────────────────────────────────────────────
static var _rx_const: RegEx
static var _rx_var: RegEx
static var _rx_enum: RegEx
static var _rx_type: RegEx
static var _rx_sub: RegEx
static var _rx_func: RegEx

func _ensure_rx() -> void:
	if _rx_const == null:
		_rx_const = RegEx.new()
		_rx_const.compile("(?i)^(Public\\s+|Private\\s+)?Const\\s+(\\w+)(\\s+As\\s+(\\w+))?\\s*=\\s*(.+)")
		_rx_var = RegEx.new()
		_rx_var.compile("(?i)^(Public|Private|Dim)\\s+(\\w+)(\\([^)]*\\))?(\\s+As\\s+(\\w+))?")
		_rx_enum = RegEx.new()
		_rx_enum.compile("(?i)^(Public\\s+|Private\\s+)?Enum\\s+(\\w+)")
		_rx_type = RegEx.new()
		_rx_type.compile("(?i)^(Public\\s+|Private\\s+)?Type\\s+(\\w+)")
		_rx_sub = RegEx.new()
		_rx_sub.compile("(?i)^(Public\\s+|Private\\s+|Static\\s+)?Sub\\s+(\\w+)\\s*\\(([^)]*)\\)")
		_rx_func = RegEx.new()
		_rx_func.compile("(?i)^(Public\\s+|Private\\s+|Static\\s+)?Function\\s+(\\w+)\\s*\\(([^)]*)\\)(\\s+As\\s+(\\w+))?")

func _match_const(lt: String) -> bool:
	_ensure_rx(); return _rx_const.search(lt) != null
func _match_variable(lt: String) -> bool:
	_ensure_rx()
	if lt.begins_with("ReDim "):
		return true
	return _rx_var.search(lt) != null
func _match_enum(lt: String) -> bool:
	_ensure_rx(); return _rx_enum.search(lt) != null
func _match_type(lt: String) -> bool:
	_ensure_rx(); return _rx_type.search(lt) != null
func _match_sub(lt: String) -> bool:
	_ensure_rx(); return _rx_sub.search(lt) != null
func _match_function(lt: String) -> bool:
	_ensure_rx(); return _rx_func.search(lt) != null

# ── Const parser ──────────────────────────────────────────────────────────
func _parse_const(lt: String, doc: String) -> Dictionary:
	_ensure_rx()
	var rm := _rx_const.search(lt)
	if not rm:
		return {}
	return {
		"name": rm.get_string(2),
		"type": rm.get_string(4) if rm.get_string(4) != "" else "Variant",
		"value": rm.get_string(5).strip_edges(),
		"doc": doc.strip_edges()
	}

# ── Variable parser ───────────────────────────────────────────────────────
func _parse_variable(lt: String, doc: String) -> Dictionary:
	_ensure_rx()
	# Handle ReDim
	if lt.begins_with("ReDim "):
		var rest := lt.substr(6).strip_edges()
		var paren := rest.find("(")
		var name := rest.substr(0, paren) if paren > 0 else rest.split(" ")[0]
		return {"name": name.strip_edges(), "scope": "Dim", "type": "Array", "doc": doc.strip_edges()}
	var rm := _rx_var.search(lt)
	if not rm:
		return {}
	var arr_suffix := rm.get_string(3)
	var vtype := rm.get_string(5) if rm.get_string(5) != "" else "Variant"
	if arr_suffix != "":
		vtype += " Array"
	return {
		"name": rm.get_string(2),
		"scope": rm.get_string(1).strip_edges() if rm.get_string(1) != "" else "Dim",
		"type": vtype,
		"doc": doc.strip_edges()
	}

# ── Enum parser ───────────────────────────────────────────────────────────
func _parse_enum(lines: PackedStringArray, start: int, doc: String) -> Dictionary:
	_ensure_rx()
	var rm := _rx_enum.search(lines[start].strip_edges())
	if not rm:
		return {}
	var en := {"name": rm.get_string(2), "members": [], "doc": doc.strip_edges()}
	var j := start + 1
	while j < lines.size():
		var el := lines[j].strip_edges()
		if el.begins_with("End Enum"):
			break
		if el != "" and not el.begins_with("'"):
			var parts := el.split("=")
			var mname := parts[0].strip_edges()
			var mval := parts[1].strip_edges() if parts.size() > 1 else ""
			en["members"].append({"name": mname, "value": mval})
		j += 1
	return {"enum": en, "end_line": j}

# ── Type parser ───────────────────────────────────────────────────────────
func _parse_type(lines: PackedStringArray, start: int, doc: String) -> Dictionary:
	_ensure_rx()
	var rm := _rx_type.search(lines[start].strip_edges())
	if not rm:
		return {}
	var tp := {"name": rm.get_string(2), "fields": [], "doc": doc.strip_edges()}
	var j := start + 1
	while j < lines.size():
		var el := lines[j].strip_edges()
		if el.begins_with("End Type"):
			break
		if el != "" and not el.begins_with("'"):
			var as_pos := el.findn(" As ")
			if as_pos > 0:
				tp["fields"].append({
					"name": el.substr(0, as_pos).strip_edges(),
					"type": el.substr(as_pos + 4).strip_edges()
				})
		j += 1
	return {"type": tp, "end_line": j}

# ── Sub parser ────────────────────────────────────────────────────────────
func _parse_sub(lt: String, doc: String) -> Dictionary:
	_ensure_rx()
	var rm := _rx_sub.search(lt)
	if not rm:
		return {}
	var scope := rm.get_string(1).strip_edges() if rm.get_string(1) != "" else ""
	var params := _parse_params(rm.get_string(3))
	var tags := _parse_doc_tags(doc)
	return {
		"name": rm.get_string(2),
		"scope": scope,
		"params": params,
		"doc": tags["description"],
		"tags": tags
	}

# ── Function parser ───────────────────────────────────────────────────────
func _parse_function(lt: String, doc: String) -> Dictionary:
	_ensure_rx()
	var rm := _rx_func.search(lt)
	if not rm:
		return {}
	var scope := rm.get_string(1).strip_edges() if rm.get_string(1) != "" else ""
	var params := _parse_params(rm.get_string(3))
	var ret := rm.get_string(5) if rm.get_string(5) != "" else "Variant"
	var tags := _parse_doc_tags(doc)
	return {
		"name": rm.get_string(2),
		"scope": scope,
		"params": params,
		"return_type": ret,
		"doc": tags["description"],
		"tags": tags
	}

# ── Parameter list parser ────────────────────────────────────────────────
func _parse_params(raw: String) -> Array:
	var params: Array = []
	if raw.strip_edges() == "":
		return params
	for chunk in raw.split(","):
		var c := chunk.strip_edges()
		var modifier := ""
		if c.begins_with("ByRef "):
			modifier = "ByRef"
			c = c.substr(6).strip_edges()
		elif c.begins_with("ByVal "):
			modifier = "ByVal"
			c = c.substr(6).strip_edges()
		elif c.begins_with("Optional "):
			modifier = "Optional"
			c = c.substr(9).strip_edges()
		var as_pos := c.findn(" As ")
		var pname: String
		var ptype: String
		if as_pos > 0:
			pname = c.substr(0, as_pos).strip_edges()
			ptype = c.substr(as_pos + 4).strip_edges()
		else:
			pname = c
			ptype = "Variant"
		params.append({"name": pname, "type": ptype, "modifier": modifier})
	return params

# ── Event handler heuristic ───────────────────────────────────────────────
func _is_event_handler(name: String) -> bool:
	# Pattern: ControlName_EventName  (contains underscore, second part is a known event)
	var parts := name.split("_")
	if parts.size() < 2:
		return false
	var event_part := parts[parts.size() - 1]
	var known_events := ["Click", "DblClick", "Change", "KeyPress", "KeyDown", "KeyUp",
		"MouseDown", "MouseUp", "MouseMove", "GotFocus", "LostFocus", "Scroll",
		"Load", "Unload", "Resize", "Paint", "Timer", "Activate", "Deactivate",
		"Initialize", "Terminate", "ItemClick", "Validate", "DragDrop", "DragOver",
		"Ready", "Process", "Input"]
	return event_part in known_events

# ══════════════════════════════════════════════════════════════════════════
#  Markdown Emitter
# ══════════════════════════════════════════════════════════════════════════
func _emit_markdown(modules: Array, out_dir: String) -> int:
	var count := 0

	# Index page
	var idx := "# API Reference\n\n"
	idx += "_Generated by VisualGasic Documentation Generator_\n\n"
	idx += "| Module | Type | Description |\n|--------|------|-------------|\n"
	for m: DocModule in modules:
		var short_desc := m.description.split("\n")[0] if m.description != "" else ""
		idx += "| [%s](%s.md) | %s | %s |\n" % [m.module_name, m.module_name, m.module_type, short_desc]
	idx += "\n---\n*%d modules documented.*\n" % modules.size()
	_write_file(out_dir.path_join("index.md"), idx)
	count += 1

	# Per-module pages
	for m: DocModule in modules:
		var md := _module_to_md(m)
		_write_file(out_dir.path_join(m.module_name + ".md"), md)
		count += 1

	return count

func _module_to_md(m: DocModule) -> String:
	var md := "# %s\n\n" % m.module_name
	md += "**Type:** %s &nbsp;|&nbsp; **File:** `%s`\n\n" % [m.module_type, m.file_path]
	if m.description != "":
		md += m.description + "\n\n"

	md += "---\n\n"

	# Constants
	if m.constants.size() > 0:
		md += "## Constants\n\n| Name | Type | Value | Description |\n|------|------|-------|-------------|\n"
		for c in m.constants:
			md += "| `%s` | %s | `%s` | %s |\n" % [c["name"], c["type"], c["value"], c.get("doc", "")]
		md += "\n"

	# Enums
	if m.enums.size() > 0:
		md += "## Enums\n\n"
		for e in m.enums:
			md += "### %s\n\n" % e["name"]
			if e.get("doc", "") != "":
				md += e["doc"] + "\n\n"
			md += "| Member | Value |\n|--------|-------|\n"
			for mem in e["members"]:
				md += "| `%s` | %s |\n" % [mem["name"], mem.get("value", "")]
			md += "\n"

	# Types
	if m.types.size() > 0:
		md += "## Types\n\n"
		for t in m.types:
			md += "### %s\n\n" % t["name"]
			if t.get("doc", "") != "":
				md += t["doc"] + "\n\n"
			md += "| Field | Type |\n|-------|------|\n"
			for fld in t["fields"]:
				md += "| `%s` | %s |\n" % [fld["name"], fld["type"]]
			md += "\n"

	# Variables
	if m.variables.size() > 0:
		md += "## Variables\n\n| Name | Scope | Type | Description |\n|------|-------|------|-------------|\n"
		for v in m.variables:
			md += "| `%s` | %s | %s | %s |\n" % [v["name"], v.get("scope", "Dim"), v["type"], v.get("doc", "")]
		md += "\n"

	# Subs
	if m.subs.size() > 0:
		md += "## Subs\n\n"
		for s in m.subs:
			md += _routine_to_md(s, "Sub")
		md += "\n"

	# Functions
	if m.functions.size() > 0:
		md += "## Functions\n\n"
		for f in m.functions:
			md += _routine_to_md(f, "Function")
		md += "\n"

	md += "---\n*Generated by VisualGasic Documentation Generator*\n"
	return md

func _routine_to_md(r: Dictionary, kind: String) -> String:
	var sig := ""
	if r.get("scope", "") != "":
		sig += r["scope"] + " "
	sig += kind + " " + r["name"] + "("
	var pstrs: PackedStringArray = []
	for p in r["params"]:
		var ps := ""
		if p.get("modifier", "") != "":
			ps += p["modifier"] + " "
		ps += p["name"] + " As " + p["type"]
		pstrs.append(ps)
	sig += ", ".join(pstrs) + ")"
	if kind == "Function" and r.get("return_type", "") != "":
		sig += " As " + r["return_type"]

	var md := "### `%s`\n\n" % r["name"]
	md += "```vb\n%s\n```\n\n" % sig

	var tags: Dictionary = r.get("tags", {})
	if r.get("doc", "") != "":
		md += r["doc"] + "\n\n"

	# @param tags
	if tags.get("params", []).size() > 0:
		md += "**Parameters:**\n\n| Name | Description |\n|------|-------------|\n"
		for pt in tags["params"]:
			md += "| `%s` | %s |\n" % [pt["name"], pt["text"]]
		md += "\n"

	# @return
	if tags.get("return", "") != "":
		md += "**Returns:** %s\n\n" % tags["return"]

	# @example
	if tags.get("example", "") != "":
		md += "**Example:**\n```vb\n%s\n```\n\n" % tags["example"]

	return md

# ══════════════════════════════════════════════════════════════════════════
#  HTML Emitter
# ══════════════════════════════════════════════════════════════════════════
func _emit_html(modules: Array, out_dir: String) -> int:
	var count := 0

	# Index page
	var html := _html_head("API Reference")
	html += "<h1>API Reference</h1>\n<p><em>Generated by VisualGasic Documentation Generator</em></p>\n"
	html += "<table>\n<tr><th>Module</th><th>Type</th><th>Description</th></tr>\n"
	for m: DocModule in modules:
		var short_desc := m.description.split("\n")[0] if m.description != "" else ""
		html += "<tr><td><a href=\"%s.html\">%s</a></td><td>%s</td><td>%s</td></tr>\n" % [
			m.module_name, m.module_name, m.module_type, _esc(short_desc)]
	html += "</table>\n<hr>\n<p><em>%d modules documented.</em></p>\n" % modules.size()
	html += _html_foot()
	_write_file(out_dir.path_join("index.html"), html)
	count += 1

	# Per-module pages
	for m: DocModule in modules:
		var pg := _module_to_html(m)
		_write_file(out_dir.path_join(m.module_name + ".html"), pg)
		count += 1

	return count

func _html_head(title: String) -> String:
	return """<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>%s</title>
<style>
body{font-family:'Segoe UI',Tahoma,sans-serif;margin:2em;background:#f5f3ec;color:#222}
h1{color:#003399}h2{color:#336}h3{margin-top:1.5em}
table{border-collapse:collapse;width:100%%}
th,td{border:1px solid #999;padding:4px 8px;text-align:left}
th{background:#ddd}
code,pre{background:#eee;padding:2px 4px;font-family:'Courier New',monospace}
pre{padding:8px;overflow-x:auto}
a{color:#003399}
.sig{background:#e8e6d8;padding:6px;border:1px solid #bbb;font-family:'Courier New',monospace}
</style></head><body>
""" % _esc(title)

func _html_foot() -> String:
	return "</body></html>\n"

func _module_to_html(m: DocModule) -> String:
	var h := _html_head(m.module_name)
	h += "<p><a href=\"index.html\">← Back to Index</a></p>\n"
	h += "<h1>%s</h1>\n" % _esc(m.module_name)
	h += "<p><strong>Type:</strong> %s &nbsp;|&nbsp; <strong>File:</strong> <code>%s</code></p>\n" % [m.module_type, _esc(m.file_path)]
	if m.description != "":
		h += "<p>%s</p>\n" % _esc(m.description)

	# Constants
	if m.constants.size() > 0:
		h += "<h2>Constants</h2>\n<table><tr><th>Name</th><th>Type</th><th>Value</th><th>Description</th></tr>\n"
		for c in m.constants:
			h += "<tr><td><code>%s</code></td><td>%s</td><td><code>%s</code></td><td>%s</td></tr>\n" % [
				_esc(c["name"]), _esc(c["type"]), _esc(c["value"]), _esc(c.get("doc", ""))]
		h += "</table>\n"

	# Enums
	for e in m.enums:
		h += "<h2>Enum %s</h2>\n" % _esc(e["name"])
		if e.get("doc", "") != "":
			h += "<p>%s</p>\n" % _esc(e["doc"])
		h += "<table><tr><th>Member</th><th>Value</th></tr>\n"
		for mem in e["members"]:
			h += "<tr><td><code>%s</code></td><td>%s</td></tr>\n" % [_esc(mem["name"]), _esc(mem.get("value", ""))]
		h += "</table>\n"

	# Types
	for t in m.types:
		h += "<h2>Type %s</h2>\n" % _esc(t["name"])
		if t.get("doc", "") != "":
			h += "<p>%s</p>\n" % _esc(t["doc"])
		h += "<table><tr><th>Field</th><th>Type</th></tr>\n"
		for fld in t["fields"]:
			h += "<tr><td><code>%s</code></td><td>%s</td></tr>\n" % [_esc(fld["name"]), _esc(fld["type"])]
		h += "</table>\n"

	# Variables
	if m.variables.size() > 0:
		h += "<h2>Variables</h2>\n<table><tr><th>Name</th><th>Scope</th><th>Type</th><th>Description</th></tr>\n"
		for v in m.variables:
			h += "<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td>%s</td></tr>\n" % [
				_esc(v["name"]), _esc(v.get("scope", "Dim")), _esc(v["type"]), _esc(v.get("doc", ""))]
		h += "</table>\n"

	# Subs
	if m.subs.size() > 0:
		h += "<h2>Subs</h2>\n"
		for s in m.subs:
			h += _routine_to_html(s, "Sub")

	# Functions
	if m.functions.size() > 0:
		h += "<h2>Functions</h2>\n"
		for f in m.functions:
			h += _routine_to_html(f, "Function")

	h += "<hr>\n<p><em>Generated by VisualGasic Documentation Generator</em></p>\n"
	h += _html_foot()
	return h

func _routine_to_html(r: Dictionary, kind: String) -> String:
	var sig := ""
	if r.get("scope", "") != "":
		sig += r["scope"] + " "
	sig += kind + " " + r["name"] + "("
	var pstrs: PackedStringArray = []
	for p in r["params"]:
		var ps := ""
		if p.get("modifier", "") != "":
			ps += p["modifier"] + " "
		ps += p["name"] + " As " + p["type"]
		pstrs.append(ps)
	sig += ", ".join(pstrs) + ")"
	if kind == "Function" and r.get("return_type", "") != "":
		sig += " As " + r["return_type"]

	var h := "<h3><code>%s</code></h3>\n" % _esc(r["name"])
	h += "<div class=\"sig\">%s</div>\n" % _esc(sig)

	if r.get("doc", "") != "":
		h += "<p>%s</p>\n" % _esc(r["doc"])

	var tags: Dictionary = r.get("tags", {})
	if tags.get("params", []).size() > 0:
		h += "<p><strong>Parameters:</strong></p>\n<table><tr><th>Name</th><th>Description</th></tr>\n"
		for pt in tags["params"]:
			h += "<tr><td><code>%s</code></td><td>%s</td></tr>\n" % [_esc(pt["name"]), _esc(pt["text"])]
		h += "</table>\n"
	if tags.get("return", "") != "":
		h += "<p><strong>Returns:</strong> %s</p>\n" % _esc(tags["return"])
	if tags.get("example", "") != "":
		h += "<p><strong>Example:</strong></p>\n<pre>%s</pre>\n" % _esc(tags["example"])

	return h

func _esc(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")

# ── File writer ───────────────────────────────────────────────────────────
func _write_file(path: String, content: String) -> void:
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa:
		fa.store_string(content)
		fa.close()
