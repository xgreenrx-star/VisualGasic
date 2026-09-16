extends SceneTree

func _init():
    var script = VisualGasicScript.new()
    script.source_code = FileAccess.get_file_as_string("res://test_include.vg")
    script.reload(true)

    var node = Node.new()
    node.set_script(script)
    
    if node.has_method("Main"):
        node.call("Main")
    
    quit()
