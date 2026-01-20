extends SceneTree

var timer = 0.0
var node
var clicked = false

func _init():
    print("Initializing Form Test...")
    var script = load("res://test_pro.bas")
    if script:
        node = Node2D.new()
        node.set_name("TestNode")
        get_root().add_child(node)
        node.set_script(script)
        node.call("Main")

func _process(delta):
    timer += delta
    
    # Simulate Click at 1 second
    if timer > 1.0 and not clicked:
        # We need to find the button and click it to test logic
        # But we don't have reference easily from here unless we search tree
        var buttons = []
        find_buttons(node, buttons)
        if buttons.size() > 0:
             print("Simulating Click on First Button")
             buttons[0].emit_signal("pressed")
             clicked = true
        
    if timer > 2.0:
        quit()
        return true
    return false

func find_buttons(n, list):
    if n.is_class("Button"):
        list.append(n)
    for c in n.get_children():
        find_buttons(c, list)
