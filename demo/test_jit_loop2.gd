extends SceneTree
func _init():
    var script = load("res://jit_loop.vg")
    if script == null:
        print("FAIL"); quit(); return
    var node := Node.new()
    node.set_script(script)
    root.add_child(node)
    print("Testing SumTo(10) — call by call")
    for i in range(55):
        print("  Before call ", i)
        var result = node.call("SumTo", 10)
        print("  After call ", i, ": ", result)
    root.remove_child(node)
    node.queue_free()
    print("Done!"); quit()
