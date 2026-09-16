# Headless regression: start game, spawn 5 enemies, run 600 frames.
# Fails if any frame takes >2.5s (main-loop deadlock / spawn stall).
# Run: scripts/test_brotato3d_spawn.sh
extends SceneTree

func _initialize() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.call("start_game")
	var go: Node = main.get_node("GameObjects")
	var enemy_ps: PackedScene = load("res://scenes/Enemy3D.tscn")
	var skins := ["character-b", "character-c", "character-d", "character-e", "character-b"]
	for i in range(5):
		var e: Node = enemy_ps.instantiate()
		go.add_child(e)
		e.call("Setup", 30.0, 100.0, 5.0, 2, 1)
		e.call("ApplySkin", skins[i], Color(1, 0.5, 0.5))
		var angle := float(i) * 1.256637
		e.global_position = Vector3(cos(angle) * 8.0, 0.05, sin(angle) * 8.0)
		await process_frame
	print("5 enemies placed, simulating...")
	for frame in range(600):
		var t := Time.get_ticks_msec()
		await process_frame
		var dt := Time.get_ticks_msec() - t
		if dt > 2500:
			print("FAIL: hang at frame %d dt=%dms" % [frame, dt])
			quit(1)
			return
		if frame % 60 == 0:
			print("frame %d dt=%dms bullets=%d" % [
				frame, dt, main.get_tree().get_nodes_in_group("bullets").size()
			])
	print("PASS: brotato3d_combat_with_mobs")
	quit(0)
