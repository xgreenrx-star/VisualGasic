extends Node
## Portal SubViewport loader — one demo scene at a time for backrooms zoom transitions.
##
## Sets vg_portal_embedded on the root so .vg demos skip ChangeScene when loaded here.
## GDScript managers receive set_showcase_frozen via set_scene_paused() (legacy name).


func clear_beat() -> void:
	for c in get_children():
		c.queue_free()


func load_scene(path: String) -> Node:
	clear_beat()
	if path.is_empty():
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		push_warning("Backrooms screen: missing scene %s" % path)
		return null
	var scene_node: Node = packed.instantiate()
	scene_node.set_meta("vg_portal_embedded", true)
	add_child(scene_node)
	return scene_node


func set_scene_paused(paused: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	for c in get_children():
		if c.has_method("set_showcase_frozen"):
			c.call("set_showcase_frozen", paused)
		# Do not disable process on portal scenes — that stops SubViewport rendering.
