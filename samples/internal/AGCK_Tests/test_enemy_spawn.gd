@tool
extends SceneTree

# Runtime test: instantiate enemies and check what happens
# Run with: godot --headless --path . -s test_enemy_spawn.gd

func _init():
	print("=== ENEMY SPAWN RUNTIME TEST ===")
	
	var overflow_path = "res://build/BLUE_SCREEN/actors/Actor_Overflow.tscn"
	var datebug_path  = "res://build/BLUE_SCREEN/actors/Actor_DateBug.tscn"
	
	for path in [overflow_path, datebug_path]:
		print("\n--- Testing: ", path, " ---")
		var scn = load(path)
		if scn == null:
			print("FAIL: load() returned null for ", path)
			continue
		print("OK: Loaded PackedScene")
		
		var inst = scn.instantiate()
		if inst == null:
			print("FAIL: instantiate() returned null")
			continue
		print("OK: Instantiated. Type: ", inst.get_class())
		
		# Check it's a CharacterBody2D
		if not inst is CharacterBody2D:
			print("WARN: Expected CharacterBody2D, got ", inst.get_class())
		
		# Check script is attached
		var s = inst.get_script()
		if s == null:
			print("WARN: No script attached!")
		else:
			print("OK: Script attached: ", s.resource_path)
		
		# Add to temp scene so _ready() fires
		var root_node = Node2D.new()
		root_node.name = "TestRoot"
		get_root().add_child(root_node)
		root_node.add_child(inst)
		print("OK: Added to scene tree. _ready() should have fired.")
		
		# Check groups
		if inst.is_in_group("enemies"):
			print("OK: is in group 'enemies'")
		else:
			print("FAIL: NOT in group 'enemies' (AddToGroup may have failed)")
		
		# Check methods
		for m in ["TakeDamage", "SetWaveScale", "Die", "Hitbox_BodyEntered"]:
			if inst.has_method(m):
				print("OK: has_method(", m, ")")
			else:
				print("WARN: missing method: ", m)
		
		# Check visibility
		if inst.visible:
			print("OK: visible = true")
		else:
			print("FAIL: visible = false!")
		
		# Check scale
		if inst.scale == Vector2(1, 1):
			print("OK: scale = (1,1)")
		else:
			print("WARN: scale = ", inst.scale)
		
		# Check modulate alpha
		if inst.modulate.a > 0.0:
			print("OK: modulate.a = ", inst.modulate.a)
		else:
			print("FAIL: modulate.a = 0 (invisible!)")
		
		# Check position
		inst.position = Vector2(300.0, 240.0)
		print("OK: position set to ", inst.position)
		
		# Check Sprite2D child exists
		var sprite = inst.get_node_or_null("Sprite2D")
		if sprite:
			print("OK: Sprite2D found, texture: ", sprite.texture)
		else:
			print("WARN: no Sprite2D child")
		
		root_node.queue_free()
	
	print("\n=== DONE ===")
	quit()
