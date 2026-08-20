extends SceneTree
## Headless Narcea iterate + truncated-spec tests (no HTTP).
##
## Run:
##   Godot --headless --path projects/vg_narcea_test -s tests/test_narcea_iterate_scaffold.gd

const AIHelp := preload("res://addons/visual_gasic/vg_ai_help.gd")
const PROJECT_ROOT := "res://ai_projects/pacman_iterate_test/"
const ITERATE_PROMPT := (
	"Good job but lets make the maze too. Add special power-ups in the corners."
)

var _failed := 0
var _passed := 0
var _golden := ""


func _initialize() -> void:
	print("=== Narcea Iterate Scaffold (offline) ===")
	_golden = get_script().resource_path.get_base_dir().path_join("narcea_golden")

	_test_truncated_project_spec_fixture()
	_test_iterate_intent_and_hardened_prompt()
	_test_iterate_auto_scaffold_persona_parity()
	_test_maybe_nudge_on_truncated_spec()
	_test_pacman_fixtures_apply()
	_test_spec_validator()
	_test_vg_parse_gate()

	_finish()


func _test_truncated_project_spec_fixture() -> void:
	print("")
	print("--- Truncated vg-project-spec ---")
	var path := _golden.path_join("fixtures/gemini_project_spec_truncated.txt")
	var text := FileAccess.get_file_as_string(path)
	_expect("truncated fixture exists", not text.is_empty(), path)

	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var ps = ProjectSpec.new()
	var spec: Dictionary = ps.extract_spec(text)
	_expect("extract_spec empty on truncated", spec.is_empty())

	var panel: Node = AIHelp.new()
	panel._ensure_form_spec_helper()
	panel._ensure_agent_helpers()
	_expect("response_has_truncated_project_spec", panel._response_has_truncated_project_spec(text))
	panel.free()


func _test_iterate_intent_and_hardened_prompt() -> void:
	print("")
	print("--- Iterate intent + hardened prompt ---")
	var panel: Node = AIHelp.new()
	panel.set("_last_project_root", PROJECT_ROOT)
	panel.set("_last_run_scene", PROJECT_ROOT + "Game.tscn")

	var intent: String = panel._detect_build_intent(ITERATE_PROMPT)
	_expect("iterate intent -> project", intent == "project", "got %s" % intent)

	var hardened: String = panel._build_hardened_prompt(ITERATE_PROMPT, "project")
	_expect("hardened mentions existing root", hardened.find("pacman_iterate_test") >= 0)
	_expect("hardened mentions overwrite", hardened.to_lower().find("existing") >= 0)
	panel.free()


func _test_iterate_auto_scaffold_persona_parity() -> void:
	print("")
	print("--- Persona parity: iterate auto-scaffold ---")
	var turn2 := FileAccess.get_file_as_string(_golden.path_join("fixtures/pacman_maze_response.txt"))
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var ps = ProjectSpec.new()
	var proj_spec: Dictionary = ps.extract_spec(turn2)
	var panel: Node = AIHelp.new()
	panel._ensure_form_spec_helper()
	panel.set("_last_project_root", PROJECT_ROOT)
	panel.set("_build_form_ran_this_turn", false)
	panel.set("_accumulated_response", turn2)

	for persona in ["narcea", "bob", "skippy"]:
		panel.set("_persona_id", persona)
		panel.set("_last_build_intent", panel._detect_build_intent(ITERATE_PROMPT))
		var eligible: bool = panel._iterate_auto_scaffold_eligible(proj_spec)
		_expect("%s iterate auto-scaffold eligible" % persona, eligible)

	panel.free()


func _test_maybe_nudge_on_truncated_spec() -> void:
	print("")
	print("--- Agent nudge on truncated spec ---")
	var truncated := FileAccess.get_file_as_string(_golden.path_join("fixtures/gemini_project_spec_truncated.txt"))
	var panel: Node = AIHelp.new()
	panel._ensure_form_spec_helper()
	panel._ensure_agent_helpers()
	panel.set("_last_project_root", PROJECT_ROOT)
	panel.set("_last_user_prompt", ITERATE_PROMPT)
	panel.set("_last_build_intent", "project")
	panel.set("_accumulated_response", truncated)
	panel.set("_agent_hops", 0)
	panel.set("_max_agent_hops", 4)

	var nudged: bool = panel._maybe_nudge_project_build_continuation({})
	_expect("_maybe_nudge on truncated spec", nudged)
	panel.free()


func _test_pacman_fixtures_apply() -> void:
	print("")
	print("--- Pacman fixtures scaffold ---")
	var turn1 := FileAccess.get_file_as_string(_golden.path_join("fixtures/pacman_create_response.txt"))
	var turn2 := FileAccess.get_file_as_string(_golden.path_join("fixtures/pacman_maze_response.txt"))
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var FormSpec = load("res://addons/visual_gasic/vg_ai_form_spec.gd")
	var CodeSpec = load("res://addons/visual_gasic/vg_ai_code_spec.gd")
	var SafeWrite = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	var ps = ProjectSpec.new()
	var fs = FormSpec.new()
	var cs = CodeSpec.new()
	var sw = SafeWrite.new()

	var spec1: Dictionary = ps.extract_spec(turn1)
	_expect("turn1 spec extracts", not spec1.is_empty())
	var root: String = ps.project_root(spec1)
	_cleanup(root)

	var r1: Dictionary = ps.apply(spec1, {"safe_writer": sw, "code_spec": cs, "form_spec": fs, "designer": null})
	_expect("turn1 apply ok", r1.get("ok", false))
	var vg1 := FileAccess.get_file_as_string(root + "Game.vg")
	_expect("turn1 Game.vg written", vg1.length() > 80)

	var spec2: Dictionary = ps.extract_spec(turn2)
	_expect("turn2 spec extracts", not spec2.is_empty())
	var r2: Dictionary = ps.apply(spec2, {"safe_writer": sw, "code_spec": cs, "form_spec": fs, "designer": null})
	_expect("turn2 apply ok", r2.get("ok", false))
	var vg2 := FileAccess.get_file_as_string(root + "Game.vg")
	_expect("turn2 Game.vg changed", vg2 != vg1)
	_expect("turn2 has maze/wall", vg2.to_lower().find("wall") >= 0 or vg2.find("DrawRect") >= 0)
	_expect("turn2 has power/fright", vg2.to_lower().find("power") >= 0 or vg2.to_lower().find("fright") >= 0)
	_cleanup(root)


func _test_spec_validator() -> void:
	print("")
	print("--- Spec validator ---")
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var ps = ProjectSpec.new()
	var invalid := FileAccess.get_file_as_string(_golden.path_join("fixtures/invalid_project_spec_response.txt"))
	var spec: Dictionary = ps.extract_spec(invalid)
	var val: Dictionary = ps.validate_spec(spec, {})
	_expect("invalid spec extracts", not spec.is_empty())
	_expect("invalid spec fails validation", not val.get("ok", true))
	_expect("invalid spec reports empty files", str(val.get("errors", [])).find("empty") >= 0)


func _test_vg_parse_gate() -> void:
	print("")
	print("--- VG parse gate ---")
	const VgParse := preload("res://addons/visual_gasic/narcea_vg_parse.gd")
	var turn1 := FileAccess.get_file_as_string(_golden.path_join("fixtures/pacman_create_response.txt"))
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var ps = ProjectSpec.new()
	var spec: Dictionary = ps.extract_spec(turn1)
	var root: String = ps.project_root(spec)
	_cleanup(root)
	var FormSpec = load("res://addons/visual_gasic/vg_ai_form_spec.gd")
	var CodeSpec = load("res://addons/visual_gasic/vg_ai_code_spec.gd")
	var SafeWrite = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	ps.apply(spec, {"safe_writer": SafeWrite.new(), "code_spec": CodeSpec.new(), "form_spec": FormSpec.new(), "designer": null})
	var vg_path := VgParse.primary_vg_in_written([], root)
	var chk: Dictionary = VgParse.check_parse(vg_path)
	_expect("pacman turn1 vg parses", chk.get("ok", false), str(chk.get("error", "")))
	_cleanup(root)


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
	print("")
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
