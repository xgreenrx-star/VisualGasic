extends SceneTree

func _init():
    var script = load("res://test_type_checking.vg")
    if not script:
        print("Failed to load test script")
        quit()
        return

    var obj = Node.new()
    obj.set_name("TypeCheckTestRunner")
    obj.set_script(script)
    if obj.has_method("Main"):
        obj.Main()

    obj.free()
    quit()
