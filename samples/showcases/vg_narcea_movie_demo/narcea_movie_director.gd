extends Control
## Orchestrates scripted Narcea × Cursor movie segments (split UI + preview embed).

const MANIFEST_PATH := "res://movie_data/manifest.json"
const PROVIDER_LABEL := "⬡ Cursor (Composer)"

@onready var _title: ColorRect = $TitleCard
@onready var _ui: PanelContainer = $Layout/UIPanel
@onready var _preview = $Layout/PreviewPane/PreviewVBox/SubViewportContainer/SubViewport
@onready var _code_view: PanelContainer = $Layout/PreviewPane/PreviewVBox/CodePreview

var _manifest: Dictionary = {}
var _movie_mode := false
var _running := false


func _ready() -> void:
	_movie_mode = OS.has_feature("movie")
	_load_manifest()
	if _movie_mode:
		_run_movie_async()
	elif DisplayServer.get_name() == "headless":
		await get_tree().create_timer(0.5).timeout
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if _movie_mode or _running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_run_movie_async()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()


func _load_manifest() -> void:
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		push_error("Missing manifest: %s" % MANIFEST_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_manifest = parsed


func _run_movie_async() -> void:
	if _running:
		return
	_running = true
	await _play_title()
	var segments: Array = _manifest.get("segments", [])
	for seg in segments:
		await _play_segment(seg)
	await _play_end()
	_running = false
	if _movie_mode:
		await get_tree().create_timer(0.5).timeout
		get_tree().quit()


func _play_title() -> void:
	var title: Dictionary = _manifest.get("title", {})
	_title.show_title(
		str(title.get("headline", "NARCEA × CURSOR")),
		str(title.get("subline", ""))
	)
	_ui.reset_panel()
	_preview.clear_demo()
	_code_view.hide_code()
	await get_tree().create_timer(float(title.get("duration_sec", 4.0))).timeout
	_title.hide_card()


func _play_segment(seg: Dictionary) -> void:
	_ui.begin_segment(str(seg.get("label", "segment")), PROVIDER_LABEL)
	var prompt_path := "res://movie_data/%s" % str(seg.get("prompt_file", ""))
	await _ui.play_prompt(_read_text_file(prompt_path), float(seg.get("prompt_chars_per_sec", 40.0)))
	_ui.set_references(seg.get("references", []))
	await get_tree().create_timer(1.0).timeout
	var transcript_path := "res://movie_data/%s" % str(seg.get("transcript_file", ""))
	await _ui.play_response(_read_text_file(transcript_path), float(seg.get("stream_chars_per_sec", 240.0)))
	await _ui.flash_apply()
	await get_tree().create_timer(float(seg.get("apply_hold_sec", 1.0))).timeout
	_preview.load_demo(str(seg.get("demo_scene", "")))
	await get_tree().create_timer(float(seg.get("demo_duration_sec", 10.0))).timeout
	_preview.clear_demo()
	var code_file := str(seg.get("code_file", ""))
	if not code_file.is_empty():
		_ui.show_code_review(code_file)
		await _code_view.play_scroll(code_file, float(seg.get("code_scroll_sec", 5.0)))
	_ui.reset_panel()


func _play_end() -> void:
	var end: Dictionary = _manifest.get("end", {})
	_title.show_title(
		str(end.get("headline", "")),
		str(end.get("subline", "")),
		str(end.get("body", ""))
	)
	_ui.show_end(end)
	_preview.clear_demo()
	_code_view.hide_code()
	await get_tree().create_timer(float(end.get("duration_sec", 5.0))).timeout
	_title.hide_card()


func _read_text_file(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text().strip_edges()
