extends SceneTree

var _node: Node
var _frame := 0

func _init() -> void:
	var script = load("res://test_suite/test_await_resource_lifetime.vg")
	if script == null:
		printerr("ERROR: Cannot load resource-lifetime fixture")
		quit(1)
		return
	_node = Node.new()
	_node.set_script(script)
	root.add_child(_node)

func _process(_delta: float) -> bool:
	_frame += 1
	if _node.get("AuditDone") == true:
		var weak: WeakRef = _node.get("AuditWeak")
		_node.free()
		if weak != null and weak.get_ref() == null:
			print("PASS: node destruction releases awaited resource")
			print("VG_SUITE_COMPLETED")
			quit()
		else:
			print("FAIL: node destruction releases awaited resource")
			quit(1)
	elif _frame >= 10:
		printerr("ERROR: Resource-lifetime fixture did not complete")
		_node.free()
		quit(1)
	return false
