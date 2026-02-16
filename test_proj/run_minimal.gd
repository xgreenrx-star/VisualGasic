extends Node2D

func _ready():
	print("[MINIMAL_RUNNER] _ready called")
	
	# Read test file
	var f = FileAccess.open("res://current_test.txt", FileAccess.READ)
	if f == null:
		print("[MINIMAL_RUNNER] ERROR: Cannot read current_test.txt")
		get_tree().quit()
		return
	
	var path = f.get_line().strip_edges()
	f.close()
	print("[MINIMAL_RUNNER] Loading: " + path)
	
	var script = load(path)
	if script == null:
		print("[MINIMAL_RUNNER] ERROR: load() returned null for " + path)
		get_tree().quit()
		return
	
	print("[MINIMAL_RUNNER] Script loaded OK")
	var node = Node2D.new()
	node.set_script(script)
	add_child(node)
	print("[MINIMAL_RUNNER] Node added to tree")

var _frame: int = 0
func _process(_delta):
	_frame += 1
	if _frame >= 120:
		print("[MINIMAL_RUNNER] Done (%d frames)" % _frame)
		get_tree().quit()
