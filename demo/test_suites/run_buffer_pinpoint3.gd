extends SceneTree

func _init():
    var script = load("res://test_buffer_pinpoint3.vg")
    if script == null:
        push_error("Failed to load script")
        quit()
        return
    var node = Node.new()
    node.set_script(script)
    var result = node.call("SimpleBuf")
    print("SimpleBuf result: " + str(result))
    if result == 42:
        print("PASS: SimpleBuf")
    else:
        print("FAIL: SimpleBuf = " + str(result) + " (expected 42)")
    quit()
