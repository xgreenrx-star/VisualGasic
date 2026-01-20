extends SceneTree

func _init():
    var script = load("res://test_loops.bas")
    if not script:
        print("Failed to load script")
        quit()
        return

    var obj = Node.new()
    obj.set_script(script)
    
    if obj.has_method("Main"):
        obj.Main()
    
    obj.free()
    quit()
