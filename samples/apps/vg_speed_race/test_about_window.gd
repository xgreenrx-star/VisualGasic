extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://Main.tscn") as PackedScene
	var host: Control = scene.instantiate()
	root.add_child(host)
	await process_frame
	host.call("_show_about")
	await process_frame

	var about: Window
	for child in host.get_children():
		if child is Window:
			about = child
			break
	if about == null or not about.visible:
		push_error("About window did not open")
		quit(1)
		return

	var labels: Array[String] = []
	_collect_labels(about, labels)
	for expected in ["Latest VM microbenchmark", "18 Nov 2026", "VG/GD", "139×", "C++"]:
		var found := false
		for text in labels:
			if text.contains(expected):
				found = true
				break
		if not found:
			push_error("About window is missing expected content: %s" % expected)
			quit(1)
			return

	var close_button := _find_button(about, "Close")
	if close_button == null:
		push_error("About window has no visible Close button")
		quit(1)
		return
	close_button.pressed.emit()
	await process_frame
	if about.visible:
		push_error("Close button did not dismiss the About window")
		quit(1)
		return

	var picker := _find_option_button(host)
	if picker == null:
		push_error("Race workload selector was not created")
		quit(1)
		return
	picker.item_selected.emit(3)
	await process_frame
	var vg_sim := host.get("sim_vg") as Node
	var gd_sim := host.get("sim_gd") as Node
	if int(vg_sim.get("WorkloadMode")) != 3 or int(gd_sim.get("workload_mode")) != 3:
		push_error("Race workload selector did not configure both simulation lanes")
		quit(1)
		return

	print("ABOUT_WINDOW_DONE")
	quit()

func _collect_labels(node: Node, labels: Array[String]) -> void:
	if node is Label:
		labels.append(node.text)
	for child in node.get_children():
		_collect_labels(child, labels)

func _find_button(node: Node, button_text: String) -> Button:
	if node is Button and node.text == button_text:
		return node
	for child in node.get_children():
		var found := _find_button(child, button_text)
		if found != null:
			return found
	return null

func _find_option_button(node: Node) -> OptionButton:
	if node is OptionButton:
		return node
	for child in node.get_children():
		var found := _find_option_button(child)
		if found != null:
			return found
	return null
