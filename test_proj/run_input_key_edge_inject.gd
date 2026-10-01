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

func _inject(keycode: int, physical: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = physical
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _run() -> void:
	await process_frame
	await process_frame
	_inject(KEY_X, KEY_X, true)
	await process_frame
	_inject(KEY_X, KEY_X, false)
	await process_frame
	# Godot 4 Input Map style: keycode KEY_NONE, only physical_keycode set.
	_inject(KEY_NONE, KEY_Y, true)
	await process_frame
	_inject(KEY_NONE, KEY_Y, false)
	await process_frame
	_inject(KEY_NONE, KEY_Z, true)
	await process_frame
	await process_frame
	_inject(KEY_NONE, KEY_Z, false)
	await process_frame
	var saw: Variant = _node.get("saw_edge")
	var saw_phys: Variant = _node.get("saw_physical")
	var saw_hold: Variant = _node.get("saw_hold")
	if saw != true:
		print("FAIL: input_key_edge_press: _Input never saw KEY_X after inject")
		quit(1)
		return
	if saw_phys != true:
		print("FAIL: input_key_edge_press: ev.keycode did not fall back to physical KEY_Y")
		quit(1)
		return
	if saw_hold != true:
		print("FAIL: input_key_edge_press: IsKeyPressed missed physical-only KEY_Z")
		quit(1)
		return
	print("PASS: input_key_edge_press")
	quit(0)
