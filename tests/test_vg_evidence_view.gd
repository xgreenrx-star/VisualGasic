extends SceneTree

const ViewScript = preload("res://addons/visual_gasic/vg_evidence_view.gd")
const ChainScript = preload("res://addons/visual_gasic/vg_causal_chain.gd")

const UNLOCK := "Dim crystals As Integer\nDim exitOpen As Boolean\nWhenever Section UnlockExit crystals Becomes 6 OnUnlockExit\nSub OnUnlockExit()\n\tIf exitOpen Then Exit Sub\n\texitOpen = True\n\tCall PlayCue(1)\nEnd Sub\nSub PlayCue(id As Integer)\nEnd Sub\nSub Go()\n\tcrystals = 6\nEnd Sub\n"
const REENTER := "Dim a As Integer\nDim b As Integer\nWhenever Section WatchA a Becomes 1 OnA\nWhenever Section WatchB b Becomes 1 OnB\nSub OnA()\n\tb = 1\nEnd Sub\nSub OnB()\nEnd Sub\nSub Go()\n\ta = 1\nEnd Sub\n"
const CHAIN := "Dim x As Integer\nWhenever Section Feed x Changes OnFeed\nSub OnFeed()\n\tx = x + 1\nEnd Sub\nSub Go()\n\tOn Error Resume Next\n\tx = 1\nEnd Sub\n"
const MULTI := "Dim n As Integer\nWhenever Section Multi n Becomes 1 OnYes, OnMissing\nSub OnYes()\nEnd Sub\nSub Go()\n\tn = 1\nEnd Sub\n"

var failures := 0
var checks := 0
var view = ViewScript.new()
var chain = ChainScript.new()

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("FAIL: " + what)

func _run() -> void:
	if not ClassDB.class_exists("VisualGasicLanguage"):
		push_error("FAIL: VisualGasicLanguage is not loaded")
		quit(1)
		return
	for force_ast in [false, true]:
		var engine := "ast" if force_ast else "bytecode"
		_covered(engine, force_ast)
	if failures == 0:
		print("EVIDENCE VIEW: %d passed" % checks)
		quit(0)
	else:
		print("EVIDENCE VIEW: %d failed / %d" % [failures, checks])
		quit(1)

func _covered(engine: String, force_ast: bool) -> void:
	var watched: Dictionary = _play(UNLOCK, "Go", ["crystals", "exitOpen"], force_ast)
	var report: Dictionary = chain.analyze(str(watched.get("text", "")), ["UnlockExit"], str(watched.get("path", "")))
	var built: Dictionary = view.build_view(report, watched, "ended")
	var root: Dictionary = _row(built, "whenever", "")
	check(str(root.get("runtime", "")) == "observed", "%s root observed, got %s" % [engine, str(root.get("runtime", ""))])
	check(int(built.get("header", {}).get("fire_count", -1)) == 1, "%s fire_count 1" % engine)
	var callback: Dictionary = _row(built, "callback", "OnUnlockExit")
	check(str(callback.get("runtime", "")) == "observed", "%s callback observed, got %s" % [engine, str(callback.get("runtime", ""))])
	var write: Dictionary = _row(built, "state_write", "exitOpen = True")
	check(str(write.get("runtime", "")) == "observed", "%s exitOpen write observed, got %s detail %s" % [engine, str(write.get("runtime", "")), str(write.get("detail", []))])
	check(int(write.get("line", 0)) == _line_of(str(watched.get("text", "")), "exitOpen = True"), "%s exitOpen write line" % engine)
	var call: Dictionary = _row(built, "call", "PlayCue")
	check(str(call.get("runtime", "")) == "not_recorded", "%s PlayCue not_recorded, got %s" % [engine, str(call.get("runtime", ""))])
	var guard: Dictionary = _row(built, "guard", "exitOpen")
	check(not guard.is_empty(), "%s guard row exists" % engine)
	check(str(guard.get("runtime", "")) == "not_recorded", "%s guard not_recorded, got %s" % [engine, str(guard.get("runtime", ""))])
	var unwatched: Dictionary = _play(UNLOCK, "Go", ["crystals"], force_ast)
	var unwatched_view: Dictionary = view.build_view(chain.analyze(str(unwatched.get("text", "")), ["UnlockExit"], str(unwatched.get("path", ""))), unwatched, "running")
	var missed: Dictionary = _row(unwatched_view, "state_write", "exitOpen = True")
	check(str(missed.get("runtime", "")) == "not_recorded", "%s unwatched write not_recorded, got %s" % [engine, str(missed.get("runtime", ""))])
	VisualGasicLanguage.vg_evidence_stop()
	var off: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	var off_view: Dictionary = view.build_view(report, off, "none")
	_every(off_view, "unknown", engine + " recorder off")
	var dropped: Dictionary = watched.duplicate(true)
	dropped["dropped"] = 4
	dropped["recording"] = true
	var dropped_view: Dictionary = view.build_view(report, dropped, "running")
	_every(dropped_view, "unknown", engine + " dropped")
	var stale: Dictionary = watched.duplicate(true)
	var scripts: Array = stale.get("scripts", [])
	for index in scripts.size():
		var row: Dictionary = scripts[index]
		row["content_hash"] = "edited"
		scripts[index] = row
	stale["scripts"] = scripts
	stale["recording"] = true
	stale["dropped"] = 0
	var stale_view: Dictionary = view.build_view(report, stale, "ended")
	_every(stale_view, "stale", engine + " stale")
	check(bool(stale_view.get("header", {}).get("stale", false)), "%s header stale" % engine)
	var reenter: Dictionary = _play(REENTER, "Go", ["a", "b"], force_ast)
	var reenter_view: Dictionary = view.build_view(chain.analyze(str(reenter.get("text", "")), ["WatchB"], str(reenter.get("path", ""))), reenter, "ended")
	var deferred_row: Dictionary = _row(reenter_view, "whenever", "")
	var detail := " ".join(deferred_row.get("detail", []))
	check(str(deferred_row.get("runtime", "")) == "observed", "%s deferred fire is observed, got %s" % [engine, str(deferred_row.get("runtime", ""))])
	check(int(reenter_view.get("header", {}).get("fire_count", -1)) == 1, "%s deferred fire counts" % engine)
	check(not detail.contains("reason=reentrant"), "%s deferred fire is not reentrant, got %s" % [engine, detail])
	var chain_run: Dictionary = _play(CHAIN, "Go", ["x"], force_ast, 4096)
	var chain_view: Dictionary = view.build_view(chain.analyze(str(chain_run.get("text", "")), ["Feed"], str(chain_run.get("path", ""))), chain_run, "ended")
	var chain_row: Dictionary = _row(chain_view, "whenever", "")
	var chain_detail := " ".join(chain_row.get("detail", []))
	check(chain_detail.contains("reason=chain_limit"), "%s chain_limit detail, got %s" % [engine, chain_detail])
	check(str(chain_row.get("runtime", "")) == "observed", "%s chain limit root stays observed" % engine)
	var missing_run: Dictionary = _play(MULTI, "Go", ["n"], force_ast)
	var missing_view: Dictionary = view.build_view(chain.analyze(str(missing_run.get("text", "")), ["Multi"], str(missing_run.get("path", ""))), missing_run, "ended")
	var missing: Dictionary = _row(missing_view, "callback", "OnMissing")
	check(str(missing.get("runtime", "")) == "missing", "%s missing callback, got %s" % [engine, str(missing.get("runtime", ""))])
	var yes: Dictionary = _row(missing_view, "callback", "OnYes")
	check(str(yes.get("runtime", "")) == "observed", "%s OnYes observed, got %s" % [engine, str(yes.get("runtime", ""))])
	_locations(built, engine)

func _every(built: Dictionary, status: String, label: String) -> void:
	var rows: Array = built.get("rows", [])
	check(rows.size() > 0, label + " has rows")
	for row in rows:
		check(str(row.get("runtime", "")) == status, "%s row %s is %s, got %s" % [label, str(row.get("step_id", "")), status, str(row.get("runtime", ""))])
		check(str(row.get("runtime", "")) != "observed", label + " does not look observed")

func _locations(built: Dictionary, engine: String) -> void:
	for row in built.get("rows", []):
		var located := str(row.get("file", "")) != "" and int(row.get("line", 0)) > 0
		check(located or not bool(row.get("location_known", false)), "%s %s location" % [engine, str(row.get("step_id", ""))])

func _row(built: Dictionary, kind: String, text_part: String) -> Dictionary:
	for row in built.get("rows", []):
		if str(row.get("kind", "")) != kind:
			continue
		if text_part.is_empty() or str(row.get("text", "")).contains(text_part):
			return row
	return {}

func _line_of(text: String, needle: String) -> int:
	var lines := text.split("\n")
	for index in lines.size():
		if lines[index].contains(needle):
			return index + 1
	return 0

func _play(source: String, entry: String, names: Array, force_ast: bool, capacity: int = 512) -> Dictionary:
	VisualGasicLanguage.vg_set_force_ast(force_ast)
	VisualGasicLanguage.vg_evidence_stop()
	var scr := VisualGasicScript.new()
	scr.resource_path = "res://fixture.vg"
	scr.source_code = source
	var err: Error = scr.reload()
	check(err == OK, "reload " + entry)
	var node := Node.new()
	root.add_child(node)
	node.set_script(scr)
	VisualGasicLanguage.vg_evidence_start({"watch": names, "capacity": capacity})
	if err == OK:
		node.call(entry)
	var snap: Dictionary = VisualGasicLanguage.vg_evidence_snapshot()
	snap["text"] = scr.source_code
	snap["path"] = scr.resource_path
	VisualGasicLanguage.vg_evidence_stop()
	node.free()
	return snap
