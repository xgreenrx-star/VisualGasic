@tool
extends RefCounted
## Writes one wire-model vertex back to its Data line.

const META_GUARD := "vg_wire_sync_guard"


static func format_vertex_line(v: Vector3) -> String:
	return "Data %s, %s, %s" % [_num(v.x), _num(v.y), _num(v.z)]


static func apply_vertex(code_edit: CodeEdit, section: Dictionary, index: int, v: Vector3) -> bool:
	if code_edit == null or section.is_empty():
		return false
	var lines: PackedInt32Array = section.get("vert_lines", PackedInt32Array())
	if index < 0 or index >= lines.size():
		return false
	var line := int(lines[index])
	if line < 0 or line >= code_edit.get_line_count():
		return false
	code_edit.set_meta(META_GUARD, true)
	code_edit.set_line(line, format_vertex_line(v))
	code_edit.remove_meta(META_GUARD)
	if code_edit.has_signal("text_changed"):
		code_edit.text_changed.emit()
	return true


static func is_sync_guarded(code_edit: CodeEdit) -> bool:
	return code_edit != null and code_edit.has_meta(META_GUARD)


static func _num(n: float) -> String:
	var s := "%0.2f" % n
	if s.begins_with("-"):
		return "- " + s.substr(1)
	return s
