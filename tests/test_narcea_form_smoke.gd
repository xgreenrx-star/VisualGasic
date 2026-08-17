extends SceneTree
## Headless smoke — chat-first form path: spec extract → synthesis → rubric.
## Run: Godot --headless --path projects/vg_narcea_test -s tests/test_narcea_form_smoke.gd

const AIHelp := preload("res://addons/visual_gasic/vg_ai_help.gd")
const NarceaRubric := preload("res://addons/visual_gasic/narcea_rubric.gd")

var _failed := 0
var _passed := 0


func _initialize() -> void:
	print("=== Narcea Form Smoke (chat-first path) ===")
	var golden := _golden_root()
	var response := FileAccess.get_file_as_string(golden.path_join("fixtures/golden_counter_response.txt"))
	if response.is_empty():
		_fail("load fixture", "missing golden_counter_response.txt")
		_finish()
		return

	var FormSpec = load("res://addons/visual_gasic/vg_ai_form_spec.gd")
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var fs = FormSpec.new()
	var ps = ProjectSpec.new()
	var form_spec: Dictionary = fs.extract_spec(response)
	if form_spec.is_empty():
		var proj: Dictionary = ps.extract_spec(response)
		var forms: Array = proj.get("forms", [])
		if not forms.is_empty() and typeof(forms[0]) == TYPE_DICTIONARY:
			form_spec = forms[0]
	_expect("extract form spec from fixture", not form_spec.is_empty())

	var panel: Node = AIHelp.new()
	panel._last_user_prompt = FileAccess.get_file_as_string(golden.path_join("prompt.txt"))
	var tmp_vg := OS.get_cache_dir().path_join("narcea_form_smoke_Form1.vg")
	var note: String = panel._finalize_form_handlers("Form1", form_spec, tmp_vg)
	_expect("finalize handlers returns note", not note.is_empty())
	var vg_src := FileAccess.get_file_as_string(tmp_vg)
	_expect("synthesized Form1.vg exists", not vg_src.is_empty())
	var rubric: Dictionary = NarceaRubric.load_json(golden.path_join("rubrics/counter_form.json"))
	NarceaRubric.score_form_controls(form_spec, rubric, "smoke", Callable(self, "_rubric_report"))
	NarceaRubric.score_vg(vg_src, rubric, "smoke", Callable(self, "_rubric_report"))
	panel.free()
	if FileAccess.file_exists(tmp_vg):
		DirAccess.remove_absolute(tmp_vg)
	_finish()


func _golden_root() -> String:
	return get_script().resource_path.get_base_dir().path_join("narcea_golden")


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


func _expect(label: String, cond: bool) -> void:
	if cond:
		_ok(label)
	else:
		_fail(label, "assertion failed")


func _finish() -> void:
	print("")
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
