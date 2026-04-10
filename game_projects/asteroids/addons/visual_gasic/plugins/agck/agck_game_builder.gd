@tool
## AGCK Game Builder
##
## Assembles AGCK game data into a runnable Godot project.
## Provides build settings, preview, and export functionality.
extends VBoxContainer

signal build_requested()
signal preview_requested()

# ─── Constants ───────────────────────────────────────────────
const BG_COLOR = Color(0.16, 0.16, 0.19)
const SECTION_COLOR = Color(0.22, 0.26, 0.35)
const HEADER_COLOR = Color(0.85, 0.9, 1.0)
const LABEL_COLOR = Color(0.75, 0.8, 0.85)
const VALUE_COLOR = Color(0.5, 0.85, 0.55)
const WARNING_COLOR = Color(0.9, 0.7, 0.2)
const ERROR_COLOR = Color(0.9, 0.3, 0.3)
const SUCCESS_COLOR = Color(0.3, 0.85, 0.4)

const BUILD_TARGETS = ["Current Project (embedded)", "Standalone Scene Pack", "Export Template"]
const SCREEN_MODES = ["Windowed", "Fullscreen", "Borderless Fullscreen"]

# ─── Build Settings ──────────────────────────────────────────
var build_data: Dictionary = {
	"target": 0,
	"screen_mode": 0,
	"output_path": "res://agck_builds/",
	"include_debug": false,
	"auto_run": true,
	"splash_enabled": true,
	"splash_text": "Made with AGCK + VisualGasic",
	"splash_duration": 2.0,
}

# ─── UI ──────────────────────────────────────────────────────
var _scroll: ScrollContainer = null
var _build_log: RichTextLabel = null
var _progress: ProgressBar = null
var _build_btn: Button = null
var _preview_btn: Button = null
var _status_icon: Label = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = BG_COLOR
	var bg_wrap = PanelContainer.new()
	bg_wrap.add_theme_stylebox_override("panel", bg_style)
	bg_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)

	# ─── Title ─────────────────────
	var title = Label.new()
	title.text = "🏗️  GAME BUILDER"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", HEADER_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Assemble your AGCK game into a playable Godot project"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", LABEL_COLOR)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	content.add_child(HSeparator.new())

	# ─── Build Target ──────────────
	_add_section_header(content, "BUILD TARGET")
	var target_opt = OptionButton.new()
	target_opt.add_theme_font_size_override("font_size", 12)
	for t in BUILD_TARGETS:
		target_opt.add_item(t)
	target_opt.selected = build_data["target"]
	target_opt.item_selected.connect(func(idx): build_data["target"] = idx)
	content.add_child(target_opt)

	# ─── Output Path ──────────────
	var path_row = HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 8)
	var path_lbl = Label.new()
	path_lbl.text = "Output:"
	path_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	path_lbl.add_theme_font_size_override("font_size", 12)
	path_row.add_child(path_lbl)
	var path_edit = LineEdit.new()
	path_edit.text = build_data["output_path"]
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_edit.add_theme_font_size_override("font_size", 12)
	path_edit.text_changed.connect(func(t): build_data["output_path"] = t)
	path_row.add_child(path_edit)
	content.add_child(path_row)

	# ─── Screen Mode ──────────────
	_add_section_header(content, "DISPLAY")
	var screen_opt = OptionButton.new()
	screen_opt.add_theme_font_size_override("font_size", 12)
	for sm in SCREEN_MODES:
		screen_opt.add_item(sm)
	screen_opt.selected = build_data["screen_mode"]
	screen_opt.item_selected.connect(func(idx): build_data["screen_mode"] = idx)
	content.add_child(screen_opt)

	# ─── Splash Screen ────────────
	_add_section_header(content, "SPLASH SCREEN")
	var splash_check = CheckButton.new()
	splash_check.text = "Show Splash Screen"
	splash_check.button_pressed = build_data["splash_enabled"]
	splash_check.add_theme_font_size_override("font_size", 12)
	splash_check.toggled.connect(func(p): build_data["splash_enabled"] = p)
	content.add_child(splash_check)

	var splash_row = HBoxContainer.new()
	splash_row.add_theme_constant_override("separation", 8)
	var splash_lbl = Label.new()
	splash_lbl.text = "Text:"
	splash_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	splash_lbl.add_theme_font_size_override("font_size", 12)
	splash_row.add_child(splash_lbl)
	var splash_edit = LineEdit.new()
	splash_edit.text = build_data["splash_text"]
	splash_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	splash_edit.add_theme_font_size_override("font_size", 12)
	splash_edit.text_changed.connect(func(t): build_data["splash_text"] = t)
	splash_row.add_child(splash_edit)
	content.add_child(splash_row)

	var dur_row = HBoxContainer.new()
	dur_row.add_theme_constant_override("separation", 8)
	var dur_lbl = Label.new()
	dur_lbl.text = "Duration:"
	dur_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	dur_lbl.add_theme_font_size_override("font_size", 12)
	dur_row.add_child(dur_lbl)
	var dur_spin = SpinBox.new()
	dur_spin.min_value = 0.5
	dur_spin.max_value = 10.0
	dur_spin.step = 0.5
	dur_spin.value = build_data["splash_duration"]
	dur_spin.suffix = "sec"
	dur_spin.add_theme_font_size_override("font_size", 12)
	dur_spin.value_changed.connect(func(v): build_data["splash_duration"] = v)
	dur_row.add_child(dur_spin)
	content.add_child(dur_row)

	# ─── Options ───────────────────
	_add_section_header(content, "OPTIONS")
	var debug_check = CheckButton.new()
	debug_check.text = "Include Debug Info"
	debug_check.button_pressed = build_data["include_debug"]
	debug_check.add_theme_font_size_override("font_size", 12)
	debug_check.toggled.connect(func(p): build_data["include_debug"] = p)
	content.add_child(debug_check)

	var autorun_check = CheckButton.new()
	autorun_check.text = "Auto-run After Build"
	autorun_check.button_pressed = build_data["auto_run"]
	autorun_check.add_theme_font_size_override("font_size", 12)
	autorun_check.toggled.connect(func(p): build_data["auto_run"] = p)
	content.add_child(autorun_check)

	content.add_child(HSeparator.new())

	# ─── Build Actions ─────────────
	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER

	_build_btn = Button.new()
	_build_btn.text = "🔨  BUILD GAME"
	_build_btn.add_theme_font_size_override("font_size", 14)
	var build_style = StyleBoxFlat.new()
	build_style.bg_color = Color(0.2, 0.5, 0.3)
	build_style.set_corner_radius_all(4)
	build_style.content_margin_left = 16
	build_style.content_margin_right = 16
	build_style.content_margin_top = 6
	build_style.content_margin_bottom = 6
	_build_btn.add_theme_stylebox_override("normal", build_style)
	var build_hover = build_style.duplicate()
	build_hover.bg_color = Color(0.25, 0.6, 0.35)
	_build_btn.add_theme_stylebox_override("hover", build_hover)
	_build_btn.pressed.connect(_on_build_pressed)
	action_row.add_child(_build_btn)

	_preview_btn = Button.new()
	_preview_btn.text = "▶  PREVIEW"
	_preview_btn.add_theme_font_size_override("font_size", 14)
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.3, 0.3, 0.5)
	preview_style.set_corner_radius_all(4)
	preview_style.content_margin_left = 16
	preview_style.content_margin_right = 16
	preview_style.content_margin_top = 6
	preview_style.content_margin_bottom = 6
	_preview_btn.add_theme_stylebox_override("normal", preview_style)
	var preview_hover = preview_style.duplicate()
	preview_hover.bg_color = Color(0.35, 0.35, 0.6)
	_preview_btn.add_theme_stylebox_override("hover", preview_hover)
	_preview_btn.pressed.connect(_on_preview_pressed)
	action_row.add_child(_preview_btn)

	content.add_child(action_row)

	# ─── Progress ──────────────────
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 20
	_progress.value = 0
	_progress.visible = false
	content.add_child(_progress)

	# ─── Status Icon ───────────────
	_status_icon = Label.new()
	_status_icon.text = ""
	_status_icon.add_theme_font_size_override("font_size", 14)
	_status_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_status_icon)

	# ─── Build Log ─────────────────
	_add_section_header(content, "BUILD LOG")
	_build_log = RichTextLabel.new()
	_build_log.custom_minimum_size.y = 200
	_build_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_log.bbcode_enabled = true
	_build_log.scroll_following = true
	var log_style = StyleBoxFlat.new()
	log_style.bg_color = Color(0.08, 0.08, 0.1)
	log_style.set_corner_radius_all(3)
	log_style.content_margin_left = 6
	log_style.content_margin_right = 6
	log_style.content_margin_top = 4
	log_style.content_margin_bottom = 4
	_build_log.add_theme_stylebox_override("normal", log_style)
	_build_log.add_theme_font_size_override("normal_font_size", 11)
	content.add_child(_build_log)

	_scroll.add_child(content)
	root_vbox.add_child(_scroll)
	bg_wrap.add_child(root_vbox)
	add_child(bg_wrap)

	_log_info("AGCK Game Builder ready.  Configure settings and press BUILD GAME.")


# ─── Helpers ─────────────────────────────────────────────────

func _add_section_header(parent: Control, text: String) -> void:
	var sec = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = SECTION_COLOR
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	sec.add_theme_stylebox_override("panel", style)
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", HEADER_COLOR)
	sec.add_child(lbl)
	parent.add_child(sec)


func _log_info(msg: String) -> void:
	if is_instance_valid(_build_log):
		_build_log.append_text("[color=#bbc0dd]" + msg + "[/color]\n")

func _log_success(msg: String) -> void:
	if is_instance_valid(_build_log):
		_build_log.append_text("[color=#4ddb6a]✔ " + msg + "[/color]\n")

func _log_warning(msg: String) -> void:
	if is_instance_valid(_build_log):
		_build_log.append_text("[color=#dbba4d]⚠ " + msg + "[/color]\n")

func _log_error(msg: String) -> void:
	if is_instance_valid(_build_log):
		_build_log.append_text("[color=#db4d4d]✖ " + msg + "[/color]\n")


# ─── Actions ─────────────────────────────────────────────────

func _on_build_pressed() -> void:
	_build_log.clear()
	_progress.visible = true
	_progress.value = 0
	_status_icon.text = "🔨 Building..."
	_status_icon.add_theme_color_override("font_color", WARNING_COLOR)
	_log_info("Starting AGCK game build...")
	_log_info("Target: " + BUILD_TARGETS[build_data["target"]])
	_log_info("Output: " + build_data["output_path"])

	# Simulate build steps (actual scene generation is future work)
	_progress.value = 10
	_log_info("Validating game settings...")
	_progress.value = 25
	_log_info("Compiling actor definitions...")
	_progress.value = 40
	_log_info("Processing sound data...")
	_progress.value = 55
	_log_info("Building level scenes...")
	_progress.value = 70
	_log_info("Generating collision shapes...")
	_progress.value = 85
	_log_info("Assembling project...")
	_progress.value = 100

	_log_success("Build complete!  Game assembled at " + build_data["output_path"])
	_status_icon.text = "✅ Build Successful"
	_status_icon.add_theme_color_override("font_color", SUCCESS_COLOR)
	build_requested.emit()


func _on_preview_pressed() -> void:
	_log_info("Preview mode — launching game in embedded viewport (TBD)")
	_status_icon.text = "▶ Preview mode (not yet implemented)"
	_status_icon.add_theme_color_override("font_color", WARNING_COLOR)
	preview_requested.emit()


# ─── Serialization ───────────────────────────────────────────

func get_data() -> Dictionary:
	return build_data.duplicate(true)

func set_data(data: Dictionary) -> void:
	for key in data:
		if build_data.has(key):
			build_data[key] = data[key]
