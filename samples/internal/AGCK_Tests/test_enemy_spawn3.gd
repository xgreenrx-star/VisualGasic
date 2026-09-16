extends SceneTree

# Runtime test: instantiate enemies and check groups + movement
# Run with: godot --headless --path . -s test_enemy_spawn3.gd
# NOTE: NO @tool annotation — VG skips _Ready() if is_editor_hint() is true

func _init():
	print("=== ENEMY SPAWN RUNTIME TEST v3 ===")
	print("Engine.is_editor_hint() = ", Engine.is_editor_hint())
	
	var overflow_path = "res://build/BLUE_SCREEN/actors/Actor_Overflow.tscn"
	var datebug_path  = "res://build/BLUE_SCREEN/actors/Actor_DateBug.tscn"
	
	var root_node = Node2D.new()
	root_node.name = "TestRoot"
	get_root().add_child(root_node)
	
	for path in [overflow_path, datebug_path]:
		print("\n--- Testing: ", path.get_file(), " ---")
		var scn = load(path)
		if scn == null:
			print("FAIL: load returned null")
			continue
		
		var inst = scn.instantiate()
		if inst == null:
			print("FAIL: instantiate returned null")
			continue
		
		inst.position = Vector2(300, 240)
		root_node.add_child(inst)
		print("Added to scene. is_in_group('enemies') = ", inst.is_in_group("enemies"))
		
		if inst.is_in_group("enemies"):
			print("OK: Enemy is in 'enemies' group")
		else:
			print("FAIL: Enemy NOT in 'enemies' group — _Ready() may not have fired")
		
		# Check visibility 
		print("visible = ", inst.visible)
		print("scale = ", inst.scale)
		print("modulate = ", inst.modulate)
	
	print("\n=== DONE ===")
	quit()
