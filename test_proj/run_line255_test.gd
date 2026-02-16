extends SceneTree

func _init():
	print("=== Line 255 Compact Bug Test ===")
	var script = VisualGasicScript.new()
	var fa = FileAccess.open("res://test_line255.vg", FileAccess.READ)
	if fa == null:
		print("Error: Could not open test_line255.vg")
		quit()
		return
	
	script.source_code = fa.get_as_text()
	var err = script.reload()
	if err != OK:
		print("Script load error: ", err)
		quit()
		return
	
	print("Script loaded. Creating instance...")
	var node = Node.new()
	root.add_child(node)
	node.set_script(script)
	
	# Let frames run to exercise StopNote (which is at line 255)
	await create_timer(1.0).timeout
	
	print("=== Test finished ===")
	quit()
