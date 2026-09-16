extends SceneTree

func _init():
    print("Building Debug Scene...")
    var root = Node.new()
    root.name = "Root"
    
    var script = load("res://debug_pong.vg")
    if not script:
        print("Failed to load script")
        quit(1)
        return
        
    print("Attaching Script...")
    root.set_script(script)
    get_root().add_child(root)
    
    # Manually trigger Ready to ensure variables are set
    if root.has_method("_Ready"):
        root.call("_Ready")
    
    print("Running Loop...")
    
    # Simulate frames at 0.02 (50fps)
    var delta = 0.02
    
    for i in range(10):
        print("--- Cycle " + str(i) + " ---")
        if root.has_method("_Process"):
            root.call("_Process", delta)
            
    quit()
