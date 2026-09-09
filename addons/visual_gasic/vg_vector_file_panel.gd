@tool
extends VBoxContainer
## Context Rail editor for external .vgv vector files referenced by DataFile.

const VgvResolver := preload("res://addons/visual_gasic/vg_vgv_resolver.gd")
const CanvasScript := preload("res://addons/visual_gasic/vg_vector_edit_canvas.gd")

var _info: Label
var _canvas: Control
var _save_btn: Button
var _abs_path: String = ""
var _model: Dictionary = {}
var _debounce: Timer


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 10)
	_info.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	_info.text = "Open a .vgv DataFile to edit vector shapes."
	add_child(_info)

	_canvas = CanvasScript.new()
	_canvas.name = "VgvCanvas"
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(0, 160)
	_canvas.visible = false
	if _canvas.has_signal("shapes_edited"):
		_canvas.shapes_edited.connect(_on_shapes_edited)
	add_child(_canvas)

	_save_btn = Button.new()
	_save_btn.text = "Save .vgv"
	_save_btn.visible = false
	_save_btn.pressed.connect(_flush_save)
	add_child(_save_btn)

	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = 0.25
	_debounce.timeout.connect(_flush_save)
	add_child(_debounce)


func clear_preview() -> void:
	_abs_path = ""
	_model = {}
	if _canvas.has_method("clear_model"):
		_canvas.clear_model()
	_canvas.visible = false
	_save_btn.visible = false
	_info.text = "Open a .vgv DataFile to edit vector shapes."


func show_vgv_ref(ref: Dictionary) -> void:
	var abs_path: String = str(ref.get("abs_path", ""))
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		clear_preview()
		return
	var model := VgvResolver.load_file(abs_path)
	if model.is_empty():
		_info.text = "Could not parse .vgv:\n" + abs_path.get_file()
		_canvas.visible = false
		_save_btn.visible = false
		return
	_abs_path = abs_path
	_model = model
	var vw: int = int(model.get("view_w", 320))
	var vh: int = int(model.get("view_h", 240))
	var shapes: Array = model.get("shapes", [])
	_info.text = "%s\n%d×%d  ·  %d shape(s)" % [abs_path.get_file(), vw, vh, shapes.size()]
	if _canvas.has_method("set_model"):
		_canvas.set_model(vw, vh, int(model.get("grid_step", 8)), shapes)
	_canvas.visible = true
	_save_btn.visible = true


func _on_shapes_edited(new_shapes: Array) -> void:
	_model["shapes"] = new_shapes
	_debounce.start()


func _flush_save() -> void:
	if _abs_path.is_empty() or _model.is_empty():
		return
	if not VgvResolver.save_file(_abs_path, _model):
		_info.text = "Save failed: " + _abs_path.get_file()
		return
	_save_btn.text = "Save .vgv"
