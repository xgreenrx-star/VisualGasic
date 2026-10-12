extends SceneTree

const BEHAVIOR_FIXTURE := "' Whenever Section Fake crystals Becomes 1 OnFake >= <>\nwhenever section First crystals becomes GEM_TARGET OnFirst\nwhenever section Second health below 11 OnSecond\nsub Check()\nif x>=-1 and y<>2 and z<=3 then\nprint \"two  spaces <> >= <=\"\n' If Then Else >= <> keep  two spaces\ndim n as integer = -42\ndim h as integer = &HFF\ndim o as integer = &O10\ndim b as integer = &B1010\nend if\nend sub\nWalkSprite:\nData  8,  8,  0,  2\nData  0,  1,  2,  3\n"
const BEHAVIOR_EXPECTED := "' Whenever Section Fake crystals Becomes 1 OnFake >= <>\nWhenever Section First crystals Becomes GEM_TARGET OnFirst\nWhenever Section Second health Below 11 OnSecond\nSub Check()\n\tIf x >= -1 And y <> 2 And z <= 3 Then\n\t\tPrint \"two  spaces <> >= <=\"\n\t\t' If Then Else >= <> keep  two spaces\n\t\tDim n As integer = -42\n\t\tDim h As integer = &HFF\n\t\tDim o As integer = &O10\n\t\tDim b As integer = &B1010\n\tEnd If\nEnd Sub\nWalkSprite:\n\tData  8,  8,  0,  2\n\tData  0,  1,  2,  3\n"


func _initialize() -> void:
	call_deferred("_run")


static func run_checks(check: Callable, embedded, edit, formatter) -> void:
	var source: String = edit.text
	var original_path: String = embedded._vg_path
	var behavior_formatted: String = formatter.format_text(BEHAVIOR_FIXTURE)
	check.call("behavior save keeps compound comparisons and unary/based literals", behavior_formatted.contains("x >= -1 And y <> 2 And z <= 3") and behavior_formatted.contains("= -42") and behavior_formatted.contains("&HFF") and behavior_formatted.contains("&O10") and behavior_formatted.contains("&B1010"))
	check.call("behavior save keeps string and comment bytes", behavior_formatted.contains("\"two  spaces <> >= <=\"") and behavior_formatted.contains("' If Then Else >= <> keep  two spaces") and behavior_formatted.contains("' Whenever Section Fake crystals Becomes 1 OnFake >= <>"))
	check.call("behavior save keeps DATA padding", behavior_formatted.contains("\n\tData  8,  8,  0,  2\n") and behavior_formatted.contains("\n\tData  0,  1,  2,  3\n"))
	check.call("behavior save does not nest Whenever and indents the procedure", behavior_formatted.contains("\nWhenever Section Second") and behavior_formatted.contains("\nSub Check()\n\tIf ") and behavior_formatted.contains("\n\tEnd If\nEnd Sub\n"))
	check.call("behavior save matches the fixed expectation", behavior_formatted == BEHAVIOR_EXPECTED)
	check.call("behavior save formats idempotently", formatter.format_text(behavior_formatted) == behavior_formatted)
	var behavior_path := "user://behavior_evidence_save.vg"
	embedded._vg_path = behavior_path
	edit.text = BEHAVIOR_FIXTURE
	embedded.save_file()
	var behavior_saved := FileAccess.get_file_as_string(behavior_path)
	check.call("behavior actual save writes the formatted fixture", behavior_saved == BEHAVIOR_EXPECTED and edit.text == BEHAVIOR_EXPECTED)
	check.call("behavior actual save parses", embedded.validate_code())
	embedded.save_file()
	check.call("behavior second actual save is byte-identical", FileAccess.get_file_as_string(behavior_path) == behavior_saved)
	DirAccess.remove_absolute(behavior_path)
	check.call("behavior save removes its temporary file", not FileAccess.file_exists(behavior_path))
	embedded._vg_path = original_path
	edit.text = source
	check.call("behavior save restores the showcase buffer", edit.text == source)


func _run() -> void:
	var expectation_status := "unprotected"
	var Exp = load("res://addons/visual_gasic/vg_expectations.gd")
	if Exp != null:
		var exp = Exp.new()
		exp.load_manifest(ProjectSettings.globalize_path("res://"))
		expectation_status = str(exp.status("res://save_format_scenario.gd"))
	if expectation_status != "accepted" and expectation_status != "unprotected":
		print("[EXPECTATION MODIFIED] save_format_scenario.gd")
		quit(1)
		return
	var embedded = load("res://addons/visual_gasic/vg_embedded_code_editor.gd").new()
	root.add_child(embedded)
	var edit = embedded._code_edit
	var formatter = load("res://addons/visual_gasic/vg_formatter.gd")
	var tally := {"failed": 0, "checks": 0}
	var check := func(label: String, condition: bool) -> void:
		tally["checks"] = int(tally["checks"]) + 1
		if not condition:
			tally["failed"] = int(tally["failed"]) + 1
			push_error(label)
	run_checks(check, embedded, edit, formatter)
	embedded.queue_free()
	if int(tally["failed"]) == 0:
		print("[PASS] save_format_scenario.gd (%d/%d) expectation=%s" % [int(tally["checks"]), int(tally["checks"]), expectation_status])
		quit(0)
	else:
		print("[FAIL] save_format_scenario.gd (%d failures / %d checks) expectation=%s" % [int(tally["failed"]), int(tally["checks"]), expectation_status])
		quit(1)
