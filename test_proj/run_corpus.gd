extends SceneTree

var _node: Node
var _invoke_main := false
var _frame := 0
var _audit_mode := ""
var _failed := false
var _server: TCPServer
var _peer: StreamPeerTCP
var _request := ""
var _replied := false

func _init():
	var args := OS.get_cmdline_user_args()
	var vg_path := ""
	if args.size() == 1:
		vg_path = args[0]
	elif args.is_empty():
		var f = FileAccess.open("res://current_test.txt", FileAccess.READ)
		if f == null:
			_fail("Cannot open current_test.txt")
			return
		vg_path = f.get_line().strip_edges()
		f.close()
	else:
		_fail("Expected one corpus resource path")
		return
	if vg_path == "":
		_fail("Empty path")
		return
	var vgf = FileAccess.open(vg_path, FileAccess.READ)
	if vgf == null:
		_fail("Cannot read " + vg_path)
		return
	var src = vgf.get_as_text()
	vgf.close()
	for line in src.split("\n"):
		if line.begins_with("' Audit mode: "):
			_audit_mode = line.trim_prefix("' Audit mode: ").strip_edges()
	var has_ready = src.find("Sub _Ready") >= 0 or src.find("Sub _ready") >= 0
	var has_main = src.find("Sub Main") >= 0
	_invoke_main = has_main and not has_ready and _audit_mode == ""

	var script = load(vg_path)
	if script == null:
		_fail("Failed to load " + vg_path)
		return
	if _audit_mode in ["buttons", "timer", "keyboard", "properties"]:
		_node = Control.new()
		_node.name = "Form"
		match _audit_mode:
			"buttons":
				_add_control(Button.new(), "btnSave")
				_add_control(Button.new(), "btnReset")
				_add_control(Label.new(), "lblStatus")
			"timer":
				_add_control(Timer.new(), "Timer1")
				_add_control(Label.new(), "lblTime")
			"keyboard":
				_node.focus_mode = Control.FOCUS_ALL
				_add_control(Label.new(), "lblPlayer")
			"properties":
				_add_control(Sprite2D.new(), "sprite1")
				_add_control(Label.new(), "lblPlayer")
				for name in ["btnMove", "btnHide", "btnTint"]:
					_add_control(Button.new(), name)
	elif _audit_mode == "async2d":
		_node = Node2D.new()
		_node.name = "CorpusNode2D"
	elif _audit_mode in ["", "input", "async", "network"]:
		_node = Node.new()
		_node.name = "CorpusNode"
	else:
		_fail("Unknown audit mode: " + _audit_mode)
		return
	if _audit_mode == "network":
		_server = TCPServer.new()
		var error := _server.listen(0, "127.0.0.1")
		if error != OK:
			_fail("Cannot start loopback server: " + error_string(error))
			return
		_node.set_meta("corpus_port", _server.get_local_port())
	_node.set_script(script)
	root.add_child(_node)

func _add_control(control: Node, control_name: String) -> void:
	control.name = control_name
	_node.add_child(control)

func _fail(message: String) -> void:
	_failed = true
	printerr("ERROR: Corpus audit: " + message)
	_close_network()
	quit(1)

func _close_network() -> void:
	if _peer != null:
		_peer.disconnect_from_host()
	if _server != null:
		_server.stop()

func _pump_network() -> void:
	if _replied:
		return
	if _peer == null and _server.is_connection_available():
		_peer = _server.take_connection()
	if _peer == null:
		return
	var error := _peer.poll()
	if error != OK:
		_fail("Loopback peer failed: " + error_string(error))
		return
	var count := _peer.get_available_bytes()
	if count > 0:
		var data := _peer.get_data(count)
		if data[0] != OK:
			_fail("Cannot read loopback request")
			return
		_request += data[1].get_string_from_utf8()
	if _request.contains("\n") and not _replied:
		if _request != "ping\n":
			_fail("Unexpected loopback request")
			return
		error = _peer.put_data("pong\n".to_utf8_buffer())
		if error != OK:
			_fail("Cannot send loopback response")
			return
		_replied = true

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _press(button_name: String) -> void:
	var button := _node.get_node(button_name)
	_expect(not button.get_signal_connection_list("pressed").is_empty(),
		"Missing automatic Click connection: " + button_name)
	button.emit_signal("pressed")

func _exercise_host() -> void:
	match _audit_mode:
		"input":
			_node.call("GreetUser", "World")
			_node.call("GreetUser", " ")
		"buttons":
			var label: Label = _node.get_node("lblStatus")
			_expect(label.text == "Ready", "Form_Load did not initialize status")
			_press("btnSave")
			_expect(label.text == "Saved! (clicks: 1)", "First save did not update status")
			_press("btnSave")
			_expect(label.text == "Saved! (clicks: 2)", "Second save did not update status")
			_press("btnReset")
			_expect(label.text == "Ready", "Reset did not clear status")
		"timer":
			var timer: Timer = _node.get_node("Timer1")
			_expect(is_equal_approx(timer.wait_time, 1.0), "Interval must be 1000 milliseconds")
			_expect(not timer.is_stopped(), "Timer did not start")
			_expect(not timer.get_signal_connection_list("timeout").is_empty(),
				"Missing automatic Timer connection")
			for tick in range(10):
				timer.emit_signal("timeout")
			_expect(timer.is_stopped(), "Timer did not stop after ten ticks")
			_expect(_node.get_node("lblTime").text == "Done.", "Timer label did not finish")
		"keyboard":
			_expect(not _node.get_signal_connection_list("gui_input").is_empty(),
				"Missing automatic KeyDown connection")
			for key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ESCAPE]:
				var event := InputEventKey.new()
				event.keycode = key
				event.pressed = true
				event.shift_pressed = key == KEY_RIGHT
				event.ctrl_pressed = key == KEY_UP
				_node.emit_signal("gui_input", event)
			_expect(_node.get_node("lblPlayer").text == "Player: (100, 100)",
				"Escape did not reset player position")
		"properties":
			var sprite: Sprite2D = _node.get_node("sprite1")
			_expect(sprite.position == Vector2(50, 50) and sprite.visible,
				"Form_Load did not initialize sprite aliases")
			_press("btnMove")
			_expect(sprite.position == Vector2(60, 50), "Position alias did not move sprite")
			_press("btnHide")
			_expect(not sprite.visible, "Visible alias did not hide sprite")
			_press("btnTint")
			var color := sprite.modulate
			_expect(color.r >= 0 and color.r <= 1 and color.g >= 0 and color.g <= 1
				and color.b >= 0 and color.b <= 1 and color.a == 1,
				"Modulate alias produced invalid color channels")

func _process(_delta: float) -> bool:
	if _failed:
		return false
	_frame += 1
	if _audit_mode == "network":
		_pump_network()
		if _failed:
			return false
	if _frame == 1:
		if _invoke_main:
			if not _node.has_method("Main"):
				_fail("Main was declared but cannot be called")
				return false
			_node.Main()
		elif _audit_mode != "":
			_exercise_host()
	if _audit_mode in ["async", "async2d", "network"]:
		if _frame >= 300:
			_fail("Async example did not finish within 300 frames")
			return false
		if _node.get("AuditDone") != true:
			return false
	if _frame >= 2 and not _failed:
		_close_network()
		_node.free()
		print("VG_CORPUS_COMPLETED")
		quit()
	return false
