extends SceneTree

func _init():
    var script = load("res://test_error.vg")
    if not script:
        print("Failed to load script: res://test_error.vg")
        quit()
        return

    # Create a Node and attach the script
    var instance = Node.new()
    instance.set_script(script)
    
    print("Running Error Test...")
    
    # We expect 'Main' to be available as a method on the instance
    if instance.has_method("Main"):
        instance.call("Main")
    else:
        print("Error: Main method not found in script.")
    
    quit()
    quit()
