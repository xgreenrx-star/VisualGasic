extends SceneTree

func _init():
    print("Running test_stopnote.vg...")
    var script = VisualGasicScript.new()
    var fa = FileAccess.open("res://test_stopnote.vg", FileAccess.READ)
    if fa == null:
        print("Could not open test_stopnote.vg")
        quit()
        return
        
    script.source_code = fa.get_as_text()
    var err = script.reload()
    if err != OK:
        print("Script load error: ", err)
        quit()
        return

    print("Script loaded. Creating instance...")
    
    var node = Node.new()
    root.add_child(node)
    node.set_script(script)
    
    # Let several frames run for _Process
    await create_timer(0.5).timeout
    
    quit()
