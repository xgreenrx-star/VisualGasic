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

func _run() -> void:
	var snap: Dictionary = play(false)
	var f := FileAccess.open("user://probe_snapshot.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(snap))
	f.close()
	print("DUMPED crystals=%s events=%d path=%s" % [str(snap.get("crystals")), snap.get("events", []).size(), ProjectSettings.globalize_path("user://probe_snapshot.json")])
	quit(0)
