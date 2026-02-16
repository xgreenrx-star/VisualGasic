extends SceneTree

func _init():
	print("=== Globals Persistence Test ===")
	var script = VisualGasicScript.new()
	var fa = FileAccess.open("res://test_globals.vg", FileAccess.READ)
	if fa == null:
		print("Error: Could not open test_globals.vg")
		quit()
		return
	
	script.source_code = fa.get_as_text()
	script.reload()
	
	var node = Node.new()
	root.add_child(node)
	node.set_script(script)
	
	await create_timer(0.5).timeout
	quit()
