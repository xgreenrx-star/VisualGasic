extends SceneTree

func _init():
    var script = load("res://test_modern_features.vg")
    if not script:
        print("Failed to load script: res://test_modern_features.vg")
        quit()
        return

    var instance = Node.new()
    instance.set_script(script)
    
    print("Running Modern Features Test...")
    
    if instance.has_method("Main"):
        instance.call("Main")
    else:
        print("Error: Main method not found in script.")

    instance.free()
    print("--- Test Complete ---")
    quit()
