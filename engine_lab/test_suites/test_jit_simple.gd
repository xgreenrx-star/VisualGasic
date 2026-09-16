extends SceneTree

func _init():
    var script = load("res://jit_simple.vg")
    if script == null:
        print("Failed to load jit_simple.vg")
        quit()
        return
    var node := Node.new()
    node.set_script(script)
    root.add_child(node)
    print("Calling AddTwo 60 times...")
    for i in range(60):
        var result = node.call("AddTwo", 3, 7)
        if i == 0:
            print("  Result[0]: ", result, " (expected 10)")
        elif i == 59:
            print("  Result[59]: ", result, " (expected 10)")
    root.remove_child(node)
    node.queue_free()
    print("Done!")
    quit()
