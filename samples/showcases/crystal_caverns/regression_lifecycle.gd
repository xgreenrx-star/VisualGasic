extends RefCounted

static func release_scene(tree: SceneTree, game: Node) -> bool:
	var streams: Array = game.get_node("SoundEffects").get("streams").map(func(stream): return weakref(stream))
	game.free()
	await tree.process_frame
	# AudioServer retires stopped playback on its mixer thread, not necessarily
	# on the first game frame. Observe retirement with a bounded deadline.
	var deadline := Time.get_ticks_msec() + 2000
	while streams.any(func(handle): return handle.get_ref() != null) and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return streams.all(func(handle): return handle.get_ref() == null)
