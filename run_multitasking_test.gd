extends SceneTree

func _init():
    var script = load("res://test_multitasking.vg")
    if not script:
        print("Failed to load multitasking test script")
        quit()
        return

    var instance = Node.new()
    instance.set_script(script)
    
    print("🧵 Running VisualGasic Multitasking Test...")
    print("============================================")
    
    if instance.has_method("Main"):
        instance.call("Main")
    else:
        print("Main method not found in script")
    
    print("")
    print("✅ Multitasking test runner completed!")
    
    await process_frame
    quit()