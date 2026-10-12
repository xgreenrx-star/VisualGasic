extends SceneTree

const GEM_TARGET := 6
const TILE_EMPTY := 0
const TILE_WALL := 1
const TILE_CRYSTAL := 4
const WATCH := ["crystals", "exitOpen"]

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

func line_of(text: String, needle: String) -> int:
	var lines := text.split("\n")
	for index in lines.size():
		if lines[index].contains(needle):
			return index + 1
	return 0

func play(force_ast: bool) -> Dictionary:
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
	VisualGasicLanguage.vg_evidence_start({"watch": WATCH, "capacity": 512})
	blank_cave(game)
	for _i in GEM_TARGET:
		pickup_one(game)
	var snap: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	snap["crystals"] = int(game.get("crystals"))
	snap["live_text"] = live
	snap["script_path"] = script_path
	game.free()
	VisualGasicLanguage.vg_evidence_stop()
	return snap

func row_of(view: Dictionary, kind: String, text_part: String) -> Dictionary:
	for row in view.get("rows", []):
		if str(row.get("kind", "")) != kind:
			continue
		if text_part.is_empty() or str(row.get("text", "")).contains(text_part):
			return row
	return {}

func _run() -> void:
	if not ClassDB.class_exists("VisualGasicLanguage"):
		push_error("FAIL: VisualGasicLanguage is not loaded")
		quit(1)
		return
	var chain = load("res://addons/visual_gasic/vg_causal_chain.gd").new()
	var view_model = load("res://addons/visual_gasic/vg_evidence_view.gd").new()
	for force_ast in [false, true]:
		var engine := "ast" if force_ast else "bytecode"
		var snap: Dictionary = play(force_ast)
		check(int(snap.get("crystals", 0)) == GEM_TARGET, "%s six crystals, got %s" % [engine, str(snap.get("crystals", 0))])
		var report: Dictionary = chain.analyze(str(snap.get("live_text", "")), ["UnlockExit"], str(snap.get("script_path", "")))
		var built: Dictionary = view_model.build_view(report, snap, "ended")
		var header: Dictionary = built.get("header", {})
		var root: Dictionary = row_of(built, "whenever", "")
		check(str(root.get("runtime", "")) == "observed", "%s UnlockExit observed, got %s" % [engine, str(root.get("runtime", ""))])
		check(int(header.get("fire_count", -1)) == 1, "%s fire_count 1, got %s" % [engine, str(header.get("fire_count", -1))])
		var callback: Dictionary = row_of(built, "callback", "OnUnlockExit")
		check(str(callback.get("runtime", "")) == "observed", "%s OnUnlockExit observed, got %s" % [engine, str(callback.get("runtime", ""))])
		var write: Dictionary = row_of(built, "state_write", "exitOpen = True")
		var write_line := line_of(str(snap.get("live_text", "")), "exitOpen = True")
		check(str(write.get("runtime", "")) == "observed", "%s exitOpen write observed, got %s" % [engine, str(write.get("runtime", ""))])
		check(int(write.get("line", 0)) == write_line and write_line > 0, "%s exitOpen write line %s, got %s" % [engine, str(write_line), str(write.get("line", 0))])
		var saw_call := false
		for row in built.get("rows", []):
			if str(row.get("kind", "")) == "call" and str(row.get("text", "")).contains("PlayCue"):
				saw_call = true
				check(str(row.get("runtime", "")) == "not_recorded", "%s PlayCue not_recorded, got %s" % [engine, str(row.get("runtime", ""))])
		check(saw_call, "%s PlayCue call row" % engine)
	if failures == 0:
		print("EVIDENCE PANEL SCENARIO: %d passed" % checks)
		quit(0)
	else:
		print("EVIDENCE PANEL SCENARIO: %d failed / %d" % [failures, checks])
		quit(1)
