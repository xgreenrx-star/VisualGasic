extends SceneTree

func _init():
    var script = load("res://bench.vg")
    if script == null:
        print("FAIL: cannot load bench.vg")
        quit()
        return
    var node := Node.new()
    node.set_script(script)
    root.add_child(node)
    print("Testing BenchArithmetic(10,10) — expected 650")
    for i in range(55):
        var result = node.call("BenchArithmetic", 10, 10)
        if result != 650:
            print("  MISMATCH at call ", i, ": got ", result, " expected 650")
        elif i == 0 or i == 49 or i == 50 or i == 51:
            print("  Call ", i, ": ", result, " OK")
    root.remove_child(node)
    node.queue_free()
    print("Done!")
    quit()
