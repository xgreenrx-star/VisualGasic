extends SceneTree
func _init():
    var script = load("res://jit_loop.vg")
    if script == null:
        print("FAIL"); quit(); return
    var node := Node.new()
    node.set_script(script)
    root.add_child(node)
    # Access internal chunk data
    print("Calling SumTo without JIT to check constants")
    var result = node.call("SumTo", 10)
    print("Result: ", result)
    print("Done!"); quit()
