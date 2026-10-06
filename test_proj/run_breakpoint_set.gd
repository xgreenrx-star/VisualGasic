extends SceneTree
## Headless: setting a VG gutter breakpoint must survive a native leftover clear.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ECE = load("res://addons/visual_gasic/vg_embedded_code_editor.gd")
	if ECE == null:
		print("FAIL: cannot load vg_embedded_code_editor.gd")
		print("RESULTS: 0/1 passed, 1 failed")
		quit(1)
		return
	var ece: Control = ECE.new()
	root.add_child(ece)
	await process_frame
	var vg_edit: CodeEdit = ece.get_code_edit()
	if vg_edit == null:
		print("FAIL: no CodeEdit")
		print("RESULTS: 0/1 passed, 1 failed")
		quit(1)
		return
	vg_edit.text = "Sub Foo()\n\tPrint(1)\nEnd Sub\n"
	ece.set("_vg_path", "res://scripts/Play.vg")

	var native := CodeEdit.new()
	native.text = vg_edit.text
	root.add_child(native)
	native.set_line_as_breakpoint(1, true)

	vg_edit.set_line_as_breakpoint(1, true)
	var ok := true
	if not vg_edit.is_line_breakpointed(1):
		print("FAIL: CodeEdit refused the gutter breakpoint")
		ok = false
	else:
		print("PASS: VG gutter accepted breakpoint on line 2")

	if ece.has_method("set_stored_breakpoint"):
		ece.set_stored_breakpoint("res://scripts/Play.vg", 1, true)
	var bps: Dictionary = ece.get_all_debug_breakpoints()
	var lines: Array = bps.get("res://scripts/Play.vg", [])
	if 2 not in lines:
		print("FAIL: get_all_debug_breakpoints missing line 2, got ", bps)
		ok = false
	else:
		print("PASS: stash kept 1-based line 2")

	# Simulate leftover Script-tab marker being cleared (empty VG snapshot apply).
	for line_idx in native.get_breakpointed_lines():
		native.set_line_as_breakpoint(int(line_idx), false)
	if vg_edit.is_line_breakpointed(1):
		print("PASS: clearing native leftover did not clear VG gutter")
	else:
		print("FAIL: VG gutter was cleared when native leftover was removed")
		ok = false

	ece.queue_free()
	native.queue_free()
	if ok:
		print("RESULTS: 3/3 passed, 0 failed")
		quit(0)
	else:
		print("RESULTS: 0/3 passed, 3 failed")
		quit(1)
