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
