@tool
extends RefCounted
## Scans VG source for user Dim/Const/Sub/Function/Type symbols (Command Help fallback).

class_name VGUserSymbolHelp


static func lookup(keyword: String, source: String) -> Dictionary:
	if keyword.is_empty() or source.is_empty():
		return {}
	var kw_lower := keyword.to_lower()
	var lines := source.split("\n")

	# ── Pass 1: Variable declarations (Dim / Private / Public / Static / Global) ──
	for i in lines.size():
		var sline := lines[i].strip_edges()
		var sl := sline.to_lower()

		var decl_kw := ""
		var offset := 0
		if sl.begins_with("dim "):
			decl_kw = "Dim"; offset = 4
		elif sl.begins_with("private ") and not sl.begins_with("private sub ") and not sl.begins_with("private function ") and not sl.begins_with("private const "):
			decl_kw = "Private"; offset = 8
		elif sl.begins_with("public ") and not sl.begins_with("public sub ") and not sl.begins_with("public function ") and not sl.begins_with("public const "):
			decl_kw = "Public"; offset = 7
		elif sl.begins_with("static "):
			decl_kw = "Static"; offset = 7
		elif sl.begins_with("global "):
			decl_kw = "Global"; offset = 7

		if decl_kw.is_empty():
			continue

		var rest := sline.substr(offset).strip_edges()
		var vname := ""
		var ci := 0
		while ci < rest.length() and (rest[ci].is_valid_identifier() or rest[ci] == "_"):
			vname += rest[ci]
			ci += 1
		if vname.to_lower() != kw_lower:
			continue

		var vtype := "Variant"
		var after := rest.substr(ci).strip_edges()
		if after.begins_with("("):
			var close := after.find(")")
			if close >= 0:
				after = after.substr(close + 1).strip_edges()
				vtype = "Array"
		if after.to_lower().begins_with("as "):
			var tpart := after.substr(3).strip_edges()
			if tpart.to_lower().begins_with("new "):
				tpart = tpart.substr(4).strip_edges()
			var tname := ""
			for ti in tpart.length():
				var tc := tpart[ti]
				if tc.is_valid_identifier() or tc == "_" or tc == "*" or tc == " ":
					tname += tc
				else:
					break
			tname = tname.strip_edges()
			if not tname.is_empty():
				vtype = tname

		var init_val := ""
		var eq_pos := rest.find("=")
		if eq_pos >= 0:
			init_val = rest.substr(eq_pos).strip_edges()
			var cmt := init_val.find("'")
			if cmt >= 0:
				init_val = init_val.substr(0, cmt).strip_edges()

		var comment := _extract_trailing_comment(sline)
		var scope_info := _find_scope_for_line(lines, i)
		var used_on := _scan_usages(lines, vname, i)
		var modified_on := _scan_assignments(lines, vname, i)

		var scope := decl_kw
		match decl_kw:
			"Dim":
				scope = "Local variable"
			"Private":
				scope = "Private variable"
			"Public":
				scope = "Public variable"
			"Global":
				scope = "Global variable"
			"Static":
				scope = "Static variable"

		var syntax_str := decl_kw + " " + vname + " As " + vtype
		if not init_val.is_empty():
			syntax_str += " " + init_val
		var desc_str := scope + " declared on line " + str(i + 1) + ".\nType: " + vtype
		if not init_val.is_empty():
			if init_val.begins_with("= "):
				desc_str += "\nInitial value: " + init_val.substr(2).strip_edges()
			else:
				desc_str += "\nInitial value: " + init_val.substr(1).strip_edges()
		return {
			"keyword": vname + "  As " + vtype,
			"syntax": syntax_str,
			"desc": desc_str,
			"code": "",
			"ref_line": 0,
			"symbol_kind": "variable",
			"defined_on_line": i + 1,
			"comment": comment,
			"scope_info": scope_info,
			"used_on_lines": used_on,
			"modified_on_lines": modified_on,
		}

	# ── Pass 2: Const declarations ──
	for i in lines.size():
		var sline := lines[i].strip_edges()
		var sl := sline.to_lower()

		var const_offset := -1
		var const_scope := ""
		if sl.begins_with("const "):
			const_offset = 6; const_scope = "Const"
		elif sl.begins_with("public const "):
			const_offset = 14; const_scope = "Public Const"
		elif sl.begins_with("private const "):
			const_offset = 15; const_scope = "Private Const"

		if const_offset < 0:
			continue

		var rest := sline.substr(const_offset).strip_edges()
		var cname := ""
		var ci := 0
		while ci < rest.length() and (rest[ci].is_valid_identifier() or rest[ci] == "_"):
			cname += rest[ci]
			ci += 1
		if cname.to_lower() != kw_lower:
			continue

		var after := rest.substr(ci).strip_edges()
		var cmt := after.find("'")
		if cmt >= 0:
			after = after.substr(0, cmt).strip_edges()
		return {
			"keyword": cname + "  (Const)",
			"syntax": const_scope + " " + cname + " " + after,
			"desc": "Constant declared on line " + str(i + 1) + ".\nValue cannot be changed at runtime.",
			"code": "",
			"ref_line": 0,
			"symbol_kind": "const",
			"defined_on_line": i + 1,
			"comment": _extract_trailing_comment(sline),
			"scope_info": _find_scope_for_line(lines, i),
			"used_on_lines": _scan_usages(lines, cname, i),
		}

	# ── Pass 3: Sub / Function definitions ──
	var rx := RegEx.new()
	rx.compile("(?i)^\\s*(?:(Public|Private|Static)\\s+)?(?:(Sub|Function))\\s+" + keyword.replace("(", "\\(") + "\\s*\\(([^)]*)\\)(.*)")
	for i in lines.size():
		var m := rx.search(lines[i])
		if not m:
			continue
		var scope := m.get_string(1) if not m.get_string(1).is_empty() else "Public"
		var kind := m.get_string(2)
		var params := m.get_string(3).strip_edges()
		var trailer := m.get_string(4).strip_edges()
		var ret_type := ""
		if kind.to_lower() == "function":
			var tl := trailer.to_lower()
			var as_pos := tl.find("as ")
			if as_pos >= 0:
				ret_type = trailer.substr(as_pos + 3).strip_edges()
				var cmt_pos := ret_type.find("'")
				if cmt_pos >= 0:
					ret_type = ret_type.substr(0, cmt_pos).strip_edges()
		var syntax_str := scope + " " + kind + " " + keyword + "(" + params + ")"
		if not ret_type.is_empty():
			syntax_str += " As " + ret_type
		var param_desc := "\nParameters: " + (params if not params.is_empty() else "(none)")
		var desc_str := scope + " " + kind + " defined on line " + str(i + 1) + "." + param_desc
		if not ret_type.is_empty():
			desc_str += "\nReturns: " + ret_type
		var title := keyword + "(" + params + ")"
		if not ret_type.is_empty():
			title += " As " + ret_type
		return {
			"keyword": title,
			"syntax": syntax_str,
			"desc": desc_str,
			"code": "",
			"ref_line": 0,
			"symbol_kind": kind.to_lower(),
			"defined_on_line": i + 1,
			"comment": _extract_trailing_comment(lines[i]),
			"called_from_lines": _scan_callers(lines, keyword, i),
		}

	# ── Pass 4: Type definitions ──
	var type_rx := RegEx.new()
	type_rx.compile("(?i)^\\s*(?:Public\\s+|Private\\s+)?Type\\s+" + keyword.replace("(", "\\(") + "\\s*$")
	for i in lines.size():
		if not type_rx.search(lines[i]):
			continue
		var scope_kw := "Public"
		if lines[i].strip_edges().to_lower().begins_with("private"):
			scope_kw = "Private"
		return {
			"keyword": keyword + "  (Type)",
			"syntax": scope_kw + " Type " + keyword,
			"desc": "User-defined Type declared on line " + str(i + 1) + ".",
			"code": "",
			"ref_line": 0,
			"symbol_kind": "type",
			"defined_on_line": i + 1,
			"comment": _extract_trailing_comment(lines[i]),
			"scope_info": "Module-level",
			"used_on_lines": _scan_usages(lines, keyword, i),
			"type_members": _scan_type_members(lines, i),
		}

	return {}


static func _extract_trailing_comment(line: String) -> String:
	var stripped := line.strip_edges()
	if stripped.begins_with("'") or stripped.to_lower().begins_with("rem "):
		return ""
	var in_string := false
	for ci in line.length():
		var ch := line[ci]
		if ch == '"':
			in_string = not in_string
		elif ch == "'" and not in_string:
			var comment := line.substr(ci + 1).strip_edges()
			if not comment.is_empty():
				return comment
			return ""
	return ""


static func _find_scope_for_line(lines: PackedStringArray, line_idx: int) -> String:
	var proc_rx := RegEx.new()
	proc_rx.compile("(?i)^\\s*(?:(?:Public|Private|Static)\\s+)?(?:Sub|Function)\\s+(\\w+)")
	var end_rx := RegEx.new()
	end_rx.compile("(?i)^\\s*End\\s+(?:Sub|Function)")
	var inside_proc := ""
	var depth := 0
	for j in range(line_idx - 1, -1, -1):
		var em := end_rx.search(lines[j])
		if em:
			depth += 1
		var pm := proc_rx.search(lines[j])
		if pm:
			if depth > 0:
				depth -= 1
			else:
				inside_proc = pm.get_string(1)
				var kind_rx := RegEx.new()
				kind_rx.compile("(?i)\\b(Sub|Function)\\b")
				var km := kind_rx.search(lines[j])
				if km:
					return "Local to " + km.get_string(1) + " " + inside_proc
				return "Local to " + inside_proc
	return "Module-level"


static func _scan_usages(lines: PackedStringArray, symbol: String, decl_line: int) -> Array:
	var result: Array = []
	var rx := RegEx.new()
	rx.compile("(?i)\\b" + symbol.replace("(", "\\(").replace(")", "\\)") + "\\b")
	for i in lines.size():
		if i == decl_line:
			continue
		var stripped := lines[i].strip_edges()
		if stripped.begins_with("'") or stripped.to_lower().begins_with("rem "):
			continue
		if rx.search(lines[i]):
			result.append(i + 1)
	return result


static func _scan_assignments(lines: PackedStringArray, symbol: String, decl_line: int) -> Array:
	var result: Array = []
	var assign_rx := RegEx.new()
	assign_rx.compile("(?i)^[^']*\\b" + symbol.replace("(", "\\(").replace(")", "\\)") + "\\b[^=<>!]*=[^=]")
	for i in lines.size():
		if i == decl_line:
			continue
		var stripped := lines[i].strip_edges()
		if stripped.begins_with("'") or stripped.to_lower().begins_with("rem "):
			continue
		var sl := stripped.to_lower()
		if sl.begins_with("if ") or sl.begins_with("elseif ") or sl.begins_with("while ") \
			or sl.begins_with("until ") or sl.begins_with("case ") or sl.begins_with("select ") \
			or sl.begins_with("debug.print") or sl.begins_with("print ") \
			or sl.begins_with("msgbox") or sl.begins_with("call "):
			continue
		if sl.begins_with("sub ") or sl.begins_with("function ") or sl.begins_with("end ") \
			or sl.begins_with("public sub") or sl.begins_with("private sub") \
			or sl.begins_with("public function") or sl.begins_with("private function"):
			continue
		if assign_rx.search(lines[i]):
			result.append(i + 1)
	return result


static func _scan_callers(lines: PackedStringArray, proc_name: String, def_line: int) -> Array:
	var result: Array = []
	var call_rx := RegEx.new()
	call_rx.compile("(?i)\\b" + proc_name.replace("(", "\\(").replace(")", "\\)") + "\\b")
	var def_rx := RegEx.new()
	def_rx.compile("(?i)^\\s*(?:(?:Public|Private|Static)\\s+)?(?:Sub|Function)\\s+" + proc_name.replace("(", "\\(") + "\\b")
	for i in lines.size():
		if i == def_line:
			continue
		var stripped := lines[i].strip_edges()
		if stripped.begins_with("'") or stripped.to_lower().begins_with("rem "):
			continue
		if def_rx.search(lines[i]):
			continue
		if call_rx.search(lines[i]):
			result.append(i + 1)
	return result


static func _scan_type_members(lines: PackedStringArray, type_line: int) -> Array:
	var result: Array = []
	var end_rx := RegEx.new()
	end_rx.compile("(?i)^\\s*End\\s+Type")
	for i in range(type_line + 1, lines.size()):
		if end_rx.search(lines[i]):
			break
		var stripped := lines[i].strip_edges()
		if stripped.is_empty() or stripped.begins_with("'"):
			continue
		result.append(stripped)
	return result
