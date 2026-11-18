extends SceneTree
# Headless correctness + speed smoke for vg_speed_race.
# Usage: godot --headless --path samples/apps/vg_speed_race --audio-driver Dummy \
#          --script res://run_headless_race.gd

const N := 3000
const STEPS := 30
const PANEL := 480.0

func _initialize() -> void:
	run.call_deferred()

func make(path: String) -> Node2D:
	var n := Node2D.new()
	n.set_script(load(path))
	root.add_child(n)
	return n

func run() -> void:
	await process_frame
	var gd := make("res://sim_gd.gd")
	var vg := make("res://sim_vg.vg")
	await process_frame
	if vg.get_script() == null:
		print("FAIL: sim_vg.vg did not load (is visual_gasic.gdextension registered?)")
		quit(1)
		return
	var fails := 0
	for use_calls in [true, false]:
		gd.call("reset", N, PANEL, PANEL, use_calls)
		vg.call("Reset", N, PANEL, PANEL, use_calls)
		# Warm the VG JIT before measuring.
		for _w in 16:
			gd.call("step", 1.0 / 60.0)
			vg.call("Step", 1.0 / 60.0)
		var sum_gd_usec := 0
		var sum_vg_usec := 0
		for s in STEPS:
			var a: float = float(gd.call("step", 1.0 / 60.0))
			var b: float = float(vg.call("Step", 1.0 / 60.0))
			if absf(a - b) > 0.05:
				fails += 1
				print("FAIL checksum mode_calls=%s step=%d gd=%s vg=%s" % [use_calls, s, a, b])
			sum_gd_usec += int(gd.get("last_usec"))
			sum_vg_usec += int(vg.get("LastUsec"))
		var mode := "calls" if use_calls else "inline"
		var avg_gd := float(sum_gd_usec) / float(STEPS)
		var avg_vg := float(sum_vg_usec) / float(STEPS)
		var ratio := avg_vg / avg_gd if avg_gd > 0.0 else 999.0
		print("mode=%s avg_gd_us=%.1f avg_vg_us=%.1f vg/gd=%.3f" % [mode, avg_gd, avg_vg, ratio])
		# Call mode should show a clear VG win (SUBSTEPS amplify t_call).
		# Inline stays near parity on Array storage; soft gate for noise.
		var limit := 0.60 if use_calls else 1.15
		if ratio > limit:
			fails += 1
			print("FAIL speed mode=%s ratio %.3f > %.2f" % [mode, ratio, limit])
	# Budget race: loop is inside each language (fair). VG should win on Calls.
	gd.call("reset", 500, PANEL, PANEL, true)
	vg.call("Reset", 500, PANEL, PANEL, true)
	for _w in 8:
		gd.call("run_budget", 2000, 1.0 / 60.0)
		vg.call("RunBudget", 2000, 1.0 / 60.0)
	var gd_ticks := 0
	var vg_ticks := 0
	for _s in 10:
		gd_ticks += int(gd.call("run_budget", 8000, 1.0 / 40.0))
		vg_ticks += int(vg.call("RunBudget", 8000, 1.0 / 40.0))
	var budget_ratio := float(vg_ticks) / float(maxi(gd_ticks, 1))
	print("budget_calls vg_ticks=%d gd_ticks=%d vg/gd_ticks=%.2f" % [vg_ticks, gd_ticks, budget_ratio])
	if budget_ratio < 1.15:
		fails += 1
		print("FAIL budget race: expected VG more ticks (ratio %.2f)" % budget_ratio)
	print("RACE_DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
