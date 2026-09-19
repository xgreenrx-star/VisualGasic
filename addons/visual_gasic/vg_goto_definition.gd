@tool
extends RefCounted
## VisualGasic Go to Definition
##
## Navigates to the definition of a symbol:
## - Ctrl+Click or right-click → Go To Definition on identifier
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
		# Imported modules declared in the current file take priority over workspace scan
		var imports := parse_imports(FileAccess.get_file_as_string(current_file) if FileAccess.file_exists(current_file) else "", current_file)
		found = find_in_imports(symbol, imports)
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


# =============================================================================
# IMPORT / MODULE RESOLUTION
# =============================================================================

## Resolve an Import path relative to the current .vg file and project root.
static func resolve_import_path(import_spec: String, current_file: String) -> String:
	if import_spec.is_empty():
		return ""
	var spec := import_spec.strip_edges()
	if spec.begins_with("res://") or spec.begins_with("user://"):
		return spec if FileAccess.file_exists(spec) else ""
	var try_paths: Array[String] = [
		"res://" + spec,
		"res://" + spec.get_file(),
	]
	if not current_file.is_empty():
		var base_dir := current_file.get_base_dir()
		try_paths.append(base_dir.path_join(spec))
		try_paths.append(base_dir.path_join(spec.get_file()))
	for tp in try_paths:
		if FileAccess.file_exists(tp):
			return tp
	return ""


## Parse Import directives from source text.
## Returns [{name, path, public_subs, private_subs, variables, constants}] —
## subs entries are {name, line} with 0-based line numbers.
static func parse_imports(source: String, current_file: String = "") -> Array[Dictionary]:
	var modules: Array[Dictionary] = []
	if source.is_empty():
		return modules
	var import_re := RegEx.new()
	import_re.compile("(?i)^\\s*Import\\s+(?:\"([^\"]+)\"|([\\w]+))")
	for line_text in source.split("\n"):
		var m := import_re.search(line_text)
		if not m:
			continue
		var import_path := m.get_string(1)
		var import_name := m.get_string(2)
		var mod_name := ""
		var mod_path := ""
		if not import_path.is_empty():
			mod_path = import_path
			mod_name = import_path.get_file().get_basename()
		elif not import_name.is_empty():
			mod_name = import_name
			mod_path = import_name + ".vg"
		if mod_name.is_empty():
			continue
		var resolved := resolve_import_path(mod_path, current_file)
		if resolved.is_empty():
			modules.append({
				"name": mod_name,
				"path": "",
				"public_subs": [],
				"private_subs": [],
				"variables": [],
				"constants": [],
			})
		else:
			modules.append(parse_module_file(resolved, mod_name))
	return modules


## Parse a .vg module file for public/private symbols and VB_Name override.
static func parse_module_file(file_path: String, fallback_name: String = "") -> Dictionary:
	var result := {
		"name": fallback_name,
		"path": file_path,
		"public_subs": [],
		"private_subs": [],
		"variables": [],
		"constants": [],
		# Legacy keys used by IntelliSense / dot-completion
		"subs": [],
	}
	if not FileAccess.file_exists(file_path):
		return result
	var content := FileAccess.get_file_as_string(file_path)
	var lines := content.split("\n")
	var vb_name_re := RegEx.new()
	vb_name_re.compile("(?i)Attribute\\s+VB_Name\\s*=\\s*\"([^\"]+)\"")
	for line_text in lines:
		var vm := vb_name_re.search(line_text)
		if vm:
			result["name"] = vm.get_string(1)
			break
	var pub_re := RegEx.new()
	pub_re.compile("(?i)^\\s*(?:Public\\s+)?(?:Sub|Function)\\s+(\\w+)")
	var priv_re := RegEx.new()
	priv_re.compile("(?i)^\\s*Private\\s+(?:Sub|Function)\\s+(\\w+)")
	for i in lines.size():
		var stripped := lines[i].strip_edges()
		if stripped.is_empty() or stripped.begins_with("'"):
			continue
		var pm := priv_re.search(stripped)
		if pm:
			var pname := pm.get_string(1)
			result["private_subs"].append({"name": pname, "line": i})
			continue
		var sm := pub_re.search(stripped)
		if sm:
			var sname := sm.get_string(1)
			result["public_subs"].append({"name": sname, "line": i})
			result["subs"].append(sname)
	var var_re := RegEx.new()
	var_re.compile("(?i)Public\\s+(\\w+)(?:\\s+As\\s+\\w+)?")
	for m in var_re.search_all(content):
		var vname := m.get_string(1)
		if vname.to_lower() not in ["sub", "function", "const", "enum", "type", "property", "module", "class"]:
			if vname not in result["variables"]:
				result["variables"].append(vname)
	var const_re := RegEx.new()
	const_re.compile("(?i)(?:Public\\s+)?Const\\s+(\\w+)")
	for m in const_re.search_all(content):
		var cname := m.get_string(1)
		if cname not in result["constants"]:
			result["constants"].append(cname)
	return result


## Look up an unqualified or ModuleName.Member symbol in parsed imports.
static func find_in_imports(symbol: String, imports: Array, module_prefix: String = "") -> DefinitionResult:
	var result := DefinitionResult.new()
	result.symbol = symbol
	if imports.is_empty():
		return result
	if not module_prefix.is_empty():
		for mod_info in imports:
			if mod_info.get("name", "").nocasecmp_to(module_prefix) != 0:
				continue
			return _find_member_in_module(mod_info, symbol, result)
		return result
	# Unqualified — search imported public subs (VB6-style flat namespace)
	for mod_info in imports:
		var found := _find_member_in_module(mod_info, symbol, result)
		if found.found:
			return found
	return result


static func _find_member_in_module(mod_info: Dictionary, symbol: String, result: DefinitionResult) -> DefinitionResult:
	for entry in mod_info.get("public_subs", []):
		if str(entry.get("name", "")).nocasecmp_to(symbol) == 0:
			result.found = true
			result.file_path = str(mod_info.get("path", ""))
			result.line = int(entry.get("line", 0)) + 1
			result.column = 0
			result.type = "sub"
			result.signature = "Sub " + symbol + " — " + _module_display_path(mod_info)
			return result
	for vname in mod_info.get("variables", []):
		if str(vname).nocasecmp_to(symbol) == 0:
			result.found = true
			result.file_path = str(mod_info.get("path", ""))
			result.type = "variable"
			result.signature = "Public " + symbol + " — " + _module_display_path(mod_info)
			return result
	for cname in mod_info.get("constants", []):
		if str(cname).nocasecmp_to(symbol) == 0:
			result.found = true
			result.file_path = str(mod_info.get("path", ""))
			result.type = "const"
			result.signature = "Const " + symbol + " — " + _module_display_path(mod_info)
			return result
	return result


static func _module_display_path(mod_info: Dictionary) -> String:
	var p := str(mod_info.get("path", ""))
	if p.is_empty():
		return str(mod_info.get("name", "Module"))
	if p.begins_with("res://"):
		return p.substr(6)
	return p


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
