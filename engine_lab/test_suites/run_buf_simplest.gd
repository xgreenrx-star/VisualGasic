extends SceneTree

func _init():
    var script = load("res://test_buf_simplest.vg")
    var node = Node.new()
    node.set_script(script)
    var result = node.call("TestBuf")
    print("Result: " + str(result))
    quit()
