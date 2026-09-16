@tool
extends RefCounted
## Scan project .vg sources for PeekData / dimension constants affected by grid resize.

const DataFileResolver := preload("res://addons/visual_gasic/vg_datafile_resolver.gd")

const KIND_DATACOUNT := "datacount"
const KIND_PEEKDATA_LITERAL := "peekdata_literal"
const KIND_PEEKDATA_EXPR := "peekdata_expr"
const KIND_CONST_WIDTH := "const_width"
const KIND_CONST_HEIGHT := "const_height"
const KIND_CONST_COUNT := "const_count"
const KIND_ASSIGN_WIDTH := "assign_width"
const KIND_ASSIGN_HEIGHT := "assign_height"
const KIND_ASSIGN_COUNT := "assign_count"
const KIND_LOOP_BOUND := "loop_bound"

static var _const_re: RegEx
static var _assign_num_re: RegEx
static var _for_to_re: RegEx
static var _peekdata_re: RegEx
static var _datacount_re: RegEx
static var _flat_index_re: RegEx


static func analyze_resize_impact(
	label: String,
	old_w: int,
	old_h: int,
	new_w: int,
	new_h: int,
	scan_root: String = "res://",
	extra_files: PackedStringArray = []
) -> Dictionary:
	var old_count := old_w * old_h
	var new_count := new_w * new_h
	var findings: Array = []
	var files := _collect_vg_files(scan_root)
	for ef in extra_files:
		if not ef.is_empty() and ef.ends_with(".vg") and ef not in files:
			files.append(ef)
	for path in files:
		if not _file_might_reference_label(path, label):
			continue
		_scan_file(path, label, old_w, old_h, new_w, new_h, old_count, new_count, findings)
	findings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: String = str(a.get("file", ""))
		var pb: String = str(b.get("file", ""))
		if pa != pb:
			return pa < pb
		return int(a.get("line", 0)) < int(b.get("line", 0))
	)
	return {
		"label": label,
		"old_width": old_w,
		"old_height": old_h,
		"new_width": new_w,
		"new_height": new_h,
		"old_count": old_count,
		"new_count": new_count,
		"findings": findings,
		"files_scanned": files.size(),
	}


static func apply_selected_fixes(findings: Array, selected: Array) -> Dictionary:
	var out := {"ok": true, "applied": 0, "errors": [], "files": PackedStringArray()}
	var by_file: Dictionary = {}
	for idx in selected:
		var i := int(idx)
		if i < 0 or i >= findings.size():
			continue
		var f: Dictionary = findings[i]
		if not bool(f.get("auto_fixable", false)):
			continue
		var path: String = str(f.get("file", ""))
		if not by_file.has(path):
			by_file[path] = []
		var bucket: Array = by_file[path]
		bucket.append(f)
	for path in by_file.keys():
		var n := _apply_file_fixes(path, by_file[path])
		if n < 0:
			out["ok"] = false
			out["errors"].append("Could not write " + path)
		elif n > 0 and path not in out["files"]:
			out["files"].append(path)
		out["applied"] += maxi(0, n)
	return out


static func find_label_for_path(res_path: String, scan_root: String = "res://") -> String:
	if res_path.is_empty():
		return ""
	var norm := res_path.replace("\\", "/")
	for path in _collect_vg_files(scan_root):
		var txt := _read_file(path)
		if txt.is_empty():
			continue
		for block in DataFileResolver.enumerate_datafile_blocks(txt):
			var bp: String = str(block.get("res_path", "")).replace("\\", "/")
			if bp == norm or bp.ends_with("/" + norm.get_file()):
				return str(block.get("label", ""))
	return ""


static func _file_might_reference_label(path: String, label: String) -> bool:
	var source := _read_file(path)
	if source.is_empty():
		return false
	var upper := source.to_upper()
	if upper.find("PEEKDATA") < 0 and upper.find("DATACOUNT") < 0 and upper.find("DATABUFFER") < 0:
		return false
	if label.is_empty():
		return true
	var needle := label.strip_edges().to_upper()
	return upper.find(needle) >= 0 or upper.find("\"" + needle + "\"") >= 0


static func _scan_file(
	path: String,
	label: String,
	old_w: int,
	old_h: int,
	new_w: int,
	new_h: int,
	old_count: int,
	new_count: int,
	findings: Array
) -> void:
	var source := _read_file(path)
	if source.is_empty():
		return
	var lines := source.split("\n")
	var consts := _parse_consts(lines)
	for i in lines.size():
		var line := lines[i]
		var stripped := line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("'"):
			continue
		_check_datacount(path, i, line, label, old_count, new_count, findings)
		_check_peekdata(path, i, line, label, new_count, findings)
		_check_const_match(path, i, line, old_w, old_h, old_count, new_w, new_h, new_count, consts, findings)
		_check_assign_match(path, i, line, old_w, old_h, old_count, new_w, new_h, new_count, findings)
		_check_loop_bound(path, i, line, old_w, old_h, old_count, new_w, new_h, new_count, consts, findings)
		_check_flat_index(path, i, line, old_w, new_w, consts, findings)


static func _check_datacount(path: String, line_no: int, line: String, label: String, old_count: int, new_count: int, findings: Array) -> void:
	var m := _datacount_rx().search(line)
	if m == null:
		return
	if not _labels_equal(m.get_string(1), label):
		return
	findings.append(_finding(
		path, line_no, line, KIND_DATACOUNT, "warning",
		"DataCount(\"%s\") returns %d after resize (was %d)" % [label, new_count, old_count],
		"", old_count, new_count, false
	))


static func _check_peekdata(path: String, line_no: int, line: String, label: String, new_count: int, findings: Array) -> void:
	var m := _peekdata_rx().search(line)
	if m == null:
		return
	if not _labels_equal(m.get_string(1), label):
		return
	var expr := m.get_string(2).strip_edges()
	var lit_re := RegEx.new()
	lit_re.compile("^(-?\\d+)$")
	var lm := lit_re.search(expr)
	if lm:
		var off := int(lm.get_string(1))
		var sev := "info"
		var msg := "PeekData(\"%s\", %d) — verify still valid after resize (grid has %d cells)" % [label, off, new_count]
		if off < 0 or off >= new_count:
			sev = "error"
			msg = "PeekData(\"%s\", %d) out of range after resize (valid 0..%d)" % [label, off, maxi(0, new_count - 1)]
		findings.append(_finding(
			path, line_no, line, KIND_PEEKDATA_LITERAL, sev, msg,
			"", off, -1, false
		))
	else:
		findings.append(_finding(
			path, line_no, line, KIND_PEEKDATA_EXPR, "warning",
			"PeekData(\"%s\", %s) uses computed index — review row/col math for new dimensions" % [label, expr],
			"", -1, -1, false
		))


static func _check_const_match(
	path: String,
	line_no: int,
	line: String,
	old_w: int,
	old_h: int,
	old_count: int,
	new_w: int,
	new_h: int,
	new_count: int,
	consts: Dictionary,
	findings: Array
) -> void:
	var m := _const_rx().search(line)
	if m == null:
		return
	var name: String = m.get_string(1)
	var val := int(m.get_string(2))
	var kind := ""
	var suggested := -1
	var msg := ""
	var auto_fixable := false
	if val == old_w and old_w != new_w:
		kind = KIND_CONST_WIDTH
		suggested = new_w
		msg = "Const %s = %d matches old grid width; new width is %d" % [name, old_w, new_w]
		auto_fixable = _name_looks_width(name) or old_w != old_h
	elif val == old_h and old_h != new_h:
		kind = KIND_CONST_HEIGHT
		suggested = new_h
		msg = "Const %s = %d matches old grid height; new height is %d" % [name, old_h, new_h]
		auto_fixable = _name_looks_height(name) or old_w != old_h
	elif val == old_count and old_count != new_count:
		kind = KIND_CONST_COUNT
		suggested = new_count
		msg = "Const %s = %d matches old cell count (width×height); new count is %d" % [name, old_count, new_count]
		auto_fixable = _name_looks_count(name)
	else:
		return
	findings.append(_finding(
		path, line_no, line, kind, "warning", msg,
		name, val, suggested, auto_fixable
	))


static func _check_assign_match(
	path: String,
	line_no: int,
	line: String,
	old_w: int,
	old_h: int,
	old_count: int,
	new_w: int,
	new_h: int,
	new_count: int,
	findings: Array
) -> void:
	var m := _assign_num_rx().search(line)
	if m == null:
		return
	var name: String = m.get_string(1)
	if name.to_lower() in ["if", "elseif", "for", "while", "return", "print", "dim", "const", "redim"]:
		return
	var val := int(m.get_string(2))
	var kind := ""
	var suggested := -1
	var msg := ""
	if val == old_w and old_w != new_w and _name_looks_width(name):
		kind = KIND_ASSIGN_WIDTH
		suggested = new_w
		msg = "%s = %d looks like grid width; new width is %d" % [name, old_w, new_w]
	elif val == old_h and old_h != new_h and _name_looks_height(name):
		kind = KIND_ASSIGN_HEIGHT
		suggested = new_h
		msg = "%s = %d looks like grid height; new height is %d" % [name, old_h, new_h]
	elif val == old_count and old_count != new_count and _name_looks_count(name):
		kind = KIND_ASSIGN_COUNT
		suggested = new_count
		msg = "%s = %d looks like grid cell count; new count is %d" % [name, old_count, new_count]
	else:
		return
	findings.append(_finding(
		path, line_no, line, kind, "warning", msg,
		name, val, suggested, true
	))


static func _check_loop_bound(
	path: String,
	line_no: int,
	line: String,
	old_w: int,
	old_h: int,
	old_count: int,
	new_w: int,
	new_h: int,
	new_count: int,
	consts: Dictionary,
	findings: Array
) -> void:
	var m := _for_to_rx().search(line)
	if m == null:
		return
	var iter: String = m.get_string(1)
	var bound: String = m.get_string(2)
	var bound_val := _resolve_numeric(bound, consts)
	if bound_val < 0:
		return
	var kind := ""
	var suggested := -1
	var msg := ""
	if bound_val == old_w and old_w != new_w and (_name_looks_width(iter) or _name_looks_width(bound)):
		kind = KIND_LOOP_BOUND
		suggested = new_w
		msg = "Loop To %s - 1 (%d cols) matches old width; new width is %d" % [bound, old_w, new_w]
	elif bound_val == old_h and old_h != new_h and (_name_looks_height(iter) or _name_looks_height(bound)):
		kind = KIND_LOOP_BOUND
		suggested = new_h
		msg = "Loop To %s - 1 (%d rows) matches old height; new height is %d" % [bound, old_h, new_h]
	elif bound_val == old_count and old_count != new_count:
		kind = KIND_LOOP_BOUND
		suggested = new_count
		msg = "Loop To %s - 1 matches old cell count; new count is %d" % [bound, new_count]
	else:
		return
	findings.append(_finding(
		path, line_no, line, kind, "warning", msg,
		bound, bound_val, suggested, false
	))


static func _check_flat_index(path: String, line_no: int, line: String, old_w: int, new_w: int, consts: Dictionary, findings: Array) -> void:
	var m := _flat_index_rx().search(line)
	if m == null:
		return
	var mul_name: String = m.get_string(2)
	var mul_val := _resolve_numeric(mul_name, consts)
	if mul_val == old_w and old_w != new_w:
		findings.append(_finding(
			path, line_no, line, KIND_PEEKDATA_EXPR, "warning",
			"Index uses %s (= %d) as row stride; new grid width is %d" % [mul_name, old_w, new_w],
			mul_name, old_w, new_w, false
		))


static func _parse_consts(lines: PackedStringArray) -> Dictionary:
	var out := {}
	for line in lines:
		var m := _const_rx().search(line)
		if m:
			out[m.get_string(1).to_upper()] = int(m.get_string(2))
	return out


static func _resolve_numeric(name: String, consts: Dictionary) -> int:
	var key := name.strip_edges().to_upper()
	if consts.has(key):
		return int(consts[key])
	if name.is_valid_int():
		return int(name)
	return -1


static func _bound_auto_fixable(bound: String, consts: Dictionary) -> bool:
	if bound.is_valid_int():
		return true
	return consts.has(bound.strip_edges().to_upper())


static func _name_looks_width(name: String) -> bool:
	var n := name.to_upper()
	return n.contains("WIDTH") or n.contains("COL") or n.ends_with("_W") or n == "W" or n.contains("MAPW")


static func _name_looks_height(name: String) -> bool:
	var n := name.to_upper()
	return n.contains("HEIGHT") or n.contains("ROW") or n.ends_with("_H") or n == "H" or n.contains("MAPH")


static func _name_looks_count(name: String) -> bool:
	var n := name.to_upper()
	return n.contains("COUNT") or n.contains("CELL") or n.contains("TILE") or n.contains("SIZE")


static func _labels_equal(a: String, b: String) -> bool:
	return a.strip_edges().to_upper() == b.strip_edges().to_upper()


static func _finding(
	file: String,
	line_no: int,
	line_text: String,
	kind: String,
	severity: String,
	message: String,
	symbol: String,
	old_value: int,
	suggested_value: int,
	auto_fixable: bool
) -> Dictionary:
	return {
		"file": file,
		"line": line_no,
		"line_text": line_text.strip_edges(),
		"kind": kind,
		"severity": severity,
		"message": message,
		"symbol": symbol,
		"old_value": old_value,
		"suggested_value": suggested_value,
		"auto_fixable": auto_fixable,
	}


static func _apply_file_fixes(path: String, fixes: Array) -> int:
	var source := _read_file(path)
	if source.is_empty():
		return -1
	var lines := source.split("\n")
	fixes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("line", 0)) > int(b.get("line", 0))
	)
	var applied := 0
	for f in fixes:
		var ln := int(f.get("line", -1))
		if ln < 0 or ln >= lines.size():
			continue
		var new_line := _fix_line(lines[ln], f)
		if new_line != lines[ln]:
			lines[ln] = new_line
			applied += 1
	var out := "\n".join(lines)
	var abs := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var fh := FileAccess.open(abs, FileAccess.WRITE)
	if fh == null:
		return -1
	fh.store_string(out)
	fh.close()
	return applied


static func _fix_line(line: String, finding: Dictionary) -> String:
	var kind: String = str(finding.get("kind", ""))
	var old_v := int(finding.get("old_value", -1))
	var new_v := int(finding.get("suggested_value", -1))
	if new_v < 0:
		return line
	if kind in [KIND_CONST_WIDTH, KIND_CONST_HEIGHT, KIND_CONST_COUNT]:
		return _fix_const_line(line, old_v, new_v)
	if kind in [KIND_ASSIGN_WIDTH, KIND_ASSIGN_HEIGHT, KIND_ASSIGN_COUNT]:
		return _fix_assign_line(line, finding, old_v, new_v)
	if kind == KIND_LOOP_BOUND:
		return _fix_loop_line(line, finding, new_v)
	return line


static func _fix_const_line(line: String, old_v: int, new_v: int) -> String:
	var m := _const_rx().search(line)
	if m == null:
		return line
	if int(m.get_string(2)) != old_v:
		return line
	var prefix := line.substr(0, m.get_start(2))
	var suffix := line.substr(m.get_end(2))
	return prefix + str(new_v) + suffix


static func _fix_assign_line(line: String, finding: Dictionary, old_v: int, new_v: int) -> String:
	var sym: String = str(finding.get("symbol", ""))
	if sym.is_empty():
		return line
	var re := RegEx.new()
	re.compile("(?i)(\\b" + sym + "\\s*=\\s*)" + str(old_v) + "\\b")
	var m := re.search(line)
	if m:
		return line.substr(0, m.get_end()) + str(new_v) + line.substr(m.get_end())
	return line


static func _fix_loop_line(line: String, finding: Dictionary, new_v: int) -> String:
	var sym: String = str(finding.get("symbol", ""))
	var re := RegEx.new()
	re.compile("(?i)(To\\s+)" + sym + "(\\s*-\\s*1)")
	var m := re.search(line)
	if m:
		return line.substr(0, m.get_start(2)) + str(new_v) + line.substr(m.get_start(2))
	return line


static func _collect_vg_files(root: String) -> PackedStringArray:
	var out: PackedStringArray = []
	_walk_vg(root, out)
	return out


static func _walk_vg(path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			_walk_vg(full, out)
		elif name.ends_with(".vg"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


static func _read_file(path: String) -> String:
	var abs := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(abs):
		return ""
	var f := FileAccess.open(abs, FileAccess.READ)
	if f == null:
		return ""
	var txt := f.get_as_text()
	f.close()
	return txt


static func _const_rx() -> RegEx:
	if _const_re == null:
		_const_re = RegEx.new()
		_const_re.compile("(?i)^\\s*Const\\s+(\\w+)\\s+As\\s+\\w+\\s*=\\s*(-?\\d+)")
	return _const_re


static func _assign_num_rx() -> RegEx:
	if _assign_num_re == null:
		_assign_num_re = RegEx.new()
		_assign_num_re.compile("(?i)^\\s*(\\w+)\\s*=\\s*(-?\\d+)\\s*$")
	return _assign_num_re


static func _for_to_rx() -> RegEx:
	if _for_to_re == null:
		_for_to_re = RegEx.new()
		_for_to_re.compile("(?i)For\\s+(\\w+)\\s*=\\s*0\\s+To\\s+(\\w+)\\s*-")
	return _for_to_re


static func _peekdata_rx() -> RegEx:
	if _peekdata_re == null:
		_peekdata_re = RegEx.new()
		_peekdata_re.compile("(?i)PeekData\\s*\\(\\s*\"([^\"]+)\"\\s*,\\s*([^)]+)\\)")
	return _peekdata_re


static func _datacount_rx() -> RegEx:
	if _datacount_re == null:
		_datacount_re = RegEx.new()
		_datacount_re.compile("(?i)DataCount\\s*\\(\\s*\"([^\"]+)\"\\s*\\)")
	return _datacount_re


static func _flat_index_rx() -> RegEx:
	if _flat_index_re == null:
		_flat_index_re = RegEx.new()
		_flat_index_re.compile("(?i)(\\w+)\\s*\\*\\s*(\\w+)\\s*\\+\\s*(\\w+)")
	return _flat_index_re
