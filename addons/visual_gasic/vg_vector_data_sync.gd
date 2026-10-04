@tool
extends RefCounted
## Rewrites labeled vector Data rows in a CodeEdit from edited shape models.

const Resolver := preload("res://addons/visual_gasic/vg_vector_data_resolver.gd")

const META_GUARD := "vg_vector_sync_guard"


static func apply_shapes(code_edit: CodeEdit, section: Dictionary, shapes: Array) -> bool:
	if code_edit == null or section.is_empty():
		return false
	var start_line: int = section.get("data_start_line", -1)
	var end_line: int = section.get("data_end_line", -1)
	if start_line < 0 or end_line < start_line:
		return false
	if shapes.size() < 1 or shapes.size() > Resolver.MAX_SHAPES:
		return false

	var old_count := end_line - start_line + 1
	var new_count := shapes.size()

	# Keep shape rows indented under the label so the block stays foldable.
	var prefix := "\t"
	var header_line: int = int(section.get("header_line", start_line - 1))
	if header_line >= 0 and header_line < code_edit.get_line_count():
		var hp := _indent_prefix(code_edit.get_line(header_line))
		if not hp.is_empty():
			prefix = hp
		elif start_line > 0:
			var lp := _indent_prefix(code_edit.get_line(maxi(0, int(section.get("label_line", 0)))))
			prefix = "\t" if lp.is_empty() else lp + "\t"

	code_edit.set_meta(META_GUARD, true)
	while old_count > new_count:
		code_edit.remove_line_at(end_line)
		end_line -= 1
		old_count -= 1
	while old_count < new_count:
		end_line += 1
		code_edit.insert_line_at(end_line, prefix + Resolver.format_shape_line(shapes[old_count]))
		old_count += 1
	for i in new_count:
		code_edit.set_line(start_line + i, prefix + Resolver.format_shape_line(shapes[i]))
	code_edit.remove_meta(META_GUARD)
	if code_edit.has_signal("text_changed"):
		code_edit.text_changed.emit()
	return true


## Rewrite header + shape rows (view size / grid / shapes) for a labeled block.
static func apply_section(
	code_edit: CodeEdit,
	section: Dictionary,
	view_w: int,
	view_h: int,
	grid_step: int,
	shapes: Array
) -> bool:
	if code_edit == null or section.is_empty():
		return false
	view_w = clampi(view_w, 1, Resolver.MAX_VIEW)
	view_h = clampi(view_h, 1, Resolver.MAX_VIEW)
	grid_step = maxi(0, grid_step)
	if shapes.size() > Resolver.MAX_SHAPES:
		return false
	var work_shapes: Array = shapes
	if work_shapes.is_empty():
		work_shapes = [default_shape(view_w, view_h)]

	var header_line: int = int(section.get("header_line", -1))
	var old_end: int = int(section.get("data_end_line", header_line))
	if header_line < 0 or old_end < header_line:
		return false

	var prefix := _indent_prefix(code_edit.get_line(header_line))
	if prefix.is_empty():
		prefix = "\t"
	var new_lines: PackedStringArray = PackedStringArray()
	new_lines.append(prefix + Resolver.format_header_line(view_w, view_h, grid_step))
	for shape in work_shapes:
		new_lines.append(prefix + Resolver.format_shape_line(shape))

	var old_count := old_end - header_line + 1
	var new_count := new_lines.size()
	code_edit.set_meta(META_GUARD, true)
	while old_count > new_count:
		code_edit.remove_line_at(old_end)
		old_end -= 1
		old_count -= 1
	while old_count < new_count:
		old_end += 1
		code_edit.insert_line_at(old_end, new_lines[old_count])
		old_count += 1
	for i in new_count:
		code_edit.set_line(header_line + i, new_lines[i])
	code_edit.remove_meta(META_GUARD)
	if code_edit.has_signal("text_changed"):
		code_edit.text_changed.emit()
	return true


static func insert_new_block(
	code_edit: CodeEdit,
	caret_line: int,
	label: String,
	view_w: int = 64,
	view_h: int = 64,
	grid_step: int = 4
) -> Dictionary:
	var out := {"ok": false, "error": "", "section": {}, "label_line": -1}
	if code_edit == null:
		out["error"] = "No code editor"
		return out
	var lbl := normalize_label(label)
	var err := validate_new_label(code_edit.text, lbl)
	if not err.is_empty():
		out["error"] = err
		return out
	view_w = clampi(view_w, 1, Resolver.MAX_VIEW)
	view_h = clampi(view_h, 1, Resolver.MAX_VIEW)
	grid_step = maxi(0, grid_step)

	var shape := default_shape(view_w, view_h)
	var lines: PackedStringArray = PackedStringArray()
	lines.append(lbl + ":")
	lines.append("\t" + Resolver.format_header_line(view_w, view_h, grid_step))
	lines.append("\t" + Resolver.format_shape_line(shape))

	var line := clampi(caret_line, 0, code_edit.get_line_count())
	code_edit.set_meta(META_GUARD, true)
	for i in range(lines.size() - 1, -1, -1):
		code_edit.insert_line_at(line, lines[i])
	var after := line + lines.size()
	if after < code_edit.get_line_count():
		var next_txt := code_edit.get_line(after).strip_edges()
		if not next_txt.is_empty():
			code_edit.insert_line_at(after, "")
	code_edit.remove_meta(META_GUARD)
	code_edit.set_caret_line(line)
	code_edit.set_caret_column(0)
	if code_edit.has_signal("text_changed"):
		code_edit.text_changed.emit()

	var sec := Resolver.resolve_at_line(code_edit.text, line)
	if sec.is_empty():
		out["error"] = "Inserted block but could not resolve it"
		return out
	out["ok"] = true
	out["section"] = sec
	out["label_line"] = line
	return out


static func default_shape(view_w: int, view_h: int) -> Dictionary:
	var margin := maxf(4.0, float(mini(view_w, view_h)) * 0.15)
	return {
		"type": "LINE",
		"points": PackedVector2Array([
			Vector2(margin, float(view_h) * 0.5),
			Vector2(float(view_w) - margin, float(view_h) * 0.5),
		]),
		"stroke_r": 255, "stroke_g": 255, "stroke_b": 255, "stroke_a": 255, "stroke_w": 2.0,
	}


static func normalize_label(label: String) -> String:
	var lbl := label.strip_edges()
	if lbl.ends_with(":"):
		lbl = lbl.substr(0, lbl.length() - 1).strip_edges()
	return lbl


static func is_valid_label(label: String) -> bool:
	var lbl := normalize_label(label)
	if lbl.is_empty():
		return false
	var re := RegEx.new()
	re.compile("^[A-Za-z_]\\w*$")
	return re.search(lbl) != null and Resolver.is_vector_label(lbl)


static func validate_new_label(source: String, label: String) -> String:
	var lbl := normalize_label(label)
	if not is_valid_label(lbl):
		return "Label must be an identifier ending with Vector (e.g. ShipOutlineVector)"
	for b in Resolver.enumerate_blocks(source):
		if str(b.get("label", "")).to_lower() == lbl.to_lower():
			return "A vector block named %s already exists" % lbl
	var lines := source.split("\n")
	var label_re := RegEx.new()
	label_re.compile("^\\s*([A-Za-z_]\\w*)\\s*:\\s*(?:'.*)?$")
	for line in lines:
		var m := label_re.search(line)
		if m != null and m.get_string(1).to_lower() == lbl.to_lower():
			return "Label %s is already used in this file" % lbl
	return ""


static func suggest_label(source: String) -> String:
	const DEFAULT_LABEL := "ArtVector"
	var used: Dictionary = {}
	var label_re := RegEx.new()
	label_re.compile("^\\s*([A-Za-z_]\\w*)\\s*:\\s*(?:'.*)?$")
	for line in source.split("\n"):
		var m := label_re.search(line)
		if m != null:
			used[m.get_string(1).to_lower()] = true
	if not used.has(DEFAULT_LABEL.to_lower()):
		return DEFAULT_LABEL
	var n := 2
	while used.has(("%s%d" % [DEFAULT_LABEL, n]).to_lower()):
		n += 1
	return "%s%d" % [DEFAULT_LABEL, n]


static func is_sync_guarded(code_edit: CodeEdit) -> bool:
	return code_edit != null and code_edit.has_meta(META_GUARD)


static func _indent_prefix(line: String) -> String:
	var i := 0
	while i < line.length():
		var ch := line[i]
		if ch != "\t" and ch != " ":
			break
		i += 1
	if i <= 0:
		return ""
	return line.substr(0, i)
