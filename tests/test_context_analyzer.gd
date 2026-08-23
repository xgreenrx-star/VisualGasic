@tool
extends SceneTree
## Headless tests: VG Context Rail analyzer (region, procedure, outline, events).
## Run: scripts/run_sprite_data_tests.sh

const Analyzer := preload("res://addons/visual_gasic/vg_context_analyzer.gd")

var _failed := 0
var _passed := 0

const FIXTURE := """' @VG-Summary Validates input and saves
Sub btnOK_Click()
    If txtName.Text = "" Then
        MsgBox "Required"
    End If
    Call SaveData()
End Sub

Function SaveData() As Boolean
    SaveData = True
End Function

PlayerSprite:
Data 4, 4, 0, 0
Data 0, 1, 1, 0
Data 0, 1, 2, 1
Data 0, 0, 1, 0
Data 0, 0, 0, 0

NoteData:
Data \"C4\", 261.63
"""


func _init() -> void:
	print("=== context_analyzer headless tests ===")
	print("")
	_test_procedure_region()
	_test_event_handler()
	_test_sprite_region()
	_test_outline()
	_test_summary()
	_finish()


func _test_procedure_region() -> void:
	print("-- procedure at caret --")
	var ctx := Analyzer.analyze(FIXTURE, 2)
	_check("inside procedure", not ctx.get("procedure", {}).is_empty())
	var proc: Dictionary = ctx.get("procedure", {})
	_check("handler name", proc.get("name", "") == "btnOK_Click")
	_check("region title mentions Sub", str(ctx.get("region_title", "")).contains("Sub"))
	_check("line range detail", str(ctx.get("region_detail", "")).contains("Lines"))


func _test_event_handler() -> void:
	print("-- event handler chain roots --")
	var ctx := Analyzer.analyze(FIXTURE, 2)
	_check("is event handler", ctx.get("is_event_handler", false))
	_check("chain root", ctx.get("chain_roots", []) == ["btnOK_Click"])
	_check("event label mentions click", str(ctx.get("event_label", "")).to_lower().contains("click"))


func _test_sprite_region() -> void:
	print("-- sprite block region --")
	var ctx := Analyzer.analyze(FIXTURE, 14)
	_check("sprite dict populated", not ctx.get("sprite", {}).is_empty())
	_check("sprite title", str(ctx.get("region_title", "")).contains("PlayerSprite"))
	_check("4x4 in title", str(ctx.get("region_title", "")).contains("4×4") or str(ctx.get("region_title", "")).contains("4x4"))


func _test_outline() -> void:
	print("-- outline entries --")
	var ctx := Analyzer.analyze(FIXTURE, 0)
	var outline: Array = ctx.get("outline", [])
	_check("outline has landmarks", outline.size() >= 2)
	var labels: Array = []
	for e in outline:
		labels.append(e.get("label", ""))
	_check("outline has PlayerSprite", labels.has("PlayerSprite"))
	_check("outline has NoteData", labels.has("NoteData"))
	_check("outline skips Sub entries", not labels.any(func(l): return str(l).begins_with("Sub ")))
	_check("outline skips Function entries", not labels.any(func(l): return str(l).begins_with("Function ")))


func _test_summary() -> void:
	print("-- @VG-Summary / comment summary --")
	var ctx := Analyzer.analyze(FIXTURE, 2)
	var proc: Dictionary = ctx.get("procedure", {})
	_check("summary from @VG-Summary", str(proc.get("summary", "")).contains("Validates"))


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  OK  ", label)
	else:
		_failed += 1
		print("  FAIL", label)


func _finish() -> void:
	print("")
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
