extends SceneTree

func _init():
    print("Checking available classes...")
    print("VisualGasicInstance exists: " + str(ClassDB.class_exists("VisualGasicInstance")))
    print("VisualGasicForm exists: " + str(ClassDB.class_exists("VisualGasicForm")))
    print("VisualGasicLanguage exists: " + str(ClassDB.class_exists("VisualGasicLanguage")))
    
    # Try to get all classes with "Visual" in name
    var all_classes = ClassDB.get_class_list()
    print("\nClasses containing 'Visual':")
    for c in all_classes:
        if c.to_lower().contains("visual"):
            print("  - " + c)
    
    quit()
