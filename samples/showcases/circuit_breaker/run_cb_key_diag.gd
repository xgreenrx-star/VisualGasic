extends SceneTree
## Isolate Circuit Breaker _Input / PlayHandleKey (no Input Map hold).

func _player_x(main: Node) -> float:
	var x: Variant = main.call("PlayerWorldX")
	if x == null:
		return 0.0
	return float(x)

func _state(main: Node) -> int:
	var s: Variant = main.call("PlayState")
	if s == null:
		return -1
	return int(s)

func _tap_physical_right() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_NONE
	ev.physical_keycode = KEY_RIGHT
	ev.pressed = true
	Input.parse_input_event(ev)
	ev = InputEventKey.new()
	ev.keycode = KEY_NONE
	ev.physical_keycode = KEY_RIGHT
	ev.pressed = false
	Input.parse_input_event(ev)

func _tap_keycode_d() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_D
	ev.physical_keycode = KEY_D
	ev.pressed = true
	Input.parse_input_event(ev)
	ev = InputEventKey.new()
	ev.keycode = KEY_D
	ev.physical_keycode = KEY_D
	ev.pressed = false
	Input.parse_input_event(ev)

func _call_handle(main: Node, keycode: int) -> void:
	if main.has_method("PlayHandleKey"):
		main.call("PlayHandleKey", keycode)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		print("FAIL: cb_key_diag: load")
		quit(1)
		return
	var main: Node = scene.instantiate()
	root.add_child(main)
	for _i in 3:
		await process_frame
	var s0 := _state(main)
	var x0 := _player_x(main)
	print("CB_KEY: start state=", s0, " x=", x0)
	_tap_physical_right()
	for _j in 16:
		await process_frame
	var x1 := _player_x(main)
	var s1 := _state(main)
	print("CB_KEY: after physical RIGHT tap state=", s1, " x=", x1)
	_tap_keycode_d()
	for _k in 16:
		await process_frame
	var x2 := _player_x(main)
	print("CB_KEY: after KEY_D tap x=", x2)
	_call_handle(main, KEY_RIGHT)
	for _m in 16:
		await process_frame
	var x3 := _player_x(main)
	print("CB_KEY: after PlayHandleKey(KEY_RIGHT) x=", x3, " state=", _state(main))
	var moved_input := x1 > x0 + 0.5 or x2 > x0 + 0.5
	var moved_call := x3 > x0 + 0.5
	if not moved_input:
		print("FAIL: cb_key_diag: _Input tap did not move x0=", x0, " x1=", x1, " x2=", x2)
		if not moved_call:
			print("FAIL: cb_key_diag: PlayHandleKey() also did not move x3=", x3)
			quit(1)
			return
		print("FAIL: cb_key_diag: PlayHandleKey works but _Input tap does not")
		quit(1)
		return
	print("PASS: cb_key_diag")
	quit(0)
