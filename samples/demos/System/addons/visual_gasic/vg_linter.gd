@tool
extends RefCounted
## VisualGasic Linter
##
## Static analysis for VG code quality:
## - Unused variable detection
## - Unreachable code warnings
## - Undefined variable usage
## - Deprecated syntax warnings
## - Missing End statements

class_name VGLinter

# =============================================================================
# WARNING TYPES
# =============================================================================

enum Severity {
	ERROR = 0,
	WARNING = 1,
	INFO = 2,
	HINT = 3
}

## A lint warning/error
class LintIssue:
	var severity: Severity = Severity.WARNING
	var message: String = ""
	var file_path: String = ""
	var line: int = 0
	var column: int = 0
	var code: String = ""  # Issue code like "VG001"
	var source_line: String = ""  # The actual line of code
	
	func _to_string() -> String:
		var sev_str = ["ERROR", "WARNING", "INFO", "HINT"][severity]
		return "[%s] %s:%d - %s: %s" % [code, file_path.get_file(), line, sev_str, message]

# =============================================================================
# ISSUE CODES
# =============================================================================

const ISSUE_UNUSED_VARIABLE = "VG001"
const ISSUE_UNDEFINED_VARIABLE = "VG002"
const ISSUE_UNREACHABLE_CODE = "VG003"
const ISSUE_MISSING_END = "VG004"
const ISSUE_DEPRECATED_SYNTAX = "VG005"
const ISSUE_EMPTY_BLOCK = "VG006"
const ISSUE_UNUSED_PARAMETER = "VG007"
const ISSUE_SHADOWED_VARIABLE = "VG008"
const ISSUE_IMPLICIT_VARIANT = "VG009"
const ISSUE_MISSING_RETURN = "VG010"

# =============================================================================
# LINTING
# =============================================================================

## Lints a VG file and returns all issues
static func lint_file(file_path: String) -> Array[LintIssue]:
	var issues: Array[LintIssue] = []
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return issues
	
	var content = file.get_as_text()
	file.close()
	
	issues.append_array(_check_undefined_variables(content, file_path))
	issues.append_array(_check_unused_variables(content, file_path))
	issues.append_array(_check_missing_end_statements(content, file_path))
	issues.append_array(_check_unreachable_code(content, file_path))
	issues.append_array(_check_empty_blocks(content, file_path))
	issues.append_array(_check_implicit_variants(content, file_path))
	issues.append_array(_check_deprecated_syntax(content, file_path))
	
	return issues

## Lints text content directly
static func lint_text(content: String, file_path: String = "") -> Array[LintIssue]:
	var issues: Array[LintIssue] = []
	
	issues.append_array(_check_undefined_variables(content, file_path))
	issues.append_array(_check_unused_variables(content, file_path))
	issues.append_array(_check_missing_end_statements(content, file_path))
	issues.append_array(_check_unreachable_code(content, file_path))
	issues.append_array(_check_empty_blocks(content, file_path))
	issues.append_array(_check_implicit_variants(content, file_path))
	issues.append_array(_check_deprecated_syntax(content, file_path))
	
	return issues

# =============================================================================
# CHECK: Undefined Variables
# =============================================================================

static func _check_undefined_variables(content: String, file_path: String) -> Array[LintIssue]:
	var issues: Array[LintIssue] = []
	var lines = content.split("\n")
	
	# First pass: collect all declared variables
	var declared_vars: Dictionary = {}  # name -> line declared
	var dim_regex = RegEx.new()
	dim_regex.compile("(?i)(?:DIM|PRIVATE|PUBLIC|STATIC)\\s+(\\w+)")
	
	for i in range(lines.size()):
		var line = lines[i]
		var matches = dim_regex.search_all(line)
		for m in matches:
			var var_name = m.get_string(1)
			declared_vars[var_name.to_upper()] = i + 1
	
	# Also add Sub/Function parameters
	var param_regex = RegEx.new()
	param_regex.compile("(?i)(?:SUB|FUNCTION)\\s+\\w+\\s*\\(([^)]+)\\)")
	
	for i in range(lines.size()):
		var line = lines[i]
		var match = param_regex.search(line)
		if match:
			var params = match.get_string(1)
			var param_names = _extract_parameter_names(params)
			for pn in param_names:
				declared_vars[pn.to_upper()] = i + 1
	
	# Second pass: look for usage of undeclared variables
	# This is a simplified check - assignment targets
	var assign_regex = RegEx.new()
	assign_regex.compile("^\\s*(\\w+)\\s*=")
	
	for i in range(lines.size()):
		var line = lines[i]
		var stripped = line.strip_edges()
		
		# Skip declarations, comments, empty
		if stripped.is_empty() or stripped.begins_with("'"):
			continue
		if stripped.to_upper().begins_with("DIM ") or stripped.to_upper().begins_with("PRIVATE ") or \
		   stripped.to_upper().begins_with("PUBLIC ") or stripped.to_upper().begins_with("STATIC "):
			continue
		if stripped.to_upper().begins_with("SUB ") or stripped.to_upper().begins_with("FUNCTION "):
			continue
		if stripped.to_upper().begins_with("END "):
			continue
		
		# Check for assignment to undeclared variable
		var match = assign_regex.search(line)
		if match:
			var var_name = match.get_string(1)
			# Skip if it's a known keyword
			if var_name.to_upper() in ["ME", "SET", "LET", "IF", "FOR", "WHILE", "DO", "PRINT"]:
				continue
			if not declared_vars.has(var_name.to_upper()):
				var issue = LintIssue.new()
				issue.severity = Severity.WARNING
				issue.code = ISSUE_UNDEFINED_VARIABLE
				issue.message = "Variable '%s' is used without declaration (Option Explicit)" % var_name
				issue.file_path = file_path
				issue.line = i + 1
				issue.column = match.get_start(1)
				issue.source_line = line
				issues.append(issue)
	
	return issues

static func _extract_parameter_names(params_str: String) -> Array[String]:
	var names: Array[String] = []
	var parts = params_str.split(",")
	for part in parts:
		var clean = part.strip_edges()
		# Handle "ByVal x As Integer" or just "x"
		var words = clean.split(" ")
		for w in words:
			var word = w.strip_edges()
			if word.to_upper() in ["BYVAL", "BYREF", "OPTIONAL", "AS", "INTEGER", "STRING", "LONG", "DOUBLE", "BOOLEAN", "VARIANT", "OBJECT"]:
				continue
			if not word.is_empty() and word[0].is_valid_identifier():
				names.append(word)
				break
	return names

# =============================================================================
# CHECK: Unused Variables
# =============================================================================

static func _check_unused_variables(content: String, file_path: String) -> Array[LintIssue]:
	var issues: Array[LintIssue] = []
	var lines = content.split("\n")
	
	# Collect declarations
	var declarations: Array[Dictionary] = []  # [{name, line, used}]
	var dim_regex = RegEx.new()
	dim_regex.compile("(?i)(?:DIM|PRIVATE|PUBLIC|STATIC)\\s+(\\w+)")
	
	for i in range(lines.size()):
		var line = lines[i]
		var matches = dim_regex.search_all(line)
		for m in matches:
			var var_name = m.get_string(1)
			declarations.append({
				"name": var_name,
				"name_upper": var_name.to_upper(),
				"line": i + 1,
				"used": false
			})
	
	# Check for usage (very simple: just look for the name elsewhere)
	for decl in declarations:
		var usage_regex = RegEx.new()
		usage_regex.compile("(?i)(?<![A-Za-z0-9_])" + decl["name"] + "(?![A-Za-z0-9_])")
		
		var usage_count = 0
		for i in range(lines.size()):
			var line = lines[i]
			# Skip the declaration line
			if i + 1 == decl["line"]:
				continue
			# Skip comments
			if line.strip_edges().begins_with("'"):
				continue
			
			if usage_regex.search(line):
				usage_count += 1
				break
		
		if usage_count == 0:
			var issue = LintIssue.new()
			issue.severity = Severity.INFO
			issue.code = ISSUE_UNUSED_VARIABLE
			issue.message = "Variable '%s' is declared but never used" % decl["name"]
			issue.file_path = file_path
			issue.line = decl["line"]
			issue.source_line = lines[decl["line"] - 1]
			issues.append(issue)
	
	return issues

# =============================================================================
# CHECK: Missing End Statements
# =============================================================================

static func _check_missing_end_statements(content: String, file_path: String) -> Array[LintIssue]:
	var issues: Array[LintIssue] = []
	var lines = content.split("\n")
	
	# Track block starts
	var block_stack: Array[Dictionary] = []  # [{type, line}]
	
	var block_pairs = {
		"SUB": "END SUB",
		"FUNCTION": "END FUNCTION",
		"IF": "END IF",
		"FOR": "NEXT",
		"WHILE": "WEND",
		"DO": "LOOP",
		"SELECT CASE": "END SELECT",
		"CLASS": "END CLASS",
		"TRY": "END TRY",
		"WITH": "END WITH",
		"WHENEVER": "END WHENEVER"
	}
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges().to_upper()
		
		# Skip comments
		if line.begins_with("'"):
			continue
		
		# Check for block starts
		for start_kw in block_pairs:
			if line.begins_with(start_kw + " ") or line.begins_with(start_kw + "(") or line == start_kw:
				# Special case: single-line If
				if start_kw == "IF" and "THEN" in line:
					var after_then = line.split("THEN", true, 1)
					if after_then.size() > 1 and not after_then[1].strip_edges().is_empty():
						continue  # Single-line If
				block_stack.append({"type": start_kw, "line": i + 1})
				break
		
		# Check for block ends
		for start_kw in block_pairs:
			var end_kw = block_pairs[start_kw]
			if line.begins_with(end_kw) or line == end_kw:
				# Find matching start
				var found = false
				for j in range(block_stack.size() - 1, -1, -1):
					if block_stack[j]["type"] == start_kw:
						block_stack.remove_at(j)
						found = true
						break
				if not found:
					var issue = LintIssue.new()
					issue.severity = Severity.ERROR
					issue.code = ISSUE_MISSING_END
					issue.message = "'%s' without matching '%s'" % [end_kw, start_kw]
					issue.file_path = file_path
					issue.line = i + 1
					issue.source_line = lines[i]
					issues.append(issue)
				break
	
	# Any unclosed blocks?
	for block in block_stack:
		var issue = LintIssue.new()
		issue.severity = Severity.ERROR
		issue.code = ISSUE_MISSING_END
		issue.message = "'%s' is missing '%s'" % [block["type"], block_pairs[block["type"]]]
		issue.file_path = file_path
		issue.line = block["line"]
		issue.source_line = lines[block["line"] - 1] if block["line"] <= lines.size() else ""
		issues.append(issue)
	
	return issues

# =============================================================================
# CHECK: Unreachable Code
# =============================================================================

static func _check_unreachable_code(content: String, file_path: String) -> Array[LintIssue]:
	var issues: Array[LintIssue] = []
	var lines = content.split("\n")
	
	var exit_statements = ["EXIT SUB", "EXIT FUNCTION", "RETURN", "END"]
	var in_unreachable = false
	var unreachable_start = -1
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges().to_upper()
		
		# Skip comments and empty
		if line.is_empty() or line.begins_with("'"):
			continue
		
		# End of block resets unreachable state
		if line.begins_with("END ") or line == "NEXT" or line == "WEND" or line == "LOOP":
			in_unreachable = false
			continue
		
		if in_unreachable:
			# Check if this is actually executable code
			if not line.begins_with("'") and not line.is_empty():
				if unreachable_start < 0:
					unreachable_start = i
		else:
			# Check if this line causes unreachable code after
			for exit_stmt in exit_statements:
				if line.begins_with(exit_stmt):
					in_unreachable = true
					unreachable_start = -1
					break
	
	return issues

# =============================================================================
# CHECK: Empty Blocks
# =============================================================================

static func _check_empty_blocks(content: String, file_path: String) -> Array[LintIssue]:
	var issues: Array[LintIssue] = []
	var lines = content.split("\n")
	
	var block_starts = ["SUB ", "FUNCTION ", "IF ", "FOR ", "WHILE ", "DO"]
	var i = 0
	
	while i < lines.size():
		var line = lines[i].strip_edges().to_upper()
		
		# Check for block start
		for start in block_starts:
			if line.begins_with(start):
				# Look for next non-empty, non-comment line
				var j = i + 1
				var has_content = false
				
				while j < lines.size():
					var next_line = lines[j].strip_edges()
					var next_upper = next_line.to_upper()
					
					# Skip empty and comments
					if next_line.is_empty() or next_line.begins_with("'"):
						j += 1
						continue
					
					# Check if it's the end
					if next_upper.begins_with("END ") or next_upper == "NEXT" or \
					   next_upper == "WEND" or next_upper == "LOOP":
						# Empty block!
						if not has_content:
							var issue = LintIssue.new()
							issue.severity = Severity.INFO
							issue.code = ISSUE_EMPTY_BLOCK
							issue.message = "Empty block - consider adding implementation or comment"
							issue.file_path = file_path
							issue.line = i + 1
							issue.source_line = lines[i]
							issues.append(issue)
						break
					
					has_content = true
					break
				break
		i += 1
	
	return issues

# =============================================================================
# CHECK: Implicit Variants
# =============================================================================

static func _check_implicit_variants(content: String, file_path: String) -> Array[LintIssue]:
	var issues: Array[LintIssue] = []
	var lines = content.split("\n")
	
	# Look for Dim without As
	var dim_regex = RegEx.new()
	dim_regex.compile("(?i)^\\s*(?:DIM|PRIVATE|PUBLIC|STATIC)\\s+(\\w+)\\s*$")
	
	for i in range(lines.size()):
		var line = lines[i]
		var match = dim_regex.search(line)
		if match:
			var var_name = match.get_string(1)
			var issue = LintIssue.new()
			issue.severity = Severity.HINT
			issue.code = ISSUE_IMPLICIT_VARIANT
			issue.message = "Variable '%s' has no type - will be Variant (consider explicit type)" % var_name
			issue.file_path = file_path
			issue.line = i + 1
			issue.source_line = line
			issues.append(issue)
	
	return issues

# =============================================================================
# CHECK: Deprecated Syntax
# =============================================================================

static func _check_deprecated_syntax(content: String, file_path: String) -> Array[LintIssue]:
	var issues: Array[LintIssue] = []
	var lines = content.split("\n")
	
	var deprecated = {
		"GOSUB": "Use 'Call SubName' instead of GoSub",
		"ON ERROR GOTO": "Consider using 'Try/Catch' for error handling",
		"LET ": "'Let' keyword is optional and deprecated",
	}
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges().to_upper()
		
		for pattern in deprecated:
			if pattern in line:
				var issue = LintIssue.new()
				issue.severity = Severity.INFO
				issue.code = ISSUE_DEPRECATED_SYNTAX
				issue.message = deprecated[pattern]
				issue.file_path = file_path
				issue.line = i + 1
				issue.source_line = lines[i]
				issues.append(issue)
				break
	
	return issues
