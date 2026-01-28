extends SceneTree

func _init() -> void:
    var args = OS.get_cmdline_args()
    var entries = []
    var script_path = "res://bench.bas"
    var json_mode = false
    var output_path = ""
    for arg in args:
        if arg.begins_with("--entry="):
            var single = arg.substr(8)
            if single.length() > 0:
                entries.append(single)
        elif arg.begins_with("--entries="):
            var packed = arg.substr(10).split(",", false)
            for name in packed:
                if String(name).length() > 0:
                    entries.append(name)
        elif arg.begins_with("--script="):
            script_path = arg.substr(9)
        elif arg == "--json":
            json_mode = true
        elif arg.begins_with("--out="):
            output_path = arg.substr(6)
    if entries.is_empty():
        entries.append("BenchArraySum")
    _dump_bytecode(script_path, entries, json_mode, output_path)

func _dump_bytecode(script_path: String, entries: Array, json_mode: bool, output_path: String) -> void:
    var script = load(script_path)
    if script == null:
        push_error("Failed to load %s" % script_path)
        quit(1)
        return

    if script.has_method("reload"):
        var err = script.reload()
        if err != OK:
            push_error("Reload failed for %s" % script_path)
            quit(1)
            return

    var dumps = []
    for entry in entries:
        var dump = script.call("debug_dump_bytecode", entry)
        if typeof(dump) != TYPE_DICTIONARY:
            push_error("Unexpected dump payload for %s" % entry)
            quit(1)
            return
        if dump.has("error"):
            push_error("Failed to dump %s: %s" % [entry, dump["error"]])
            quit(1)
            return
        dumps.append(dump)

    if json_mode:
        var payload = {
            "script_path": script_path,
            "entries": dumps,
        }
        if not _emit_output(JSON.stringify(payload, "  "), output_path):
            quit(1)
            return
    else:
        if not output_path.is_empty():
            push_error("--out is only supported together with --json")
            quit(1)
            return
        for i in range(dumps.size()):
            if i > 0:
                print("")
            _print_dump(dumps[i])
    quit(0)

func _print_dump(dump: Dictionary) -> void:
    var entry := String(dump.get("entry_point", ""))
    print("Bytecode dump for %s" % entry)

    var local_names : PackedStringArray = dump.get("local_names", PackedStringArray())
    var local_types : PackedByteArray = dump.get("local_types", PackedByteArray())
    var local_count : int = int(dump.get("local_count", local_names.size()))
    print("Locals (%d)" % local_count)
    for i in local_names.size():
        var type_id := local_types[i] if i < local_types.size() else -1
        print("  [%02d] %s (type=%d)" % [i, local_names[i], type_id])

    var constants : Array = dump.get("constants", [])
    print("\nConstants (%d)" % constants.size())
    for i in constants.size():
        print("  [%02d] %s" % [i, constants[i]])

    var code : PackedByteArray = dump.get("code", PackedByteArray())
    var instructions : Array = dump.get("instructions", [])
    print("\nInstructions (%d bytes)" % code.size())
    for inst in instructions:
        var offset := int(inst.get("offset", 0))
        var name := String(inst.get("name", "OP_UNKNOWN"))
        var detail := String(inst.get("detail", ""))
        if detail.is_empty():
            var operands = inst.get("operands", [])
            detail = str(operands) if operands.size() > 0 else ""
        var line_num := int(inst.get("line", -1))
        if line_num >= 0:
            print("%04d  %-24s %s (line %d)" % [offset, name, detail, line_num])
        else:
            print("%04d  %-24s %s" % [offset, name, detail])

func _emit_output(text: String, output_path: String) -> bool:
    if output_path.is_empty():
        print(text)
        return true

    var resolved := _resolve_output_path(output_path)
    var dir_path := resolved.get_base_dir()
    var dir_err := DirAccess.make_dir_recursive_absolute(dir_path)
    if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
        push_error("Failed to prepare directory %s (err=%d)" % [dir_path, dir_err])
        return false

    var file := FileAccess.open(resolved, FileAccess.WRITE)
    if file == null:
        push_error("Failed to open %s for writing" % resolved)
        return false
    file.store_string(text)
    file.store_string("\n")
    file.flush()
    print("Wrote bytecode dump to %s" % resolved)
    return true

func _resolve_output_path(path: String) -> String:
    if path.is_empty():
        return path
    if path.begins_with("res://") or path.begins_with("user://"):
        return ProjectSettings.globalize_path(path)
    if _is_absolute_path(path):
        return path
    var project_root := ProjectSettings.globalize_path("res://")
    return project_root.path_join(path)

func _is_absolute_path(path: String) -> bool:
    if path.is_empty():
        return false
    if path.begins_with("/"):
        return true
    if path.length() > 1 and path[1] == ":":
        return true
    return false