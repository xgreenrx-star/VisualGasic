extends SceneTree
func _init():
    var script = load("res://test_exit_do.vg")
    if script:
        var obj = Node.new()
        obj.set_script(script)
        if obj.has_method("Main"):
            obj.Main()
        obj.free()
    quit()
