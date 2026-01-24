@tool
extends EditorScript

func _run():
	# If run from the CLI with -s, the environment may not provide Editor APIs. Guard and explain.
	if not has_method("get_editor_interface"):
		print("VisualGasic: verify_toolbox must be run inside the Godot Editor as an EditorScript (use Script -> Run or the EditorScript runner). Aborting.")
		return
	print("VisualGasic: verify_toolbox running...")
	var base = get_editor_interface().get_base_control()
	if not base:
		print("VisualGasic: ERROR: no Editor base control")
		return
	var plugin = base.get_meta("visual_gasic_plugin_instance")
	if not plugin:
		print("VisualGasic: ERROR: plugin instance not found in meta")
		return
	var real_toolbox = plugin._get_toolbox_instance()
	if not real_toolbox:
		print("VisualGasic: ERROR: Toolbox instance not found (native not instantiated)")
		return
	print("VisualGasic: Toolbox found -> " + str(real_toolbox))
	# List tabs and children
	for i in real_toolbox.get_children():
		print("  child: " + i.get_class() + " name=" + i.name)
		for btn in i.get_children():
			print("    tool: " + btn.get_class() + " tooltip=" + str(btn.get_tooltip_text()))
	# Done
	print("VisualGasic: verify_toolbox done")
	return
