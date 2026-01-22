extends SceneTree

func _init() -> void:
	# defer actual work until the main loop is running
	call_deferred("_run_test")

func _run_test() -> void:
	print("DUAL_KAWASE_TEST_START")
	# instantiate a fake DualKawase node and the bridge, then exercise apply_to_viewport
	var dk = load("res://dual_kawase_fake.gd").new()
	dk.name = "DualKawase"
	get_root().add_child(dk)
	var bridge = load("res://dual_kawase_bridge.gd").new()
	bridge.name = "DualKawaseBridge"
	# point at the root-level DualKawase node (sibling) using absolute path
	bridge.target_node_path = NodePath("/root/DualKawase")
	get_root().add_child(bridge)
	# apply the effect via bridge
	bridge.apply_to_viewport(get_root().get_viewport())
	# small delay to ensure operations run
	await create_timer(0.05).timeout
	# free resources and report
	if dk.has_method("free_compositor"):
		dk.free_compositor()
		print("DUAL_KAWASE_FAKE_FREED")

	# Capture a screenshot of the main viewport and save it for validation
	var img = get_root().get_viewport().get_texture().get_image()
	img.flip_y()
	var out_path = ProjectSettings.globalize_path("res://../tests/output/dual_kawase.png")
	var err = img.save_png(out_path)
	if err == OK:
		print("DUAL_KAWASE_SCREENSHOT_SAVED:" + out_path)
	else:
		print("DUAL_KAWASE_SCREENSHOT_FAILED")

	print("DUAL_KAWASE_TEST_DONE")
	quit()