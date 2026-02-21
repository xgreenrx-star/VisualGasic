extends SceneTree

var game_node: Node2D
var frame := 0

func _init():
	print("=== Piano Demo Automated Test ===")
	
	var scene = load("res://main.tscn")
	if scene == null:
		print("[FAIL] Could not load main.tscn")
		quit()
		return
	
	game_node = scene.instantiate()
	root.add_child(game_node)
	print("[OK] Scene instantiated")

func _process(delta):
	frame += 1
	
	if frame == 3:
		# Check that noteCount was loaded from DATA statements
		var nc = game_node.get("noteCount")
		print("[Frame 3] noteCount=%s" % [nc])
		
		# Try calling PlayNote to verify PlayTone builtin exists
		# PlayNote calls PlayTone internally
		print("[Frame 3] Calling PlayNote(0) to test PlayTone builtin...")
		game_node.call("PlayNote", 0)
		
		var active0 = game_node.get("activeNotes")
		print("[Frame 3] After PlayNote, activeNotes=%s" % [active0])
	
	if frame == 10:
		var nc = game_node.get("noteCount")
		print("[Frame 10 FINAL] noteCount=%s" % [nc])
		print("=== Test Complete ===")
		quit()
