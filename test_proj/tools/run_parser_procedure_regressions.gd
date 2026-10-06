extends SceneTree

func _init() -> void:
	var invalid_cases := [
		["duplicated Sub", "Sub _Ready()\nSub _Ready()\nEnd Sub\n", 2],
		["nested Function", "Function Outer() As Integer\nFunction Inner() As Integer\nEnd Function\nEnd Function\n", 2],
		["procedure inside If", "Sub Outer()\nIf True Then\nSub Inner()\nEnd Sub\nEnd If\nEnd Sub\n", 3],
	]
	var failed := false
	for entry in invalid_cases:
		var result: Dictionary = ClassDB.class_call_static("VisualGasicLanguage", "vg_validate_code", entry[1], "res://nested_procedure.vg")
		var diagnosed := false
		for diagnostic in result.get("errors", []):
			if diagnostic.get("line") == entry[2] and str(diagnostic.get("message")).contains("Nested procedure"):
				diagnosed = true
		if result.get("valid", true) or not diagnosed:
			printerr("FAIL: ", entry[0], " must produce a nested-procedure diagnostic at line ", entry[2], ": ", result)
			failed = true
		else:
			print("PASS: parser rejects ", entry[0], " at line ", entry[2])
	var valid := "Sub First()\nPrint 1\nEnd Sub\nFunction Second() As Integer\nSecond = 2\nEnd Function\n"
	var valid_result: Dictionary = ClassDB.class_call_static("VisualGasicLanguage", "vg_validate_code", valid, "res://valid_procedures.vg")
	if not valid_result.get("valid", false):
		printerr("FAIL: separate module procedures must remain valid: ", valid_result)
		failed = true
	else:
		print("PASS: separate module procedures remain valid")
	var script = ClassDB.instantiate("VisualGasicScript")
	script.resource_path = "res://nested_procedure_reload.vg"
	script.source_code = invalid_cases[0][1] + "Function Healthy() As Integer\nHealthy = 12\nEnd Function\n"
	script.reload()
	var has_bad := false
	var has_healthy := false
	for method in script.get_script_method_list():
		has_bad = has_bad or method.get("name") == "_Ready"
		has_healthy = has_healthy or method.get("name") == "Healthy"
	if not script.has_reload_errors() or has_bad or not has_healthy:
		printerr("FAIL: discard malformed procedure while retaining healthy procedures")
		failed = true
	else:
		var node := Node.new()
		node.set_script(script)
		root.add_child(node)
		if node.call("Healthy") != 12:
			printerr("FAIL: healthy procedure must execute after a sibling parse error")
			failed = true
		else:
			print("PASS: malformed procedure cannot execute; healthy sibling remains runnable")
		node.queue_free()
	quit(1 if failed else 0)
