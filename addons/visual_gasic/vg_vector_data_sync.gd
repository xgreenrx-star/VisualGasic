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

	code_edit.set_meta(META_GUARD, true)
	while old_count > new_count:
		code_edit.remove_line_at(end_line)
		end_line -= 1
		old_count -= 1
	while old_count < new_count:
		end_line += 1
		code_edit.insert_line_at(end_line, Resolver.format_shape_line(shapes[old_count]))
		old_count += 1
	for i in new_count:
		code_edit.set_line(start_line + i, Resolver.format_shape_line(shapes[i]))
	code_edit.remove_meta(META_GUARD)
	if code_edit.has_signal("text_changed"):
		code_edit.text_changed.emit()
	return true


static func is_sync_guarded(code_edit: CodeEdit) -> bool:
	return code_edit != null and code_edit.has_meta(META_GUARD)
