extends SceneTree

func _init():
    print("Loading test_modifiers.vg...")
    var script = load("res://test_modifiers.vg")
    if not script:
        print("FAIL: Could not load test_modifiers.vg")
        quit(1)
        return
        
    var node = Node.new()
    node.set_name("TestNode")
    root.add_child(node)
    
    print("Attaching Script...")
    node.set_script(script)
    
    print("Executing Main()...")
    if node.has_method("Main"):
        node.call("Main")
    else:
        print("FAIL: Main method not found via reflection.")
    
    print("Done.")
    quit(0)
