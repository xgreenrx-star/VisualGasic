extends SceneTree
## Tier C — live Gemini project-spec → scaffold smoke test.
##
## Env:
##   NARCEA_GEMINI_KEY     — API key (else reads ~/.config/godot/editor_settings-4.6.tres)
##   NARCEA_GEMINI_MODEL   — default gemini-2.0-flash (override if your key tier differs)
##   NARCEA_LIVE=1         — required gate

const DEFAULT_MODEL := "gemini-3.6-flash"
const TIMEOUT_SEC := 120.0

var _failed := 0
var _passed := 0
var _http: HTTPRequest
var _done := false


func _initialize() -> void:
	if OS.get_environment("NARCEA_LIVE") != "1":
		printerr("Set NARCEA_LIVE=1 to run live Gemini test")
		quit(2)
		return

	print("=== Narcea Live Gemini Tier C ===")
	var api_key := _load_gemini_key()
	if api_key.is_empty():
		printerr("No Gemini API key — set NARCEA_GEMINI_KEY or configure EditorSettings")
		quit(2)
		return

	var model := OS.get_environment("NARCEA_GEMINI_MODEL").strip_edges()
	if model.is_empty():
		model = DEFAULT_MODEL
	print("Model: %s" % model)

	# Offline normalize fixture first (proves Gemini-shaped drift is handled).
	_test_gemini_fixture_normalize()
	if OS.get_environment("NARCEA_LIVE_SKIP_API") == "1":
		print("(NARCEA_LIVE_SKIP_API=1 — skipping live HTTP call)")
		_finish()
		return

	var prompt := FileAccess.get_file_as_string(_golden_path("prompt.txt"))
	if prompt.is_empty():
		prompt = "Build a simple counter form under ai_projects with lblCount and btnIncrement. Reply with vg-project-spec JSON including forms[] controls and Form1.vg in files[]."
	var system := _build_system_prompt()

	_http = HTTPRequest.new()
	root.add_child(_http)
	_http.request_completed.connect(_on_http_completed)
	_http.timeout = int(TIMEOUT_SEC)

	var Providers = load("res://addons/visual_gasic/vg_ai_providers.gd")
	var req: Dictionary = Providers.build_request("gemini", model, system, [], prompt, api_key)
	var body_str: String = req.get("body", "")
	var path: String = str(req.get("path", "")).replace(":streamGenerateContent?alt=sse", ":generateContent?")
	var url: String = "https://generativelanguage.googleapis.com" + path
	call_deferred("_start_gemini_request", url, body_str)
	var timer := Timer.new()
	timer.wait_time = TIMEOUT_SEC
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if _done:
			return
		_fail("HTTP timeout", "no response in %ds" % int(TIMEOUT_SEC))
		_finish()
	)
	root.add_child(timer)
	timer.start()


func _start_gemini_request(url: String, body_str: String) -> void:
	var err := _http.request(url, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body_str)
	if err != OK:
		_fail("HTTP request", error_string(err))
		_finish()


func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_done = true
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("HTTP result", str(result))
		_finish()
		return
	if response_code != 200:
		_fail("HTTP status", "%d — %s" % [response_code, body.get_string_from_utf8().substr(0, 400)])
		_finish()
		return

	var text: String = _extract_gemini_text(body.get_string_from_utf8())
	_expect("Gemini returned text", text.length() > 80, "len=%d" % text.length())
	print("--- Gemini response (first 500 chars) ---")
	print(text.substr(0, 500))
	print("---")

	_run_scaffold_pipeline(text, "live_gemini")
	_finish()


func _extract_gemini_text(raw: String) -> String:
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return raw
	var candidates: Array = parsed.get("candidates", [])
	if candidates.is_empty():
		return raw
	var content = candidates[0].get("content", {})
	var parts: Array = content.get("parts", [])
	var out := ""
	for p in parts:
		if typeof(p) == TYPE_DICTIONARY:
			out += str(p.get("text", ""))
	return out


func _test_gemini_fixture_normalize() -> void:
	print("")
	print("--- Pre-flight: Gemini fixture normalize ---")
	var fixture := FileAccess.get_file_as_string(_golden_path("fixtures/gemini_tipcalc_response.txt"))
	if fixture.is_empty():
		_fail("load gemini fixture", "missing")
		return
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var ps = ProjectSpec.new()
	var spec: Dictionary = ps.extract_spec(fixture)
	_expect("fixture extract_spec", not spec.is_empty())
	_expect("fixture project_name TipCalc", str(spec.get("project_name", "")) == "TipCalc")
	var files: Array = spec.get("files", [])
	_expect("fixture files non-empty", not files.is_empty())
	if not files.is_empty() and typeof(files[0]) == TYPE_DICTIONARY:
		_expect("fixture source from contents", not str(files[0].get("source", "")).is_empty())
	var forms: Array = spec.get("forms", [])
	if not forms.is_empty() and typeof(forms[0]) == TYPE_DICTIONARY:
		var ctrls: Array = forms[0].get("controls", [])
		if not ctrls.is_empty() and typeof(ctrls[0]) == TYPE_DICTIONARY:
			_expect("fixture control left normalized", ctrls[0].has("left"))
	_run_scaffold_pipeline(fixture, "fixture_gemini", false)


func _run_scaffold_pipeline(response: String, label: String, cleanup: bool = true) -> void:
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var FormSpec = load("res://addons/visual_gasic/vg_ai_form_spec.gd")
	var CodeSpec = load("res://addons/visual_gasic/vg_ai_code_spec.gd")
	var SafeWrite = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	if ProjectSpec == null or FormSpec == null or CodeSpec == null or SafeWrite == null:
		_fail("[%s] load modules" % label, "missing")
		return

	var ps = ProjectSpec.new()
	var fs = FormSpec.new()
	var cs = CodeSpec.new()
	var sw = SafeWrite.new()

	var spec: Dictionary = ps.extract_spec(response)
	_expect("[%s] extract vg-project-spec" % label, not spec.is_empty())
	if spec.is_empty():
		return

	if cleanup:
		_cleanup(ps.project_root(spec))

	var result: Dictionary = ps.apply(spec, {
		"safe_writer": sw,
		"code_spec": cs,
		"form_spec": fs,
		"designer": null,
	})
	_expect("[%s] apply ok" % label, result.get("ok", false), str(result.get("summary", "")))
	_expect("[%s] Form1.vg written" % label, _has_suffix(result.get("written", []), "Form1.vg"), str(result.get("written", [])))

	for s in result.get("skipped", []):
		if typeof(s) == TYPE_DICTIONARY:
			print("  [skip] %s — %s" % [str(s.get("path", "")), str(s.get("reason", ""))])

	if cleanup:
		_cleanup(ps.project_root(spec))


func _build_system_prompt() -> String:
	var Narcea = load("res://addons/visual_gasic/vg_ai_narcea.gd")
	if Narcea == null:
		return "You are Narcea. Reply with a fenced vg-project-spec JSON block."
	var n = Narcea.new()
	return n.build_context_block(null)


func _load_gemini_key() -> String:
	var from_env := OS.get_environment("NARCEA_GEMINI_KEY").strip_edges()
	if not from_env.is_empty():
		return from_env
	var home := OS.get_environment("HOME")
	if home.is_empty():
		return ""
	for tres_name in ["editor_settings-4.6.tres", "editor_settings-4.5.tres"]:
		var path: String = home + "/.config/godot/" + tres_name
		if not FileAccess.file_exists(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		var rx := RegEx.new()
		rx.compile('visual_gasic/ai/gemini_key\\s*=\\s*"([^"]+)"')
		var m := rx.search(text)
		if m:
			return m.get_string(1)
	return ""


func _golden_path(rel: String) -> String:
	var base: String = get_script().resource_path.get_base_dir()
	return base.path_join("narcea_golden").path_join(rel)


func _cleanup(root: String) -> void:
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


func _has_suffix(arr: Array, suffix: String) -> bool:
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


func _finish() -> void:
	print("")
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
