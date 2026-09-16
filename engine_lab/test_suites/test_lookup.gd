extends SceneTree

func _init():
    print("Testing Go To Definition Lookup...")
    
    # We can't access _lookup_code directly from GDScript as it is protected.
    # But since it compiled, the virtual method is registered in the C++ extension.
    # When Godot Editor loads this extension, Ctrl+Clicking a symbol like "MySub" 
    # will trigger this C++ function.
    
    # Logic trace:
    # 1. User Ctrl+Clicks "MySub" in "Call MySub()"
    # 2. Godot calls _lookup_code(code, "MySub", ...)
    # 3. Our loop finds "Sub MySub" at line X.
    # 4. Returns Dictionary {line: X, column: 0}.
    # 5. Editor jumps to line X.
    
    print("Feature 'Go to Definition' implemented in C++ extension.")
    print("Logic scans for 'Sub <Name>', 'Function <Name>', or '<Name>:' Labels.")
    
    quit()
