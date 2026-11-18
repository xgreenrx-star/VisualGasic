extends SceneTree
# Runs one VG benchmark case for a long time so `perf record` can sample it.
# Usage: ... --script res://perf/vm_gap/hot_case.gd -- t_dict [iterations]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var fn: String = args[0] if args.size() > 0 else "t_dict"
	var n_iter: int = int(args[1]) if args.size() > 1 else 20000000
	var n := Node.new()
	n.set_script(load("res://perf/vm_gap/micro.vg"))
	root.add_child(n)
	await process_frame
	var t0 := Time.get_ticks_usec()
	var r: Variant = 0
	if fn == "external":
		for i in n_iter:
			n.call("empty_fn")
	else:
		r = n.call(fn, n_iter)
	print("%s %.1f ns/iter result=%s" % [fn, (Time.get_ticks_usec() - t0) * 1000.0 / n_iter, r])
	quit()
