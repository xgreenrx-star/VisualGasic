extends SceneTree

func _init():
    var btn = Button.new()
    print("Button class:", btn.get_class())
    print("Initial disabled:", btn.disabled)
    print("Initial get(disabled):", btn.get("disabled"))
    print("Has property disabled:", "disabled" in btn.get_property_list().map(func(p): return p.name))
    btn.disabled = true
    print("After set to true, disabled:", btn.disabled)
    print("After set to true, get(disabled):", btn.get("disabled"))
    btn.disabled = false
    print("After set to false, disabled:", btn.disabled)
    
    # Test LineEdit
    var le = LineEdit.new()
    print("\nLineEdit class:", le.get_class())
    print("LineEdit has editable:", "editable" in le.get_property_list().map(func(p): return p.name))
    print("LineEdit editable:", le.editable)
    print("LineEdit get(editable):", le.get("editable"))
    print("LineEdit get(disabled):", le.get("disabled"))
    
    btn.queue_free()
    le.queue_free()
    quit()
