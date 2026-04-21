@tool
extends Control

var editor: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

# Sample a cubic bezier into a PackedVector2Array with `steps` segments.
func _bezier(p0: Vector2, c1: Vector2, c2: Vector2, p3: Vector2, steps: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var mt := 1.0 - t
		pts.push_back(mt*mt*mt*p0 + 3.0*mt*mt*t*c1 + 3.0*mt*t*t*c2 + t*t*t*p3)
	return pts

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
		var p0 := points[0]
		var p3 := points[points.size() - 1]
		# Horizontal control points matching GraphEdit's native bezier style
		var ctrl := clamp(abs(p3.x - p0.x) * 0.5, 40.0, 200.0)
		var c1 := p0 + Vector2(ctrl, 0.0)
		var c2 := p3 + Vector2(-ctrl, 0.0)
		var curve := _bezier(p0, c1, c2, p3, 24)
		draw_polyline(curve, color, width, true)
		# Wire label: drawn at the midpoint of the curve
		var label: String = c.get("label", "")
		if not label.is_empty():
			var mid: Vector2 = curve[curve.size() / 2]
			var font := ThemeDB.fallback_font
			var font_size := 10
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var pad := Vector2(4, 2)
			draw_rect(Rect2(mid - text_size * 0.5 - pad, text_size + pad * 2),
				Color(0.08, 0.08, 0.12, 0.80), true)
			draw_string(font, mid - text_size * 0.5, label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.92, 0.55, 0.95))
