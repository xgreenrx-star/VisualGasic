extends SceneTree

func _init():
	print("HEADLESS SCRIPT LOADED")
	print("HEADLESS TEST: starting toggle")
	var handler_script = load("res://addons/visual_gasic/vg_debug_handler.gd")
	print("HEADLESS TEST: handler_script=", handler_script)
	if not handler_script:
		print("HEADLESS TEST: failed to load debug handler")
		quit()
		return
	var handler = handler_script.new()
	print("HEADLESS TEST: handler=", handler)
	get_root().add_child(handler)

	if handler.has_method("_input"):
		var ev = InputEventKey.new()
		ev.keycode = KEY_T
		ev.ctrl_pressed = true
		ev.shift_pressed = true
		ev.pressed = true
		print("HEADLESS TEST: sending Ctrl+Shift+T")
		handler.call_deferred("_input", ev)
		print("HEADLESS TEST: input deferred")
	else:
		print("HEADLESS TEST: handler missing _input")

	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(func():
		print("HEADLESS TEST: done")
		quit()
	)
	get_root().add_child(timer)
	print("HEADLESS TEST: waiting for timer...")
