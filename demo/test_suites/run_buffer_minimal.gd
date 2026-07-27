extends SceneTree

var _vg_script: Script = null

func _get_vg_script() -> Script:
    if _vg_script == null:
        _vg_script = load("res://test_buffer_minimal.vg")
    return _vg_script

func _init():
    var script = _get_vg_script()
    if script == null:
        push_error("Failed to load test_buffer_minimal.vg")
        quit()
        return
    
    var node = Node.new()
    node.set_script(script)
    
    var result = node.call("WriteReadBuffer", 100)
    # Sum of 0..99 = 99*100/2 = 4950
    var expected = 4950
    if result == expected:
        print("PASS: WriteReadBuffer(" + str(100) + ") = " + str(result))
    else:
        print("FAIL: WriteReadBuffer(" + str(100) + ") = " + str(result) + " (expected " + str(expected) + ")")
    
    quit()
