extends SceneTree

func _init():
    print("Loading test_pro.bas...")
    var script = load("res://test_pro.bas")
    if not script:
        print("Failed to load script")
        quit()
        return

    print("Instantiating script...")
    # print("Methods: ", script.get_method_list()) # This might be huge
    
    # Try different instantiation?
    # var instance = ClassDB.instantiate(script.get_instance_base_type())
    # instance.set_script(script)
    # This is how you manually attach.
    
    var instance = Node.new()
    instance.set_script(script)
    
    if not instance:
        print("Failed to instantiate")
        quit()
        return
        
    print("Instance created: ", instance)
    
    # Check if has method
    if instance.has_method("Main"):
        print("Instance has method 'Main'")
        print("Calling Main()...")
        instance.call("Main")
    else:
        print("Instance does NOT have method 'Main'")
        
        # Try finding why. 
        # has_method is implemented in my C++ code to return true for "Main".
    
    instance.free()
    quit()
