extends SceneTree
func _init():
    var script = load("res://test_2d_array.vg")
    var obj = Node.new()
    obj.set_script(script)
    if obj.has_method("Main"):
        obj.Main()
    quit()
