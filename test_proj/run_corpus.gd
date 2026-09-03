extends SceneTree

var _node: Node
var _invoke_main := false
var _frame := 0

func _init():
	var f = FileAccess.open("res://current_test.txt", FileAccess.READ)
	if f == null:
		print("ERROR: Cannot open current_test.txt")
		quit()
		return
	var vg_path = f.get_line().strip_edges()
	f.close()
	if vg_path == "":
		print("ERROR: Empty path")
		quit()
		return
	var vgf = FileAccess.open(vg_path, FileAccess.READ)
	if vgf == null:
		print("ERROR: Cannot read " + vg_path)
		quit()
		return
	var src = vgf.get_as_text()
	vgf.close()
	var has_ready = src.find("Sub _Ready") >= 0 or src.find("Sub _ready") >= 0
	var has_main = src.find("Sub Main") >= 0
	_invoke_main = has_main and not has_ready

	var script = load(vg_path)
	if script == null:
		print("ERROR: Failed to load " + vg_path)
		quit()
		return
	_node = Node.new()
	_node.name = "CorpusNode"
	_node.set_script(script)
	root.add_child(_node)

func _process(_delta):
	_frame += 1
	if _invoke_main:
		if _frame == 1 and _node.has_method("Main"):
			_node.Main()
		if _frame >= 2:
			quit()
	elif _frame >= 2:
		quit()
