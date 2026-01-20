extends SceneTree

func _init():
    print("Building Pong Scene...")
    
    # Root Node
    var root = Node2D.new()
    root.name = "Root"
    
    # Ball
    var ball = Node2D.new() # Using Node2D as dummy sprite
    ball.name = "Ball"
    ball.position = Vector2(400, 300)
    root.add_child(ball) # Add child
    
    # Paddles
    var p1 = Node2D.new()
    p1.name = "Paddle1"
    p1.position = Vector2(50, 250)
    root.add_child(p1)
    
    var p2 = Node2D.new()
    p2.name = "Paddle2"
    p2.position = Vector2(750, 250)
    root.add_child(p2)
    
    # Attach Script
    var script = load("res://pong.bas")
    if not script:
        print("Failed to load pong.bas")
        quit(1)
        return
        
    print("Attaching Script...")
    root.set_script(script)
    
    # Add to Scene
    get_root().add_child(root)

    print("Running Simulation Loop...")
    
    var runner = Runner.new()
    runner.root_ref = root
    get_root().add_child(runner)

class Runner extends Node:
    var root_ref
    var frames = 0
    
    func _process(delta):
        frames += 1
        # print("Godot Frame: ", frames)
        if root_ref:
            var b = root_ref.get_node("Ball")
            if b:
                print("Frame ", frames, " Ball Pos: ", b.position)
        
        if frames >= 10:
            print("Simulation Complete.")
            get_tree().quit()
