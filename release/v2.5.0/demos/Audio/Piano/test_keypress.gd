extends SceneTree

# Test to detect double _Process calls AND check keyPressed behavior
var game_node: Node2D
var frame := 0
var last_process_count := 0

func _init():
	print("=== Piano Double-Call Diagnostic ===")
	
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
	
	if frame == 2:
		# Check initial state
		var nc = game_node.get("noteCount")
		var dsl = game_node.get("demoSongLength")
		var kp = game_node.get("keyPressed")
		print("[Frame 2] noteCount=%s demoSongLength=%s" % [nc, dsl])
		print("[Frame 2] keyPressed type=%s size=%s" % [typeof(kp), kp.size() if kp is Array else "N/A"])
		if kp is Array and kp.size() > 0:
			print("[Frame 2] keyPressed[0]=%s type=%s" % [kp[0], typeof(kp[0])])
		
		# Manually simulate a keypress debounce cycle
		# Set keyPressed[0] = true, then verify it persists
		print("")
		print("[Frame 2] Manually calling PlayNote(0)...")
		game_node.call("PlayNote", 0)
		
		# Now set keyPressed[0] = True via script set
		var kp_arr = game_node.get("keyPressed")
		print("[Frame 2] After PlayNote, keyPressed[0]=%s" % [kp_arr[0] if kp_arr is Array else "?"])
	
	if frame == 3:
		# Check if keyPressed[0] persisted to next frame
		var kp = game_node.get("keyPressed")
		print("[Frame 3] keyPressed[0]=%s (should still be True if persisted)" % [kp[0] if kp is Array else "?"])
		# Note: PlayNote sets activeNotes, not keyPressed. keyPressed is set by HandleKeyboardInput.
		# Let's directly test the array persistence by setting it from GD
		if kp is Array:
			kp[0] = true
			game_node.set("keyPressed", kp)
			print("[Frame 3] Set keyPressed[0]=true via GDScript")
	
	if frame == 4:
		var kp = game_node.get("keyPressed")
		print("[Frame 4] keyPressed[0]=%s (should be True)" % [kp[0] if kp is Array else "?"])
	
	if frame == 5:
		var kp = game_node.get("keyPressed")
		print("[Frame 5] keyPressed[0]=%s (should be True)" % [kp[0] if kp is Array else "?"])
		# Now let's also check if HandleKeyboardInput ran (process count)
		var fc = game_node.get("frameCount") 
		print("[Frame 5] VG frameCount=%s (doesn't exist in piano, may be 0/null)" % [fc])
	
	if frame == 10:
		print("")
		print("=== Diagnostic Complete ===")
		quit()
