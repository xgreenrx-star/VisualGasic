extends SceneTree

func _init():
    var script = load("res://test_datetime.vg")
    if not script:
        print("Failed to load test_datetime.vg script")
        quit()
        return

    var obj = Node.new()
    obj.set_name("DateTimeTestRunner")
    obj.set_script(script)
    if obj.has_method("Main"):
        obj.Main()

    obj.free()
    quit()
