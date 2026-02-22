extends SceneTree

func _init():
    var interpreter = ClassDB.instantiate("VisualGasic")
    
    var file = FileAccess.open("res://examples/test_xojo_features.vg", FileAccess.READ)
    if not file:
        print("Error: Could not open test file")
        quit(1)
        return
        
    var source_code = file.get_as_text()
    
    # Setup output capture
    # Assuming VisualGasic has a signal 'print_output' or we rely on stdout capture if we can't hook it
    # Based on previous tests, it seems we rely on standard output or signals.
    # Let's check how run_tests.gd does it: it probably uses the 'print_message' signal if available, or just runs it.
    
    interpreter.set_source_code(source_code)
    var err = interpreter.compile()
    
    if err != OK:
        print("Compilation Error: ", err)
        quit(1)
        return
        
    print("Compilation Successful. Running...")
    interpreter.run()
    
    # We rely on the script printing to stdout via the engine's print or custom signal
    # If VisualGasic uses `UtilityFunctions::print`, it goes to stdout.
    
    quit(0)
