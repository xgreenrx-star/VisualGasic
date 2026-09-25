extends SceneTree

const MODE_MENU := 0
const MODE_INTRO := 8
const MODE_ABOUT := 9
const MODE_MENU_B := 10
const MODE_MENU_C := 11
const MODE_GORILLAS := 12
const MODE_BLACKJACK := 15
const MODE_MINES := 16
const MODE_HANOI := 17
const MODE_HAUNTED := 13
const MODE_DEFENDER := 21

var _main: Node2D

func _init() -> void:
	var scene: PackedScene = load("res://Main.tscn")
	if scene == null:
		print("FAIL: qb_abc_showcase_input: load Main.tscn")
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

func _mode() -> int:
	return int(_main.get("curMode"))

func _hud1() -> String:
	var v: Variant = _main.get("hud1")
	if v is String:
		return v
	return ""

func _fail(msg: String) -> void:
	print("FAIL: qb_abc_showcase_input: ", msg)
	quit(1)

func _run() -> void:
	await process_frame
	await process_frame
	if _mode() != MODE_MENU:
		_fail("expected menu at start got " + str(_mode()))
	_tap(KEY_F1)
	await process_frame
	if _mode() != MODE_ABOUT:
		_fail("F1 should open About got " + str(_mode()))
	_tap(KEY_ESCAPE)
	await process_frame
	if _mode() != MODE_MENU:
		_fail("Esc from About should return to menu got " + str(_mode()))
	_tap(KEY_8)
	await process_frame
	if _mode() != MODE_INTRO:
		_fail("KEY_8 should show Gorillas intro got " + str(_mode()))
	_tap(KEY_SPACE)
	await process_frame
	if _mode() != MODE_GORILLAS:
		_fail("Space should launch Gorillas got " + str(_mode()))
	_tap(KEY_ESCAPE)
	await process_frame
	if _mode() != MODE_MENU:
		_fail("Esc from Gorillas should return to the menu got " + str(_mode()))
	_tap(KEY_B)
	await process_frame
	if _mode() != MODE_INTRO:
		_fail("Blackjack pick intro got " + str(_mode()))
	_tap(KEY_SPACE)
	await process_frame
	if _mode() != MODE_BLACKJACK:
		_fail("Blackjack launch got " + str(_mode()))
	_tap(KEY_H)
	await process_frame
	_tap(KEY_ESCAPE)
	await process_frame
	_tap(KEY_C)
	await process_frame
	if _mode() != MODE_INTRO:
		_fail("Mines intro got " + str(_mode()))
	_tap(KEY_SPACE)
	await process_frame
	if _mode() != MODE_MINES:
		_fail("Mines launch got " + str(_mode()))
	_tap(KEY_RIGHT)
	await process_frame
	if _hud1().find("cursor 1,") < 0:
		_fail("Mines cursor should move right hud=" + _hud1())
	_tap(KEY_ESCAPE)
	await process_frame
	_tap(KEY_D)
	await process_frame
	if _mode() != MODE_INTRO:
		_fail("Hanoi intro got " + str(_mode()))
	_tap(KEY_SPACE)
	await process_frame
	if _mode() != MODE_HANOI:
		_fail("Hanoi launch got " + str(_mode()))
	_tap(KEY_1)
	await process_frame
	if _hud1().find("sel peg:1") < 0:
		_fail("Hanoi peg 1 select hud=" + _hud1())
	_tap(KEY_ESCAPE)
	await process_frame
	_tap(KEY_9)
	await process_frame
	if _mode() != MODE_INTRO:
		_fail("Haunted intro got " + str(_mode()))
	_tap(KEY_SPACE)
	await process_frame
	if _mode() != MODE_HAUNTED:
		_fail("Haunted launch got " + str(_mode()))
	_tap(KEY_E)
	await process_frame
	if _hud1().find("room 3") < 0:
		_fail("Haunted E should go to library hud=" + _hud1())
	_tap(KEY_ESCAPE)
	await process_frame
	if _mode() != MODE_MENU:
		_fail("Esc should reach the menu got " + str(_mode()))
	_tap(KEY_H)
	await process_frame
	if _mode() != MODE_INTRO:
		_fail("Defender intro got " + str(_mode()))
	_tap(KEY_SPACE)
	await process_frame
	if _mode() != MODE_DEFENDER:
		_fail("Defender launch got " + str(_mode()))
	_tap(KEY_SPACE)
	await process_frame
	print("PASS: qb_abc_showcase_input")
	quit(0)
