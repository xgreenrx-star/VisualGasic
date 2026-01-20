extends SceneTree

func _init():
    print("Building Repro Angle Scene...")
    
    var root = Node2D.new()
    root.name = "Root"
    
    var script = load("res://pong/pong.bas") # Using the actual file location if possible, or copy it
    # Since res:// usually maps to project root.
    # The user's workspace has examples/pong/pong.bas
    # We should probably copy it to root or load it via path if VisualGasic supports absolute paths or relative?
    # Usually VisualGasic Script loading is via ResourceLoader.
    # GDExtension usually expects imported resources.
    
    # Let's hope the user is running the game from project root where pck is?
    # Or just assume we can load it if we place it right.
    # We will copy it to root for safety.
    
    var dir = DirAccess.open("res://")
    if dir:
        dir.copy("res://pong/pong.bas", "res://pong_angle.bas")
    
    var s = load("res://pong_angle.bas")
    if not s:
        print("Failed to load pong_angle.bas")
        quit(1)
        
    root.set_script(s)
    get_root().add_child(root)
    
    if root.has_method("_Ready"):
        root.call("_Ready")
        
    print("Running Loop...")
    var delta = 0.02
    
    # We want to simulate:
    # 1. Move Paddle UP (W key)
    # 2. Ball hitting paddle
    # 3. Check BallVelY change
    
    # We can't easily injection Input in headless without mocking.
    # But VisualGasicInstance access Input singleton.
    # We can only mock Input if we can write to Input (not possible via script easily).
    # OR we modified the script to check keys.
    
    # However, we can check the collision logic by moving paddle via script variable if exposed?
    # pong.bas checks IsKeyDown("W").
    
    # Alternative: We can modify the script for the test to Force P1Vy = -300
    # But we already modified the script to use IsKeyDown.
    
    # Let's simple Run it and see if it crashes first.
    # We can't verify the physics change purely via this unless we rewrite Input map or mock IsKeyDown?
    # VisualGasic checks OS::find_keycode.
    # Input.action_press? No, it uses is_key_pressed.
    # Input.parse_input_event? Maybe.
    
    for i in range(10):
        if root.has_method("_Process"):
            root.call("_Process", delta)
            
    quit()
