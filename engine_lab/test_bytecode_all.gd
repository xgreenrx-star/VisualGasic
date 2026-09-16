extends SceneTree

func dump_func(script, name: String):
    var dump = script.debug_dump_bytecode(name)
    if dump.is_empty():
        print("No bytecode for " + name)
        return
    var insts = dump.get("instructions", [])
    print("\n=== " + name + " ===")
    print("Locals: " + str(dump.get("local_names", [])))
    print("Types: " + str(dump.get("local_types", [])))
    print("Constants: " + str(dump.get("constants", [])))
    for inst in insts:
        var op_name = inst.get("name", "?")
        var offset = inst.get("offset", 0)
        var operands = inst.get("operands", [])
        var op_str = ""
        if operands.size() > 0:
            op_str = "  " + str(operands)
        print("  [" + str(offset) + "] " + op_name + op_str)

func _init():
    var script = load("res://bench.vg")
    if script == null:
        push_error("Failed to load")
        quit(1)
    
    dump_func(script, "BenchArithmetic")
    dump_func(script, "BenchArraySum")
    dump_func(script, "BenchStringConcat")
    dump_func(script, "BenchBranch")
    dump_func(script, "BenchAllocations")
    
    print("\nDone!")
    quit(0)
