extends SceneTree

func _init():
    var script_path = "demo/test_comprehensive.vg"
    
    print("Loading VisualGasic plugin...")
    var plugin = preload("res://addons/visual_gasic/plugin.gd")
    
    # Load the language
    var vg_lang = preload("res://addons/visual_gasic/visual_gasic.gdextension")
    
    # Try to create instance
    if ClassDB.class_exists("VisualGasicInstance"):
        var instance = ClassDB.instantiate("VisualGasicInstance")
        if instance:
            print("VisualGasicInstance created successfully")
            var source = FileAccess.get_file_as_string("res://" + script_path)
            if source and source.length() > 0:
                print("Source loaded: " + str(source.length()) + " bytes")
                print("Running test suite...\n")
                instance.load_string(source)
                instance.execute()
            else:
                print("ERROR: Could not load source file")
        else:
            print("ERROR: Could not create instance")
    else:
        print("ERROR: VisualGasicInstance class not found")
    
    quit()
