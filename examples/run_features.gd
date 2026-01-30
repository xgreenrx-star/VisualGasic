extends SceneTree

var timer = 0.0
var node

func _init():
    print("Initializing Test...")
    var script = load("res://test_features.vg")
    if script:
        node = Node2D.new()
        node.set_name("TestNode")
        get_root().add_child(node)
        node.set_script(script)
        
        # Call using call_deferred to ensure it runs inside the loop context if needed,
        # but calling directly is fine if node is in tree.
        # We invoke "Main" manually.
        node.call("Main")

func _process(delta):
    timer += delta
    if timer > 3.0:
        quit()
        return true
    return false
