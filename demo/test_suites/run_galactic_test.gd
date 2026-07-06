extends SceneTree

func _init():
	print("=== Galactic Defender Load Test ===")
	
	var path = "/home/Commodore/Documents/VisualGasic/demos/2D_Games/Galactic_Defender/galactic_defender.vg"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("[FAIL] Could not open file")
		quit()
		return
	
	var source = file.get_as_text()
	file.close()
	print("Source loaded: " + str(source.length()) + " chars, " + str(source.count("\n")) + " lines")
	
	# Create VisualGasicScript and parse
	var vgs = VisualGasicScript.new()
	vgs.source_code = source
	var err = vgs.reload()
	
	print("reload() returned: " + str(err))
	
	if err == OK:
		print("[PASS] Script parsed successfully!")
		# Try instantiating on a node
		var node = Node.new()
		node.set_script(vgs)
		root.add_child(node)
		print("[PASS] Script attached to node and initialized!")
		node.queue_free()
	else:
		print("[FAIL] Parse error: " + str(err))
	
	quit()
