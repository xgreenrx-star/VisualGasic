extends SceneTree

# ── VG Browser Dashboard — system-tray launcher ────────────────────────────
# Phase-5c of the Browser Dashboard work.  Like vg_dashboard_headless.gd, but
# also installs a system status indicator (tray icon) via
# DisplayServer.create_status_indicator() when the platform supports it
# (macOS and Windows per Godot 4.6 docs).
#
# Usage:
#   godot --path <project> -s addons/visual_gasic/vg_dashboard_tray.gd \
#         [--port=N] [--bind=A]
#
# Note: this script does NOT pass --headless because the status indicator
# needs a real display server.  We hide the main window immediately so the
# only visible UI is the tray icon.
#
# Tray callback receives (mouse_button, position).  Left click opens the
# dashboard URL in the default browser; right click does nothing (the OS
# popup menu is wired via NativeMenu where supported).

const _ServerCls := preload("res://addons/visual_gasic/vg_dashboard_server.gd")
const _ICON_PATH := "res://addons/visual_gasic/icon.png"

var _srv: Node = null
var _port: int = 8765
var _bind: String = "127.0.0.1"
var _indicator_id: int = -1
var _menu_rid: RID


func _parse_args() -> void:
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
	# Hide the main window: the tray icon is the entire UI.  Using
	# WINDOW_MODE_MINIMIZED keeps the process attached to the display
	# server (required for the status indicator) without showing a window.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
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

	# Try to install a system tray icon.  Falls back to a stderr notice.
	if DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
		_install_tray(url)
	else:
		print("[VG] System tray not supported on this platform "
			+ "(DisplayServer=%s) — running without tray icon." % DisplayServer.get_name())
		print("[VG] Open the URL above manually; Ctrl+C in this terminal to stop.")


func _install_tray(url: String) -> void:
	var icon_tex: Texture2D = null
	if ResourceLoader.exists(_ICON_PATH):
		icon_tex = load(_ICON_PATH)
	if icon_tex == null:
		push_warning("[VG] Tray icon missing at %s — using empty icon." % _ICON_PATH)
		# Construct a 1×1 transparent placeholder so the call still succeeds.
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		icon_tex = ImageTexture.create_from_image(img)
	var tooltip := "VG Dashboard — %s" % url
	_indicator_id = DisplayServer.create_status_indicator(
		icon_tex, tooltip, Callable(self, "_on_tray_click"))
	if _indicator_id == DisplayServer.INVALID_INDICATOR_ID:
		push_warning("[VG] DisplayServer.create_status_indicator() refused — no tray.")
		return
	# Attach a NativeMenu popup (right-click on Windows, any click on macOS).
	if NativeMenu and NativeMenu.has_feature(NativeMenu.FEATURE_POPUP_MENU):
		_menu_rid = NativeMenu.create_menu()
		NativeMenu.add_item(_menu_rid, "Open dashboard…",
			Callable(self, "_menu_open"))
		NativeMenu.add_separator(_menu_rid)
		NativeMenu.add_item(_menu_rid, "Quit",
			Callable(self, "_menu_quit"))
		DisplayServer.status_indicator_set_menu(_indicator_id, _menu_rid)
	print("[VG] Tray icon installed.  Left-click to open dashboard.")


func _on_tray_click(mouse_button: int, _pos: Vector2i) -> void:
	# MouseButton.LEFT == 1.
	if mouse_button == MOUSE_BUTTON_LEFT and _srv != null:
		OS.shell_open(String(_srv.get_url()))


func _menu_open(_tag: Variant = null) -> void:
	if _srv != null:
		OS.shell_open(String(_srv.get_url()))


func _menu_quit(_tag: Variant = null) -> void:
	quit()


func _finalize() -> void:
	if _indicator_id != -1 and _indicator_id != DisplayServer.INVALID_INDICATOR_ID:
		DisplayServer.delete_status_indicator(_indicator_id)
		_indicator_id = -1
	if _menu_rid.is_valid() and NativeMenu:
		NativeMenu.free_menu(_menu_rid)
	if _srv != null and _srv.has_method("stop_server"):
		_srv.stop_server()
