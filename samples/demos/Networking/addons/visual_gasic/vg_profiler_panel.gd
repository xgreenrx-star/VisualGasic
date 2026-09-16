@tool
extends VBoxContainer
## VisualGasic Profiler Panel
##
## Bytecode-level performance profiler for VisualGasic scripts.
## Shows per-function timing, call counts, and hot-path highlighting.
## Integrates with the C++ VisualGasicProfiler via the debug protocol.

signal profiling_toggled(enabled: bool)

# ---- UI elements ----
var _toolbar: HBoxContainer
var _toggle_btn: Button
var _refresh_btn: Button
var _clear_btn: Button
var _export_btn: Button
var _status_label: Label
var _tree: Tree
var _counter_tree: Tree
var _tab_container: TabContainer

# ---- State ----
var _debugger_plugin: EditorDebuggerPlugin = null
var _profiling_active: bool = false
var _last_report: Dictionary = {}
var _auto_refresh_timer: Timer = null

# Color thresholds (total_time_ms)
const HOT_THRESHOLD := 50.0   # Red
const WARM_THRESHOLD := 10.0  # Orange
const COOL_THRESHOLD := 1.0   # Yellow

func _ready() -> void:
	name = "Profiler"
	_build_ui()

# ============================================================================
# UI CONSTRUCTION
# ============================================================================

func _build_ui() -> void:
	# ---- Toolbar ----
	_toolbar = HBoxContainer.new()
	add_child(_toolbar)

	_toggle_btn = Button.new()
	_toggle_btn.text = "▶ Start Profiling"
	_toggle_btn.tooltip_text = "Start / stop collecting profiling data"
	_toggle_btn.toggle_mode = true
	_toggle_btn.toggled.connect(_on_toggle_profiling)
	_toolbar.add_child(_toggle_btn)

	_refresh_btn = Button.new()
	_refresh_btn.text = "🔄 Refresh"
	_refresh_btn.tooltip_text = "Fetch latest profiling data from running game"
	_refresh_btn.pressed.connect(_request_profile_data)
	_toolbar.add_child(_refresh_btn)

	_clear_btn = Button.new()
	_clear_btn.text = "🗑 Clear"
	_clear_btn.tooltip_text = "Reset profiler counters"
	_clear_btn.pressed.connect(_clear_profile_data)
	_toolbar.add_child(_clear_btn)

	_export_btn = Button.new()
	_export_btn.text = "💾 Export"
	_export_btn.tooltip_text = "Export profile data to JSON"
	_export_btn.pressed.connect(_export_profile_data)
	_toolbar.add_child(_export_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar.add_child(spacer)

	_status_label = Label.new()
	_status_label.text = "Profiler idle"
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	_toolbar.add_child(_status_label)

	# ---- Tabs ----
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tab_container)

	# -- Functions tab --
	var functions_panel := VBoxContainer.new()
	functions_panel.name = "Functions"
	_tab_container.add_child(functions_panel)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = 7
	_tree.set_column_title(0, "Function")
	_tree.set_column_title(1, "Category")
	_tree.set_column_title(2, "Calls")
	_tree.set_column_title(3, "Total (ms)")
	_tree.set_column_title(4, "Avg (ms)")
	_tree.set_column_title(5, "Min (ms)")
	_tree.set_column_title(6, "Max (ms)")
	_tree.column_titles_visible = true
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 100)
	_tree.set_column_expand(2, false)
	_tree.set_column_custom_minimum_width(2, 65)
	_tree.set_column_expand(3, false)
	_tree.set_column_custom_minimum_width(3, 85)
	_tree.set_column_expand(4, false)
	_tree.set_column_custom_minimum_width(4, 75)
	_tree.set_column_expand(5, false)
	_tree.set_column_custom_minimum_width(5, 75)
	_tree.set_column_expand(6, false)
	_tree.set_column_custom_minimum_width(6, 75)
	_tree.select_mode = Tree.SELECT_ROW
	functions_panel.add_child(_tree)

	# -- Counters tab --
	var counters_panel := VBoxContainer.new()
	counters_panel.name = "Counters"
	_tab_container.add_child(counters_panel)

	_counter_tree = Tree.new()
	_counter_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_counter_tree.columns = 4
	_counter_tree.set_column_title(0, "Counter")
	_counter_tree.set_column_title(1, "Value")
	_counter_tree.set_column_title(2, "Updates")
	_counter_tree.set_column_title(3, "Unit")
	_counter_tree.column_titles_visible = true
	_counter_tree.set_column_expand(0, true)
	_counter_tree.set_column_expand(1, false)
	_counter_tree.set_column_custom_minimum_width(1, 100)
	_counter_tree.set_column_expand(2, false)
	_counter_tree.set_column_custom_minimum_width(2, 80)
	_counter_tree.set_column_expand(3, false)
	_counter_tree.set_column_custom_minimum_width(3, 80)
	counters_panel.add_child(_counter_tree)

# ============================================================================
# DEBUGGER INTEGRATION
# ============================================================================

func set_debugger_plugin(plugin: EditorDebuggerPlugin) -> void:
	_debugger_plugin = plugin
	# The profiler_data_received signal will be connected when available
	if _debugger_plugin and _debugger_plugin.has_signal("profiler_data_received"):
		_debugger_plugin.profiler_data_received.connect(_on_profiler_data_received)

func _on_toggle_profiling(pressed: bool) -> void:
	_profiling_active = pressed
	if pressed:
		_toggle_btn.text = "⏹ Stop Profiling"
		_status_label.text = "⏺ Profiling…"
		_status_label.add_theme_color_override("font_color", Color.RED)
		_send_profiler_command("start")
		# Auto-refresh while profiling
		if _auto_refresh_timer == null:
			_auto_refresh_timer = Timer.new()
			_auto_refresh_timer.wait_time = 2.0
			_auto_refresh_timer.timeout.connect(_request_profile_data)
			add_child(_auto_refresh_timer)
		_auto_refresh_timer.start()
	else:
		_toggle_btn.text = "▶ Start Profiling"
		_status_label.text = "Profiler stopped"
		_status_label.add_theme_color_override("font_color", Color.GRAY)
		_send_profiler_command("stop")
		if _auto_refresh_timer:
			_auto_refresh_timer.stop()
	profiling_toggled.emit(pressed)

func _request_profile_data() -> void:
	_send_profiler_command("get_data")

func _clear_profile_data() -> void:
	_send_profiler_command("clear")
	_last_report = {}
	_tree.clear()
	_counter_tree.clear()
	_status_label.text = "Profiler cleared"
	_status_label.add_theme_color_override("font_color", Color.GRAY)

func _send_profiler_command(command: String) -> void:
	if _debugger_plugin and _debugger_plugin.has_method("send_profiler_command"):
		_debugger_plugin.send_profiler_command(command)
	elif _debugger_plugin and _debugger_plugin._active_session:
		_debugger_plugin._active_session.send_message("visualgasic:profiler_" + command, [])

# ============================================================================
# DATA DISPLAY
# ============================================================================

func _on_profiler_data_received(report: Dictionary) -> void:
	_last_report = report
	_update_functions_tree(report.get("profiles", {}))
	_update_counters_tree(report.get("counters", {}))

	var profile_count: int = (report.get("profiles", {}) as Dictionary).size()
	var counter_count: int = (report.get("counters", {}) as Dictionary).size()
	_status_label.text = "%d functions, %d counters" % [profile_count, counter_count]
	if _profiling_active:
		_status_label.add_theme_color_override("font_color", Color.RED)
	else:
		_status_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)

func _update_functions_tree(profiles: Dictionary) -> void:
	_tree.clear()
	if profiles.is_empty():
		return

	var root := _tree.create_item()

	# Sort by total_time_ms descending
	var entries: Array = []
	for key in profiles:
		var p: Dictionary = profiles[key]
		p["_key"] = key
		entries.append(p)
	entries.sort_custom(func(a, b): return a.get("total_time_ms", 0.0) > b.get("total_time_ms", 0.0))

	# Compute grand total for percentage coloring
	var grand_total := 0.0
	for e in entries:
		grand_total += e.get("total_time_ms", 0.0)

	for e in entries:
		var item := _tree.create_item(root)
		var total_ms: float = e.get("total_time_ms", 0.0)
		var call_count: int = e.get("call_count", 0)
		var avg_ms: float = e.get("avg_time_ms", total_ms / maxf(call_count, 1))
		var min_ms: float = e.get("min_time_ms", 0.0)
		var max_ms: float = e.get("max_time_ms", 0.0)

		item.set_text(0, e.get("name", e.get("_key", "?")))
		item.set_text(1, e.get("category", ""))
		item.set_text(2, str(call_count))
		item.set_text(3, "%.2f" % total_ms)
		item.set_text(4, "%.3f" % avg_ms)
		item.set_text(5, "%.3f" % min_ms)
		item.set_text(6, "%.3f" % max_ms)

		# Hot-path coloring
		var color := _heat_color(total_ms)
		for col in range(7):
			item.set_custom_color(col, color)

func _update_counters_tree(counters: Dictionary) -> void:
	_counter_tree.clear()
	if counters.is_empty():
		return

	var root := _counter_tree.create_item()

	# Sort alphabetically
	var keys: Array = counters.keys()
	keys.sort()

	for key in keys:
		var c: Dictionary = counters[key]
		var item := _counter_tree.create_item(root)
		item.set_text(0, c.get("name", key))
		item.set_text(1, "%.1f" % c.get("value", 0.0))
		item.set_text(2, str(c.get("count", 0)))
		item.set_text(3, c.get("unit", ""))

func _heat_color(total_ms: float) -> Color:
	if total_ms >= HOT_THRESHOLD:
		return Color(1.0, 0.3, 0.3)  # Red — hot
	elif total_ms >= WARM_THRESHOLD:
		return Color(1.0, 0.65, 0.2)  # Orange — warm
	elif total_ms >= COOL_THRESHOLD:
		return Color(1.0, 1.0, 0.4)  # Yellow — tepid
	else:
		return Color(0.6, 1.0, 0.6)  # Green — cool

# ============================================================================
# EXPORT
# ============================================================================

func _export_profile_data() -> void:
	if _last_report.is_empty():
		_status_label.text = "Nothing to export"
		return
	var path := "user://vg_profile_export.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_last_report, "\t"))
		file.close()
		_status_label.text = "Exported → " + path
		_status_label.add_theme_color_override("font_color", Color.CYAN)
	else:
		_status_label.text = "Export failed"
		_status_label.add_theme_color_override("font_color", Color.RED)
