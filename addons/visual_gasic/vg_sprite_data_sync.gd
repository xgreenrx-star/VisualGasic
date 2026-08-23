@tool
extends RefCounted
## Rewrites labeled sprite Data rows in a CodeEdit from a flat pixel buffer.

const Resolver := preload("res://addons/visual_gasic/vg_sprite_data_resolver.gd")

const META_GUARD := "vg_sprite_sync_guard"


static func apply_pixels(code_edit: CodeEdit, section: Dictionary, pixels: PackedInt32Array) -> bool:
	if code_edit == null or section.is_empty():
		return false
	var w: int = section.get("w", 0)
	var h: int = section.get("h", 0)
	var start_line: int = section.get("data_start_line", -1)
	if w < 1 or h < 1 or start_line < 0:
		return false
	if pixels.size() != w * h:
		return false

	code_edit.set_meta(META_GUARD, true)
	for row in h:
		var parts: PackedStringArray = PackedStringArray()
		for col in w:
			parts.append(str(pixels[row * w + col]))
		var line_text := "Data " + ", ".join(parts)
		code_edit.set_line(start_line + row, line_text)
	code_edit.remove_meta(META_GUARD)
	# set_line does not emit text_changed — notify the embedded editor so
	# dirty tracking, context rail, and flush_for_run see the edit.
	if code_edit.has_signal("text_changed"):
		code_edit.text_changed.emit()
	return true


static func is_sync_guarded(code_edit: CodeEdit) -> bool:
	return code_edit != null and code_edit.has_meta(META_GUARD)
