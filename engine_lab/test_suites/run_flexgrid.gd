extends SceneTree

func _init():
    print("Loading test_flexgrid.vg...")
    var script = load("res://test_flexgrid.vg")
    if script:
        var node = Node2D.new()
        get_root().add_child(node)
        node.set_script(script)
        print("Running Main...")
        node.call("Main")
    else:
        print("Failed to load script")
    quit()
