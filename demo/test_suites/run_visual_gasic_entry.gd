extends SceneTree

func _init() -> void:
    var entry := ""
    var script_path := "res://bench.vg"
    var args : Array = []
    var raw_args := OS.get_cmdline_args()
    for token in raw_args:
        if token.begins_with("--entry="):
            entry = token.substr(8)
        elif token.begins_with("--script="):
            script_path = token.substr(9)
        elif token.begins_with("--args="):
            args = _parse_args(token.substr(7))
        elif token == "--help":
            _print_usage()
            quit(0)
            return
    if entry.is_empty():
        var env_entry := OS.get_environment("VG_ENTRY")
        if not env_entry.is_empty():
            entry = env_entry
    if script_path.is_empty() or script_path == "res://bench.vg":
        var env_script := OS.get_environment("VG_SCRIPT")
        if not env_script.is_empty():
            script_path = env_script
    if args.is_empty():
        var env_args := OS.get_environment("VG_ARGS")
        if not env_args.is_empty():
            args = _parse_args(env_args)
    if entry.is_empty():
        push_error("Missing --entry=<FunctionName>")
        quit(64)
        return
    var script: Script = load(script_path)
    if script == null:
        push_error("Failed to load %s" % script_path)
        quit(65)
        return
    var node: Node = Node.new()
    node.set_script(script)
    get_root().add_child(node)
    var start: int = Time.get_ticks_usec()
    var result: Variant = node.callv(entry, args)
    var elapsed: int = Time.get_ticks_usec() - start
    get_root().remove_child(node)
    node.queue_free()
    print("entry=", entry, " args=", args, " elapsed_us=", elapsed, " result=", result)
    quit(0)

func _parse_args(payload: String) -> Array:
    if payload.is_empty():
        return []
    var parsed : Array = []
    var parts := payload.split(",", false)
    for p in parts:
        var text := p.strip_edges()
        if text.is_empty():
            continue
        var value := text.to_float()
        if int(value) == value:
            parsed.append(int(value))
        else:
            parsed.append(value)
    return parsed

func _print_usage() -> void:
    print("Usage: godot --headless --path demo --script run_visual_gasic_entry.gd --entry=<Function> --args=a,b,...")
    print("Defaults: script_path=res://bench.bas; args are optional and passed directly via callv().")
