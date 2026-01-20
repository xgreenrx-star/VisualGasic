extends SceneTree

func _init():
    var script = load("res://test_select.bas")
    if not script:
        print("Failed to load script")
        quit()
        return

    var instance = Node.new()
    instance.set_script(script)
    
    print("Running Select Test...")
    
    if instance.has_method("Main"):
        instance.call("Main")
    else:
        print("Main not found")
    
    await process_frame
    quit()
