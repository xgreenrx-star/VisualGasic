extends SceneTree
## Narcea Golden Path — Tier A (fixture) and Tier B (recorded replay).
##
## Tier A: tests/narcea_golden/fixtures/golden_counter_response.txt
## Tier B: tests/narcea_golden/recorded/*_response.txt (+ optional .ndjson)
##
## Env: NARCEA_GOLDEN_TIER=A|B (set by scripts/run_narcea_golden.sh)

var _tier := "A"
var _failed := 0
var _passed := 0
var _golden_root := ""
var _fixtures_dir := ""
var _recorded_dir := ""
var _rubric: Dictionary = {}


func _init() -> void:
	_tier = OS.get_environment("NARCEA_GOLDEN_TIER").strip_edges().to_upper()
	if _tier.is_empty():
		_tier = "A"

	print("=== Narcea Golden Path — Tier %s ===" % _tier)
	_golden_root = _resolve_golden_root()
	if _golden_root.is_empty():
		printerr("Cannot locate tests/narcea_golden/")
		_print_summary()
		quit(1)
		return

	_fixtures_dir = _golden_root.path_join("fixtures")
	_recorded_dir = _golden_root.path_join("recorded")

	if not _load_rubric():
		_print_summary()
		quit(1)
		return

	match _tier:
		"A":
			_run_tier_a()
		"B":
			_run_tier_b()
		_:
			_fail("tier", "unknown NARCEA_GOLDEN_TIER '%s' (use A or B)" % _tier)

	_print_summary()
	quit(1 if _failed > 0 else 0)


func _resolve_golden_root() -> String:
	var base: String = get_script().resource_path.get_base_dir()
	var candidate: String = base.path_join("narcea_golden")
	if DirAccess.dir_exists_absolute(candidate):
		return candidate
	candidate = ProjectSettings.globalize_path("res://_narcea_golden")
	if DirAccess.dir_exists_absolute(candidate):
		return candidate
	return ""


func _rubric_path() -> String:
	var p: String = _golden_root.path_join("rubric.json")
	if FileAccess.file_exists(p):
		return p
	p = ProjectSettings.globalize_path("res://_narcea_golden_rubric.json")
	if FileAccess.file_exists(p):
		return p
	return ""


func _load_rubric() -> bool:
	var path := _rubric_path()
	if path.is_empty():
		_fail("load rubric", "rubric.json not found")
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("load rubric", "invalid JSON")
		return false
	_rubric = parsed
	_ok("loaded rubric '%s'" % str(_rubric.get("scenario_id", "?")))
	return true


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		_fail("read file", "missing %s" % path)
		return ""
	return FileAccess.get_file_as_string(path)


func _run_tier_a() -> void:
	print("")
	print("--- Tier A: canonical fixture ---")
	var response := _read_text(_fixtures_dir.path_join("golden_counter_response.txt"))
	if response.is_empty():
		return
	_run_response_pipeline(response, "tier_a_fixture")


func _run_tier_b() -> void:
	print("")
	print("--- Tier B: recorded response replay ---")
	var files: PackedStringArray = _list_recorded_responses()
	if files.is_empty():
		_fail("discover recorded responses", "no *_response.txt in %s" % _recorded_dir)
		return
	_ok("found %d recorded response file(s)" % files.size())
	for path in files:
		var label := path.get_file().trim_suffix("_response.txt")
		print("")
		print(">> Scenario: %s" % label)
		var response := _read_text(path)
		if response.is_empty():
			continue
		_run_response_pipeline(response, label)
		var ndjson_path := path.trim_suffix("_response.txt") + ".ndjson"
		if FileAccess.file_exists(ndjson_path):
			_validate_ndjson(ndjson_path, label)
		else:
			_ok("[%s] no paired .ndjson (response-only replay)" % label)


func _list_recorded_responses() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(_recorded_dir):
		return out
	var da := DirAccess.open(_recorded_dir)
	if da == null:
		return out
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if name.ends_with("_response.txt") and not da.current_is_dir():
			out.append(_recorded_dir.path_join(name))
		name = da.get_next()
	da.list_dir_end()
	out.sort()
	return out


func _run_response_pipeline(response: String, label: String) -> void:
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var FormSpec = load("res://addons/visual_gasic/vg_ai_form_spec.gd")
	var CodeSpec = load("res://addons/visual_gasic/vg_ai_code_spec.gd")
	var SafeWrite = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	if ProjectSpec == null or FormSpec == null or CodeSpec == null or SafeWrite == null:
		_fail("[%s] load appliers" % label, "vg_ai_* module missing")
		return

	var ps = ProjectSpec.new()
	var fs = FormSpec.new()
	var cs = CodeSpec.new()
	var sw = SafeWrite.new()

	var spec: Dictionary = ps.extract_spec(response)
	_expect("[%s] extract vg-project-spec" % label, not spec.is_empty())
	if spec.is_empty():
		return

	var want_name := str(_rubric.get("required_project_name", "CounterDemo"))
	_expect("[%s] project_name is '%s'" % [label, want_name],
		str(spec.get("project_name", "")) == want_name,
		"got '%s'" % str(spec.get("project_name", "")))

	var forms: Array = spec.get("forms", [])
	_expect("[%s] spec includes at least one form" % label, forms.size() >= 1)
	for form_dict in forms:
		if typeof(form_dict) == TYPE_DICTIONARY:
			_validate_form_rubric(form_dict, fs, label)

	_cleanup_project_sandbox(spec, ps)
	var helpers := {
		"safe_writer": sw,
		"code_spec": cs,
		"form_spec": fs,
		"designer": null,
	}
	var result: Dictionary = ps.apply(spec, helpers)
	_expect("[%s] project-spec apply ok" % label, result.get("ok", false),
		str(result.get("summary", "")))

	var written: Array = result.get("written", [])
	_expect("[%s] Form1.vg written" % label, _array_has_suffix(written, "Form1.vg"),
		str(written))

	if not forms.is_empty():
		var form_skipped := false
		for s in result.get("skipped", []):
			if typeof(s) == TYPE_DICTIONARY and str(s.get("reason", "")).find("designer") != -1:
				form_skipped = true
				break
		_expect("[%s] forms skipped headless (designer unavailable)" % label, form_skipped)

	var vg_path := ""
	for w in written:
		if str(w).ends_with("Form1.vg"):
			vg_path = str(w)
			break
	if vg_path.is_empty():
		_fail("[%s] locate Form1.vg" % label, "not in written list")
		_cleanup_project_sandbox(spec, ps)
		return

	var vg_src: String = sw.read(vg_path)
	_expect("[%s] read Form1.vg back" % label, not vg_src.is_empty())
	_score_vg_rubric(vg_src, label)
	_lint_vg(vg_src, vg_path, label)

	if forms.size() > 0 and typeof(forms[0]) == TYPE_DICTIONARY:
		var stubs: String = fs.generate_event_stubs(forms[0], vg_src)
		_expect("[%s] generate_event_stubs idempotent" % label,
			stubs.is_empty() or not stubs.contains("btnIncrement_Click"))

	_cleanup_project_sandbox(spec, ps)


func _validate_ndjson(path: String, label: String) -> void:
	var text := _read_text(path)
	if text.is_empty():
		return
	var lines := text.split("\n", false)
	var has_start := false
	var has_end := false
	var end_reason := ""
	var has_project_spec_flag := false
	var has_user_prompt := false
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue
		var obj = JSON.parse_string(line)
		if typeof(obj) != TYPE_DICTIONARY:
			_fail("[%s] ndjson line" % label, "invalid JSON: %s" % line.substr(0, 80))
			continue
		match str(obj.get("type", "")):
			"session_start":
				has_start = true
			"session_end":
				has_end = true
				end_reason = str(obj.get("reason", ""))
			"user_prompt":
				has_user_prompt = true
			"assistant_response":
				if obj.get("has_project_spec", false):
					has_project_spec_flag = true
	_expect("[%s] ndjson has session_start" % label, has_start)
	_expect("[%s] ndjson has session_end" % label, has_end)
	if has_end:
		var allowed: Array = ["complete", "mutation_stop", "user_new_turn", "hop_limit", "blocked"]
		_expect("[%s] ndjson session_end reason valid" % label,
			end_reason.is_empty() or allowed.has(end_reason),
			"reason='%s'" % end_reason)
	_expect("[%s] ndjson has user_prompt event" % label, has_user_prompt)
	_expect("[%s] ndjson assistant_response has_project_spec" % label, has_project_spec_flag)


func _validate_form_rubric(form_dict: Dictionary, form_spec: Object, label: String) -> void:
	var controls: Array = form_dict.get("controls", [])
	for req in _rubric.get("required_controls", []):
		if typeof(req) != TYPE_DICTIONARY:
			continue
		var rname := str(req.get("name", ""))
		var rtypes: Array = req.get("types", [])
		var found := false
		for c in controls:
			if typeof(c) != TYPE_DICTIONARY:
				continue
			if str(c.get("name", "")) != rname:
				continue
			var ctype := str(c.get("type", ""))
			if rtypes.is_empty() or rtypes.has(ctype):
				found = true
				break
		_expect("[%s] form control '%s' present" % [label, rname], found)

	var warnings: Array = form_spec.check_layout(form_dict)
	var max_w := int(_rubric.get("max_layout_warnings", 3))
	_expect("[%s] layout warnings <= %d (got %d)" % [label, max_w, warnings.size()],
		warnings.size() <= max_w, str(warnings))


func _score_vg_rubric(source: String, label: String) -> void:
	var lower := source.to_lower()
	for sub_name in _rubric.get("required_handler_subs", []):
		var needle := ("sub " + str(sub_name)).to_lower()
		_expect("[%s] handler %s present" % [label, str(sub_name)],
			lower.find(needle) != -1 or lower.find(needle.replace(" ", "")) != -1)
	for frag in _rubric.get("required_vg_substrings", []):
		_expect("[%s] vg contains '%s'" % [label, str(frag)], str(frag).to_lower() in lower)
	for pat in _rubric.get("required_vg_patterns", []):
		if typeof(pat) != TYPE_DICTIONARY:
			continue
		var rx := RegEx.new()
		if rx.compile(str(pat.get("regex", ""))) != OK:
			_fail("[%s] compile rubric regex %s" % [label, str(pat.get("id", "?"))], "RegEx error")
			continue
		_expect("[%s] vg pattern '%s'" % [label, str(pat.get("id", "?"))],
			rx.search(source) != null, str(pat.get("description", "")))


func _lint_vg(source: String, path: String, label: String) -> void:
	if not ClassDB.class_exists("VGLinter"):
		_ok("[%s] VGLinter skipped (headless)" % label)
		return
	var issues: Array = VGLinter.lint_text(source, path)
	var forbid := str(_rubric.get("forbid_lint_severity", "ERROR")).to_upper()
	var bad := 0
	for issue in issues:
		if typeof(issue) != TYPE_OBJECT:
			continue
		var sev := ""
		if issue.has_method("get_severity_name"):
			sev = str(issue.get_severity_name()).to_upper()
		elif "severity" in issue:
			sev = str(issue.severity).to_upper()
		if sev == forbid:
			bad += 1
	_expect("[%s] no VGLinter %s issues (got %d)" % [label, forbid, bad], bad == 0)


func _cleanup_project_sandbox(spec: Dictionary, project_spec: Object) -> void:
	var root := str(project_spec.project_root(spec))
	if root.is_empty() or root == "res://":
		return
	var abs := ProjectSettings.globalize_path(root)
	if DirAccess.dir_exists_absolute(abs):
		_remove_tree(abs)


func _remove_tree(abs_path: String) -> void:
	var da := DirAccess.open(abs_path)
	if da == null:
		return
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := abs_path.path_join(name)
			if da.current_is_dir():
				_remove_tree(full)
			else:
				DirAccess.remove_absolute(full)
		name = da.get_next()
	da.list_dir_end()
	DirAccess.remove_absolute(abs_path)


func _array_has_suffix(arr: Array, suffix: String) -> bool:
	for item in arr:
		if str(item).ends_with(suffix):
			return true
	return false


func _ok(label: String) -> void:
	_passed += 1
	print("  [PASS] %s" % label)


func _fail(label: String, reason: String) -> void:
	_failed += 1
	print("  [FAIL] %s: %s" % [label, reason])


func _expect(label: String, cond: bool, reason: String = "") -> void:
	if cond:
		_ok(label)
	else:
		_fail(label, reason if not reason.is_empty() else "assertion failed")


func _print_summary() -> void:
	print("")
	var total := _passed + _failed
	print("RESULTS: %d/%d passed, %d failed" % [_passed, total, _failed])
	print("=== Narcea Golden Tier %s %s ===" % [_tier, "PASSED" if _failed == 0 else "FAILED"])
