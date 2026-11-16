extends SceneTree

# Benchmark: Backlight City first-frame build, VG adapter vs GDScript adapter.
#
#   cd samples/games/ash_meridian_part1
#   xvfb-run -a <godot> --user-data-dir /tmp/vg-bench --path . -s bench_backlight_build.gd
#
# Env:
#   BENCH_RUNS  number of timed builds per adapter (default 3; best is reported)
#   BENCH_ONLY  "vg" or "gd" to time one adapter
#
# Prints one line per adapter plus BENCH_RATIO (vg / gd, lower is better).
# Must run rendered (not --headless): the build writes mesh surfaces.

func _initialize() -> void:
	call_deferred("_run")

func _time_adapter(which: String, runs: int) -> int:
	var best := -1
	for r in range(runs):
		var host := Node2D.new()
		root.add_child(host)
		var p: Node
		if which == "gd":
			p = Node.new()
			p.set_script(load("res://presentation.gd"))
		else:
			p = ClassDB.instantiate("Node")
			p.set_script(load("res://presentation.vg"))
		p.name = "Presentation"
		host.add_child(p)
		await process_frame
		await process_frame
		p.call("start_backlight_city")
		p.call("begin_frame", true)
		var t1 := Time.get_ticks_usec()
		p.call("draw_backlight_city", 0.5, 220.0, 1)
		var t2 := Time.get_ticks_usec()
		var city = p.get("backlight_city")
		var verts: int = city.world.mesh.surface_get_array_len(0) if city and city.get("world") else -1
		var us := t2 - t1
		print("BENCH_", which.to_upper(), "_RUN=", r, " build_us=", us, " verts=", verts)
		if best < 0 or us < best:
			best = us
		host.queue_free()
		await process_frame
	return best

func _run() -> void:
	var runs := int(OS.get_environment("BENCH_RUNS")) if OS.get_environment("BENCH_RUNS") != "" else 3
	var only := OS.get_environment("BENCH_ONLY")
	var gd_best := -1
	var vg_best := -1
	if only != "vg":
		gd_best = await _time_adapter("gd", runs)
		print("BENCH_GD_BEST_US=", gd_best)
	if only != "gd":
		vg_best = await _time_adapter("vg", runs)
		print("BENCH_VG_BEST_US=", vg_best)
	if gd_best > 0 and vg_best > 0:
		print("BENCH_RATIO=", String.num(float(vg_best) / float(gd_best), 2))
	quit()
