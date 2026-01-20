extends SceneTree

func _init():
    var script = load("res://test_multi_array.bas")
    if not script:
        print("Failed to load script")
        quit()
        return

    var instance = Node.new()
    instance.set_script(script)
    
    print("Running Multidimensional Array Test...")
    
    if instance.has_method("Main"):
        instance.call("Main")
    else:
        print("Main not found")
    
    await process_frame
    quit()
