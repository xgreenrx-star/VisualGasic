@tool
extends ColorRect
## Game UI — Full-screen loading overlay with progress bar and tips.

signal loading_finished

# ── VB6-style properties ──────────────────────────────────────

@export var TipText: String = "Press SPACE to jump":
	set(v):
		TipText = v
		if _tip_label: _tip_label.text = v

@export var ProgressLabel: String = "Loading...":
	set(v):
		ProgressLabel = v
		if _progress_label: _progress_label.text = v

@export_range(0.0, 1.0, 0.01) var Progress: float = 0.0:
	set(v):
		Progress = clampf(v, 0.0, 1.0)
		if _progress_bar: _progress_bar.value = Progress * 100.0
		if is_equal_approx(Progress, 1.0):
			loading_finished.emit()

@export var BarColor: Color = Color(0.2, 0.7, 1.0):
	set(v):
		BarColor = v
		if _progress_bar: _apply_bar_style()

@export var BackgroundColor: Color = Color(0.05, 0.05, 0.08, 1.0):
	set(v):
		BackgroundColor = v
		color = BackgroundColor

@export var ShowSpinner: bool = true
@export var ShowTip: bool = true:
	set(v):
		ShowTip = v
		if _tip_label: _tip_label.visible = v

var _progress_bar: ProgressBar
var _progress_label: Label
var _tip_label: Label
var _spinner: Control
var _spin_angle: float = 0.0

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	color = BackgroundColor
	custom_minimum_size = Vector2(320, 180)

	var center := VBoxContainer.new()
	center.set_anchors_preset(PRESET_CENTER)
	center.add_theme_constant_override("separation", 16)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.custom_minimum_size = Vector2(280, 0)
	add_child(center)

	# Spinner placeholder
	if ShowSpinner:
		_spinner = Control.new()
		_spinner.custom_minimum_size = Vector2(40, 40)
		_spinner.set("layout_mode", 1)
		center.add_child(_spinner)
		if Engine.is_editor_hint():
			_spinner.draw.connect(_draw_spinner)

	# Progress label
	_progress_label = Label.new()
	_progress_label.text = ProgressLabel
	_progress_label.add_theme_font_size_override("font_size", 14)
	_progress_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_progress_label)

	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(240, 18)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = Progress * 100.0
	_progress_bar.show_percentage = false
	_apply_bar_style()
	center.add_child(_progress_bar)

	# Tip label
	_tip_label = Label.new()
	_tip_label.text = TipText
	_tip_label.add_theme_font_size_override("font_size", 11)
	_tip_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.visible = ShowTip
	center.add_child(_tip_label)

func _apply_bar_style() -> void:
	if not _progress_bar: return
	var fill := StyleBoxFlat.new()
	fill.bg_color = BarColor
	fill.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.2)
	bg.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("background", bg)

func _draw_spinner() -> void:
	if not _spinner: return
	var cx := _spinner.size.x * 0.5
	var cy := _spinner.size.y * 0.5
	var r: float = min(cx, cy) - 2.0
	for i in range(8):
		var angle := _spin_angle + i * TAU / 8.0
		var alpha := 1.0 - float(i) / 8.0
		var from := Vector2(cx + cos(angle) * r * 0.4, cy + sin(angle) * r * 0.4)
		var to := Vector2(cx + cos(angle) * r, cy + sin(angle) * r)
		_spinner.draw_line(from, to, Color(BarColor, alpha), 2.0)

func set_progress(value: float) -> void:
	Progress = value
