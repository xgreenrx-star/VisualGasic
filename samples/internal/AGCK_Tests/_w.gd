extends SceneTree
func _init():
	var s = load("res://_t.gd")
	var n = s.new()
	root.add_child(n)
