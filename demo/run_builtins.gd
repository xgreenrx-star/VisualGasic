extends SceneTree

func _init():
    var script = load("res://test_builtins.bas")
    if not script:
        print("Failed to load builtin test script")
        quit()
        return

    var obj = Node.new()
    obj.set_name("BuiltinTestRunner")
    obj.set_script(script)
    if obj.has_method("Main"):
        obj.Main()

    obj.free()
    quit()
