extends Node
## Headless spawn stress runner — detects frame stalls during enemy spawns.

const MAX_WALL_SEC := 45.0
const STALL_SEC := 4.0
const MIN_ENEMIES := 8
const MAX_FRAME_SEC := 2.5

var _main: Node = null
var _started := false
var _wall_start := 0.0
var _last_tick := 0.0
var _max_delta := 0.0
var _max_spike := 0.0
var _log_timer := 0.0

func setup(main: Node) -> void:
	_main = main

func _ready() -> void:
	_wall_start = Time.get_ticks_msec() / 1000.0
	_last_tick = _wall_start
	call_deferred("_begin_fight")

func _begin_fight() -> void:
	# VG subs may not appear in has_method() from GDScript — call directly.
	if _main != null:
		_main.call("start_game")
	_started = true
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		print("[spawn_stress] fight started, game_state=", gm.get("game_state"))
	else:
		print("[spawn_stress] fight started (GameManager autoload missing)")

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var since_last := now - _last_tick
	_last_tick = now
	if delta > _max_delta:
		_max_delta = delta
	if since_last > _max_spike:
		_max_spike = since_last

	if not _started:
		return

	_log_timer += delta
	if _log_timer >= 5.0:
		_log_timer = 0.0
		var enemies := get_tree().get_nodes_in_group("enemies")
		print("[spawn_stress] t=%.0fs enemies=%d max_delta=%.3f spike=%.3f" % [
			now - _wall_start, enemies.size(), _max_delta, _max_spike
		])

	if since_last > STALL_SEC:
		_fail("main-thread stall %.2fs (max_spike=%.3fs max_delta=%.3fs)" % [
			since_last, _max_spike, _max_delta
		])
		return

	if _max_delta > MAX_FRAME_SEC:
		_fail("frame spike max_delta=%.3fs at t=%.1fs" % [_max_delta, now - _wall_start])
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	var elapsed := now - _wall_start
	if elapsed >= MAX_WALL_SEC:
		if enemies.size() >= MIN_ENEMIES:
			_pass(enemies.size())
		else:
			_fail("only %d enemies after %.0fs (need %d)" % [enemies.size(), elapsed, MIN_ENEMIES])
		return

func _pass(enemy_count: int) -> void:
	print("PASS: brotato3d_spawn_stress enemies=%d max_delta=%.3f max_spike=%.3f" % [
		enemy_count, _max_delta, _max_spike
	])
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("FAIL: brotato3d_spawn_stress: ", msg)
	get_tree().quit(1)
