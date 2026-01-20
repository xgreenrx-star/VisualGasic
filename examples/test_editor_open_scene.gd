@tool
extends SceneTree

func _init():
    var interface = EditorInterface
    if interface:
        print("EditorInterface found.")
        print("Trying to open script in editor...")
        var script = load("res://dodge/main.bas")
        if script:
            print("Script loaded: ", script)
            interface.edit_script(script)
            print("edit_script called.")
        else:
            print("Failed to load script.")
    else:
        print("EditorInterface not found (expected in headless editor run).")
    
    quit()
