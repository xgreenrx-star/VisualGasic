extends SceneTree
func _init():
    var script = load("res://jit_loop.vg")
    if script == null:
        print("FAIL"); quit(); return
    var node := Node.new()
    node.set_script(script)
    root.add_child(node)
    # Run exactly 50 calls (compile at 49, first JIT at 49)
    for i in range(50):
        var result = node.call("SumTo", 10)
        if i >= 48:
            print("  Call ", i, ": ", result)
    root.remove_child(node)
    node.queue_free()
    print("Done!"); quit()
