extends SceneTree

func _init():
    var script = load("res://test_strings.vg")
    if not script:
        print("Failed to load script")
        quit()
        return

    var instance = Node.new()
    instance.set_script(script)
    root.add_child(instance)
    
    # We need a runner to wait a few frames
    var runner = Runner.new()
    root.add_child(runner)

class Runner extends Node:
    var frames = 0
    func _process(delta):
        frames += 1
        if frames >= 2:
            get_tree().quit()
