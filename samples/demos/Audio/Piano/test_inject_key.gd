extends SceneTree

# Inject real Godot key events to test Piano debounce with real Input.IsKeyPressed
var game_node: Node2D
var frame := 0
var key_pressed_frame := 0
var key_released_frame := 0

func _init():
	print("=== Piano Input Injection Test ===")
	
	var scene = load("res://main.tscn")
	if scene == null:
		print("[FAIL] Could not load main.tscn")
		quit()
		return
	
	game_node = scene.instantiate()
	root.add_child(game_node)
	print("[OK] Scene instantiated")

func inject_key(keycode: int, pressed: bool):
	var event = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

func _process(delta):
	frame += 1
	
	if frame == 3:
		# Press key A (note C4)
		print("[Frame 3] Injecting KEY_A press...")
		inject_key(KEY_A, true)
		key_pressed_frame = frame
	
	if frame >= 4 and frame <= 8:
		# Key A is still "held" (no release event)
		# Check if PlayNote is called repeatedly
		var kp = game_node.get("keyPressed")
		var an = game_node.get("activeNotes")
		if kp is Array:
			print("[Frame %d] keyPressed[0]=%s activeNotes[0]=%s" % [frame, kp[0], an[0] if an is Array else "?"])
	
	if frame == 10:
		# Release key A
		print("[Frame 10] Injecting KEY_A release...")
		inject_key(KEY_A, false)
		key_released_frame = frame
	
	if frame == 12:
		var kp = game_node.get("keyPressed")
		print("[Frame 12] After release: keyPressed[0]=%s" % [kp[0] if kp is Array else "?"])
	
	if frame == 15:
		# Press key A again
		print("[Frame 15] Injecting KEY_A press again...")
		inject_key(KEY_A, true)
	
	if frame >= 16 and frame <= 18:
		var kp = game_node.get("keyPressed")
		print("[Frame %d] keyPressed[0]=%s" % [frame, kp[0] if kp is Array else "?"])
	
	if frame == 20:
		inject_key(KEY_A, false)
		print("[Frame 20] Final release")
	
	if frame == 22:
		print("")
		print("=== Test Complete ===")
		# The output should show PlayNote called exactly twice (frame 4 and frame 16)
		quit()
