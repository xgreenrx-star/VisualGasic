extends SubViewport
## Loads generated demo scenes for the movie preview pane.


func clear_demo() -> void:
	for c in get_children():
		c.queue_free()


func load_demo(scene_path: String) -> void:
	clear_demo()
	if scene_path.is_empty():
		return
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_warning("Narcea movie: missing scene %s" % scene_path)
		return
	var node: Node = packed.instantiate()
	node.set_meta("vg_portal_embedded", true)
	node.set_meta("vg_movie_demo", true)
	add_child(node)
