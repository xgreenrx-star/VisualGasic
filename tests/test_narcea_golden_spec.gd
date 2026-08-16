extends SceneTree
## Narcea Golden Path — Tier A (deterministic, no live LLM)
##
## Validates the counter-form golden scenario against vg-project-spec /
## vg-form-spec / vg-code-spec appliers and rubric.json.
##
## Run: bash scripts/run_narcea_golden.sh --tier A

const TIER_A := "A"

var _failed := 0
var _passed := 0
var _fixtures_dir := ""
var _rubric: Dictionary = {}


func _init() -> void:
	print("=== Narcea Golden Path — Tier %s ===" % TIER_A)
	_fixtures_dir = _resolve_fixtures_dir()
	if _fixtures_dir.is_empty():
		printerr("Cannot locate tests/narcea_golden/fixtures (script dir: %s)" %
			[str(get_script().resource_path.get_base_dir())])
		_print_summary()
		quit(1)
		return

	if not _load_rubric():
		_print_summary()
		quit(1)
		return

	_run_tier_a()
	_print_summary()
	quit(1 if _failed > 0 else 0)


func _resolve_fixtures_dir() -> String:
	var base: String = get_script().resource_path.get_base_dir()
	# Script lives at tests/test_narcea_golden_spec.gd → fixtures sibling.
	var candidate: String = base.path_join("narcea_golden/fixtures")
	if DirAccess.dir_exists_absolute(candidate):
		return candidate
	# Fallback when staged under a host project (run_gd_tests copy pattern).
	candidate = "res://_narcea_golden_fixtures"
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate)):
		return ProjectSettings.globalize_path(candidate)
	return ""


func _rubric_path() -> String:
	var base: String = get_script().resource_path.get_base_dir()
	var p: String = base.path_join("narcea_golden/rubric.json")
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
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("load rubric", "invalid JSON")
		return false
	_rubric = parsed
	_ok("loaded rubric '%s'" % str(_rubric.get("scenario_id", "?")))
	return true


func _read_fixture(name: String) -> String:
	var path := _fixtures_dir.path_join(name)
	if not FileAccess.file_exists(path):
		_fail("read fixture %s" % name, "missing at %s" % path)
		return ""
	return FileAccess.get_file_as_string(path)


func _run_tier_a() -> void:
	print("")
	print("--- Tier A: extract → validate → apply → lint ---")

	var response := _read_fixture("golden_counter_response.txt")
	if response.is_empty():
		return

	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var FormSpec = load("res://addons/visual_gasic/vg_ai_form_spec.gd")
	var CodeSpec = load("res://addons/visual_gasic/vg_ai_code_spec.gd")
	var SafeWrite = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	if ProjectSpec == null or FormSpec == null or CodeSpec == null or SafeWrite == null:
		_fail("load appliers", "one or more vg_ai_* modules missing")
		return

	var ps = ProjectSpec.new()
	var fs = FormSpec.new()
	var cs = CodeSpec.new()
	var sw = SafeWrite.new()

	# 1. Extract project spec from simulated LLM response.
	var spec: Dictionary = ps.extract_spec(response)
	_expect("extract vg-project-spec from response", not spec.is_empty())
	if spec.is_empty():
		return

	var want_name := str(_rubric.get("required_project_name", "CounterDemo"))
	_expect("project_name is '%s'" % want_name,
		str(spec.get("project_name", "")) == want_name,
		"got '%s'" % str(spec.get("project_name", "")))

	# 2. Compare against canonical JSON fixture (structural parity).
	var fixture_json := _read_fixture("golden_counter_project_spec.json")
	if not fixture_json.is_empty():
		var fixture_spec = JSON.parse_string(fixture_json)
		if typeof(fixture_spec) == TYPE_DICTIONARY:
			_expect("extracted spec matches fixture project_name",
				str(spec.get("project_name", "")) == str(fixture_spec.get("project_name", "")))
			var ef: Array = spec.get("forms", [])
			var ff: Array = fixture_spec.get("forms", [])
			_expect("forms[] count matches fixture", ef.size() == ff.size() and ef.size() >= 1)

	# 3. Form-spec validation (layout + required controls).
	var forms: Array = spec.get("forms", [])
	_expect("spec includes at least one form", forms.size() >= 1)
	for form_dict in forms:
		if typeof(form_dict) != TYPE_DICTIONARY:
			continue
		_validate_form_rubric(form_dict, fs)

	# 4. Apply code files via project-spec (designer=null — forms skipped, files written).
	_cleanup_project_sandbox(spec, ps)
	var helpers := {
		"safe_writer": sw,
		"code_spec": cs,
		"form_spec": fs,
		"designer": null,
	}
	var result: Dictionary = ps.apply(spec, helpers)
	_expect("project-spec apply ok", result.get("ok", false),
		str(result.get("summary", "")))
	var written: Array = result.get("written", [])
	_expect("Form1.vg written", _array_has_suffix(written, "Form1.vg"),
		"written: %s" % str(written))

	# Forms skipped without designer — expected in Tier A headless.
	var skipped: Array = result.get("skipped", [])
	var form_skipped := false
	for s in skipped:
		if typeof(s) == TYPE_DICTIONARY and str(s.get("reason", "")).find("designer") != -1:
			form_skipped = true
			break
	if not forms.is_empty():
		_expect("forms skipped headless (designer unavailable)", form_skipped)

	# 5. Read back .vg and score handler rubric + lint.
	var vg_path := ""
	for w in written:
		if str(w).ends_with("Form1.vg"):
			vg_path = str(w)
			break
	if vg_path.is_empty():
		_fail("locate Form1.vg", "not in written list")
		return

	var vg_src: String = sw.read(vg_path)
	_expect("read Form1.vg back", not vg_src.is_empty())
	_score_vg_rubric(vg_src)
	_lint_vg(vg_src, vg_path)

	# 6. Event stub generator idempotency (form-spec helper used by project apply).
	if forms.size() > 0 and typeof(forms[0]) == TYPE_DICTIONARY:
		var stubs: String = fs.generate_event_stubs(forms[0], vg_src)
		_expect("generate_event_stubs idempotent (handler already present)",
			stubs.is_empty() or not stubs.contains("btnIncrement_Click"),
			"stubs would duplicate existing subs")

	_cleanup_project_sandbox(spec, ps)


func _validate_form_rubric(form_dict: Dictionary, form_spec: Object) -> void:
	var controls: Array = form_dict.get("controls", [])
	var required: Array = _rubric.get("required_controls", [])
	for req in required:
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
		_expect("form control '%s' present" % rname, found)

	var warnings: Array = form_spec.check_layout(form_dict)
	var max_w := int(_rubric.get("max_layout_warnings", 3))
	_expect("layout warnings <= %d (got %d)" % [max_w, warnings.size()],
		warnings.size() <= max_w,
		str(warnings))


func _score_vg_rubric(source: String) -> void:
	var lower := source.to_lower()
	for sub_name in _rubric.get("required_handler_subs", []):
		var needle := ("sub " + str(sub_name)).to_lower()
		_expect("handler %s present" % str(sub_name),
			lower.find(needle) != -1 or lower.find(needle.replace(" ", "")) != -1)

	for frag in _rubric.get("required_vg_substrings", []):
		_expect("vg contains '%s'" % str(frag), str(frag).to_lower() in lower)

	for pat in _rubric.get("required_vg_patterns", []):
		if typeof(pat) != TYPE_DICTIONARY:
			continue
		var rx := RegEx.new()
		var err := rx.compile(str(pat.get("regex", "")))
		if err != OK:
			_fail("compile rubric regex %s" % str(pat.get("id", "?")), "RegEx error")
			continue
		_expect("vg pattern '%s'" % str(pat.get("id", "?")),
			rx.search(source) != null,
			str(pat.get("description", "")))


func _lint_vg(source: String, path: String) -> void:
	if not ClassDB.class_exists("VGLinter"):
		_ok("VGLinter skipped (class not registered in headless)")
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
	_expect("no VGLinter %s issues (got %d)" % [forbid, bad], bad == 0,
		"%d lint issue(s)" % issues.size())


func _cleanup_project_sandbox(spec: Dictionary, project_spec: Object) -> void:
	var root := str(project_spec.project_root(spec))
	if root.is_empty() or root == "res://":
		return
	var abs := ProjectSettings.globalize_path(root)
	if DirAccess.dir_exists_absolute(abs):
		_remove_tree(abs)


func _cleanup_dir(user_path: String) -> void:
	var abs := ProjectSettings.globalize_path(user_path)
	if not DirAccess.dir_exists_absolute(abs):
		return
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
	print("=== Narcea Golden Tier %s %s ===" % [
		TIER_A,
		"PASSED" if _failed == 0 else "FAILED",
	])
