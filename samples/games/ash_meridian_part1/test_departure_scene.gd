extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("Departure scene regression did not complete")
		quit(1)
	)
	var test_path := "res://test_level1_departure.vg"
	for arg: String in OS.get_cmdline_user_args():
		if arg.ends_with(".vg"):
			test_path = arg
	var script: Script = load(test_path)
	if script == null:
		push_error("Cannot load departure scene regression")
		quit(1)
		return
	var test_node: Node = ClassDB.instantiate(script.get_instance_base_type())
	test_node.set_script(script)
	root.add_child(test_node)
