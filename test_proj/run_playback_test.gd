extends SceneTree

func _init():
	print("=== Playback Test ===")
	var script = VisualGasicScript.new()
	var fa = FileAccess.open("res://test_playback.vg", FileAccess.READ)
	if fa == null:
		print("Error: Could not open test_playback.vg")
		quit()
		return
	
	script.source_code = fa.get_as_text()
	var err = script.reload()
	if err != OK:
		print("Script load error: ", err)
		quit()
		return
	
	var node = Node.new()
	root.add_child(node)
	node.set_script(script)
	
	await create_timer(2.0).timeout
	print("=== Test finished ===")
	quit()
