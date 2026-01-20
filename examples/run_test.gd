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

    # If running from --path demo, the file is relative to that root usually?
    # Or just use the filename if it's in the root
    var res_path = file
    if !res_path.begins_with("res://"):
        # If it's just a filename, prepend res://
        # If it's a path, we strip dir?
        # Ideally we assume the test file is in the project root.
        res_path = "res://" + file.get_file()

    print("Loading Script: ", res_path)
    var script = load(res_path)
    if script == null:
        print("Error: Could not load script ", res_path)
        quit()
        return

    var instance = Node.new()
    instance.set_name("VisualGasicTest")
    instance.set_script(script)
    root.add_child(instance)

    if instance.has_method("Main"):
        instance.call("Main")
    else:
        print("No Main() sub found.")
        
    quit()
