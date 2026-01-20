extends SceneTree

func _init():
    var script = load("res://test_full.bas")
    if not script:
        print("Failed to load script")
        quit()
        return

    var obj = Node.new()
    obj.set_name("Original")
    obj.set_script(script)
    
    if obj.has_method("Main"):
        obj.Main()
    
    print("Final Name: ", obj.get_name())
    # Verify meta execution directly
    if obj.has_meta("TestKey"):
        print("Meta TestKey found on object: ", obj.get_meta("TestKey"))
    
    obj.free()
    quit()
