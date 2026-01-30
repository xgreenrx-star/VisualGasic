extends SceneTree

func _init():
    var script_source = FileAccess.get_file_as_string("res://test_exit.vg")
    
    var vg_script = VisualGasicScript.new()
    vg_script.source_code = script_source
    vg_script.reload(true)
    
    var node = Node.new()
    node.set_script(vg_script)
    
    print("Running Test Exit:")
    # node.call("Main") # Calling main wrapper if exits
    if node.has_method("Main"):
         node.call("Main")
    
    quit()
