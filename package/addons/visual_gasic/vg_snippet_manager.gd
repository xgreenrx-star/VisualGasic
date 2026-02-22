@tool
extends RefCounted
## VisualGasic Snippet Manager
##
## Manages reusable code snippets with variables:
## - Built-in VB6 templates
## - User-defined snippets
## - Tab stops and placeholders
## - Category organization

class_name VGSnippetManager

# =============================================================================
# SNIPPET DATA
# =============================================================================

## A code snippet with metadata
class Snippet:
	var name: String = ""
	var prefix: String = ""  # Trigger text
	var description: String = ""
	var category: String = "General"
	var body: String = ""  # Snippet content with placeholders
	var is_builtin: bool = false
	
	func _to_string() -> String:
		return "%s (%s)" % [name, prefix]

# Placeholder pattern: ${1:default} or $1
const PLACEHOLDER_REGEX = "\\$\\{(\\d+)(?::([^}]*))?\\}|\\$(\\d+)"

# =============================================================================
# BUILT-IN SNIPPETS
# =============================================================================

static var _builtin_snippets: Array[Snippet] = []
static var _user_snippets: Array[Snippet] = []
static var _initialized: bool = false

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_init_builtin_snippets()

static func _init_builtin_snippets() -> void:
	_builtin_snippets.clear()
	
	# -- Control Flow --
	_add_builtin("If Statement", "if", "Control Flow",
		"If ${1:condition} Then\n\t${2:' code}\nEnd If",
		"If-Then-End If block")
	
	_add_builtin("If-Else Statement", "ife", "Control Flow",
		"If ${1:condition} Then\n\t${2:' true}\nElse\n\t${3:' false}\nEnd If",
		"If-Then-Else-End If block")
	
	_add_builtin("If-ElseIf-Else", "ifel", "Control Flow",
		"If ${1:condition1} Then\n\t${2:' first}\nElseIf ${3:condition2} Then\n\t${4:' second}\nElse\n\t${5:' default}\nEnd If",
		"If with ElseIf and Else")
	
	_add_builtin("Select Case", "sel", "Control Flow",
		"Select Case ${1:expression}\n\tCase ${2:value1}\n\t\t${3:' code}\n\tCase ${4:value2}\n\t\t${5:' code}\n\tCase Else\n\t\t${6:' default}\nEnd Select",
		"Select Case statement")
	
	# -- Loops --
	_add_builtin("For Loop", "for", "Loops",
		"For ${1:i} = ${2:0} To ${3:10}\n\t${4:' code}\nNext ${1:i}",
		"For-Next loop")
	
	_add_builtin("For Step Loop", "fors", "Loops",
		"For ${1:i} = ${2:0} To ${3:10} Step ${4:1}\n\t${5:' code}\nNext ${1:i}",
		"For-Next loop with Step")
	
	_add_builtin("For Each Loop", "fore", "Loops",
		"For Each ${1:item} In ${2:collection}\n\t${3:' code}\nNext ${1:item}",
		"For Each-Next loop")
	
	_add_builtin("Do While Loop", "dow", "Loops",
		"Do While ${1:condition}\n\t${2:' code}\nLoop",
		"Do While-Loop")
	
	_add_builtin("Do Until Loop", "dou", "Loops",
		"Do Until ${1:condition}\n\t${2:' code}\nLoop",
		"Do Until-Loop")
	
	_add_builtin("Do-Loop While", "dolw", "Loops",
		"Do\n\t${1:' code}\nLoop While ${2:condition}",
		"Do-Loop While (runs at least once)")
	
	_add_builtin("While-Wend Loop", "whi", "Loops",
		"While ${1:condition}\n\t${2:' code}\nWend",
		"While-Wend loop")
	
	# -- Procedures --
	_add_builtin("Sub Procedure", "sub", "Procedures",
		"Sub ${1:ProcedureName}(${2:})\n\t${3:' code}\nEnd Sub",
		"Sub procedure")
	
	_add_builtin("Private Sub", "psub", "Procedures",
		"Private Sub ${1:ProcedureName}(${2:})\n\t${3:' code}\nEnd Sub",
		"Private Sub procedure")
	
	_add_builtin("Function", "func", "Procedures",
		"Function ${1:FunctionName}(${2:}) As ${3:Variant}\n\t${4:' code}\n\t${1:FunctionName} = ${5:result}\nEnd Function",
		"Function with return")
	
	_add_builtin("Private Function", "pfunc", "Procedures",
		"Private Function ${1:FunctionName}(${2:}) As ${3:Variant}\n\t${4:' code}\n\t${1:FunctionName} = ${5:result}\nEnd Function",
		"Private Function")
	
	# -- Properties --
	_add_builtin("Property Get", "propg", "Properties",
		"Property Get ${1:PropertyName}() As ${2:Variant}\n\t${1:PropertyName} = m_${1:PropertyName}\nEnd Property",
		"Property Get accessor")
	
	_add_builtin("Property Let", "propl", "Properties",
		"Property Let ${1:PropertyName}(ByVal value As ${2:Variant})\n\tm_${1:PropertyName} = value\nEnd Property",
		"Property Let mutator")
	
	_add_builtin("Property Set", "props", "Properties",
		"Property Set ${1:PropertyName}(ByVal value As ${2:Object})\n\tSet m_${1:PropertyName} = value\nEnd Property",
		"Property Set for objects")
	
	_add_builtin("Full Property", "propf", "Properties",
		"Private m_${1:PropertyName} As ${2:Variant}\n\nProperty Get ${1:PropertyName}() As ${2:Variant}\n\t${1:PropertyName} = m_${1:PropertyName}\nEnd Property\n\nProperty Let ${1:PropertyName}(ByVal value As ${2:Variant})\n\tm_${1:PropertyName} = value\nEnd Property",
		"Complete property with backing field")
	
	# -- Error Handling --
	_add_builtin("Try-Catch", "try", "Error Handling",
		"Try\n\t${1:' code that might fail}\nCatch ${2:ex} As Exception\n\t${3:' handle error}\nEnd Try",
		"Try-Catch error handling")
	
	_add_builtin("Try-Catch-Finally", "tryf", "Error Handling",
		"Try\n\t${1:' code}\nCatch ${2:ex} As Exception\n\t${3:' handle error}\nFinally\n\t${4:' cleanup}\nEnd Try",
		"Try-Catch with Finally")
	
	_add_builtin("On Error Resume Next", "oern", "Error Handling",
		"On Error Resume Next\n${1:' code}\nIf Err.Number <> 0 Then\n\t${2:' handle}\nEnd If\nOn Error GoTo 0",
		"Classic VB6 error handling")
	
	# -- Declarations --
	_add_builtin("Dim Variable", "dim", "Declarations",
		"Dim ${1:varName} As ${2:Variant}",
		"Declare a variable")
	
	_add_builtin("Dim Array", "dima", "Declarations",
		"Dim ${1:arrName}(${2:0} To ${3:10}) As ${4:Variant}",
		"Declare an array")
	
	_add_builtin("Const Declaration", "const", "Declarations",
		"Const ${1:CONST_NAME} As ${2:String} = ${3:\"value\"}",
		"Declare a constant")
	
	_add_builtin("Enum Declaration", "enum", "Declarations",
		"Enum ${1:EnumName}\n\t${2:Value1} = ${3:0}\n\t${4:Value2} = ${5:1}\nEnd Enum",
		"Declare an enumeration")
	
	_add_builtin("Struct Declaration", "struct", "Declarations",
		"Struct ${1:StructName}\n\t${2:Field1} As ${3:String}\n\t${4:Field2} As ${5:Integer}\nEnd Struct",
		"Declare a structure")
	
	# -- Events --
	_add_builtin("Form Load", "fload", "Events",
		"Private Sub Form_Load()\n\t${1:' initialization}\nEnd Sub",
		"Form Load event handler")
	
	_add_builtin("Button Click", "btnc", "Events",
		"Private Sub ${1:Button1}_Click()\n\t${2:' handle click}\nEnd Sub",
		"Button Click event handler")
	
	_add_builtin("Timer Event", "timer", "Events",
		"Private Sub ${1:Timer1}_Timer()\n\t${2:' periodic code}\nEnd Sub",
		"Timer event handler")
	
	# -- Game Development --
	_add_builtin("Process Function", "proc", "Game",
		"Sub _process(delta As Single)\n\t${1:' per-frame logic}\nEnd Sub",
		"Godot _process callback")
	
	_add_builtin("Ready Function", "ready", "Game",
		"Sub _ready()\n\t${1:' initialization}\nEnd Sub",
		"Godot _ready callback")
	
	_add_builtin("Input Function", "input", "Game",
		"Sub _input(event As InputEvent)\n\t${1:' handle input}\nEnd Sub",
		"Godot _input callback")
	
	_add_builtin("Physics Process", "phys", "Game",
		"Sub _physics_process(delta As Single)\n\t${1:' physics logic}\nEnd Sub",
		"Godot _physics_process callback")
	
	# -- Utility --
	_add_builtin("Message Box", "msg", "Utility",
		"MsgBox ${1:\"Message\"}, ${2:vbOKOnly}, ${3:\"Title\"}",
		"Display a message box")
	
	_add_builtin("Input Box", "inp", "Utility",
		"${1:result} = InputBox(${2:\"Prompt\"}, ${3:\"Title\"}, ${4:\"Default\"})",
		"Get user input")
	
	_add_builtin("Debug Print", "dbg", "Utility",
		"Debug.Print ${1:\"message\"}",
		"Debug output")
	
	_add_builtin("Comment Block", "cmt", "Utility",
		"' ============================================================================\n' ${1:Description}\n' ============================================================================",
		"Section comment block")
	
	_add_builtin("TODO Comment", "todo", "Utility",
		"' TODO: ${1:description}",
		"TODO reminder comment")

static func _add_builtin(name: String, prefix: String, category: String, body: String, description: String) -> void:
	var s = Snippet.new()
	s.name = name
	s.prefix = prefix
	s.category = category
	s.body = body
	s.description = description
	s.is_builtin = true
	_builtin_snippets.append(s)

# =============================================================================
# PUBLIC API
# =============================================================================

## Get all snippets (builtin + user)
static func get_all_snippets() -> Array[Snippet]:
	_ensure_initialized()
	var all: Array[Snippet] = []
	all.append_array(_builtin_snippets)
	all.append_array(_user_snippets)
	return all

## Get snippets by category
static func get_snippets_by_category(category: String) -> Array[Snippet]:
	_ensure_initialized()
	var result: Array[Snippet] = []
	for s in _builtin_snippets + _user_snippets:
		if s.category == category:
			result.append(s)
	return result

## Get all categories
static func get_categories() -> Array[String]:
	_ensure_initialized()
	var cats: Dictionary = {}
	for s in _builtin_snippets + _user_snippets:
		cats[s.category] = true
	var result: Array[String] = []
	for c in cats:
		result.append(c)
	result.sort()
	return result

## Find snippet by prefix
static func find_by_prefix(prefix: String) -> Snippet:
	_ensure_initialized()
	for s in _user_snippets:  # User snippets take priority
		if s.prefix == prefix:
			return s
	for s in _builtin_snippets:
		if s.prefix == prefix:
			return s
	return null

## Find snippets matching partial prefix
static func find_matching(partial: String) -> Array[Snippet]:
	_ensure_initialized()
	var matches: Array[Snippet] = []
	var partial_lower = partial.to_lower()
	for s in _builtin_snippets + _user_snippets:
		if s.prefix.to_lower().begins_with(partial_lower) or \
		   s.name.to_lower().contains(partial_lower):
			matches.append(s)
	return matches

## Add a user snippet
static func add_user_snippet(name: String, prefix: String, category: String, body: String, description: String) -> Snippet:
	var s = Snippet.new()
	s.name = name
	s.prefix = prefix
	s.category = category
	s.body = body
	s.description = description
	s.is_builtin = false
	_user_snippets.append(s)
	return s

## Remove a user snippet
static func remove_user_snippet(prefix: String) -> bool:
	for i in range(_user_snippets.size() - 1, -1, -1):
		if _user_snippets[i].prefix == prefix:
			_user_snippets.remove_at(i)
			return true
	return false

## Expand a snippet body, processing placeholders
## Returns {text: String, first_placeholder_pos: int}
static func expand_snippet(snippet: Snippet, indent: String = "") -> Dictionary:
	var body = snippet.body
	
	# Replace tabs with proper indentation
	body = body.replace("\t", "\t" + indent)
	
	# First line shouldn't have extra indent
	if body.begins_with("\t" + indent):
		body = body.substr(("\t" + indent).length())
		body = "\t" + body
	
	# Process placeholders - find first one
	var regex = RegEx.new()
	regex.compile(PLACEHOLDER_REGEX)
	
	var first_match = regex.search(body)
	var first_pos = -1
	
	if first_match:
		first_pos = first_match.get_start()
	
	# Replace placeholders with their default values (for display)
	# In a real editor, these would become tab stops
	var final_text = body
	var placeholder_match = regex.search(final_text)
	while placeholder_match:
		var default_val = ""
		if placeholder_match.get_group_count() >= 2:
			var group2 = placeholder_match.get_string(2)
			if group2:
				default_val = group2
		# Replace this placeholder with its default value
		final_text = final_text.substr(0, placeholder_match.get_start()) + default_val + final_text.substr(placeholder_match.get_end())
		placeholder_match = regex.search(final_text)
	
	return {
		"text": final_text,
		"raw": body,
		"first_placeholder_pos": first_pos
	}

## Get placeholder positions from raw snippet body
static func get_placeholders(snippet_body: String) -> Array[Dictionary]:
	var placeholders: Array[Dictionary] = []
	var regex = RegEx.new()
	regex.compile(PLACEHOLDER_REGEX)
	
	var matches = regex.search_all(snippet_body)
	for m in matches:
		var index_str = m.get_string(1) if m.get_string(1) else m.get_string(3)
		var default_val = m.get_string(2) if m.get_group_count() >= 2 else ""
		
		placeholders.append({
			"index": int(index_str) if index_str else 0,
			"default": default_val,
			"start": m.get_start(),
			"end": m.get_end()
		})
	
	# Sort by index
	placeholders.sort_custom(func(a, b): return a["index"] < b["index"])
	
	return placeholders

# =============================================================================
# PERSISTENCE
# =============================================================================

const USER_SNIPPETS_PATH = "user://vg_snippets.cfg"

## Save user snippets to file
static func save_user_snippets() -> void:
	var config = ConfigFile.new()
	
	for i in range(_user_snippets.size()):
		var s = _user_snippets[i]
		var section = "snippet_%d" % i
		config.set_value(section, "name", s.name)
		config.set_value(section, "prefix", s.prefix)
		config.set_value(section, "category", s.category)
		config.set_value(section, "body", s.body)
		config.set_value(section, "description", s.description)
	
	config.save(USER_SNIPPETS_PATH)

## Load user snippets from file
static func load_user_snippets() -> void:
	_user_snippets.clear()
	
	var config = ConfigFile.new()
	if config.load(USER_SNIPPETS_PATH) != OK:
		return
	
	for section in config.get_sections():
		var s = Snippet.new()
		s.name = config.get_value(section, "name", "")
		s.prefix = config.get_value(section, "prefix", "")
		s.category = config.get_value(section, "category", "General")
		s.body = config.get_value(section, "body", "")
		s.description = config.get_value(section, "description", "")
		s.is_builtin = false
		
		if s.name and s.prefix and s.body:
			_user_snippets.append(s)
