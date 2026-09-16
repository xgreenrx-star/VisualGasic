extends SceneTree

func _init():
    var script = load("res://bench.vg")
    if script == null:
        push_error("Failed to load bench.vg")
        quit(1)
    
    var dump = script.debug_dump_bytecode("BenchArithmetic")
    if dump.is_empty():
        push_error("Failed to dump bytecode")
        quit(1)
    
    print("=== BenchArithmetic Bytecode Dump ===")
    print("Local count: " + str(dump.get("local_count", 0)))
    print("Local names: " + str(dump.get("local_names", [])))
    print("Local types: " + str(dump.get("local_types", [])))
    print("Constants: " + str(dump.get("constants", [])))
    print("\nInstructions:")
    var insts = dump.get("instructions", [])
    for inst in insts:
        var op_name = inst.get("name", "?")
        var offset = inst.get("offset", 0)
        var line = inst.get("line", 0)
        var operands = inst.get("operands", [])
        var op_str = ""
        if operands.size() > 0:
            op_str = "  " + str(operands)
        print("  [" + str(offset) + "] " + op_name + op_str)
    
    print("\nDone!")
    quit(0)
