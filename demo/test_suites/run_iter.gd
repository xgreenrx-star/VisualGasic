extends SceneTree

func _init():
    var script = load("res://test_const.vg")
    var instance = Node.new()
    instance.set_script(script)
    root.add_child(instance)
    
    instance.call("Main")
    
    quit()
