extends SceneTree
## Headless runner for a single .vg test in this project (PASS/FAIL via Print → stdout).

const DEFAULT_TEST := "res://test_pattern_parse.vg"
const DEFAULT_MAX_FRAMES := 120

func _init() -> void:
	var vg_path := DEFAULT_TEST
	var args := OS.get_cmdline_args()
	for a in args:
		if a.ends_with(".vg"):
			vg_path = a if a.begins_with("res://") else "res://" + a.get_file()

	var max_frames := DEFAULT_MAX_FRAMES
	var vgf := FileAccess.open(vg_path, FileAccess.READ)
	if vgf:
		for _i in range(8):
			if vgf.eof_reached():
				break
			var line: String = vgf.get_line().strip_edges()
			if line.begins_with("' MAX_FRAMES:"):
				var val := line.substr(len("' MAX_FRAMES:")).strip_edges()
				if val.is_valid_int():
					max_frames = int(val)
		vgf.close()

	var script: Script = load(vg_path)
	if script == null:
		print("ERROR: Failed to load ", vg_path)
		quit(1)
		return

	var base_type: StringName = &"Node"
	var bt: StringName = script.get_instance_base_type()
	if bt != StringName() and ClassDB.class_exists(bt) and ClassDB.can_instantiate(bt):
		base_type = bt

	var test_node: Node = ClassDB.instantiate(base_type) as Node
	if test_node == null:
		test_node = Node.new()
	test_node.name = "VgHeadlessTest"
	test_node.set_script(script)
	root.add_child(test_node)

	_frame_budget = max_frames

var _frame_budget: int = 120
var _frame: int = 0

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame >= _frame_budget:
		quit(0)
	return true
