extends SceneTree

func _init():
    var script = load("res://test_buf_minimal.vg")
    if script == null:
        push_error("Failed to load script")
        quit()
        return
    var node = Node.new()
    node.set_script(script)
    var result = node.call("TestBuf")
    print("TestBuf result: " + str(result))
    if result == 42:
        print("PASS: TestBuf")
    else:
        print("FAIL: TestBuf = " + str(result) + " (expected 42)")
    quit()
