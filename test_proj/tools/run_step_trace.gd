extends SceneTree
## Drive VisualGasic step-into through the bytecode VM and require one pause per source line.

func _init() -> void:
	var script_path := "res://test_suite/test_step_lines.vg"
	var script: VisualGasicScript = load(script_path)
	if script == null:
		printerr("FAIL: could not load ", script_path)
		quit(1)
		return
	var node := Node.new()
	node.set_script(script)
	root.add_child(node)
	ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_debug_begin_autostep", 40)
	node.call("Main")
	var trace: PackedInt32Array = ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_debug_get_trace")
	var expect := PackedInt32Array([11, 12, 13, 5, 6, 7, 8, 14, 15, 16, 17])
	print("STEP TRACE (", trace.size(), "): ", trace)
	var failed := false
	if trace != expect:
		printerr("FAIL: trace ", trace, " != ", expect)
		failed = true
	var prev := -1
	for i in trace.size():
		if int(trace[i]) == prev:
			printerr("FAIL: consecutive pause on line ", prev)
			failed = true
		prev = int(trace[i])
	if failed:
		quit(1)
		return
	print("PASS: step-into one pause per source line, including stepping into Leaf")

	var loop_script: VisualGasicScript = load("res://test_suite/test_step_loop.vg")
	if loop_script == null:
		printerr("FAIL: could not load loop script")
		quit(1)
		return
	var loop_node := Node.new()
	loop_node.set_script(loop_script)
	root.add_child(loop_node)
	ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_debug_begin_autostep", 40)
	loop_node.call("Main")
	var loop_trace: PackedInt32Array = ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_debug_get_trace")
	print("LOOP TRACE: ", loop_trace)
	var body_hits := 0
	for i in loop_trace.size():
		if int(loop_trace[i]) == 8:
			body_hits += 1
	if body_hits != 3:
		printerr("FAIL: loop body line 8 paused ", body_hits, " times, expected 3")
		quit(1)
		return
	print("PASS: loop body paused once per iteration")

	var big: Array = []
	for i in 2000:
		big.append(i)
	var preview = ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_debug_preview_value", big)
	print("PREVIEW: ", preview)
	if typeof(preview) != TYPE_STRING or not str(preview).begins_with("[2000"):
		printerr("FAIL: debugger preview expanded a large array: ", preview)
		quit(1)
		return
	var node_preview = ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_debug_preview_value", loop_node)
	print("NODE PREVIEW: ", node_preview)
	if typeof(node_preview) != TYPE_STRING or not str(node_preview).begins_with("<"):
		printerr("FAIL: debugger preview exposed a live object: ", node_preview)
		quit(1)
		return
	print("PASS: debugger values are shallow")
	quit(0)
