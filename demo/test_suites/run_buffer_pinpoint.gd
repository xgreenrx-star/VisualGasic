extends SceneTree

var _vg_script: Script = null

func _get_vg_script() -> Script:
    if _vg_script == null:
        _vg_script = load("res://test_buffer_pinpoint.vg")
    return _vg_script

func _init():
    var script = _get_vg_script()
    if script == null:
        push_error("Failed to load test_buffer_pinpoint.vg")
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
