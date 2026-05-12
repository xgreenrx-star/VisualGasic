extends SceneTree

# ── VG Browser Dashboard — headless launcher ───────────────────────────────
# Phase-5b of the Browser Dashboard work.  Runs the embedded dashboard
# server without opening the full VG IDE.  Designed to be invoked as:
#
#   godot --headless --path <project> \
#         -s addons/visual_gasic/vg_dashboard_headless.gd [--port=N] [--bind=A]
#
# The `vg-dashboard` shell wrapper in the repo root handles binary lookup
# and project resolution.
#
# Lifecycle:
#   _initialize() spawns a VGDashboardServer under the SceneTree root, calls
#   start_server(), then prints the URL and pins the process open.  SIGINT
#   (Ctrl+C) triggers Godot's default shutdown path which calls _finalize().

const _ServerCls := preload("res://addons/visual_gasic/vg_dashboard_server.gd")

var _srv: Node = null
var _port: int = 8765
var _bind: String = "127.0.0.1"


func _parse_args() -> void:
	# OS.get_cmdline_user_args() returns args after a `--` separator on the
	# Godot CLI.  When invoked via `-s script.gd --port=…`, the dashboard
	# flags arrive in get_cmdline_args() instead, so we walk both lists.
	var all_args: Array = []
	all_args.append_array(OS.get_cmdline_args())
	all_args.append_array(OS.get_cmdline_user_args())
	for a in all_args:
		var s := String(a)
		if s.begins_with("--port="):
			var v := s.substr("--port=".length()).to_int()
			if v > 0 and v < 65536:
				_port = v
		elif s.begins_with("--bind="):
			var v := s.substr("--bind=".length())
			if not v.is_empty():
				_bind = v


func _initialize() -> void:
	_parse_args()
	# Defer to the first idle frame so the SceneTree root is fully wired
	# before we attach the server (and its Timer child).
	_boot.call_deferred()


func _boot() -> void:
	_srv = _ServerCls.new()
	_srv.name = "VGDashboardServer"
	root.add_child(_srv)
	var ok: bool = _srv.start_server(_port, _bind)
	if not ok:
		push_error("[VG] Dashboard failed to bind on %s:%d" % [_bind, _port])
		quit(1)
		return
	var url: String = String(_srv.get_url())
	print("[VG] Browser Dashboard running at %s" % url)
	print("[VG] Press Ctrl+C to stop.")


func _finalize() -> void:
	if _srv != null and _srv.has_method("stop_server"):
		_srv.stop_server()
