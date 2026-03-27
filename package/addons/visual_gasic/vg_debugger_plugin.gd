@tool
extends EditorDebuggerPlugin
## VisualGasic Debugger Plugin
## Enables communication with running VisualGasic instances via Godot's debug protocol

signal instances_updated(instances: Array)
signal variable_received(var_name: String, value: Variant)
signal variables_list_received(variables: Dictionary)
signal whenever_sections_received(sections: Array)
signal debug_state_received(state: Dictionary)
signal debug_break_hit(file: String, line: int)
signal debug_print_received(text: String)
signal profiler_data_received(report: Dictionary)
signal form_controls_received(controls: Array)
signal debug_continued()
signal debug_session_stopped()
signal debug_session_started()
signal call_stack_received(stack: Array)
signal stack_level_locals_received(level: int, locals: Dictionary)
signal error_break_received(file: String, line: int, message: String, code: int)
signal set_next_statement_failed(requested_line: int, actual_line: int)

var _active_session: EditorDebuggerSession = null
var _pending_requests: Dictionary = {}
var _request_id: int = 0

# Track the last break emission to deduplicate (break_hit + debug_state both emit)
var _last_break_file: String = ""
var _last_break_line: int = -1
var _last_break_time: int = 0  # msec timestamp

# Breakpoint tracking - stores all VG breakpoints set in editor
# Key: script_path (String), Value: Array of line numbers (int)
var _breakpoints: Dictionary = {}

# Timer to poll breakpoints from ScriptEditor (workaround for custom script languages)
var _breakpoint_poll_timer: Timer = null

## Emit debug_break_hit only if this file:line wasn't already emitted recently
## (within 500ms). Prevents duplicates from break_hit + debug_state arriving
## for the same pause event.
func _emit_break_hit_deduped(file: String, line: int) -> void:
	var now := Time.get_ticks_msec()
	if file == _last_break_file and line == _last_break_line and (now - _last_break_time) < 500:
		print("[VG Debugger Plugin] Skipping duplicate break_hit: ", file, ":", line)
		return
	_last_break_file = file
	_last_break_line = line
	_last_break_time = now
	debug_break_hit.emit(file, line)

func _has_capture(prefix: String) -> bool:
	# Debug: Log all prefixes to see what's coming through
	if prefix.begins_with("visual"):
		print("[VG Debugger Plugin] _has_capture called with prefix: ", prefix)
	return prefix == "visualgasic"

func _goto_script_line(script: Script, line: int) -> void:
	"""Called by Godot when user clicks on a breakpoint line in the debugger panel."""
	# Godot passes 0-based line (it subtracts 1 from _debug_get_stack_level_line internally).
	# Our _navigate_to_script_line expects 1-based, so convert here.
	var one_based_line := line + 1
	print("[VG Debugger Plugin] _goto_script_line: ", script.resource_path if script else "null", " line ", line, " -> 1-based ", one_based_line)
	if script and script.resource_path.ends_with(".vg"):
		_navigate_to_script_line(script.resource_path, one_based_line)
		_emit_break_hit_deduped(script.resource_path, one_based_line)

func _capture(message: String, data: Array, session_id: int) -> bool:
	# Debug: Log all messages to see what's coming through
	if message.begins_with("visualgasic"):
		print("[VG Debugger Plugin] _capture received: ", message, " data size: ", data.size())
	
	if not message.begins_with("visualgasic:"):
		return false
	
	# CRITICAL FIX: Godot 4.6 may never call _setup_session() for our plugin,
	# but it DOES call _capture() with a valid session_id on every message.
	# Ensure we always have a reference to the active session.
	if _active_session == null:
		var session = get_session(session_id)
		if session:
			print("[VG Debugger Plugin] Acquired session from _capture (session_id=%d)" % session_id)
			_active_session = session
			# Connect signals we would have connected in _setup_session
			if not session.breaked.is_connected(_on_session_breaked):
				session.breaked.connect(_on_session_breaked)
			if not session.continued.is_connected(_on_session_continued):
				session.continued.connect(_on_session_continued)
			if session.has_signal("stopped") and not session.stopped.is_connected(_on_session_stopped_signal):
				session.stopped.connect(_on_session_stopped_signal)
			# Start breakpoint polling
			if _breakpoint_poll_timer == null:
				_breakpoint_poll_timer = Timer.new()
				_breakpoint_poll_timer.wait_time = 0.5
				_breakpoint_poll_timer.timeout.connect(_poll_breakpoints_from_editor)
				EditorInterface.get_base_control().add_child(_breakpoint_poll_timer)
			_breakpoint_poll_timer.start()
			debug_session_started.emit()
	
	var command = message.substr(12)  # Strip "visualgasic:"
	
	match command:
		"instances":
			# Received list of running instances
			var instances = data[0] if data.size() > 0 else []
			instances_updated.emit(instances)
			return true
		
		"variable":
			# Received a variable value
			if data.size() >= 2:
				variable_received.emit(data[0], data[1])
			return true
		
		"variables_list":
			# Received all variables from an instance
			var vars = data[0] if data.size() > 0 else {}
			variables_list_received.emit(vars)
			return true
		
		"whenever_sections":
			# Received Whenever sections from an instance
			var sections = data[0] if data.size() > 0 else []
			whenever_sections_received.emit(sections)
			return true
		
		"eval_result":
			# Received result of code evaluation
			if data.size() >= 2:
				var req_id = data[0]
				var result = data[1]
				print("[VG Debugger Plugin] eval_result received: req_id=%s result=%s pending_keys=%s" % [str(req_id), str(result), str(_pending_requests.keys())])
				if _pending_requests.has(req_id):
					var callback = _pending_requests[req_id]
					_pending_requests.erase(req_id)
					if callback.is_valid():
						callback.call(result)
					else:
						print("[VG Debugger Plugin] eval_result: callback INVALID for req_id=%s" % str(req_id))
				else:
					print("[VG Debugger Plugin] eval_result: NO pending request for req_id=%s" % str(req_id))
			else:
				print("[VG Debugger Plugin] eval_result: data too small, size=%d" % data.size())
			return true
		
		"debug_state":
			# Received debug state (step mode, current line/file)
			var state = data[0] if data.size() > 0 else {}
			print("[VG Debugger Plugin] debug_state received: ", state)
			debug_state_received.emit(state)
			# If we're in a break state and have file/line info, navigate there
			var current_file = state.get("current_file", "")
			var current_line = state.get("current_line", 0)
			print("[VG Debugger Plugin] debug_state file: '", current_file, "' line: ", current_line)
			if not current_file.is_empty() and current_line > 0:
				print("[VG Debugger Plugin] Navigating from debug_state...")
				_navigate_to_script_line(current_file, current_line)
				_emit_break_hit_deduped(current_file, current_line)
			return true
		
		"break_hit":
			# Received notification that a breakpoint or step was hit
			if data.size() >= 2:
				print("[VG Debugger Plugin] Received break_hit: ", data[0], ":", data[1])
				# Navigate directly to the script line
				_navigate_to_script_line(data[0], data[1])
				_emit_break_hit_deduped(data[0], data[1])
			return true
		
		"debug_print":
			# Debug.Print output → route to Immediate Window
			if data.size() >= 1:
				debug_print_received.emit(String(data[0]))
			return true
		
		"profiler_data":
			# Profiler report from running game
			if data.size() >= 1:
				profiler_data_received.emit(data[0])
			return true
		
		"form_controls":
			# v4.3: Controls Inspector — list of form controls with properties
			if data.size() >= 1:
				form_controls_received.emit(data[0])
			return true
		
		"call_stack":
			# Call Stack Navigation — received stack frames from game
			var stack = data[0] if data.size() > 0 else []
			call_stack_received.emit(stack)
			return true
		
		"stack_level_locals":
			# Call Stack Navigation — received locals for a specific frame level
			if data.size() >= 2:
				stack_level_locals_received.emit(int(data[0]), data[1])
			return true
		
		"error_break":
			# Exception Assistant — unhandled runtime error break
			if data.size() >= 4:
				var file = data[0]
				var line = int(data[1])
				var err_msg = data[2]
				var err_code = int(data[3])
				print("[VG Debugger Plugin] Error break: ", file.get_file(), ":", line, " — ", err_msg)
				_navigate_to_script_line(file, line)
				_emit_break_hit_deduped(file, line)
				error_break_received.emit(file, line, err_msg, err_code)
			return true
		
		"set_next_statement_failed":
			# VM couldn't find the target line in the current bytecode chunk
			if data.size() >= 2:
				var requested = int(data[0])
				var actual = int(data[1])
				print("[VG Debugger Plugin] Set Next Statement FAILED: line ", requested, " not in current procedure, actual=", actual)
				set_next_statement_failed.emit(requested, actual)
			return true
	
	return false

func _setup_session(session_id: int) -> void:
	var session = get_session(session_id)
	print("[VG Debugger Plugin] _setup_session(%d) session=%s" % [session_id, str(session != null)])
	if session:
		_active_session = session
		print("[VG Debugger Plugin] _active_session SET, is_active=%s" % str(session.is_active()))
		# Request initial list of instances
		session.send_message("visualgasic:get_instances", [])
		
		# Connect to session signals for break state
		if not session.breaked.is_connected(_on_session_breaked):
			session.breaked.connect(_on_session_breaked)
		if not session.continued.is_connected(_on_session_continued):
			session.continued.connect(_on_session_continued)
		# Connect to session stopped signal so we detect when the game process exits
		var has_stopped := session.has_signal("stopped")
		print("[VG Debugger Plugin] session.has_signal('stopped')=%s" % str(has_stopped))
		if has_stopped and not session.stopped.is_connected(_on_session_stopped_signal):
			session.stopped.connect(_on_session_stopped_signal)
			print("[VG Debugger Plugin] Connected to session.stopped signal")
		
		# Notify listeners that a debug session is now active (enables Stop button etc.)
		debug_session_started.emit()
		
		# Poll breakpoints from ScriptEditor immediately
		_poll_breakpoints_from_editor()
		
		# Start polling timer - Godot doesn't call _breakpoint_set_in_tree for custom languages
		# Note: EditorDebuggerPlugin is RefCounted, not Node, so add timer to editor base
		if _breakpoint_poll_timer == null:
			_breakpoint_poll_timer = Timer.new()
			_breakpoint_poll_timer.wait_time = 0.5
			_breakpoint_poll_timer.timeout.connect(_poll_breakpoints_from_editor)
			EditorInterface.get_base_control().add_child(_breakpoint_poll_timer)
		_breakpoint_poll_timer.start()

func _on_session_breaked(can_debug: bool) -> void:
	"""Called when the remote game enters break state."""
	# When we break, request the current debug state from the game
	if _active_session:
		_active_session.send_message("visualgasic:get_debug_state", [])

func _on_session_continued() -> void:
	"""Called when the remote game continues from break."""
	debug_continued.emit()

func _session_stopped(session_id: int) -> void:
	print("[VG Debugger Plugin] _session_stopped(%d) called!" % session_id)
	_active_session = null
	_pending_requests.clear()
	if _breakpoint_poll_timer:
		_breakpoint_poll_timer.stop()
	instances_updated.emit([])
	debug_session_stopped.emit()

func _on_session_stopped_signal() -> void:
	## Fallback: fired by EditorDebuggerSession.stopped signal
	print("[VG Debugger Plugin] _on_session_stopped_signal() FIRED!")
	_active_session = null
	_pending_requests.clear()
	if _breakpoint_poll_timer:
		_breakpoint_poll_timer.stop()
	instances_updated.emit([])
	debug_session_stopped.emit()

func _poll_breakpoints_from_editor() -> void:
	"""Poll breakpoints from ScriptEditor - workaround since _breakpoint_set_in_tree 
	   isn't called for custom script languages like .vg"""
	# Check if the active session died (fallback if stopped signal didn't fire).
	# IMPORTANT: Only check when NOT breaked — is_active() can return false during
	# break state in some Godot versions, which would incorrectly nuke the session.
	if _active_session:
		var is_act = _active_session.is_active()
		var is_brk = _active_session.is_breaked()
		var session_gone := false
		if not is_act and not is_brk:
			session_gone = true
		if session_gone:
			print("[VG Debugger Plugin] Detected ended session via polling — is_active=%s is_breaked=%s — cleaning up" % [str(is_act), str(is_brk)])
			_active_session = null
			_pending_requests.clear()
			if _breakpoint_poll_timer:
				_breakpoint_poll_timer.stop()
			instances_updated.emit([])
			debug_session_stopped.emit()
			return
	
	var script_editor = EditorInterface.get_script_editor()
	if not script_editor:
		return
	
	# get_breakpoints() returns PackedStringArray of "res://path.gd:line" strings
	var bp_strings = script_editor.get_breakpoints()
	var new_breakpoints: Dictionary = {}
	
	for bp_str in bp_strings:
		# Parse "res://path/script.vg:123" format
		var colon_idx = bp_str.rfind(":")
		if colon_idx == -1:
			continue
		
		var path = bp_str.substr(0, colon_idx)
		var line_str = bp_str.substr(colon_idx + 1)
		
		# Only track .vg scripts
		if not path.ends_with(".vg"):
			continue
		
		var line = int(line_str)
		if not new_breakpoints.has(path):
			new_breakpoints[path] = []
		if line not in new_breakpoints[path]:
			new_breakpoints[path].append(line)
	
	# Check if breakpoints changed OR if we have breakpoints and should re-sync
	# Re-sync periodically because game might not be ready on first sync
	if new_breakpoints != _breakpoints or not new_breakpoints.is_empty():
		_breakpoints = new_breakpoints
		_sync_breakpoints_to_game()

# ============================================================================
# BREAKPOINT HANDLING - Required for custom script debugging
# ============================================================================

func _breakpoint_set_in_tree(script: Script, line: int, enabled: bool) -> void:
	"""Called by Godot when a breakpoint is set/unset in the script editor.
	   We need to forward these to the running game process."""
	if script == null:
		return
	
	var path = script.resource_path
	# Only handle .vg scripts
	if not path.ends_with(".vg"):
		return
	
	# Update our local breakpoint tracking
	if enabled:
		if not _breakpoints.has(path):
			_breakpoints[path] = []
		if line not in _breakpoints[path]:
			_breakpoints[path].append(line)
	else:
		if _breakpoints.has(path):
			_breakpoints[path].erase(line)
			if _breakpoints[path].is_empty():
				_breakpoints.erase(path)
	
	# Send to running game
	_sync_breakpoints_to_game()

func _breakpoints_cleared_in_tree() -> void:
	"""Called by Godot when all breakpoints are cleared."""
	_breakpoints.clear()
	_sync_breakpoints_to_game()

func _sync_breakpoints_to_game() -> void:
	"""Send the current breakpoint state to the running game."""
	# Also save to file so game can load breakpoints at startup (before debug session connects)
	_save_breakpoints_to_file()
	if _active_session:
		_active_session.send_message("visualgasic:set_breakpoints", [_breakpoints])

func _save_breakpoints_to_file() -> void:
	"""Save breakpoints to a file so game can load them at startup."""
	var file = FileAccess.open("res://.vg_breakpoints.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_breakpoints))
		file.close()

func request_instances() -> void:
	if _active_session:
		_active_session.send_message("visualgasic:get_instances", [])

func request_variable(instance_id: int, var_name: String) -> void:
	if _active_session:
		_active_session.send_message("visualgasic:get_variable", [instance_id, var_name])

func request_all_variables(instance_id: int) -> void:
	if _active_session:
		_active_session.send_message("visualgasic:get_all_variables", [instance_id])

func set_variable(instance_id: int, var_name: String, value: Variant) -> void:
	if _active_session:
		_active_session.send_message("visualgasic:set_variable", [instance_id, var_name, value])

func request_whenever_sections(instance_id: int) -> void:
	if _active_session:
		_active_session.send_message("visualgasic:get_whenever_sections", [instance_id])

func set_whenever_active(instance_id: int, section_name: String, active: bool) -> void:
	if _active_session:
		_active_session.send_message("visualgasic:set_whenever_active", [instance_id, section_name, active])

func evaluate_code(instance_id: int, code: String, callback: Callable) -> void:
	if _active_session and _active_session.is_active():
		_request_id += 1
		_pending_requests[_request_id] = callback
		print("[VG Debugger Plugin] evaluate_code: sending req_id=%d instance=%d code='%s'" % [_request_id, instance_id, code])
		_active_session.send_message("visualgasic:evaluate", [instance_id, code, _request_id])
	elif _active_session and _active_session.is_breaked():
		# Session exists and game is paused at breakpoint — is_active() may be
		# false during break in some Godot versions, but we can still send.
		_request_id += 1
		_pending_requests[_request_id] = callback
		print("[VG Debugger Plugin] evaluate_code: sending (breaked) req_id=%d instance=%d code='%s'" % [_request_id, instance_id, code])
		_active_session.send_message("visualgasic:evaluate", [instance_id, code, _request_id])
	else:
		print("[VG Debugger Plugin] evaluate_code: NO ACTIVE SESSION — cannot send")
		if callback.is_valid():
			callback.call({"success": false, "result": "No active debug session"})

func is_session_active() -> bool:
	return _active_session != null

func is_session_alive() -> bool:
	"""Returns true if the session exists AND the game is still running or breaked.
	   When the game exits, is_active() and is_breaked() both become false."""
	if not _active_session:
		return false
	return _active_session.is_active() or _active_session.is_breaked()

# ============================================================================
# STEP DEBUGGING COMMANDS
# ============================================================================

func debug_continue() -> void:
	"""Resume execution after a breakpoint or step."""
	if _active_session:
		# Set VG flags, then bare command to unblock script_debug()
		_active_session.send_message("visualgasic:debug_continue", [])
		_active_session.send_message("continue", [])

func debug_break() -> void:
	"""Request a pause at the next statement (VB6-style Break button)."""
	# Try to acquire session if we don't have one yet (game may have just started)
	if _active_session == null:
		var session = get_session(0)
		if session and session.is_active():
			_active_session = session
			print("[VG Debugger Plugin] debug_break: acquired session 0 on demand")
	if _active_session:
		_active_session.send_message("visualgasic:debug_break", [])

func debug_step_into() -> void:
	"""Step to the next line, entering function calls."""
	if _active_session:
		_active_session.send_message("visualgasic:debug_step_into", [])
		_active_session.send_message("step", [])

func debug_step_over() -> void:
	"""Step to the next line, stepping over function calls."""
	if _active_session:
		_active_session.send_message("visualgasic:debug_step_over", [])
		_active_session.send_message("next", [])

func debug_step_out() -> void:
	"""Step out of the current function."""
	if _active_session:
		_active_session.send_message("visualgasic:debug_step_out", [])
		_active_session.send_message("out", [])

func debug_stop() -> void:
	"""Stop execution — terminate the running game process."""
	# If paused in script_debug(), continue first so the game can exit cleanly
	if _active_session:
		_active_session.send_message("visualgasic:debug_continue", [])
		_active_session.send_message("continue", [])
	# Then stop the running scene
	EditorInterface.stop_playing_scene()

func request_debug_state() -> void:
	"""Request the current debug state from the game."""
	if _active_session:
		_active_session.send_message("visualgasic:get_debug_state", [])

func send_profiler_command(command: String) -> void:
	"""Send a profiler command (start/stop/get_data/clear) to the running game."""
	if _active_session:
		_active_session.send_message("visualgasic:profiler_" + command, [])

# ============================================================================
# v3.2: DEBUGGER PROTOCOL v2 — Watch Expressions & Data Breakpoints
# ============================================================================

func add_watchpoint(variable_name: String) -> void:
	"""Add a data breakpoint (watchpoint) that breaks when a variable changes."""
	if _active_session:
		_active_session.send_message("visualgasic:add_watchpoint", [variable_name])

func remove_watchpoint(variable_name: String) -> void:
	"""Remove a data breakpoint."""
	if _active_session:
		_active_session.send_message("visualgasic:remove_watchpoint", [variable_name])

func clear_watchpoints() -> void:
	"""Clear all data breakpoints."""
	if _active_session:
		_active_session.send_message("visualgasic:clear_watchpoints", [])

func request_watchpoints() -> void:
	"""Request the current list of watchpoints from the game."""
	if _active_session:
		_active_session.send_message("visualgasic:get_watchpoints", [])

func eval_watch_expressions(instance_id: int, expressions: Array) -> void:
	"""Evaluate a list of expressions in the context of a running instance.
	   Results come back via 'visualgasic:watch_results' message."""
	if _active_session:
		_active_session.send_message("visualgasic:eval_watch_expressions", [instance_id, expressions])

func set_conditional_breakpoint(script_path: String, line: int, condition: String) -> void:
	"""Set a breakpoint with a condition expression.
	   The breakpoint only triggers when the condition evaluates to true."""
	if _active_session:
		_active_session.send_message("visualgasic:set_conditional_breakpoint", [script_path, line, condition])

# ============================================================================
# SET NEXT STATEMENT — VB6-style "move the yellow arrow"
# ============================================================================

func set_next_statement(line: int) -> void:
	"""Set Next Statement: move execution point to a new line (1-based).
	   Only works while paused at a breakpoint or step.
	   Sends the command to the running game which will jump the bytecode VM's
	   instruction pointer to the target line when execution resumes."""
	if _active_session:
		print("[VG Debugger Plugin] Set Next Statement → line ", line)
		_active_session.send_message("visualgasic:set_next_statement", [line])

# ============================================================================
# TRACEPOINTS (LOG POINTS) — breakpoints that log instead of pausing
# ============================================================================

func set_tracepoint(script_path: String, line: int, message: String) -> void:
	"""Set a tracepoint (log point) at the given line. When hit, it logs
	   the message (with {variable} interpolation) and continues."""
	if _active_session:
		_active_session.send_message("visualgasic:set_tracepoint", [script_path, line, message])

func remove_tracepoint(script_path: String, line: int) -> void:
	"""Remove a tracepoint at the given line."""
	if _active_session:
		_active_session.send_message("visualgasic:remove_tracepoint", [script_path, line])

# ============================================================================
# EDIT AND CONTINUE — VB6 signature: apply code changes while debug-paused
# ============================================================================

func edit_and_continue(script_path: String, new_source: String) -> void:
	"""Send the updated source code to the running game so the C++ side can
	   hot-reload the script while the VM is paused in script_debug()."""
	if _active_session:
		print("[VG Debugger Plugin] Edit & Continue → ", script_path.get_file())
		_active_session.send_message("visualgasic:edit_and_continue", [script_path, new_source])

# ============================================================================
# CALL STACK NAVIGATION — inspect variables at any stack frame level
# ============================================================================

func request_call_stack() -> void:
	"""Request the current call stack from the running game."""
	if _active_session:
		_active_session.send_message("visualgasic:get_call_stack", [])

func request_stack_level_locals(level: int) -> void:
	"""Request local variables for a specific stack frame level (0 = top/current)."""
	if _active_session:
		_active_session.send_message("visualgasic:get_stack_level_locals", [level])

# ============================================================================
# NAVIGATION HELPER
# ============================================================================

func _navigate_to_script_line(file_path: String, line: int) -> void:
	"""Navigate the editor to a specific script file and line.
	For .vg files, we skip Godot's Script editor — the main VisualGasic plugin
	listens to the debug_break_hit signal and opens the embedded VG code editor.
	For non-.vg scripts we fall back to Godot's built-in Script editor."""
	print("[VG Debugger Plugin] Navigating to: ", file_path, " line ", line)
	if file_path.is_empty() or line <= 0:
		return

	# .vg files are handled by the main plugin via debug_break_hit signal
	if file_path.ends_with(".vg"):
		return

	# Non-.vg scripts: use Godot's built-in Script editor
	if not ResourceLoader.exists(file_path):
		print("[VG Debugger Plugin] Script not found: ", file_path)
		return
	
	var script = load(file_path)
	if not script:
		print("[VG Debugger Plugin] Failed to load script: ", file_path)
		return
	
	# Switch to Script editor
	EditorInterface.set_main_screen_editor("Script")
	
	# Open the script at the specified line
	EditorInterface.edit_script(script, line, 0)
	
	# Center on line after a delay
	_deferred_center_on_line.call_deferred(line)

func _deferred_center_on_line(line: int) -> void:
	"""Center the script editor viewport on the specified line."""
	var script_editor = EditorInterface.get_script_editor()
	if not script_editor:
		return
	
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return
	
	var code_edit = current_editor.get_base_editor() as CodeEdit
	if code_edit:
		# Line numbers in CodeEdit are 0-based
		code_edit.set_caret_line(line - 1)
		code_edit.set_caret_column(0)
		code_edit.center_viewport_to_caret()
		code_edit.grab_focus()
		print("[VG Debugger Plugin] Centered on line ", line)
