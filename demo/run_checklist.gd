extends SceneTree

func _init():
    print("Running checklist tests...")
    var script = VisualGasicScript.new()
    var fa = FileAccess.open("res://test_checklist.vg", FileAccess.READ)
    if fa == null:
        print("Could not open test_checklist.vg")
        quit()
        return
        
    script.source_code = fa.get_as_text()
    fa.close()
    
    var err = script.reload()
    if err != OK:
        print("Script load error: ", err)
        quit()
        return

    var node = Node.new()
    node.set_script(script)
    
    if node.has_method("Main"):
        node.Main()
    else:
        print("Main method not found")

    quit()
