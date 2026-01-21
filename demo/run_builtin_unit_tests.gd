extends SceneTree

func _init():
    var tests = [
        "res://builtin_tests/01_string.bas",
        "res://builtin_tests/02_math.bas",
        "res://builtin_tests/03_array.bas",
    ]

    for tpath in tests:
        print("RUN_TEST:", tpath)
        var script = load(tpath)
        if not script:
            print("FAILED_LOAD:", tpath)
            continue
        var obj = Node.new()
        obj.set_script(script)
        if obj.has_method("Main"):
            obj.Main()
        obj.free()

    print("UNIT_TESTS_DONE")
    quit()
