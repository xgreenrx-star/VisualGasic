@tool
## AGCK Plugin — Arcade Game Construction Kit
##
## Bloxels-inspired unified dashboard with icon sidebar + large central workspace.
## Workflow: Levels → Actors → Sounds → Settings → Build
## Level editor is the default "hero" view with the biggest canvas.
extends "res://addons/visual_gasic/vg_plugin_base.gd"

const AGCK_DIR = "res://addons/visual_gasic/plugins/agck/"
const BuilderBackend = preload("res://addons/visual_gasic/plugins/agck/agck_builder_backend.gd")
const TileLibrary = preload("res://addons/visual_gasic/plugins/agck/agck_tile_library.gd")

# ─── Theme ───────────────────────────────────────────────────
const SIDEBAR_BG    = Color(0.09, 0.09, 0.12)
const SIDEBAR_HOVER = Color(0.15, 0.16, 0.22)
const SIDEBAR_SEL   = Color(0.22, 0.26, 0.40)
const CONTENT_BG    = Color(0.13, 0.13, 0.16)
const ACCENT        = Color(1.0, 0.82, 0.35)
const WHITE         = Color(1.0, 1.0, 1.0)
const DIM           = Color(0.55, 0.55, 0.60)

# ─── Workflow Steps ──────────────────────────────────────────
const STEPS = [
	{"icon": "🗺️", "label": "Levels",   "tip": "Paint tile-based levels"},
	{"icon": "👾", "label": "Actors",   "tip": "Define game characters"},
	{"icon": "🔊", "label": "Sounds",   "tip": "Create retro sound effects"},
	{"icon": "🎨", "label": "Shaders",  "tip": "Add visual effects (CRT, Glow, etc.)"},
	{"icon": "⚙️", "label": "Settings", "tip": "Configure game physics & rules"},
	{"icon": "🚀", "label": "Build",    "tip": "Build & preview your game"},
]

# ─── Sub-editors ─────────────────────────────────────────────
var _editors: Array = []        # [level, actor, sound, settings, builder]
var _sidebar_btns: Array = []
var _active_step: int = 0       # default: Levels (hero view)
var _content_area: PanelContainer = null
var _sidebar: VBoxContainer = null
var _builder: RefCounted = null  # BuilderBackend instance
var _tile_lib = null             # TileLibrary instance

# ─── Project Data ────────────────────────────────────────────
var _project_path: String = ""
var _dirty: bool = false

# Default auto-save location for the AGCK project
const AUTO_SAVE_PATH = "res://agck_project.agck"

# ─── Build-on-save debounce ──────────────────────────────────
const BUILD_DEBOUNCE_SEC = 3.0   # seconds of inactivity before auto-rebuild
var _build_timer: Timer = null
var _auto_build_enabled: bool = true


# ─── Plugin Identity ─────────────────────────────────────────

func get_plugin_name() -> String:
	return "AGCK"

func get_toolbar_icon() -> String:
	return "🕹️"

func get_toolbar_color() -> Color:
	return Color(0.85, 0.55, 0.2)

func get_toolbar_tooltip() -> String:
	return "Arcade Game Construction Kit"


# ─── LabelSettings helper ───────────────────────────────────

func _ls(size: int, color: Color) -> LabelSettings:
	var s = LabelSettings.new()
	s.font_size = size
	s.font_color = color
	return s


# ─── Build UI ────────────────────────────────────────────────

func _build_ui() -> void:
	# _view is an HSplitContainer from the base class.
	# We use it as: [slim sidebar | large content area]

	# ── Sidebar ──
	var sidebar_wrap = PanelContainer.new()
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = SIDEBAR_BG
	sidebar_wrap.add_theme_stylebox_override("panel", sb_style)
	sidebar_wrap.custom_minimum_size.x = 72
	sidebar_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_sidebar = VBoxContainer.new()
	_sidebar.add_theme_constant_override("separation", 2)
	_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# AGCK logo / title
	var logo = Label.new()
	logo.text = "🕹️"
	logo.label_settings = _ls(22, ACCENT)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sidebar.add_child(logo)
	var brand = Label.new()
	brand.text = "AGCK"
	brand.label_settings = _ls(10, ACCENT)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sidebar.add_child(brand)

	_sidebar.add_child(HSeparator.new())

	# Workflow step buttons
	for i in range(STEPS.size()):
		var btn = _make_sidebar_btn(i)
		_sidebar.add_child(btn)
		_sidebar_btns.append(btn)

	# Spacer pushes version to bottom
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar.add_child(spacer)

	# Version label at bottom
	var ver = Label.new()
	ver.text = "v2.0"
	ver.label_settings = _ls(9, DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sidebar.add_child(ver)

	sidebar_wrap.add_child(_sidebar)
	_view.add_child(sidebar_wrap)

	# ── Content Area ──
	_content_area = PanelContainer.new()
	var ca_style = StyleBoxFlat.new()
	ca_style.bg_color = CONTENT_BG
	_content_area.add_theme_stylebox_override("panel", ca_style)
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.add_child(_content_area)

	# ── Load Sub-Editors ──
	var scripts = [
		"agck_level_editor.gd",
		"agck_actor_editor.gd",
		"agck_sound_editor.gd",
		"agck_shader_editor.gd",
		"agck_game_settings.gd",
		"agck_game_builder.gd",
	]
	for script_name in scripts:
		var scr = load(AGCK_DIR + script_name)
		if scr:
			var editor = scr.new()
			editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
			editor.visible = false
			_content_area.add_child(editor)
			_editors.append(editor)
		else:
			push_error("AGCK: Failed to load " + script_name)
			_editors.append(null)

	# Connect signals
	# Editor indices: 0=Levels, 1=Actors, 2=Sounds, 3=Shaders, 4=Settings, 5=Build
	if _editors.size() > 1 and _editors[1] and _editors[1].has_signal("actor_changed"):
		_editors[1].actor_changed.connect(_on_actor_changed)
	if _editors.size() > 1 and _editors[1] and _editors[1].has_signal("switch_tab_requested"):
		_editors[1].switch_tab_requested.connect(_switch_to)
	if _editors.size() > 0 and _editors[0] and _editors[0].has_signal("level_changed"):
		_editors[0].level_changed.connect(func(_id): _dirty = true; _restart_build_debounce(); _sync_start_level_count())
	if _editors.size() > 3 and _editors[3] and _editors[3].has_signal("data_changed"):
		_editors[3].data_changed.connect(_on_data_changed)
	if _editors.size() > 4 and _editors[4] and _editors[4].has_signal("settings_changed"):
		_editors[4].settings_changed.connect(_on_data_changed)
	if _editors.size() > 5 and _editors[5] and _editors[5].has_signal("build_requested"):
		_editors[5].build_requested.connect(_on_build_requested)
	if _editors.size() > 5 and _editors[5] and _editors[5].has_signal("preview_requested"):
		_editors[5].preview_requested.connect(_on_preview_requested)
	if _editors.size() > 5 and _editors[5] and _editors[5].has_signal("template_requested"):
		_editors[5].template_requested.connect(_on_template_requested)
	if _editors.size() > 5 and _editors[5] and _editors[5].has_signal("save_template_requested"):
		_editors[5].save_template_requested.connect(_on_save_template_requested)
	if _editors.size() > 5 and _editors[5] and _editors[5].has_signal("load_template_requested"):
		_editors[5].load_template_requested.connect(_on_load_template_requested)
	if _editors.size() > 5 and _editors[5] and _editors[5].has_signal("web_publish_requested"):
		_editors[5].web_publish_requested.connect(_on_web_publish_requested)

	_sync_actor_names()
	_sync_start_level_count()

	# Initialize tile library and wire to editors
	_tile_lib = TileLibrary.new()
	_tile_lib.initialize()
	if _editors.size() > 0 and _editors[0]:
		_editors[0].tile_library = _tile_lib
		if _editors[0].has_method("refresh_all"):
			_editors[0].refresh_all()
	if _editors.size() > 1 and _editors[1]:
		_editors[1].tile_library = _tile_lib
		if _editors.size() > 2 and _editors[2]:
			_editors[1].sound_editor = _editors[2]
		if _editors[1].has_method("refresh_all"):
			_editors[1].refresh_all()

	# Build-on-save debounce timer (attached to _view so it ticks in editor)
	_build_timer = Timer.new()
	_build_timer.one_shot = true
	_build_timer.wait_time = BUILD_DEBOUNCE_SEC
	_build_timer.timeout.connect(_on_build_debounce_timeout)
	_view.add_child(_build_timer)

	# Show the hero view (Levels)
	_switch_to(0)

	# ─── Keyboard Shortcut Relay (Task 7) ────────────────────
	# A tiny invisible Control that captures _shortcut_input while
	# the AGCK panel is visible, so shortcuts work editor-wide.
	var _shortcut_relay := Control.new()
	_shortcut_relay.name = "ShortcutRelay"
	_shortcut_relay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shortcut_relay.set_script(_build_shortcut_relay_script())
	_shortcut_relay.set_meta("plugin", self)
	_view.add_child(_shortcut_relay)


func _build_shortcut_relay_script() -> GDScript:
	var code := """@tool
extends Control

func _shortcut_input(event: InputEvent) -> void:
	if not visible or not is_visible_in_tree():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var plug = get_meta("plugin")
	if plug == null:
		return
	var key: InputEventKey = event
	var ctrl := key.ctrl_pressed or key.meta_pressed
	match key.keycode:
		KEY_F5:
			plug._on_preview_requested()
			get_viewport().set_input_as_handled()
		KEY_B:
			if ctrl:
				plug._on_build_requested()
				get_viewport().set_input_as_handled()
		KEY_S:
			if ctrl:
				plug._auto_save()
				plug._forward_build_log("[color=#8f8]💾 Project saved (Ctrl+S)[/color]")
				get_viewport().set_input_as_handled()
		KEY_1:
			if not ctrl:
				plug._switch_to(0)
				get_viewport().set_input_as_handled()
		KEY_2:
			if not ctrl:
				plug._switch_to(1)
				get_viewport().set_input_as_handled()
		KEY_3:
			if not ctrl:
				plug._switch_to(2)
				get_viewport().set_input_as_handled()
		KEY_4:
			if not ctrl:
				plug._switch_to(3)
				get_viewport().set_input_as_handled()
		KEY_5:
			if not ctrl:
				plug._switch_to(4)
				get_viewport().set_input_as_handled()
		KEY_6:
			if not ctrl:
				plug._switch_to(5)
				get_viewport().set_input_as_handled()
"""
	var scr := GDScript.new()
	scr.source_code = code
	scr.reload()
	return scr


func _make_sidebar_btn(idx: int) -> Button:
	var step = STEPS[idx]
	var btn = Button.new()
	# Include keyboard shortcut hint in the label
	var shortcut_hint = str(idx + 1)
	btn.text = step["icon"] + "\n" + step["label"]
	btn.tooltip_text = step["tip"] + "  [" + shortcut_hint + "]"
	btn.toggle_mode = true
	btn.button_pressed = (idx == 0)
	btn.custom_minimum_size = Vector2(68, 54)
	btn.add_theme_font_size_override("font_size", 11)

	# Normal style
	var ns = StyleBoxFlat.new()
	ns.bg_color = Color.TRANSPARENT
	ns.set_corner_radius_all(6)
	ns.content_margin_left = 4
	ns.content_margin_right = 4
	ns.content_margin_top = 4
	ns.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", ns)

	# Hover
	var hs = ns.duplicate()
	hs.bg_color = SIDEBAR_HOVER
	btn.add_theme_stylebox_override("hover", hs)

	# Pressed / active
	var ps = ns.duplicate()
	ps.bg_color = SIDEBAR_SEL
	ps.border_width_left = 3
	ps.border_color = ACCENT
	btn.add_theme_stylebox_override("pressed", ps)

	# Focus (same as pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Colors — always white for readability
	btn.add_theme_color_override("font_color", DIM)
	btn.add_theme_color_override("font_pressed_color", WHITE)
	btn.add_theme_color_override("font_hover_color", WHITE)
	btn.add_theme_color_override("font_hover_pressed_color", WHITE)

	btn.pressed.connect(_on_sidebar_btn.bind(idx))
	return btn


func _on_sidebar_btn(idx: int) -> void:
	_switch_to(idx)


func _switch_to(idx: int) -> void:
	_active_step = idx
	# Hide all editors, show selected
	for i in range(_editors.size()):
		if _editors[i]:
			_editors[i].visible = (i == idx)
	# Update sidebar button states
	for i in range(_sidebar_btns.size()):
		_sidebar_btns[i].button_pressed = (i == idx)


# ─── Lifecycle ───────────────────────────────────────────────

func _on_activated() -> void:
	print("AGCK: Plugin activated")
	# Auto-load project if one exists and nothing is loaded yet
	if _project_path.is_empty():
		var load_path := AUTO_SAVE_PATH
		if FileAccess.file_exists(load_path):
			print("AGCK: Auto-loading project from ", load_path)
			load_project(load_path)

func _on_deactivated() -> void:
	print("AGCK: Plugin deactivated")
	# Auto-save if dirty
	_auto_save()

func _on_cleanup() -> void:
	_editors.clear()
	_sidebar_btns.clear()
	_content_area = null
	_sidebar = null


# ─── Data Flow ───────────────────────────────────────────────

func _on_data_changed(_key = null, _value = null) -> void:
	_dirty = true
	# Propagate pixel-art size changes to the shared tile library so the actor
	# editor / level editor pick up the new render targets immediately.
	if _tile_lib and typeof(_key) == TYPE_STRING:
		match _key:
			"tile_size":
				_tile_lib.tile_render_size = int(_value)
			"actor_frame_size":
				_tile_lib.actor_frame_size = int(_value)
		# Refresh actor editor so its canvas / blank-frames pick up the new size.
		if _editors.size() > 1 and _editors[1] and _editors[1].has_method("refresh_all"):
			_editors[1].refresh_all()
	_restart_build_debounce()

func _on_actor_changed(_actor_id = null) -> void:
	_dirty = true
	_sync_actor_names()
	_restart_build_debounce()

## Restart (or start) the build debounce timer.
## Each change resets the countdown so rapid edits don't trigger multiple builds.
func _restart_build_debounce() -> void:
	if not _auto_build_enabled:
		return
	if _build_timer and is_instance_valid(_build_timer):
		_build_timer.stop()
		_build_timer.start(BUILD_DEBOUNCE_SEC)

## Called when the debounce timer fires — auto-save and auto-rebuild.
func _on_build_debounce_timeout() -> void:
	if not _dirty:
		return
	_auto_save()
	_forward_build_log("[color=#aaa]⏱ Auto-rebuild triggered (data changed " + str(BUILD_DEBOUNCE_SEC) + "s ago)…[/color]")
	var game_data: Dictionary = _collect_all_data()
	_run_build_no_load(game_data)

## Update the builder's Start Level dropdown to match the current level count.
func _sync_start_level_count() -> void:
	if _editors.size() < 6:
		return
	var level_ed = _editors[0]
	var builder  = _editors[5]
	if level_ed and builder and builder.has_method("update_level_count"):
		var levels_data = level_ed.get_data()
		builder.update_level_count(levels_data.size())

func _sync_actor_names() -> void:
	if _editors.size() < 2:
		return
	var actor_ed = _editors[1]
	var level_ed = _editors[0]
	if actor_ed and level_ed:
		var actors_data = actor_ed.get_data()
		var names: Array = []
		var types: Array = []
		for a in actors_data:
			names.append(a.get("name", "Actor"))
			types.append(a.get("type", "Drone"))
		if level_ed.has_method("set_actor_names"):
			level_ed.set_actor_names(names, types)

func _on_build_requested() -> void:
	# Auto-save before building
	_auto_save()
	var game_data: Dictionary = _collect_all_data()
	_begin_build(game_data)

func _on_preview_requested() -> void:
	# Auto-save before previewing
	_auto_save()
	var game_data: Dictionary = _collect_all_data()
	_begin_build_and_play(game_data)

func _on_web_publish_requested(web_cfg: Dictionary) -> void:
	_auto_save()
	_forward_build_log("[color=#5577cc]🌐 Publishing to Web (Flash-successor pipeline)…[/color]")

	# Merge game settings into web config (canvas size, title)
	var settings := {}
	if _editors.size() > 4 and _editors[4]:
		settings = _editors[4].get_data()
	if not web_cfg.has("game_title") or web_cfg["game_title"] == "My Game":
		web_cfg["game_title"] = settings.get("game_title", "My Game")
	if not web_cfg.has("canvas_width") or web_cfg["canvas_width"] == 1280:
		web_cfg["canvas_width"] = settings.get("screen_width", 1280)
	if not web_cfg.has("canvas_height") or web_cfg["canvas_height"] == 720:
		web_cfg["canvas_height"] = settings.get("screen_height", 720)

	# Load the web export backend
	var WebExport = load(AGCK_DIR + "agck_web_export.gd")
	if not WebExport:
		_forward_build_log("[color=#ff5555]✗ Cannot load agck_web_export.gd[/color]")
		return

	# Build the WebConfig
	var config = WebExport.WebConfig.new()
	config.game_title       = web_cfg.get("game_title", "My Game")
	config.bg_color         = web_cfg.get("bg_color", "#0d0d14")
	config.loading_style    = web_cfg.get("loading_style", "Bar")
	config.loading_color    = web_cfg.get("loading_color", "#ffd159")
	config.quality          = web_cfg.get("quality", "High")
	config.scale_mode       = web_cfg.get("scale_mode", "Fit")
	config.fullscreen_button = web_cfg.get("fullscreen_button", true)
	config.right_click_menu = web_cfg.get("right_click_menu", true)
	config.show_watermark   = web_cfg.get("show_watermark", true)
	config.canvas_width     = web_cfg.get("canvas_width", 1280)
	config.canvas_height    = web_cfg.get("canvas_height", 720)
	config.embed_ready      = web_cfg.get("embed_ready", true)
	config.splash_enabled   = web_cfg.get("splash_enabled", true)
	config.description      = web_cfg.get("description", "")

	# Output directory
	var output_dir := "res://build/web/"

	# Log callback
	var log_fn := Callable(self, "_forward_build_log")

	# Run the publish pipeline (no Godot export — generates wrapper + portal + embed)
	var result = WebExport.publish_to_web(config, output_dir, false, log_fn)

	# Trigger filesystem scan
	if Engine.is_editor_hint():
		var efs = EditorInterface.get_resource_filesystem()
		if efs:
			efs.scan()

	_forward_build_log("[color=#8f8]🌐 Web publish complete! Files are in " + output_dir + "[/color]")


# ─── Project Templates (Task 5) ─────────────────────────────

func _on_template_requested(template_name: String) -> void:
	_forward_build_log("[color=#ffcc55]📋 Applying template: " + template_name + "[/color]")
	# Clear out any levels left over from a prior template — without this the
	# new template's level[0] would replace slot 0 but leave slots 1+ from the
	# previous template intact, so e.g. finishing a Platformer level 1 would
	# Sequential-teleport the player into Geometry Dash's level 2.
	if _editors.size() > 0 and _editors[0] and "levels" in _editors[0]:
		_editors[0].levels.clear()
	match template_name:
		"Platformer":
			_apply_platformer_template()
		"Space Shooter":
			_apply_space_shooter_template()
		"Maze Game":
			_apply_maze_template()
		"Top-Down RPG":
			_apply_topdown_rpg_template()
		"Side Shmup":
			_apply_side_shmup_template()
		"Match-3":
			_apply_match3_template()
		"Asteroids":
			_apply_asteroids_template()
		"Endless Runner":
			_apply_endless_runner_template()
		"Geometry Dash":
			_apply_geometry_dash_template()
	_dirty = true
	_sync_actor_names()
	_sync_start_level_count()
	# Refresh editors
	if _editors.size() > 0 and _editors[0] and _editors[0].has_method("refresh_all"):
		_editors[0].refresh_all()
	if _editors.size() > 0 and _editors[0]:
		_editors[0]._refresh_level_list()
		_editors[0]._refresh_ui()
	if _editors.size() > 1 and _editors[1] and _editors[1].has_method("refresh_all"):
		_editors[1].refresh_all()
	_switch_to(0)  # Jump to Levels view
	_forward_build_log("[color=#8f8]  ✓ Template applied! Edit to your liking, then press PLAY PREVIEW.[/color]")


# ─── User template save / load ───────────────────────────────────────────────

const AGCK_TEMPLATES_DIR := "user://agck_templates"

func _on_save_template_requested() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Save Template"
	dlg.dialog_text = ""
	# Build a compact VBox with a label + LineEdit for the template name.
	var vb := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Template name:"
	vb.add_child(lbl)
	var le := LineEdit.new()
	le.placeholder_text = "My Game Template"
	le.custom_minimum_size = Vector2(300, 0)
	vb.add_child(le)
	dlg.add_child(vb)
	# Position the VBox inside the dialog after it is ready.
	dlg.get_ok_button().text = "Save"
	add_child(dlg)
	dlg.popup_centered()
	# Focus the LineEdit once visible.
	await dlg.visibility_changed
	le.grab_focus()
	dlg.confirmed.connect(func():
		var tname: String = le.text.strip_edges()
		if tname.is_empty():
			tname = "Untitled"
		_save_user_template(tname)
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)

func _save_user_template(template_name: String) -> void:
	var game_data := _collect_all_data()
	game_data["_template_name"] = template_name
	game_data["_saved_at"] = Time.get_datetime_string_from_system()
	DirAccess.make_dir_recursive_absolute(AGCK_TEMPLATES_DIR)
	# Sanitise name → safe filename.
	var safe := template_name.strip_edges()
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe = safe.replace(ch, "_")
	if safe.is_empty():
		safe = "template"
	var path := AGCK_TEMPLATES_DIR + "/" + safe + ".agckt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_forward_build_log("[color=#f55]✗ Could not write template: " + path + "[/color]")
		return
	f.store_string(JSON.stringify(game_data, "\t"))
	f.close()
	_forward_build_log("[color=#8f8]  💾 Template saved: " + safe + ".agckt[/color]")

func _on_load_template_requested() -> void:
	# Gather *.agckt files in the templates dir.
	var dir := DirAccess.open(AGCK_TEMPLATES_DIR)
	var files: Array[String] = []
	if dir != null:
		dir.list_dir_begin()
		while true:
			var f := dir.get_next()
			if f.is_empty():
				break
			if f.ends_with(".agckt"):
				files.append(f)
		dir.list_dir_end()
	if files.is_empty():
		var info := AcceptDialog.new()
		info.title = "No saved templates"
		info.dialog_text = "You haven't saved any templates yet.\nUse '💾 Save as Template...' to create one."
		add_child(info)
		info.popup_centered()
		info.confirmed.connect(info.queue_free)
		return
	# Show a popup list.
	var dlg := AcceptDialog.new()
	dlg.title = "Load Template"
	dlg.dialog_text = ""
	var vb := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Choose a template:"
	vb.add_child(lbl)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(320, 0)
	files.sort()
	for fn in files:
		opt.add_item(fn.trim_suffix(".agckt"))
	vb.add_child(opt)
	dlg.add_child(vb)
	dlg.get_ok_button().text = "Load"
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(func():
		var chosen: String = files[opt.selected]
		_load_user_template(AGCK_TEMPLATES_DIR + "/" + chosen)
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)

func _load_user_template(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_forward_build_log("[color=#f55]✗ Cannot open template: " + path + "[/color]")
		return
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		_forward_build_log("[color=#f55]✗ Template file is corrupt: " + path + "[/color]")
		return
	var data: Dictionary = parsed
	var tname: String = data.get("_template_name", path.get_file().trim_suffix(".agckt"))
	_forward_build_log("[color=#ffcc55]📋 Loading user template: " + tname + "[/color]")
	# Clear current levels.
	if _editors.size() > 0 and _editors[0] and "levels" in _editors[0]:
		_editors[0].levels.clear()
	# Restore each editor section.
	if data.has("settings") and _editors.size() > 4 and _editors[4]:
		_editors[4].set_data(data["settings"])
	if data.has("actors") and _editors.size() > 1 and _editors[1]:
		_editors[1].set_data(data["actors"])
	if data.has("sounds") and _editors.size() > 2 and _editors[2]:
		_editors[2].set_data(data["sounds"])
	if data.has("levels") and _editors.size() > 0 and _editors[0]:
		_editors[0].set_data(data["levels"])
	if data.has("shaders") and _editors.size() > 3 and _editors[3]:
		_editors[3].set_data(data["shaders"])
	_dirty = true
	_sync_actor_names()
	_sync_start_level_count()
	if _editors.size() > 0 and _editors[0] and _editors[0].has_method("refresh_all"):
		_editors[0].refresh_all()
	if _editors.size() > 0 and _editors[0]:
		_editors[0]._refresh_level_list()
		_editors[0]._refresh_ui()
	if _editors.size() > 1 and _editors[1] and _editors[1].has_method("refresh_all"):
		_editors[1].refresh_all()
	_switch_to(0)
	_forward_build_log("[color=#8f8]  ✓ Template '" + tname + "' loaded![/color]")


func _apply_platformer_template() -> void:
	# Settings
	if _editors.size() > 4 and _editors[4]:
		_editors[4].set_data({
			"game_title": "Platformer Adventure",
			"gravity": 980, "friction": 50, "elasticity": 30,
			"screen_width": 640, "screen_height": 384,
			"lives": 3, "show_score": true, "show_lives": true,
			"start_level": 1, "level_order": "Sequential",
		})
	# Actors: Player, Enemy, Coin, Powerup
	if _editors.size() > 1 and _editors[1]:
		_editors[1].set_data([
			{"name": "Hero", "type": "Player", "max_speed": 200, "gravity_scale": 1.0, "max_hp": 100, "damage": 0, "score_value": 0, "collision_mode": "Slide", "death_mode": "Respawn", "rebirth": 2.0},
			{"name": "Slime", "type": "Drone", "max_speed": 60, "gravity_scale": 1.0, "max_hp": 50, "damage": 20, "score_value": 100, "ai_behavior": "Patrol", "ai_patrol_speed": 60, "collision_mode": "Bounce", "death_mode": "Destroy"},
			{"name": "Coin", "type": "Computer", "max_speed": 0, "gravity_scale": 0, "max_hp": 1, "damage": 0, "score_value": 50, "collision_mode": "None", "death_mode": "Destroy"},
			{"name": "Mushroom", "type": "Powerup", "max_speed": 60, "gravity_scale": 1.0, "max_hp": 1, "damage": 0, "score_value": 1000, "ai_patrol_speed": 60, "collision_mode": "Bounce", "death_mode": "Destroy"},
		])
	# Level 1: simple platformer layout
	if _editors.size() > 0 and _editors[0]:
		var GRID_W = 20
		var GRID_H = 12
		var lvl = _editors[0]._make_empty_level(1)
		lvl["name"] = "World 1-1"
		var grid = lvl["grid"]
		# Floor
		for x in range(GRID_W):
			grid[GRID_H - 1][x] = {"block_type": 1, "tile_index": 0}
		# Platforms
		for x in range(5, 9):
			grid[8][x] = {"block_type": 1, "tile_index": 0}
		for x in range(12, 17):
			grid[6][x] = {"block_type": 1, "tile_index": 0}
		for x in range(3, 6):
			grid[4][x] = {"block_type": 1, "tile_index": 0}
		# Deadly pit
		grid[GRID_H - 1][9] = {"block_type": 3, "tile_index": 0}
		grid[GRID_H - 1][10] = {"block_type": 3, "tile_index": 0}
		# Question Block (tile_index 15 in BLOCK_BARRIER) — bump from below
		# to spawn the Mushroom actor (via per-cell `spawn_actor` field).
		grid[7][14] = {"block_type": 1, "tile_index": 15, "spawn_actor": "Mushroom"}
		# Teleport (exit)
		grid[5][GRID_W - 2] = {"block_type": 5, "tile_index": 0}
		# Actors
		lvl["actors"] = [
			{"actor_id": 0, "x": 2, "y": GRID_H - 2, "path": []},  # Player
			{"actor_id": 1, "x": 7, "y": 7, "path": []},           # Slime
			{"actor_id": 1, "x": 14, "y": 5, "path": []},          # Slime
			{"actor_id": 2, "x": 6, "y": 7, "path": []},           # Coin
			{"actor_id": 2, "x": 13, "y": 5, "path": []},          # Coin
			{"actor_id": 2, "x": 15, "y": 5, "path": []},          # Coin
			{"actor_id": 3, "x": 4, "y": 3, "path": []},           # Mushroom (Powerup)
		]
		_editors[0].levels.append(lvl)


func _apply_space_shooter_template() -> void:
	if _editors.size() > 4 and _editors[4]:
		_editors[4].set_data({
			"game_title": "Space Blaster",
			"gravity": 0, "friction": 0, "elasticity": 0,
			"screen_width": 480, "screen_height": 640,
			"lives": 3, "show_score": true, "show_lives": true,
			"start_level": 1, "level_order": "Sequential",
		})
	if _editors.size() > 1 and _editors[1]:
		_editors[1].set_data([
			{"name": "Ship", "type": "Player", "max_speed": 250, "gravity_scale": 0, "max_hp": 100, "damage": 25, "score_value": 0, "collision_mode": "Slide", "death_mode": "Respawn", "rebirth": 2.0},
			{"name": "Alien", "type": "Drone", "max_speed": 80, "gravity_scale": 0, "max_hp": 30, "damage": 20, "score_value": 150, "ai_behavior": "Patrol", "ai_patrol_speed": 80, "collision_mode": "Bounce", "death_mode": "Destroy"},
			{"name": "Bullet", "type": "Missile", "max_speed": 400, "gravity_scale": 0, "max_hp": 1, "damage": 25, "score_value": 0, "collision_mode": "None", "death_mode": "Destroy"},
		])
	if _editors.size() > 0 and _editors[0]:
		var GRID_W = 20; var GRID_H = 12
		var lvl = _editors[0]._make_empty_level(1)
		lvl["name"] = "Sector 1"
		var grid = lvl["grid"]
		# Side walls
		for y in range(GRID_H):
			grid[y][0] = {"block_type": 1, "tile_index": 0}
			grid[y][GRID_W - 1] = {"block_type": 1, "tile_index": 0}
		# Teleport at top
		grid[0][GRID_W / 2] = {"block_type": 5, "tile_index": 0}
		# Actors
		lvl["actors"] = [
			{"actor_id": 0, "x": GRID_W / 2, "y": GRID_H - 2, "path": []},  # Ship
			{"actor_id": 1, "x": 5, "y": 2, "path": []},
			{"actor_id": 1, "x": 10, "y": 3, "path": []},
			{"actor_id": 1, "x": 15, "y": 2, "path": []},
		]
		_editors[0].levels.append(lvl)


func _apply_maze_template() -> void:
	if _editors.size() > 4 and _editors[4]:
		_editors[4].set_data({
			"game_title": "Maze Runner",
			"gravity": 0, "friction": 80, "elasticity": 0,
			"screen_width": 640, "screen_height": 384,
			"lives": 1, "show_score": true, "show_lives": false,
			"start_level": 1, "level_order": "Sequential",
		})
	if _editors.size() > 1 and _editors[1]:
		_editors[1].set_data([
			# Maze is a top-down genre — use the TopHero / TopGoblin sprite variants
			# instead of the platformer-style side-view art.
			{"name": "Explorer", "type": "TopHero", "max_speed": 150, "gravity_scale": 0, "max_hp": 100, "damage": 0, "score_value": 0, "collision_mode": "Slide", "death_mode": "GameOver", "rebirth": 0},
			{"name": "Ghost", "type": "TopGoblin", "max_speed": 80, "gravity_scale": 0, "max_hp": 999, "damage": 100, "score_value": 0, "ai_behavior": "Chase", "ai_patrol_speed": 80, "collision_mode": "Bounce", "death_mode": "Destroy"},
			{"name": "Gem", "type": "Computer", "max_speed": 0, "gravity_scale": 0, "max_hp": 1, "damage": 0, "score_value": 100, "collision_mode": "None", "death_mode": "Destroy"},
		])
	if _editors.size() > 0 and _editors[0]:
		var GRID_W = 20; var GRID_H = 12
		var lvl = _editors[0]._make_empty_level(1)
		lvl["name"] = "The Labyrinth"
		var grid = lvl["grid"]
		# Border walls
		for x in range(GRID_W):
			grid[0][x] = {"block_type": 1, "tile_index": 0}
			grid[GRID_H - 1][x] = {"block_type": 1, "tile_index": 0}
		for y in range(GRID_H):
			grid[y][0] = {"block_type": 1, "tile_index": 0}
			grid[y][GRID_W - 1] = {"block_type": 1, "tile_index": 0}
		# Internal maze walls
		for y in range(2, 10):
			grid[y][4] = {"block_type": 1, "tile_index": 0}
		for y in range(1, 8):
			grid[y][8] = {"block_type": 1, "tile_index": 0}
		for y in range(4, 11):
			grid[y][12] = {"block_type": 1, "tile_index": 0}
		for y in range(1, 6):
			grid[y][16] = {"block_type": 1, "tile_index": 0}
		# Gaps in walls
		grid[5][4] = {"block_type": 0, "tile_index": 0}
		grid[3][8] = {"block_type": 0, "tile_index": 0}
		grid[8][12] = {"block_type": 0, "tile_index": 0}
		grid[2][16] = {"block_type": 0, "tile_index": 0}
		# Teleport (exit) in far corner
		grid[1][GRID_W - 2] = {"block_type": 5, "tile_index": 0}
		# Actors
		lvl["actors"] = [
			{"actor_id": 0, "x": 1, "y": GRID_H - 2, "path": []},
			{"actor_id": 1, "x": 6, "y": 3, "path": []},
			{"actor_id": 1, "x": 14, "y": 8, "path": []},
			{"actor_id": 2, "x": 2, "y": 1, "path": []},
			{"actor_id": 2, "x": 10, "y": 5, "path": []},
			{"actor_id": 2, "x": 17, "y": 9, "path": []},
		]
		_editors[0].levels.append(lvl)


# ─── New genre templates (added Apr 2026) ───────────────────

func _apply_topdown_rpg_template() -> void:
	# ── Top-Down RPG (3-level dungeon-crawl) ───────────────────────────
	# A Sequential chain of three bird's-eye-view levels that escalates
	# from a friendly village → a hostile forest → a boss chamber.  Each
	# level uses goal teleport (block_type 5) on a north wall door to
	# chain to the next, so the player feels like they're "descending"
	# into the realm.
	#
	# Why TopHero and friends?  These are the bird's-eye sprite variants
	# (gravity_scale 0, no jump physics) — using them keeps this distinct
	# from the side-scrolling Platformer template.  Actor roles still
	# follow normal AGCK semantics: Player-style controls (TopHero),
	# Drone-style AI (TopGoblin/Bat/Boss), Computer-static (TopChest).
	if _editors.size() > 4 and _editors[4]:
		_editors[4].set_data({
			"game_title": "Quest of the Realm",
			# Friction keeps the hero from sliding after WASD release —
			# critical for tile-grid feel.  Elasticity 0 = no bouncing.
			"gravity": 0, "friction": 80, "elasticity": 0,
			"screen_width": 640, "screen_height": 384,
			"background_color": "#2a2030",
			"lives": 3, "show_score": true, "show_lives": true,
			"start_level": 1, "level_order": "Sequential",
			"wrap_screen": false, "camera_zoom": 1.0,
			"keyboard_enabled": true, "joystick_enabled": true,
			"mouse_enabled": true, "touch_enabled": true,
			"deadly_damage": 999,
		})
	if _editors.size() > 1 and _editors[1]:
		_editors[1].set_data([
			# Hero: melee-range damage (25) lets a fresh hero one-shot
			# normal goblins in 2 hits, takes ~3 hits before respawn.
			{"name": "Hero", "type": "TopHero", "max_speed": 130, "gravity_scale": 0,
				"max_hp": 100, "damage": 25, "score_value": 0,
				"collision_mode": "Slide", "death_mode": "Respawn", "rebirth": 1.5},
			# Goblin: standard chaser, 70 speed slower than hero so the
			# player can kite — encourages combat positioning not flight.
			{"name": "Goblin", "type": "TopGoblin", "max_speed": 70, "gravity_scale": 0,
				"max_hp": 40, "damage": 15, "score_value": 75,
				"ai_behavior": "Chase", "ai_patrol_speed": 70,
				"collision_mode": "Bounce", "death_mode": "Destroy"},
			# Bat: faster but glassier — patrol AI for unpredictable
			# ambush vectors in the forest level.
			{"name": "Bat", "type": "Bat", "max_speed": 110, "gravity_scale": 0,
				"max_hp": 20, "damage": 10, "score_value": 50,
				"ai_behavior": "Patrol", "ai_patrol_speed": 110,
				"collision_mode": "Bounce", "death_mode": "Destroy"},
			# Boss: stationary-ish but lethal, ends the chain.
			{"name": "Boss", "type": "Boss", "max_speed": 50, "gravity_scale": 0,
				"max_hp": 250, "damage": 35, "score_value": 1000,
				"ai_behavior": "Chase", "ai_patrol_speed": 50,
				"collision_mode": "Bounce", "death_mode": "Destroy"},
			{"name": "NPC", "type": "NPC", "max_speed": 0, "gravity_scale": 0,
				"max_hp": 9999, "damage": 0, "score_value": 0,
				"collision_mode": "None", "death_mode": "Destroy"},
			{"name": "Treasure", "type": "TopChest", "max_speed": 0, "gravity_scale": 0,
				"max_hp": 1, "damage": 0, "score_value": 250,
				"collision_mode": "None", "death_mode": "Destroy"},
			# Health pickup — Powerup heals on contact (engine-default).
			{"name": "Heart", "type": "Powerup", "max_speed": 0, "gravity_scale": 0,
				"max_hp": 1, "damage": 0, "score_value": 25,
				"collision_mode": "None", "death_mode": "Destroy"},
		])
	if _editors.size() > 0 and _editors[0]:
		const GRID_W := 20
		const GRID_H := 12
		# Each chamber is a 20x12 walled room.  "walls" are obstacle
		# rectangles carved INTO the empty floor (block_type 1).
		# "door" is the (x,y) of the north exit teleport.
		var rooms := [
			{
				"name": "Village Outskirts",
				"spawn": Vector2i(2, GRID_H - 2),
				"door": Vector2i(GRID_W / 2, 0),
				# A central pond — pure decoration / kiting cover.
				"walls": [
					{"x0": 8, "y0": 4, "x1": 11, "y1": 6},
				],
				"goblins": [Vector2i(14, 2), Vector2i(16, 8)],
				"bats": [],
				"npcs": [Vector2i(4, 2), Vector2i(3, 5)],
				"chests": [Vector2i(17, 9), Vector2i(5, 8)],
				"hearts": [Vector2i(10, 9)],
				"boss": null,
			},
			{
				"name": "Whispering Forest",
				"spawn": Vector2i(GRID_W / 2, GRID_H - 2),
				"door": Vector2i(GRID_W - 2, 0),
				# Two tree-clusters create choke points for bat ambushes.
				"walls": [
					{"x0": 4, "y0": 3, "x1": 7, "y1": 5},
					{"x0": 12, "y0": 6, "x1": 15, "y1": 8},
					{"x0": 9, "y0": 2, "x1": 10, "y1": 2},
				],
				"goblins": [Vector2i(3, 9), Vector2i(17, 4)],
				"bats": [Vector2i(8, 6), Vector2i(14, 3), Vector2i(11, 9)],
				"npcs": [],
				"chests": [Vector2i(2, 2), Vector2i(18, 9)],
				"hearts": [Vector2i(8, 4), Vector2i(15, 2)],
				"boss": null,
			},
			{
				"name": "Throne of the Realm",
				"spawn": Vector2i(GRID_W / 2, GRID_H - 2),
				"door": null, # Final level — no further teleport.
				# Pillars flanking the boss — visual symmetry + cover.
				"walls": [
					{"x0": 5, "y0": 3, "x1": 6, "y1": 4},
					{"x0": 13, "y0": 3, "x1": 14, "y1": 4},
					{"x0": 5, "y0": 7, "x1": 6, "y1": 8},
					{"x0": 13, "y0": 7, "x1": 14, "y1": 8},
				],
				"goblins": [Vector2i(2, 2), Vector2i(17, 2), Vector2i(2, 9), Vector2i(17, 9)],
				"bats": [Vector2i(8, 2), Vector2i(11, 2)],
				"npcs": [],
				"chests": [Vector2i(9, 9), Vector2i(10, 9)],
				"hearts": [Vector2i(2, 5), Vector2i(17, 5)],
				"boss": Vector2i(GRID_W / 2, 3),
			},
		]
		# Actor IDs match the order set above on _editors[1]:
		# 0=Hero, 1=Goblin, 2=Bat, 3=Boss, 4=NPC, 5=Treasure, 6=Heart
		for i in range(rooms.size()):
			var room = rooms[i]
			var lvl = _editors[0]._make_empty_level(i + 1, GRID_W, GRID_H)
			lvl["name"] = room["name"]
			# Death = restart current level (per-room checkpoints).
			lvl["death_action"] = "Restart Level"
			lvl["death_action_target"] = i + 1
			var grid = lvl["grid"]
			# Perimeter walls.
			for x in range(GRID_W):
				grid[0][x] = {"block_type": 1, "tile_index": 0}
				grid[GRID_H - 1][x] = {"block_type": 1, "tile_index": 0}
			for y in range(GRID_H):
				grid[y][0] = {"block_type": 1, "tile_index": 0}
				grid[y][GRID_W - 1] = {"block_type": 1, "tile_index": 0}
			# Inner obstacles (ponds / trees / pillars).
			for w in room["walls"]:
				for xx in range(w["x0"], w["x1"] + 1):
					for yy in range(w["y0"], w["y1"] + 1):
						grid[yy][xx] = {"block_type": 1, "tile_index": 0}
			# North door (goal teleport) — skipped on the final level.
			if room["door"] != null:
				var dr: Vector2i = room["door"]
				grid[dr.y][dr.x] = {"block_type": 5, "tile_index": 0}
			# Actors: hero first, then enemies, then friendlies/loot.
			var actors := [
				{"actor_id": 0, "x": room["spawn"].x, "y": room["spawn"].y, "path": []},
			]
			for p in room["goblins"]:
				actors.append({"actor_id": 1, "x": p.x, "y": p.y, "path": []})
			for p in room["bats"]:
				actors.append({"actor_id": 2, "x": p.x, "y": p.y, "path": []})
			if room["boss"] != null:
				var bp: Vector2i = room["boss"]
				actors.append({"actor_id": 3, "x": bp.x, "y": bp.y, "path": []})
			for p in room["npcs"]:
				actors.append({"actor_id": 4, "x": p.x, "y": p.y, "path": []})
			for p in room["chests"]:
				actors.append({"actor_id": 5, "x": p.x, "y": p.y, "path": []})
			for p in room["hearts"]:
				actors.append({"actor_id": 6, "x": p.x, "y": p.y, "path": []})
			lvl["actors"] = actors
			_editors[0].levels.append(lvl)


func _apply_side_shmup_template() -> void:
	if _editors.size() > 4 and _editors[4]:
		_editors[4].set_data({
			"game_title": "Hyperwing",
			"gravity": 0, "friction": 0, "elasticity": 0,
			"screen_width": 640, "screen_height": 384,
			"lives": 3, "show_score": true, "show_lives": true,
			"start_level": 1, "level_order": "Sequential",
		})
	if _editors.size() > 1 and _editors[1]:
		_editors[1].set_data([
			{"name": "Fighter", "type": "Player", "max_speed": 240, "gravity_scale": 0, "max_hp": 100, "damage": 30, "score_value": 0, "collision_mode": "Slide", "death_mode": "Respawn", "rebirth": 1.5},
			{"name": "Drone", "type": "Drone", "max_speed": 100, "gravity_scale": 0, "max_hp": 25, "damage": 20, "score_value": 100, "ai_behavior": "Patrol", "ai_patrol_speed": 100, "collision_mode": "Bounce", "death_mode": "Destroy"},
			{"name": "Bullet", "type": "Missile", "max_speed": 450, "gravity_scale": 0, "max_hp": 1, "damage": 30, "score_value": 0, "collision_mode": "None", "death_mode": "Destroy"},
		])
	if _editors.size() > 0 and _editors[0]:
		var GRID_W = 20; var GRID_H = 12
		var lvl = _editors[0]._make_empty_level(1)
		lvl["name"] = "Sector Alpha"
		var grid = lvl["grid"]
		# Top/bottom walls only — sides open for scroll
		for x in range(GRID_W):
			grid[0][x] = {"block_type": 1, "tile_index": 0}
			grid[GRID_H - 1][x] = {"block_type": 1, "tile_index": 0}
		# Exit on the right
		grid[GRID_H / 2][GRID_W - 1] = {"block_type": 5, "tile_index": 0}
		lvl["actors"] = [
			{"actor_id": 0, "x": 2, "y": GRID_H / 2, "path": []},  # Fighter on the left
			{"actor_id": 1, "x": 12, "y": 3, "path": []},
			{"actor_id": 1, "x": 14, "y": 6, "path": []},
			{"actor_id": 1, "x": 16, "y": 4, "path": []},
			{"actor_id": 1, "x": 17, "y": 8, "path": []},
		]
		_editors[0].levels.append(lvl)


func _apply_match3_template() -> void:
	if _editors.size() > 4 and _editors[4]:
		_editors[4].set_data({
			"game_title": "Gem Match",
			"gravity": 0, "friction": 0, "elasticity": 0,
			"screen_width": 480, "screen_height": 640,
			"lives": 1, "show_score": true, "show_lives": false,
			"start_level": 1, "level_order": "Sequential",
		})
	if _editors.size() > 1 and _editors[1]:
		_editors[1].set_data([
			{"name": "Cursor", "type": "Player", "max_speed": 0, "gravity_scale": 0, "max_hp": 1, "damage": 0, "score_value": 0, "collision_mode": "None", "death_mode": "GameOver", "rebirth": 0},
			{"name": "RedGem", "type": "Computer", "max_speed": 0, "gravity_scale": 0, "max_hp": 1, "damage": 0, "score_value": 100, "collision_mode": "None", "death_mode": "Destroy"},
			{"name": "BlueGem", "type": "Computer", "max_speed": 0, "gravity_scale": 0, "max_hp": 1, "damage": 0, "score_value": 100, "collision_mode": "None", "death_mode": "Destroy"},
			{"name": "GreenGem", "type": "Computer", "max_speed": 0, "gravity_scale": 0, "max_hp": 1, "damage": 0, "score_value": 100, "collision_mode": "None", "death_mode": "Destroy"},
		])
	if _editors.size() > 0 and _editors[0]:
		var GRID_W = 20; var GRID_H = 12
		var lvl = _editors[0]._make_empty_level(1)
		lvl["name"] = "Cascade 1"
		var grid = lvl["grid"]
		# Frame the play area
		for x in range(GRID_W):
			grid[0][x] = {"block_type": 1, "tile_index": 0}
			grid[GRID_H - 1][x] = {"block_type": 1, "tile_index": 0}
		for y in range(GRID_H):
			grid[y][0] = {"block_type": 1, "tile_index": 0}
			grid[y][GRID_W - 1] = {"block_type": 1, "tile_index": 0}
		# Fill an 8×6 gem grid offset inside
		var actors: Array = [
			{"actor_id": 0, "x": 2, "y": 2, "path": []},  # Cursor
		]
		var gem_kinds := [1, 2, 3]
		for row in range(6):
			for col in range(8):
				var kind: int = gem_kinds[(row * 7 + col * 3) % 3]
				actors.append({"actor_id": kind, "x": 5 + col, "y": 3 + row, "path": []})
		lvl["actors"] = actors
		_editors[0].levels.append(lvl)


func _apply_asteroids_template() -> void:
	if _editors.size() > 4 and _editors[4]:
		_editors[4].set_data({
			"game_title": "Rock Storm",
			"gravity": 0, "friction": 5, "elasticity": 60,
			"screen_width": 640, "screen_height": 480,
			"lives": 3, "show_score": true, "show_lives": true,
			"start_level": 1, "level_order": "Sequential",
		})
	if _editors.size() > 1 and _editors[1]:
		_editors[1].set_data([
			{"name": "Ship", "type": "Player", "max_speed": 220, "gravity_scale": 0, "max_hp": 100, "damage": 40, "score_value": 0, "collision_mode": "Bounce", "death_mode": "Respawn", "rebirth": 2.0},
			{"name": "Rock", "type": "Drone", "max_speed": 60, "gravity_scale": 0, "max_hp": 30, "damage": 25, "score_value": 50, "ai_behavior": "Patrol", "ai_patrol_speed": 60, "collision_mode": "Bounce", "death_mode": "Destroy"},
			{"name": "Bullet", "type": "Missile", "max_speed": 380, "gravity_scale": 0, "max_hp": 1, "damage": 40, "score_value": 0, "collision_mode": "None", "death_mode": "Destroy"},
		])
	if _editors.size() > 0 and _editors[0]:
		var GRID_W = 20; var GRID_H = 12
		var lvl = _editors[0]._make_empty_level(1)
		lvl["name"] = "Wave 1"
		var grid = lvl["grid"]
		# Open arena (no walls — wraparound feel)
		# Ship at center
		lvl["actors"] = [
			{"actor_id": 0, "x": GRID_W / 2, "y": GRID_H / 2, "path": []},
			{"actor_id": 1, "x": 2, "y": 2, "path": []},
			{"actor_id": 1, "x": GRID_W - 3, "y": 2, "path": []},
			{"actor_id": 1, "x": 2, "y": GRID_H - 3, "path": []},
			{"actor_id": 1, "x": GRID_W - 3, "y": GRID_H - 3, "path": []},
			{"actor_id": 1, "x": GRID_W / 2, "y": 2, "path": []},
		]
		_editors[0].levels.append(lvl)


func _apply_endless_runner_template() -> void:
	# ── Endless Runner (coin chase, Runner-physics) ────────────────────
	# Distinct from Geometry Dash: same auto-run engine but tuned for a
	# *score-attack* loop — wide gaps over a deathfloor, dense coin
	# trails along the ideal jump arcs, and Sequential teleport chain
	# of THREE 60-cell levels so a full run lasts ~12s before looping.
	#
	# Why Runner (not Player)?  We want hold-to-rejump cadence + auto
	# horizontal velocity so the player only thinks about jump timing.
	# Phase-1 fields (rotation_speed, snap_angle_deg) are not overridden
	# here so the sprite stays upright — overriding rotation_speed=0
	# would freeze it visually if a future skin uses a directional
	# sprite.  Leaving at default 9 rad/s gives a tumble that reads as
	# "running animation" without authoring frames.
	if _editors.size() > 4 and _editors[4]:
		_editors[4].set_data({
			"game_title": "Forever Run",
			# Gravity 1300 + jump_force 460 → ~1.7-cell jump arc, ~0.5s
			# airtime.  Lower than GD so coin lines feel reachable.
			"gravity": 1300, "friction": 0, "elasticity": 0,
			"screen_width": 640, "screen_height": 384,
			"background_color": "#1a2030",
			"lives": 1, "show_score": true, "show_lives": false,
			"start_level": 1, "level_order": "Sequential",
			"wrap_screen": false, "camera_zoom": 1.0,
			"keyboard_enabled": true, "joystick_enabled": true,
			"mouse_enabled": true, "touch_enabled": true,
			"deadly_damage": 999,
		})
	if _editors.size() > 1 and _editors[1]:
		_editors[1].set_data([
			# Speed 240 ≈ 15 cells/sec — easier to read coin lines than
			# GD's 260.  jump_force 460 pairs with gravity 1300 for the
			# arc described above.
			{"name": "Runner", "type": "Runner", "max_speed": 240, "gravity_scale": 1.0,
				"max_hp": 1, "damage": 0, "score_value": 0,
				"collision_mode": "Slide", "death_mode": "GameOver", "rebirth": 0,
				"jump_force": 460},
			{"name": "Spike", "type": "Drone", "max_speed": 0, "gravity_scale": 0,
				"max_hp": 9999, "damage": 100, "score_value": 0,
				"ai_behavior": "Idle", "ai_patrol_speed": 0,
				"collision_mode": "None", "death_mode": "Destroy"},
			{"name": "Coin", "type": "Computer", "max_speed": 0, "gravity_scale": 0,
				"max_hp": 1, "damage": 0, "score_value": 10,
				"collision_mode": "None", "death_mode": "Destroy"},
		])
	if _editors.size() > 0 and _editors[0]:
		const LVL_W := 60
		const LVL_H := 14
		# Each chunk: gaps (deathfloor segments), spike columns, and the
		# coin arcs.  Coin arcs are authored as relative (dx, dy) offsets
		# from a centre tile so they sit on the natural jump curve.
		var chunks := [
			{
				"name": "Sunrise Sprint",
				"spawn_x": 1,
				"gaps": [[20, 23], [38, 41]],
				"spikes": [12, 30, 50],
				# Coin arcs at the apex over each obstacle/gap.
				"coin_arcs": [
					{"cx": 12, "cy": LVL_H - 4},
					{"cx": 21, "cy": LVL_H - 4},
					{"cx": 30, "cy": LVL_H - 4},
					{"cx": 39, "cy": LVL_H - 4},
					{"cx": 50, "cy": LVL_H - 4},
				],
				# Free-floating coin streamers between obstacles.
				"coin_rows": [
					{"row": LVL_H - 6, "x0": 4, "x1": 9},
					{"row": LVL_H - 6, "x0": 44, "x1": 47},
				],
			},
			{
				"name": "Canyon Chase",
				"spawn_x": 0,
				# Tighter cluster of gaps with a "land + jump again" beat.
				"gaps": [[14, 17], [22, 25], [40, 44]],
				"spikes": [9, 32, 52],
				"coin_arcs": [
					{"cx": 9, "cy": LVL_H - 4},
					{"cx": 15, "cy": LVL_H - 4},
					{"cx": 23, "cy": LVL_H - 4},
					{"cx": 32, "cy": LVL_H - 4},
					{"cx": 42, "cy": LVL_H - 4},
					{"cx": 52, "cy": LVL_H - 4},
				],
				"coin_rows": [
					{"row": LVL_H - 6, "x0": 4, "x1": 7},
					{"row": LVL_H - 6, "x0": 28, "x1": 30},
				],
			},
			{
				"name": "Skyline Finale",
				"spawn_x": 0,
				# Wider gaps + clustered spikes — payoff level.
				"gaps": [[16, 20], [32, 37], [46, 50]],
				"spikes": [10, 11, 26, 41, 42, 54],
				"coin_arcs": [
					{"cx": 10, "cy": LVL_H - 4},
					{"cx": 18, "cy": LVL_H - 4},
					{"cx": 26, "cy": LVL_H - 4},
					{"cx": 34, "cy": LVL_H - 4},
					{"cx": 41, "cy": LVL_H - 4},
					{"cx": 48, "cy": LVL_H - 4},
					{"cx": 54, "cy": LVL_H - 4},
				],
				"coin_rows": [
					{"row": LVL_H - 6, "x0": 4, "x1": 7},
				],
			},
		]
		for i in range(chunks.size()):
			var ck = chunks[i]
			var lvl = _editors[0]._make_empty_level(i + 1, LVL_W, LVL_H)
			lvl["name"] = ck["name"]
			lvl["death_action"] = "Restart Level"
			lvl["death_action_target"] = i + 1
			var grid = lvl["grid"]
			# Solid floor across the bottom — punch out gaps below.
			for x in range(LVL_W):
				grid[LVL_H - 1][x] = {"block_type": 1, "tile_index": 0}
			# Carve out gaps (death pits the Runner must jump over).
			for g in ck["gaps"]:
				for x in range(g[0], g[1] + 1):
					grid[LVL_H - 1][x] = null
			# Spike columns on the row above the floor.
			for sx in ck["spikes"]:
				grid[LVL_H - 2][sx] = {"block_type": 3, "tile_index": 0}
			# Goal teleport tile at far right.
			grid[LVL_H - 5][LVL_W - 2] = {"block_type": 5, "tile_index": 0}
			# Actor list — Runner first, then all coins.
			var actors := [
				{"actor_id": 0, "x": ck["spawn_x"], "y": LVL_H - 2, "path": []},
			]
			# Coin arcs: 5 coins shaped like an inverted V around (cx, cy).
			# Pattern (relative): (-2,+1), (-1, 0), (0,-1), (+1, 0), (+2,+1).
			var arc_offsets := [
				Vector2i(-2, 1), Vector2i(-1, 0), Vector2i(0, -1),
				Vector2i(1, 0), Vector2i(2, 1),
			]
			for arc in ck["coin_arcs"]:
				var cx: int = arc["cx"]
				var cy: int = arc["cy"]
				for off in arc_offsets:
					var ax: int = cx + off.x
					var ay: int = cy + off.y
					if ax >= 0 and ax < LVL_W and ay >= 0 and ay < LVL_H:
						actors.append({"actor_id": 2, "x": ax, "y": ay, "path": []})
			# Straight coin streamers between obstacles.
			for r in ck["coin_rows"]:
				for x in range(r["x0"], r["x1"] + 1):
					actors.append({"actor_id": 2, "x": x, "y": r["row"], "path": []})
			lvl["actors"] = actors
			_editors[0].levels.append(lvl)


func _apply_geometry_dash_template() -> void:
	# ── 8-bit Geometry Dash ─────────────────────────────────────────────
	# True-to-genre auto-runner. The "Cube" actor is type=Runner (not Player),
	# so it uses _gen_runner_physics: constant rightward velocity, jump-only
	# input, sprite rotates while airborne and snaps to 90° on landing.
	#
	# LEVEL LENGTH STRATEGY:
	# AGCK now supports per-level variable grid dimensions (up to 200×60).
	# We build FOUR chained 50×16 levels — wide enough that each section
	# breathes properly, tall enough to give ceiling segments real sky,
	# and the Sequential teleport at the far right still chains them.
	# At speed 260 (~16 cells/sec) each 50-cell segment lasts ~3.1s; the
	# full chain is ~12.5s of authentic-GD play. Death reloads the
	# current level only (forgiving), not the whole chain.
	if _editors.size() > 4 and _editors[4]:
		_editors[4].set_data({
			"game_title": "Cube Beat",
			# Gravity 1600 + jump_force 520 → ~2-tile-high arc landing every ~0.55s.
			"gravity": 1600, "friction": 0, "elasticity": 0,
			"screen_width": 480, "screen_height": 320,
			"background_color": "#0a0a1a",
			"lives": 1, "show_score": true, "show_lives": false,
			# Sequential level_order is what makes the teleport tiles chain
			# from Level 1 → 2 → 3 ... — each one a fresh wide scene.
			"start_level": 1, "level_order": "Sequential",
			"wrap_screen": false, "camera_zoom": 1.0,
			"keyboard_enabled": true, "joystick_enabled": true,
			"mouse_enabled": true, "touch_enabled": true,
			"deadly_damage": 999,
		})
	if _editors.size() > 1 and _editors[1]:
		_editors[1].set_data([
			# Speed 260: gives the player ~0.4s to react to the first spike.
			{"name": "Cube", "type": "Runner", "max_speed": 260, "gravity_scale": 1.0,
				"max_hp": 1, "damage": 0, "score_value": 0,
				"collision_mode": "Slide", "death_mode": "GameOver", "rebirth": 0,
				"jump_force": 520},
			{"name": "Pad", "type": "Computer", "max_speed": 0, "gravity_scale": 0,
				"max_hp": 9999, "damage": 0, "score_value": 50,
				"collision_mode": "None", "death_mode": "Destroy"},
		])
	if _editors.size() > 0 and _editors[0]:
		# Per-level dimensions. 50 wide gives ~3s of screen-time per level
		# (was 20 → ~1.25s, which felt cramped). 16 tall gives clear sky
		# above the play surface so ceiling sections are visually distinct
		# from the floor — at 12 they were almost touching.
		const LVL_W := 50
		const LVL_H := 16
		# Each chunk describes one level: name + spike columns + extras.
		# Spike X positions are tuned for a ~0.55s jump cadence at speed 260.
		# Cube spawns at x=2 only on Level 1 (gives a visible 2-cell runway
		# before any obstacle); subsequent levels spawn it at x=0 so it
		# crosses the boundary without losing momentum.
		var chunks := [
			{
				# ── Level 1 — Lead-in / tutorial ───────────────────────
				# Long quiet runway (12 cells) so the player can adapt to
				# the auto-run cadence. Then four single spikes spaced 6
				# cells apart — the easy-mode "find the beat" intro.
				"name": "Stereo Madness",
				"spawn_x": 2,
				"spikes": [14, 20, 26, 32, 40],
				"platforms": [],
				"ceilings": [],
				"pads": [{"x": 36, "y": LVL_H - 5}],
			},
			{
				# ── Level 2 — Single→double rhythm ─────────────────────
				# Singles for the first half, then adjacent pairs — same
				# beat, longer commitment. Reward pad mid-level.
				"name": "Back On Track",
				"spawn_x": 0,
				"spikes": [5, 11, 17, 23, 29, 30, 36, 37, 43],
				"platforms": [{"row": LVL_H - 4, "x0": 24, "x1": 27}],
				"ceilings": [],
				"pads": [{"x": 25, "y": LVL_H - 5}],
			},
			{
				# ── Level 3 — Ceiling section ──────────────────────────
				# Mid-level ceiling bar forces a NON-jump (stay grounded).
				# Wide level lets us telegraph it visually before it bites.
				"name": "Polargeist",
				"spawn_x": 0,
				"spikes": [4, 10, 16, 30, 36, 42],
				"platforms": [],
				"ceilings": [{"row": LVL_H - 5, "x0": 20, "x1": 26}],
				"pads": [],
			},
			{
				# ── Level 4 — Finale: triples + reward ─────────────────
				# Triple-spike clusters require committed jump arcs.
				# Raised platform finish with a pad reward right before
				# the goal teleport.
				"name": "Cant Let Go",
				"spawn_x": 0,
				"spikes": [4, 5, 6, 13, 14, 15, 23, 24, 25, 33, 39, 40, 41],
				"platforms": [{"row": LVL_H - 4, "x0": 44, "x1": 47}],
				"ceilings": [],
				"pads": [{"x": 45, "y": LVL_H - 5}],
			},
		]
		for i in range(chunks.size()):
			var ck = chunks[i]
			# _make_empty_level now accepts (num, w, h) so we get a 50×16
			# grid out of the gate with grid_w/grid_h baked into the dict.
			var lvl = _editors[0]._make_empty_level(i + 1, LVL_W, LVL_H)
			lvl["name"] = ck["name"]
			# Death restarts THIS level only (not the chain) — that's the
			# forgiving "checkpoint per level" feel. GD purists would prefer
			# a full chain reset; we can add a "Hardcore" flag later.
			lvl["death_action"] = "Restart Level"
			lvl["death_action_target"] = i + 1
			var grid = lvl["grid"]
			# Solid floor across the entire bottom row.
			for x in range(LVL_W):
				grid[LVL_H - 1][x] = {"block_type": 1, "tile_index": 0}
			# Spikes (block_type 3 = Deadly) on the row above the floor.
			for sx in ck["spikes"]:
				grid[LVL_H - 2][sx] = {"block_type": 3, "tile_index": 0}
			# Optional raised platforms (Barrier blocks, walkable surface).
			for plat in ck["platforms"]:
				for x in range(plat["x0"], plat["x1"] + 1):
					grid[plat["row"]][x] = {"block_type": 1, "tile_index": 0}
			# Optional ceiling segments (force player to stay grounded).
			for c in ck["ceilings"]:
				for x in range(c["x0"], c["x1"] + 1):
					grid[c["row"]][x] = {"block_type": 1, "tile_index": 0}
			# Goal teleport at far right (Sequential mode advances level).
			grid[LVL_H - 5][LVL_W - 2] = {"block_type": 5, "tile_index": 0}
			# Actors: the cube + any pad collectibles.
			var actors := [
				{"actor_id": 0, "x": ck["spawn_x"], "y": LVL_H - 2, "path": []},
			]
			for p in ck["pads"]:
				actors.append({"actor_id": 1, "x": p["x"], "y": p["y"], "path": []})
			lvl["actors"] = actors
			_editors[0].levels.append(lvl)


## Build the project then launch it in Godot's play-scene runner.
func _begin_build_and_play(game_data: Dictionary) -> void:
	var result := _execute_build(game_data)
	if not result.get("ok", false):
		_forward_build_log("[color=#ff4444]✗ Build failed — cannot launch preview.[/color]")
		return

	var output_dir: String = result.get("output_dir", "")
	var main_tscn := output_dir + "Main.tscn"
	if not FileAccess.file_exists(main_tscn):
		_forward_build_log("[color=#ff4444]✗ Main.tscn not found at " + main_tscn + "[/color]")
		return

	_forward_build_log("[color=#5599ff]▶ Launching preview: " + main_tscn + "[/color]")

	# Wait for the filesystem scan to register the new/updated files
	if _view and is_instance_valid(_view) and _view.is_inside_tree():
		# Give the filesystem scan enough frames to complete
		for _i in range(5):
			await _view.get_tree().process_frame
		# Also wait for the scan to finish, but bound the wait so we never
		# deadlock — on Windows we've observed `filesystem_changed` to be
		# slow or to coalesce with an earlier scan, leaving an `await` on
		# it pinned forever (looks like AGCK has hung). Race the signal
		# against a 5s timeout so the build always proceeds.
		if Engine.is_editor_hint():
			var efs = EditorInterface.get_resource_filesystem()
			if efs and efs.is_scanning():
				var timer := _view.get_tree().create_timer(5.0)
				await Engine.get_main_loop().process_frame  # let the timer arm
				while efs.is_scanning() and timer.time_left > 0.0:
					await _view.get_tree().process_frame
				await _view.get_tree().process_frame

	# Launch the scene using Godot's built-in play-scene runner
	if Engine.is_editor_hint():
		EditorInterface.play_custom_scene(main_tscn)
		_forward_build_log("[color=#8f8]  ✓ Game launched! Close the game window to return to the editor.[/color]")


## Checks for existing project content and either builds immediately
## or shows a confirmation dialog when the output directory already has files.
func _begin_build(game_data: Dictionary) -> void:
	var build_opts: Dictionary = game_data.get("build", {})
	var settings: Dictionary = game_data.get("settings", {})
	var game_title: String = settings.get("game_title", "AGCKGame")
	var safe_name: String = game_title.replace(" ", "_").replace("/", "_").replace("\\", "_")
	if safe_name.is_empty():
		safe_name = "AGCKGame"
	var output_dir: String = build_opts.get("output_path", "res://build/")
	if not output_dir.ends_with("/"):
		output_dir += "/"
	output_dir += safe_name + "/"

	# Check if the output directory already has content
	var existing_files := _scan_existing_project(output_dir)
	if existing_files.is_empty():
		# No conflicts — build and load directly
		_run_build_and_load(game_data)
	else:
		# Existing content found — show confirmation dialog
		_show_build_conflict_dialog(game_data, output_dir, existing_files)


## Scans the build output directory for existing .vg, .tscn, and .png files.
## Returns a list of found file paths (empty if directory doesn't exist or is empty).
func _scan_existing_project(output_dir: String) -> Array[String]:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(output_dir):
		return found
	var dir := DirAccess.open(output_dir)
	if not dir:
		return found
	# Check top-level and one level of subdirectories
	var dirs_to_scan: Array[String] = [output_dir]
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			dirs_to_scan.append(output_dir + entry + "/")
		entry = dir.get_next()
	dir.list_dir_end()
	for scan_dir in dirs_to_scan:
		var d := DirAccess.open(scan_dir)
		if not d:
			continue
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if not d.current_is_dir():
				if f.ends_with(".vg") or f.ends_with(".tscn") or f.ends_with(".png"):
					found.append(scan_dir + f)
			f = d.get_next()
		d.list_dir_end()
	return found


## Shows an AGCK-themed build conflict dialog with four options.
func _show_build_conflict_dialog(game_data: Dictionary, output_dir: String, existing_files: Array[String]) -> void:
	# Build file summary
	var vg_count := 0
	var tscn_count := 0
	var png_count := 0
	for f in existing_files:
		if f.ends_with(".vg"):
			vg_count += 1
		elif f.ends_with(".tscn"):
			tscn_count += 1
		elif f.ends_with(".png"):
			png_count += 1

	# Create the dialog
	var dialog := AcceptDialog.new()
	dialog.title = "AGCK — Existing Project Detected"
	dialog.dialog_hide_on_ok = true
	dialog.min_size = Vector2(520, 0)

	# On Windows the editor frequently runs with VG's VB6 light theme,
	# which paints the dialog background light grey/white. Combined with
	# the body labels' explicit light-grey font color, that produced
	# unreadable light-on-light text. Linux/macOS were unaffected, so we
	# only force a guaranteed-dark background on Windows and leave the
	# other platforms picking up the host theme as before.
	var is_windows := OS.get_name() == "Windows"

	if is_windows:
		# Belt-and-suspenders: also force a dark Theme directly on the Window
		# panel stylebox so the dialog frame itself paints dark even before
		# our content PanelContainer (added below) gets a chance to render.
		# Without this the strip of frame around the PanelContainer is still
		# light grey on Windows.
		var dlg_theme := Theme.new()
		var dlg_bg := StyleBoxFlat.new()
		dlg_bg.bg_color = Color(0.16, 0.17, 0.20)
		dlg_bg.border_color = Color(0.30, 0.32, 0.38)
		dlg_bg.set_border_width_all(1)
		dlg_bg.set_content_margin_all(8)
		for tn in ["AcceptDialog", "ConfirmationDialog", "Window", "PopupPanel", "Panel"]:
			dlg_theme.set_stylebox("panel", tn, dlg_bg)
			dlg_theme.set_stylebox("embedded_border", tn, dlg_bg)
		dlg_theme.set_color("title_color", "Window", Color(0.95, 0.95, 0.97))
		dlg_theme.set_color("font_color", "Label", Color(0.92, 0.92, 0.95))
		dialog.theme = dlg_theme

	# Remove the default OK button — we add custom ones
	dialog.get_ok_button().visible = false

	# Build the content. On Windows wrap it in a PanelContainer with an
	# explicit dark stylebox so the labels always sit on a known background.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# Warning icon + message
	var msg := Label.new()
	msg.text = "⚠️  The build output directory already contains project files:"
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 13)
	if is_windows:
		msg.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	vbox.add_child(msg)

	# File counts
	var details := Label.new()
	var parts: Array[String] = []
	if vg_count > 0:
		parts.append(str(vg_count) + " code file" + ("s" if vg_count != 1 else "") + " (.vg)")
	if tscn_count > 0:
		parts.append(str(tscn_count) + " scene" + ("s" if tscn_count != 1 else "") + " (.tscn)")
	if png_count > 0:
		parts.append(str(png_count) + " sprite" + ("s" if png_count != 1 else "") + " (.png)")
	details.text = "    📁  " + output_dir + "\n    " + ", ".join(parts)
	details.add_theme_font_size_override("font_size", 11)
	# Light-grey on Linux's dark dialog reads fine; on Windows we need
	# near-white to show against the dark wrapper added below.
	if is_windows:
		details.add_theme_color_override("font_color", Color(0.82, 0.84, 0.90))
	else:
		details.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	vbox.add_child(details)

	vbox.add_child(HSeparator.new())

	# Buttons in a centered row
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 8)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER

	# 1. Overwrite & Load
	var overwrite_btn := Button.new()
	overwrite_btn.text = "🔨 Overwrite && Load"
	overwrite_btn.tooltip_text = "Rebuild all files and open the project in VG"
	overwrite_btn.custom_minimum_size = Vector2(140, 36)
	overwrite_btn.add_theme_font_size_override("font_size", 12)
	var ow_s := StyleBoxFlat.new()
	ow_s.bg_color = Color(0.30, 0.80, 0.35)
	ow_s.set_corner_radius_all(6)
	ow_s.content_margin_left = 10; ow_s.content_margin_right = 10
	ow_s.content_margin_top = 4;   ow_s.content_margin_bottom = 4
	overwrite_btn.add_theme_stylebox_override("normal", ow_s)
	var ow_h := ow_s.duplicate()
	ow_h.bg_color = Color(0.30, 0.80, 0.35).lightened(0.15)
	overwrite_btn.add_theme_stylebox_override("hover", ow_h)
	overwrite_btn.add_theme_color_override("font_color", Color.WHITE)
	overwrite_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn_box.add_child(overwrite_btn)

	# 2. Build Only (don't load)
	var build_only_btn := Button.new()
	build_only_btn.text = "📦 Build Only"
	build_only_btn.tooltip_text = "Rebuild files but don't open them in VG"
	build_only_btn.custom_minimum_size = Vector2(120, 36)
	build_only_btn.add_theme_font_size_override("font_size", 12)
	var bo_s := StyleBoxFlat.new()
	bo_s.bg_color = Color(0.35, 0.55, 0.95)
	bo_s.set_corner_radius_all(6)
	bo_s.content_margin_left = 10; bo_s.content_margin_right = 10
	bo_s.content_margin_top = 4;   bo_s.content_margin_bottom = 4
	build_only_btn.add_theme_stylebox_override("normal", bo_s)
	var bo_h := bo_s.duplicate()
	bo_h.bg_color = Color(0.35, 0.55, 0.95).lightened(0.15)
	build_only_btn.add_theme_stylebox_override("hover", bo_h)
	build_only_btn.add_theme_color_override("font_color", Color.WHITE)
	build_only_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn_box.add_child(build_only_btn)

	# 3. Cancel
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.tooltip_text = "Don't build — go back to AGCK"
	cancel_btn.custom_minimum_size = Vector2(90, 36)
	cancel_btn.add_theme_font_size_override("font_size", 12)
	var cn_s := StyleBoxFlat.new()
	cn_s.bg_color = Color(0.25, 0.25, 0.30)
	cn_s.set_corner_radius_all(6)
	cn_s.content_margin_left = 10; cn_s.content_margin_right = 10
	cn_s.content_margin_top = 4;   cn_s.content_margin_bottom = 4
	cancel_btn.add_theme_stylebox_override("normal", cn_s)
	var cn_h := cn_s.duplicate()
	cn_h.bg_color = Color(0.30, 0.30, 0.38)
	cancel_btn.add_theme_stylebox_override("hover", cn_h)
	cancel_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	cancel_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn_box.add_child(cancel_btn)

	vbox.add_child(btn_box)
	if is_windows:
		# Wrap the vbox in a PanelContainer with an explicit dark stylebox
		# so the labels are guaranteed to sit on a dark background, no
		# matter what host theme the editor is using.
		var panel := PanelContainer.new()
		var panel_bg := StyleBoxFlat.new()
		panel_bg.bg_color = Color(0.16, 0.17, 0.20)
		panel_bg.border_color = Color(0.30, 0.32, 0.38)
		panel_bg.set_border_width_all(1)
		panel_bg.set_content_margin_all(12)
		panel_bg.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", panel_bg)
		panel.add_child(vbox)
		dialog.add_child(panel)
	else:
		dialog.add_child(vbox)

	# Wire button signals
	overwrite_btn.pressed.connect(func():
		dialog.hide()
		dialog.queue_free()
		_run_build_and_load(game_data)
	)
	build_only_btn.pressed.connect(func():
		dialog.hide()
		dialog.queue_free()
		_run_build_no_load(game_data)
	)
	cancel_btn.pressed.connect(func():
		dialog.hide()
		dialog.queue_free()
		_forward_build_log("[color=#aaa]Build cancelled by user.[/color]")
	)

	# Show the dialog
	if _view and is_instance_valid(_view) and _view.is_inside_tree():
		_view.add_child(dialog)
	elif Engine.is_editor_hint():
		EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()


## Runs the build and opens the result in VG's editors.
func _run_build_and_load(game_data: Dictionary) -> void:
	var result := _execute_build(game_data)
	if result.get("ok", false):
		_load_build_result(result)


## Runs the build without opening files (legacy behavior).
func _run_build_no_load(game_data: Dictionary) -> void:
	var result := _execute_build(game_data)
	if result.get("ok", false):
		_forward_build_log("[color=#aaa]💡 Build complete. Files are in " + result["output_dir"] + "[/color]")
		_forward_build_log("[color=#aaa]   Open them manually via the FileSystem dock or Project Explorer.[/color]")


## Core build execution — shared by all build modes.
func _execute_build(game_data: Dictionary) -> Dictionary:
	# Before building, reimport any sprites the user edited externally
	_reimport_changed_sprites(game_data)

	_builder = BuilderBackend.new()
	_builder.tile_library = _tile_lib
	var log_cb = Callable(self, "_forward_build_log")
	var result = _builder.build(game_data, log_cb)
	if result.get("ok", false):
		print("AGCK: Build succeeded — ", result["files"].size(), " files in ", result["output_dir"])

		# Remove any stale nested project.godot from build output (would confuse Godot)
		var nested_pg: String = result["output_dir"] + "project.godot"
		if FileAccess.file_exists(nested_pg):
			DirAccess.remove_absolute(nested_pg)

		# Update the REAL project root project.godot so the game is playable
		var main_scene_path: String = result["output_dir"] + "Main.tscn"
		_update_root_project_godot(main_scene_path, game_data.get("settings", {}))

		# Trigger Godot filesystem scan so new files appear
		if Engine.is_editor_hint():
			var efs = EditorInterface.get_resource_filesystem()
			if efs:
				efs.scan()
		# Stamp sprite modification times so the bridge can detect future edits
		var sprites_dir: String = result["output_dir"] + "sprites/"
		if _tile_lib and _tile_lib.has_method("stamp_exported_sprites"):
			_tile_lib.stamp_exported_sprites(sprites_dir)
	else:
		push_warning("AGCK: Build failed")
	return result


## Updates the ROOT project.godot so the built game is immediately playable.
## Sets run/main_scene to the built Main.tscn and opens it in the editor.
##
## Uses the ProjectSettings API (not raw file write) so the editor doesn't
## flag project.godot as "file changed on disk" — the editor itself is the
## one persisting the change, so its dirty-tracking stays in sync.
func _update_root_project_godot(main_scene_path: String, settings: Dictionary) -> void:
	# Main scene — what F5 / play_custom_scene runs.
	ProjectSettings.set_setting("application/run/main_scene", main_scene_path)

	# Honor the Display → Fullscreen toggle on the host project. EditorInterface
	# .play_custom_scene runs under the host project's display settings, so this
	# is what actually engages fullscreen when previewing from the editor.
	# 0 = Windowed, 3 = Exclusive Fullscreen. (We also inject a runtime
	# DisplayServer call into Main.tscn as a belt-and-suspenders fallback.)
	var fullscreen: bool = bool(settings.get("fullscreen", false))
	ProjectSettings.set_setting("display/window/size/mode", 3 if fullscreen else 0)

	# Reduce input-to-action latency. Player input is sampled inside
	# _PhysicsProcess; the engine default 60 Hz physics tick adds up to ~16 ms
	# of input lag on top of v-sync. 120 Hz halves the worst case to ~8 ms
	# without changing balance (movement uses delta).
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second", 120)

	# Uncap rendering FPS on high-refresh displays. vsync_mode 3 = Mailbox:
	# no tearing, no 60 Hz cap when the monitor can do more. Falls back to
	# enabled-vsync behavior on 60 Hz panels. This addresses tester feedback
	# that the game "feels lower framerate than Geometry Dash" — GD runs
	# uncapped, so on a 144/240 Hz display ours was visibly choppier.
	ProjectSettings.set_setting("display/window/vsync/vsync_mode", 3)

	# Persist the ProjectSettings changes back to project.godot. The editor
	# performs this write itself, so it does NOT trigger a "file changed on
	# disk" reload prompt the way a raw FileAccess.WRITE did.
	var err := ProjectSettings.save()
	if err == OK:
		_forward_build_log("[color=#8f8]  ✓ project.godot updated — main scene: " + main_scene_path + "[/color]")
		print("AGCK: Updated root project.godot main_scene=", main_scene_path)
	else:
		push_warning("AGCK: ProjectSettings.save() returned error " + str(err))

	# NOTE: Don't open Main.tscn here — _load_build_result() will open it
	# AFTER the filesystem scan finishes importing new resources (sprites, etc.).


## Set or insert a "key=value" line under [section] in a project.godot text
## blob. Creates the section if it doesn't exist. Returns the modified text.
## (Retained for any callers that still need raw .ini patching; the main
## build path now goes through ProjectSettings.set_setting + save.)
func _patch_project_godot_kv(text: String, section: String, key: String, value: String) -> String:
	var line := key + "=" + value
	# Try to replace an existing key= line anywhere in the file (Godot tolerates
	# section-less keys but we still scope the replace to the named section
	# when the section is present).
	var sec_header := "[" + section + "]"
	var sec_idx := text.find(sec_header)
	if sec_idx < 0:
		# No section yet — append a fresh one
		if not text.ends_with("\n"):
			text += "\n"
		text += "\n" + sec_header + "\n\n" + line + "\n"
		return text
	# Find the end of this section (next [...] header or EOF)
	var sec_body_start := text.find("\n", sec_idx) + 1
	var next_sec := text.find("\n[", sec_body_start)
	var sec_body_end := next_sec if next_sec >= 0 else text.length()
	var body := text.substr(sec_body_start, sec_body_end - sec_body_start)
	var key_re := RegEx.new()
	# Escape regex metachars in key (the keys we patch contain '/')
	var esc_key := key.replace("/", "\\/").replace(".", "\\.")
	key_re.compile("(?m)^" + esc_key + "=.*$")
	if key_re.search(body):
		body = key_re.sub(body, line)
	else:
		# Insert at the end of the section body, before the trailing newline
		if not body.ends_with("\n"):
			body += "\n"
		body += line + "\n"
	return text.substr(0, sec_body_start) + body + text.substr(sec_body_end)


## Reimport any sprites that were edited in VG Sprite Editor or externally
## since the last build, flowing changes back into the tile library.
func _reimport_changed_sprites(game_data: Dictionary) -> void:
	if not _tile_lib or not _tile_lib.has_method("reimport_changed_sprites"):
		return
	var build_opts: Dictionary = game_data.get("build", {})
	var settings: Dictionary = game_data.get("settings", {})
	var game_title: String = settings.get("game_title", "AGCKGame")
	var safe_name: String = game_title.replace(" ", "_").replace("/", "_").replace("\\", "_")
	if safe_name.is_empty():
		safe_name = "AGCKGame"
	var output_dir: String = build_opts.get("output_path", "res://build/")
	if not output_dir.ends_with("/"):
		output_dir += "/"
	output_dir += safe_name + "/"
	var sprites_dir := output_dir + "sprites/"
	var actors: Array = game_data.get("actors", [])
	var count = _tile_lib.reimport_changed_sprites(sprites_dir, actors)
	if count > 0:
		_forward_build_log("[color=#55ccff]🔄 Reimported " + str(count) + " edited sprite(s) from build output[/color]")
		# Refresh editors so updated tiles/actors are visible
		if _editors.size() > 0 and _editors[0] and _editors[0].has_method("refresh_all"):
			_editors[0].refresh_all()
		if _editors.size() > 1 and _editors[1] and _editors[1].has_method("refresh_all"):
			_editors[1].refresh_all()


## Opens the built project files in VG's editors.
## Opens Main.tscn in the 2D editor and Main.vg in the code editor.
## Also refreshes the VG Project Explorer so the new files appear immediately.
func _load_build_result(result: Dictionary) -> void:
	var output_dir: String = result.get("output_dir", "")
	var files: Array = result.get("files", [])
	if output_dir.is_empty():
		return

	_forward_build_log("[color=#55ccff]📂 Loading project into VG editors…[/color]")

	# Wait for the filesystem scan to fully import new files (sprites, scenes, etc.)
	if _view and is_instance_valid(_view) and _view.is_inside_tree():
		if Engine.is_editor_hint():
			var efs = EditorInterface.get_resource_filesystem()
			if efs:
				# Trigger a fresh scan so newly generated PNGs get imported
				efs.scan()
				# Wait a few frames for the scan to start
				for _i in range(8):
					await _view.get_tree().process_frame
				# If still scanning, wait for completion
				if efs.is_scanning():
					await efs.filesystem_changed
				# Extra frames for import finalisation
				for _i in range(3):
					await _view.get_tree().process_frame

	# 1. Open Main.tscn in VG's 2D Editor (not the Form Designer — AGCK games
	#    are Node2D-based scenes, not VB6-style forms, so the 2D Editor's
	#    click-to-select / drag-to-move machinery is what we need here).
	var main_tscn := output_dir + "Main.tscn"
	if FileAccess.file_exists(main_tscn):
		# Also open in Godot's scene tab so the scene tree is available
		if not main_tscn in EditorInterface.get_open_scenes():
			EditorInterface.open_scene_from_path(main_tscn)
		# Load into VG's embedded 2D editor
		if _host_plugin:
			var editor_2d = _host_plugin.get("_vg_2d_editor")
			if editor_2d and editor_2d.has_method("load_scene"):
				editor_2d.load_scene(main_tscn)
				_forward_build_log("[color=#8f8]  ✓ Opened Main.tscn in 2D Editor[/color]")
			else:
				EditorInterface.open_scene_from_path(main_tscn)
				_forward_build_log("[color=#8f8]  ✓ Opened Main.tscn in Scene Editor[/color]")
			# Switch VG IDE to the 2D view so the user sees the 2D editor
			if _host_plugin.has_method("_on_2d_view_pressed"):
				EditorInterface.set_main_screen_editor("Visual Gasic IDE")
				_host_plugin._on_2d_view_pressed()
		else:
			EditorInterface.open_scene_from_path(main_tscn)
			_forward_build_log("[color=#8f8]  ✓ Opened Main.tscn in Scene Editor[/color]")

	# 2. Open Main.vg in VG's embedded code editor
	var main_vg := output_dir + "Main.vg"
	if FileAccess.file_exists(main_vg):
		if _host_plugin and _host_plugin.has_method("open_module_in_embedded_editor"):
			_host_plugin.open_module_in_embedded_editor(main_vg)
			_forward_build_log("[color=#8f8]  ✓ Opened Main.vg in Code Editor[/color]")

	# 3. Refresh the VG Project Explorer so new files show up in the tree
	if _host_plugin:
		var proj_explorer = _host_plugin.get("_project_explorer")
		if proj_explorer and proj_explorer.has_method("refresh"):
			proj_explorer.refresh()
			_forward_build_log("[color=#8f8]  ✓ Project Explorer refreshed[/color]")

	# 4. Log summary with hints
	_forward_build_log("")
	_forward_build_log("[color=#ffcc55]═══════════════════════════════════════════[/color]")
	_forward_build_log("[color=#ffcc55]  🎮 Project loaded! You can now:[/color]")
	_forward_build_log("[color=#aaa]  • Edit code in the Code Editor (Main.vg)[/color]")
	_forward_build_log("[color=#aaa]  • Edit scenes in the 2D Editor (Main.tscn)[/color]")
	_forward_build_log("[color=#aaa]  • Edit sprites in the Sprite Editor (.png)[/color]")
	_forward_build_log("[color=#aaa]  • Return to AGCK to redesign and rebuild[/color]")
	_forward_build_log("[color=#ffcc55]═══════════════════════════════════════════[/color]")

func _forward_build_log(bbcode: String) -> void:
	# Forward to the game builder's log output (index 5 = Build tab)
	if _editors.size() > 5 and _editors[5] and _editors[5].has_method("log_msg"):
		_editors[5].log_msg(bbcode)

func _collect_all_data() -> Dictionary:
	var game_data: Dictionary = {}
	# Editor indices: 0=Levels, 1=Actors, 2=Sounds, 3=Shaders, 4=Settings, 5=Build
	if _editors.size() > 4 and _editors[4]:
		game_data["settings"] = _editors[4].get_data()
	if _editors.size() > 1 and _editors[1]:
		game_data["actors"] = _editors[1].get_data()
	if _editors.size() > 2 and _editors[2]:
		game_data["sounds"] = _editors[2].get_data()
	if _editors.size() > 0 and _editors[0]:
		game_data["levels"] = _editors[0].get_data()
	if _editors.size() > 3 and _editors[3]:
		game_data["shaders"] = _editors[3].get_data()
	if _editors.size() > 5 and _editors[5]:
		game_data["build"] = _editors[5].get_data()
	if _tile_lib and _tile_lib.has_method("get_data"):
		game_data["tile_library"] = _tile_lib.get_data()
	# Merge the build screen's Start Level into settings so the builder uses it
	var build_sl: int = game_data.get("build", {}).get("start_level", 0)
	if build_sl > 0:
		if not game_data.has("settings"):
			game_data["settings"] = {}
		game_data["settings"]["start_level"] = build_sl
	return game_data


# ─── Save / Load ─────────────────────────────────────────────

## Auto-save to the current project path (or the default location).
func _auto_save() -> void:
	if not _dirty:
		return
	var path := _project_path if not _project_path.is_empty() else AUTO_SAVE_PATH
	save_project(path)
	print("AGCK: Auto-saved to ", path)


func save_project(path: String) -> bool:
	var game_data = _collect_all_data()
	var json = JSON.new()
	var json_str = json.stringify(game_data, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("AGCK: Cannot write to " + path)
		return false
	file.store_string(json_str)
	file.close()
	_project_path = path
	_dirty = false
	# Announce on the bus so file browser, command palette MRU, etc. notice.
	preload("res://addons/visual_gasic/vg_asset_bus.gd").get_instance().emit_saved(path, "agck")
	print("AGCK: Project saved to ", path)
	return true


## Auto-open a previously built Main.tscn into the VG 2D Editor.
func _auto_open_built_scene(game_data: Dictionary) -> void:
	var settings: Dictionary = game_data.get("settings", {})
	var build_opts: Dictionary = game_data.get("build", {})
	var game_title: String = settings.get("game_title", "AGCKGame")
	var safe_name: String = game_title.replace(" ", "_").replace("/", "_").replace("\\", "_")
	if safe_name.is_empty():
		safe_name = "AGCKGame"
	var output_dir: String = build_opts.get("output_path", "res://build/")
	if not output_dir.ends_with("/"):
		output_dir += "/"
	output_dir += safe_name + "/"
	var main_tscn := output_dir + "Main.tscn"
	if not FileAccess.file_exists(main_tscn):
		print("AGCK: No previous build found at ", main_tscn)
		return
	print("AGCK: Auto-opening built scene: ", main_tscn)
	if _host_plugin:
		var editor_2d = _host_plugin.get("_vg_2d_editor")
		if editor_2d and editor_2d.has_method("load_scene"):
			editor_2d.load_scene(main_tscn)
			print("AGCK: Loaded Main.tscn into 2D Editor (background pre-load)")

func load_project(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("AGCK: Cannot read " + path)
		return false
	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("AGCK: JSON parse error in " + path)
		return false
	var game_data = json.data
	if not game_data is Dictionary:
		push_error("AGCK: Invalid project data in " + path)
		return false

	# Editor indices: 0=Levels, 1=Actors, 2=Sounds, 3=Shaders, 4=Settings, 5=Build
	if _editors.size() > 4 and _editors[4] and game_data.has("settings"):
		_editors[4].set_data(game_data["settings"])
	if _editors.size() > 1 and _editors[1] and game_data.has("actors"):
		_editors[1].set_data(game_data["actors"])
	if _editors.size() > 2 and _editors[2] and game_data.has("sounds"):
		_editors[2].set_data(game_data["sounds"])
	if _editors.size() > 3 and _editors[3] and game_data.has("shaders"):
		_editors[3].set_data(game_data["shaders"])
	if _editors.size() > 0 and _editors[0] and game_data.has("levels"):
		_editors[0].set_data(game_data["levels"])
	if _editors.size() > 5 and _editors[5] and game_data.has("build"):
		_editors[5].set_data(game_data["build"])

	# Restore tile library (custom edits, new tiles)
	if _tile_lib and game_data.has("tile_library") and _tile_lib.has_method("set_data"):
		_tile_lib.set_data(game_data["tile_library"])
	# Sync pixel-art render sizes from settings → tile library (settings is
	# the source of truth; tile_library mirrors them for editor/runtime use).
	if _tile_lib and _editors.size() > 4 and _editors[4]:
		var s: Dictionary = _editors[4].game_data
		_tile_lib.tile_render_size = int(s.get("tile_size", _tile_lib.tile_render_size))
		_tile_lib.actor_frame_size = int(s.get("actor_frame_size", _tile_lib.actor_frame_size))
	# Refresh editors with tile library
	if _editors.size() > 0 and _editors[0] and _editors[0].has_method("refresh_all"):
		_editors[0].refresh_all()
	if _editors.size() > 1 and _editors[1] and _editors[1].has_method("refresh_all"):
		_editors[1].refresh_all()

	_project_path = path
	_dirty = false
	_sync_actor_names()
	_sync_start_level_count()
	# Announce open + set context. AGCK is a project-level provider, so
	# its "asset" *is* the .agck project file.
	preload("res://addons/visual_gasic/vg_asset_bus.gd").get_instance().emit_opened(path, "agck")
	preload("res://addons/visual_gasic/vg_context_broker.gd").get_instance().set_current_asset(path, "agck")
	print("AGCK: Project loaded from ", path)

	# Auto-open previously built Main.tscn into the VG 2D Editor
	_auto_open_built_scene(game_data)

	return true


# ─── VGPluginRegistry contract ──────────────────────────────
## Called by VGPluginRegistry.open_asset() when a .agck file is opened.
## Activates the AGCK view and loads the project. Returns true on success.
func open_asset(path: String) -> bool:
	if not load_project(path):
		return false
	activate()
	return true
