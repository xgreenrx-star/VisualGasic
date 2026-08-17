extends SceneTree
## Multi-scenario Narcea live eval — any provider (Gemini, OpenAI, Claude, Ollama).
##
## Env:
##   NARCEA_LIVE=1              required gate
##   NARCEA_PROVIDER            gemini|openai|claude|ollama (default gemini)
##   NARCEA_MODEL               override model id
##   NARCEA_API_KEY             generic key (else provider-specific env / editor settings)
##   NARCEA_LIVE_SKIP_API=1     replay fixture_response only (no HTTP)
##   NARCEA_SCENARIO              run one scenario id (default: all)
##   NARCEA_LIVE_TIMEOUT          seconds (default 180)

const NarceaRubric := preload("res://addons/visual_gasic/narcea_rubric.gd")
const AIHelp := preload("res://addons/visual_gasic/vg_ai_help.gd")

var _failed := 0
var _passed := 0
var _golden := ""
var _providers = null
var _scenario_idx := 0
var _scenarios: Array = []
var _http: HTTPRequest
var _pending: Dictionary = {}
var _system_prompt := ""


func _initialize() -> void:
	if OS.get_environment("NARCEA_LIVE") != "1":
		printerr("Set NARCEA_LIVE=1 to run live Narcea suite")
		quit(2)
		return

	_golden = get_script().resource_path.get_base_dir().path_join("narcea_golden")
	_providers = load("res://addons/visual_gasic/vg_ai_providers.gd")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(_golden.path_join("scenarios.json")))
	if typeof(catalog) != TYPE_DICTIONARY:
		_fail("load scenarios.json", "invalid")
		_finish()
		return
	_scenarios = catalog.get("scenarios", [])
	var only := OS.get_environment("NARCEA_SCENARIO").strip_edges()
	if not only.is_empty():
		_scenarios = _scenarios.filter(func(s): return str(s.get("id", "")) == only)

	print("=== Narcea Live Suite (%d scenario(s)) ===" % _scenarios.size())
	_system_prompt = _build_system_prompt()
	if _scenarios.is_empty():
		_fail("scenarios", "none matched")
		_finish()
		return
	_http = HTTPRequest.new()
	root.add_child(_http)
	_http.request_completed.connect(_on_http_completed)
	_run_next_scenario()


func _run_next_scenario() -> void:
	if _scenario_idx >= _scenarios.size():
		_finish()
		return
	var sc: Dictionary = _scenarios[_scenario_idx]
	var sid := str(sc.get("id", "?"))
	print("")
	print("--- Scenario: %s ---" % sid)
	if OS.get_environment("NARCEA_LIVE_SKIP_API") == "1":
		var fix_path := _golden.path_join(str(sc.get("fixture_response", "")))
		var response := FileAccess.get_file_as_string(fix_path)
		_expect("[%s] fixture loaded" % sid, not response.is_empty(), fix_path)
		_apply_and_score(sid, sc, response)
		_scenario_idx += 1
		call_deferred("_run_next_scenario")
		return
	_start_live_request(sid, sc)


func _start_live_request(sid: String, sc: Dictionary) -> void:
	var provider_id := OS.get_environment("NARCEA_PROVIDER").strip_edges()
	if provider_id.is_empty():
		provider_id = "gemini"
	var pinfo = _providers.find_provider(provider_id)
	if pinfo == null:
		_fail("[%s] provider" % sid, "unknown %s" % provider_id)
		_scenario_idx += 1
		call_deferred("_run_next_scenario")
		return
	var model := OS.get_environment("NARCEA_MODEL").strip_edges()
	if model.is_empty():
		model = pinfo.default_model
	var api_key := _load_api_key(provider_id)
	if api_key.is_empty() and provider_id != "ollama":
		_fail("[%s] api key" % sid, "set NARCEA_API_KEY or provider key in editor settings")
		_scenario_idx += 1
		call_deferred("_run_next_scenario")
		return

	var prompt_path := _golden.path_join(str(sc.get("prompt_file", "prompt.txt")))
	var user_prompt := FileAccess.get_file_as_string(prompt_path)
	if user_prompt.is_empty():
		user_prompt = "Build a counter form with label and button."
	var panel: Node = AIHelp.new()
	user_prompt = panel._build_hardened_prompt(user_prompt.strip_edges(), str(sc.get("mode", "form")))
	panel.free()

	var req: Dictionary = _providers.build_request_nostream(provider_id, model, _system_prompt, user_prompt, api_key)
	var url: String = _providers.request_url(pinfo, req)
	var headers: PackedStringArray = PackedStringArray(req.get("headers", []))
	_pending = {"sid": sid, "scenario": sc, "provider": provider_id}
	_http.timeout = int(OS.get_environment("NARCEA_LIVE_TIMEOUT").strip_edges()) if not OS.get_environment("NARCEA_LIVE_TIMEOUT").strip_edges().is_empty() else 180
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, str(req.get("body", "")))
	if err != OK:
		_fail("[%s] http" % sid, error_string(err))
		_scenario_idx += 1
		call_deferred("_run_next_scenario")


func _on_http_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var sid := str(_pending.get("sid", ""))
	var sc: Dictionary = _pending.get("scenario", {})
	var provider_id := str(_pending.get("provider", ""))
	_pending = {}
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		_fail("[%s] http response" % sid, "result=%d code=%d" % [result, code])
		_scenario_idx += 1
		call_deferred("_run_next_scenario")
		return
	var text: String = _providers.extract_response_text(provider_id, body.get_string_from_utf8())
	_expect("[%s] model returned text" % sid, text.length() > 40, "len=%d" % text.length())
	print("  (first 300 chars): %s" % text.substr(0, 300))
	_apply_and_score(sid, sc, text)
	_scenario_idx += 1
	call_deferred("_run_next_scenario")


func _apply_and_score(sid: String, sc: Dictionary, response: String) -> void:
	var rubric: Dictionary = NarceaRubric.load_json(_golden.path_join(str(sc.get("rubric", ""))))
	var mode := str(sc.get("mode", "project"))
	if mode == "form":
		_apply_form_path(sid, response, rubric)
	else:
		_apply_project_path(sid, response, rubric)


func _apply_form_path(sid: String, response: String, rubric: Dictionary) -> void:
	var FormSpec = load("res://addons/visual_gasic/vg_ai_form_spec.gd")
	var CodeSpec = load("res://addons/visual_gasic/vg_ai_code_spec.gd")
	var fs = FormSpec.new()
	var cs = CodeSpec.new()
	var form_spec: Dictionary = fs.extract_spec(response)
	if form_spec.is_empty():
		var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
		var ps = ProjectSpec.new()
		var proj: Dictionary = ps.extract_spec(response)
		var forms: Array = proj.get("forms", [])
		if not forms.is_empty() and typeof(forms[0]) == TYPE_DICTIONARY:
			form_spec = forms[0]
	_expect("[%s] extract vg-form-spec" % sid, not form_spec.is_empty())
	if form_spec.is_empty():
		return
	NarceaRubric.score_form_controls(form_spec, rubric, sid, Callable(self, "_rubric_report"))

	var code_spec: Dictionary = cs.extract_spec(response)
	var tmp_vg := OS.get_cache_dir().path_join("narcea_live_%s_Form1.vg" % sid)
	var vg_src := ""
	if not code_spec.is_empty():
		var SafeWrite = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
		var sw = SafeWrite.new()
		sw.set_root("res://")
		cs.apply(code_spec, sw, false)
		for fe in code_spec.get("files", []):
			var fp := str(fe.get("path", ""))
			if fp.ends_with(".vg") and FileAccess.file_exists(fp):
				vg_src = FileAccess.get_file_as_string(fp)
				break
	else:
		var panel: Node = AIHelp.new()
		panel._last_user_prompt = FileAccess.get_file_as_string(_golden.path_join("prompt.txt"))
		panel._finalize_form_handlers("Form1", form_spec, tmp_vg)
		if FileAccess.file_exists(tmp_vg):
			vg_src = FileAccess.get_file_as_string(tmp_vg)
		panel.free()

	_expect("[%s] Form1.vg content" % sid, not vg_src.is_empty())
	if not vg_src.is_empty():
		NarceaRubric.score_vg(vg_src, rubric, sid, Callable(self, "_rubric_report"))
	if FileAccess.file_exists(tmp_vg):
		DirAccess.remove_absolute(tmp_vg)


func _apply_project_path(sid: String, response: String, rubric: Dictionary) -> void:
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var FormSpec = load("res://addons/visual_gasic/vg_ai_form_spec.gd")
	var CodeSpec = load("res://addons/visual_gasic/vg_ai_code_spec.gd")
	var SafeWrite = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	var ps = ProjectSpec.new()
	var fs = FormSpec.new()
	var cs = CodeSpec.new()
	var sw = SafeWrite.new()
	var spec: Dictionary = ps.extract_spec(response)
	_expect("[%s] extract vg-project-spec" % sid, not spec.is_empty())
	if spec.is_empty():
		return
	var want := str(rubric.get("required_project_name", ""))
	if not want.is_empty():
		_expect("[%s] project_name" % sid, str(spec.get("project_name", "")) == want, str(spec.get("project_name", "")))
	var root: String = ps.project_root(spec)
	_cleanup(root)
	var result: Dictionary = ps.apply(spec, {
		"safe_writer": sw,
		"code_spec": cs,
		"form_spec": fs,
		"designer": null,
	})
	_expect("[%s] apply ok" % sid, result.get("ok", false), str(result.get("summary", "")))
	var vg_path: String = root + "Form1.vg"
	var vg_src: String = sw.read(vg_path) if FileAccess.file_exists(vg_path) else ""
	if vg_src.is_empty() and FileAccess.file_exists("res://Form1.vg"):
		vg_src = FileAccess.get_file_as_string("res://Form1.vg")
	_expect("[%s] Form1.vg written" % sid, not vg_src.is_empty())
	if not vg_src.is_empty():
		NarceaRubric.score_vg(vg_src, rubric, sid, Callable(self, "_rubric_report"))
	_cleanup(root)


func _build_system_prompt() -> String:
	var Narcea = load("res://addons/visual_gasic/vg_ai_narcea.gd")
	if Narcea == null:
		return "You are Narcea. Reply with fenced vg-form-spec and vg-code-spec blocks."
	return Narcea.new().build_context_block(null)


func _load_api_key(provider_id: String) -> String:
	var generic := OS.get_environment("NARCEA_API_KEY").strip_edges()
	if not generic.is_empty():
		return generic
	var env_map := {
		"gemini": "NARCEA_GEMINI_KEY",
		"openai": "NARCEA_OPENAI_KEY",
		"claude": "NARCEA_CLAUDE_KEY",
	}
	var env_name: String = env_map.get(provider_id, "")
	if not env_name.is_empty():
		var from_env := OS.get_environment(env_name).strip_edges()
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
		rx.compile('visual_gasic/ai/' + provider_id + '_key\\s*=\\s*"([^"]+)"')
		var m := rx.search(text)
		if m:
			return m.get_string(1)
	return ""


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


func _rubric_report(ok: bool, msg: String) -> void:
	if ok:
		_ok(msg)
	else:
		_fail("rubric", msg)


func _ok(msg: String) -> void:
	_passed += 1
	print("  [PASS] %s" % msg)


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
