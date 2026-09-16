extends PanelContainer
## Auto-scrolling source preview shown after each demo segment.

@onready var _path_label: Label = $VBox/Header/PathLabel
@onready var _code: CodeEdit = $VBox/CodeEdit
@onready var _demo_host: Control = get_parent().get_node("SubViewportContainer")


func _ready() -> void:
	visible = false
	_code.editable = false
	_code.gutters_draw_line_numbers = true
	_code.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	_code.scroll_smooth = false
	_code.add_theme_color_override("background_color", Color(0.06, 0.07, 0.1, 1.0))
	_code.add_theme_color_override("font_color", Color(0.86, 0.9, 0.96, 1.0))
	_code.add_theme_color_override("line_number_color", Color(0.42, 0.48, 0.58, 1.0))
	_code.add_theme_font_size_override("font_size", 12)
	_code.add_theme_font_size_override("line_number_size", 12)


func hide_code() -> void:
	visible = false
	if is_instance_valid(_demo_host):
		_demo_host.visible = true
	_code.text = ""
	_code.scroll_vertical = 0


func play_scroll(res_path: String, duration_sec: float) -> void:
	if res_path.is_empty() or not FileAccess.file_exists(res_path):
		hide_code()
		return
	var body := FileAccess.get_file_as_string(res_path)
	if body.is_empty():
		hide_code()
		return
	if is_instance_valid(_demo_host):
		_demo_host.visible = false
	_path_label.text = res_path.replace("res://", "")
	_code.text = body
	visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	var bar := _code.get_v_scroll_bar()
	bar.value = 0.0
	var target := bar.max_value
	var dur := maxf(duration_sec, 0.5)
	if target <= 0.0:
		await get_tree().create_timer(dur).timeout
	else:
		var tw := create_tween()
		tw.tween_property(bar, "value", target, dur).set_trans(Tween.TRANS_LINEAR)
		await tw.finished
		await get_tree().create_timer(0.2).timeout
	hide_code()
