extends SceneTree

var obj: Node
var step = 0

func _init():
    var script = load("res://test_events.vg")
    if not script:
        print("Failed to load test_events.vg script")
        quit()
        return

    obj = Node.new()
    obj.set_name("EventTestRunner")
    obj.set_script(script)
    
    # Add to tree - triggers NOTIFICATION_READY which calls Form_Load
    get_root().call_deferred("add_child", obj)

func _process(_delta):
    step += 1
    if step == 2:
        # After node is added and processed, call Main
        print("")
        print("--- Calling Main() ---")
        if obj.has_method("Main"):
            obj.Main()
        print("")
    elif step == 4:
        # Remove from tree - triggers Form_Unload
        print("--- Removing from tree (triggers Form_Unload) ---")
        get_root().remove_child(obj)
    elif step == 6:
        print("")
        print("=== Event Handler Test Complete ===")
        obj.free()
        quit()
