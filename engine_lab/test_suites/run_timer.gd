extends SceneTree

func _init():
    var script = load("res://test_timer.vg")
    var instance = Node.new()
    instance.set_name("VisualGasicNode")
    instance.set_script(script)
    root.add_child(instance)
    
    print("Runner calling Main...")
    # NOTE: add_child works, but we should handle quit gracefully.
    instance.call("Main")
    print("Runner Main returned. Waiting for events...")

    
    # Do NOT quit here. Let the script quit itself.
    # How to keep headless alive?
    # By default headless quits after one frame if no Main Loop logic keeps it?
    # SceneTree should keep running?
    # We are extending SceneTree, so _init is like a main loop start.
    # We need to not return? Or return and let engine run?
    # If we return, the engine might exit if it thinks it's done.
    # But we added a node.
    pass
