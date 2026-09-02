extends SceneTree
## Headless runner for Python bridge demos (Sub Main entry point).
## Path: res://current_test.txt (one line, e.g. res://demos/python/demo_python_bridge.vg)

var max_frames: int = 180

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

	if node.has_method("Main"):
		node.Main()
	elif node.has_method("_Ready"):
		node._Ready()
	else:
		print("ERROR: No Main() or _Ready() in ", vg_path)
		quit(1)
		return

var _frame: int = 0

func _process(_delta) -> bool:
	_frame += 1
	if _frame >= max_frames:
		quit()
	return false
