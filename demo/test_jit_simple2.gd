extends SceneTree
func _init():
    var script = load("res://jit_simple2.vg")
    if script == null:
        print("FAIL: load"); quit(); return
    var node := Node.new()
    node.set_script(script)
    root.add_child(node)
    for i in range(55):
        var result = node.call("CountTo", 10)
        if i >= 48:
            print("  Call ", i, ": CountTo(10) = ", result)
    root.remove_child(node)
    node.queue_free()
    print("Done!"); quit()
