extends SceneTree
# VG vs GDScript micro-benchmark. Best of 5 runs per case, ns per loop iteration.
# Usage: godot --headless --path test_proj --audio-driver Dummy --script res://perf/vm_gap/run_gap.gd
# Exit code 1 when a VG result differs from the GD result (correctness gate).

const N := 200000
const REPEATS := 5
const CASES := ["t_local", "t_global", "t_gint", "t_gint_if", "t_getx", "t_getx_typed", "t_sety", "t_dict",
	"t_streq", "t_call", "t_call_args", "t_call_byref", "t_call_global", "t_call_host", "t_vec", "t_sin",
	"t_branch", "t_poly"]

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

func max_ratio_limit() -> float:
	# Empty = report only (historic behavior). Set VG_GAP_MAX_RATIO=1.00 to gate.
	var env := OS.get_environment("VG_GAP_MAX_RATIO").strip_edges()
	if env.is_empty():
		return INF
	return float(env)

func run() -> void:
	var gd := make("res://perf/vm_gap/micro.gd")
	var vg := make("res://perf/vm_gap/micro.vg")
	await process_frame
	var mismatches := 0
	var over_limit := 0
	var max_r := max_ratio_limit()
	print("case            gd_ns    vg_ns   vg/gd")
	for fn: String in CASES:
		var g: Array = best_ns(gd, fn)
		var v: Array = best_ns(vg, fn)
		var ratio: float = v[0] / g[0]
		var same: bool = str(g[1]) == str(v[1])
		if not same:
			mismatches += 1
		var note := ""
		if not same:
			note = "  RESULT MISMATCH gd=%s vg=%s" % [g[1], v[1]]
		elif max_r < INF and ratio > max_r:
			over_limit += 1
			note = "  OVER MAX %.2f" % max_r
		print("%-14s %7.1f  %7.1f  %5.2f%s" % [fn, g[0], v[0], ratio, note])
	var calls := 100000
	var t0 := Time.get_ticks_usec()
	for i in calls:
		gd.call("empty_fn")
	var gd_ext := (Time.get_ticks_usec() - t0) * 1000.0 / calls
	t0 = Time.get_ticks_usec()
	for i in calls:
		vg.call("empty_fn")
	var vg_ext := (Time.get_ticks_usec() - t0) * 1000.0 / calls
	var ext_ratio: float = vg_ext / gd_ext
	var ext_note := ""
	if max_r < INF and ext_ratio > max_r:
		over_limit += 1
		ext_note = "  OVER MAX %.2f" % max_r
	print("%-14s %7.1f  %7.1f  %5.2f%s" % ["external_call", gd_ext, vg_ext, ext_ratio, ext_note])
	print("VM_GAP_DONE mismatches=%d over_limit=%d max_ratio=%s" % [
		mismatches, over_limit, ("inf" if max_r >= INF else "%.2f" % max_r)])
	quit(1 if mismatches > 0 or over_limit > 0 else 0)
