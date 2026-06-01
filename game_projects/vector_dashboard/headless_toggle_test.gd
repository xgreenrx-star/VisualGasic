extends Node

func _ready():
    print("HEADLESS TEST: starting toggle")
    var handler_script = load("res://addons/visual_gasic/vg_debug_handler.gd")
    print("HEADLESS TEST: handler_script=", handler_script)
    if not handler_script:
        print("HEADLESS TEST: failed to load debug handler")
        get_tree().quit()
        return
    var handler = handler_script.new()
    print("HEADLESS TEST: handler=", handler)
    add_child(handler)
    if handler.has_method("_toggle_tweak_overlay"):
        handler._toggle_tweak_overlay()
        print("HEADLESS TEST: toggled overlay")
    else:
        print("HEADLESS TEST: handler missing _toggle_tweak_overlay")
    get_tree().quit()
