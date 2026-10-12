extends SceneTree

# Plain expectations. Phase 3 will protect this file. Do not chase a moved line.
const UNLOCK_LINE := 71
const GEM_TARGET := 6
const TILE_EMPTY := 0
const TILE_WALL := 1
const TILE_CRYSTAL := 4
const WATCH := ["crystals", "exitOpen", "health"]
const STOP_SHORT := 5
const OVERFLOW_PICKUPS := 70
const OVERFLOW_CAPACITY := 64

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("FAIL: " + what)

func blank_cave(game: Node) -> void:
	game.call("RestartCave")
	var board: Array = game.get("board").duplicate()
	for y in range(12):
		for x in range(20):
			board[y * 20 + x] = TILE_WALL if x == 0 or y == 0 or x == 19 or y == 11 else TILE_EMPTY
	game.set("board", board)
	game.set("playerX", 2)
	game.set("playerY", 8)

func put(game: Node, x: int, y: int, tile: int) -> void:
	var board: Array = game.get("board").duplicate()
	board[y * 20 + x] = tile
	game.set("board", board)

func pickup_one(game: Node) -> void:
	var x := int(game.get("playerX"))
	var y := int(game.get("playerY"))
	var dx := 1 if x < 18 else -1
	put(game, x + dx, y, TILE_CRYSTAL)
	game.call("StepCave", dx, 0)

func unlock_fires(snap: Dictionary) -> Array:
	var found: Array = []
	for event in snap.get("events", []):
		if str(event.get("kind", "")) == "whenever_fired" and str(event.get("section", "")) == "UnlockExit":
			found.append(event)
	return found

func status_of(joined: Dictionary, section: String) -> String:
	for root in joined.get("roots", []):
		if str(root.get("section", "")) == section:
			return str(root.get("status", ""))
	return ""

func play(force_ast: bool, pickups: int, record: bool, capacity: int) -> Dictionary:
	VisualGasicLanguage.vg_set_force_ast(force_ast)
	VisualGasicLanguage.vg_evidence_stop()
	var packed := load("res://main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	var live := ""
	var script_path := ""
	var scr: Script = game.get_script()
	if scr != null:
		live = scr.source_code
		script_path = scr.resource_path
	if record:
		VisualGasicLanguage.vg_evidence_start({"watch": WATCH, "capacity": capacity})
	blank_cave(game)
	for _i in pickups:
		pickup_one(game)
	var snap: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	snap["crystals"] = int(game.get("crystals"))
	snap["live_text"] = live
	snap["script_path"] = script_path
	game.free()
	return snap

func _run() -> void:
	if not ClassDB.class_exists("VisualGasicLanguage"):
		push_error("FAIL: VisualGasicLanguage is not loaded")
		quit(1)
		return
	var expectation_status := "unprotected"
	var Exp = load("res://addons/visual_gasic/vg_expectations.gd")
	if Exp != null:
		var exp = Exp.new()
		exp.load_manifest(ProjectSettings.globalize_path("res://"))
		expectation_status = str(exp.status("res://evidence_exit_scenario.gd"))
	if expectation_status != "accepted" and expectation_status != "unprotected":
		print("[EXPECTATION MODIFIED] evidence_exit_scenario.gd")
		quit(1)
		return
	var chain = load("res://addons/visual_gasic/vg_causal_chain.gd").new()
	for force_ast in [false, true]:
		var engine := "ast" if force_ast else "bytecode"
		var positive: Dictionary = play(force_ast, GEM_TARGET, true, 512)
		check(int(positive.get("crystals", 0)) == GEM_TARGET, "%s crystals reach %d by pickup, got %s" % [engine, GEM_TARGET, str(positive.get("crystals", 0))])
		var fires: Array = unlock_fires(positive)
		check(fires.size() == 1, "%s exactly one UnlockExit fire, got %d" % [engine, fires.size()])
		if fires.size() == 1:
			var fire: Dictionary = fires[0]
			check(int(fire.get("declared_line", 0)) == UNLOCK_LINE, "%s UnlockExit declared_line %s" % [engine, str(fire.get("declared_line", 0))])
			check(str(fire.get("engine", "")) == engine, "%s UnlockExit engine tag" % engine)
			var callbacks: Array = fire.get("callbacks", [])
			var resolved := false
			for row in callbacks:
				if str(row.get("name", "")) == "OnUnlockExit" and bool(row.get("resolved", false)):
					resolved = true
			check(resolved, "%s OnUnlockExit is resolved" % engine)
			var opened := false
			for event in positive.get("events", []):
				if str(event.get("kind", "")) != "watched_write":
					continue
				if str(event.get("variable", "")) != "exitOpen" or str(event.get("procedure", "")) != "OnUnlockExit":
					continue
				if int(event.get("seq", 0)) > int(fire.get("seq", 0)) and bool(event.get("new", false)) == true and bool(event.get("old", true)) == false:
					opened = true
			check(opened, "%s exitOpen False to True inside OnUnlockExit after the fire" % engine)
		var report: Dictionary = chain.analyze(str(positive.get("live_text", "")), ["UnlockExit"], str(positive.get("script_path", "")))
		var joined: Dictionary = chain.join_runtime(report, positive)
		check(status_of(joined, "UnlockExit") == "observed", "%s join observed %s" % [engine, str(joined)])

		var short: Dictionary = play(force_ast, STOP_SHORT, true, 512)
		check(int(short.get("crystals", 0)) == STOP_SHORT, "%s stops at %d crystals" % [engine, STOP_SHORT])
		check(unlock_fires(short).is_empty(), "%s five crystals do not fire UnlockExit" % engine)
		var short_report: Dictionary = chain.analyze(str(short.get("live_text", "")), ["UnlockExit"], str(short.get("script_path", "")))
		var short_join: Dictionary = chain.join_runtime(short_report, short)
		check(status_of(short_join, "UnlockExit") == "not_observed", "%s join not_observed %s" % [engine, str(short_join)])

		var silent: Dictionary = play(force_ast, GEM_TARGET, false, 512)
		check(not bool(silent.get("recording", true)) and silent.get("events", []).is_empty(), "%s recorder off snapshot is empty" % engine)
		var silent_report: Dictionary = chain.analyze(str(silent.get("live_text", "")), ["UnlockExit"], str(silent.get("script_path", "")))
		var silent_join: Dictionary = chain.join_runtime(silent_report, silent)
		check(status_of(silent_join, "UnlockExit") == "unknown", "%s join unknown while recorder is off, not %s" % [engine, status_of(silent_join, "UnlockExit")])

		var flooded: Dictionary = play(force_ast, OVERFLOW_PICKUPS, true, OVERFLOW_CAPACITY)
		check(int(flooded.get("dropped", 0)) > 0, "%s capacity %d drops events (%s)" % [engine, OVERFLOW_CAPACITY, str(flooded.get("dropped", 0))])
		var flood_report: Dictionary = chain.analyze(str(flooded.get("live_text", "")), ["UnlockExit"], str(flooded.get("script_path", "")))
		var flood_join: Dictionary = chain.join_runtime(flood_report, flooded)
		check(status_of(flood_join, "UnlockExit") == "unknown", "%s overflow join is unknown %s" % [engine, str(flood_join)])

		var edited: Dictionary = play(force_ast, GEM_TARGET, true, 512)
		var edited_report: Dictionary = chain.analyze(str(edited.get("live_text", "")) + "\n' edited\n", ["UnlockExit"], str(edited.get("script_path", "")))
		var edited_join: Dictionary = chain.join_runtime(edited_report, edited)
		check(status_of(edited_join, "UnlockExit") == "stale", "%s edited source is stale %s" % [engine, str(edited_join)])
		VisualGasicLanguage.vg_evidence_stop()
		var wiped: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
		check(wiped.get("events", []).is_empty(), "%s stop leaves no events" % engine)

	if failures == 0:
		print("[PASS] evidence_exit_scenario.gd (%d/%d, both engines) expectation=%s" % [checks, checks, expectation_status])
		quit(0)
	else:
		print("[FAIL] evidence_exit_scenario.gd (%d failures / %d checks) expectation=%s" % [failures, checks, expectation_status])
		quit(1)
