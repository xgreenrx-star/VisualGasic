extends SceneTree

# Verify _Process runs exactly once per GD frame after the fix
var game_node: Node2D
var frame := 0

func _init():
	print("=== _Process Single-Call Verification ===")
	var scene = load("res://main.tscn")
	if scene == null:
		print("[FAIL] Could not load main.tscn")
		quit()
		return
	game_node = scene.instantiate()
	root.add_child(game_node)

func _process(delta):
	frame += 1
	if frame == 1:
		# Set a counter variable on the VG instance
		game_node.set("_testCounter", 0)
	
	if frame <= 10:
		var counter = game_node.get("_testCounter")
		if counter != null:
			print("[GD Frame %d] VG _testCounter = %s" % [frame, counter])
	
	if frame == 12:
		var counter = game_node.get("_testCounter")
		# The VG _Process runs between GD frames
		# After 12 GD frames, _Process should have run ~12 times (not ~24)
		print("")
		print("[Final] After %d GD frames, _testCounter should be ~%d" % [frame, frame])
		print("[Final] Actual _testCounter = %s" % [counter])
		if counter != null and counter is int:
			if counter <= frame + 2:
				print("PASS - _Process runs once per frame")
			else:
				print("FAIL - _Process runs %d times in %d frames (%.1fx)" % [counter, frame, float(counter)/frame])
		quit()
