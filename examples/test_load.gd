extends SceneTree

func _init():
    print("Checking for VisualGasic class...")
    var exists = ClassDB.class_exists("VisualGasic")
    print("VisualGasic class exists: ", exists)
    quit()
