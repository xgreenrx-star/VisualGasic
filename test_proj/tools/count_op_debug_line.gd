extends SceneTree
## Count OP_DEBUG_LINE opcodes per source line for a VG sub (headless bytecode audit).
## Usage:
##   godot --headless --path test_proj --script res://tools/count_op_debug_line.gd -- \
##     res://../samples/showcases/circuit_breaker/scripts/Play.vg TryStartMove

const OP_DEBUG_LINE := 126  # visual_gasic_bytecode.h (opcode_name switch may lag)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Usage: ... -- <script.vg> <SubName>")
		quit(1)
		return
	var script_path: String = args[0]
	var sub_name: String = args[1]
	if not ResourceLoader.exists(script_path):
		printerr("Script not found: ", script_path)
		quit(1)
		return
	var script: VisualGasicScript = load(script_path)
	if script == null:
		printerr("Failed to load VisualGasicScript")
		quit(1)
		return
	var dump: Dictionary = script.debug_dump_bytecode(sub_name)
	if dump.has("error"):
		printerr(dump["error"])
		quit(1)
		return
	var instructions: Array = dump.get("instructions", [])
	if instructions.is_empty():
		printerr("No instructions in bytecode dump")
		quit(1)
		return
	var per_line: Dictionary = {}
	var debug_hits := 0
	for inst in instructions:
		if int(inst.get("opcode", -1)) != OP_DEBUG_LINE:
			continue
		debug_hits += 1
		var ops: Array = inst.get("operands", [])
		var line_num := -1
		if ops.size() >= 2:
			line_num = int(ops[0]) | (int(ops[1]) << 8)
		elif ops.size() == 1:
			line_num = int(ops[0])
		if line_num >= 0:
			per_line[line_num] = int(per_line.get(line_num, 0)) + 1
	if debug_hits == 0:
		print("First opcodes in chunk:")
		for i in mini(12, instructions.size()):
			var ins = instructions[i]
			print("  ", ins.get("name", "?"), " opcode=", ins.get("opcode", "?"), " line=", ins.get("line", -1))
	print("=== OP_DEBUG_LINE counts for ", sub_name, " in ", script_path, " (", debug_hits, " total) ===")
	var lines: Array = per_line.keys()
	lines.sort()
	for ln in lines:
		var c: int = per_line[ln]
		if c > 1:
			print("  line ", ln, ": ", c, " checkpoints  <-- duplicate source line")
		else:
			print("  line ", ln, ": ", c)
	quit(0)
