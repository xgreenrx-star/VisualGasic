extends SceneTree

func _init():
    print("=== VisualGasic Comprehensive Test Suite ===\n")
    
    var script = load("res://test_comprehensive.vg")
    if not script:
        print("Failed to load test script")
        quit()
        return
    
    var obj = Node.new()
    obj.set_name("TestRunner")
    obj.set_script(script)
    if obj.has_method("Main"):
        obj.Main()
    else:
        print("No Main() method found in script")
    
    obj.free()
    quit()
