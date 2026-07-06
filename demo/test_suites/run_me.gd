extends SceneTree

func _init():
    pass

func _initialize():
    var script = load("res://test_doevents.vg")
    if script == null:
        print("Failed to load script")
        quit(1)
        return
        
    var instance = Node.new()
    instance.set_name("TestNode")
    instance.set_script(script)
    get_root().add_child(instance)
    
    print("Runner calling Main...")
    instance.call("Main")
    print("Runner finished.")
    
    quit()
