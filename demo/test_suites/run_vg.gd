extends SceneTree

func _init():
    var args = OS.get_cmdline_user_args()
    var fname = "test_classes.vg"
    if args.size() > 0:
        fname = args[0]
    print("Running " + fname + "...")
    var script = VisualGasicScript.new()
    var fa = FileAccess.open("res://" + fname, FileAccess.READ)
    if fa == null:
        print("Could not open " + fname)
        quit()
        return
    script.source_code = fa.get_as_text()
    var err = script.reload()
    if err != OK:
        print("Script load error: ", err)
        quit()
        return
    var node = Node.new()
    node.set_script(script)
    if node.has_method("Main"):
        node.Main()
    else:
        print("Main method not found")
    node.queue_free()
    quit()
