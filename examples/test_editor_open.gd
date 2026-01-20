@tool
extends EditorScript

func _run():
    print("Trying to open script in editor...")
    var script = load("res://dodge/main.bas")
    if script:
        print("Script loaded: ", script)
        EditorInterface.edit_script(script)
        print("edit_script called.")
    else:
        print("Failed to load script.")
