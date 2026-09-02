extends SceneTree

const ChainScript := preload("res://addons/visual_gasic/vg_causal_chain.gd")

func _init() -> void:
	var chain: RefCounted = ChainScript.new()
	var passed := 0

	passed += _run_fixture(chain, "simple_msgbox", _fixture_simple_msgbox(), func(r: String) -> bool:
		return r.contains("User triggers btnOK.Click") and r.contains("MsgBox")
	)

	passed += _run_fixture(chain, "nested_call", _fixture_nested_call(), func(r: String) -> bool:
		return r.contains("Call ValidateForm()") and r.contains("Returns True")
	)

	passed += _run_fixture(chain, "raise_event", _fixture_raise_event(), func(r: String) -> bool:
		return r.contains("RaiseEvent FormSubmitted") and r.contains("Parent scene")
	)

	passed += _run_fixture(chain, "timer_tick", _fixture_timer_tick(), func(r: String) -> bool:
		return r.contains("User triggers tmrMain.Timer") and r.contains("Call UpdateClock()")
	)

	passed += _run_fixture(chain, "form_load", _fixture_form_load(), func(r: String) -> bool:
		return r.contains("Form.Load") and r.contains("Call InitControls()")
	)

	passed += _run_fixture(chain, "multi_handler", _fixture_multi_handler(), func(r: String) -> bool:
		return r.contains("btnSave.Click") and r.contains("btnCancel.Click")
	)

	passed += _run_fixture(chain, "recursive_call", _fixture_recursive_call(), func(r: String) -> bool:
		return r.contains("Call Walk(3)") and r.contains("Call Walk(level - 1)")
	)

	passed += _run_fixture(chain, "narcea_form", _fixture_narcea_form(), func(r: String) -> bool:
		return r.contains("btnSubmit.Click") and r.contains("MsgBox") and r.contains("Call ValidateEmail()")
	)

	if passed == 8:
		print("[PASS] test_vg_causal_chain.gd (8/8 fixtures)")
		quit(0)
	else:
		push_error("test_vg_causal_chain: %d/8 fixtures passed" % passed)
		quit(1)


func _run_fixture(chain: RefCounted, name: String, source: String, check: Callable) -> int:
	var report: String = chain.generate(source)
	if report.is_empty():
		push_error("Fixture %s: empty report" % name)
		return 0
	if not check.call(report):
		push_error("Fixture %s failed:\n%s" % [name, report])
		return 0
	return 1


func _fixture_simple_msgbox() -> String:
	return """
Sub btnOK_Click()
    MsgBox "Hello"
End Sub
"""


func _fixture_nested_call() -> String:
	return """
Sub btnOK_Click()
    Call ValidateForm()
End Sub

Function ValidateForm() As Boolean
    If txtName.Text = "" Then
        MsgBox "Required"
        ValidateForm = False
        Return
    End If
    ValidateForm = True
End Function
"""


func _fixture_raise_event() -> String:
	return """
Sub btnSubmit_Click()
    RaiseEvent FormSubmitted(data)
End Sub
"""


func _fixture_timer_tick() -> String:
	return """
Sub tmrMain_Timer()
    Call UpdateClock()
End Sub

Sub UpdateClock()
    Print "tick"
End Sub
"""


func _fixture_form_load() -> String:
	return """
Sub Form_Load()
    Call InitControls()
End Sub

Sub InitControls()
    Print "ready"
End Sub
"""


func _fixture_multi_handler() -> String:
	return """
Sub btnSave_Click()
    Call SaveData()
End Sub

Sub btnCancel_Click()
    MsgBox "Cancelled"
End Sub

Sub SaveData()
    Print "saved"
End Sub
"""


func _fixture_recursive_call() -> String:
	return """
Sub btnRun_Click()
    Call Walk(3)
End Sub

Sub Walk(level As Long)
    If level <= 0 Then
        Return
    End If
    Call Walk(level - 1)
End Sub
"""


func _fixture_narcea_form() -> String:
	return """
Sub btnSubmit_Click()
    If Call ValidateEmail() Then
        MsgBox "OK"
    End If
End Sub

Function ValidateEmail() As Boolean
    ValidateEmail = True
End Function
"""
