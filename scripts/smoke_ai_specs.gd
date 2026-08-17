extends SceneTree

func _initialize() -> void:
	print("--- vg_ai smoke test ---")
	var sw_script := load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	var sw = sw_script.new()
	print("safe_writer root: ", sw.get_root())

	var bad: Array = sw.is_safe("res://addons/visual_gasic/evil.gd")
	print("forbidden glob check: ok=", bad[0], " reason=", bad[1])
	assert(bad[0] == false, "should refuse addons/visual_gasic")

	var traversal: Array = sw.is_safe("res://../../etc/passwd")
	print("traversal check: ok=", traversal[0], " reason=", traversal[1])
	assert(traversal[0] == false, "should refuse ..")

	var good: Array = sw.is_safe("res://ai_projects/Test/foo.vg")
	print("good path check: ok=", good[0], " reason=", good[1])
	assert(good[0] == true)

	# Code-spec round-trip
	var cs_script := load("res://addons/visual_gasic/vg_ai_code_spec.gd")
	var cs = cs_script.new()
	var reply := """Sure, here's the code:
```vg-code-spec
{
  "files": [
    {"path": "res://ai_projects/Smoke/hello.vg", "source": "Sub Main()\\n    Print \\"hi\\"\\nEnd Sub\\n"}
  ]
}
```
"""
	var spec = cs.extract_spec(reply)
	print("spec keys: ", spec.keys())
	assert(spec.has("files"))

	var plan = cs.plan(spec, sw)
	print("plan size: ", plan.size())
	assert(plan.size() == 1)
	print("plan[0]: action=", plan[0].action, " safe=", plan[0].safe)

	var result = cs.apply(spec, sw, false)
	print("apply: ", result.summary)
	assert(result.ok)

	# Project-spec
	var ps_script := load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var ps = ps_script.new()
	var preply := """```vg-project-spec
{
  "project_name": "PongSmoke",
  "main_scene": "frmGame.tscn",
  "files": [
    {"path": "helpers.vg", "source": "Sub Helper()\\n    Print \\"ok\\"\\nEnd Sub\\n"}
  ]
}
```"""
	var pspec = ps.extract_spec(preply)
	print("project spec keys: ", pspec.keys())
	print("project root: ", ps.project_root(pspec))
	var proot: String = ps.project_root(pspec)
	sw.set_root(proot)
	assert(ps.rebase_path("helpers.vg", proot, sw) == proot + "helpers.vg")
	assert(ps.rebase_path("res://MainForm.vg", proot, sw) == proot + "MainForm.vg")
	var skip_spec := {
		"forms": [{"form_name": "CounterForm", "controls": []}],
		"files": [{"path": "res://CounterForm.tscn", "source": "[ext_resource path=\"res://CounterForm.vg\" id=\"1\"]"}],
	}
	assert(ps._skip_scaffold_file(proot + "CounterForm.tscn", skip_spec, PackedStringArray(["counterform"])))
	assert(not ps._skip_scaffold_file(proot + "CounterForm.tscn", skip_spec))
	assert(not ps._skip_scaffold_file(proot + "helpers.vg", skip_spec))
	var gemini_path := ProjectSettings.globalize_path("res://").path_join("tests/narcea_golden/fixtures/gemini_tipcalc_response.txt")
	var gemini_fixture := FileAccess.get_file_as_string(gemini_path) if FileAccess.file_exists(gemini_path) else ""
	if not gemini_fixture.is_empty():
		var gspec: Dictionary = ps.extract_spec(gemini_fixture)
		assert(not gspec.is_empty())
		assert(str(gspec.get("project_name", "")) == "TipCalc")
		assert(not str((gspec.get("files", []) as Array)[0].get("source", "")).is_empty())
	var rebased: String = ps._rebase_tscn_script_paths(
		"[ext_resource type=\"Script\" path=\"res://MainForm.vg\" id=\"1\"]",
		proot)
	assert(rebased.find("res://ai_projects/PongSmoke/MainForm.vg") != -1)
	var presult = ps.apply(pspec, {"safe_writer": sw, "code_spec": cs, "form_spec": null, "designer": null})
	print("project apply: ", presult.summary)
	print("written: ", presult.written)

	# Reset writer for code-spec lint check
	sw.set_root("res://")
	var bad_vg := """```vg-code-spec
{"files":[{"path":"res://ai_projects/Bad/x.vg","source":"Sub Foo()\\nLet x = 1"}]}
```"""
	var bad_spec = cs.extract_spec(bad_vg)
	var bad_plan = cs.plan(bad_spec, sw)
	print("lint findings on incomplete sub: ", bad_plan[0].lint.size())

	print("--- ALL SMOKE TESTS PASSED ---")
	quit(0)
