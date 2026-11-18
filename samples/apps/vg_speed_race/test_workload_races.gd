extends SceneTree

const WORK_SIZE := 500

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
			for _warmup in 2:
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

	print("WORKLOAD_RACES_DONE")
	quit()
