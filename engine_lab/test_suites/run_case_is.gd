extends SceneTree

func _init():
    var script = load("res://test_case_is.vg")
    if not script:
        print("Failed to load test script")
        quit()
        return

    var obj = Node.new()
    obj.set_name("CaseIsTestRunner")
    obj.set_script(script)
    if obj.has_method("Main"):
        obj.Main()

    obj.free()
    quit()
