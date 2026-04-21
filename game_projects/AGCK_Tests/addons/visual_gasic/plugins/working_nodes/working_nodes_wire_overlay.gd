@tool
extends Control

var editor: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func _draw() -> void:
	if editor == null or not is_instance_valid(editor):
		return
	if not editor.has_method("_get_visible_connections_for_overlay"):
		return
	var visible_connections: Array = editor._get_visible_connections_for_overlay()
	for c in visible_connections:
		var points: PackedVector2Array = c.get("points", PackedVector2Array())
		if points.size() < 2:
			continue
		var color: Color = c.get("color", Color(0.8, 0.8, 0.9, 0.95))
		var width: float = c.get("width", 2.0)
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], color, width, true)
		# Wire label: drawn at the midpoint of the wire
		var label: String = c.get("label", "")
		if not label.is_empty() and points.size() >= 2:
			var mid_idx := points.size() / 2
			var mid: Vector2 = (points[mid_idx - 1] + points[mid_idx]) * 0.5
			var font := ThemeDB.fallback_font
			var font_size := 10
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			# Semi-transparent background pill
			var pad := Vector2(4, 2)
			draw_rect(Rect2(mid - text_size * 0.5 - pad, text_size + pad * 2),
				Color(0.08, 0.08, 0.12, 0.80), true)
			draw_string(font, mid - text_size * 0.5, label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.92, 0.55, 0.95))
