extends SceneTree
func _init():
    var script = load("res://jit_intonly.vg")
    if script == null:
        print("FAIL: load"); quit(); return
    var node := Node.new()
    node.set_script(script)
    root.add_child(node)
    print("Testing Identity(42)")
    for i in range(55):
        var result = node.call("Identity", 42)
        if i >= 48:
            print("  Call ", i, ": Identity(42) = ", result)
    print("Testing AddTwo(3, 7)")
    for i in range(55):
        var result = node.call("AddTwo", 3, 7)
        if i >= 48:
            print("  Call ", i, ": AddTwo(3,7) = ", result)
    root.remove_child(node)
    node.queue_free()
    print("Done!"); quit()
