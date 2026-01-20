extends SceneTree

func _init():
    var args = OS.get_cmdline_user_args()
    print("User Args: ", args)
    var file = ""
    for a in args:
        if a.ends_with(".bas"):
            file = a
            break
            
    if file == "":
        print("Usage: godot --script run_test.gd -- file.bas")
        quit()
        return

    var res_path = file
    if !res_path.begins_with("res://"):
        res_path = "res://" + file.get_file()

    print("Loading Script: ", res_path)
    var script = load(res_path)
    if script == null:
        print("Error: Could not load script ", res_path)
        quit()
        return

    # Use Node2D to support drawing
    var instance = Node2D.new()
    instance.set_name("VisualGasicTest")
    instance.set_script(script)
    root.add_child(instance)
    
    # We need to manually trigger draw for headless?
    # Notification Draw happens when viewport updates.
    # In headless, maybe not?
    # We can force call OnDraw if it exists, or emit Draw notification
    
    if instance.has_method("Main"):
        instance.call("Main")
    else:
        print("No Main() sub found.")
        
    print("Checking OnDraw...")
    if instance.has_method("OnDraw"):
         print("Calling OnDraw directly (Headless simulation)")
         instance.call("OnDraw")
         
    quit()
