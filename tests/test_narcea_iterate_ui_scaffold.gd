extends SceneTree
## Headless UI path — _refresh_build_form_btn → _on_make_project → disk writes.
##
## Exercises the real AIHelp auto-scaffold chain (Skippy persona, iteration turn).
##
## Run:
##   Godot --headless --path projects/vg_narcea_test -s tests/test_narcea_iterate_ui_scaffold.gd

const AIHelp := preload("res://addons/visual_gasic/vg_ai_help.gd")
const PROJECT_ROOT := "res://ai_projects/pacman_iterate_test/"
const CREATE_PROMPT := (
	"make a 2d packman game. The arrow keys will be used to move the player "
	+ "through the pacman maze while the ghosts chase at a slow speed."
)
const ITERATE_PROMPT := (
	"Good job but lets make the maze too. Add special power-ups in the corners."
)

var _failed := 0
var _passed := 0
var _golden := ""
var _panel: Node = null
var _phase := 0
var _deadline_ms := 0
var _vg_before := ""
var _log_text := ""
var _tick := 0
var _saw_scaffold := false


func _initialize() -> void:
	print("=== Narcea Iterate UI Scaffold (offline) ===")
	_golden = get_script().resource_path.get_base_dir().path_join("narcea_golden")
	_cleanup(PROJECT_ROOT)
	_panel = _make_panel()
	_phase = 1
	_deadline_ms = Time.get_ticks_msec() + 15000
	call_deferred("_begin_turn1")


func _make_panel() -> Node:
	var panel: Node = AIHelp.new()
	root.add_child(panel)
	var out := RichTextLabel.new()
	out.bbcode_enabled = true
	out.scroll_active = false
	panel.set("_output", out)
	panel.add_child(out)
	panel.set("_status_label", Label.new())
	var btn := Button.new()
	panel.set("_make_project_btn", btn)
	panel._ensure_form_spec_helper()
	panel._ensure_agent_helpers()
	return panel


func _begin_turn1() -> void:
	print("")
	print("--- UI turn 1: Skippy create ---")
	var turn1 := FileAccess.get_file_as_string(_golden.path_join("fixtures/pacman_create_response.txt"))
	_panel.set("_persona_id", "skippy")
	_panel.set("_last_user_prompt", CREATE_PROMPT)
	_panel.set("_last_build_intent", "project")
	_panel.set("_build_form_ran_this_turn", false)
	_panel.set("_last_send_was_desc_mode", false)
	_panel.set("_accumulated_response", turn1)
	_panel.set("_scaffold_in_progress", false)
	_panel._refresh_build_form_btn()


func _begin_turn2() -> void:
	print("")
	print("--- UI turn 2: Skippy iterate ---")
	var turn2 := FileAccess.get_file_as_string(_golden.path_join("fixtures/pacman_maze_response.txt"))
	_panel.set("_persona_id", "skippy")
	_panel.set("_last_user_prompt", ITERATE_PROMPT)
	_panel.set("_last_build_intent", _panel._detect_build_intent(ITERATE_PROMPT))
	_panel.set("_build_form_ran_this_turn", false)
	_panel.set("_last_send_was_desc_mode", false)
	_panel.set("_accumulated_response", turn2)
	_panel.set("_scaffold_in_progress", false)
	_expect("turn1 left _last_project_root set", str(_panel.get("_last_project_root")).find("pacman_iterate_test") >= 0)
	_panel._refresh_build_form_btn()


func _begin_truncated() -> void:
	print("")
	print("--- UI truncated spec: no scaffold ---")
	_cleanup(PROJECT_ROOT)
	var truncated := FileAccess.get_file_as_string(_golden.path_join("fixtures/gemini_project_spec_truncated.txt"))
	_panel.set("_persona_id", "skippy")
	_panel.set("_last_user_prompt", ITERATE_PROMPT)
	_panel.set("_last_build_intent", "project")
	_panel.set("_build_form_ran_this_turn", false)
	_panel.set("_accumulated_response", truncated)
	_panel.set("_scaffold_in_progress", false)
	_panel._refresh_build_form_btn()


func _begin_invalid_spec() -> void:
	print("")
	print("--- UI invalid spec: validator blocks scaffold ---")
	_cleanup(PROJECT_ROOT)
	var invalid := FileAccess.get_file_as_string(_golden.path_join("fixtures/invalid_project_spec_response.txt"))
	_panel.set("_persona_id", "skippy")
	_panel.set("_last_build_intent", "project")
	_panel.set("_accumulated_response", invalid)
	_panel.set("_scaffold_in_progress", false)
	_panel.set("_ollama_available", false)
	_panel._on_make_project(true)


func _process(_delta: float) -> bool:
	if _phase == 0:
		return false
	_tick += 1
	if bool(_panel.get("_scaffold_in_progress")):
		_saw_scaffold = true
	if Time.get_ticks_msec() > _deadline_ms:
		_fail("phase %d timeout" % _phase, PROJECT_ROOT + "Game.vg")
		_finish()
		return true

	match _phase:
		1:
			if _tick >= 2 and FileAccess.file_exists(PROJECT_ROOT + "Game.vg") and not bool(_panel.get("_scaffold_in_progress")):
				_vg_before = FileAccess.get_file_as_string(PROJECT_ROOT + "Game.vg")
				_log_text = _panel.get("_output").get_parsed_text()
				_expect("turn1 Game.vg written via UI path", _vg_before.length() > 80)
				_expect("turn1 chat mentions scaffolding", _log_text.to_lower().find("scaffold") >= 0)
				_expect("turn1 telemetry line", _log_text.find("📊 Scaffold") >= 0 or _log_text.to_lower().find("scaffold (new)") >= 0)
				_tick = 0
				_saw_scaffold = false
				_phase = 2
				_deadline_ms = Time.get_ticks_msec() + 15000
				call_deferred("_begin_turn2")
		2:
			if _tick >= 2 and not bool(_panel.get("_scaffold_in_progress")):
				var vg2 := FileAccess.get_file_as_string(PROJECT_ROOT + "Game.vg")
				if vg2 != _vg_before:
					_expect("turn2 Game.vg changed via UI path", true)
					_expect("turn2 has maze/power markers", vg2.to_lower().find("wall") >= 0 or vg2.to_lower().find("power") >= 0)
					_tick = 0
					_saw_scaffold = false
					_phase = 3
					_deadline_ms = Time.get_ticks_msec() + 8000
					call_deferred("_begin_truncated")
		3:
			if _tick >= 4 and not bool(_panel.get("_scaffold_in_progress")):
				_expect("truncated did not write Game.vg", not FileAccess.file_exists(PROJECT_ROOT + "Game.vg"))
				_tick = 0
				_phase = 4
				_deadline_ms = Time.get_ticks_msec() + 8000
				call_deferred("_begin_invalid_spec")
		4:
			if _tick >= 3 and not bool(_panel.get("_scaffold_in_progress")):
				_expect("invalid spec did not write Game.vg", not FileAccess.file_exists(PROJECT_ROOT + "Game.vg"))
				_finish()
				return true
	return false


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
	if is_instance_valid(_panel):
		_panel.free()
	_cleanup(PROJECT_ROOT)
	print("")
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
