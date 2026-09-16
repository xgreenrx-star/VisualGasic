extends SceneTree

var _vg_script: Script = null

func _get_vg_script() -> Script:
    if _vg_script == null:
        _vg_script = load("res://bench.vg")
    return _vg_script

func _init():
    var script = _get_vg_script()
    if script == null:
        push_error("Failed to load bench.vg")
        quit()
        return
    
    var node = Node.new()
    node.set_script(script)
    
    # Test: allocate buffer, write bytes, read back
    var buf_func = node.get("BenchBuffer")
    if buf_func == null:
        print("FAIL: BenchBuffer not found")
        quit()
        return
    
    var result = buf_func.call(node, 1, 100)
    # Sum of 0..99 = 99*100/2 = 4950
    var expected = 4950
    if result == expected:
        print("PASS: BenchBuffer result = " + str(result))
    else:
        print("FAIL: BenchBuffer result = " + str(result) + " (expected " + str(expected) + ")")
    
    quit()
