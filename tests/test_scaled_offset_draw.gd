extends SceneTree

const SOURCE := """
Dim offsets(3) As Long
Dim ready As Boolean
Dim checksum As Long
Dim emptyChecksum As Long
Dim emptyValid As Boolean
Dim rangeError As Boolean
Dim lastI As Long
Dim lastX As Double
Dim lastY As Double
Dim divisor As Long = 10
Const CELL As Long = 8

Sub _Ready()
	offsets(0) = -19
	offsets(1) = 0
	offsets(2) = 17
	offsets(3) = 7999
End Sub

Sub _Draw()
	If ready Then Exit Sub
	emptyChecksum = Render(0)
	emptyValid = emptyChecksum = 5 And lastI = 0 And lastX = 42.0 And lastY = 43.0
	If emptyValid Then
		Print "PASS: empty draw preserves locals"
	Else
		Print "FAIL: empty draw locals"
	End If
	checksum = Render(4)
	Try
		Render(5)
	Catch ex
		rangeError = ex.Number = 9
	End Try
	ready = True
End Sub

Function Render(ByVal count As Long) As Long
	Dim i As Long
	Dim x As Double = 42.0
	Dim y As Double = 43.0
	Dim cs As Long = 5
	For i = 0 To count - 1 Step 1
		x = CDbl(offsets(i)) / 10.0
		y = CDbl((i * 7) Mod 40) * CDbl(CELL)
		DrawRect x, y, CDbl(CELL), CDbl(CELL), Color(0.2, 0.4, 0.9, 1.0), True
		cs = cs + (offsets(i) \\ 10) + CLng(y) + CELL
	Next i
	lastI = i
	lastX = x
	lastY = y
	Render = cs
End Function
"""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var variants: Array[Dictionary] = [
		{"name": "scaled integer offsets", "source": SOURCE, "fused": true, "checksum": 1172, "x": 799.9},
		{"name": "legacy unscaled offsets", "source": SOURCE.replace("CDbl(offsets(i)) / 10.0", "offsets(i)").replace("(offsets(i) \\ 10)", "CLng(x)"), "fused": true, "checksum": 8370, "x": 7999.0},
		{"name": "different checksum divisor", "source": SOURCE.replace("(offsets(i) \\ 10)", "(offsets(i) \\ 11)"), "fused": false, "checksum": 1100, "x": 799.9},
		{"name": "variable position divisor", "source": SOURCE.replace("/ 10.0", "/ divisor"), "fused": false, "checksum": 1172, "x": 799.9},
		{"name": "floating offset array", "source": SOURCE.replace("offsets(3) As Long", "offsets(3) As Double"), "fused": false, "checksum": 1172, "x": 799.9},
	]
	var failures := 0
	var force_ast := OS.get_environment("VG_FORCE_AST") == "1"
	for variant in variants:
		var script: Script = ClassDB.instantiate("VisualGasicScript")
		script.resource_path = "res://scaled_offset_" + str(variants.find(variant)) + ".vg"
		script.source_code = variant["source"]
		if script.reload() != OK:
			printerr("FAIL: cannot compile ", variant["name"])
			failures += 1
			continue
		var dump: Dictionary = script.call("debug_dump_bytecode", "Render")
		var fused := false
		var decoded_after_fusion := false
		for instruction in dump.get("instructions", []):
			if instruction["name"] == "OP_DRAW_RECT_OFFSET_LOOP":
				fused = true
				if instruction["operands"].size() != 37:
					printerr("FAIL: fused operand length")
					failures += 1
			elif fused and instruction["name"] == "OP_RETURN":
				decoded_after_fusion = true
		if not force_ast and (fused != variant["fused"] or (fused and not decoded_after_fusion)):
			printerr("FAIL: fusion selection/decoding ", variant["name"])
			failures += 1
		else:
			print("PASS: fusion selection/decoding ", variant["name"])
		var node := Node2D.new()
		node.set_script(script)
		root.add_child(node)
		node.queue_redraw()
		for frame in 60:
			await process_frame
			if node.get("ready"):
				break
		if not node.get("ready") or not node.get("emptyValid") or node.get("checksum") != variant["checksum"]:
			printerr("FAIL: checksum ", variant["name"], ": ", node.get("checksum"))
			failures += 1
		else:
			print("PASS: checksum ", variant["name"])
		if node.get("lastI") != 4 or not is_equal_approx(float(node.get("lastX")), variant["x"]) or node.get("lastY") != 168.0:
			printerr("FAIL: observable loop locals ", variant["name"])
			failures += 1
		else:
			print("PASS: observable loop locals ", variant["name"])
		if not node.get("rangeError"):
			printerr("FAIL: out-of-range offset error ", variant["name"])
			failures += 1
		else:
			print("PASS: out-of-range offset error ", variant["name"])
		node.free()
	print("SCALED_OFFSET_TESTS_COMPLETED failures=", failures)
	quit(1 if failures else 0)
