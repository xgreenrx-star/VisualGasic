extends SceneTree
# Prints the optimized bytecode of each benchmark function.
# Usage: ... --script res://perf/vm_gap/dump_bytecode.gd [-- t_dict t_call]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var s: Script = load("res://perf/vm_gap/micro.vg")
	var n := Node.new()
	n.set_script(s)
	root.add_child(n)
	await process_frame
	var names: PackedStringArray = OS.get_cmdline_user_args()
	if names.is_empty():
		names = PackedStringArray(["t_local", "t_getx", "t_sety", "t_dict", "t_streq", "t_call", "t_vec"])
	for fn in names:
		n.call(fn, 10)
		var d: Dictionary = s.debug_dump_bytecode(fn)
		print("=== ", fn, "  constants=", d.constants)
		for ins: Dictionary in d.instructions:
			print("  %4d %-26s %s" % [ins.offset, ins.name, ins.detail])
	quit()
