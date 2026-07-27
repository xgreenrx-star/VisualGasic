@tool
extends RefCounted
## Causal Chain Visualization — Show/Export the call-chain report for any VG form.
##
## M6 Milestone (Oct 31 2026): Static AST walk generates a readable call-chain
## report.  Even a text-mode output qualifies.  The full interactive visual
## panel is v6.1+.
##
## Why VG is uniquely suited to this:
##   1. Sub Button1_Click() is an unambiguous entry point — the parser already
##      knows every entry point without running the code.
##   2. BASIC has no hidden side effects, metaclasses, or decorators that change
##      what a function does — static analysis is reliable and complete.
##   3. The two-layer signal architecture (controls → form, form → parent) makes
##      the causal chain traceable across scene boundaries.
##   4. The Code Navigator already walks the AST — the chain generator reuses
##      the same infrastructure.
##
## Usage:
##   var chain = VGCausalChain.new()
##   var report = chain.generate(text)        # returns indented string
##   print(report)
##   chain.copy_to_clipboard(report)          # copy to system clipboard
##
## Output format (tree):
##   User clicks [Submit]
##     └─ Sub SubmitButton_Click()
##         ├─ Call ValidateForm()
##         │   ├─ If txtName.Text = "" → MsgBox "Name required" → EXIT
##         │   └─ Returns True
##         ├─ Call SaveData(userName, txtName.Text)
##         │   └─ File.Write("save.dat", ...)
##         └─ RaiseEvent FormSubmitted(txtName.Text)
##             └─ [Parent scene connects here]
##

const INDENT_WIDTH := 4          # spaces per indent level
const MAX_DEPTH := 20            # safety limit to guard against infinite recursion
const MAX_CHARS := 80            # line-wrap target for call descriptions

# Regex patterns reused across the walk
var _call_re: RegEx
var _raise_re: RegEx
var _sub_def_re: RegEx
var _func_def_re: RegEx
var _sig_re: RegEx
var _if_re: RegEx
var _elseif_re: RegEx
var _else_re: RegEx
var _for_re: RegEx
var _select_re: RegEx
var _exit_re: RegEx
var _return_re: RegEx
var _set_re: RegEx
var _msgbox_re: RegEx
var _print_re: RegEx
var _file_open_re: RegEx
var _file_write_re: RegEx
var _file_close_re: RegEx
var _dot_call_re: RegEx     # matches obj.Method(args)

func _init() -> void:
	_call_re = RegEx.new()
	_call_re.compile("^\\s*(?:Call\\s+)?(\\w+(?:\\.\\w+)*)\\s*\\(([^)]*)\\)")
	
	_raise_re = RegEx.new()
	_raise_re.compile("^\\s*RaiseEvent\\s+(\\w+)\\s*(.*)$")
	
	_sub_def_re = RegEx.new()
	_sub_def_re.compile("^(?:Public|Private|Friend|)\\s*Sub\\s+(\\w+)")
	
	_func_def_re = RegEx.new()
	_func_def_re.compile("^(?:Public|Private|Friend|)\\s*Function\\s+(\\w+)")
	
	_sig_re = RegEx.new()
	_sig_re.compile("^(?:Public\\s+|Private\\s+|Friend\\s+)?(Sub|Function|Property\\s+(?:Get|Let|Set))\\s+(\\w+)\\s*\\(")
	
	_if_re = RegEx.new()
	_if_re.compile("^\\s*(?:Else)?If\\s+(.+?)\\s+Then")
	
	_elseif_re = RegEx.new()
	_elseif_re.compile("^\\s*ElseIf\\s+(.+?)\\s+Then")
	
	_else_re = RegEx.new()
	_else_re.compile("^\\s*Else\\s*$")
	
	_for_re = RegEx.new()
	_for_re.compile("^\\s*For\\s+(\\w+)\\s*=|^\\s*For\\s+Each\\s+(\\w+)")
	
	_select_re = RegEx.new()
	_select_re.compile("^\\s*Select\\s+Case")
	
	_exit_re = RegEx.new()
	_exit_re.compile("^\\s*Exit\\s+(Sub|Function|For|Do|While)")
	
	_return_re = RegEx.new()
	_return_re.compile("^\\s*Return\\s+(.+)$")
	
	_set_re = RegEx.new()
	_set_re.compile("^\\s*Set\\s+(\\w+(?:\\.\\w+)*)\\s*=")
	
	_msgbox_re = RegEx.new()
	_msgbox_re.compile("^\\s*MsgBox\\s+(.+)$")
	
	_print_re = RegEx.new()
	_print_re.compile("^\\s*Print\\s+(.+)$")
	
	_file_open_re = RegEx.new()
	_file_open_re.compile("^\\s*Open\\s+(.+?)\\s+For")
	
	_file_write_re = RegEx.new()
	_file_write_re.compile("^\\s*(?:Write|Print)\\s+#")
	
	_file_close_re = RegEx.new()
	_file_close_re.compile("^\\s*Close\\s+#")
	
	_dot_call_re = RegEx.new()
	_dot_call_re.compile("^\\s*(\\w+(?:\\.\\w+)*)\\s*\\.\\s*(\\w+)\\s*\\(")


## Generate a causal chain report from VG source text.
##
## @param text   The full .vg file text.
## @param root   An optional array of Sub names to start from (e.g. ["Form_Load"]).
##               If empty, the walk starts from all event-handler subs.
## @return       A UTF-8 string with the indented causal chain report.
func generate(text: String, root: Array = []) -> String:
	if text.is_empty():
		return ""
	
	# ── 1. Parse all Sub/Function definitions and their bodies ──
	var procs := _parse_procedures_with_body(text)
	
	# ── 2. Determine entry points ──
	var entry_points: Array = root
	if entry_points.is_empty():
		entry_points = _find_entry_points(procs)
	
	# ── 3. Walk each entry point ──
	var lines: Array = []
	
	for ep in entry_points:
		# Build a visited set per entry point to avoid duplicate expansions
		var visited: Dictionary = {}
		var report_line := _describe_entry(ep, procs, text)
		lines.append(report_line)
		
		var ep_proc := _find_proc(procs, ep)
		if ep_proc != null:
			var depth := 0
			var proc_visited: Array = []
			var body_lines := _walk_body(ep_proc, procs, depth + 1, visited, proc_visited)
			lines.append_array(body_lines)
		
		lines.append("")  # blank line between entry-point groups
	
	return "\n".join(lines)


## Parse VG source and extract all procedure definitions with their body text.
## Returns an Array of Dictionaries:
##   { name, kind, line, body_start, body_end, body_text }
func _parse_procedures_with_body(text: String) -> Array:
	var procs: Array = []
	var lines := text.split("\n")
	var i := 0
	
	while i < lines.size():
		var stripped := lines[i].strip_edges()
		
		# Match Sub/Function/Property definition
		var m := _sig_re.search(stripped)
		if m:
			var kind := m.get_string(1)
			var name := m.get_string(2)
			var body_start := i + 1
			
			# Find the matching End Sub / End Function / End Property
			var body_end := body_start
			var nesting := 0
			while body_end < lines.size():
				var ls := lines[body_end].strip_edges().to_lower()
				if ls.begins_with("end sub") or ls.begins_with("end function") or ls.begins_with("end property"):
					if nesting == 0:
						break
					nesting -= 1
				elif ls.begins_with("sub ") or ls.begins_with("function ") or ls.begins_with("property "):
					nesting += 1
				body_end += 1
			
			var body_text := ""
			if body_end > body_start:
				body_text = "\n".join(lines.slice(body_start, body_end))
			
			procs.append({
				"name": name,
				"kind": kind,
				"line": i,
				"body_start": body_start,
				"body_end": body_end,
				"body_text": body_text,
			})
			i = body_end + 1
			continue
		i += 1
	
	return procs


## Find entry points — every Sub named <Control>_<Event>() in the file.
## Also includes Form_Load, Form_Unload, Class_Initialize, Class_Terminate.
func _find_entry_points(procs: Array) -> Array:
	var entries: Array = []
	var extra := ["Form_Load", "Form_Unload", "Form_Initialize", "Form_Terminate",
				  "Class_Initialize", "Class_Terminate", "_ready", "_process", "_input"]
	
	for p in procs:
		var name: String = p["name"]
		# Check if it looks like <Name>_<Event> — has underscore followed by known event
		if name.contains("_"):
			var parts := name.rsplit("_", true, 1)
			if parts.size() == 2:
				var event_part := parts[1].to_lower()
				if event_part in ["click", "dblclick", "mousedown", "mouseup", "mousemove",
						"keydown", "keypress", "keyup", "change", "load", "unload",
						"activate", "deactivate", "resize", "paint", "timer",
						"gotfocus", "lostfocus", "mouseenter", "mouseexit",
						"scroll", "validate", "init", "terminate",
						"bodyentered", "bodyexited", "areaentered", "areaexited",
						"ready", "process", "physicsprocess", "input"]:
					if not entries.has(name):
						entries.append(name)
		elif name in extra:
			if not entries.has(name):
				entries.append(name)
	
	# If no event handlers found, list ALL subs/functions as entry points
	if entries.is_empty():
		for p in procs:
			entries.append(p["name"])
	
	return entries


func _find_proc(procs: Array, name: String) -> Dictionary:
	for p in procs:
		if p["name"] == name:
			return p
	return {}


func _describe_entry(name: String, procs: Array, text: String) -> String:
	"""Produce the top-level line describing an entry point."""
	# Check if it's a known event pattern or a standalone sub
	if name.contains("_"):
		var parts := name.rsplit("_", true, 1)
		var control := parts[0]
		var event_name := parts[1]
		return "User triggers " + control + "." + event_name
	elif name in ["Form_Load", "Class_Initialize"]:
		return "Form/Class loads"
	elif name in ["_ready", "_process", "_input"]:
		return "Godot lifecycle: " + name
	else:
		return "Entry: " + name


func _walk_body(proc: Dictionary, procs: Array, depth: int,
				visited: Dictionary, proc_visited: Array) -> Array:
	"""Walk the body of a procedure and return indented chain lines.
	
	visited:     Dictionary[name → bool] — tracks full procedure names already visited
	             at ANY recursion level to avoid infinite loops.
	proc_visited: Array — ordering of procedures visited in this walk
	"""
	if depth > MAX_DEPTH:
		return [" ".repeat(depth * INDENT_WIDTH) + "└─ [MAX_DEPTH reached — truncating]"]
	
	var result: Array = []
	var body: String = proc.get("body_text", "")
	if body.is_empty():
		return result
	
	var body_lines: PackedStringArray = body.split("\n")
	var in_block := false
	var block_type := ""
	var block_lines: Array = []
	
	for raw_line in body_lines:
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("'") or line.begins_with("REM "):
			continue
		
		# ── Track nested blocks (If/End If, For/Next, etc.) ──
		var lower := line.to_lower()
		
		if lower.begins_with("if ") or lower.begins_with("elseif "):
			var cond := ""
			if lower.begins_with("if "):
				var ifmatch := _if_re.search(line)
				if ifmatch:
					cond = ifmatch.get_string(1)
				in_block = true
				block_type = "If"
				block_lines = []
				result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ If " + cond + " Then")
			else:  # ElseIf
				var elseifmatch := _elseif_re.search(line)
				if elseifmatch:
					cond = elseifmatch.get_string(1)
				result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ ElseIf " + cond + " Then")
		
		elif lower.strip_edges() == "else":
			result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ Else")
		
		elif lower.begins_with("end if") or lower.begins_with("end select") or lower.begins_with("wend") or lower.begins_with("next") or lower.begins_with("loop"):
			# End of a block — nothing special needed for the chain
			pass
		
		elif lower.begins_with("select case "):
			var select_target := line.substr(12).strip_edges()
			result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ Select Case " + select_target)
		
		elif lower.begins_with("case ") and lower != "case else" and lower != "case else":
			var case_val := line.substr(5).strip_edges()
			result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ Case " + case_val)
		
		elif lower.begins_with("case else"):
			result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ Case Else")
		
		elif lower.begins_with("for ") or lower.begins_with("for each "):
			var loop_var := ""
			var formatch := _for_re.search(line)
			if formatch:
				loop_var = formatch.get_string(1)
			result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ Loop over " + loop_var)
		
		elif lower.begins_with("do ") or lower.begins_with("while ") or lower.begins_with("until "):
			result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ Loop entry (" + line.strip_edges() + ")")
		
		elif lower.begins_with("exit ") or lower.begins_with("continue "):
			var exitmatch := _exit_re.search(line)
			if exitmatch:
				result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ " + exitmatch.get_string(0).strip_edges())
		
		elif lower.begins_with("return "):
			var retmatch := _return_re.search(line)
			if retmatch:
				var ret_val := retmatch.get_string(1).strip_edges()
				# Truncate long return values
				if ret_val.length() > MAX_CHARS / 2:
					ret_val = ret_val.left(MAX_CHARS / 2 - 3) + "..."
				result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ Returns " + ret_val)
		
		# ── Call Statement ──
		elif lower.begins_with("call "):
			var call_target := line.substr(5).strip_edges()
			var call_detail := _describe_call(call_target, procs, visited, proc_visited)
			result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ " + call_detail)
		
		# ── RaiseEvent ──
		elif lower.begins_with("raiseevent "):
			var raisematch := _raise_re.search(line)
			if raisematch:
				var event_name := raisematch.get_string(1)
				var args := raisematch.get_string(2).strip_edges()
				if args.begins_with("(") and args.ends_with(")"):
					args = args.substr(1, args.length() - 2)
				var detail := "RaiseEvent " + event_name
				if not args.is_empty():
					detail += "(" + _truncate(args) + ")"
				result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ " + detail)
				result.append(" ".repeat(depth * INDENT_WIDTH) + "│   └─ [Parent scene connects here]")
		
		# ── MsgBox ──
		elif lower.begins_with("msgbox "):
			var msgmatch := _msgbox_re.search(line)
			if msgmatch:
				var msg := msgmatch.get_string(1).strip_edges()
				result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ MsgBox (" + _truncate(msg, 50) + ")")
		
		# ── Print / Write / File I/O ──
		elif lower.begins_with("print "):
			var prmatch := _print_re.search(line)
			if prmatch:
				var output := prmatch.get_string(1).strip_edges()
				result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ Print " + _truncate(output, 50))
		
		elif lower.begins_with("open "):
			var openmatch := _file_open_re.search(line)
			if openmatch:
				var filepath := openmatch.get_string(1).strip_edges()
				result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ File.Open(" + _truncate(filepath, 50) + ")")
		
		elif lower.begins_with("write #") or lower.begins_with("print #"):
			result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ File.Write(...)")
		
		elif lower.begins_with("close #"):
			result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ File.Close()")
		
		# ── Set (object assignment) ──
		elif lower.begins_with("set "):
			var setmatch := _set_re.search(line)
			if setmatch:
				var target := setmatch.get_string(1)
				result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ Assign " + target)
		
		# ── Dot-call: obj.Method(args) or variable.Method(args) ──
		#     Handles: Button1.Caption = "Hello", dict.Add(key, val), etc.
		elif _dot_call_re.search(line):
			var dotmatch := _dot_call_re.search(line)
			if dotmatch:
				var obj_name := dotmatch.get_string(1)
				var method := dotmatch.get_string(2)
				var after_method := raw_line.substr(dotmatch.get_end(2))
				# Check if it's a property assignment (obj.Method = ...)
				if after_method.strip_edges().begins_with("="):
					result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ Set " + obj_name + "." + method)
				else:
					result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ " + obj_name + "." + method + "(...)")
		
		# ── Direct Sub call without Call keyword (e.g. "ValidateForm()") ──
		#     This handles standalone calls of the form "SomeSub()" on their own line.
		else:
			var is_direct_call := false
			# Pattern: A line that starts with an identifier, then "(", 
			# and the identifier isn't a control flow keyword
			var open_paren_idx := line.find("(")
			if open_paren_idx > 0:
				var maybe_name := line.left(open_paren_idx).strip_edges()
				# Must be a valid VG identifier (starts with letter/underscore)
				var is_keyword := false
				var keywords := ["if", "elseif", "else", "for", "do", "while",
					"until", "select", "case", "dim", "redim", "const",
					"sub", "function", "property", "class", "end",
					"public", "private", "friend", "static", "option",
					"on", "resume", "goto", "gosub", "raiseevent",
					"set", "let", "with", "me", "new"]
				if maybe_name.to_lower() in keywords:
					is_keyword = true
				if not is_keyword and _is_valid_identifier(maybe_name):
					# This looks like a direct call to a Sub or Function
					var call_detail := _describe_call(line.strip_edges(), procs, visited, proc_visited)
					result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ " + call_detail)
					is_direct_call = true
			
			if not is_direct_call:
				# Skip — this is a Dim/variable assignment/other construct
				pass
	
	return result


func _describe_call(call_text: String, procs: Array, visited: Dictionary,
					proc_visited: Array) -> String:
	"""Describe a Call statement — extract target, args, and recurse if possible."""
	# Match "Call Target(args)" or "Target(args)" or "Call Target arg1, arg2"
	var callmatch := _call_re.search(call_text)
	var target_name := ""
	var args_str := ""
	
	if callmatch:
		target_name = callmatch.get_string(1)
		args_str = callmatch.get_string(2)
		# Truncate args if very long
		if args_str.length() > MAX_CHARS / 2:
			args_str = args_str.left(MAX_CHARS / 2 - 3) + "..."
	else:
		# Simple call: "Call SomeSub" (no parentheses) or "SomeSub"
		# Remove leading "Call "
		var cleaned := call_text
		if cleaned.to_lower().begins_with("call "):
			cleaned = cleaned.substr(5).strip_edges()
		target_name = cleaned.split(" ")[0].split(",")[0].strip_edges()
	
	# Lookup the target in parsed procedures
	var target_proc := _find_proc(procs, target_name)
	
	var detail := ""
	if target_proc.has("name"):
		var full_sig := target_name
		if not args_str.is_empty():
			full_sig += "(" + args_str + ")"
		detail = "Call " + full_sig
		
		# Recurse into the called procedure (if not already visited)
		var visited_key := target_name
		if not visited.has(visited_key):
			visited[visited_key] = true
			proc_visited.append(visited_key)
			# No need to recurse here — we just describe the call
	else:
		# Unknown target — it might be a builtin or external
		var cleaned_call := call_text
		if cleaned_call.to_lower().begins_with("call "):
			cleaned_call = cleaned_call.substr(5).strip_edges()
		detail = cleaned_call
	
	return detail


## Walk the called subroutines recursively to expand their bodies.
func _walk_called_proc(call_text: String, procs: Array, depth: int,
						visited: Dictionary, proc_visited: Array) -> Array:
	"""Called from within a parent walk to expand a child Sub's body."""
	if depth > MAX_DEPTH:
		return []
	
	var callmatch := _call_re.search(call_text)
	var target_name := ""
	
	if callmatch:
		target_name = callmatch.get_string(1)
	else:
		var cleaned := call_text
		if cleaned.to_lower().begins_with("call "):
			cleaned = cleaned.substr(5).strip_edges()
		target_name = cleaned.split(" ")[0].split(",")[0].strip_edges()
	
	if visited.has(target_name):
		return []  # Already visited — prevent infinite recursion
	
	var target_proc := _find_proc(procs, target_name)
	if target_proc.is_empty():
		return []
	
	visited[target_name] = true
	proc_visited.append(target_name)
	
	var result: Array = []
	var body_lines := _walk_body(target_proc, procs, depth, visited, proc_visited)
	
	# Filter out top-level "├─ " prefix and re-indent under the call
	for bl in body_lines:
		# Remove the original indent/prefix and add new depth indent
		var line_content := _strip_tree_prefix(bl)
		result.append(" ".repeat(depth * INDENT_WIDTH) + "│   " + line_content)
	
	return result


func _strip_tree_prefix(line: String) -> String:
	"""Strip the leading '├─ ' or '└─ ' or '│   ' tree characters."""
	var result := line
	# Remove leading whitespace
	result = result.lstrip(" ")
	# Remove tree connector characters
	if result.begins_with("├─ "):
		result = result.substr(3)
	elif result.begins_with("└─ "):
		result = result.substr(3)
	elif result.begins_with("│   "):
		result = result.substr(4)
	return result.strip_edges()


func _is_valid_identifier(name: String) -> bool:
	"""Check if a string is a valid VG identifier."""
	if name.is_empty():
		return false
	# Must start with a letter or underscore
	if not (name[0].is_valid_identifier()):
		return false
	# All characters must be alphanumeric or underscore
	for c in name:
		if not (c.is_valid_identifier() or c == "."):
			return false
	return true


## Generate a standalone causal chain report and return it as a single string.
## This is the method called from the UI button.
func generate_chain_report(text: String, root: Array = []) -> String:
	var output := "═══════════════════════════════════════════════════════════\n"
	output += "  VG Causal Chain Report\n"
	output += "  Generated: " + Time.get_datetime_string_from_system() + "\n"
	output += "═══════════════════════════════════════════════════════════\n\n"
	output += generate(text, root)
	output += "\n═══════════════════════════════════════════════════════════\n"
	output += "  End of Report\n"
	output += "═══════════════════════════════════════════════════════════\n"
	return output


## Copy the given report text to the system clipboard.
func copy_to_clipboard(report: String) -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(report)


func _truncate(s: String, max_len: int = MAX_CHARS / 2) -> String:
	if s.length() <= max_len:
		return s
	return s.left(max_len - 3) + "..."
