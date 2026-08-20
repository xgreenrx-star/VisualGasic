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
const NarceaVgParse := preload("res://addons/visual_gasic/narcea_vg_parse.gd")
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
var _retry_counts: Dictionary = {}
var _failure_records: Array = []
var _last_response := ""
var _last_sid := ""


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
	call_deferred("_run_next_scenario")


func _run_next_scenario() -> void:
	if _scenario_idx >= _scenarios.size():
		_finish()
		return
	var sc: Dictionary = _scenarios[_scenario_idx]
	var sid := str(sc.get("id", "?"))
	print("")
	print("--- Scenario: %s ---" % sid)
	var turns: Array = sc.get("turns", [])
	if not turns.is_empty():
		_run_multi_turn_scenario(sid, sc, turns)
		return
	if OS.get_environment("NARCEA_LIVE_SKIP_API") == "1":
		var fix_path := _golden.path_join(str(sc.get("fixture_response", "")))
		if fix_path.get_file().is_empty() or not FileAccess.file_exists(fix_path):
			if str(sc.get("fixture_response", "")).is_empty():
				print("  [skip] live-only scenario (no fixture)")
				_scenario_idx += 1
				call_deferred("_run_next_scenario")
				return
			_fail("[%s] fixture" % sid, "no fixture_response for offline replay")
			_scenario_idx += 1
			call_deferred("_run_next_scenario")
			return
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
	_pending = {"sid": sid, "scenario": sc, "provider": provider_id, "req": {
		"url": url, "headers": headers, "body": str(req.get("body", "")),
	}}
	_http.timeout = int(OS.get_environment("NARCEA_LIVE_TIMEOUT").strip_edges()) if not OS.get_environment("NARCEA_LIVE_TIMEOUT").strip_edges().is_empty() else 180
	if not _http.is_inside_tree():
		call_deferred("_start_live_request", sid, sc)
		return
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, str(req.get("body", "")))
	if err != OK:
		_fail("[%s] http" % sid, error_string(err))
		_scenario_idx += 1
		call_deferred("_run_next_scenario")


func _run_multi_turn_scenario(sid: String, sc: Dictionary, turns: Array) -> void:
	var rubric: Dictionary = NarceaRubric.load_json(_golden.path_join(str(sc.get("rubric", ""))))
	var mode := str(sc.get("mode", "project"))
	var vg_before := ""
	for i in turns.size():
		var turn: Dictionary = turns[i] if typeof(turns[i]) == TYPE_DICTIONARY else {}
		var turn_label := "%s turn%d" % [sid, i + 1]
		print("  [%s]" % turn_label)
		var response := ""
		if OS.get_environment("NARCEA_LIVE_SKIP_API") == "1":
			var fix_path := _golden.path_join(str(turn.get("fixture_response", "")))
			if fix_path.get_file().is_empty() or not FileAccess.file_exists(fix_path):
				_fail("[%s] fixture" % turn_label, "missing %s" % fix_path)
				break
			response = FileAccess.get_file_as_string(fix_path)
			_expect("[%s] fixture loaded" % turn_label, not response.is_empty(), fix_path)
		else:
			_fail("[%s] live multi-turn" % turn_label, "set NARCEA_LIVE_SKIP_API=1 or add live HTTP support")
			break
		if response.is_empty():
			break
		_last_sid = turn_label
		_last_response = response
		if mode == "project":
			var vg_after := _apply_project_turn(turn_label, sc, response, rubric, i == turns.size() - 1)
			if i == 0:
				vg_before = vg_after
			elif i == turns.size() - 1:
				NarceaRubric.score_iteration(vg_before, vg_after, rubric, sid, Callable(self, "_rubric_report"))
		else:
			_apply_form_path(turn_label, response, rubric)
	_scenario_idx += 1
	call_deferred("_run_next_scenario")


func _apply_project_turn(label: String, _sc: Dictionary, response: String, rubric: Dictionary, final_turn: bool) -> String:
	var t0 := Time.get_ticks_msec()
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var FormSpec = load("res://addons/visual_gasic/vg_ai_form_spec.gd")
	var CodeSpec = load("res://addons/visual_gasic/vg_ai_code_spec.gd")
	var SafeWrite = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	var ps = ProjectSpec.new()
	var fs = FormSpec.new()
	var cs = CodeSpec.new()
	var sw = SafeWrite.new()
	var spec: Dictionary = ps.extract_spec(response)
	_expect("[%s] extract vg-project-spec" % label, not spec.is_empty())
	if spec.is_empty():
		return ""
	var want := str(rubric.get("required_project_name", ""))
	if not want.is_empty():
		_expect("[%s] project_name" % label, str(spec.get("project_name", "")) == want, str(spec.get("project_name", "")))
	var root: String = ps.project_root(spec)
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root)):
		_cleanup(root)
	var result: Dictionary = ps.apply(spec, {
		"safe_writer": sw,
		"code_spec": cs,
		"form_spec": fs,
		"designer": null,
	})
	print("  (apply took %d ms)" % (Time.get_ticks_msec() - t0))
	_expect("[%s] apply ok" % label, result.get("ok", false), str(result.get("summary", "")))
	var vg_src := ""
	for w in result.get("written", []):
		var wp := str(w)
		if wp.ends_with(".vg"):
			vg_src = sw.read(wp) if FileAccess.file_exists(wp) else FileAccess.get_file_as_string(wp)
			break
	if vg_src.is_empty():
		var fallback := root + "Game.vg"
		if FileAccess.file_exists(fallback):
			vg_src = FileAccess.get_file_as_string(fallback)
	_expect("[%s] .vg written" % label, not vg_src.is_empty(), str(result.get("written", [])))
	if not vg_src.is_empty() and final_turn:
		NarceaRubric.score_vg(vg_src, rubric, label, Callable(self, "_rubric_report"))
	_score_project_post_apply(label, rubric, result, root)
	return vg_src


func _retry_live_request(sid: String, sc: Dictionary, provider_id: String, req_snapshot: Dictionary) -> void:
	if not _http.is_inside_tree():
		call_deferred("_retry_live_request", sid, sc, provider_id, req_snapshot)
		return
	_pending = {"sid": sid, "scenario": sc, "provider": provider_id, "req": req_snapshot}
	var err := _http.request(
		str(req_snapshot.get("url", "")),
		PackedStringArray(req_snapshot.get("headers", [])),
		HTTPClient.METHOD_POST,
		str(req_snapshot.get("body", "")))
	if err != OK:
		_fail("[%s] http retry" % sid, error_string(err))
		_scenario_idx += 1
		call_deferred("_run_next_scenario")


func _on_http_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var sid := str(_pending.get("sid", ""))
	var sc: Dictionary = _pending.get("scenario", {})
	var provider_id := str(_pending.get("provider", ""))
	var req_snapshot: Dictionary = _pending.get("req", {})
	_pending = {}
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		if code in [429, 502, 503] and int(_retry_counts.get(sid, 0)) < 2:
			_retry_counts[sid] = int(_retry_counts.get(sid, 0)) + 1
			print("  [retry] %s HTTP %d — attempt %d" % [sid, code, _retry_counts[sid]])
			call_deferred("_retry_live_request", sid, sc, provider_id, req_snapshot)
			return
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
	_last_sid = sid
	_last_response = response
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
	var t0 := Time.get_ticks_msec()
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
	elif not str(spec.get("project_name", "")).is_empty():
		_ok("[%s] project_name present" % sid)
	var root: String = ps.project_root(spec)
	_cleanup(root)
	var result: Dictionary = ps.apply(spec, {
		"safe_writer": sw,
		"code_spec": cs,
		"form_spec": fs,
		"designer": null,
	})
	print("  (apply took %d ms)" % (Time.get_ticks_msec() - t0))
	_expect("[%s] apply ok" % sid, result.get("ok", false), str(result.get("summary", "")))
	var vg_path := ""
	var vg_src := ""
	for w in result.get("written", []):
		var wp := str(w)
		if wp.ends_with(".vg"):
			vg_path = wp
			vg_src = sw.read(vg_path) if FileAccess.file_exists(vg_path) else FileAccess.get_file_as_string(vg_path)
			break
	if vg_path.is_empty():
		vg_path = root + "Form1.vg"
		vg_src = sw.read(vg_path) if FileAccess.file_exists(vg_path) else ""
	_expect("[%s] .vg written" % sid, not vg_src.is_empty(), str(result.get("written", [])))
	if not vg_src.is_empty():
		NarceaRubric.score_vg(vg_src, rubric, sid, Callable(self, "_rubric_report"))
	_score_project_post_apply(sid, rubric, result, root)
	_cleanup(root)


func _score_project_post_apply(label: String, rubric: Dictionary, result: Dictionary, root: String) -> void:
	if not result.get("ok", false):
		return
	var vg_path := NarceaVgParse.primary_vg_in_written(result.get("written", []), root)
	if FileAccess.file_exists(vg_path):
		NarceaRubric.score_vg_parse(vg_path, rubric, label, Callable(self, "_rubric_report"))
	var ms := str(result.get("main_scene", "")).strip_edges()
	if ms.is_empty():
		ms = root + "Game.tscn"
	elif not ms.begins_with("res://"):
		ms = root + ms
	if FileAccess.file_exists(ms):
		NarceaRubric.score_run_smoke(self, ms, rubric, label, Callable(self, "_rubric_report"))


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
	if not _last_response.is_empty() and not _last_sid.is_empty():
		_failure_records.append({"sid": _last_sid, "label": label, "reason": reason, "response": _last_response})


func _expect(label: String, cond: bool, reason: String = "") -> void:
	if cond:
		_ok(label)
	else:
		_fail(label, reason if not reason.is_empty() else "assertion failed")


func _finish() -> void:
	_record_failures_to_tier_b()
	_append_metrics_row()
	print("")
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _record_failures_to_tier_b() -> void:
	if _failure_records.is_empty():
		return
	var out_dir := _golden.path_join("recorded")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ts := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	for i in _failure_records.size():
		var rec: Dictionary = _failure_records[i]
		var sid := str(rec.get("sid", "scenario"))
		var path := out_dir.path_join("failure_%s_%s_%d_response.txt" % [sid, ts, i])
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(str(rec.get("response", "")))
			f.close()
			print("  [recorded] failure fixture -> %s" % path)


func _append_metrics_row() -> void:
	var metrics_dir := _golden.path_join("metrics")
	DirAccess.make_dir_recursive_absolute(metrics_dir)
	var provider := OS.get_environment("NARCEA_PROVIDER").strip_edges()
	if provider.is_empty():
		provider = "gemini"
	var model := OS.get_environment("NARCEA_MODEL").strip_edges()
	var skip_api := OS.get_environment("NARCEA_LIVE_SKIP_API") == "1"
	var csv_path := metrics_dir.path_join("narcea_suite_runs.csv")
	var header_needed := not FileAccess.file_exists(csv_path)
	var row := "%s,%s,%s,%s,%d,%d,%d,%s\n" % [
		Time.get_datetime_string_from_system(),
		provider,
		model if not model.is_empty() else "-",
		"offline" if skip_api else "live",
		_scenarios.size(),
		_passed,
		_failed,
		OS.get_environment("NARCEA_SCENARIO").strip_edges() if not OS.get_environment("NARCEA_SCENARIO").strip_edges().is_empty() else "all",
	]
	var f := FileAccess.open(csv_path, FileAccess.READ_WRITE if FileAccess.file_exists(csv_path) else FileAccess.WRITE)
	if f:
		if header_needed:
			f.store_string("timestamp,provider,model,mode,scenarios,passed,failed,scenario_filter\n")
		else:
			f.seek_end()
		f.store_string(row)
		f.close()
