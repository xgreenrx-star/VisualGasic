extends SceneTree

var _main: Node2D

func _init() -> void:
	var scene: PackedScene = load("res://Main.tscn")
	if scene == null:
		print("FAIL: classic_screen_modes: load Main.tscn")
		quit(1)
		return
	_main = scene.instantiate() as Node2D
	root.add_child(_main)
	call_deferred("_run")

func _tap(keycode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	if keycode >= KEY_A and keycode <= KEY_Z:
		down.unicode = 97 + (keycode - KEY_A)
	if keycode >= KEY_0 and keycode <= KEY_9:
		down.unicode = 48 + (keycode - KEY_0)
	Input.parse_input_event(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)

func _run() -> void:
	await process_frame
	await process_frame
	_tap(KEY_3)
	await process_frame
	await process_frame
	var mode: int = int(_main.get("demoMode"))
	if mode != 13:
		print("FAIL: classic_screen_modes: KEY_3 should launch mode 13 demo, got ", mode)
		quit(1)
		return
	print("PASS: classic_screen_modes_launch_13")
	_tap(KEY_ESCAPE)
	await process_frame
	mode = int(_main.get("demoMode"))
	if mode != 0:
		print("FAIL: classic_screen_modes: Esc should return to menu, got ", mode)
		quit(1)
		return
	print("PASS: classic_screen_modes_menu")
	quit(0)
