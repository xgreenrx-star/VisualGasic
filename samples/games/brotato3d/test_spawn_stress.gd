# Longer headless stress: natural spawns for 2400+ frames, needs 8+ live enemies.
# Catches wave spawn / bullet hit regressions under sustained load.
# Run: scripts/test_brotato3d_spawn.sh
extends SceneTree
## Run: godot --headless --path projects/brotato3d --script test_spawn_stress.gd

const MAX_FRAMES := 3600
const LOG_EVERY := 300
const MIN_ENEMIES := 8
const MAX_FRAME_MS := 2500.0

func _initialize() -> void:
	print("=== brotato3d spawn stress ===")
	var main_ps: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = main_ps.instantiate()
	root.add_child(main)
	await process_frame
	main.call("start_game")
	var max_frame_ms := 0.0
	for frame in range(MAX_FRAMES):
		var before := Time.get_ticks_msec()
		await process_frame
		var frame_ms := float(Time.get_ticks_msec() - before)
		if frame_ms > max_frame_ms:
			max_frame_ms = frame_ms
		if frame_ms > MAX_FRAME_MS:
			print("FAIL: brotato3d_spawn_stress: frame spike %.0fms at frame %d" % [frame_ms, frame])
			quit(1)
			return
		var enemies := main.get_tree().get_nodes_in_group("enemies")
		if frame > 0 and frame % LOG_EVERY == 0:
			print("[stress] frame=%d enemies=%d bullets=%d max_frame_ms=%.0f" % [
				frame, enemies.size(),
				main.get_tree().get_nodes_in_group("bullets").size(),
				max_frame_ms
			])
		if frame >= 2400 and enemies.size() >= MIN_ENEMIES:
			print("PASS: brotato3d_spawn_stress enemies=%d max_frame_ms=%.0f" % [enemies.size(), max_frame_ms])
			quit(0)
			return
	print("FAIL: brotato3d_spawn_stress: only %d enemies after %d frames" % [
		main.get_tree().get_nodes_in_group("enemies").size(), MAX_FRAMES
	])
	quit(1)
