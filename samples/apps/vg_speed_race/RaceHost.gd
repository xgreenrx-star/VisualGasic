extends Control
## Side-by-side Visual Gasic vs GDScript particle race.
## Fair demo requires EngineDebugger NOT active (CLI or Project Manager Run).
## Window title "(DEBUG)" only means the editor/debug binary — it is normal.

const PANEL := 420.0
const DEFAULT_N := 500
const BUDGET_USEC := 8000
const TICK_DT := 1.0 / 40.0
const RACE_GOAL := 3000
const FAIR_CMD := "./scripts/run_speed_race.sh"
const BG := Color(0.035, 0.047, 0.075)
const SURFACE := Color(0.075, 0.094, 0.137)
const SURFACE_ALT := Color(0.095, 0.118, 0.169)
const TEXT_MAIN := Color(0.88, 0.92, 0.98)
const TEXT_MUTED := Color(0.53, 0.60, 0.71)
const VG_ACCENT := Color(0.35, 0.91, 0.62)
const GD_ACCENT := Color(0.33, 0.70, 1.0)
const WARN_ACCENT := Color(1.0, 0.71, 0.34)
const ERROR_ACCENT := Color(1.0, 0.39, 0.40)

var sim_gd: Node2D
var sim_vg: Node2D
var lbl_gd: Label
var lbl_vg: Label
var detail_gd: Label
var detail_vg: Label
var lbl_verdict: Label
var lbl_hint: Label
var lbl_mode: Label
var lbl_warn: Label
var bar_vg: ProgressBar
var bar_gd: ProgressBar
var btn_budget: Button
var btn_same: Button
var btn_calls: Button
var btn_inline: Button
var about_window: Window
var workload_picker: OptionButton
var btn_particles: Array[Button] = []
var use_calls: bool = true
var budget_race: bool = true
var particle_n: int = DEFAULT_N
var workload_mode: int = 0
var ema_gd: float = 0.0
var ema_vg: float = 0.0
var ema_ticks_gd: float = 0.0
var ema_ticks_vg: float = 0.0
var total_ticks_gd: int = 0
var total_ticks_vg: int = 0
var frames: int = 0
var mismatch_frames: int = 0
var race_finished: bool = false
var finish_factor: float = 0.0
var debugger_active: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = _make_theme()

	var background := ColorRect.new()
	background.color = BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 2)
	header.add_child(heading)
	var title := Label.new()
	title.text = "VG SPEED RACE"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TEXT_MAIN)
	heading.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Matched workloads. Compare completed work under equal time."
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", TEXT_MUTED)
	heading.add_child(subtitle)
	var live_tag := Label.new()
	live_tag.text = "  LIVE BENCHMARK  "
	live_tag.add_theme_font_size_override("font_size", 11)
	live_tag.add_theme_color_override("font_color", VG_ACCENT)
	live_tag.add_theme_stylebox_override("normal", _make_box(SURFACE_ALT, VG_ACCENT.darkened(0.6), 8, 1))
	live_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(live_tag)
	var about_button := _add_btn(header, "About & results", _show_about)
	about_button.tooltip_text = "What this race measures and the published VG / GDScript / C++ results"

	var controls := _make_card(root, SURFACE)
	var control_rows := VBoxContainer.new()
	control_rows.add_theme_constant_override("separation", 10)
	controls.add_child(_padded(control_rows, 12, 12))

	var top_controls := HBoxContainer.new()
	top_controls.add_theme_constant_override("separation", 24)
	control_rows.add_child(top_controls)
	var scenario_group := _make_control_group(top_controls, "RACE")
	workload_picker = OptionButton.new()
	workload_picker.add_item("Particles")
	workload_picker.add_item("Arithmetic")
	workload_picker.add_item("Array scan")
	workload_picker.add_item("Dictionary reads")
	workload_picker.add_item("Branching")
	workload_picker.add_item("String building")
	workload_picker.add_item("Function calls")
	workload_picker.item_selected.connect(_set_workload)
	scenario_group.get_child(1).add_child(workload_picker)
	var race_group := _make_control_group(top_controls, "RACE MODE")
	var race_buttons := race_group.get_child(1) as HBoxContainer
	btn_budget = _toggle(race_buttons, "Time budget", true, func(): _set_budget(true))
	btn_same = _toggle(race_buttons, "Same steps", false, func(): _set_budget(false))
	var math_group := _make_control_group(top_controls, "WORKLOAD")
	var math_buttons := math_group.get_child(1) as HBoxContainer
	btn_calls = _toggle(math_buttons, "Calls  ·  1", true, func(): _set_mode(true))
	btn_inline = _toggle(math_buttons, "Inline  ·  2", false, func(): _set_mode(false))

	var lower_controls := HBoxContainer.new()
	lower_controls.add_theme_constant_override("separation", 8)
	control_rows.add_child(lower_controls)
	var particle_group := _make_control_group(lower_controls, "WORK SIZE")
	particle_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var particle_buttons := particle_group.get_child(1) as HBoxContainer
	btn_particles.append(_particle_button(particle_buttons, "300", 300))
	btn_particles.append(_particle_button(particle_buttons, "500  ·  typical", 500))
	btn_particles.append(_particle_button(particle_buttons, "1,200", 1200))
	btn_particles.append(_particle_button(particle_buttons, "3,000  ·  heavy", 3000))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	lower_controls.add_child(actions)
	_add_btn(actions, "Restart", func(): _reset_both())
	_add_btn(actions, "Copy fair-run command", func(): _copy_fair_cmd())

	var status_card := _make_card(root, SURFACE)
	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 3)
	status_card.add_child(_padded(status, 10, 10))
	lbl_warn = Label.new()
	lbl_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_warn.add_theme_font_size_override("font_size", 12)
	status.add_child(lbl_warn)
	lbl_mode = Label.new()
	lbl_mode.add_theme_font_size_override("font_size", 11)
	lbl_mode.add_theme_color_override("font_color", TEXT_MUTED)
	status.add_child(lbl_mode)
	lbl_verdict = Label.new()
	lbl_verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_verdict.add_theme_font_size_override("font_size", 14)
	lbl_verdict.add_theme_color_override("font_color", TEXT_MAIN)
	status.add_child(lbl_verdict)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	root.add_child(row)

	var left := _make_panel(row, "VISUAL GASIC", ".vg  ·  native language", VG_ACCENT)
	var right := _make_panel(row, "GDSCRIPT", ".gd  ·  engine baseline", GD_ACCENT)
	lbl_vg = left["label"]
	lbl_gd = right["label"]
	detail_vg = left["detail"]
	detail_gd = right["detail"]
	bar_vg = left["bar"]
	bar_gd = right["bar"]

	sim_vg = Node2D.new()
	sim_vg.set_script(load("res://sim_vg.vg"))
	left["viewport"].add_child(sim_vg)

	sim_gd = Node2D.new()
	sim_gd.set_script(load("res://sim_gd.gd"))
	right["viewport"].add_child(sim_gd)

	await get_tree().process_frame
	_reset_both()

func _show_about() -> void:
	if about_window == null:
		about_window = _build_about_window()
		add_child(about_window)
	about_window.popup_centered(Vector2i(920, 740))

func _build_about_window() -> Window:
	var window := Window.new()
	window.title = "About the VG Speed Race"
	window.size = Vector2i(920, 740)
	window.min_size = Vector2i(640, 520)
	window.transient = true
	window.exclusive = false
	window.theme = theme
	window.close_requested.connect(window.hide)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	window.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	var heading := Label.new()
	heading.text = "What this demo measures"
	heading.add_theme_font_size_override("font_size", 22)
	content.add_child(heading)
	var intro := _about_text(
		"Choose Particles, Arithmetic, Array scan, Dictionary reads, Branching, String " +
		"building, or Function calls. Each race runs matched VG and GDScript work on both " +
		"sides. Checksums are compared in Same steps mode to catch workload divergence. " +
		"Particles is the animated scene: each particle advances through 24 substeps, " +
		"reflects at the simulation bounds, and contributes to a checksum."
	)
	content.add_child(intro)
	var modes := _about_text(
		"Time budget gives each language an equal time slice and compares completed ticks. " +
		"Same steps runs the same number of updates and compares elapsed time and checksum. " +
		"Calls / Inline is available for Particles and Function calls; it compares helper " +
		"calls with the same operation written inline. Work size sets the workload batch size. " +
		"The live races compare VG with GDScript; there is no C++ lane."
	)
	content.add_child(modes)
	var fair_run := _about_text(
		"For a fair result, run from Project Manager or with ./scripts/run_speed_race.sh, " +
		"not with the editor script debugger attached. A debugger changes the VG execution " +
		"path and can distort timings. Results vary with CPU load, engine build, and platform."
	)
	fair_run.add_theme_color_override("font_color", WARN_ACCENT)
	content.add_child(fair_run)

	var vm_heading := _about_heading("Latest VM microbenchmark · 18 Nov 2026")
	content.add_child(vm_heading)
	content.add_child(_about_text(
		"Published from BENCHMARK_PUBLISHED_RESULTS.md. Best-of-5 loop timings, N=200,000, " +
		"Linux x86-64 on a quiet pinned-core run. Ratio is VG/GDScript; below 1.00 means VG " +
		"was faster. This suite compares VG and GDScript only, not C++."
	))
	content.add_child(_about_text(
		"Live race coverage: Function calls, Array scan, Dictionary reads, Arithmetic, " +
		"Branching, and String building. The VM table is a separate per-operation " +
		"microbenchmark; its measurements are not the live race timings."
	))
	content.add_child(_about_table(
		["Workload", "GDScript", "VG JIT", "VG/GD", "VG JIT=0", "VG/GD"],
		[
			["Local loop", "9.5 ns", "1.9 ns", "0.20×", "5.2 ns", "0.59×"],
			["Integer global", "9.8 ns", "0.6 ns", "0.07×", "6.5 ns", "0.70×"],
			["Vector2 add", "11.8 ns", "4.4 ns", "0.37×", "5.0 ns", "0.42×"],
			["Dictionary read", "32.5 ns", "29.0 ns", "0.89×", "30.8 ns", "0.95×"],
			["String compare", "28.8 ns", "24.6 ns", "0.86×", "30.0 ns", "0.99×"],
			["Function call", "61.1 ns", "1.9 ns", "0.03×", "5.7 ns", "0.10×"],
			["GDScript → VG call", "63.5 ns", "56.7 ns", "0.89×", "56.4 ns", "0.99×"],
		]
	))

	var published_heading := _about_heading("Published three-language suite · 25 Aug 2026")
	content.add_child(published_heading)
	content.add_child(_about_text(
		"Canonical compute and draw results from BENCHMARK_PUBLISHED_RESULTS.md. These " +
		"portable bytecode benchmarks do not enable the native JIT. Times are total elapsed " +
		"microseconds; lower is faster. A dash means that the published suite has no C++ " +
		"measurement for that workload."
	))
	content.add_child(_about_table(
		["Compute workload", "GDScript", "VG", "C++", "VG faster vs GD"],
		[
			["Arithmetic", "3,756 µs", "27 µs", "62 µs", "139×"],
			["Array sum", "5,244 µs", "265 µs", "56 µs", "20×"],
			["String concatenate", "7,257 µs", "140 µs", "717 µs", "52×"],
			["Branching", "10,354 µs", "152 µs", "85 µs", "68×"],
			["Function call", "8,448 µs", "140 µs", "—", "60×"],
			["Array + Dictionary", "16,216 µs", "4,391 µs", "5,602 µs", "3.7×"],
			["Dictionary fast get", "41,845 µs", "3,545 µs", "—", "12×"],
			["Dictionary fast set", "27,891 µs", "3,170 µs", "—", "8.8×"],
			["Interop", "11,260 µs", "267 µs", "9,940 µs", "42×"],
			["Allocations", "9,069 µs", "212 µs", "655 µs", "43×"],
			["Fast allocations", "13,716 µs", "1,749 µs", "498 µs", "7.8×"],
			["File I/O", "1,267 µs", "710 µs", "552 µs", "1.8×"],
		]
	))
	content.add_child(_about_table(
		["Draw workload (separate suite)", "GDScript", "VG", "C++", "VG faster vs GD"],
		[
			["Filled rectangles", "1,078 µs", "160 µs", "110 µs", "6.7×"],
			["Outline rectangles", "1,467 µs", "554 µs", "371 µs", "2.6×"],
			["Lines", "1,142 µs", "276 µs", "105 µs", "4.1×"],
			["Circles", "3,226 µs", "2,552 µs", "2,288 µs", "1.3×"],
			["Sprites", "862 µs", "321 µs", "81 µs", "2.7×"],
			["Polylines", "1,582 µs", "881 µs", "682 µs", "1.8×"],
			["Mixed primitives", "4,966 µs", "2,632 µs", "2,343 µs", "1.9×"],
			["Vector canvas rectangles", "1,038 µs", "191 µs", "189 µs", "5.4×"],
			["Moving rectangles†", "144 µs", "25 µs", "25 µs", "5.8×"],
		]
	))
	var source := _about_text(
		"† Moving-rectangle values are average draw time per frame; other draw rows are " +
		"total time for their listed workload. Source: BENCHMARK_PUBLISHED_RESULTS.md. " +
		"Reproduction scripts and methodology are " +
		"in that document. Published results are machine- and workload-specific, not a " +
		"guarantee that VG is faster for every program. Draw timings remain a separate " +
		"suite because they measure rendered workloads, not the script-side CPU race above."
	)
	source.add_theme_color_override("font_color", TEXT_MUTED)
	content.add_child(source)
	var footer := HBoxContainer.new()
	footer.alignment = HBoxContainer.ALIGNMENT_END
	layout.add_child(footer)
	_add_btn(footer, "Close", window.hide)
	return window

func _about_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", VG_ACCENT)
	return label

func _about_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", TEXT_MAIN)
	return label

func _about_table(headers: Array, rows: Array) -> GridContainer:
	var table := GridContainer.new()
	table.columns = headers.size()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("h_separation", 8)
	table.add_theme_constant_override("v_separation", 3)
	for i in headers.size():
		table.add_child(_table_cell(str(headers[i]), true, i == 0))
	for row: Array in rows:
		for i in row.size():
			table.add_child(_table_cell(str(row[i]), false, i == 0))
	return table

func _table_cell(text: String, is_header: bool, is_label: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 95 if is_label else 78
	label.add_theme_font_size_override("font_size", 11 if not is_header else 10)
	label.add_theme_color_override(
		"font_color",
		TEXT_MUTED if is_header else (TEXT_MAIN if is_label else VG_ACCENT)
	)
	if is_header:
		label.add_theme_stylebox_override("normal", _make_box(SURFACE_ALT, SURFACE_ALT, 3, 0))
	elif is_label:
		label.add_theme_stylebox_override("normal", _make_box(SURFACE, SURFACE, 3, 0))
	return label

func _make_theme() -> Theme:
	var app_theme := Theme.new()
	app_theme.set_color("font_color", "Label", TEXT_MAIN)
	app_theme.set_color("font_hover_color", "Button", TEXT_MAIN)
	app_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	app_theme.set_color("font_focus_color", "Button", TEXT_MAIN)
	app_theme.set_color("font_disabled_color", "Button", TEXT_MUTED)
	app_theme.set_font_size("font_size", "Button", 12)
	app_theme.set_stylebox("normal", "Button", _make_box(SURFACE_ALT, Color(0.17, 0.22, 0.31), 6, 1))
	app_theme.set_stylebox("hover", "Button", _make_box(Color(0.14, 0.19, 0.27), Color(0.28, 0.38, 0.51), 6, 1))
	app_theme.set_stylebox("pressed", "Button", _make_box(Color(0.10, 0.27, 0.22), VG_ACCENT.darkened(0.2), 6, 1))
	app_theme.set_stylebox("focus", "Button", _make_box(Color.TRANSPARENT, VG_ACCENT, 6, 1))
	app_theme.set_stylebox("disabled", "Button", _make_box(SURFACE, SURFACE_ALT, 6, 1))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = app_theme.get_stylebox(state, "Button")
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
	app_theme.set_stylebox("background", "ProgressBar", _make_box(Color(0.035, 0.045, 0.067), Color(0.13, 0.16, 0.22), 5, 1))
	return app_theme

func _make_box(fill: Color, border: Color, radius: int = 8, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_card(parent: Control, fill: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_box(fill, Color(0.14, 0.18, 0.25), 9, 1))
	parent.add_child(card)
	return card

func _padded(content: Control, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	margin.add_child(content)
	return margin

func _make_control_group(parent: Control, heading_text: String) -> VBoxContainer:
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wrapper.add_theme_constant_override("separation", 5)
	parent.add_child(wrapper)
	var heading := Label.new()
	heading.text = heading_text
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", TEXT_MUTED)
	wrapper.add_child(heading)
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 6)
	wrapper.add_child(group)
	return wrapper

func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l

func _make_bar(parent: Control, accent: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = RACE_GOAL
	bar.value = 0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("fill", _make_box(accent, accent, 5, 0))
	parent.add_child(bar)
	return bar

func _make_panel(parent: Control, caption: String, detail: String, accent: Color) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_box(SURFACE, accent.darkened(0.68), 10, 1))
	parent.add_child(card)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 7)
	card.add_child(_padded(col, 10, 10))
	var name_lbl := Label.new()
	name_lbl.text = caption
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", accent)
	col.add_child(name_lbl)
	var detail_lbl := Label.new()
	detail_lbl.text = detail
	detail_lbl.add_theme_font_size_override("font_size", 11)
	detail_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	col.add_child(detail_lbl)
	var stats := Label.new()
	stats.text = "warming up…"
	stats.add_theme_font_size_override("font_size", 12)
	col.add_child(stats)
	var bar := _make_bar(col, accent)
	var viewport_frame := AspectRatioContainer.new()
	viewport_frame.ratio = 1.0
	viewport_frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	viewport_frame.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	viewport_frame.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	viewport_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_frame.custom_minimum_size = Vector2(0, 250)
	col.add_child(viewport_frame)
	var host := SubViewportContainer.new()
	host.stretch = true
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_theme_stylebox_override("panel", _make_box(Color(0.035, 0.045, 0.067), Color(0.13, 0.16, 0.22), 7, 1))
	viewport_frame.add_child(host)
	var vp := SubViewport.new()
	vp.size = Vector2i(int(PANEL), int(PANEL))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	return {"label": stats, "detail": detail_lbl, "bar": bar, "viewport": vp}

func _add_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _toggle(parent: Control, text: String, start_on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = start_on
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _particle_button(parent: Control, text: String, count: int) -> Button:
	var button := _toggle(parent, text, count == DEFAULT_N, func(): _set_n(count))
	button.set_meta("particle_count", count)
	return button

func _refresh_toggles() -> void:
	if btn_budget:
		btn_budget.button_pressed = budget_race
		btn_same.button_pressed = not budget_race
		btn_calls.button_pressed = use_calls
		btn_inline.button_pressed = not use_calls
		btn_calls.disabled = workload_mode != 0 and workload_mode != 6
		btn_inline.disabled = btn_calls.disabled
	if workload_picker:
		workload_picker.select(workload_mode)
		btn_calls.get_parent().get_parent().visible = workload_mode == 0 or workload_mode == 6
	for button in btn_particles:
		button.button_pressed = int(button.get_meta("particle_count")) == particle_n

func _debugger_on() -> bool:
	# True only when the editor script debugger is attached (Play from an open project).
	# False for Project Manager Run and ./scripts/run_speed_race.sh.
	return EngineDebugger != null and EngineDebugger.is_active()

func _copy_fair_cmd() -> void:
	DisplayServer.clipboard_set(FAIR_CMD)
	lbl_verdict.text = "Copied to clipboard: %s  — quit this window, run that from the repo root." % FAIR_CMD
	lbl_verdict.modulate = Color(0.7, 0.9, 1.0)

func _set_budget(on: bool) -> void:
	budget_race = on
	_reset_both()

func _set_mode(calls: bool) -> void:
	use_calls = calls
	_reset_both()

func _set_n(n: int) -> void:
	particle_n = n
	_reset_both()

func _set_workload(mode: int) -> void:
	workload_mode = mode
	_reset_both()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_set_mode(true)
			KEY_2:
				_set_mode(false)
			KEY_R:
				_reset_both()

func _total_tick_ratio() -> float:
	if total_ticks_gd <= 0:
		return 0.0
	return float(total_ticks_vg) / float(total_ticks_gd)

func _reset_both() -> void:
	ema_gd = 0.0
	ema_vg = 0.0
	ema_ticks_gd = 0.0
	ema_ticks_vg = 0.0
	total_ticks_gd = 0
	total_ticks_vg = 0
	frames = 0
	mismatch_frames = 0
	race_finished = false
	finish_factor = 0.0
	debugger_active = _debugger_on()
	_refresh_toggles()
	if bar_vg:
		bar_vg.value = 0
	if bar_gd:
		bar_gd.value = 0
	var race_name := "BUDGET" if budget_race else "SAME-STEPS"
	lbl_mode.text = "%s · %s" % [race_name, _workload_detail()]
	if lbl_vg:
		lbl_vg.text = "warming up…"
	if lbl_gd:
		lbl_gd.text = "warming up…"
	if detail_vg:
		detail_vg.text = _workload_detail()
	if detail_gd:
		detail_gd.text = _workload_detail()
	sim_vg.call("SelectWorkload", workload_mode)
	sim_gd.call("select_workload", workload_mode)
	sim_vg.call("Reset", particle_n, PANEL, PANEL, use_calls)
	sim_gd.call("reset", particle_n, PANEL, PANEL, use_calls)

	if debugger_active:
		lbl_warn.modulate = ERROR_ACCENT
		lbl_warn.text = "UNFAIR RUN: editor script debugger is attached (Play from an open project). VG keeps line-debug on and will often lose. Quit → Project Manager → Run, or: " + FAIR_CMD
		lbl_verdict.modulate = ERROR_ACCENT
		lbl_verdict.text = "Results below are not a fair VG vs GD race. Ctrl+F5 does NOT clear (DEBUG) in the title — and often still attaches. Use Project Manager Run or the shell script."
	else:
		lbl_warn.modulate = VG_ACCENT
		lbl_warn.text = "Fair run (no script debugger). Green = VG · blue = GDScript. Select a race workload above."
		lbl_verdict.modulate = TEXT_MAIN
		lbl_verdict.text = "Warming up…"

func _fmt_time(usec: float) -> String:
	if usec >= 1000.0:
		return "%.1f ms/tick" % (usec / 1000.0)
	return "%d µs/tick" % int(usec)

func _workload_detail() -> String:
	var names := [
		"Particles", "Arithmetic", "Array scan", "Dictionary reads",
		"Branching", "String building", "Function calls",
	]
	var detail := "%s · size %d" % [names[workload_mode], particle_n]
	if workload_mode == 0:
		detail = "%s · %d particles · 24 substeps" % [names[workload_mode], particle_n]
	if workload_mode == 0 or workload_mode == 6:
		detail += " · %s" % ("Calls" if use_calls else "Inline")
	return detail

func _process(_delta: float) -> void:
	if sim_gd == null or sim_vg == null:
		return

	# Re-check: debugger can attach a frame late after Play.
	if not debugger_active and _debugger_on():
		debugger_active = true
		lbl_warn.modulate = ERROR_ACCENT
		lbl_warn.text = "UNFAIR RUN: script debugger just attached. Quit and use Project Manager Run or " + FAIR_CMD

	if race_finished:
		if bool(sim_gd.get("dirty")):
			sim_gd.queue_redraw()
		if bool(sim_vg.get("Dirty")):
			sim_vg.queue_redraw()
		return

	var ticks_vg := 0
	var ticks_gd := 0
	var ug := 0
	var uv := 0

	if budget_race:
		ticks_vg = int(sim_vg.call("RunBudget", BUDGET_USEC, TICK_DT))
		ticks_gd = int(sim_gd.call("run_budget", BUDGET_USEC, TICK_DT))
		total_ticks_vg += ticks_vg
		total_ticks_gd += ticks_gd
		uv = int(sim_vg.get("LastUsec"))
		ug = int(sim_gd.get("last_usec"))
	else:
		sim_vg.call("Step", TICK_DT)
		sim_gd.call("step", TICK_DT)
		ticks_vg = 1
		ticks_gd = 1
		uv = int(sim_vg.get("LastUsec"))
		ug = int(sim_gd.get("last_usec"))
		total_ticks_vg += 1
		total_ticks_gd += 1
	if not budget_race or workload_mode != 0:
		if absf(float(sim_gd.get("last_checksum")) - float(sim_vg.get("LastChecksum"))) > 0.05:
			mismatch_frames += 1

	if bool(sim_gd.get("dirty")):
		sim_gd.queue_redraw()
	if bool(sim_vg.get("Dirty")):
		sim_vg.queue_redraw()

	frames += 1
	if frames < 10:
		return

	var a := 0.12 if frames > 20 else 0.4
	ema_gd = lerpf(ema_gd, float(ug), a)
	ema_vg = lerpf(ema_vg, float(uv), a)
	ema_ticks_gd = lerpf(ema_ticks_gd, float(ticks_gd), a)
	ema_ticks_vg = lerpf(ema_ticks_vg, float(ticks_vg), a)

	bar_vg.value = mini(float(total_ticks_vg), float(RACE_GOAL))
	bar_gd.value = mini(float(total_ticks_gd), float(RACE_GOAL))

	var tick_ratio := _total_tick_ratio()
	var time_ratio := (ema_vg / ema_gd) if ema_gd > 0.5 else 0.0

	if budget_race:
		lbl_vg.text = "%d ticks/frame · total %d · %s" % [int(ema_ticks_vg), total_ticks_vg, _fmt_time(ema_vg)]
		lbl_gd.text = "%d ticks/frame · total %d · %s" % [int(ema_ticks_gd), total_ticks_gd, _fmt_time(ema_gd)]
	else:
		lbl_vg.text = _fmt_time(ema_vg)
		lbl_gd.text = _fmt_time(ema_gd)

	if frames < 18:
		if not debugger_active:
			lbl_verdict.text = "Measuring…"
		return

	if debugger_active:
		lbl_verdict.modulate = ERROR_ACCENT
		lbl_verdict.text = "Debugger attached — ignore who is ahead. Quit this window → Godot Project Manager → select VG Speed Race → Run. Or shell: %s" % FAIR_CMD
		return

	if mismatch_frames > 0:
		lbl_verdict.text = "Checksum mismatch — sims disagree."
		lbl_verdict.modulate = ERROR_ACCENT
		return

	if budget_race:
		if workload_mode == 0 and not use_calls:
			lbl_warn.text = "INLINE is a near-tie by design. Switch to CALLS (button 1) for the VG win."
			lbl_warn.modulate = WARN_ACCENT
		elif particle_n >= 3000:
			lbl_warn.text = "Large work size can make the 8 ms time slice noisy. Try 500 for a steadier race."
			lbl_warn.modulate = WARN_ACCENT
		else:
			lbl_warn.text = "Fair run. Green = VG · Blue = GD. First to %d ticks wins." % RACE_GOAL
			lbl_warn.modulate = VG_ACCENT

		if total_ticks_vg >= RACE_GOAL or total_ticks_gd >= RACE_GOAL:
			race_finished = true
			finish_factor = tick_ratio
			if total_ticks_vg > total_ticks_gd:
				lbl_verdict.modulate = VG_ACCENT
				lbl_verdict.text = "Race over: Visual Gasic wins %d–%d (%.1f× more work). Restart to race again." % [
					total_ticks_vg, total_ticks_gd, finish_factor]
			elif total_ticks_gd > total_ticks_vg:
				lbl_verdict.modulate = ERROR_ACCENT
				lbl_verdict.text = "Race over: GDScript wins %d–%d. Check the selected workload and use a fair launch (%s)." % [
					total_ticks_gd, total_ticks_vg, FAIR_CMD]
			else:
				lbl_verdict.text = "Race over: tie."
			return

		if tick_ratio > 1.15:
			lbl_verdict.modulate = VG_ACCENT
			lbl_verdict.text = "VG is pulling ahead — %.1f× more total ticks (%d vs %d)." % [
				tick_ratio, total_ticks_vg, total_ticks_gd]
		elif tick_ratio < 0.85:
			lbl_verdict.modulate = ERROR_ACCENT
			lbl_verdict.text = "GD ahead (%.2f×, %d vs %d). Need CALLS + N=500 + fair launch." % [
				tick_ratio, total_ticks_vg, total_ticks_gd]
		else:
			lbl_verdict.modulate = WARN_ACCENT
			lbl_verdict.text = "Close (%.2f×, %d vs %d)." % [tick_ratio, total_ticks_vg, total_ticks_gd]
	else:
		var vg_faster := ema_vg < ema_gd and ema_vg > 0.5
		var factor := (ema_gd / ema_vg) if vg_faster else ((ema_vg / ema_gd) if ema_gd > 0.5 else 0.0)
		if vg_faster:
			lbl_verdict.modulate = VG_ACCENT
			lbl_verdict.text = "Same-steps: VG tick ~%.1f× cheaper (vg/gd=%.2f). Switch to Budget for a visual race." % [
				factor, time_ratio]
		else:
			lbl_verdict.modulate = ERROR_ACCENT
			lbl_verdict.text = "Same-steps: GD cheaper (vg/gd=%.2f)." % time_ratio
