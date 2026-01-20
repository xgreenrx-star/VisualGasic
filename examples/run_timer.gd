extends SceneTree

func _init():
    var script = load("res://test_timer.bas")
    var instance = Node.new()
    instance.set_name("VisualGasicNode")
    instance.set_script(script)
    get_root().add_child(instance)
    
    print("Runner calling Main...")
    instance.call("Main")
    print("Runner Main returned. Waiting for events...")
    
    # Create a failsafe timer to quit even if the script loops forever
    var t = Timer.new()
    t.wait_time = 3.0
    t.one_shot = true
    t.autostart = true
    t.timeout.connect(func():
        print("Timeout reached. Quitting.")
        quit()
    )
    get_root().add_child(t)
