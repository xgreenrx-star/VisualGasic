extends SceneTree

func _init():
	var script = load("res://addons/visual_gasic/visual_gasic_script.gdns")
	if not script:
		printerr("Failed to load VisualGasic script resource")
		quit(1)
		return
	
	var vg_script = script.new()
	if not vg_script:
		printerr("Failed to create VisualGasic script instance")
		quit(1)
		return
	
	var source_path = "res://../test_compiler_fix.vg"
	var file = FileAccess.open(source_path, FileAccess.READ)
	if not file:
		printerr("Failed to open test file: ", source_path)
		quit(1)
		return
	
	var source_code = file.get_as_text()
	file.close()
	
	vg_script.set_source_code(source_code)
	var err = vg_script.reload(true)
	if err != OK:
		printerr("Failed to compile VisualGasic script: ", err)
		quit(1)
		return
	
	var node = Node.new()
	node.set_script(vg_script)
	root.add_child(node)
	
	if node.has_method("_Ready"):
		node._Ready()
	
	print("\n=== Test completed successfully ===")
	quit(0)
