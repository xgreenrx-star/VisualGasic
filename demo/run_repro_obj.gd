extends SceneTree

func _init():
    print("Building Repro Object Scene...")
    
    # Root MUST be a Node that supports AddChild if script calls it?
    # CreateNode usually requires `owner` to be set.
    # In VisualGasicInstance, `owner` is the node running the script.
    
    # If script calls `AddChild`, it acts on `owner`.
    # `owner` must be a Node.
    
    var root = Node2D.new() # Node2D so it has position context if needed, and children
    root.name = "Root"
    
    var script = load("res://repro_obj.bas")
    if not script:
        print("Failed to load script")
        quit(1)
    
    root.set_script(script)
    get_root().add_child(root)
    
    if root.has_method("_Ready"):
        root.call("_Ready")
        
    print("Running Loop...")
    var delta = 0.02
    
    for i in range(10):
        if root.has_method("_Process"):
            root.call("_Process", delta)
            
    quit()
