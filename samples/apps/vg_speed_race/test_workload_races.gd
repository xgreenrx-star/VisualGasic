extends SceneTree

const WORK_SIZE := 500
const MEASUREMENTS := 7

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var gd := Node2D.new()
	gd.set_script(load("res://sim_gd.gd"))
	root.add_child(gd)
	var vg := Node2D.new()
	vg.set_script(load("res://sim_vg.vg"))
	root.add_child(vg)
	await process_frame

	for mode in 7:
		for use_calls in [true, false]:
			if mode != 0 and mode != 6 and not use_calls:
				continue
			vg.call("SelectWorkload", mode)
			gd.call("select_workload", mode)
			vg.call("Reset", WORK_SIZE, 420.0, 420.0, use_calls)
			gd.call("reset", WORK_SIZE, 420.0, 420.0, use_calls)
			for _warmup in 64:
				vg.call("Step", 1.0 / 40.0)
				gd.call("step", 1.0 / 40.0)
			var vg_checksum := float(vg.get("LastChecksum"))
			var gd_checksum := float(gd.get("last_checksum"))
			if absf(vg_checksum - gd_checksum) > 0.05:
				push_error(
					"Checksum mismatch: mode=%d calls=%s gd=%s vg=%s"
					% [mode, use_calls, gd_checksum, vg_checksum]
				)
				quit(1)
				return
			var vg_samples: Array[float] = []
			var gd_samples: Array[float] = []
			for sample in MEASUREMENTS:
				var first_vg := sample % 2 == 0
				for lane in 2:
					if (lane == 0) == first_vg:
						vg.call("Step", 1.0 / 40.0)
						vg_samples.append(float(vg.get("LastUsec")))
					else:
						gd.call("step", 1.0 / 40.0)
						gd_samples.append(float(gd.get("last_usec")))
				vg_checksum = float(vg.get("LastChecksum"))
				gd_checksum = float(gd.get("last_checksum"))
				if absf(vg_checksum - gd_checksum) > 0.05:
					push_error(
						"Measured checksum mismatch: mode=%d calls=%s gd=%s vg=%s"
						% [mode, use_calls, gd_checksum, vg_checksum]
					)
					quit(1)
					return
			var gd_median := _median(gd_samples)
			var vg_median := _median(vg_samples)
			var workload_names: Array[String] = [
				"particles", "arithmetic", "array", "dictionary", "branching",
				"strings", "calls",
			]
			var workload_name: String = workload_names[mode]
			print(
				"RACE_TIMING workload=%s calls=%s gd_us=%d vg_us=%d vg/gd=%.3f checksum=%.2f"
				% [workload_name, use_calls, int(gd_median), int(vg_median),
					vg_median / gd_median if gd_median > 0.0 else 0.0, vg_checksum]
			)
			vg.call("Reset", WORK_SIZE, 420.0, 420.0, use_calls)
			gd.call("reset", WORK_SIZE, 420.0, 420.0, use_calls)
			var vg_ticks := 0
			var gd_ticks := 0
			for sample in 10:
				if sample % 2 == 0:
					vg_ticks += int(vg.call("RunBudget", 8000, 1.0 / 40.0))
					gd_ticks += int(gd.call("run_budget", 8000, 1.0 / 40.0))
				else:
					gd_ticks += int(gd.call("run_budget", 8000, 1.0 / 40.0))
					vg_ticks += int(vg.call("RunBudget", 8000, 1.0 / 40.0))
			print(
				"RACE_BUDGET workload=%s calls=%s gd_ticks=%d vg_ticks=%d vg/gd=%.3f"
				% [workload_name, use_calls, gd_ticks, vg_ticks,
					float(vg_ticks) / float(gd_ticks) if gd_ticks > 0 else 0.0]
			)

	print("WORKLOAD_RACES_DONE")
	quit()

func _median(samples: Array[float]) -> float:
	samples.sort()
	return samples[samples.size() / 2]
