extends Node
## VisualGasic Debug Handler
## This script handles debugger messages from the editor's Immediate Window
## It runs in the GAME process and responds to queries about running instances

var _registered_instances: Dictionary = {}  # instance_id -> weak reference info
var _next_instance_id: int = 1

# Breakpoint storage - Key: script_path (String), Value: Array of line numbers (int)
# This is populated by the editor's debugger plugin and queried by C++ code
var _breakpoints: Dictionary = {}

var _capture_registered := false
var _capture_prefix := "visualgasic"

func _ready() -> void:
	# Load breakpoints from file FIRST - before any scripts run
	# This ensures breakpoints work for init code
	_load_breakpoints_from_file()
	
	# Register our message capture with the engine debugger.
	# The C++ language runtime already registers "visualgasic" when loaded,
	# so skip registration here when the native extension is active to
	# avoid the "Capture already registered" error that can cascade into
	# an unregister failure at exit.
	if EngineDebugger.is_active():
		var cpp_loaded := ClassDB.class_exists("VisualGasicLanguage")
		if cpp_loaded:
			print("[VisualGasic] Debug handler: C++ capture active, skipping GDScript registration")
		else:
			EngineDebugger.register_message_capture(_capture_prefix, _on_debugger_message)
			_capture_registered = true
			print("[VisualGasic] Debug handler registered")

func _load_breakpoints_from_file() -> void:
	"""Load breakpoints saved by the editor at startup.
	   This allows breakpoints to work for init code that runs before the debug session connects."""
	if not FileAccess.file_exists("res://.vg_breakpoints.json"):
		return
	var file = FileAccess.open("res://.vg_breakpoints.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(content)
		if parsed is Dictionary:
			# Convert float line numbers to int (JSON parses numbers as floats)
			for script_path in parsed:
				var lines = parsed[script_path]
				var int_lines: Array[int] = []
				for line in lines:
					int_lines.append(int(line))
				_breakpoints[script_path] = int_lines

func _exit_tree() -> void:
	if _capture_registered and EngineDebugger.is_active():
		EngineDebugger.unregister_message_capture(_capture_prefix)
		_capture_registered = false

func _on_debugger_message(message: String, data: Array) -> bool:
	match message:
		"get_instances":
			_send_instances_list()
			return true
		
		"set_breakpoints":
			if data.size() >= 1:
				_set_breakpoints(data[0])
			return true
		
		"get_variable":
			if data.size() >= 2:
				_send_variable(data[0], data[1])
			return true
		
		"get_all_variables":
			if data.size() >= 1:
				_send_all_variables(data[0])
			return true
		
		"set_variable":
			if data.size() >= 3:
				_set_variable(data[0], data[1], data[2])
			return true
		
		"get_whenever_sections":
			if data.size() >= 1:
				_send_whenever_sections(data[0])
			return true
		
		"set_whenever_active":
			if data.size() >= 3:
				_set_whenever_active(data[0], data[1], data[2])
			return true
		
		"evaluate":
			if data.size() >= 3:
				_evaluate_code(data[0], data[1], data[2])
			return true
		
		# Step debugging commands
		"debug_continue":
			_debug_continue()
			return true
		
		"debug_step_into":
			_debug_step_into()
			return true
		
		"debug_step_over":
			_debug_step_over()
			return true
		
		"debug_step_out":
			_debug_step_out()
			return true
		
		"get_debug_state":
			_send_debug_state()
			return true
		
		"profiler_start":
			_profiler_start()
			return true
		
		"profiler_stop":
			_profiler_stop()
			return true
		
		"profiler_get_data":
			_profiler_send_data()
			return true
		
		"profiler_clear":
			_profiler_clear()
			return true
		
		# v3.2: Debugger Protocol v2 — Watch expressions & data breakpoints
		"add_watchpoint":
			if data.size() >= 1:
				_add_watchpoint(data[0])
			return true
		
		"remove_watchpoint":
			if data.size() >= 1:
				_remove_watchpoint(data[0])
			return true
		
		"clear_watchpoints":
			_clear_watchpoints()
			return true
		
		"get_watchpoints":
			_send_watchpoints()
			return true
		
		"eval_watch_expressions":
			if data.size() >= 2:
				_eval_watch_expressions(data[0], data[1])
			return true
		
		"set_conditional_breakpoint":
			if data.size() >= 3:
				_set_conditional_breakpoint(data[0], data[1], data[2])
			return true
		
		# v4.3: Visual Form Debugger — Controls Inspector
		"get_form_controls":
			if data.size() >= 1:
				_send_form_controls(data[0])
			return true
	
	return false

# ============================================================================
# BREAKPOINT MANAGEMENT
# ============================================================================

func _set_breakpoints(breakpoints_dict: Dictionary) -> void:
	"""Receive breakpoints from the editor debugger plugin."""
	_breakpoints = breakpoints_dict

# ============================================================================
# STEP DEBUGGING
# These methods are stubs for future implementation when the native
# extension exposes debug stepping methods.
# ============================================================================

func _debug_continue() -> void:
	"""Resume execution after a breakpoint or step."""
	if ClassDB.class_exists("VisualGasicLanguage"):
		VisualGasicLanguage.vg_debug_continue()

func _debug_step_into() -> void:
	"""Step to the next line, entering function calls."""
	if ClassDB.class_exists("VisualGasicLanguage"):
		VisualGasicLanguage.vg_debug_step_into()

func _debug_step_over() -> void:
	"""Step to the next line, stepping over function calls."""
	if ClassDB.class_exists("VisualGasicLanguage"):
		VisualGasicLanguage.vg_debug_step_over()

func _debug_step_out() -> void:
	"""Step out of the current function."""
	if ClassDB.class_exists("VisualGasicLanguage"):
		VisualGasicLanguage.vg_debug_step_out()

func _send_debug_state() -> void:
	"""Send the current debug state to the editor."""
	var state = {
		"step_mode": 0,
		"current_line": 0,
		"current_file": "",
		"has_error": false,
		"error_message": ""
	}
	if ClassDB.class_exists("VisualGasicLanguage"):
		state["step_mode"] = VisualGasicLanguage.vg_get_step_mode()
		state["current_line"] = VisualGasicLanguage.vg_get_current_debug_line()
		state["current_file"] = VisualGasicLanguage.vg_get_current_debug_file()
	EngineDebugger.send_message("visualgasic:debug_state", [state])

func has_breakpoint(script_path: String, line: int) -> bool:
	"""Check if there's a breakpoint at the given location.
	   Called by C++ code to determine if execution should pause."""
	if not _breakpoints.has(script_path):
		return false
	return line in _breakpoints[script_path]

func get_breakpoints_for_script(script_path: String) -> Array:
	"""Get all breakpoint line numbers for a script."""
	if _breakpoints.has(script_path):
		return _breakpoints[script_path]
	return []

func register_instance(instance: Object, script_path: String) -> int:
	var id = _next_instance_id
	_next_instance_id += 1
	
	var node_name = instance.name if instance is Node else "Instance"
	print("[VGDebug] Registering instance #%d: %s (%s)" % [id, node_name, script_path])
	
	_registered_instances[id] = {
		"instance": weakref(instance),
		"script_path": script_path,
		"node_name": node_name,
		"node_path": str(instance.get_path()) if instance is Node else ""
	}
	
	# Notify editor that instances changed
	if EngineDebugger.is_active():
		_send_instances_list()
	
	return id

func unregister_instance(instance_id: int) -> void:
	_registered_instances.erase(instance_id)
	
	if EngineDebugger.is_active():
		_send_instances_list()

func _send_instances_list() -> void:
	var instances = []
	var to_remove = []
	
	for id in _registered_instances:
		var info = _registered_instances[id]
		var ref = info["instance"] as WeakRef
		if ref and ref.get_ref():
			instances.append({
				"id": id,
				"script_path": info["script_path"],
				"node_name": info["node_name"],
				"node_path": info["node_path"]
			})
		else:
			to_remove.append(id)
	
	# Clean up dead references
	for id in to_remove:
		_registered_instances.erase(id)
	
	EngineDebugger.send_message("visualgasic:instances", [instances])

func _get_instance(instance_id: int) -> Object:
	if not _registered_instances.has(instance_id):
		return null
	
	var info = _registered_instances[instance_id]
	var ref = info["instance"] as WeakRef
	if ref:
		return ref.get_ref()
	return null

func _get_instance_by_cpp_index(index: int) -> Object:
	"""Fallback lookup: when the C++ extension is active, instance IDs sent
	   from the editor are 0-based array indexes into the C++ registry, not
	   GDScript _registered_instances keys.  Use the VisualGasicLanguage
	   static helper to resolve them."""
	if not ClassDB.class_exists("VisualGasicLanguage"):
		return null
	var instances: Array = VisualGasicLanguage.vg_get_running_instances()
	if index < 0 or index >= instances.size():
		return null
	var info: Dictionary = instances[index]
	var owner_id = info.get("owner_id", 0)
	if owner_id == 0:
		return null
	return instance_from_id(owner_id)

func _get_instance_flexible(instance_id: int) -> Object:
	"""Try GDScript registration first, then C++ index-based lookup."""
	var inst = _get_instance(instance_id)
	if inst == null:
		inst = _get_instance_by_cpp_index(instance_id)
	return inst

func _send_variable(instance_id: int, var_name: String) -> void:
	var inst = _get_instance_flexible(instance_id)
	if inst == null:
		EngineDebugger.send_message("visualgasic:variable", [var_name, null])
		return
	
	# Use the internal method to get the variable
	var value = null
	if inst.has_method("_vg_get_variable"):
		value = inst._vg_get_variable(var_name)
	else:
		value = inst.get(var_name)
	EngineDebugger.send_message("visualgasic:variable", [var_name, value])

func _send_all_variables(instance_id: int) -> void:
	var inst = _get_instance_flexible(instance_id)
	if inst == null:
		EngineDebugger.send_message("visualgasic:variables_list", [{}])
		return
	
	# Use the internal method to get all VisualGasic script variables
	var vars = {}
	if inst.has_method("_vg_get_all_variables"):
		vars = inst.call("_vg_get_all_variables")
	else:
		# Fallback: try property list (won't find internal vars)
		var props = inst.get_property_list()
		for prop in props:
			var name = prop["name"]
			if name.begins_with("_") or name in ["script", "Script Variables"]:
				continue
			if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				vars[name] = inst.get(name)
	
	EngineDebugger.send_message("visualgasic:variables_list", [vars])

func _set_variable(instance_id: int, var_name: String, value: Variant) -> void:
	var inst = _get_instance_flexible(instance_id)
	if inst == null:
		return
	
	# Parse the value string to the appropriate type
	var parsed_value = _parse_value(value)
	print("[VGDebug] SET: %s = %s" % [var_name, str(parsed_value)])
	
	# Use the internal method to set the variable
	if inst.has_method("_vg_set_variable"):
		inst.call("_vg_set_variable", var_name, parsed_value)
	else:
		inst.set(var_name, parsed_value)

func _parse_value(value: Variant) -> Variant:
	"""Parse a string value to the appropriate type"""
	if not value is String:
		return value
	
	var str_val: String = value.strip_edges()
	
	# Boolean
	if str_val.to_lower() == "true":
		return true
	if str_val.to_lower() == "false":
		return false
	
	# Integer (check before float since integers are also valid floats)
	if str_val.is_valid_int():
		return str_val.to_int()
	
	# Float
	if str_val.is_valid_float():
		return str_val.to_float()
	
	# String with quotes
	if (str_val.begins_with("\"") and str_val.ends_with("\"")) or \
	   (str_val.begins_with("'") and str_val.ends_with("'")):
		return str_val.substr(1, str_val.length() - 2)
	
	# Return as-is (could be a string without quotes)
	return str_val

func _evaluate_code(instance_id: int, code: String, request_id: int) -> void:
	var inst = _get_instance_flexible(instance_id)
	var result = {"success": false, "result": "Instance not found"}
	
	if inst != null:
		# Try to evaluate using the instance's call method if it has one
		if inst.has_method("_vg_immediate_eval"):
			result = inst._vg_immediate_eval(code)
		else:
			# Fallback: try to get a variable value
			var upper = code.strip_edges().to_upper()
			if upper.begins_with("PRINT ") or code.strip_edges().begins_with("? "):
				var var_name = ""
				if code.strip_edges().begins_with("? "):
					var_name = code.strip_edges().substr(2).strip_edges()
				else:
					var_name = code.strip_edges().substr(6).strip_edges()
				
				var value = inst.get(var_name)
				result = {"success": true, "result": str(value)}
			elif "=" in code and not "==" in code:
				# Assignment
				var parts = code.split("=", true, 1)
				var var_name = parts[0].strip_edges()
				var value_str = parts[1].strip_edges() if parts.size() > 1 else ""
				
				# Parse simple values
				var value: Variant
				if value_str.is_valid_int():
					value = value_str.to_int()
				elif value_str.is_valid_float():
					value = value_str.to_float()
				else:
					value = value_str
				
				inst.set(var_name, value)
				result = {"success": true, "result": var_name + " = " + str(value)}
			else:
				# Try to get as variable
				var value = inst.get(code.strip_edges())
				if value != null:
					result = {"success": true, "result": str(value)}
				else:
					result = {"success": false, "result": "Unknown command: " + code}
	
	EngineDebugger.send_message("visualgasic:eval_result", [request_id, result])

func _send_whenever_sections(instance_id: int) -> void:
	var inst = _get_instance_flexible(instance_id)
	if inst == null:
		EngineDebugger.send_message("visualgasic:whenever_sections", [[]])
		return
	
	# Use the internal method to get Whenever sections
	var sections = []
	if inst.has_method("_vg_get_whenever_sections"):
		sections = inst.call("_vg_get_whenever_sections")
	
	EngineDebugger.send_message("visualgasic:whenever_sections", [sections])

func _set_whenever_active(instance_id: int, section_name: String, active: bool) -> void:
	var inst = _get_instance_flexible(instance_id)
	if inst == null:
		return
	
	if inst.has_method("_vg_set_whenever_active"):
		inst.call("_vg_set_whenever_active", section_name, active)
		# Send updated sections list
		_send_whenever_sections(instance_id)

# ============================================================================
# PROFILER COMMANDS
# ============================================================================

func _profiler_start() -> void:
	"""Enable C++ profiler and start collecting data."""
	# Call the C++ VisualGasicProfiler singleton
	for inst_id in _registered_instances:
		var inst = _get_instance(inst_id)
		if inst and inst.has_method("_vg_profiler_enable"):
			inst.call("_vg_profiler_enable", true)
	print("[VisualGasic] Profiler started")

func _profiler_stop() -> void:
	"""Disable C++ profiler."""
	for inst_id in _registered_instances:
		var inst = _get_instance(inst_id)
		if inst and inst.has_method("_vg_profiler_enable"):
			inst.call("_vg_profiler_enable", false)
	print("[VisualGasic] Profiler stopped")

func _profiler_send_data() -> void:
	"""Collect profiler report from C++ and send to editor."""
	var report: Dictionary = {}
	for inst_id in _registered_instances:
		var inst = _get_instance(inst_id)
		if inst and inst.has_method("_vg_profiler_get_report"):
			report = inst.call("_vg_profiler_get_report")
			break  # One report covers the global profiler
	if report.is_empty():
		# Build a minimal empty report so the editor panel still updates
		report = {"profiles": {}, "counters": {}}
	EngineDebugger.send_message("visualgasic:profiler_data", [report])

func _profiler_clear() -> void:
	"""Reset C++ profiler counters."""
	for inst_id in _registered_instances:
		var inst = _get_instance(inst_id)
		if inst and inst.has_method("_vg_profiler_clear"):
			inst.call("_vg_profiler_clear")
	print("[VisualGasic] Profiler counters cleared")

# ============================================================================
# v3.2: DEBUGGER PROTOCOL v2 — Watch Expressions & Data Breakpoints
# ============================================================================

func _add_watchpoint(variable_name: String) -> void:
	"""Add a data breakpoint (watchpoint) on a variable."""
	if ClassDB.class_exists("VisualGasicLanguage"):
		VisualGasicLanguage.vg_add_watchpoint(variable_name)
	EngineDebugger.send_message("visualgasic:watchpoint_added", [variable_name])

func _remove_watchpoint(variable_name: String) -> void:
	"""Remove a data breakpoint (watchpoint)."""
	if ClassDB.class_exists("VisualGasicLanguage"):
		VisualGasicLanguage.vg_remove_watchpoint(variable_name)
	EngineDebugger.send_message("visualgasic:watchpoint_removed", [variable_name])

func _clear_watchpoints() -> void:
	"""Clear all data breakpoints."""
	if ClassDB.class_exists("VisualGasicLanguage"):
		VisualGasicLanguage.vg_clear_watchpoints()
	EngineDebugger.send_message("visualgasic:watchpoints_cleared", [])

func _send_watchpoints() -> void:
	"""Send current watchpoint list to editor."""
	var watchpoints: Array = []
	if ClassDB.class_exists("VisualGasicLanguage"):
		watchpoints = VisualGasicLanguage.vg_get_watchpoints()
	EngineDebugger.send_message("visualgasic:watchpoints_list", [watchpoints])

func _eval_watch_expressions(instance_id: int, expressions: Array) -> void:
	"""Evaluate a list of watch expressions and send results back.
	   Each expression is evaluated in the context of the given instance."""
	var results: Array = []
	var inst = _get_instance_flexible(instance_id)
	
	for expr in expressions:
		var result_entry: Dictionary = {"expr": expr, "value": "", "error": false}
		if inst == null:
			result_entry["value"] = "<no instance>"
			result_entry["error"] = true
		elif inst.has_method("_vg_get_variable"):
			# Try simple variable lookup first
			var val = inst.call("_vg_get_variable", expr)
			if val != null:
				result_entry["value"] = str(val)
			else:
				# Fall back to C++ expression evaluator
				if ClassDB.class_exists("VisualGasicLanguage"):
					var eval_result = VisualGasicLanguage.vg_evaluate_expression(expr)
					result_entry["value"] = eval_result
				else:
					result_entry["value"] = "<cannot evaluate>"
					result_entry["error"] = true
		else:
			# Try direct property access
			var val = inst.get(expr)
			if val != null:
				result_entry["value"] = str(val)
			else:
				result_entry["value"] = "<undefined>"
				result_entry["error"] = true
		results.append(result_entry)
	
	EngineDebugger.send_message("visualgasic:watch_results", [results])

func _set_conditional_breakpoint(script_path: String, line: int, condition: String) -> void:
	"""Set a conditional breakpoint via the C++ debugger."""
	# Use the global debugger instance — do NOT instantiate a throwaway one,
	# as breakpoint data would be lost when the temporary object is freed.
	if ClassDB.class_exists("VisualGasicDebugger") and ClassDB.class_has_method("VisualGasicDebugger", "get_global_debugger"):
		var global_debugger = ClassDB.instantiate("VisualGasicDebugger").call("get_global_debugger")
		if global_debugger:
			global_debugger.set_breakpoint(script_path, line, condition)
		else:
			# Fallback: store in our own breakpoint dict with condition metadata
			if not _breakpoints.has(script_path):
				_breakpoints[script_path] = []
			if line not in _breakpoints[script_path]:
				_breakpoints[script_path].append(line)
			# Store condition in a separate dict for the C++ conditional check
			if not has_meta("_conditional_bps"):
				set_meta("_conditional_bps", {})
			var cond_bps: Dictionary = get_meta("_conditional_bps")
			cond_bps["%s:%d" % [script_path, line]] = condition
			set_meta("_conditional_bps", cond_bps)
	print("[VisualGasic] Conditional breakpoint set at %s:%d [%s]" % [script_path, line, condition])
	EngineDebugger.send_message("visualgasic:conditional_bp_set", [script_path, line, condition])

# ============================================================================
# v4.3: VISUAL FORM DEBUGGER — Controls Inspector
# ============================================================================

func _send_form_controls(instance_id: int) -> void:
	"""Collect all child controls of the instance's owner Node and send
	   their names, types, and key properties to the editor."""
	var inst = _get_instance_flexible(instance_id)
	if inst == null:
		EngineDebugger.send_message("visualgasic:form_controls", [[]])
		return
	
	var owner_node: Node = inst if inst is Node else null
	if owner_node == null:
		EngineDebugger.send_message("visualgasic:form_controls", [[]])
		return
	
	var controls: Array = []
	_collect_controls(owner_node, controls)
	EngineDebugger.send_message("visualgasic:form_controls", [controls])

func _collect_controls(node: Node, out: Array) -> void:
	"""Recursively collect child controls with their properties."""
	for child in node.get_children():
		var entry: Dictionary = {}
		entry["name"] = child.name
		entry["type"] = child.get_class()
		entry["path"] = str(child.get_path())
		
		var props: Dictionary = {}
		# Collect commonly inspected VB6-style properties
		if child is Control:
			props["Visible"] = child.visible
			props["Position"] = str(child.position)
			props["Size"] = str(child.size)
			props["Enabled"] = not child.is_set_as_top_level() if child.has_method("is_set_as_top_level") else true
		
		if child is BaseButton:
			props["Text"] = child.text if "text" in child else ""
			props["Disabled"] = child.disabled
			props["Pressed"] = child.button_pressed if child.toggle_mode else false
		
		if child is Label:
			props["Text"] = child.text
			props["AutoSize"] = child.autowrap_mode != TextServer.AUTOWRAP_OFF
		
		if child is LineEdit:
			props["Text"] = child.text
			props["MaxLength"] = child.max_length
			props["ReadOnly"] = not child.editable
			props["PasswordChar"] = child.secret_character if child.secret else ""
		
		if child is TextEdit:
			props["Text"] = child.text
			props["ReadOnly"] = not child.editable
		
		if child is Range:
			props["Value"] = child.value
			props["Min"] = child.min_value
			props["Max"] = child.max_value
		
		if child is ItemList:
			props["ListCount"] = child.item_count
		
		if child is OptionButton:
			props["ListCount"] = child.item_count
			props["Selected"] = child.selected
			if child.selected >= 0 and child.selected < child.item_count:
				props["SelectedText"] = child.get_item_text(child.selected)
		
		if child is CheckBox or child is CheckButton:
			props["Checked"] = child.button_pressed
			props["Text"] = child.text
		
		if child is ProgressBar:
			props["Value"] = child.value
			props["Min"] = child.min_value
			props["Max"] = child.max_value
		
		if child is Timer:
			props["Interval"] = child.wait_time
			props["Enabled"] = not child.is_stopped()
			props["OneShot"] = child.one_shot
		
		if child is TabContainer:
			props["CurrentTab"] = child.current_tab
			props["TabCount"] = child.get_tab_count()
		
		# Always include modulate/self_modulate for color debugging
		if child is CanvasItem:
			if child.modulate != Color(1, 1, 1, 1):
				props["Modulate"] = str(child.modulate)
			if child.self_modulate != Color(1, 1, 1, 1):
				props["SelfModulate"] = str(child.self_modulate)
		
		entry["properties"] = props
		out.append(entry)
		
		# Recurse into children (but skip deeply nested internal nodes)
		if child.get_child_count() > 0 and child.get_child_count() < 50:
			_collect_controls(child, out)