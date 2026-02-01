@tool
extends EditorDebuggerPlugin
## VisualGasic Debugger Plugin
## Enables communication with running VisualGasic instances via Godot's debug protocol

signal instances_updated(instances: Array)
signal variable_received(var_name: String, value: Variant)
signal variables_list_received(variables: Dictionary)

var _active_session: EditorDebuggerSession = null
var _pending_requests: Dictionary = {}
var _request_id: int = 0

func _has_capture(prefix: String) -> bool:
	return prefix == "visualgasic"

func _capture(message: String, data: Array, session_id: int) -> bool:
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
	
	return false

func _setup_session(session_id: int) -> void:
	var session = get_session(session_id)
	if session:
		_active_session = session
		# Request initial list of instances
		session.send_message("visualgasic:get_instances", [])

func _session_stopped() -> void:
	_active_session = null
	_pending_requests.clear()
	instances_updated.emit([])

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

func evaluate_code(instance_id: int, code: String, callback: Callable) -> void:
	if _active_session:
		_request_id += 1
		_pending_requests[_request_id] = callback
		_active_session.send_message("visualgasic:evaluate", [instance_id, code, _request_id])

func is_session_active() -> bool:
	return _active_session != null
