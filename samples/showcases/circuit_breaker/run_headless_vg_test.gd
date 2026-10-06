extends SceneTree
## Headless Circuit Breaker smoke: load main.tscn, inject ui_right, confirm the
## player world X changes, then quit.

func _init() -> void:
	call_deferred("_run")

func _player_x(main: Node) -> float:
	var x: Variant = main.call("PlayerWorldX")
	if x == null:
		return 0.0
	return float(x)

func _inject_right() -> void:
	Input.action_press("ui_right")
	var ev := InputEventKey.new()
	ev.keycode = KEY_NONE
	ev.physical_keycode = KEY_RIGHT
	ev.pressed = true
	Input.parse_input_event(ev)

func _run() -> void:
	var t0 := Time.get_ticks_msec()
	print("CB_HEADLESS: boot msec=", t0)
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		print("FAIL: circuit_breaker_headless: load main.tscn")
		quit(1)
		return
	var main: Node = scene.instantiate()
	if main == null:
		print("FAIL: circuit_breaker_headless: instantiate")
		quit(1)
		return
	root.add_child(main)
	print("CB_HEADLESS: instantiated msec=", Time.get_ticks_msec() - t0)
	for _i in 3:
		await process_frame
	var x0 := _player_x(main)
	print("CB_HEADLESS: x0=", x0, " msec=", Time.get_ticks_msec() - t0)
	_inject_right()
	for _j in 12:
		await process_frame
	Input.action_release("ui_right")
	var x1 := _player_x(main)
	print("CB_HEADLESS: x1=", x1, " msec=", Time.get_ticks_msec() - t0)
	if x1 <= x0 + 0.5:
		print("FAIL: circuit_breaker_headless: player did not move x0=", x0, " x1=", x1)
		quit(1)
		return
	print("PASS: circuit_breaker_headless")
	quit(0)
