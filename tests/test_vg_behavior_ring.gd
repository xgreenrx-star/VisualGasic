extends SceneTree

var failures := 0
var checks := 0

const BECOMES := "Dim n As Integer\nWhenever Section Gate n Becomes 6 OnGate\nSub OnGate()\nEnd Sub\nSub Go()\n  n = 5\n  n = 6\n  n = 6\nEnd Sub\n"
const CHANGES := "Dim n As Integer\nWhenever Section Gate n Changes OnGate\nSub OnGate()\nEnd Sub\nSub Go()\n  n = 1\n  n = 1\nEnd Sub\n"
const EXCEEDS := "Dim n As Integer\nWhenever Section Gate n Exceeds 10 OnGate\nSub OnGate()\nEnd Sub\nSub Go()\n  n = 10\n  n = 11\n  n = 12\nEnd Sub\n"
const BELOW := "Dim n As Integer\nWhenever Section Gate n Below 3 OnGate\nSub OnGate()\nEnd Sub\nSub Go()\n  n = 9\n  n = 2\n  n = 1\nEnd Sub\n"
const NO_FIRE := "Dim n As Integer\nWhenever Section Gate n Becomes 6 OnGate\nSub OnGate()\nEnd Sub\nSub Go()\n  n = 5\nEnd Sub\n"
const BETWEEN := "Dim n As Integer\nWhenever Section Gate n Between 2 And 4 OnGate\nSub OnGate()\nEnd Sub\nSub Go()\n  n = 3\n  n = 4\n  n = 9\nEnd Sub\n"
const CONTAINS := "Dim s As String\nWhenever Section Gate s Contains \"gem\" OnGate\nSub OnGate()\nEnd Sub\nSub Go()\n  s = \"xgem\"\n  s = \"xgem\"\nEnd Sub\n"
const EXPR := "Dim score As Integer\nWhenever Section Hot (score > 3) OnHot\nSub OnHot()\nEnd Sub\nSub Go()\n  score = 2\n  score = 4\n  score = 5\nEnd Sub\n"
const MULTI := "Dim n As Integer\nWhenever Section Multi n Becomes 1 OnYes, OnMissing\nSub OnYes()\nEnd Sub\nSub Go()\n  n = 1\nEnd Sub\n"
const REENTER := "Dim a As Integer\nDim b As Integer\nWhenever Section WatchA a Becomes 1 OnA\nWhenever Section WatchB b Becomes 1 OnB\nSub OnA()\n  b = 1\nEnd Sub\nSub OnB()\nEnd Sub\nSub Go()\n  a = 1\nEnd Sub\n"
const DEBOUNCE := "Dim score As Integer\nWhenever Section UIUpdate score Changes OnScore Debounce 1000ms\nSub OnScore()\nEnd Sub\nSub Go()\n  score = 1\n  score = 2\nEnd Sub\n"
const DEBOUNCE_FIRST := "Dim score As Integer\nWhenever Section UIUpdate score Changes OnScore Debounce 600000ms\nSub OnScore()\nEnd Sub\nSub Go()\n  score = 1\n  score = 2\nEnd Sub\n"
const NO_SECTION := "Dim crystals As Integer\nSub Go()\n  crystals = 3\nEnd Sub\n"
const SHADOW := "Dim crystals As Integer\nSub Go()\n  Dim crystals As Integer\n  crystals = 4\nEnd Sub\n"
const SCRIPT_A := "Dim a As Integer\nSub GoA()\n  a = 1\nEnd Sub\n"
const SCRIPT_B := "Dim b As Integer\nSub GoB()\n  b = 2\nEnd Sub\n"
const OVERFLOW := "Dim crystals As Integer\nSub Go()\n  Dim i As Integer\n  For i = 1 To 80\n    crystals = i\n  Next i\nEnd Sub\n"

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("FAIL: " + what)

func line_of(text: String, needle: String) -> int:
	var lines := text.split("\n")
	for index in lines.size():
		if lines[index].contains(needle):
			return index + 1
	return 0

func attach(source: String) -> Dictionary:
	VisualGasicLanguage.vg_evidence_stop()
	var scr := VisualGasicScript.new()
	scr.source_code = source
	var err: Error = scr.reload()
	var node := Node.new()
	root.add_child(node)
	node.set_script(scr)
	return {"node": node, "script": scr, "error": err, "text": scr.source_code}

func start_watch(names: Array, capacity: int = 512) -> void:
	var cfg := {"watch": names, "capacity": capacity}
	VisualGasicLanguage.vg_evidence_start(cfg)

func finish(node: Node) -> Dictionary:
	var snap: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	VisualGasicLanguage.vg_evidence_stop()
	node.free()
	return snap

func run_entry(source: String, entry: String, names: Array, force_ast: bool, capacity: int = 512) -> Dictionary:
	VisualGasicLanguage.vg_set_force_ast(force_ast)
	var host: Dictionary = attach(source)
	var node: Node = host["node"]
	check(int(host["error"]) == OK, "reload %s (%s)" % [entry, "ast" if force_ast else "bytecode"])
	if int(host["error"]) != OK:
		node.free()
		return {"events": [], "live_text": str(host["text"])}
	start_watch(names, capacity)
	node.call(entry)
	var snap := finish(node)
	snap["live_text"] = str(host["text"])
	return snap

func fires(snap: Dictionary, section: String) -> Array:
	var found: Array = []
	for event in snap.get("events", []):
		if str(event.get("kind", "")) == "whenever_fired" and str(event.get("section", "")).to_lower() == section.to_lower():
			found.append(event)
	return found

func tuples(snap: Dictionary) -> Array:
	var rows: Array = []
	for event in snap.get("events", []):
		rows.append([
			str(event.get("kind", "")),
			str(event.get("section", "")),
			str(event.get("variable", "")),
			event.get("old", null),
			event.get("new", null),
		])
	return rows

func assert_one_fire(label: String, source: String, section: String, variable: String, names: Array) -> void:
	for force_ast in [false, true]:
		var engine := "ast" if force_ast else "bytecode"
		var snap: Dictionary = run_entry(source, "Go", names, force_ast)
		var hit: Array = fires(snap, section)
		check(hit.size() == 1, "%s %s fires once, got %d %s" % [label, engine, hit.size(), str(tuples(snap))])
		if hit.size() != 1:
			continue
		var event: Dictionary = hit[0]
		check(str(event.get("engine", "")) == engine, "%s %s engine tag" % [label, engine])
		check(str(event.get("variable", "")) == variable, "%s %s variable" % [label, engine])
		check(bool(event.get("location_known", false)) and int(event.get("line", 0)) > 0, "%s %s executing line is known" % [label, engine])
		var declared := line_of(str(snap.get("live_text", source)), "Whenever Section " + section)
		check(int(event.get("declared_line", 0)) == declared and declared > 0, "%s %s declared_line %s vs %s" % [label, engine, str(event.get("declared_line", 0)), str(declared)])

func _run() -> void:
	if not ClassDB.class_exists("VisualGasicLanguage") or not ClassDB.class_exists("VisualGasicScript"):
		push_error("FAIL: VisualGasic classes are not loaded")
		quit(1)
		return
	await _suite()
	if failures == 0:
		print("[PASS] test_vg_behavior_ring.gd (%d/%d)" % [checks, checks])
		quit(0)
	else:
		print("[FAIL] test_vg_behavior_ring.gd (%d failures / %d checks)" % [failures, checks])
		quit(1)

func _suite() -> void:
	assert_one_fire("changes", CHANGES, "Gate", "n", ["n"])
	assert_one_fire("becomes", BECOMES, "Gate", "n", ["n"])
	assert_one_fire("exceeds", EXCEEDS, "Gate", "n", ["n"])
	assert_one_fire("below", BELOW, "Gate", "n", ["n"])
	assert_one_fire("between", BETWEEN, "Gate", "n", ["n"])
	assert_one_fire("contains", CONTAINS, "Gate", "s", ["s"])
	assert_one_fire("expression", EXPR, "Hot", "", ["score"])

	for force_ast in [false, true]:
		var engine := "ast" if force_ast else "bytecode"
		var becomes: Dictionary = run_entry(BECOMES, "Go", ["n"], force_ast)
		var write_same := false
		var fired_on_same := false
		for event in becomes.get("events", []):
			if str(event.get("kind", "")) == "watched_write" and int(event.get("old", -1)) == 6 and int(event.get("new", -1)) == 6:
				write_same = true
			if str(event.get("kind", "")) == "whenever_fired" and int(event.get("old", -1)) == 6:
				fired_on_same = true
		check(write_same and not fired_on_same, "becomes 6 to 6 is a write without a fire (%s)" % engine)

		var between: Dictionary = run_entry(BETWEEN, "Go", ["n"], force_ast)
		var between_fire: Array = fires(between, "Gate")
		if between_fire.size() == 1:
			var target: Variant = between_fire[0].get("target", null)
			check(target is Array and target.size() == 2 and int(target[0]) == 2 and int(target[1]) == 4, "between target is 2..4 (%s)" % engine)

		var multi: Dictionary = run_entry(MULTI, "Go", ["n"], force_ast)
		var multi_fire: Array = fires(multi, "Multi")
		check(multi_fire.size() == 1, "multi callback fires once (%s)" % engine)
		if multi_fire.size() == 1:
			var callbacks: Array = multi_fire[0].get("callbacks", [])
			check(callbacks.size() == 2, "multi lists both callbacks (%s)" % engine)
			var yes_resolved := false
			var missing_resolved := true
			for row in callbacks:
				if str(row.get("name", "")) == "OnYes":
					yes_resolved = bool(row.get("resolved", false))
				if str(row.get("name", "")) == "OnMissing":
					missing_resolved = bool(row.get("resolved", true))
			check(yes_resolved and not missing_resolved, "multi resolves OnYes only (%s)" % engine)
		var missing := 0
		for event in multi.get("events", []):
			if str(event.get("kind", "")) == "callback_missing" and str(event.get("callback", "")) == "OnMissing":
				missing += 1
		check(missing == 1, "callback_missing for OnMissing (%s) %s" % [engine, str(tuples(multi))])

		var reenter: Dictionary = run_entry(REENTER, "Go", ["a", "b"], force_ast)
		check(fires(reenter, "WatchA").size() == 1, "reenter fires WatchA (%s)" % engine)
		check(fires(reenter, "WatchB").is_empty(), "reenter does not fire WatchB (%s)" % engine)
		var suppressed := 0
		for event in reenter.get("events", []):
			if str(event.get("kind", "")) == "whenever_suppressed" and str(event.get("section", "")) == "WatchB" and str(event.get("reason", "")) == "reentrant":
				suppressed += 1
		check(suppressed == 1, "reenter suppresses WatchB (%s) %s" % [engine, str(tuples(reenter))])

		var bare: Dictionary = run_entry(NO_SECTION, "Go", ["crystals"], force_ast)
		var bare_writes := 0
		var bare_other := 0
		for event in bare.get("events", []):
			if str(event.get("kind", "")) == "watched_write" and str(event.get("variable", "")) == "crystals":
				bare_writes += 1
				check(str(event.get("engine", "")) == engine, "no-section write engine (%s)" % engine)
				check(bool(event.get("location_known", false)), "no-section line known (%s)" % engine)
			else:
				bare_other += 1
		check(bare_writes == 1 and bare_other == 0, "watched write with no section (%s) %s" % [engine, str(tuples(bare))])

		var shadow: Dictionary = run_entry(SHADOW, "Go", ["crystals"], force_ast)
		check(shadow.get("events", []).is_empty(), "local shadow is not recorded (%s) %s" % [engine, str(tuples(shadow))])

		var overflow: Dictionary = run_entry(OVERFLOW, "Go", ["crystals"], force_ast, 64)
		check(int(overflow.get("dropped", 0)) > 0 and overflow.get("events", []).size() == 64, "capacity 64 drops oldest (%s) dropped=%s size=%s" % [engine, str(overflow.get("dropped", 0)), str(overflow.get("events", []).size())])

	var bytecode: Dictionary = run_entry(BECOMES, "Go", ["n"], false)
	var ast: Dictionary = run_entry(BECOMES, "Go", ["n"], true)
	check(tuples(bytecode) == tuples(ast), "ast and bytecode tuples match %s vs %s" % [str(tuples(bytecode)), str(tuples(ast))])

	VisualGasicLanguage.vg_set_force_ast(false)
	VisualGasicLanguage.vg_evidence_stop()
	var first: Dictionary = attach(SCRIPT_A)
	var second: Dictionary = attach(SCRIPT_B)
	start_watch(["a", "b"])
	(first["node"] as Node).call("GoA")
	(second["node"] as Node).call("GoB")
	var shared: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	VisualGasicLanguage.vg_evidence_stop()
	(first["node"] as Node).free()
	(second["node"] as Node).free()
	var shared_events: Array = shared.get("events", [])
	check(shared_events.size() == 2, "two scripts share one stream (%d)" % shared_events.size())
	if shared_events.size() == 2:
		check(int(shared_events[0].get("seq", 0)) + 1 == int(shared_events[1].get("seq", 0)), "shared seq is ordered")
		check(str(shared_events[0].get("script_hash", "")) != str(shared_events[1].get("script_hash", "")), "shared scripts keep distinct hashes")
	check(shared.get("scripts", []).size() == 2, "snapshot lists both scripts")

	VisualGasicLanguage.vg_evidence_stop()
	var quiet: Dictionary = attach(NO_SECTION)
	(quiet["node"] as Node).call("Go")
	var idle: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	check(not bool(idle.get("recording", true)) and idle.get("events", []).is_empty() and int(idle.get("dropped", 1)) == 0 and int(idle.get("next_seq", 1)) == 0, "recorder off keeps an empty buffer")
	(quiet["node"] as Node).free()
	var after_stop: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	check(after_stop.get("events", []).is_empty() and int(after_stop.get("dropped", 1)) == 0 and int(after_stop.get("next_seq", 1)) == 0, "stop wipes the buffer")

	for force_ast in [false, true]:
		var engine := "ast" if force_ast else "bytecode"
		var debounced: Dictionary = run_entry(DEBOUNCE, "Go", ["score"], force_ast)
		var debounce_fires: Array = fires(debounced, "UIUpdate")
		var debounce_skips := 0
		for event in debounced.get("events", []):
			if str(event.get("kind", "")) == "whenever_suppressed" and str(event.get("reason", "")) == "debounce":
				debounce_skips += 1
		check(debounce_fires.size() == 1 and debounce_skips == 1, "debounce fires once then suppresses (%s) %s" % [engine, str(tuples(debounced))])
		var cold: Dictionary = run_entry(DEBOUNCE_FIRST, "Go", ["score"], force_ast)
		var cold_fires: Array = fires(cold, "UIUpdate")
		var cold_skips := 0
		for event in cold.get("events", []):
			if str(event.get("kind", "")) == "whenever_suppressed" and str(event.get("reason", "")) == "debounce":
				cold_skips += 1
		check(cold_fires.size() == 1 and cold_skips == 1, "first change fires inside a 600000ms window (%s) %s" % [engine, str(tuples(cold))])

	var chain = load("res://addons/visual_gasic/vg_causal_chain.gd").new()
	var joined_host: Dictionary = attach(BECOMES)
	var live := str(joined_host["text"])
	var static_report: Dictionary = chain.analyze(live, ["Gate"], "")
	start_watch(["n"])
	(joined_host["node"] as Node).call("Go")
	var ran: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	var joined: Dictionary = chain.join_runtime(static_report, ran)
	check(_status(joined, "Gate") == "observed", "join observed %s" % str(joined))
	VisualGasicLanguage.vg_evidence_stop()
	var stopped: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	var unknown_join: Dictionary = chain.join_runtime(static_report, stopped)
	check(_status(unknown_join, "Gate") == "unknown", "join unknown when recorder is off")
	(joined_host["node"] as Node).free()

	var quiet_host: Dictionary = attach(NO_FIRE)
	start_watch(["n"])
	(quiet_host["node"] as Node).call("Go")
	var no_fire: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	var no_fire_report: Dictionary = chain.analyze(str(quiet_host["text"]), ["Gate"], "")
	var not_seen: Dictionary = chain.join_runtime(no_fire_report, no_fire)
	check(_status(not_seen, "Gate") == "not_observed", "join not_observed when the section does not fire")
	VisualGasicLanguage.vg_evidence_stop()
	(quiet_host["node"] as Node).free()

	var missing_host: Dictionary = attach(MULTI)
	var missing_report: Dictionary = chain.analyze(str(missing_host["text"]), ["Multi"], "")
	start_watch(["n"])
	(missing_host["node"] as Node).call("Go")
	var missing_run: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	var unresolved: Dictionary = chain.join_runtime(missing_report, missing_run)
	check(_status(unresolved, "Multi") == "unresolved", "join stays unresolved when a callback is unresolved %s" % str(unresolved))
	VisualGasicLanguage.vg_evidence_stop()
	(missing_host["node"] as Node).free()

	var stale_host: Dictionary = attach(BECOMES)
	var stale_report: Dictionary = chain.analyze(str(stale_host["text"]) + "\n' edited\n", ["Gate"], "")
	start_watch(["n"])
	(stale_host["node"] as Node).call("Go")
	var stale_run: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	var stale: Dictionary = chain.join_runtime(stale_report, stale_run)
	check(_status(stale, "Gate") == "stale", "join stale when the source hash differs %s" % str(stale))
	VisualGasicLanguage.vg_evidence_stop()
	(stale_host["node"] as Node).free()

func _status(joined: Dictionary, section: String) -> String:
	for root in joined.get("roots", []):
		if str(root.get("section", "")).to_lower() == section.to_lower():
			return str(root.get("status", ""))
	return ""
