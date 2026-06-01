extends SceneTree
func _init():
    var s = load("res://_gd_test_running.gd")
    if s == null:
        printerr("[gd-runner] cannot load staged test")
        quit(1)
        return
    var n: Node = s.new()
    root.add_child(n)
