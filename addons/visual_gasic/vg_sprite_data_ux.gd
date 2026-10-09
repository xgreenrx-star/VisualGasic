@tool
extends RefCounted
## Shared *Sprite / *Vector Data editor UX helpers (fold policy, migrate, draw stubs, live refresh).

const SpriteResolver := preload("res://addons/visual_gasic/vg_sprite_data_resolver.gd")
const SpriteSync := preload("res://addons/visual_gasic/vg_sprite_data_sync.gd")
const VectorResolver := preload("res://addons/visual_gasic/vg_vector_data_resolver.gd")
const WireResolver := preload("res://addons/visual_gasic/vg_wire_model_resolver.gd")
const Palettes := preload("res://addons/visual_gasic/vg_sprite_data_palettes.gd")

const SETTING_FOLD_POLICY := "vg/editor/sprite_data_fold"
## on_change | on_open | never
const FOLD_ON_CHANGE := "on_change"
const FOLD_ON_OPEN := "on_open"
const FOLD_NEVER := "never"


static func fold_policy() -> String:
	var v := str(ProjectSettings.get_setting(SETTING_FOLD_POLICY, FOLD_ON_CHANGE)).strip_edges().to_lower()
	if v == FOLD_ON_OPEN or v == FOLD_NEVER or v == FOLD_ON_CHANGE:
		return v
	return FOLD_ON_CHANGE


static func should_auto_fold_on_change() -> bool:
	return fold_policy() == FOLD_ON_CHANGE


static func should_auto_fold_on_open() -> bool:
	var p := fold_policy()
	return p == FOLD_ON_CHANGE or p == FOLD_ON_OPEN


## Indent header + Data rows under each *Sprite label so CodeEdit can fold them.
## Returns number of blocks that needed migration.
static func migrate_sprite_indents(code_edit: CodeEdit) -> int:
	if code_edit == null:
		return 0
	return _migrate_indents(code_edit, SpriteResolver.enumerate_blocks(code_edit.text))


## Indent *Vector / wire Data rows under their labels.
static func migrate_vector_indents(code_edit: CodeEdit) -> int:
	if code_edit == null:
		return 0
	var src := code_edit.get_text()
	var blocks: Array = VectorResolver.enumerate_blocks(src)
	blocks.append_array(WireResolver.enumerate_blocks(src))
	return _migrate_indents(code_edit, blocks)


static func _migrate_indents(code_edit: CodeEdit, blocks: Array) -> int:
	var changed := 0
	var edits: Dictionary = {}
	for block in blocks:
		var label_line: int = int(block.get("label_line", -1))
		var end_line: int = int(block.get("end_line", label_line))
		if label_line < 0 or end_line <= label_line:
			continue
		var label_text := code_edit.get_line(label_line)
		var prefix := label_text.substr(0, label_text.length() - label_text.strip_edges(true, false).length())
		var label_depth := _indent_depth(prefix, code_edit.indent_size)
		var needs := false
		for li in range(label_line + 1, end_line + 1):
			var raw := code_edit.get_line(li)
			if raw.strip_edges().is_empty():
				continue
			if _indent_depth(raw, code_edit.indent_size) <= label_depth:
				edits[li] = prefix + "\t" + raw.strip_edges(true, false)
				needs = true
		if needs:
			changed += 1
	if changed > 0:
		var was_guarded := SpriteSync.is_sync_guarded(code_edit)
		code_edit.begin_complex_operation()
		code_edit.set_meta(SpriteSync.META_GUARD, true)
		for line in edits:
			code_edit.set_line(line, edits[line])
		if not was_guarded:
			code_edit.remove_meta(SpriteSync.META_GUARD)
		code_edit.end_complex_operation()
		code_edit.text_changed.emit()
	return changed


static func _indent_depth(text: String, tab_size: int) -> int:
	var depth := 0
	for character in text:
		if character == "\t":
			depth += tab_size - depth % tab_size
		elif character == " ":
			depth += 1
		else:
			break
	return depth


static func data_blocks(source: String) -> Array:
	var blocks := SpriteResolver.enumerate_blocks(source)
	blocks.append_array(VectorResolver.enumerate_blocks(source))
	blocks.append_array(WireResolver.enumerate_blocks(source))
	return blocks


static func all_data_folded(code_edit: CodeEdit) -> bool:
	var blocks := data_blocks(code_edit.text)
	if blocks.is_empty():
		return false
	for block in blocks:
		if not code_edit.is_line_folded(int(block["label_line"])):
			return false
	return true


static func set_data_folded(code_edit: CodeEdit, folded: bool) -> int:
	var blocks := data_blocks(code_edit.text)
	if folded:
		for block in blocks:
			var label_line := int(block["label_line"])
			if code_edit.get_caret_line() > label_line and code_edit.get_caret_line() <= int(block["end_line"]):
				code_edit.set_caret_line(label_line)
				code_edit.set_caret_column(0)
				break
	var changed := 0
	for block in blocks:
		var line := int(block["label_line"])
		if folded and code_edit.can_fold_line(line) and not code_edit.is_line_folded(line):
			code_edit.fold_line(line)
			changed += 1
		elif not folded and code_edit.is_line_folded(line):
			code_edit.unfold_line(line)
			changed += 1
	return changed


static func migrate_all_indents(code_edit: CodeEdit) -> int:
	if code_edit == null:
		return 0
	return _migrate_indents(code_edit, data_blocks(code_edit.text))


## Variable names assigned via DataToArray("Label") in source.
static func find_data_to_array_vars(source: String, label: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if source.is_empty() or label.is_empty():
		return out
	var re := RegEx.new()
	# Dim x = DataToArray("Foo") / x = DataToArray("Foo") / Set x = …
	re.compile("(?i)\\b([A-Za-z_]\\w*)\\s*=\\s*DataToArray\\s*\\(\\s*\"%s\"\\s*\\)" % label)
	for m in re.search_all(source):
		var name := m.get_string(1)
		if not out.has(name):
			out.append(name)
	return out


static func suggest_raw_var_name(label: String) -> String:
	var base := label
	if base.to_lower().ends_with("sprite"):
		base = base.substr(0, base.length() - 6)
	if base.is_empty():
		base = "sprite"
	return base.substr(0, 1).to_lower() + base.substr(1) + "Raw"


## Insert Dim + LoadSprites cache + DrawDataSprite stub if missing.
## Returns {ok, message, load_line, draw_line}.
static func insert_draw_helpers(code_edit: CodeEdit, label: String, scale: int = 2) -> Dictionary:
	var result := {"ok": false, "message": "", "load_line": -1, "draw_line": -1}
	if code_edit == null or label.is_empty():
		result["message"] = "No editor / label"
		return result
	var src := code_edit.get_text()
	var existing := find_data_to_array_vars(src, label)
	var var_name := existing[0] if existing.size() > 0 else suggest_raw_var_name(label)
	var scale_i := clampi(scale, 1, 16)

	# Ensure module Dim
	if not _has_dim_for(src, var_name):
		var dim_line := _find_module_dim_insert_line(src)
		code_edit.insert_line_at(dim_line, "Dim %s As Variant" % var_name)
		src = code_edit.get_text()

	# Ensure load assignment
	if existing.is_empty():
		var load_line := _ensure_load_assignment(code_edit, var_name, label)
		result["load_line"] = load_line
		src = code_edit.get_text()
		_ensure_call_load_sprites(code_edit)
	else:
		result["load_line"] = _find_line_containing(src, "DataToArray(\"%s\")" % label)

	# Ensure DrawDataSprite in _Draw
	if not _source_has_draw_for(src, var_name, label):
		var draw_line := _ensure_draw_call(code_edit, var_name, scale_i)
		result["draw_line"] = draw_line
	else:
		result["draw_line"] = _find_line_containing(code_edit.get_text(), "DrawDataSprite %s" % var_name)

	result["ok"] = true
	result["message"] = "Wired %s → DrawDataSprite" % var_name
	result["var_name"] = var_name
	return result


static func build_array_literal(section: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(str(int(section.get("w", 0))))
	parts.append(str(int(section.get("h", 0))))
	parts.append(str(int(section.get("transparent", 0))))
	parts.append(str(int(section.get("palette_id", 0))))
	var pixels: PackedInt32Array = section.get("pixels", PackedInt32Array())
	for p in pixels:
		parts.append(str(int(p)))
	return "Array(" + ", ".join(parts) + ")"


static func palette_name(palette_id: int) -> String:
	var id := clampi(palette_id, 0, Palettes.PALETTE_NAMES.size() - 1)
	return str(Palettes.PALETTE_NAMES[id])


static func _has_dim_for(source: String, var_name: String) -> bool:
	var re := RegEx.new()
	re.compile("(?i)\\bDim\\s+%s\\b" % var_name)
	return re.search(source) != null


static func _source_has_draw_for(source: String, var_name: String, label: String) -> bool:
	if source.findn("DrawDataSprite %s" % var_name) >= 0:
		return true
	if source.findn("DrawDataSprite(%s" % var_name) >= 0:
		return true
	# Already drawing via another var for this label is fine.
	for v in find_data_to_array_vars(source, label):
		if source.findn("DrawDataSprite %s" % v) >= 0:
			return true
	return false


static func _find_module_dim_insert_line(source: String) -> int:
	var lines := source.split("\n")
	var last_dim := -1
	for i in lines.size():
		var t := lines[i].strip_edges()
		var tl := t.to_lower()
		if tl.begins_with("dim ") or tl.begins_with("public ") or tl.begins_with("private "):
			if not tl.begins_with("sub ") and not tl.begins_with("function "):
				last_dim = i
		if tl.begins_with("sub ") or tl.begins_with("function ") or tl.begins_with("property "):
			if last_dim >= 0:
				return last_dim + 1
			return i
	return maxi(0, last_dim + 1)


static func _ensure_load_assignment(code_edit: CodeEdit, var_name: String, label: String) -> int:
	var src := code_edit.get_text()
	var lines := src.split("\n")
	# Prefer existing LoadSprites / Form_Load / _Ready
	for prefer in ["LoadSprites", "Form_Load", "_Ready", "Ready"]:
		var range := _find_proc_range(lines, prefer)
		if range.x >= 0:
			var insert_at := range.x + 1
			while insert_at < range.y and lines[insert_at].strip_edges().is_empty():
				insert_at += 1
			var stmt := "\t%s = DataToArray(\"%s\")" % [var_name, label]
			code_edit.insert_line_at(insert_at, stmt)
			return insert_at
	# Create LoadSprites before first Sub if possible
	var insert_sub := _find_module_dim_insert_line(src)
	code_edit.insert_line_at(insert_sub, "")
	code_edit.insert_line_at(insert_sub + 1, "Sub LoadSprites()")
	code_edit.insert_line_at(insert_sub + 2, "\t%s = DataToArray(\"%s\")" % [var_name, label])
	code_edit.insert_line_at(insert_sub + 3, "End Sub")
	return insert_sub + 2


static func _ensure_call_load_sprites(code_edit: CodeEdit) -> void:
	var src := code_edit.get_text()
	if src.findn("LoadSprites") < 0:
		return
	if src.findn("Call LoadSprites") >= 0 or src.findn("LoadSprites()") >= 0:
		# Already invoked somewhere (Call or as expression).
		if src.findn("Call LoadSprites") >= 0:
			return
		# Bare LoadSprites() call inside a Sub counts.
		var re_call := RegEx.new()
		re_call.compile("(?i)^\\s*LoadSprites\\s*\\(")
		for line in src.split("\n"):
			if re_call.search(line) != null:
				return
	var lines := src.split("\n")
	for prefer in ["_Ready", "Ready", "Form_Load"]:
		var range := _find_proc_range(lines, prefer)
		if range.x >= 0:
			code_edit.insert_line_at(range.x + 1, "\tCall LoadSprites()")
			return


static func _ensure_draw_call(code_edit: CodeEdit, var_name: String, scale: int) -> int:
	var src := code_edit.get_text()
	var lines := src.split("\n")
	var range := _find_proc_range(lines, "_Draw")
	if range.x < 0:
		range = _find_proc_range(lines, "Draw")
	var stmt := "\tDrawDataSprite %s, 0, 0, %d" % [var_name, scale]
	if range.x >= 0:
		var insert_at := range.y  # before End Sub
		code_edit.insert_line_at(insert_at, stmt)
		return insert_at
	# Append a _Draw stub
	var at := code_edit.get_line_count()
	code_edit.insert_line_at(at, "")
	code_edit.insert_line_at(at + 1, "Sub _Draw()")
	code_edit.insert_line_at(at + 2, stmt)
	code_edit.insert_line_at(at + 3, "End Sub")
	return at + 2


static func _find_proc_range(lines: PackedStringArray, proc_name: String) -> Vector2i:
	var re := RegEx.new()
	re.compile("(?i)^\\s*(?:Public\\s+|Private\\s+)?Sub\\s+%s\\s*\\(" % proc_name)
	var start := -1
	for i in lines.size():
		if re.search(lines[i]) != null:
			start = i
			break
	if start < 0:
		return Vector2i(-1, -1)
	for j in range(start + 1, lines.size()):
		if lines[j].strip_edges().to_lower() == "end sub":
			return Vector2i(start, j)
	return Vector2i(start, lines.size())


static func _find_line_containing(source: String, needle: String) -> int:
	var lines := source.split("\n")
	for i in lines.size():
		if lines[i].findn(needle) >= 0:
			return i
	return -1
