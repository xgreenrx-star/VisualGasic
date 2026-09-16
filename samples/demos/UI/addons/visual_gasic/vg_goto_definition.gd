@tool
extends RefCounted
## VisualGasic Go to Definition
##
## Navigates to the definition of a symbol:
## - Ctrl+Click or F12 on identifier
## - Finds Sub, Function, Variable declarations
## - Searches current file first, then all .vg files
## - Returns file path and line number

class_name VGGoToDefinition

# =============================================================================
# DEFINITION FINDING
# =============================================================================

## Result of a definition lookup
class DefinitionResult:
	var found: bool = false
	var file_path: String = ""
	var line: int = 0
	var column: int = 0
	var symbol: String = ""
	var type: String = ""  # "sub", "function", "variable", "class", "property"
	var signature: String = ""

## Finds the definition of a symbol
static func find_definition(symbol: String, current_file: String, workspace_path: String = "res://") -> DefinitionResult:
	var result = DefinitionResult.new()
	result.symbol = symbol
	
	# Search current file first
	if not current_file.is_empty():
		var found = _search_file_for_definition(current_file, symbol)
		if found.found:
			return found
	
	# Search all .vg files
	var vg_files = _find_vg_files(workspace_path)
	for file_path in vg_files:
		if file_path == current_file:
			continue  # Already searched
		var found = _search_file_for_definition(file_path, symbol)
		if found.found:
			return found
	
	return result

## Searches a file for the definition of a symbol
static func _search_file_for_definition(file_path: String, symbol: String) -> DefinitionResult:
	var result = DefinitionResult.new()
	result.symbol = symbol
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return result
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("\n")
	var symbol_upper = symbol.to_upper()
	
	for line_num in range(lines.size()):
		var line = lines[line_num]
		var line_stripped = line.strip_edges()
		var line_upper = line_stripped.to_upper()
		
		# Skip empty lines and comments
		if line_stripped.is_empty() or line_stripped.begins_with("'"):
			continue
		
		# Check for Sub definition
		if _matches_sub_definition(line_upper, symbol_upper):
			result.found = true
			result.file_path = file_path
			result.line = line_num + 1
			result.column = line.find(symbol)
			result.type = "sub"
			result.signature = line_stripped
			return result
		
		# Check for Function definition
		if _matches_function_definition(line_upper, symbol_upper):
			result.found = true
			result.file_path = file_path
			result.line = line_num + 1
			result.column = line.find(symbol)
			result.type = "function"
			result.signature = line_stripped
			return result
		
		# Check for Property definition
		if _matches_property_definition(line_upper, symbol_upper):
			result.found = true
			result.file_path = file_path
			result.line = line_num + 1
			result.column = line.find(symbol)
			result.type = "property"
			result.signature = line_stripped
			return result
		
		# Check for Class definition
		if _matches_class_definition(line_upper, symbol_upper):
			result.found = true
			result.file_path = file_path
			result.line = line_num + 1
			result.column = line.find(symbol)
			result.type = "class"
			result.signature = line_stripped
			return result
		
		# Check for variable declaration
		if _matches_variable_declaration(line_upper, symbol_upper):
			result.found = true
			result.file_path = file_path
			result.line = line_num + 1
			result.column = line.find(symbol)
			result.type = "variable"
			result.signature = line_stripped
			return result
		
		# Check for Const definition
		if _matches_const_definition(line_upper, symbol_upper):
			result.found = true
			result.file_path = file_path
			result.line = line_num + 1
			result.column = line.find(symbol)
			result.type = "const"
			result.signature = line_stripped
			return result
	
	return result

## Checks if line matches "Sub SymbolName(" pattern
static func _matches_sub_definition(line_upper: String, symbol_upper: String) -> bool:
	var patterns = [
		"SUB " + symbol_upper + "(",
		"SUB " + symbol_upper + " ",
		"SUB " + symbol_upper,
		"PRIVATE SUB " + symbol_upper,
		"PUBLIC SUB " + symbol_upper,
	]
	for pattern in patterns:
		if line_upper.begins_with(pattern) or (" " + pattern) in line_upper:
			return true
	return false

## Checks if line matches "Function SymbolName(" pattern
static func _matches_function_definition(line_upper: String, symbol_upper: String) -> bool:
	var patterns = [
		"FUNCTION " + symbol_upper + "(",
		"FUNCTION " + symbol_upper + " ",
		"PRIVATE FUNCTION " + symbol_upper,
		"PUBLIC FUNCTION " + symbol_upper,
	]
	for pattern in patterns:
		if line_upper.begins_with(pattern) or (" " + pattern) in line_upper:
			return true
	return false

## Checks if line matches "Property Get/Let/Set SymbolName" pattern
static func _matches_property_definition(line_upper: String, symbol_upper: String) -> bool:
	var patterns = [
		"PROPERTY GET " + symbol_upper,
		"PROPERTY LET " + symbol_upper,
		"PROPERTY SET " + symbol_upper,
		"PUBLIC PROPERTY GET " + symbol_upper,
		"PUBLIC PROPERTY LET " + symbol_upper,
		"PUBLIC PROPERTY SET " + symbol_upper,
	]
	for pattern in patterns:
		if line_upper.begins_with(pattern):
			return true
	return false

## Checks if line matches "Class SymbolName" pattern
static func _matches_class_definition(line_upper: String, symbol_upper: String) -> bool:
	var patterns = [
		"CLASS " + symbol_upper,
		"PUBLIC CLASS " + symbol_upper,
		"PRIVATE CLASS " + symbol_upper,
	]
	for pattern in patterns:
		if line_upper.begins_with(pattern):
			return true
	return false

## Checks if line matches "Dim/Private/Public SymbolName As" pattern
static func _matches_variable_declaration(line_upper: String, symbol_upper: String) -> bool:
	# Look for "Dim symbol As", "Private symbol As", etc.
	var regex = RegEx.new()
	var pattern = "(?:DIM|PRIVATE|PUBLIC|STATIC)\\s+" + symbol_upper + "(?:\\s+AS|\\s*$|\\s*,)"
	regex.compile(pattern)
	return regex.search(line_upper) != null

## Checks if line matches "Const SymbolName =" pattern
static func _matches_const_definition(line_upper: String, symbol_upper: String) -> bool:
	var patterns = [
		"CONST " + symbol_upper + " ",
		"CONST " + symbol_upper + "=",
		"PUBLIC CONST " + symbol_upper,
		"PRIVATE CONST " + symbol_upper,
	]
	for pattern in patterns:
		if line_upper.begins_with(pattern) or (" " + pattern) in line_upper:
			return true
	return false

## Recursively finds all .vg files
static func _find_vg_files(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			var full_path = path.path_join(file_name)
			
			if dir.current_is_dir():
				if not file_name.begins_with(".") and file_name != "addons":
					files.append_array(_find_vg_files(full_path))
			elif file_name.ends_with(".vg"):
				files.append(full_path)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	return files

# =============================================================================
# SYMBOL EXTRACTION
# =============================================================================

## Extracts all symbols (Subs, Functions, Variables) from a file
## Useful for building a symbol index
static func extract_symbols(file_path: String) -> Array[Dictionary]:
	var symbols: Array[Dictionary] = []
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return symbols
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("\n")
	
	for line_num in range(lines.size()):
		var line = lines[line_num].strip_edges()
		var line_upper = line.to_upper()
		
		# Skip empty and comments
		if line.is_empty() or line.begins_with("'"):
			continue
		
		# Sub
		var sub_match = _extract_sub_name(line, line_upper)
		if not sub_match.is_empty():
			symbols.append({
				"name": sub_match,
				"type": "sub",
				"line": line_num + 1,
				"signature": line,
				"file": file_path
			})
			continue
		
		# Function
		var func_match = _extract_function_name(line, line_upper)
		if not func_match.is_empty():
			symbols.append({
				"name": func_match,
				"type": "function",
				"line": line_num + 1,
				"signature": line,
				"file": file_path
			})
			continue
		
		# Variable declarations
		var vars = _extract_variable_names(line, line_upper)
		for v in vars:
			symbols.append({
				"name": v,
				"type": "variable",
				"line": line_num + 1,
				"signature": line,
				"file": file_path
			})
	
	return symbols

static func _extract_sub_name(line: String, line_upper: String) -> String:
	var regex = RegEx.new()
	regex.compile("(?:PRIVATE\\s+|PUBLIC\\s+)?SUB\\s+(\\w+)")
	var match = regex.search(line_upper)
	if match:
		# Extract from original line to preserve case
		var start = match.get_start(1)
		var end = match.get_end(1)
		return line.substr(start, end - start)
	return ""

static func _extract_function_name(line: String, line_upper: String) -> String:
	var regex = RegEx.new()
	regex.compile("(?:PRIVATE\\s+|PUBLIC\\s+)?FUNCTION\\s+(\\w+)")
	var match = regex.search(line_upper)
	if match:
		var start = match.get_start(1)
		var end = match.get_end(1)
		return line.substr(start, end - start)
	return ""

static func _extract_variable_names(line: String, line_upper: String) -> Array[String]:
	var names: Array[String] = []
	var regex = RegEx.new()
	regex.compile("(?:DIM|PRIVATE|PUBLIC|STATIC)\\s+(\\w+)")
	var matches = regex.search_all(line_upper)
	for m in matches:
		var start = m.get_start(1)
		var end = m.get_end(1)
		names.append(line.substr(start, end - start))
	return names
