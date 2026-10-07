@tool
extends EditorPlugin

var _passed := 0
var _failed := 0
var _instances_received := 0
var _eval_reply: Dictionary = {}
var _preview_texture: ImageTexture
var _preview_captures := 0

func _enter_tree() -> void:
	call_deferred("_run_checks")

func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error("EDITOR-LIFECYCLE FAIL: " + description)

func _run_checks() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	await _run_preview_checks()
	var debugger_script = load("res://addons/visual_gasic/vg_debugger_plugin.gd")
	for cycle in range(3):
		var debugger = debugger_script.new()
		debugger.bind_vg_main_plugin(self)
		add_debugger_plugin(debugger)
		_check(not debugger.get_sessions().is_empty(), "native session attached")
		_check(debugger.is_session_active(), "setup retained attached session")
		var timer: Timer = debugger._breakpoint_poll_timer
		var timer_ref := weakref(timer) if timer else null
		var session: EditorDebuggerSession = debugger._active_session
		_check(is_instance_valid(timer), "poll timer created")
		if cycle == 0 and ProjectSettings.get_setting("vg/tests/live_debugger", false):
			await _run_live_checks(debugger)
		var pending_reply: Dictionary = {}
		debugger._pending_requests[999] = func(result: Dictionary): pending_reply.merge(result)
		if cycle != 2 and debugger.has_method("shutdown"):
			debugger.shutdown()
			debugger.shutdown()
		remove_debugger_plugin(debugger)
		_check(not debugger.is_session_alive(), "detached session is not alive")
		_check(not debugger.is_session_active(), "detached session is not active")
		_check(debugger._active_session == null, "session reference released")
		_check(debugger._vg_main_plugin == null, "parent plugin reference released")
		_check(not session.breaked.is_connected(debugger._on_session_breaked) \
			and not session.continued.is_connected(debugger._on_session_continued) \
			and not session.stopped.is_connected(debugger._on_session_stopped_signal),
			"retained session signals disconnected")
		_check(pending_reply.get("success") == false, "pending evaluation explicitly closed")
		debugger._poll_breakpoints_from_editor()
		debugger.debug_break()
		debugger.request_instances()
		debugger.request_variable(0, "x")
		debugger.request_all_variables(0)
		debugger.set_variable(0, "x", 1)
		debugger.debug_continue()
		debugger.debug_step_into()
		debugger.debug_step_over()
		debugger.debug_step_out()
		debugger.request_debug_state()
		debugger.request_call_stack()
		debugger.request_stack_level_locals(0)
		debugger.request_capture_frame()
		debugger.request_audio_chunk()
		debugger.request_ui_tree()
		debugger.send_inject_pointer(0, 0, true)
		debugger.send_inject_unicode("x")
		debugger.add_watchpoint("x")
		debugger.remove_watchpoint("x")
		debugger.clear_watchpoints()
		debugger.request_watchpoints()
		debugger.eval_watch_expressions(0, ["x"])
		debugger.set_conditional_breakpoint("res://fixture.vg", 1, "x = 1")
		debugger.set_next_statement(1)
		debugger.set_tracepoint("res://fixture.vg", 1, "x")
		debugger.remove_tracepoint("res://fixture.vg", 1)
		debugger.edit_and_continue("res://fixture.vg", "")
		debugger.toggle_tweak_overlay()
		debugger.request_tweak_targets()
		debugger.apply_tweak_override("fixture", {})
		debugger.undo_tweak_override()
		debugger.redo_tweak_override()
		debugger.reset_tweak_overrides()
		_check(not debugger.send_profiler_command("start"), "late profiler command rejected")
		_check(not debugger._capture("visualgasic:instances", [[]], 0), "late capture rejected")
		debugger._setup_session(0)
		var reply: Dictionary = {}
		debugger.evaluate_code(0, "1 + 1", func(result: Dictionary): reply.merge(result))
		_check(reply.get("success") == false, "late evaluation explicitly reports no session")
		_check(debugger._pending_requests.is_empty(), "no queued evaluation remains")
		await get_tree().process_frame
		_check(timer_ref == null or timer_ref.get_ref() == null, "poll timer freed")
		var debugger_ref := weakref(debugger)
		session = null
		debugger = null
		await get_tree().process_frame
		_check(debugger_ref.get_ref() == null, "debugger released after removal")
	print("EDITOR-LIFECYCLE RESULTS: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _run_live_checks(debugger: EditorDebuggerPlugin) -> void:
	debugger.instances_updated.connect(_on_instances_updated)
	for launch in range(2):
		_instances_received = 0
		EditorInterface.play_main_scene()
		var deadline := Time.get_ticks_msec() + 15000
		while _instances_received == 0 and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_check(_instances_received > 0 and debugger.is_session_alive(), "live game connected")
		if _instances_received > 0:
			var previous := _instances_received
			debugger.request_instances()
			while _instances_received == previous and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			_check(_instances_received > previous, "instance request/reply crosses debug transport")
			_eval_reply.clear()
			debugger.evaluate_code(0, "? answer", _on_eval_reply)
			while _eval_reply.is_empty() and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			_check(_eval_reply.get("success") == true and str(_eval_reply.get("result")) == "42",
				"evaluation callback crosses debug transport")
		EditorInterface.stop_playing_scene()
		deadline = Time.get_ticks_msec() + 15000
		while EditorInterface.is_playing_scene() and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_check(not debugger.is_session_alive(), "game stop clears live session")
	_check(not debugger._shutting_down, "ordinary game stop allows restart")

func _on_instances_updated(instances: Array) -> void:
	if not instances.is_empty():
		_instances_received += 1

func _on_eval_reply(reply: Dictionary) -> void:
	_eval_reply = reply

func _run_preview_checks() -> void:
	var manager_script = load("res://addons/visual_gasic/vg_live_preview_manager.gd")
	var manager = manager_script.new(self, self)
	add_child(manager)
	manager.register_control("Fixture", "res://addons/lifecycle_test/preview.tscn")
	if DisplayServer.get_name() == "headless":
		_check(manager._viewports.is_empty(), "headless preview allocates no viewports")
		_check(manager._capture_timer == null, "headless preview allocates no capture timer")
	else:
		_check(manager._viewports.size() == 1, "graphical preview creates viewport")
		var deadline := Time.get_ticks_msec() + 10000
		while _preview_texture == null and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_check(_preview_texture != null, "rendered preview delivered")
		if _preview_texture:
			var image := _preview_texture.get_image()
			_check(image.get_size() == Vector2i(200, 150), "preview texture dimensions preserved")
			while not image.get_pixel(100, 75).is_equal_approx(Color(1, 0, 0, 1)) \
					and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
				image = _preview_texture.get_image()
			_check(image.get_pixel(100, 75).is_equal_approx(Color(1, 0, 0, 1)),
				"preview contains actual rendered control pixels: %s" % image.get_pixel(100, 75))
		manager.set_frozen(true)
		var captures := _preview_captures
		for frame in range(5):
			await get_tree().process_frame
		_check(_preview_captures == captures, "frozen previews do not recapture")
		manager.unregister_control("Fixture")
		manager.register_control("Fixture", "res://addons/lifecycle_test/preview.tscn")
		_check(manager._first_captures.size() == 1, "reregister schedules only current viewport")
		manager.unregister_control("Fixture")
		_check(manager._first_captures.is_empty(), "unregister cancels first capture")
	manager.shutdown()
	manager.shutdown()
	_check(manager._viewports.is_empty(), "shutdown clears preview viewports")
	_check(not RenderingServer.frame_post_draw.is_connected(manager._on_frame_post_draw),
		"shutdown disconnects rendered-frame callback")
	var manager_ref := weakref(manager)
	manager.queue_free()
	manager = null
	_preview_texture = null
	await get_tree().process_frame
	_check(manager_ref.get_ref() == null, "preview manager and children released")

func set_control_preview_texture(_type_name: String, texture: ImageTexture) -> void:
	_preview_texture = texture
	_preview_captures += 1
