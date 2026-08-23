@tool
extends RefCounted
## Reserved editor overlay semantics for Visual Gasic.
##
## **Actionable links** (blue tint + underline + optional accent bar) — right-click
## context menu available. Use ONLY for interactive targets (file paths, etc.).
##
## **String literals** (warm tint, no underline) — ordinary quoted text; not clickable.


static func enumerate_quoted_strings(source: String) -> Array:
	var lines := source.split("\n")
	var out: Array = []
	for line_idx in lines.size():
		var line: String = lines[line_idx]
		var col := 0
		while col < line.length():
			if line[col] != "\"":
				col += 1
				continue
			var start := col
			col += 1
			while col < line.length():
				if line[col] == "\"" and line[col - 1] != "\\":
					break
				col += 1
			if col >= line.length():
				break
			out.append({
				"line": line_idx,
				"literal_start": start,
				"literal_end": col,
			})
			col += 1
	return out


static func is_actionable_literal(ref: Dictionary, actionable_ranges: Array) -> bool:
	for act in actionable_ranges:
		if int(act.get("line", -1)) != int(ref.get("line", -1)):
			continue
		if int(act.get("literal_start", -1)) == int(ref.get("literal_start", -1)) \
				and int(act.get("literal_end", -1)) == int(ref.get("literal_end", -1)):
			return true
	return false


## Warm background for ordinary `"..."` strings — never underline.
static func string_literal_colors(code_edit: CodeEdit) -> Color:
	var lum := _bg_lum(code_edit)
	if lum > 0.5:
		return Color(0.95, 0.82, 0.62, 0.28)
	return Color(0.62, 0.42, 0.18, 0.22)


## Blue link chrome reserved for right-click context-menu targets.
static func actionable_link_colors(code_edit: CodeEdit, active: bool = false, hover: bool = false) -> Dictionary:
	var lum := _bg_lum(code_edit)
	if lum > 0.5:
		if active or hover:
			return {
				"bg": Color(0.68, 0.84, 1.0, 0.78),
				"underline": Color(0.0, 0.22, 0.72, 1.0),
				"accent": Color(0.0, 0.38, 0.92, 1.0),
			}
		return {
			"bg": Color(0.82, 0.91, 1.0, 0.62),
			"underline": Color(0.05, 0.32, 0.82, 0.98),
			"accent": Color(0.08, 0.45, 0.95, 0.95),
		}
	if active or hover:
		return {
			"bg": Color(0.16, 0.34, 0.58, 0.62),
			"underline": Color(0.55, 0.78, 1.0, 1.0),
			"accent": Color(0.45, 0.72, 1.0, 1.0),
		}
	return {
		"bg": Color(0.10, 0.24, 0.48, 0.42),
		"underline": Color(0.38, 0.62, 0.98, 0.92),
		"accent": Color(0.35, 0.58, 0.96, 0.88),
	}


static func _bg_lum(code_edit: CodeEdit) -> float:
	if code_edit and code_edit.has_theme_color("background_color"):
		return code_edit.get_theme_color("background_color").get_luminance()
	return 0.15
