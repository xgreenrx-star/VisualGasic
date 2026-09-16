@tool
extends "res://addons/visual_gasic/vg_plugin_base.gd"

func get_plugin_name() -> String:
	return "Vector Graphics"

func get_toolbar_icon() -> String:
	return "🖋️"

func get_toolbar_color() -> Color:
	return Color(0.18, 0.45, 0.78)

func get_toolbar_tooltip() -> String:
	return "Vector Graphics tools and examples"

func _build_ui() -> void:
	var wrapper = VBoxContainer.new()
	wrapper.name = "VectorGraphicsInfo"
	wrapper.custom_minimum_size = Vector2(520, 320)

	var title = Label.new()
	title.text = "Vector Graphics"
	title.add_theme_font_size_override("font_size", 20)
	wrapper.add_child(title)

	if _view:
		_view.add_child(wrapper)

	var description = RichTextLabel.new()
	description.bbcode_enabled = true
	description.text = "Use the VectorCanvas node and helper API, or the shared VGVectorAPI.Get() singleton, to draw shapes, text, arcs, and chart layers in VisualGasic projects."
	wrapper.add_child(description)

	var sample = RichTextLabel.new()
	sample.bbcode_enabled = true
	sample.text = (
		"[b]Sample usage[/b]\n"
		+ "var VG = VGVectorAPI.Get()\n"
		+ "var canvas = VG.CreateVectorCanvas()\n"
		+ "canvas.position = Vector2(24, 24)\n"
		+ "AddChild(canvas)\n"
		+ "VG.DrawRoundedRect(canvas, Rect2(20, 20, 300, 180), 16, 3, Color8(0, 180, 215), true, Color8(0, 90, 110, 120))\n"
		+ "VG.DrawPieSlice(canvas, Vector2(180, 110), 70, 0.0, PI * 0.6, 32, Color8(255, 150, 80), true, Color8(255, 150, 80, 100))\n"
		+ "VG.DrawTextCentered(canvas, Vector2(180, 220), \"VectorCanvas Demo\", Color8(255,255,255), Null)"
	)
	wrapper.add_child(sample)

	if _view:
		_view.add_child(wrapper)

func _on_activated() -> void:
	print("Vector Graphics plugin activated")

func _on_deactivated() -> void:
	print("Vector Graphics plugin deactivated")

func _on_cleanup() -> void:
	print("Vector Graphics cleanup")
