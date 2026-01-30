extends SceneTree

func _init():
    var script_source = FileAccess.get_file_as_string("res://test_public.vg")
    
    var vg_script = VisualGasicScript.new()
    vg_script.source_code = script_source
    vg_script.reload(true)
    
    var node = Node.new()
    node.set_script(vg_script)
    
    print("Setting properties...")
    node.set("MySpeed", 99.5)
    node.set("PlayerName", "Commodore")
    
    print("Running Main...")
    if node.has_method("Main"):
        node.call("Main")
    
    quit()
