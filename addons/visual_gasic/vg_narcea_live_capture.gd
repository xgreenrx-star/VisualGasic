extends Node
## Editor-side coordinator: debugger ↔ game capture ↔ VGNarceaLiveSession.

signal session_run_enabled_changed(enabled: bool)
signal capture_status_changed(text: String)
signal banner_visible_changed(visible: bool)

const MIN_CAPTURE_INTERVAL_MS := 500
const MAX_BURST_PER_BREAK := 4

var session: VGNarceaLiveSession

var session_run_enabled: bool = false:
	set(v):
		if session_run_enabled == v:
			return
		session_run_enabled = v
		session_run_enabled_changed.emit(v)
		_update_banner()
		if not v:
			_pending.clear()

var drive_mode_enabled: bool = false

var _debugger = null  # EditorDebuggerPlugin
var _plugin = null
var _last_capture_ms: int = 0
var _break_burst_count: int = 0
var _last_break_key: String = ""
var _pending: Dictionary = {}  # request_id -> partial meta
var _pending_request_id: int = 0
var _waiting_stack: bool = false
var _waiting_locals: bool = false
var _waiting_png: bool = false
var _waiting_ui: bool = false
var _active_meta: Dictionary = {}


func _ready() -> void:
	session = VGNarceaLiveSession.new()
	_reload_settings()


func setup(debugger_plugin, visual_gasic_plugin) -> void:
	_debugger = debugger_plugin
	_plugin = visual_gasic_plugin
	if _debugger == null:
		return
	if not _debugger.debug_break_hit.is_connected(_on_debug_break_hit):
		_debugger.debug_break_hit.connect(_on_debug_break_hit)
	if not _debugger.error_break_received.is_connected(_on_error_break):
		_debugger.error_break_received.connect(_on_error_break)
	if not _debugger.debug_session_stopped.is_connected(_on_debug_session_stopped):
		_debugger.debug_session_stopped.connect(_on_debug_session_stopped)
	if not _debugger.debug_continued.is_connected(_on_debug_continued):
		_debugger.debug_continued.connect(_on_debug_continued)
	if _debugger.has_signal("capture_frame_received") and not _debugger.capture_frame_received.is_connected(_on_capture_frame_received):
		_debugger.capture_frame_received.connect(_on_capture_frame_received)
	if _debugger.has_signal("ui_tree_received") and not _debugger.ui_tree_received.is_connected(_on_ui_tree_received):
		_debugger.ui_tree_received.connect(_on_ui_tree_received)
	if _debugger.has_signal("call_stack_received") and not _debugger.call_stack_received.is_connected(_on_call_stack_received):
		_debugger.call_stack_received.connect(_on_call_stack_received)
	if _debugger.has_signal("stack_level_locals_received") and not _debugger.stack_level_locals_received.is_connected(_on_stack_locals_received):
		_debugger.stack_level_locals_received.connect(_on_stack_locals_received)
	if _debugger.has_signal("debug_state_received") and not _debugger.debug_state_received.is_connected(_on_debug_state_received):
		_debugger.debug_state_received.connect(_on_debug_state_received)
	if _debugger.has_signal("capture_audio_received") and not _debugger.capture_audio_received.is_connected(_on_capture_audio_received):
		_debugger.capture_audio_received.connect(_on_capture_audio_received)
	if _debugger.has_signal("debug_session_started") and not _debugger.debug_session_started.is_connected(_on_debug_session_started):
		_debugger.debug_session_started.connect(_on_debug_session_started)


func _on_debug_session_started() -> void:
	notify_game_started()


func _reload_settings() -> void:
	var max_f := int(ProjectSettings.get_setting("vg/narcea/live_debug_capture_max_frames", 32))
	session.configure(max_f)


func project_capture_allowed() -> bool:
	return bool(ProjectSettings.get_setting("vg/narcea/live_debug_capture", false))


func is_capture_active() -> bool:
	return project_capture_allowed() and session_run_enabled and _debugger != null and _debugger._active_session != null


func purge_all() -> void:
	session.purge_all()
	capture_status_changed.emit("Capture: ON (%d frames)" % session.entry_count() if session_run_enabled else "Capture: OFF")


func clear_run_session() -> void:
	session_run_enabled = false
	session.purge_all()
	capture_status_changed.emit("Capture: OFF")


func refresh_snapshot_manual() -> void:
	if not is_capture_active():
		return
	_request_full_capture("", 0, "manual")


func explain_screen_prompt() -> String:
	var block := session.format_for_narcea(1, true)
	if block.is_empty():
		return "Explain what is on the game viewport at the latest debug break. No snapshot is stored yet — enable live capture and hit a breakpoint or press Refresh snapshot."
	return (
		"Explain what is visible on the game screen at this debug break. "
		+ "Use the live debug context below (viewport snapshot metadata, UI layout, stack, locals).\n\n"
		+ block
	)


func _on_debug_session_stopped() -> void:
	clear_run_session()


func _on_debug_continued() -> void:
	_break_burst_count = 0
	if not bool(ProjectSettings.get_setting("vg/narcea/live_debug_capture_while_running", false)):
		_update_banner()


func _on_debug_break_hit(file: String, line: int) -> void:
	_on_break_event(file, line, {})


func _on_error_break(file: String, line: int, message: String, _code: int) -> void:
	_on_break_event(file, line, {"error_message": message})


func _on_break_event(file: String, line: int, extra: Dictionary) -> void:
	if not is_capture_active():
		return
	if not _should_capture_now():
		return
	var key := "%s:%d" % [file, line]
	if key != _last_break_key:
		_last_break_key = key
		_break_burst_count = 0
	if _break_burst_count >= MAX_BURST_PER_BREAK:
		return
	_break_burst_count += 1
	_request_full_capture(file, line, "break", extra)


func _should_capture_now() -> bool:
	if not _debugger or _debugger._active_session == null:
		return false
	if bool(ProjectSettings.get_setting("vg/narcea/live_debug_capture_while_running", false)):
		return true
	return _debugger._active_session.is_breaked()


func _request_full_capture(file: String, line: int, reason: String, extra: Dictionary = {}) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_capture_ms < MIN_CAPTURE_INTERVAL_MS and reason != "manual":
		return
	_last_capture_ms = now
	_active_meta = {
		"file": file,
		"line": line,
		"reason": reason,
		"captured_ms": now,
	}
	_active_meta.merge(extra, true)
	_waiting_stack = true
	_waiting_locals = true
	_waiting_png = true
	_waiting_ui = bool(ProjectSettings.get_setting("vg/narcea/live_debug_capture_ui_tree", true))
	if _debugger.has_method("request_call_stack"):
		_debugger.request_call_stack()
	else:
		_waiting_stack = false
	if _debugger.has_method("request_stack_level_locals"):
		_debugger.request_stack_level_locals(0)
	else:
		_waiting_locals = false
	var max_w := int(ProjectSettings.get_setting("vg/narcea/live_debug_capture_max_png_width", 960))
	if _debugger.has_method("request_capture_frame"):
		_debugger.request_capture_frame(max_w)
	else:
		_waiting_png = false
	if _waiting_ui and _debugger.has_method("request_ui_tree"):
		_debugger.request_ui_tree(0)
	else:
		_waiting_ui = false
	if bool(ProjectSettings.get_setting("vg/narcea/live_debug_capture_audio", false)):
		if _debugger.has_method("request_audio_chunk"):
			_debugger.request_audio_chunk(int(ProjectSettings.get_setting("vg/narcea/live_debug_capture_audio_ms", 250)))
	_try_finalize_entry()


func _on_call_stack_received(stack: Array) -> void:
	_active_meta["call_stack"] = stack
	_waiting_stack = false
	_try_finalize_entry()


func _on_stack_locals_received(_level: int, locals: Dictionary) -> void:
	_active_meta["locals"] = locals
	_waiting_locals = false
	_try_finalize_entry()


func _on_debug_state_received(state: Dictionary) -> void:
	_active_meta["debug_state"] = state


func _on_ui_tree_received(tree: Array) -> void:
	_active_meta["ui_tree"] = tree
	_waiting_ui = false
	_try_finalize_entry()


func _on_capture_frame_received(payload: Dictionary) -> void:
	_active_meta["w"] = payload.get("w", 0)
	_active_meta["h"] = payload.get("h", 0)
	var b64 := str(payload.get("png_b64", ""))
	var img: Image = null
	if not b64.is_empty():
		var raw := Marshalls.base64_to_raw(b64)
		img = Image.new()
		var err := img.load_png_from_buffer(raw)
		if err != OK:
			img = null
	_active_meta["_png_image"] = img
	_waiting_png = false
	_try_finalize_entry()


func _on_capture_audio_received(payload: Dictionary) -> void:
	if payload.get("ok", false):
		_active_meta["audio_note"] = "WAV chunk %d ms (%d bytes b64)" % [
			int(payload.get("duration_ms", 0)),
			str(payload.get("wav_b64", "")).length(),
		]
	else:
		_active_meta["audio_note"] = str(payload.get("error", "audio unavailable"))


func _try_finalize_entry() -> void:
	if _waiting_stack or _waiting_locals or _waiting_png or _waiting_ui:
		return
	var img: Variant = _active_meta.get("_png_image", null)
	_active_meta.erase("_png_image")
	var png: Image = img if img is Image else null
	session.add_entry(png, _active_meta)
	capture_status_changed.emit("Capture: ON (%d frames)" % session.entry_count())
	_active_meta = {}


func _update_banner() -> void:
	var show := is_capture_active() or (session_run_enabled and project_capture_allowed() and _debugger != null and _debugger._active_session != null)
	banner_visible_changed.emit(show)


func notify_game_started() -> void:
	_update_banner()
	capture_status_changed.emit("Capture: ON (0 frames)" if session_run_enabled else "Capture: OFF")


func inject_pointer(viewport_x: int, viewport_y: int, pressed: bool) -> Dictionary:
	if not drive_mode_enabled or not is_capture_active():
		return {"ok": false, "error": "Drive mode off or capture inactive"}
	if not _debugger._active_session.is_breaked():
		return {"ok": false, "error": "Game must be paused"}
	if _debugger.has_method("send_inject_pointer"):
		_debugger.send_inject_pointer(viewport_x, viewport_y, pressed)
		return {"ok": true}
	return {"ok": false, "error": "Debugger unavailable"}


func inject_unicode(text: String) -> Dictionary:
	if not drive_mode_enabled or not is_capture_active():
		return {"ok": false, "error": "Drive mode off or capture inactive"}
	if not _debugger._active_session.is_breaked():
		return {"ok": false, "error": "Game must be paused"}
	if text.length() > 256:
		return {"ok": false, "error": "Text too long (max 256)"}
	if _debugger.has_method("send_inject_unicode"):
		_debugger.send_inject_unicode(text)
		return {"ok": true}
	return {"ok": false, "error": "Debugger unavailable"}
