extends SceneTree
func _init():
    var script = load("res://jit_loop.vg")
    if script == null:
        print("FAIL"); quit(); return
    var node := Node.new()
    node.set_script(script)
    root.add_child(node)
    print("Testing SumTo(10) — expected 10")
    for i in range(55):
        var result = node.call("SumTo", 10)
        if result != 10:
            print("  MISMATCH at call ", i, ": got ", result)
        elif i == 0 or i == 49 or i == 54:
            print("  Call ", i, ": ", result, " OK")
    root.remove_child(node)
    node.queue_free()
    print("Done!"); quit()
