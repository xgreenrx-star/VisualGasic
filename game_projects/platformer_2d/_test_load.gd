extends SceneTree

func _init():
	var packed = ResourceLoader.load("res://_test_clean.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	print("Packed scene: ", packed)
	if packed:
		var instance = packed.instantiate()
		print("Instance: ", instance)
		print("Instance type: ", instance.get_class())
		print("Children: ", instance.get_child_count())
		for i in range(mini(instance.get_child_count(), 5)):
			var c = instance.get_child(i)
			print("  Child ", i, ": ", c.name, " (", c.get_class(), ")")
	else:
		print("FAILED to load packed scene!")
	quit()
