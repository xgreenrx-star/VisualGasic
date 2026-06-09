extends SceneTree

func _init():
	var s = load("res://test_redim_packed.vg")
	var n = Node.new()
	n.set_script(s)
	root.add_child(n)
	n.call("Main")
	quit()
