extends SceneTree
## Headless checks for chat-first build intent detection.

const AIHelp := preload("res://addons/visual_gasic/vg_ai_help.gd")


func _initialize() -> void:
	var panel: Node = AIHelp.new()
	var failures: Array[String] = []

	var cases := [
		["Please make a form with a command button and a label", "form"],
		["Build a runnable mini-project for Pong", "project"],
		["Write the code for btnOK_Click", "code"],
		["What does Dim mean in VG?", ""],
		["Explain this error", ""],
	]
	for c in cases:
		var got: String = panel._detect_build_intent(c[0])
		if got != c[1]:
			failures.append('intent("%s") expected "%s" got "%s"' % [c[0], c[1], got])

	# Empty handler detection
	var src := "\nSub btnClick_Click()\n\nEnd Sub\n"
	var spec := {"controls": [{"type": "Button", "name": "btnClick"}]}
	if not panel._vg_source_has_empty_handlers(src, spec):
		failures.append("empty btnClick_Click should need code")
	var good := "\nSub btnClick_Click()\n    lblCount.Caption = \"x\"\nEnd Sub\n"
	if panel._vg_source_has_empty_handlers(good, spec):
		failures.append("implemented handler should not need follow-up")
	var todo := "\nSub btnClick_Click()\n    ' TODO: implement btnClick_Click\nEnd Sub\n"
	if not panel._vg_source_has_empty_handlers(todo, spec):
		failures.append("TODO stub should need code")

	# Local click-counter synthesis
	var synth_spec := {
		"controls": [
			{"type": "Label", "name": "lblCount", "text": "Clicks: 0"},
			{"type": "Button", "name": "btnClick", "caption": "Click me!"},
		],
	}
	var tmp := OS.get_cache_dir().path_join("vg_synth_test.vg")
	var prompt := "label displays the number of times the command button is clicked"
	if not panel._try_synthesize_click_counter("Form1", synth_spec, tmp, prompt):
		failures.append("click-counter synthesis should succeed")
	else:
		var written := FileAccess.get_file_as_string(tmp)
		if panel._vg_source_has_empty_handlers(written, synth_spec):
			failures.append("synthesized code should implement btnClick_Click")
		if not written.contains("clickCount"):
			failures.append("synthesized code should declare clickCount")
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)

	if not panel._try_synthesize_form_handlers("Form1", synth_spec, tmp, prompt):
		failures.append("form handler dispatcher should succeed")

	var wrapped := panel._build_click_counter_vg("Form1", "btnClickMe", "lblCount", "Clicked 0 times")
	if not wrapped.contains("\"Clicked \" & clickCount & \" times\""):
		failures.append("should wrap embedded number in label text")

	panel.free()
	if failures.is_empty():
		print("PASS chat-first build (%d cases)" % cases.size())
		quit(0)
	else:
		for f in failures:
			push_error("FAIL: " + f)
		quit(1)
