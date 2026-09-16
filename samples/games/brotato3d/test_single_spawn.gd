extends SceneTree
## Minimal spawn benchmark — times one enemy instantiate + skin apply.
## Run: godot --headless --path projects/brotato3d --script test_single_spawn.gd

func _initialize() -> void:
	print("=== brotato3d single spawn benchmark ===")
	var t0 := Time.get_ticks_msec()

	var main_ps: PackedScene = load("res://scenes/Main.tscn")
	print("load Main.tscn: %d ms" % (Time.get_ticks_msec() - t0))
	t0 = Time.get_ticks_msec()

	var main: Node = main_ps.instantiate()
	root.add_child(main)
	print("instantiate+add Main: %d ms" % (Time.get_ticks_msec() - t0))
	t0 = Time.get_ticks_msec()

	# Wait one idle frame for autoload + _Ready
	await process_frame
	print("after 1 frame: %d ms" % (Time.get_ticks_msec() - t0))
	t0 = Time.get_ticks_msec()

	var gm := root.get_node_or_null("GameManager")
	if gm == null:
		gm = get_root().get_node_or_null("GameManager")
	if gm != null:
		gm.call("Reset")
		gm.set("game_state", "fight")
	print("GameManager reset: %d ms" % (Time.get_ticks_msec() - t0))
	t0 = Time.get_ticks_msec()

	var enemy_ps: PackedScene = load("res://scenes/Enemy3D.tscn")
	print("load Enemy3D.tscn: %d ms" % (Time.get_ticks_msec() - t0))
	t0 = Time.get_ticks_msec()

	var go: Node = main.get_node("GameObjects")
	for i in range(5):
		var t_spawn := Time.get_ticks_msec()
		var enemy: Node = enemy_ps.instantiate()
		var t_inst := Time.get_ticks_msec()
		go.add_child(enemy)
		var t_add := Time.get_ticks_msec()
		enemy.call("Setup", 20.0, 100.0, 5.0, 2, 1)
		var t_setup := Time.get_ticks_msec()
		enemy.call("ApplySkin", "character-b", Color(1, 0.5, 0.5))
		var t_skin := Time.get_ticks_msec()
		print("spawn #%d: inst=%dms add=%dms setup=%dms skin=%dms total=%dms" % [
			i + 1, t_inst - t_spawn, t_add - t_inst, t_setup - t_add, t_skin - t_setup, t_skin - t_spawn
		])
		await process_frame

	print("PASS: brotato3d_single_spawn_benchmark")
	quit(0)
