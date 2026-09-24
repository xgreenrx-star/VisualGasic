extends SceneTree

const VG_PATH := "res://test_suite/test_input_key_edge_press.vg"

var _node: Node

func _init() -> void:
	var script: Script = load(VG_PATH)
	if script == null:
		print("FAIL: input_key_edge_press: load vg")
		quit(1)
		return
	_node = Node.new()
	_node.name = "InputEdgePressTest"
	_node.set_script(script)
	root.add_child(_node)
	call_deferred("_run")

func _inject(keycode: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _run() -> void:
	await process_frame
	await process_frame
	_inject(KEY_X, true)
	await process_frame
	_inject(KEY_X, false)
	await process_frame
	await process_frame
	var saw: Variant = _node.get("saw_edge")
	if saw == true:
		print("PASS: input_key_edge_press")
		quit(0)
	else:
		print("FAIL: input_key_edge_press: _Input never saw KEY_X after inject")
		quit(1)
