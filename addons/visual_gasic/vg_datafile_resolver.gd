@tool
extends RefCounted
## Resolve DataFile "path" references and labeled Data blocks for Context rail.

const Sniff := preload("res://addons/visual_gasic/vg_datafile_sniff.gd")

static var _label_re: RegEx
static var _datafile_re: RegEx
static var _data_re: RegEx


static func _label_rx() -> RegEx:
	if _label_re == null:
		_label_re = RegEx.new()
		_label_re.compile("^\\s*([A-Za-z_]\\w*)\\s*:\\s*(?:'.*)?$")
	return _label_re


static func _datafile_rx() -> RegEx:
	if _datafile_re == null:
		_datafile_re = RegEx.new()
		_datafile_re.compile("(?i)^\\s*DataFile\\s+\"([^\"]*)\"")
	return _datafile_re


static func _data_rx() -> RegEx:
	if _data_re == null:
		_data_re = RegEx.new()
		_data_re.compile("(?i)^\\s*Data\\s+(.+)$")
	return _data_re


static func resolve_at_line(source: String, caret_line: int) -> Dictionary:
	if source.is_empty() or caret_line < 0:
		return {}
	var lines := source.split("\n")
	if caret_line >= lines.size():
		return {}

	var df_caret := _datafile_rx().search(lines[caret_line])
	if df_caret != null:
		var ll := _find_enclosing_label_line(lines, caret_line)
		var ln := ""
		if ll >= 0:
			var lm := _label_rx().search(lines[ll])
			if lm:
				ln = lm.get_string(1)
		return _build_ref(ln, ll, df_caret.get_string(1), lines, caret_line)

	var lm_on_line := _label_rx().search(lines[caret_line])
	if lm_on_line != null:
		var dl := _find_first_datafile_after_label(lines, caret_line)
		if dl >= 0:
			var df := _datafile_rx().search(lines[dl])
			if df:
				return _build_ref(lm_on_line.get_string(1), caret_line, df.get_string(1), lines, dl)

	var label_line := _find_enclosing_label_line(lines, caret_line)
	if label_line < 0:
		return {}
	var lm := _label_rx().search(lines[label_line])
	if lm == null:
		return {}
	var data_line := _find_datafile_near_caret(lines, label_line, caret_line)
	if data_line < 0:
		return {}
	var df2 := _datafile_rx().search(lines[data_line])
	if df2 == null:
		return {}
	return _build_ref(lm.get_string(1), label_line, df2.get_string(1), lines, data_line)


static func _build_ref(label_name: String, label_line: int, path: String, lines: PackedStringArray, data_line: int = -1) -> Dictionary:
	var res_path := _to_res_path(path)
	var abs_path := ProjectSettings.globalize_path(res_path) if res_path.begins_with("res://") else path
	var sniff := Sniff.sniff_path(abs_path)
	return {
		"label": label_name,
		"label_line": label_line,
		"data_line": data_line if data_line >= 0 else label_line,
		"path": path,
		"res_path": res_path,
		"abs_path": abs_path,
		"sniff": sniff,
	}


static func _to_res_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	if path.begins_with("/"):
		return path
	return "res://" + path.trim_prefix("./")


static func _find_enclosing_label_line(lines: PackedStringArray, caret_line: int) -> int:
	for i in range(caret_line, -1, -1):
		if _label_rx().search(lines[i]) != null:
			return i
	return -1


static func _find_first_datafile_after_label(lines: PackedStringArray, label_line: int) -> int:
	for j in range(label_line + 1, mini(label_line + 12, lines.size())):
		var s := lines[j].strip_edges()
		if s.is_empty() or s.begins_with("'"):
			continue
		if _datafile_rx().search(lines[j]) != null:
			return j
		if _data_rx().search(lines[j]) != null:
			return -1
		if _label_rx().search(lines[j]) != null:
			return -1
	return -1


## Nearest DataFile under label at or before caret; if caret is past all, return last.
static func _find_datafile_near_caret(lines: PackedStringArray, label_line: int, caret_line: int) -> int:
	var best := -1
	for j in range(label_line + 1, lines.size()):
		var s := lines[j].strip_edges()
		if s.is_empty() or s.begins_with("'"):
			continue
		if _label_rx().search(lines[j]) != null:
			break
		if _data_rx().search(lines[j]) != null:
			break
		if _datafile_rx().search(lines[j]) != null:
			best = j
			if j >= caret_line:
				return j
	return best


static func enumerate_datafile_blocks(source: String) -> Array:
	var out: Array = []
	if source.is_empty():
		return out
	var lines := source.split("\n")
	var pending_label := ""
	var pending_label_line := -1
	for i in lines.size():
		var lm := _label_rx().search(lines[i])
		if lm != null:
			pending_label = lm.get_string(1)
			pending_label_line = i
			continue
		var df := _datafile_rx().search(lines[i])
		if df != null:
			out.append(_build_ref(pending_label, pending_label_line, df.get_string(1), lines, i))
	return out
