extends SceneTree
func _init():
    var s = load("res://test_pfor_lock_counters.vg")
    if not s:
        print("LOAD FAIL")
        quit()
        return
    var o = Node.new()
    o.set_script(s)
    if o.has_method("Main"): o.Main()
    o.free()
    quit()
