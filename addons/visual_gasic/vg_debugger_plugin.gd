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

var _active_session: EditorDebuggerSession = null
var _pending_requests: Dictionary = {}
var _request_id: int = 0

# Breakpoint tracking - stores all VG breakpoints set in editor
# Key: script_path (String), Value: Array of line numbers (int)
var _breakpoints: Dictionary = {}

# Timer to poll breakpoints from ScriptEditor (workaround for custom script languages)
var _breakpoint_poll_timer: Timer = null

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
		debug_break_hit.emit(script.resource_path, one_based_line)

func _capture(message: String, data: Array, session_id: int) -> bool:
	# Debug: Log all messages to see what's coming through
	if message.begins_with("visualgasic"):
		print("[VG Debugger Plugin] _capture received: ", message, " data size: ", data.size())
	
	if not message.begins_with("visualgasic:"):
		return false
	
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
				if _pending_requests.has(req_id):
					var callback = _pending_requests[req_id]
					_pending_requests.erase(req_id)
					if callback.is_valid():
						callback.call(result)
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
				debug_break_hit.emit(current_file, current_line)
			return true
		
		"break_hit":
			# Received notification that a breakpoint or step was hit
			if data.size() >= 2:
				print("[VG Debugger Plugin] Received break_hit: ", data[0], ":", data[1])
				# Navigate directly to the script line
				_navigate_to_script_line(data[0], data[1])
				debug_break_hit.emit(data[0], data[1])
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
	
	return false

func _setup_session(session_id: int) -> void:
	var session = get_session(session_id)
	if session:
		_active_session = session
		# Request initial list of instances
		session.send_message("visualgasic:get_instances", [])
		
		# Connect to session signals for break state
		if not session.breaked.is_connected(_on_session_breaked):
			session.breaked.connect(_on_session_breaked)
		if not session.continued.is_connected(_on_session_continued):
			session.continued.connect(_on_session_continued)
		
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
	pass

func _session_stopped() -> void:
	_active_session = null
	_pending_requests.clear()
	if _breakpoint_poll_timer:
		_breakpoint_poll_timer.stop()
	instances_updated.emit([])

func _poll_breakpoints_from_editor() -> void:
	"""Poll breakpoints from ScriptEditor - workaround since _breakpoint_set_in_tree 
	   isn't called for custom script languages like .vg"""
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
	if _active_session:
		_request_id += 1
		_pending_requests[_request_id] = callback
		_active_session.send_message("visualgasic:evaluate", [instance_id, code, _request_id])

func is_session_active() -> bool:
	return _active_session != null

# ============================================================================
# STEP DEBUGGING COMMANDS
# ============================================================================

func debug_continue() -> void:
	"""Resume execution after a breakpoint or step."""
	if _active_session:
		_active_session.send_message("visualgasic:debug_continue", [])

func debug_step_into() -> void:
	"""Step to the next line, entering function calls."""
	if _active_session:
		_active_session.send_message("visualgasic:debug_step_into", [])

func debug_step_over() -> void:
	"""Step to the next line, stepping over function calls."""
	if _active_session:
		_active_session.send_message("visualgasic:debug_step_over", [])

func debug_step_out() -> void:
	"""Step out of the current function."""
	if _active_session:
		_active_session.send_message("visualgasic:debug_step_out", [])

func request_debug_state() -> void:
	"""Request the current debug state from the game."""
	if _active_session:
		_active_session.send_message("visualgasic:get_debug_state", [])

func send_profiler_command(command: String) -> void:
	"""Send a profiler command (start/stop/get_data/clear) to the running game."""
	if _active_session:
		_active_session.send_message("visualgasic:profiler_" + command, [])

# ============================================================================
# NAVIGATION HELPER
# ============================================================================

func _navigate_to_script_line(file_path: String, line: int) -> void:
	"""Navigate the editor to a specific script file and line."""
	print("[VG Debugger Plugin] Navigating to: ", file_path, " line ", line)
	if file_path.is_empty() or line <= 0:
		return
	
	# Load the script resource
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
