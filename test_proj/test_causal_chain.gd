extends SceneTree

func _init() -> void:
	var Chain = load("res://addons/visual_gasic/vg_causal_chain.gd")
	assert(Chain != null, "vg_causal_chain.gd missing")
	var chain = Chain.new()

	var fixture := """
Sub btnOK_Click()
    If txtName.Text = \"\" Then
        MsgBox \"Required\"
    End If
    Call SaveData()
End Sub

Function SaveData() As Boolean
    SaveData = True
End Function
"""
	var report = str(chain.generate(fixture))
	assert(report.length() > 0, "report should not be empty")
	assert(report.contains("User triggers btnOK.Click"), "missing entry-point header:\n%s" % report)
	assert(report.contains("MsgBox"), "missing MsgBox behavior:\n%s" % report)
	assert(report.contains("Call SaveData()"), "missing call detail:\n%s" % report)
	assert(report.contains("Returns True"), "missing return detail:\n%s" % report)
	print("[PASS] test_causal_chain.gd")
	quit(0)
