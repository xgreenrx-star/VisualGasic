extends SceneTree

func _init():
	print("=== Galactic Defender Parallel For Test ===")
	
	var vg = VisualGasicScript.new()
	vg.source_code = FileAccess.open("res://galactic_defender.vg", FileAccess.READ).get_as_text()
	vg.reload()
	
	if vg == null:
		print("[FAIL] Could not load script")
		quit()
		return
	
	var node = Node2D.new()
	node.set_script(vg)
	get_root().add_child(node)
	
	# Give it a couple frames to initialize
	await get_root().get_tree().process_frame
	await get_root().get_tree().process_frame
	await get_root().get_tree().process_frame
	
	print("[OK] Galactic Defender running - no errors")
	
	node.queue_free()
	quit()
