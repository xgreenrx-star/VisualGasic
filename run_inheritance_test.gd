extends SceneTree

func _init():
    print("Running test_inheritance.vg...")
    var script = VisualGasicScript.new()
    var fa = FileAccess.open("res://test_inheritance.vg", FileAccess.READ)
    if fa == null:
        fa = FileAccess.open("res://demo/test_inheritance.vg", FileAccess.READ)
    if fa == null:
        print("Could not open test_inheritance.vg")
        quit()
        return
        
    script.source_code = fa.get_as_text()
    var err = script.reload()
    if err != OK:
        print("Script load error: ", err)
        quit()
        return

    print("Script loaded. Creating instance via Node attachment...")
    
    var node = Node.new()
    node.set_script(script)
    
    if node.get_script() == script:
        print("Script attached successfully.")
        if node.has_method("Main"):
            node.Main()
        else:
            print("No Main() - module-level code already ran.")
    else:
        print("Failed to attach script.")

    quit()
