extends SceneTree

func _init():
    var script = load("res://test_fa2.vg")
    if not script:
        print("LOAD FAILED")
        quit(1)
        return
    var obj = RefCounted.new()
    obj.set_script(script)
    obj.call("RunTest")
    quit(0)
