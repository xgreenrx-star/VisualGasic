@tool
extends RefCounted
## VisualGasic Conditional Breakpoint System
##
## Extends basic breakpoints with:
## - Condition expressions (break only if true)
## - Hit count conditions (break on Nth hit)
## - Log messages instead of breaking
## - Temporary breakpoints (delete after first hit)

class_name VGBreakpointConditions

# =============================================================================
# TYPES
# =============================================================================

enum HitCountType {
	NONE,           ## Always break
	EQUALS,         ## Break when hit count == value
	GREATER_EQUAL,  ## Break when hit count >= value
	MULTIPLE,       ## Break when hit count is multiple of value
}

## Breakpoint information
class BreakpointInfo:
	var line: int = 0
	var enabled: bool = true
	var condition: String = ""            ## Expression that must be true
	var hit_count_type: HitCountType = HitCountType.NONE
	var hit_count_value: int = 0          ## Target hit count
	var current_hits: int = 0             ## Current hit counter
	var log_message: String = ""          ## Log instead of break (if not empty)
	var is_temporary: bool = false        ## Delete after first break
	
	func to_dict() -> Dictionary:
		return {
			"line": line,
			"enabled": enabled,
			"condition": condition,
			"hit_count_type": hit_count_type,
			"hit_count_value": hit_count_value,
			"current_hits": current_hits,
			"log_message": log_message,
			"is_temporary": is_temporary
		}
	
	static func from_dict(data: Dictionary) -> BreakpointInfo:
		var bp = BreakpointInfo.new()
		bp.line = data.get("line", 0)
		bp.enabled = data.get("enabled", true)
		bp.condition = data.get("condition", "")
		bp.hit_count_type = data.get("hit_count_type", HitCountType.NONE)
		bp.hit_count_value = data.get("hit_count_value", 0)
		bp.current_hits = data.get("current_hits", 0)
		bp.log_message = data.get("log_message", "")
		bp.is_temporary = data.get("is_temporary", false)
		return bp

# =============================================================================
# STORAGE
# =============================================================================

## Key: script_path (String), Value: Dictionary of {line: BreakpointInfo}
var _breakpoints: Dictionary = {}

## Config file path
const CONFIG_PATH = "user://vg_breakpoints.cfg"

# =============================================================================
# BREAKPOINT MANAGEMENT
# =============================================================================

## Adds or updates a breakpoint
func set_breakpoint(script_path: String, line: int, info: BreakpointInfo = null) -> BreakpointInfo:
	if not _breakpoints.has(script_path):
		_breakpoints[script_path] = {}
	
	if info == null:
		info = BreakpointInfo.new()
		info.line = line
	
	_breakpoints[script_path][line] = info
	_save_breakpoints()
	return info

## Removes a breakpoint
func remove_breakpoint(script_path: String, line: int) -> void:
	if _breakpoints.has(script_path):
		_breakpoints[script_path].erase(line)
		if _breakpoints[script_path].is_empty():
			_breakpoints.erase(script_path)
	_save_breakpoints()

## Gets breakpoint info
func get_breakpoint(script_path: String, line: int) -> BreakpointInfo:
	if _breakpoints.has(script_path) and _breakpoints[script_path].has(line):
		return _breakpoints[script_path][line]
	return null

## Gets all breakpoints for a script
func get_breakpoints_for_script(script_path: String) -> Array[BreakpointInfo]:
	var result: Array[BreakpointInfo] = []
	if _breakpoints.has(script_path):
		for bp in _breakpoints[script_path].values():
			result.append(bp)
	return result

## Gets all breakpoints
func get_all_breakpoints() -> Dictionary:
	return _breakpoints.duplicate(true)

## Clears all breakpoints for a script
func clear_script_breakpoints(script_path: String) -> void:
	_breakpoints.erase(script_path)
	_save_breakpoints()

## Clears all breakpoints
func clear_all_breakpoints() -> void:
	_breakpoints.clear()
	_save_breakpoints()

## Enables/disables a breakpoint
func set_enabled(script_path: String, line: int, enabled: bool) -> void:
	var bp = get_breakpoint(script_path, line)
	if bp:
		bp.enabled = enabled
		_save_breakpoints()

# =============================================================================
# CONDITION CHECKING
# =============================================================================

## Checks if we should break at this location
## Returns: true = break, false = continue
func should_break(script_path: String, line: int, context: Dictionary = {}) -> Dictionary:
	var result = {
		"should_break": false,
		"log_message": "",
		"remove_breakpoint": false
	}
	
	var bp = get_breakpoint(script_path, line)
	if bp == null or not bp.enabled:
		return result
	
	# Increment hit counter
	bp.current_hits += 1
	
	# Check hit count condition
	if not _check_hit_count(bp):
		return result
	
	# Check expression condition
	if not bp.condition.is_empty():
		var condition_result = _evaluate_condition(bp.condition, context)
		if not condition_result:
			return result
	
	# If we have a log message, log instead of breaking
	if not bp.log_message.is_empty():
		result["log_message"] = _format_log_message(bp.log_message, context)
		# Still break if there's no log message replacement
		if "{" in bp.log_message:
			return result
	
	# Should break!
	result["should_break"] = true
	
	# If temporary, mark for removal
	if bp.is_temporary:
		result["remove_breakpoint"] = true
	
	return result

## Checks if hit count condition is satisfied
func _check_hit_count(bp: BreakpointInfo) -> bool:
	match bp.hit_count_type:
		HitCountType.NONE:
			return true
		HitCountType.EQUALS:
			return bp.current_hits == bp.hit_count_value
		HitCountType.GREATER_EQUAL:
			return bp.current_hits >= bp.hit_count_value
		HitCountType.MULTIPLE:
			return bp.hit_count_value > 0 and bp.current_hits % bp.hit_count_value == 0
	return true

## Evaluates a condition expression
## @param condition: Expression like "x > 5" or "name == \"test\""
## @param context: Dictionary of variable values
func _evaluate_condition(condition: String, context: Dictionary) -> bool:
	if condition.is_empty():
		return true
	
	# Simple expression evaluation
	# Replace variable names with values
	var expr_str = condition
	for var_name in context:
		var value = context[var_name]
		var value_str: String
		if value is String:
			value_str = "\"%s\"" % value
		elif value == null:
			value_str = "null"
		else:
			value_str = str(value)
		expr_str = expr_str.replace(var_name, value_str)
	
	# Use Expression class to evaluate
	var expression = Expression.new()
	var parse_error = expression.parse(expr_str)
	if parse_error != OK:
		push_warning("VGBreakpoints: Failed to parse condition: %s" % condition)
		return true  # Break on parse error
	
	var result = expression.execute()
	if expression.has_execute_failed():
		push_warning("VGBreakpoints: Failed to execute condition: %s" % condition)
		return true  # Break on execution error
	
	return bool(result)

## Formats a log message with variable substitution
## @param message: Message with {variable} placeholders
## @param context: Dictionary of variable values
func _format_log_message(message: String, context: Dictionary) -> String:
	var result = message
	for var_name in context:
		result = result.replace("{%s}" % var_name, str(context[var_name]))
	return result

# =============================================================================
# PERSISTENCE
# =============================================================================

func _save_breakpoints() -> void:
	var config = ConfigFile.new()
	
	for script_path in _breakpoints:
		var script_section = script_path.replace("/", "_").replace(".", "_")
		for line in _breakpoints[script_path]:
			var bp: BreakpointInfo = _breakpoints[script_path][line]
			config.set_value(script_section, "line_%d" % line, bp.to_dict())
		config.set_value(script_section, "_script_path", script_path)
	
	config.save(CONFIG_PATH)

func load_breakpoints() -> void:
	_breakpoints.clear()
	
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	
	for section in config.get_sections():
		var script_path = config.get_value(section, "_script_path", "")
		if script_path.is_empty():
			continue
		
		_breakpoints[script_path] = {}
		
		for key in config.get_section_keys(section):
			if key.begins_with("line_"):
				var data = config.get_value(section, key, {})
				var bp = BreakpointInfo.from_dict(data)
				_breakpoints[script_path][bp.line] = bp

## Exports breakpoints to simple format for runtime
## Returns: Dictionary of {script_path: [line_numbers]}
func export_for_runtime() -> Dictionary:
	var result: Dictionary = {}
	
	for script_path in _breakpoints:
		var lines: Array[int] = []
		for line in _breakpoints[script_path]:
			var bp: BreakpointInfo = _breakpoints[script_path][line]
			if bp.enabled:
				lines.append(line)
		if not lines.is_empty():
			result[script_path] = lines
	
	return result

## Resets all hit counters (e.g., when starting a new debug session)
func reset_hit_counters() -> void:
	for script_path in _breakpoints:
		for line in _breakpoints[script_path]:
			_breakpoints[script_path][line].current_hits = 0
