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
	var report: String = chain.generate(fixture)
	assert(report.length() > 0, "report should not be empty")
	assert(report.contains("User triggers btnOK.Click"), "report should identify event handler: %s" % report)
	assert(report.contains("MsgBox"), "report should include MsgBox: %s" % report)
	assert(report.contains("Call SaveData()"), "report should include direct call: %s" % report)
	assert(report.contains("Returns True"), "report should include return value: %s" % report)
	print("[PASS] test_vg_causal_chain.gd")
	quit(0)
