extends SceneTree

const TIER_B_OPS := 100_000
const NODE_OUTER := 100
const NODE_INNER := 1_000
const GAMEPLAY_TICKS := 500
const ENTITY_COUNT := 64

const VG_SCRIPT := preload("res://bench.vg")

var _vg_script: Script = null


func _get_vg_script() -> Script:
	if _vg_script == null:
		_vg_script = load("res://bench.vg")
	return _vg_script


func run_visual_gasic(func_name: String, args: Array) -> Dictionary:
	var script := _get_vg_script()
	if script == null:
		push_error("Failed to load bench.vg")
		return {}

	var node := Node.new()
	node.set_script(script)
	root.add_child(node)

	var start := Time.get_ticks_usec()
	var checksum = node.callv(func_name, args)
	var elapsed := Time.get_ticks_usec() - start

	root.remove_child(node)
	node.queue_free()

	return {"elapsed_us": elapsed, "checksum": checksum}


func _gp_call_leaf(x: int) -> int:
	return x + 1


func _gp_call_mid(x: int) -> int:
	return _gp_call_leaf(x)


func _gp_call_root(x: int) -> int:
	return _gp_call_mid(x)


func bench_gd_integer_loop(ops: int) -> Dictionary:
	var s := 0
	var start := Time.get_ticks_usec()
	for i in ops:
		s += (i * 3) - 7
	var elapsed := Time.get_ticks_usec() - start
	return {"elapsed_us": elapsed, "checksum": s, "ops": ops}


func bench_vg_integer_loop(ops: int) -> Dictionary:
	var r := run_visual_gasic("BenchIntegerLoop", [ops])
	r["ops"] = ops
	return r


func bench_gd_float_loop(ops: int) -> Dictionary:
	var f := 0.0
	var start := Time.get_ticks_usec()
	for i in ops:
		f += 0.001
	var elapsed := Time.get_ticks_usec() - start
	return {"elapsed_us": elapsed, "checksum": int(f * 1000.0), "ops": ops}


func bench_vg_float_loop(ops: int) -> Dictionary:
	var r := run_visual_gasic("BenchFloatLoop", [ops])
	r["ops"] = ops
	return r


func bench_gd_local_calls(ops: int) -> Dictionary:
	var s := 0
	var start := Time.get_ticks_usec()
	for i in ops:
		s = _gp_call_leaf(s)
	var elapsed := Time.get_ticks_usec() - start
	return {"elapsed_us": elapsed, "checksum": s, "ops": ops}


func bench_vg_local_calls(ops: int) -> Dictionary:
	var r := run_visual_gasic("BenchLocalCalls", [ops])
	r["ops"] = ops
	return r


func bench_gd_call_chain(ops: int) -> Dictionary:
	var s := 0
	var start := Time.get_ticks_usec()
	for i in ops:
		s = _gp_call_root(s)
	var elapsed := Time.get_ticks_usec() - start
	return {"elapsed_us": elapsed, "checksum": s, "ops": ops}


func bench_vg_call_chain(ops: int) -> Dictionary:
	var r := run_visual_gasic("BenchCallChain", [ops])
	r["ops"] = ops
	return r


func bench_gd_node_property_churn(outer: int, inner: int) -> Dictionary:
	if outer <= 0 or inner <= 0:
		return {"elapsed_us": 0, "checksum": 0, "ops": 0}
	var node := Node.new()
	var prefix := "gp_"
	var checksum := 0
	var start := Time.get_ticks_usec()
	for _i in outer:
		for j in inner:
			node.name = prefix + str(j)
			checksum += node.name.length()
	node.queue_free()
	var elapsed := Time.get_ticks_usec() - start
	return {"elapsed_us": elapsed, "checksum": checksum, "ops": outer * inner}


func bench_vg_node_property_churn(outer: int, inner: int) -> Dictionary:
	var r := run_visual_gasic("BenchNodePropertyChurn", [outer, inner])
	r["ops"] = outer * inner
	return r


func bench_gd_array_iterate(ticks: int, size: int) -> Dictionary:
	if ticks <= 0 or size <= 0:
		return {"elapsed_us": 0, "checksum": 0, "ops": 0}
	var arr: Array = []
	arr.resize(size)
	for i in size:
		arr[i] = i % 17
	var sum := 0
	var start := Time.get_ticks_usec()
	for _t in ticks:
		for item in arr:
			sum += int(item)
	var elapsed := Time.get_ticks_usec() - start
	return {"elapsed_us": elapsed, "checksum": sum, "ops": ticks * size}


func bench_vg_array_iterate(ticks: int, size: int) -> Dictionary:
	var r := run_visual_gasic("BenchArrayIterate", [ticks, size])
	r["ops"] = ticks * size
	return r


func bench_gd_dictionary_scan(ticks: int, size: int) -> Dictionary:
	if ticks <= 0 or size <= 0:
		return {"elapsed_us": 0, "checksum": 0, "ops": 0}
	var dict := {}
	var keys: Array = []
	keys.resize(size)
	for i in size:
		var key := "k" + str(i)
		keys[i] = key
		dict[key] = i * 3
	var sum := 0
	var start := Time.get_ticks_usec()
	for _t in ticks:
		for k in keys:
			sum += int(dict[k])
	var elapsed := Time.get_ticks_usec() - start
	return {"elapsed_us": elapsed, "checksum": sum, "ops": ticks * size}


func bench_vg_dictionary_scan(ticks: int, size: int) -> Dictionary:
	var r := run_visual_gasic("BenchDictionaryScan", [ticks, size])
	r["ops"] = ticks * size
	return r


func bench_gd_entity_think(ticks: int, entities: int) -> Dictionary:
	if ticks <= 0 or entities <= 0:
		return {"elapsed_us": 0, "checksum": 0, "ops": 0}
	var hp := PackedInt64Array()
	var state := PackedInt64Array()
	hp.resize(entities)
	state.resize(entities)
	for i in entities:
		hp[i] = 100 + (i % 7)
		state[i] = i % 4
	var sum := 0
	var start := Time.get_ticks_usec()
	for _t in ticks:
		for i in entities:
			if state[i] == 0:
				hp[i] -= 1
			elif state[i] == 1:
				hp[i] += 2
			else:
				state[i] = (state[i] + 1) % 4
			sum += hp[i] + state[i]
	var elapsed := Time.get_ticks_usec() - start
	return {"elapsed_us": elapsed, "checksum": sum, "ops": ticks * entities}


func bench_vg_entity_think(ticks: int, entities: int) -> Dictionary:
	var r := run_visual_gasic("BenchEntityThink", [ticks, entities])
	r["ops"] = ticks * entities
	return r


func bench_gd_batch_nearest(ticks: int, entities: int) -> Dictionary:
	if ticks <= 0 or entities <= 0:
		return {"elapsed_us": 0, "checksum": 0, "ops": 0}
	var px := PackedInt64Array()
	var py := PackedInt64Array()
	px.resize(entities)
	py.resize(entities)
	for i in entities:
		px[i] = (i % 16) * 10
		py[i] = (i % 13) * 8
	var tx := 80
	var ty := 52
	var sum := 0
	var start := Time.get_ticks_usec()
	for _t in ticks:
		var best_idx := -1
		var best := 2147483647
		for i in entities:
			var d := (px[i] - tx) * (px[i] - tx) + (py[i] - ty) * (py[i] - ty)
			if d < best:
				best = d
				best_idx = i
		sum += best_idx + best
		tx += 1
		ty -= 1
	var elapsed := Time.get_ticks_usec() - start
	return {"elapsed_us": elapsed, "checksum": sum, "ops": ticks * entities}


func bench_vg_batch_nearest(ticks: int, entities: int) -> Dictionary:
	var r := run_visual_gasic("BenchBatchNearest", [ticks, entities])
	r["ops"] = ticks * entities
	return r


func bench_gd_frame_slice(frames: int, entities: int) -> Dictionary:
	if frames <= 0 or entities <= 0:
		return {"elapsed_us": 0, "checksum": 0, "ops": 0}
	var hp := PackedInt64Array()
	var state := PackedInt64Array()
	var tag := PackedInt64Array()
	hp.resize(entities)
	state.resize(entities)
	tag.resize(entities)
	for i in entities:
		hp[i] = 100 + (i % 7)
		state[i] = i % 4
		tag[i] = 0
	var sum := 0
	var start := Time.get_ticks_usec()
	for _t in frames:
		for i in entities:
			var h := hp[i]
			var st := state[i]
			if st == 0:
				h -= 1
			elif st == 1:
				h += 2
			else:
				st = (st + 1) % 4
			hp[i] = h
			state[i] = st
			tag[i] = h + st
			sum += tag[i]
	var elapsed := Time.get_ticks_usec() - start
	return {"elapsed_us": elapsed, "checksum": sum, "ops": frames * entities}


func bench_vg_frame_slice(frames: int, entities: int) -> Dictionary:
	var r := run_visual_gasic("BenchFrameSlice", [frames, entities])
	r["ops"] = frames * entities
	return r


func run_workload(name: String, tier: String, category: String, gd_call: Callable, vg_call: Callable) -> Dictionary:
	return {
		"name": name,
		"tier": tier,
		"category": category,
		"gd": gd_call.call(),
		"vg": vg_call.call(),
	}


func _ratios(entries: Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for e in entries:
		var gd_us := float(e["gd"].get("elapsed_us", 0))
		var vg_us := float(e["vg"].get("elapsed_us", 0))
		if gd_us > 0.0 and vg_us > 0.0:
			out.append(gd_us / vg_us)
	return out


func _geom_mean(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var product := 1.0
	for v in values:
		product *= v
	return pow(product, 1.0 / float(values.size()))


func _median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	if sorted.size() % 2 == 1:
		return sorted[mid]
	return (sorted[mid - 1] + sorted[mid]) * 0.5


func _print_entry(entry: Dictionary) -> void:
	print("\n=== ", entry["name"], " [", entry["tier"], " · ", entry.get("category", ""), "] ===")
	var gd_result: Dictionary = entry["gd"]
	var vg_result: Dictionary = entry["vg"]
	print("GDScript: ", gd_result)
	print("VisualGasic: ", vg_result)

	if gd_result.is_empty() or vg_result.is_empty():
		push_warning("Skipping " + entry["name"] + " due to missing benchmark data.")
		return

	var gd_sum = gd_result.get("checksum")
	var vg_sum = vg_result.get("checksum")
	if gd_sum != vg_sum:
		push_warning(entry["name"] + ": checksum mismatch gd=" + str(gd_sum) + " vg=" + str(vg_sum))

	var gd_us := float(gd_result.get("elapsed_us", 0))
	var vg_us := float(vg_result.get("elapsed_us", 0))
	var ops := int(gd_result.get("ops", 0))
	if gd_us > 0.0 and vg_us > 0.0:
		print("VisualGasic vs GDScript: ", gd_us / vg_us, "x")
	if ops > 0:
		print("GDScript us/op: ", gd_us / float(ops))
		print("VisualGasic us/op: ", vg_us / float(ops))


func _init() -> void:
	print("=== Visual Gasic Gameplay Realism Benchmarks ===")
	print("Tier B: script-local loops and calls · Tier C: engine-adjacent gameplay shapes")
	print("Categories: representative (typical frame work) · optimization-target (tracked VM gaps)")
	print("Metric: elapsed microseconds (lower is faster) · us/op when ops count is fixed")
	print("IMPORTANT: geometric mean mixes unlike workloads — use median + per-test rows for game-speed claims.\n")

	print("Warmup...")
	bench_gd_integer_loop(TIER_B_OPS)
	bench_vg_integer_loop(TIER_B_OPS)
	bench_vg_local_calls(TIER_B_OPS)

	var results: Array = []

	results.append(run_workload(
		"IntegerLoop",
		"B",
		"representative",
		Callable(self, "bench_gd_integer_loop").bind(TIER_B_OPS),
		Callable(self, "bench_vg_integer_loop").bind(TIER_B_OPS)
	))
	results.append(run_workload(
		"FloatLoop",
		"B",
		"representative",
		Callable(self, "bench_gd_float_loop").bind(TIER_B_OPS),
		Callable(self, "bench_vg_float_loop").bind(TIER_B_OPS)
	))
	results.append(run_workload(
		"LocalCalls",
		"B",
		"representative",
		Callable(self, "bench_gd_local_calls").bind(TIER_B_OPS),
		Callable(self, "bench_vg_local_calls").bind(TIER_B_OPS)
	))
	results.append(run_workload(
		"CallChain",
		"B",
		"optimization-target",
		Callable(self, "bench_gd_call_chain").bind(TIER_B_OPS),
		Callable(self, "bench_vg_call_chain").bind(TIER_B_OPS)
	))

	results.append(run_workload(
		"NodePropertyChurn",
		"C",
		"representative",
		Callable(self, "bench_gd_node_property_churn").bind(NODE_OUTER, NODE_INNER),
		Callable(self, "bench_vg_node_property_churn").bind(NODE_OUTER, NODE_INNER)
	))
	results.append(run_workload(
		"ArrayIterate",
		"C",
		"optimization-target",
		Callable(self, "bench_gd_array_iterate").bind(GAMEPLAY_TICKS, ENTITY_COUNT),
		Callable(self, "bench_vg_array_iterate").bind(GAMEPLAY_TICKS, ENTITY_COUNT)
	))
	results.append(run_workload(
		"DictionaryScan",
		"C",
		"optimization-target",
		Callable(self, "bench_gd_dictionary_scan").bind(GAMEPLAY_TICKS, ENTITY_COUNT),
		Callable(self, "bench_vg_dictionary_scan").bind(GAMEPLAY_TICKS, ENTITY_COUNT)
	))
	results.append(run_workload(
		"EntityThink",
		"C",
		"representative",
		Callable(self, "bench_gd_entity_think").bind(GAMEPLAY_TICKS, ENTITY_COUNT),
		Callable(self, "bench_vg_entity_think").bind(GAMEPLAY_TICKS, ENTITY_COUNT)
	))
	results.append(run_workload(
		"BatchNearest",
		"C",
		"representative",
		Callable(self, "bench_gd_batch_nearest").bind(GAMEPLAY_TICKS, ENTITY_COUNT),
		Callable(self, "bench_vg_batch_nearest").bind(GAMEPLAY_TICKS, ENTITY_COUNT)
	))
	results.append(run_workload(
		"FrameSlice",
		"C",
		"representative",
		Callable(self, "bench_gd_frame_slice").bind(GAMEPLAY_TICKS, ENTITY_COUNT),
		Callable(self, "bench_vg_frame_slice").bind(GAMEPLAY_TICKS, ENTITY_COUNT)
	))

	for entry in results:
		_print_entry(entry)

	var tier_b: Array = []
	var tier_c: Array = []
	for entry in results:
		if entry["tier"] == "B":
			tier_b.append(entry)
		else:
			tier_c.append(entry)

	var rb := _ratios(tier_b)
	var rc := _ratios(tier_c)
	var ra := _ratios(results)
	var rep: Array = []
	var opt: Array = []
	for entry in results:
		var cat: String = entry.get("category", "")
		if cat == "representative":
			rep.append(entry)
		elif cat == "optimization-target":
			opt.append(entry)
	var rrep := _ratios(rep)
	var ropt := _ratios(opt)
	print("\n=== Summary (VG vs GDScript speedup; >1 = VG faster) ===")
	print("Representative gameplay — median: ", _median(rrep), "x · geom mean: ", _geom_mean(rrep), "x")
	print("Optimization targets — median: ", _median(ropt), "x · geom mean: ", _geom_mean(ropt), "x")
	print("Tier B  — geometric mean: ", _geom_mean(rb), "x · median: ", _median(rb), "x")
	print("Tier C  — geometric mean: ", _geom_mean(rc), "x · median: ", _median(rc), "x")
	print("Combined — geometric mean: ", _geom_mean(ra), "x · median: ", _median(ra), "x")
	print("Use median + per-test rows for claims; geometric mean mixes unlike workloads.")
	print("Use Tier A compute/draw + representative Tier C (FrameSlice, EntityThink, NodePropertyChurn) for shipping claims.")
	print("Note: Tier B/C are informational — not part of CI regression gate (Tier A + draw gate releases).")

	quit(0)
