extends SceneTree

func _init():
    var script = load("res://test_calls.bas")
    if not script:
        print("Failed to load script")
        quit()
        return

    var obj = Node.new()
    obj.set_name("OriginalName")
    
    # Check original name
    print("Original Name: ", obj.get_name())
    
    obj.set_script(script)
    
    if obj.has_method("Main"):
        print("Calling Main...")
        obj.Main()
    else:
        print("Main not found")
        
    print("New Name: ", obj.get_name())
    
    # Cleanup
    obj.free()
    quit()
