extends RefCounted
class_name NarceaRubric
## Shared rubric scoring for Narcea golden + live test harnesses.


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func score_vg(vg_src: String, rubric: Dictionary, label: String, report: Callable) -> bool:
	var ok := true
	if bool(rubric.get("forbid_todo_stubs", false)):
		if vg_src.to_lower().find("' todo:") >= 0 or vg_src.find("TODO: implement") >= 0:
			report.call(false, "[%s] forbids TODO stubs" % label)
			ok = false
	for sub in rubric.get("required_handler_subs", []):
		var name := str(sub)
		if name == "_any_button_Click":
			if not _has_any_button_handler(vg_src):
				report.call(false, "[%s] missing any button _Click handler" % label)
				ok = false
		elif vg_src.find("Sub " + name) < 0 and vg_src.find("sub " + name.to_lower()) < 0:
			report.call(false, "[%s] missing Sub %s" % [label, name])
			ok = false
	for frag in rubric.get("required_vg_substrings", []):
		if not vg_src.contains(str(frag)):
			report.call(false, "[%s] vg missing '%s'" % [label, str(frag)])
			ok = false
	for pat in rubric.get("required_vg_patterns", []):
		if typeof(pat) != TYPE_DICTIONARY:
			continue
		var rx := RegEx.new()
		if rx.compile(str(pat.get("regex", ""))) != OK:
			continue
		if rx.search(vg_src) == null:
			report.call(false, "[%s] pattern '%s' not matched" % [label, str(pat.get("id", "?"))])
			ok = false
	if ok:
		report.call(true, "[%s] vg rubric ok" % label)
	return ok


static func score_form_controls(form_spec: Dictionary, rubric: Dictionary, label: String, report: Callable) -> bool:
	var ok := true
	var controls: Array = form_spec.get("controls", [])
	for req in rubric.get("required_controls", []):
		if typeof(req) != TYPE_DICTIONARY:
			continue
		var want_name := str(req.get("name", ""))
		var name_pat := str(req.get("name_pattern", ""))
		var types: Array = req.get("types", [])
		var found := false
		for c in controls:
			if typeof(c) != TYPE_DICTIONARY:
				continue
			var cname := str(c.get("name", ""))
			var ctype := str(c.get("type", ""))
			var name_ok := want_name.is_empty() or cname == want_name
			if not name_pat.is_empty() and not name_ok:
				var low := cname.to_lower()
				for part in name_pat.split("|"):
					if part.strip_edges() in low:
						name_ok = true
						break
			var type_ok := types.is_empty()
			for t in types:
				if ctype == str(t):
					type_ok = true
					break
			if name_ok and type_ok:
				found = true
				break
		if not found:
			report.call(false, "[%s] missing control %s" % [label, want_name if not want_name.is_empty() else name_pat])
			ok = false
	if ok and not rubric.get("required_controls", []).is_empty():
		report.call(true, "[%s] form controls ok" % label)
	return ok


static func _has_any_button_handler(vg_src: String) -> bool:
	var rx := RegEx.new()
	if rx.compile("(?i)Sub\\s+\\w+_Click\\s*\\(") != OK:
		return false
	return rx.search(vg_src) != null
