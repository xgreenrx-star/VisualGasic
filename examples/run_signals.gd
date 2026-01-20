extends SceneTree

func _init():
    var script = load("res://test_signals.bas")
    var instance = Node.new()
    instance.set_script(script)
    root.add_child(instance)
    
    # Connect signal
    # Note: connect requires exact signal definition in the script for editor, but runtime connect uses object meta or script list?
    # GDExtension scripts must declare signals properly.
    if instance.has_signal("MySignal"):
        instance.connect("MySignal", _on_my_signal)
    else:
        print("Signal MySignal not found on instance!")
    
    # Trigger
    instance.call("RunTest")
    
    # Check Property
    print("Checking exported property MyProp: ", instance.get("MyProp"))
    instance.set("MyProp", 99)
    print("Checking exported property MyProp after set: ", instance.get("MyProp"))
    # quit() called in signal handler
    
    quit()

func _on_my_signal(val):
    print("Signal Received in GDScript! Value: ", val)
