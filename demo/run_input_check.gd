extends SceneTree

func _init():
    var script = load("res://test_input.bas")
    var instance = Node.new()
    instance.set_script(script)
    root.add_child(instance)
    
    # We can't easily simulate input in headless without heavier mocking, 
    # but we just want to see if the script LOADS (parses) and runs without crashing on the token.
    print("Script loaded successfully.")
    
    # Force run the sub if it loaded
    instance.call("_Process", 0.16)
    
    quit()
