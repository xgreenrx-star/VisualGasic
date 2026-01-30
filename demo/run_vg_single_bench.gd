extends SceneTree

func _init():
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("Usage: godot --script run_vg_single_bench.gd <FunctionName> [arg1 arg2 ...]")
        quit(64)
        return

    var func_name: String = args[0]
    var call_args: Array = []
    for i in range(1, args.size()):
        var raw: String = args[i]
        if raw.is_valid_int():
            call_args.append(int(raw))
        elif raw.is_valid_float():
            call_args.append(float(raw))
        else:
            call_args.append(raw)

    var script: Script = load("res://bench.vg")
    if script == null:
        push_error("Failed to load bench.vg")
        quit(65)
        return

    var node := Node.new()
    node.set_script(script)
    root.add_child(node)

    var start := Time.get_ticks_usec()
    var checksum: Variant = node.callv(func_name, call_args)
    var elapsed := Time.get_ticks_usec() - start

    var payload: Dictionary = {
        "func": func_name,
        "args": call_args,
        "elapsed_us": elapsed,
        "checksum": checksum
    }
    print(JSON.stringify(payload))

    root.remove_child(node)
    node.queue_free()
    quit(0)
