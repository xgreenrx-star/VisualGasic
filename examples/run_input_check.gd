extends SceneTree

func _init():
    print("Initializing Input Test...")
    var script = load("res://test_input.bas")
    var instance = Node.new()
    instance.set_script(script)
    get_root().add_child(instance)

    print("Script loaded successfully.")
    
    # We delay the call to 'Process' to allow the node to enter the tree.
    var t = Timer.new()
    t.wait_time = 0.5
    t.one_shot = true
    t.autostart = true 
    t.timeout.connect(func(): 
        print("Timer timeout. Calling Process manually.")
        if instance.is_inside_tree():
             instance.call("_Process", 0.16)
        else:
             print("Instance NOT in tree!")
             
        print("Input check finished without crash.")
        quit()
    )
    get_root().add_child(t)
    
    print("Waiting for timer...")
    # SceneTree should continue running
