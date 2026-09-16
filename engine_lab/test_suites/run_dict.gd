extends SceneTree

func _init():
    var script = load("res://test_dict.vg")
    var instance = Node.new()
    instance.set_script(script)
    root.add_child(instance)
    
    print("Testing Dictionary...")
    instance.call("CheckDict")
    
    print("Testing Godot.Input (Mock)...")
    # We can't easily mock Godot.Input without an InputMap event, but we can verify it doesn't crash
    # and "Godot" returns the Engine.
    # Actually Godot is Engine. Input is a singleton. Engine doesn't have "Input" property.
    # Wait, Engine::get_singleton() returns the Engine singleton object.
    # Does Engine have a property named "Input"? No.
    # "Input" is a distinct singleton.
    # So Godot.Input will fail if Godot is just Engine.
    # We need Godot to be a namespace proxy.
    
    quit()
