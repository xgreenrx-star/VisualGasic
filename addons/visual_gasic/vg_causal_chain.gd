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
	_sig_re.compile("(?i)^(?:Public\\s+|Private\\s+|Friend\\s+)?(Sub|Function|Property\\s+(?:Get|Let|Set))\\s+(\\w+)\\s*\\(")
	
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


func _ast_report_usable(report: String) -> bool:
	# Known AST gaps (e.g. `If Call Func() Then`, `End If` mis-parse) — use regex fallback.
	if report.contains("End(If)") or report.contains("If Call Then"):
		return false
	return not report.is_empty()


## Generate a causal chain report from VG source text.
##
## @param text   The full .vg file text.
## @param root   An optional array of Sub names to start from (e.g. ["Form_Load"]).
##               If empty, the walk starts from all event-handler subs.
## @return       A UTF-8 string with the indented causal chain report.
func generate(text: String, root: Array = []) -> String:
	if text.is_empty():
		return ""
	return str(analyze(text, root).get("report", ""))


## Structured possible-behavior evidence.
##
## schema_version 1. line_base 1 matches the VG tokenizer (the first line is line 1).
## source.content_hash is SHA-256 of the exact analyzed text encoded as UTF-8.
## source.kind is "memory" when source_path is empty; an in-memory snippet never
## receives a disk path. engine "ast" is the C++ walker. engine "fallback" is a
## line scan and is not equivalent in completeness to the AST.
## Step line 0 with location_known false is a synthetic limit, not a location.
## Risks (state write, early-return guard, external effect, unresolved target)
## are reasons to inspect. An unmarked line is not certified safe.
## force_engine: "" (AST when usable, else fallback), "ast", or "fallback".
func analyze(text: String, roots: Array = [], source_path: String = "", force_engine: String = "") -> Dictionary:
	if force_engine == "fallback":
		return _stamp_source(_fallback_evidence(text, roots), text, source_path)
	if force_engine == "ast":
		return _stamp_source(_ast_evidence(text, roots, true), text, source_path)
	if ClassDB.class_exists(&"VisualGasicLanguage"):
		var ast := _ast_evidence(text, roots, false)
		if bool(ast.get("ok", false)) and str(ast.get("engine", "")) == "ast":
			var report := str(ast.get("report", ""))
			if _ast_report_usable(report) or report.is_empty():
				return _stamp_source(ast, text, source_path)
	return _stamp_source(_fallback_evidence(text, roots), text, source_path)


func _regex_report(text: String, root: Array = []) -> String:
	if text.is_empty():
		return ""

	# Regex fallback (legacy path when extension unavailable or AST gaps).
	var procs := _parse_procedures_with_body(text)
	var entry_points: Array = []
	if root.is_empty():
		entry_points = _find_entry_points(procs)
	else:
		for ep in root:
			var found := _find_proc(procs, str(ep))
			entry_points.append(str(found["name"]) if not found.is_empty() else str(ep))
	
	var lines: Array = []
	for ep in entry_points:
		var visited: Dictionary = {}
		var report_line := _describe_entry(ep, procs, text)
		lines.append(report_line)
		var ep_proc := _find_proc(procs, ep)
		if not ep_proc.is_empty():
			var proc_visited: Array = []
			var body_lines := _walk_body(ep_proc, procs, 1, visited, proc_visited)
			for line in body_lines:
				lines.append(line)
		lines.append("")
	
	if lines.size() > 0 and lines[-1] == "":
		lines.remove_at(lines.size() - 1)
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
func _is_event_entry_name(name: String) -> bool:
	var extra := ["Form_Load", "Form_Unload", "Form_Initialize", "Form_Terminate",
			"Class_Initialize", "Class_Terminate", "_ready", "_process", "_input"]
	if name in extra:
		return true
	if not name.contains("_"):
		return false
	var event_part := name.rsplit("_", true, 1)[1].to_lower()
	return event_part in ["click", "dblclick", "mousedown", "mouseup", "mousemove",
			"keydown", "keypress", "keyup", "change", "load", "unload",
			"activate", "deactivate", "resize", "paint", "timer",
			"gotfocus", "lostfocus", "mouseenter", "mouseexit",
			"scroll", "validate", "init", "terminate",
			"bodyentered", "bodyexited", "areaentered", "areaexited",
			"ready", "process", "physicsprocess", "input"]


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
	var want := name.to_lower()
	for p in procs:
		if str(p["name"]).to_lower() == want:
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
		elif not proc.get("kind", "").to_lower().contains("sub"):
			var current_name := str(proc.get("name", "")).strip_edges()
			if not current_name.is_empty():
				var lower_name := current_name.to_lower()
				if lower.begins_with(lower_name + " ="):
					var expr := line.substr(current_name.length() + 1).strip_edges()
					expr = expr.lstrip("=").strip_edges()
					if expr.length() > MAX_CHARS / 2:
						expr = expr.left(MAX_CHARS / 2 - 3) + "..."
					result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ Returns " + expr)
		
		# ── Call Statement ──
		elif lower.begins_with("call "):
			var call_target := line.substr(5).strip_edges()
			var call_detail := _describe_call(call_target, procs, visited, proc_visited)
			result.append(" ".repeat(depth * INDENT_WIDTH) + "├─ " + call_detail)
			var target_name := call_target
			var callmatch := _call_re.search(call_target)
			if callmatch:
				target_name = callmatch.get_string(1)
			var target_proc := _find_proc(procs, target_name)
			if not target_proc.is_empty() and not visited.has(target_name):
				visited[target_name] = true
				proc_visited.append(target_name)
				var child_lines := _walk_body(target_proc, procs, depth + 1, visited, proc_visited)
				for child_line in child_lines:
					result.append(child_line)
		
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
		if args_str.is_empty():
			full_sig += "()"
		else:
			full_sig += "(" + args_str + ")"
		detail = "Call " + full_sig
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


func _content_hash(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()


func _stamp_source(evidence: Dictionary, text: String, source_path: String) -> Dictionary:
	var identity := source_path.strip_edges()
	evidence["schema_version"] = 1
	evidence["line_base"] = 1
	evidence["source"] = {
		"identity": identity,
		"kind": "path" if not identity.is_empty() else "memory",
		"content_hash": _content_hash(text),
		"hash_covers": "exact analyzed source text encoded as UTF-8",
	}
	return evidence


func _ast_evidence(text: String, roots: Array, require_evidence: bool) -> Dictionary:
	if not ClassDB.class_exists(&"VisualGasicLanguage"):
		return {
			"ok": false,
			"engine": "unavailable",
			"completeness": "unavailable",
			"report": "",
			"truncated": false,
			"roots": [],
			"steps": [],
			"limitations": ["AST path unavailable: VisualGasicLanguage is not loaded."],
			"errors": [],
		}
	var ast_result: Dictionary = ClassDB.class_call_static(
		&"VisualGasicLanguage", &"vg_analyze_causal_graph", text, roots)
	if not bool(ast_result.get("ok", false)):
		return {
			"ok": false,
			"engine": "ast",
			"completeness": "ast",
			"report": "",
			"truncated": false,
			"roots": [],
			"steps": [],
			"limitations": ["AST parse failed. This is not a fallback result."],
			"errors": ast_result.get("errors", []),
		}
	var evidence: Dictionary = ast_result.get("evidence", {})
	if evidence.is_empty():
		if require_evidence:
			return {
				"ok": false,
				"engine": "ast",
				"completeness": "ast",
				"report": str(ast_result.get("report", "")),
				"truncated": false,
				"roots": [],
				"steps": [],
				"limitations": ["AST path returned no evidence dictionary."],
				"errors": [],
			}
		return {"ok": false, "engine": "ast", "report": str(ast_result.get("report", ""))}
	evidence["ok"] = true
	evidence["engine"] = "ast"
	evidence["completeness"] = "ast"
	var event_report := str(ast_result.get("report", ""))
	var rendered := _render_whenever_text(evidence.get("roots", []), evidence.get("steps", []), evidence.get("limitations", []))
	evidence["whenever_text"] = rendered
	evidence["report"] = _join_reports(event_report, rendered)
	return evidence


func _join_reports(event_report: String, whenever_text: String) -> String:
	if whenever_text.is_empty():
		return event_report
	if event_report.is_empty():
		return whenever_text
	return event_report + "\n" + whenever_text


func _render_whenever_text(roots: Array, steps: Array, limitations: Array) -> String:
	var lines := PackedStringArray()
	var saw := false
	for i in roots.size():
		var root: Dictionary = roots[i]
		if str(root.get("kind", "")) != "whenever":
			continue
		saw = true
		var labels: Array = []
		for handler in root.get("handlers", []):
			labels.append(_handler_label(handler))
		if labels.is_empty() and not str(root.get("handler", "")).is_empty():
			labels.append(str(root.get("handler", "")))
		lines.append("Whenever %s line %d: %s -> %s" % [
			str(root.get("section", "")),
			int(root.get("line", 0)),
			str(root.get("declaration", "")),
			", ".join(labels),
		])
		for step in steps:
			if int(step.get("root_index", -1)) != i:
				continue
			lines.append(_step_label(step))
	if not saw:
		return ""
	lines.append("Limits:")
	for note in limitations:
		lines.append("  " + str(note))
	return "\n".join(lines)


func _handler_label(handler: Dictionary) -> String:
	var written := str(handler.get("name", ""))
	if str(handler.get("resolution", "")) == "resolved":
		return "%s [resolved %s line %d]" % [written, str(handler.get("target_name", "")), int(handler.get("line", 0))]
	return "%s [unresolved]" % written


func _step_label(step: Dictionary) -> String:
	var loc := "limit" if not bool(step.get("location_known", false)) else "L%d" % int(step.get("line", 0))
	var branch := str(step.get("branch", ""))
	var branch_bit := (branch + " ") if not branch.is_empty() else ""
	var extra := ""
	if str(step.get("kind", "")) == "call":
		if bool(step.get("target_known", false)):
			extra = " [resolved %s line %d]" % [str(step.get("target_name", "")), int(step.get("target_line", 0))]
		else:
			extra = " [unresolved]"
	return "  %s %s%s %s%s" % [loc, branch_bit, str(step.get("kind", "")), str(step.get("text", "")), extra]


func _procedure_key(procedures: Dictionary, name: String) -> String:
	if procedures.has(name):
		return name
	var want := name.to_lower()
	for key in procedures.keys():
		if str(key).to_lower() == want:
			return str(key)
	return ""


func _handler_records(procedures: Dictionary, names: Array) -> Array:
	var rows: Array = []
	for callback_name in names:
		var written := str(callback_name)
		var proc_key := _procedure_key(procedures, written)
		rows.append({
			"name": written,
			"resolution": "resolved" if not proc_key.is_empty() else "unresolved",
			"target_name": proc_key,
			"line": int(procedures[proc_key]["line"]) if not proc_key.is_empty() else 0,
		})
	return rows


func _report_roots_for_events(procedures: Dictionary, watchers: Array, roots: Array) -> Array:
	var section_names := {}
	for watcher in watchers:
		section_names[str(watcher.get("section", "")).to_lower()] = true
	var kept: Array = []
	for root_name in roots:
		var requested := str(root_name)
		var proc_key := _procedure_key(procedures, requested)
		if proc_key.is_empty() and section_names.has(requested.to_lower()):
			continue
		kept.append(requested)
	return kept


func _watcher_selected(watcher: Dictionary, roots: Array, filter_names: Dictionary) -> bool:
	if roots.is_empty():
		return true
	if filter_names.has(str(watcher.get("section", "")).to_lower()):
		return true
	for callback_name in watcher.get("handlers", []):
		if filter_names.has(str(callback_name).to_lower()):
			return true
	return false


func _split_whenever_tail(operator_text: String, tail: String) -> Dictionary:
	var handlers: Array = []
	var words := str(tail).strip_edges().split(",", false)
	var first_words := str(words[0]).strip_edges().split(" ", false) if words.size() > 0 else []
	if operator_text.to_lower() == "changes":
		for word in first_words:
			var name := str(word).strip_edges()
			if not name.is_empty():
				handlers.append(name)
	elif first_words.size() > 0:
		handlers.append(str(first_words[first_words.size() - 1]))
		var value := " ".join(first_words.slice(0, first_words.size() - 1))
		for index in range(1, words.size()):
			var name := str(words[index]).strip_edges()
			if not name.is_empty():
				handlers.append(name)
		var condition := operator_text if value.is_empty() else operator_text + " " + value
		return {"condition": condition, "handlers": handlers}
	for index in range(1, words.size()):
		var name := str(words[index]).strip_edges()
		if not name.is_empty():
			handlers.append(name)
	return {"condition": operator_text, "handlers": handlers}


func _fallback_evidence(text: String, roots: Array) -> Dictionary:
	var parsed := _parse_fallback_source(text)
	var procedures: Dictionary = parsed["procedures"]
	var watchers: Array = parsed["watchers"]
	var filtered: Array = []
	var filter_names: Dictionary = {}
	for root_name in roots:
		filter_names[str(root_name).to_lower()] = true
	for watcher in watchers:
		if _watcher_selected(watcher, roots, filter_names):
			filtered.append(watcher)
	var evidence_roots: Array = []
	var steps: Array = []
	var limitations: Array = [
		"Static analysis describes possible behavior, not proof that it ran.",
		"Dynamic calls, signals, engine callbacks, and external objects stay unresolved. Call sites are located; target locations are not invented.",
		"Evidence records Whenever roots, guards, early exits, state writes, and calls. Other statements are omitted.",
		"Walks stop at depth 20 or when a procedure is already on the stack.",
		"Fallback line scan is not equivalent in completeness to the AST walker.",
	]
	var truncated := false
	var seq := 0
	for watcher in filtered:
		var handler_rows := _handler_records(procedures, watcher.get("handlers", []))
		var first: Dictionary = handler_rows[0] if handler_rows.size() > 0 else {}
		var handler := str(first.get("name", ""))
		var known: bool = str(first.get("resolution", "")) == "resolved"
		var root_index := evidence_roots.size()
		evidence_roots.append({
			"kind": "whenever",
			"name": str(watcher["section"]),
			"section": str(watcher["section"]),
			"variable": str(watcher["variable"]),
			"condition": str(watcher["condition"]),
			"declaration": str(watcher["declaration"]),
			"handler": handler,
			"handlers": handler_rows,
			"handler_resolution": "resolved" if known else "unresolved",
			"handler_line": int(first.get("line", 0)) if known else 0,
			"line": int(watcher["line"]),
			"location_known": int(watcher["line"]) > 0,
		})
		if handler_rows.is_empty():
			seq += 1
			steps.append(_fallback_step(seq, root_index, "", "call", int(watcher["line"]), "Call ()", "unresolved", 0, false, ["unresolved target"]))
			continue
		for recorded in handler_rows:
			var callback := str(recorded["name"])
			var proc_key := _procedure_key(procedures, callback)
			if proc_key.is_empty():
				seq += 1
				steps.append(_fallback_step(seq, root_index, "", "call", int(watcher["line"]), "Call %s()" % callback, "unresolved", 0, false, ["unresolved target"]))
				continue
			var stack := {proc_key.to_lower(): true}
			var walked: Dictionary = _fallback_walk_proc(procedures, proc_key, root_index, "", 1, stack, seq)
			seq = int(walked["seq"])
			steps.append_array(walked["steps"])
			if bool(walked["truncated"]):
				truncated = true
			for note in walked["notes"]:
				if not limitations.has(note):
					limitations.append(note)
	if roots.is_empty():
		for proc_name in procedures.keys():
			if _is_event_entry_name(str(proc_name)):
				evidence_roots.append(_fallback_event_root(procedures, str(proc_name)))
	else:
		var section_names := {}
		for watcher in watchers:
			section_names[str(watcher["section"]).to_lower()] = true
		for root_name in roots:
			if section_names.has(str(root_name).to_lower()):
				continue
			var proc_key := _procedure_key(procedures, str(root_name))
			var display := proc_key if not proc_key.is_empty() else str(root_name)
			evidence_roots.append(_fallback_event_root(procedures, display))
	var rendered := _render_whenever_text(evidence_roots, steps, limitations)
	var event_report := ""
	if roots.is_empty():
		event_report = _regex_report(text, [])
	else:
		var event_roots := _report_roots_for_events(procedures, watchers, roots)
		if not event_roots.is_empty():
			event_report = _regex_report(text, event_roots)
	var report := _join_reports(event_report, rendered)
	return {
		"ok": true,
		"engine": "fallback",
		"completeness": "fallback",
		"report": report,
		"truncated": truncated,
		"limitations": limitations,
		"roots": evidence_roots,
		"steps": steps,
		"whenever_text": rendered,
	}


func _procs_for_entries(procedures: Dictionary) -> Array:
	var procs: Array = []
	for name in procedures.keys():
		procs.append({"name": str(name)})
	return procs


func _fallback_event_root(procedures: Dictionary, name: String) -> Dictionary:
	var known: bool = procedures.has(name)
	var line := int(procedures[name]["line"]) if known else 0
	return {
		"kind": "event",
		"name": name,
		"section": "",
		"variable": "",
		"condition": "",
		"handler": "",
		"handler_resolution": "resolved" if known else "unresolved",
		"handler_line": line,
		"line": line,
		"location_known": line > 0,
	}


func _fallback_step(seq: int, root_index: int, parent_id: String, kind: String, line: int, text: String, resolution: String, target_line: int, target_known: bool, risks: Array, branch: String = "", target_name: String = "") -> Dictionary:
	return {
		"id": "s%d" % seq,
		"parent_id": parent_id,
		"root_index": root_index,
		"kind": kind,
		"branch": branch,
		"line": line,
		"location_known": line > 0,
		"text": text,
		"resolution": resolution,
		"target_line": target_line if target_known else 0,
		"target_known": target_known,
		"target_name": target_name if target_known else "",
		"possible": true,
		"unconditional": false,
		"risks": risks,
	}


func _fallback_walk_proc(procedures: Dictionary, name: String, root_index: int, parent_id: String, depth: int, stack: Dictionary, seq: int) -> Dictionary:
	if depth > MAX_DEPTH:
		seq += 1
		var limit_step := _fallback_step(seq, root_index, parent_id, "limit", 0, "MAX_DEPTH reached — truncating", "not_applicable", 0, false, [])
		limit_step["location_known"] = false
		return {
			"seq": seq,
			"steps": [limit_step],
			"truncated": true,
			"notes": ["MAX_DEPTH reached — truncating"],
		}
	return _fallback_walk_lines(procedures, procedures[name]["body"], root_index, parent_id, depth, stack, seq)


func _fallback_walk_lines(procedures: Dictionary, body: Array, root_index: int, parent_id: String, depth: int, stack: Dictionary, seq: int) -> Dictionary:
	var steps: Array = []
	var notes: Array = []
	var truncated := false
	var skip: Array = []
	var guard_re := RegEx.new()
	guard_re.compile("(?i)^If\\s+(.+)\\s+Then\\s+Exit\\s+Sub\\s*$")
	var assign_re := RegEx.new()
	assign_re.compile("^([A-Za-z_][A-Za-z0-9_]*)\\s*=\\s*(.+)$")
	var call_re := RegEx.new()
	call_re.compile("(?i)^Call\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\((.*)\\)\\s*$")
	var dot_re := RegEx.new()
	dot_re.compile("^([A-Za-z_][A-Za-z0-9_]*)\\.([A-Za-z_][A-Za-z0-9_]*)\\s*\\((.*)\\)\\s*$")
	for entry in body:
		var line_no := int(entry["line"])
		var text := str(entry["text"])
		var opener := _fallback_opener(text)
		var closer := _fallback_closer(text)
		if not skip.is_empty():
			if not opener.is_empty():
				skip.append(opener)
			elif not closer.is_empty() and str(skip[skip.size() - 1]) == closer:
				skip.remove_at(skip.size() - 1)
			continue
		var found_guard := guard_re.search(text)
		if found_guard:
			seq += 1
			var guard := _fallback_step(seq, root_index, parent_id, "guard", line_no, "If " + found_guard.get_string(1) + " Then", "not_applicable", 0, false, ["early-return guard"])
			steps.append(guard)
			seq += 1
			steps.append(_fallback_step(seq, root_index, str(guard["id"]), "exit", line_no, "Exit Sub", "not_applicable", 0, false, ["early-return guard"], "then"))
			continue
		if not opener.is_empty():
			seq += 1
			steps.append(_fallback_step(seq, root_index, parent_id, "gap", line_no, "unsupported control flow not expanded by the fallback line scan", "not_applicable", 0, false, []))
			notes.append("unsupported control flow not expanded by the fallback line scan")
			skip.append(opener)
			continue
		if text.to_lower().begins_with("if ") or text.to_lower().begins_with("elseif "):
			seq += 1
			steps.append(_fallback_step(seq, root_index, parent_id, "gap", line_no, "unsupported control flow not expanded by the fallback line scan", "not_applicable", 0, false, []))
			notes.append("unsupported control flow not expanded by the fallback line scan")
			continue
		var found_assign := assign_re.search(text)
		if found_assign:
			seq += 1
			steps.append(_fallback_step(seq, root_index, parent_id, "state_write", line_no, found_assign.get_string(1) + " = " + found_assign.get_string(2).strip_edges(), "not_applicable", 0, false, ["state write"]))
			continue
		var found_call := call_re.search(text)
		if found_call:
			var target := found_call.get_string(1)
			var proc_key := _procedure_key(procedures, target)
			var known := not proc_key.is_empty()
			var target_line := int(procedures[proc_key]["line"]) if known else 0
			seq += 1
			var call_step := _fallback_step(seq, root_index, parent_id, "call", line_no, "Call %s(%s)" % [target, found_call.get_string(2)], "resolved" if known else "unresolved", target_line, known, [] if known else ["unresolved target"], "", proc_key if known else "")
			steps.append(call_step)
			var stack_key := proc_key.to_lower() if known else ""
			if known and stack.has(stack_key):
				truncated = true
				notes.append("cycle truncated at " + proc_key)
			elif known:
				stack[stack_key] = true
				var nested: Dictionary = _fallback_walk_proc(procedures, proc_key, root_index, str(call_step["id"]), depth + 1, stack, seq)
				stack.erase(stack_key)
				seq = int(nested["seq"])
				steps.append_array(nested["steps"])
				if bool(nested["truncated"]):
					truncated = true
				for note in nested["notes"]:
					if not notes.has(note):
						notes.append(note)
			continue
		var found_dot := dot_re.search(text)
		if found_dot:
			seq += 1
			steps.append(_fallback_step(seq, root_index, parent_id, "call", line_no, "%s.%s(%s)" % [found_dot.get_string(1), found_dot.get_string(2), found_dot.get_string(3)], "unresolved", 0, false, ["external effect", "unresolved target"]))
	if not skip.is_empty():
		notes.append("unsupported control flow not expanded by the fallback line scan")
	return {"seq": seq, "steps": steps, "truncated": truncated, "notes": notes}


func _fallback_opener(text: String) -> String:
	var lower := text.to_lower()
	var block_if := RegEx.new()
	block_if.compile("(?i)^(?:Else)?If\\b.+\\bThen\\s*$")
	if block_if.search(text):
		return "if"
	if lower.begins_with("for "):
		return "for"
	if lower.begins_with("while "):
		return "while"
	if lower == "do" or lower.begins_with("do while") or lower.begins_with("do until"):
		return "do"
	if lower.begins_with("select case"):
		return "select"
	return ""


func _fallback_closer(text: String) -> String:
	var lower := text.to_lower()
	if lower == "end if":
		return "if"
	if lower == "next" or lower.begins_with("next "):
		return "for"
	if lower == "wend" or lower == "end while":
		return "while"
	if lower == "loop" or lower.begins_with("loop "):
		return "do"
	if lower == "end select":
		return "select"
	return ""


func _strip_code_comment(line: String) -> String:
	var in_string := false
	for i in line.length():
		var ch := line[i]
		if ch == '"':
			in_string = not in_string
		elif ch == "'" and not in_string:
			return line.substr(0, i).strip_edges()
	return line.strip_edges()


func _parse_fallback_source(text: String) -> Dictionary:
	var procedures := {}
	var watchers: Array = []
	var lines := text.split("\n")
	var current_name := ""
	var current_line := 0
	var current_body: Array = []
	var sub_re := RegEx.new()
	sub_re.compile("(?i)^(?:Public\\s+|Private\\s+|Friend\\s+|Static\\s+)?(Sub|Function)\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var whenever_re := RegEx.new()
	whenever_re.compile("(?i)^Whenever\\s+Section\\s+(?:Local\\s+)?([A-Za-z_][A-Za-z0-9_]*)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s+(Changes|Becomes|Exceeds|Below|Between|Contains)\\b(.*)$")
	for index in lines.size():
		var raw := lines[index]
		var code := _strip_code_comment(raw)
		if code.is_empty():
			continue
		if not current_name.is_empty() and (code.to_lower().begins_with("end sub") or code.to_lower().begins_with("end function")):
			procedures[current_name] = {"line": current_line, "body": current_body}
			current_name = ""
			current_body = []
			continue
		var sub_found := sub_re.search(code)
		if sub_found and current_name.is_empty():
			current_name = sub_found.get_string(2)
			current_line = index + 1
			current_body = []
			continue
		if current_name.is_empty():
			var watcher_found := whenever_re.search(code)
			if watcher_found:
				var tail := _split_whenever_tail(watcher_found.get_string(3), watcher_found.get_string(4))
				var condition := str(tail["condition"])
				var handlers: Array = tail["handlers"]
				watchers.append({
					"section": watcher_found.get_string(1),
					"variable": watcher_found.get_string(2),
					"condition": condition,
					"handler": str(handlers[0]) if handlers.size() > 0 else "",
					"handlers": handlers,
					"declaration": code,
					"line": index + 1,
				})
			continue
		current_body.append({"line": index + 1, "text": code})
	if not current_name.is_empty():
		procedures[current_name] = {"line": current_line, "body": current_body}
	return {"procedures": procedures, "watchers": watchers}
