@tool
extends SceneTree
## Headless tests: vg_context_caret_context.gd (Connect, symbol, event parts).

const CaretContext := preload("res://addons/visual_gasic/vg_context_caret_context.gd")

var _failed := 0
var _passed := 0

const FIXTURE := """Dim btnOK As Button
Dim score As Integer

Sub Form_Load()
    Connect btnOK, \"Click\", \"btnOK_Click\"
End Sub

Sub btnOK_Click()
    score = score + 1
End Sub
"""


func _init() -> void:
	print("=== context_caret_context headless tests ===")
	print("")
	_test_connect_line()
	_test_event_handler_parts()
	_test_dim_variable()
	_test_control_prefix()
	_finish()


func _test_connect_line() -> void:
	print("-- connect_at_line --")
	var c := CaretContext.connect_at_line(FIXTURE, 4)
	_check("resolves connect", not c.is_empty())
	_check("node btnOK", c.get("node", "") == "btnOK")
	_check("signal Click", c.get("signal", "") == "Click")
	_check("handler", c.get("handler", "") == "btnOK_Click")


func _test_event_handler_parts() -> void:
	print("-- event_handler_parts --")
	var e := CaretContext.event_handler_parts("btnOK_Click")
	_check("control", e.get("control", "") == "btnOK")
	_check("event Click", e.get("event", "") == "Click")


func _test_dim_variable() -> void:
	print("-- member dim variable --")
	var m := CaretContext.member_at_caret(FIXTURE, 8, 5)
	_check("score name", m.get("name", "") == "score")
	_check("integer type", str(m.get("type_hint", "")).to_lower() == "integer")


func _test_control_prefix() -> void:
	print("-- control prefix --")
	var m := CaretContext.member_at_caret("btnOK.Caption = \"OK\"\n", 0, 2)
	_check("btnOK control", m.get("name", "") == "btnOK")
	_check("kind control", m.get("kind", "") == "control")
	_check("has Caption prop", m.get("properties", PackedStringArray()).has("Caption"))


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
