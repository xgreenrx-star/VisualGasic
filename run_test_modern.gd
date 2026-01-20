extends SceneTree

func _init():
    print("Running test_modern.bas...")
    var script = VisualGasicScript.new()
    var fa = FileAccess.open("res://demo/test_modern.bas", FileAccess.READ)
    if fa == null:
        print("Could not open test_modern.bas")
        quit()
        return
        
    script.source_code = fa.get_as_text()
    var err = script.reload()
    if err != OK:
        print("Script load error: ", err)
        quit()
        return

    print("Script loaded. Creating instance...")
    
    var instance = script.new()
    if instance:
        print("Instance created.")
        if instance.has_method("Main"):
            print("Calling Main()...")
            instance.Main()
        else:
            print("Main method not found on instance.")
    else:
        print("Instance is null.")

    quit()
