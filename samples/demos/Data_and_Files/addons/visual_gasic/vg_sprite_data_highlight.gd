@tool
extends RefCounted
## Editor tint colors + native CodeEdit line backgrounds for sprite Data blocks.

const Resolver := preload("res://addons/visual_gasic/vg_sprite_data_resolver.gd")

const CLEAR := Color(0, 0, 0, 0)


static func overlay_colors(code_edit: CodeEdit) -> Dictionary:
	var lum := 0.15
	if code_edit and code_edit.has_theme_color("background_color"):
		lum = code_edit.get_theme_color("background_color").get_luminance()
	if lum > 0.5:
		return {
			"block": Color(0.82, 0.92, 0.86, 0.38),
			"active": Color(0.72, 0.88, 0.96, 0.52),
		}
	return {
		"block": Color(0.35, 0.55, 0.45, 0.22),
		"active": Color(0.4, 0.65, 0.75, 0.32),
	}


static func native_line_colors(code_edit: CodeEdit) -> Dictionary:
	var lum := 0.15
	if code_edit and code_edit.has_theme_color("background_color"):
		lum = code_edit.get_theme_color("background_color").get_luminance()
	if lum > 0.5:
		return {
			"block": Color(0.88, 0.96, 0.91, 0.55),
			"active": Color(0.78, 0.92, 0.98, 0.72),
		}
	return {
		"block": Color(0.25, 0.42, 0.35, 0.35),
		"active": Color(0.3, 0.5, 0.58, 0.45),
	}


static func clear_native_lines(code_edit: CodeEdit, painted: Array) -> void:
	if code_edit == null:
		return
	for idx in painted:
		var line := int(idx)
		if line >= 0 and line < code_edit.get_line_count():
			code_edit.set_line_background_color(line, CLEAR)


static func paint_native_lines(code_edit: CodeEdit, source: String, caret_line: int) -> Array:
	var painted: Array = []
	if code_edit == null or source.is_empty():
		return painted
	var colors := native_line_colors(code_edit)
	var active := Resolver.resolve_at_line(source, caret_line)
	var active_label: String = active.get("label", "")
	for block in Resolver.enumerate_blocks(source):
		var start: int = block["label_line"]
		var end: int = block["end_line"]
		var col: Color = colors["active"] if block.get("label", "") == active_label else colors["block"]
		for line_idx in range(start, end + 1):
			if line_idx >= 0 and line_idx < code_edit.get_line_count():
				code_edit.set_line_background_color(line_idx, col)
				if not painted.has(line_idx):
					painted.append(line_idx)
	return painted
