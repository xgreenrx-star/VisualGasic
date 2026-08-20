extends SceneTree
## Live Gemini — Asteroids scaffold then UFO + hyperspace iteration (video demo).
##
## Prompts (single source of truth):
##   tests/narcea_golden/prompts/asteroids_create.txt
##   tests/narcea_golden/prompts/asteroids_iterate.txt
##
## Env:
##   NARCEA_LIVE=1           — required gate for HTTP calls
##   NARCEA_GEMINI_KEY       — optional override (else EditorSettings)
##   NARCEA_GEMINI_MODEL     — default gemini-2.0-flash

const AIHelp := preload("res://addons/visual_gasic/vg_ai_help.gd")
const DEFAULT_MODEL := "gemini-2.0-flash"
const PROJECT_NAME := "asteroids_demo"
const ROOT := "res://ai_projects/%s/" % PROJECT_NAME
const TIMEOUT_SEC := 180.0

var _golden_dir := ""
var _prompt_create := ""
var _prompt_iterate := ""

var _failed := 0
var _passed := 0
var _http: HTTPRequest
var _api_key := ""
var _model := DEFAULT_MODEL
var _phase := 0
var _deadline_ms := 0
var _game_vg_before := ""


func _initialize() -> void:
	_golden_dir = get_script().resource_path.get_base_dir().path_join("narcea_golden")
	_prompt_create = _read_prompt("prompts/asteroids_create.txt")
	_prompt_iterate = _read_prompt("prompts/asteroids_iterate.txt")
	print("=== Narcea Live Asteroids Iterate ===")
	_test_offline_intent()

	if OS.get_environment("NARCEA_LIVE") != "1":
		print("(Set NARCEA_LIVE=1 to run live Gemini HTTP calls)")
		_finish()
		return

	_api_key = _load_gemini_key()
	if _api_key.is_empty():
		printerr("No Gemini API key")
		quit(2)
		return

	_model = OS.get_environment("NARCEA_GEMINI_MODEL").strip_edges()
	if _model.is_empty():
		_model = DEFAULT_MODEL
	print("Model: %s" % _model)

	_cleanup(ROOT)
	_http = HTTPRequest.new()
	root.add_child(_http)
	_http.request_completed.connect(_on_http_completed)
	_http.timeout = int(TIMEOUT_SEC)

	print("")
	print("--- Turn 1: create asteroids ---")
	call_deferred("_start_gemini", _hardened_create(_prompt_create))
	_deadline_ms = Time.get_ticks_msec() + int(TIMEOUT_SEC * 1000.0)
	_phase = 1


func _read_prompt(rel: String) -> String:
	var path := _golden_dir.path_join(rel)
	if not FileAccess.file_exists(path):
		push_error("Missing prompt file: %s" % path)
		return ""
	return FileAccess.get_file_as_string(path).strip_edges()


func _process(_delta: float) -> bool:
	if _phase == 0:
		return false
	if Time.get_ticks_msec() > _deadline_ms:
		_fail("HTTP timeout", "phase %d" % _phase)
		_finish()
		return true
	return false


func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _phase == 0:
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("HTTP result phase %d" % _phase, str(result))
		_finish()
		return
	if response_code != 200:
		_fail("HTTP status phase %d" % _phase, "%d — %s" % [response_code, body.get_string_from_utf8().substr(0, 400)])
		_finish()
		return

	var text := _extract_gemini_text(body.get_string_from_utf8())
	_expect("phase %d Gemini text" % _phase, text.length() > 100, "len=%d" % text.length())
	print("  response preview: %s…" % text.substr(0, 120).replace("\n", " "))

	if _phase == 1:
		_scaffold(text, "turn1")
		var vg_path := ROOT + "Game.vg"
		if not FileAccess.file_exists(vg_path):
			_fail("turn1 Game.vg exists", vg_path)
			_finish()
			return
		_game_vg_before = FileAccess.get_file_as_string(vg_path)
		_expect("turn1 Game.vg non-empty", _game_vg_before.length() > 200, "len=%d" % _game_vg_before.length())
		print("")
		print("--- Turn 2: UFO + hyperspace ---")
		_start_gemini(_hardened_iterate(_prompt_iterate))
		_deadline_ms = Time.get_ticks_msec() + int(TIMEOUT_SEC * 1000.0)
		_phase = 2
		return

	if _phase == 2:
		var spec2 := _extract_spec(text)
		if spec2.is_empty():
			_fail("turn2 extract_spec", "empty — response may be truncated")
			if text.find("```vg-project-spec") >= 0:
				print("  hint: partial vg-project-spec fence present")
			_finish()
			return
		_scaffold(text, "turn2")
		var vg_after := FileAccess.get_file_as_string(ROOT + "Game.vg")
		_expect("turn2 Game.vg changed", vg_after != _game_vg_before, "file identical to turn1")
		var low := vg_after.to_lower()
		var feature_hits := 0
		for kw in ["ufo", "hyperspace", "shift", "cooldown", "enemy"]:
			if low.find(kw) >= 0:
				feature_hits += 1
		_expect("turn2 UFO/hyperspace keywords", feature_hits >= 2, "hits=%d body_len=%d" % [feature_hits, vg_after.length()])
		_cleanup(ROOT)
		_finish()


func _start_gemini(prompt: String) -> void:
	var system := _build_system_prompt()
	var Providers = load("res://addons/visual_gasic/vg_ai_providers.gd")
	var req: Dictionary = Providers.build_request("gemini", _model, system, [], prompt, _api_key)
	var body_str: String = req.get("body", "")
	var path: String = str(req.get("path", "")).replace(":streamGenerateContent?alt=sse", ":generateContent?")
	var url: String = "https://generativelanguage.googleapis.com" + path
	var err := _http.request(url, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body_str)
	if err != OK:
		_fail("HTTP request", error_string(err))
		_finish()


func _test_offline_intent() -> void:
	print("")
	print("--- Offline: iterate intent detection ---")
	var panel: Node = AIHelp.new()
	panel.set("_last_project_root", ROOT)
	panel.set("_last_run_scene", ROOT + "Game.tscn")
	var intent1: String = panel._detect_build_intent(_prompt_create)
	_expect("create prompt -> project", intent1 == "project", "got %s" % intent1)
	var intent2: String = panel._detect_build_intent(_prompt_iterate)
	_expect("iterate prompt -> project", intent2 == "project", "got %s" % intent2)
	_expect("prompt_iterates_project", panel._prompt_iterates_project(_prompt_iterate))
	panel.set("_last_project_root", "")
	panel.set("_last_run_scene", "")
	# Iterate prompt says "Update the existing … project" — may still classify as project
	# even without _last_project_root; auto-scaffold eligibility is gated elsewhere.
	var intent3: String = panel._detect_build_intent(_prompt_iterate)
	_expect("iterate prompt build intent", intent3 == "project", "got %s" % intent3)
	panel.free()


func _hardened_create(desc: String) -> String:
	return (
		"Scaffold a small runnable project per this description.\n\n"
		+ "Description: " + desc + "\n\n"
		+ "Reply with: (a) one short sentence of context, then (b) a fenced ```vg-project-spec``` JSON block. "
		+ "Set main_scene. Use project_name \"%s\" and subdir \"ai_projects\". "
		+ "files[] must include Game.tscn (Node2D + Game.vg script) and FULL Game.vg source "
		+ "with _Ready/_Process/_Draw. Keep ≤ 6 files. "
		+ "Do not include any other fenced code blocks."
	) % PROJECT_NAME


func _hardened_iterate(desc: String) -> String:
	return (
		"Update the EXISTING AI-scaffolded project per this description.\n\n"
		+ "Existing project root: %s\n" % ROOT
		+ "Keep the same project_name/subdir so files overwrite in place.\n\n"
		+ "Description: " + desc + "\n\n"
		+ "Reply with: (a) one short sentence, then (b) a COMPLETE fenced ```vg-project-spec``` JSON block. "
		+ "Include files[] with the FULL updated Game.vg (UFO enemy, Shift hyperspace with cooldown). "
		+ "Use project_name \"%s\" and main_scene %sGame.tscn. "
		+ "Do not include any other fenced code blocks."
	) % [PROJECT_NAME, ROOT]


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


func _extract_spec(response: String) -> Dictionary:
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	if ProjectSpec == null:
		return {}
	var ps = ProjectSpec.new()
	return ps.extract_spec(response)


func _scaffold(response: String, label: String) -> void:
	var spec := _extract_spec(response)
	if spec.is_empty():
		_fail("[%s] extract_spec" % label, "empty")
		return
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var FormSpec = load("res://addons/visual_gasic/vg_ai_form_spec.gd")
	var CodeSpec = load("res://addons/visual_gasic/vg_ai_code_spec.gd")
	var SafeWrite = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	var ps = ProjectSpec.new()
	var result: Dictionary = ps.apply(spec, {
		"safe_writer": SafeWrite.new(),
		"code_spec": CodeSpec.new(),
		"form_spec": FormSpec.new(),
		"designer": null,
	})
	const ProjectSynth = preload("res://addons/visual_gasic/vg_ai_project_synth.gd")
	ProjectSynth.finalize_project(spec, ps.project_root(spec), _prompt_create if label == "turn1" else _prompt_iterate)
	_expect("[%s] apply ok" % label, result.get("ok", false), str(result.get("summary", "")))
	print("  written: %s" % str(result.get("written", [])))


func _build_system_prompt() -> String:
	var Narcea = load("res://addons/visual_gasic/vg_ai_narcea.gd")
	if Narcea == null:
		return "Reply with a complete fenced vg-project-spec JSON block."
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
	_phase = 0
	print("")
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
