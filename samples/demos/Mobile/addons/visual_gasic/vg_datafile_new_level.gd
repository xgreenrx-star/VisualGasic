@tool
extends RefCounted
## Create a new labeled DataFile level block + grid file on disk.

const GridIO := preload("res://addons/visual_gasic/vg_datafile_grid_io.gd")
const DataFileResolver := preload("res://addons/visual_gasic/vg_datafile_resolver.gd")
const Sniff := preload("res://addons/visual_gasic/vg_datafile_sniff.gd")

const DEFAULT_W := 20
const DEFAULT_H := 12
const MAX_DIM := 512

static var _label_valid: RegEx


static func default_label() -> String:
	return "LevelTiles"


static func suggest_from_source(source: String, caret_line: int) -> Dictionary:
	var blocks: Array = DataFileResolver.enumerate_datafile_blocks(source)
	var anchor: Dictionary = {}
	var on_datafile_line := false
	for b in blocks:
		if int(b.get("data_line", -1)) == caret_line:
			on_datafile_line = true
			break
	for b in blocks:
		var dl := int(b.get("data_line", -1))
		if on_datafile_line:
			if dl < caret_line:
				anchor = b
		elif dl <= caret_line:
			anchor = b
	if anchor.is_empty() and blocks.size() > 0:
		anchor = blocks[blocks.size() - 1]

	var prev_label := str(anchor.get("label", ""))
	var prev_path := str(anchor.get("res_path", ""))
	var sniff: Dictionary = anchor.get("sniff", {})

	var label := _next_identifier(prev_label if not prev_label.is_empty() else default_label())
	var path := _next_file_path(
		prev_path if not prev_path.is_empty() else default_path_for_label(label)
	)
	var w := int(sniff.get("width", 0))
	var h := int(sniff.get("height", 0))
	if w <= 0:
		w = DEFAULT_W
	if h <= 0:
		h = DEFAULT_H
	var as_vgd := str(sniff.get("kind_name", "")) == "vgd" or path.ends_with(".vgd")
	return {
		"label": label,
		"path": path,
		"width": w,
		"height": h,
		"as_vgd": as_vgd,
	}


static func _next_identifier(name: String) -> String:
	var base := name.strip_edges()
	if base.is_empty():
		return default_label()
	var re := RegEx.new()
	re.compile("^(\\D.*?)(\\d+)$")
	var m := re.search(base)
	if m:
		return m.get_string(1) + str(int(m.get_string(2)) + 1)
	return base + "2"


static func _next_file_path(path: String) -> String:
	if path.is_empty():
		return default_path_for_label(default_label())
	var dir := path.get_base_dir()
	var ext := path.get_extension()
	if ext.is_empty():
		ext = "csv"
	var file_base := path.get_file().get_basename()
	var stem := file_base
	var num := 2
	var re := RegEx.new()
	re.compile("^(\\D.*?)(\\d+)$")
	var m := re.search(file_base)
	if m:
		stem = m.get_string(1)
		num = int(m.get_string(2)) + 1
	if dir.is_empty():
		return stem + str(num) + "." + ext
	return dir.path_join(stem + str(num) + "." + ext)


static func default_path_for_label(label: String) -> String:
	var stem := label.strip_edges()
	if stem.is_empty():
		stem = "level"
	return "res://data/" + stem.to_lower() + ".csv"


static func is_valid_label(label: String) -> bool:
	if _label_valid == null:
		_label_valid = RegEx.new()
		_label_valid.compile("^[A-Za-z_]\\w*$")
	return _label_valid.search(label.strip_edges()) != null


static func make_empty_cells(width: int, height: int, fill: int = 0) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(maxi(1, width) * maxi(1, height))
	for i in cells.size():
		cells[i] = fill & 0xFF
	return cells


static func create_grid_file(abs_path: String, width: int, height: int, as_vgd: bool) -> Dictionary:
	var out := {"ok": false, "error": ""}
	width = clampi(width, 1, MAX_DIM)
	height = clampi(height, 1, MAX_DIM)
	var cells := make_empty_cells(width, height, 0)
	var ok := false
	if as_vgd or abs_path.get_extension().to_lower() == "vgd":
		ok = GridIO.save_vgd_u8(abs_path, width, height, cells)
	else:
		ok = GridIO.save_csv(abs_path, width, height, cells)
	if not ok:
		out["error"] = "Could not write " + abs_path
		return out
	out["ok"] = true
	out["abs_path"] = abs_path
	out["width"] = width
	out["height"] = height
	return out


static func insert_source_block(code_edit: CodeEdit, caret_line: int, label: String, res_path: String) -> int:
	if code_edit == null:
		return -1
	var line := clampi(caret_line, 0, code_edit.get_line_count())
	var block := label.strip_edges() + ":\n" + 'DataFile "' + res_path + '"'
	var parts: PackedStringArray = block.split("\n")
	for i in range(parts.size() - 1, -1, -1):
		code_edit.insert_line_at(line, parts[i])
	code_edit.set_caret_line(line)
	code_edit.set_caret_column(0)
	return line


static func build_ref(label: String, res_path: String, label_line: int) -> Dictionary:
	var abs_path := ProjectSettings.globalize_path(res_path) if res_path.begins_with("res://") else res_path
	return {
		"label": label,
		"label_line": label_line,
		"data_line": label_line + 1,
		"path": res_path,
		"res_path": res_path,
		"abs_path": abs_path,
		"sniff": Sniff.sniff_path(abs_path),
	}


static func create_level(
	code_edit: CodeEdit,
	label: String,
	res_path: String,
	width: int,
	height: int,
	as_vgd: bool,
	caret_line: int = -1
) -> Dictionary:
	var out := {"ok": false, "error": "", "ref": {}, "label_line": -1}
	if code_edit == null:
		out["error"] = "No code editor"
		return out
	var lbl := label.strip_edges()
	if not is_valid_label(lbl):
		out["error"] = "Invalid label (use letters, numbers, underscore; must start with letter or _)"
		return out
	if res_path.is_empty():
		out["error"] = "Path is required"
		return out
	if not res_path.begins_with("res://") and not res_path.begins_with("user://"):
		res_path = "res://" + res_path.trim_prefix("./")
	var abs_path := ProjectSettings.globalize_path(res_path) if res_path.begins_with("res://") else res_path
	if as_vgd and not res_path.ends_with(".vgd"):
		res_path = res_path.get_basename() + ".vgd"
		abs_path = ProjectSettings.globalize_path(res_path)
	elif not as_vgd and not res_path.ends_with(".csv"):
		res_path = res_path.get_basename() + ".csv"
		abs_path = ProjectSettings.globalize_path(res_path)
	var file_result := create_grid_file(abs_path, width, height, as_vgd)
	if not bool(file_result.get("ok", false)):
		out["error"] = str(file_result.get("error", "Write failed"))
		return out
	var ins_line := caret_line if caret_line >= 0 else code_edit.get_caret_line()
	out["label_line"] = insert_source_block(code_edit, ins_line, lbl, res_path)
	out["ref"] = build_ref(lbl, res_path, out["label_line"])
	out["ok"] = true
	return out
