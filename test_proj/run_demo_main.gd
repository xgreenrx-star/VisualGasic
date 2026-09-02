extends SceneTree
## Headless runner for Python bridge demos (Sub Main or _Ready entry point).
## Path: res://current_test.txt (one line, e.g. res://demos/python/demo_python_bridge.vg)

var max_frames: int = 180
var _demo_node: Node
var _started: bool = false

func _init() -> void:
	var f := FileAccess.open("res://current_test.txt", FileAccess.READ)
	if f == null:
		print("ERROR: Cannot open res://current_test.txt")
		quit(1)
		return
	var vg_path := f.get_line().strip_edges()
	f.close()
	if vg_path.is_empty():
		print("ERROR: Empty demo path")
		quit(1)
		return

	var script: Resource = load(vg_path)
	if script == null:
		print("ERROR: Failed to load ", vg_path)
		quit(1)
		return

	var node := Node.new()
	node.name = "DemoNode"
	node.set_script(script)
	root.add_child(node)
	_demo_node = node

var _frame: int = 0

func _process(_delta) -> bool:
	if not _started and _demo_node:
		_started = true
		if _demo_node.has_method("Main"):
			_demo_node.Main()
		elif _demo_node.has_method("_Ready"):
			_demo_node._Ready()
		else:
			print("ERROR: No Main() or _Ready() in demo script")
			quit(1)
			return false
	_frame += 1
	if _frame >= max_frames:
		quit()
	return false
