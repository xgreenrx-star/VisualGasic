extends Node
## VisualGasic Debug Handler
## This script handles debugger messages from the editor's Immediate Window
## It runs in the GAME process and responds to queries about running instances

var _registered_instances: Dictionary = {}  # instance_id -> weak reference info
var _next_instance_id: int = 1

func _ready() -> void:
	# Register our message capture with the engine debugger
	if EngineDebugger.is_active():
		EngineDebugger.register_message_capture("visualgasic", _on_debugger_message)
		print("[VisualGasic] Debug handler registered")

func _exit_tree() -> void:
	if EngineDebugger.is_active():
		EngineDebugger.unregister_message_capture("visualgasic")

func _on_debugger_message(message: String, data: Array) -> bool:
	match message:
		"get_instances":
			_send_instances_list()
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
		
		"evaluate":
			if data.size() >= 3:
				_evaluate_code(data[0], data[1], data[2])
			return true
	
	return false

func register_instance(instance: Object, script_path: String) -> int:
	var id = _next_instance_id
	_next_instance_id += 1
	
	_registered_instances[id] = {
		"instance": weakref(instance),
		"script_path": script_path,
		"node_name": instance.name if instance is Node else "Instance",
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

func _send_variable(instance_id: int, var_name: String) -> void:
	var inst = _get_instance(instance_id)
	if inst == null:
		EngineDebugger.send_message("visualgasic:variable", [var_name, null])
		return
	
	# Try to get the variable from the instance
	var value = inst.get(var_name)
	EngineDebugger.send_message("visualgasic:variable", [var_name, value])

func _send_all_variables(instance_id: int) -> void:
	var inst = _get_instance(instance_id)
	if inst == null:
		EngineDebugger.send_message("visualgasic:variables_list", [{}])
		return
	
	# Get all properties from the instance
	var vars = {}
	var props = inst.get_property_list()
	for prop in props:
		var name = prop["name"]
		# Skip internal properties
		if name.begins_with("_") or name in ["script", "Script Variables"]:
			continue
		# Only include user-defined variables (usage flag check)
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			vars[name] = inst.get(name)
	
	EngineDebugger.send_message("visualgasic:variables_list", [vars])

func _set_variable(instance_id: int, var_name: String, value: Variant) -> void:
	var inst = _get_instance(instance_id)
	if inst == null:
		return
	
	inst.set(var_name, value)

func _evaluate_code(instance_id: int, code: String, request_id: int) -> void:
	var inst = _get_instance(instance_id)
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
