@tool
extends AcceptDialog
class_name VGFirstRunDialog
## First-run welcome / project-type picker + optional plugin chooser.
##
## Two-step wizard shown the very first time VisualGasic opens a project
## that contains no `.vg`, `.frm`, or `.vgform` files AND has no
## `vg/default_mode` set.
##
## Step 1 — project type:
##   📝 Empty Code Project   — code editor first; Form Designer disabled
##   🎨 Form Application     — Form Designer first (legacy VB6-style flow)
##   🎮 AGCK Game            — code editor + AGCK plugin pre-enabled
##
## Step 2 — optional tools:
##   Checkboxes for each discovered plugin with smart defaults per type.
##
## Cancel / Esc is treated as "Empty Code Project, no extras" so a stray
## Esc doesn't leave the project in a half-configured state.
##
## On confirm the dialog writes:
##   - vg/default_mode = "code" | "forms"
##   - vg/form_designer_enabled = true | false
##   - vg/first_run_completed = true
##   …and emits project_type_chosen(kind, plugins_to_enable, plugins_to_disable).

## kind = "code" | "forms" | "agck"
## plugins_to_enable = Array of plugin folder names that should be enabled
## plugins_to_disable = Array of plugin folder names that should be disabled
signal project_type_chosen(kind: String, plugins_to_enable: Array, plugins_to_disable: Array)

const _TYPES := [
	{
		"kind": "code",
		"emoji": "📝",
		"title": "Empty Code Project",
		"blurb": "Start with a blank module in the code editor.\nBest for utilities, CLI tools, libraries, and most games.",
	},
	{
		"kind": "forms",
		"emoji": "🎨",
		"title": "Form Application",
		"blurb": "VB6-style: open the Form Designer with a blank Form1.\nBest for desktop GUI apps with buttons, labels, and dialogs.",
	},
	{
		"kind": "agck",
		"emoji": "🎮",
		"title": "AGCK Game Project",
		"blurb": "Code-first project with AGCK plugin available.\nOpen the AGCK panel to pick a game template.",
	},
]

## Plugin metadata used in Step 2.
## "id" must match the folder name under addons/visual_gasic/plugins/.
## "defaults" lists the project kinds for which the checkbox is pre-ticked.
const _PLUGINS := [
	{
		"id": "working_nodes",
		"emoji": "🔗",
		"name": "Working Nodes",
		"blurb": "Trigger graph + Blender-style math nodes with smart wires.",
		"defaults": ["code", "agck"],
	},
	{
		"id": "agck",
		"emoji": "🎮",
		"name": "AGCK",
		"blurb": "Arcade Game Construction Kit — no-code arcade game builder.",
		"defaults": ["agck"],
	},
	{
		"id": "vgsfx",
		"emoji": "🔊",
		"name": "VG SFX",
		"blurb": "Retro sound-effect generator (bfxr-style) — export WAV.",
		"defaults": ["agck"],
	},
	{
		"id": "vgmusic",
		"emoji": "🎵",
		"name": "VG Music",
		"blurb": "Built-in music composer (Bosca Ceoil Blue port).",
		"defaults": [],
	},
	{
		"id": "vgaiart",
		"emoji": "🖼",
		"name": "VG AI Art",
		"blurb": "Generate sprites & icons from text prompts (free AI services).",
		"defaults": [],
	},
	{
		"id": "vg3d",
		"emoji": "🧊",
		"name": "VG 3D",
		"blurb": "Voxel-based 3D level editor preview (technology preview).",
		"defaults": [],
	},
	{
		"id": "web_publish",
		"emoji": "🌐",
		"name": "Web Publish",
		"blurb": "Publish forms and AGCK games to the web.",
		"defaults": ["forms"],
	},
]

# ─── Internal state ──────────────────────────────────────────────────────────
var _chosen_kind: String = "code"
var _step1_panel: VBoxContainer = null
var _step2_panel: VBoxContainer = null
var _step2_heading: Label = null
var _checkboxes: Dictionary = {}   # plugin_id → CheckBox


func _init() -> void:
	title = "Welcome to VisualGasic"
	dialog_hide_on_ok = true
	dialog_close_on_escape = true
	min_size = Vector2(600, 340)
	exclusive = false
	# Hide the default OK button — we drive everything ourselves.
	get_ok_button().visible = false


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	_build_step1(root)
	_build_step2(root)

	_step2_panel.visible = false


# ─── Step 1 ──────────────────────────────────────────────────────────────────

func _build_step1(root: VBoxContainer) -> void:
	_step1_panel = VBoxContainer.new()
	_step1_panel.add_theme_constant_override("separation", 10)
	root.add_child(_step1_panel)

	var heading := Label.new()
	heading.text = "What kind of project is this?"
	heading.add_theme_font_size_override("font_size", 17)
	_step1_panel.add_child(heading)

	var sub := Label.new()
	sub.text = "Pick a starting point — you can change this later in Project Settings."
	sub.add_theme_color_override("font_color", Color(0.72, 0.72, 0.76))
	_step1_panel.add_child(sub)

	_step1_panel.add_child(HSeparator.new())

	for entry in _TYPES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_step1_panel.add_child(row)

		var btn := Button.new()
		btn.text = "%s  %s" % [entry["emoji"], entry["title"]]
		btn.custom_minimum_size = Vector2(210, 60)
		btn.pressed.connect(_on_type_pressed.bind(entry["kind"]))
		row.add_child(btn)

		var blurb := Label.new()
		blurb.text = entry["blurb"]
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		blurb.add_theme_color_override("font_color", Color(0.83, 0.83, 0.87))
		row.add_child(blurb)


# ─── Step 2 ──────────────────────────────────────────────────────────────────

func _build_step2(root: VBoxContainer) -> void:
	_step2_panel = VBoxContainer.new()
	_step2_panel.add_theme_constant_override("separation", 8)
	root.add_child(_step2_panel)

	_step2_heading = Label.new()
	_step2_heading.text = "Optional tools for your project:"
	_step2_heading.add_theme_font_size_override("font_size", 17)
	_step2_panel.add_child(_step2_heading)

	var sub2 := Label.new()
	sub2.text = "Tick the tools you want. You can toggle them anytime via ⚙ Plugin Settings."
	sub2.add_theme_color_override("font_color", Color(0.72, 0.72, 0.76))
	_step2_panel.add_child(sub2)

	_step2_panel.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 2)
	_step2_panel.add_child(grid)

	# Split plugins into two columns so all 7 fit without extra height.
	var left_plugins: Array = []
	var right_plugins: Array = []
	for i in _PLUGINS.size():
		if i < int(ceil(_PLUGINS.size() / 2.0)):
			left_plugins.append(_PLUGINS[i])
		else:
			right_plugins.append(_PLUGINS[i])

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 2)
	grid.add_child(left_col)
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 2)
	grid.add_child(right_col)

	for plug in left_plugins:
		var cb := CheckBox.new()
		cb.text = "%s  %s" % [plug["emoji"], plug["name"]]
		cb.tooltip_text = plug["blurb"]
		_checkboxes[plug["id"]] = cb
		left_col.add_child(cb)
	for plug in right_plugins:
		var cb := CheckBox.new()
		cb.text = "%s  %s" % [plug["emoji"], plug["name"]]
		cb.tooltip_text = plug["blurb"]
		_checkboxes[plug["id"]] = cb
		right_col.add_child(cb)

	_step2_panel.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_step2_panel.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.pressed.connect(_on_back_pressed)
	btn_row.add_child(back_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(spacer)

	var start_btn := Button.new()
	start_btn.text = "Start project! →"
	start_btn.pressed.connect(_on_start_pressed)
	btn_row.add_child(start_btn)


# ─── Navigation ──────────────────────────────────────────────────────────────

func _on_type_pressed(kind: String) -> void:
	_chosen_kind = kind
	# Update plugin defaults for this project type.
	for plug in _PLUGINS:
		var cb: CheckBox = _checkboxes.get(plug["id"])
		if cb:
			cb.button_pressed = kind in plug["defaults"]
	# Update Step-2 heading.
	var type_names := {"code": "Code", "forms": "Form Application", "agck": "AGCK Game"}
	_step2_heading.text = "Optional tools for your %s project:" % type_names.get(kind, "project")
	# Swap panels.
	_step1_panel.visible = false
	_step2_panel.visible = true
	# Resize to fit Step 2.
	size = Vector2i(640, 340)


func _on_back_pressed() -> void:
	_step2_panel.visible = false
	_step1_panel.visible = true
	size = Vector2i(600, 340)


func _on_start_pressed() -> void:
	var plugins_on: Array = []
	var plugins_off: Array = []
	for plug in _PLUGINS:
		var cb: CheckBox = _checkboxes.get(plug["id"])
		if cb:
			if cb.button_pressed:
				plugins_on.append(plug["id"])
			else:
				plugins_off.append(plug["id"])
	project_type_chosen.emit(_chosen_kind, plugins_on, plugins_off)
	hide()
	queue_free()


## Convenience: write the user's choice to ProjectSettings and save.
## Also writes plugin.cfg enabled=true for each requested plugin so the
## setting persists across editor restarts (the live activation is handled
## by the host plugin via set_plugin_enabled on the plugin manager).
static func apply_choice(kind: String, plugins_to_enable: Array = [], plugins_to_disable: Array = []) -> void:
	match kind:
		"code", "agck":
			ProjectSettings.set_setting("vg/default_mode", "code")
			ProjectSettings.set_setting("vg/form_designer_enabled", false)
		"forms":
			ProjectSettings.set_setting("vg/default_mode", "forms")
			ProjectSettings.set_setting("vg/form_designer_enabled", true)
		_:
			ProjectSettings.set_setting("vg/default_mode", "code")
			ProjectSettings.set_setting("vg/form_designer_enabled", false)
	ProjectSettings.set_setting("vg/first_run_completed", true)
	var err := ProjectSettings.save()
	if err != OK:
		push_warning("VGFirstRunDialog: ProjectSettings.save() returned " + str(err))
	# Persist plugin enabled/disabled flags so they survive a restart even if
	# live activation below fails (plugin manager not yet ready, etc.).
	const PLUGINS_DIR := "res://addons/visual_gasic/plugins/"
	for pid in plugins_to_enable:
		var cfg_path: String = PLUGINS_DIR + str(pid) + "/plugin.cfg"
		if not FileAccess.file_exists(cfg_path):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(cfg_path) == OK:
			cfg.set_value("plugin", "enabled", true)
			cfg.save(cfg_path)
	for pid in plugins_to_disable:
		var cfg_path: String = PLUGINS_DIR + str(pid) + "/plugin.cfg"
		if not FileAccess.file_exists(cfg_path):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(cfg_path) == OK:
			cfg.set_value("plugin", "enabled", false)
			cfg.save(cfg_path)
