extends Node
## Loads one full showcase scene into the carrier cockpit SubViewport.


func clear_beat() -> void:
	for c in get_children():
		c.queue_free()


func load_beat(beat: Dictionary) -> void:
	clear_beat()
	var path: String = str(beat.get("path", ""))
	if path.is_empty():
		return
	var packed: PackedScene = load(path)
	if packed == null:
		push_warning("Carrier screen: missing scene %s" % path)
		return
	var scene_node: Node = packed.instantiate()
	add_child(scene_node)


func update_beat(_t: float, _duration: float) -> void:
	pass
