@tool
extends VBoxContainer
## Context Rail preview for file paths (Open / LoadPicture / Sound.Play).

signal file_action_requested(action: int, ref: Dictionary)

const Resolver := preload("res://addons/visual_gasic/vg_open_path_resolver.gd")

const TEXT_PREVIEW_MAX := 8192

var _info: Label
var _action_row: HBoxContainer
var _select_btn: Button
var _create_btn: Button
var _reveal_btn: Button
var _current_ref: Dictionary = {}
var _preview_box: VBoxContainer
var _texture_rect: TextureRect
var _text_view: TextEdit
var _audio_row: HBoxContainer
var _play_btn: Button
var _stop_btn: Button
var _audio_status: Label
var _player: AudioStreamPlayer
var _current_path: String = ""
var _current_kind: String = ""


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 10)
	_info.add_theme_color_override("font_color", Color(0.25, 0.25, 0.35))
	_info.text = "Place the caret on a file path in Open, LoadPicture, Sound.Play, or Load."
	add_child(_info)

	_action_row = HBoxContainer.new()
	_action_row.visible = false
	_action_row.add_theme_constant_override("separation", 4)
	_select_btn = Button.new()
	_select_btn.text = "Select file…"
	_select_btn.tooltip_text = "Open a file dialog and insert the chosen path into the string literal"
	_select_btn.pressed.connect(func() -> void:
		if not _current_ref.is_empty():
			file_action_requested.emit(Resolver.FileMenuAction.SELECT_FILE, _current_ref.duplicate(true))
	)
	_create_btn = Button.new()
	_create_btn.text = "Create file"
	_create_btn.pressed.connect(func() -> void:
		if not _current_ref.is_empty():
			file_action_requested.emit(Resolver.FileMenuAction.CREATE_IF_MISSING, _current_ref.duplicate(true))
	)
	_reveal_btn = Button.new()
	_reveal_btn.text = "Reveal"
	_reveal_btn.pressed.connect(func() -> void:
		if not _current_ref.is_empty():
			file_action_requested.emit(Resolver.FileMenuAction.REVEAL_BROWSER, _current_ref.duplicate(true))
	)
	_action_row.add_child(_select_btn)
	_action_row.add_child(_create_btn)
	_action_row.add_child(_reveal_btn)
	add_child(_action_row)

	var hint := Label.new()
	hint.text = "Right-click the blue path for more actions."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	hint.name = "PathHint"
	add_child(hint)

	_preview_box = VBoxContainer.new()
	_preview_box.visible = false
	_preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_preview_box)

	_texture_rect = TextureRect.new()
	_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.custom_minimum_size = Vector2(120, 120)
	_texture_rect.visible = false
	_preview_box.add_child(_texture_rect)

	_text_view = TextEdit.new()
	_text_view.editable = false
	_text_view.custom_minimum_size = Vector2(0, 120)
	_text_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_view.visible = false
	_text_view.add_theme_font_size_override("font_size", 10)
	_preview_box.add_child(_text_view)

	_audio_row = HBoxContainer.new()
	_audio_row.visible = false
	_play_btn = Button.new()
	_play_btn.text = "▶ Play"
	_play_btn.pressed.connect(_on_play_pressed)
	_stop_btn = Button.new()
	_stop_btn.text = "■ Stop"
	_stop_btn.pressed.connect(_on_stop_pressed)
	_audio_status = Label.new()
	_audio_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_audio_status.add_theme_font_size_override("font_size", 10)
	_audio_row.add_child(_play_btn)
	_audio_row.add_child(_stop_btn)
	_audio_row.add_child(_audio_status)
	_preview_box.add_child(_audio_row)

	_player = AudioStreamPlayer.new()
	_player.name = "PreviewPlayer"
	add_child(_player)


func clear_preview() -> void:
	_current_ref = {}
	_current_path = ""
	_current_kind = ""
	_action_row.visible = false
	_stop_audio()
	_preview_box.visible = false
	_texture_rect.visible = false
	_text_view.visible = false
	_audio_row.visible = false
	_info.text = "Place the caret on a file path in Open, LoadPicture, Sound.Play, or Load."


func show_file_ref(ref: Dictionary, preview_mode: String = "info") -> void:
	if ref.is_empty():
		clear_preview()
		return
	_current_ref = ref.duplicate(true)
	var res_path: String = ref.get("res_path", "")
	_current_path = res_path
	_current_kind = str(ref.get("kind", "unknown"))
	var exists: bool = bool(ref.get("exists", false))
	var cmd: String = str(ref.get("command", ""))
	var mode: String = str(ref.get("mode", ""))
	_action_row.visible = true
	_select_btn.visible = true
	_create_btn.visible = not exists and mode in ["output", "append"]
	_reveal_btn.visible = exists
	var fname := res_path.get_file()
	var status := "found" if exists else "missing"
	var mode_txt := (" · For " + mode) if not mode.is_empty() else ""
	_info.text = "%s\n%s · %s%s\n%s" % [
		fname,
		cmd,
		status,
		mode_txt,
		Resolver.file_size_label(res_path) if exists else "File not on disk",
	]
	_preview_box.visible = preview_mode != "info"
	match preview_mode:
		"text":
			_show_text_preview(res_path)
		"image":
			_show_image_preview(res_path)
		"audio":
			_show_audio_controls(res_path)
		_:
			_preview_box.visible = false


func preview_kind(kind: String) -> void:
	if _current_path.is_empty():
		return
	match kind:
		"text":
			show_file_ref(_ref_stub("text"), "text")
		"image":
			show_file_ref(_ref_stub("image"), "image")
		"audio":
			show_file_ref(_ref_stub("audio"), "audio")
			_on_play_pressed()


func _ref_stub(kind: String) -> Dictionary:
	return {
		"res_path": _current_path,
		"kind": kind,
		"exists": FileAccess.file_exists(_current_path),
		"command": "",
	}


func _show_text_preview(res_path: String) -> void:
	_texture_rect.visible = false
	_audio_row.visible = false
	_text_view.visible = true
	if not FileAccess.file_exists(res_path):
		_text_view.text = "(file missing)"
		return
	var f := FileAccess.open(res_path, FileAccess.READ)
	if f == null:
		_text_view.text = "(could not read file)"
		return
	var chunk := f.get_buffer(TEXT_PREVIEW_MAX)
	f.close()
	var txt := chunk.get_string_from_utf8()
	if chunk.size() >= TEXT_PREVIEW_MAX:
		txt += "\n…"
	_text_view.text = txt


func _show_image_preview(res_path: String) -> void:
	_text_view.visible = false
	_audio_row.visible = false
	_texture_rect.visible = true
	if not FileAccess.file_exists(res_path):
		_texture_rect.texture = null
		return
	var tex: Texture2D = load(res_path)
	if tex == null:
		var img := Image.new()
		var err := img.load(ProjectSettings.globalize_path(res_path))
		if err == OK:
			tex = ImageTexture.create_from_image(img)
	_texture_rect.texture = tex


func _show_audio_controls(res_path: String) -> void:
	_texture_rect.visible = false
	_text_view.visible = false
	_audio_row.visible = true
	_audio_status.text = res_path.get_file() if FileAccess.file_exists(res_path) else "missing"


func _on_play_pressed() -> void:
	if _current_path.is_empty() or not FileAccess.file_exists(_current_path):
		_audio_status.text = "missing"
		return
	var stream: AudioStream = load(_current_path)
	if stream == null:
		_audio_status.text = "unsupported"
		return
	_player.stream = stream
	_player.play()
	_audio_status.text = "playing…"


func _on_stop_pressed() -> void:
	_stop_audio()
	if _audio_row.visible:
		_audio_status.text = "stopped"


func _stop_audio() -> void:
	if _player.playing:
		_player.stop()
