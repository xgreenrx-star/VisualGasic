extends SceneTree
# VG vs GDScript micro-benchmark. Best of 5 runs per case, ns per loop iteration.
# Usage: godot --headless --path test_proj --audio-driver Dummy --script res://perf/vm_gap/run_gap.gd
# Exit code 1 when a VG result differs from the GD result (correctness gate).

const N := 200000
const REPEATS := 5
const CASES := ["t_local", "t_global", "t_getx", "t_getx_typed", "t_sety", "t_dict",
	"t_streq", "t_call", "t_vec", "t_sin"]

func _initialize() -> void:
	run.call_deferred()

func make(path: String) -> Node:
	var n := Node.new()
	n.set_script(load(path))
	root.add_child(n)
	return n

func best_ns(node: Node, fn: String) -> Array:
	node.call(fn, 1000)
	var best := INF
	var result: Variant
	for r in REPEATS:
		var t0 := Time.get_ticks_usec()
		result = node.call(fn, N)
		best = minf(best, (Time.get_ticks_usec() - t0) * 1000.0 / N)
	return [best, result]

func run() -> void:
	var gd := make("res://perf/vm_gap/micro.gd")
	var vg := make("res://perf/vm_gap/micro.vg")
	await process_frame
	var mismatches := 0
	print("case            gd_ns    vg_ns   vg/gd")
	for fn: String in CASES:
		var g: Array = best_ns(gd, fn)
		var v: Array = best_ns(vg, fn)
		var same: bool = str(g[1]) == str(v[1])
		if not same:
			mismatches += 1
		print("%-14s %7.1f  %7.1f  %5.2f%s" % [fn, g[0], v[0], v[0] / g[0], "" if same else "  RESULT MISMATCH gd=%s vg=%s" % [g[1], v[1]]])
	var calls := 100000
	var t0 := Time.get_ticks_usec()
	for i in calls:
		gd.call("empty_fn")
	var gd_ext := (Time.get_ticks_usec() - t0) * 1000.0 / calls
	t0 = Time.get_ticks_usec()
	for i in calls:
		vg.call("empty_fn")
	var vg_ext := (Time.get_ticks_usec() - t0) * 1000.0 / calls
	print("%-14s %7.1f  %7.1f  %5.2f" % ["external_call", gd_ext, vg_ext, vg_ext / gd_ext])
	print("VM_GAP_DONE mismatches=%d" % mismatches)
	quit(1 if mismatches > 0 else 0)
