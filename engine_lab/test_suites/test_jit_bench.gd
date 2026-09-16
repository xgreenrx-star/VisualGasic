extends SceneTree

func _init():
    var script = load("res://bench.vg")
    if script == null:
        print("Failed to load bench.vg")
        quit()
        return

    var node := Node.new()
    node.set_script(script)
    root.add_child(node)

    # Call BenchArithmetic 60 times to trigger JIT T2 (threshold=50)
    print("Calling BenchArithmetic 60 times...")
    for i in range(60):
        var result = node.call("BenchArithmetic", 10, 10)
        if i == 0:
            print("  First call result: ", result)
        elif i == 59:
            print("  Last call result: ", result)

    # Call BenchBranch 60 times
    print("Calling BenchBranch 60 times...")
    for i in range(60):
        var result = node.call("BenchBranch", 10, 10)
        if i == 0:
            print("  First call result: ", result)
        elif i == 59:
            print("  Last call result: ", result)

    root.remove_child(node)
    node.queue_free()
    print("Done!")
    quit()
