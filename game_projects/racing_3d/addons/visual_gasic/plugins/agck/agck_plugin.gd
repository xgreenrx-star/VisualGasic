@tool
## AGCK Plugin — Arcade Game Construction Kit
##
## Main plugin file.  Creates a TabContainer with 5 sub-editors:
##   1. Game Settings  (Environment Editor)
##   2. Actors          (Actor Editor)
##   3. Sounds          (Sound Editor)
##   4. Levels          (Level Editor)
##   5. Build           (Game Builder)
##
## Extends vg_plugin_base.gd and is discovered via plugin.cfg.
extends "res://addons/visual_gasic/vg_plugin_base.gd"

const AGCK_DIR = "res://addons/visual_gasic/plugins/agck/"

var _tab_container: TabContainer = null
var _game_settings = null   # agck_game_settings.gd
var _actor_editor = null    # agck_actor_editor.gd
var _sound_editor = null    # agck_sound_editor.gd
var _level_editor = null    # agck_level_editor.gd
var _game_builder = null    # agck_game_builder.gd

# ─── Project Data ────────────────────────────────────────────
var _project_path: String = ""  # path to .agck save file
var _dirty: bool = false


# ─── Plugin Identity ─────────────────────────────────────────

func get_plugin_name() -> String:
	return "AGCK"

func get_toolbar_icon() -> String:
	return "🕹️"

func get_toolbar_color() -> Color:
	return Color(0.85, 0.55, 0.2)

func get_toolbar_tooltip() -> String:
	return "Arcade Game Construction Kit"


# ─── Build UI ────────────────────────────────────────────────

func _build_ui() -> void:
	# The base class created _view (an HSplitContainer).
	# We place a styled TabContainer filling the entire view.

	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.tab_alignment = TabBar.ALIGNMENT_CENTER
	_tab_container.add_theme_font_size_override("font_size", 13)

	# Style the tab bar
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.16, 0.19)
	panel_style.content_margin_left = 4
	panel_style.content_margin_right = 4
	panel_style.content_margin_top = 4
	panel_style.content_margin_bottom = 4
	_tab_container.add_theme_stylebox_override("panel", panel_style)

	# 1) Game Settings
	var GameSettingsScript = load(AGCK_DIR + "agck_game_settings.gd")
	if GameSettingsScript:
		_game_settings = GameSettingsScript.new()
		_game_settings.name = "⚙️ Game Settings"
		_game_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_game_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tab_container.add_child(_game_settings)
		if _game_settings.has_signal("settings_changed"):
			_game_settings.settings_changed.connect(_on_data_changed)

	# 2) Actor Editor
	var ActorEditorScript = load(AGCK_DIR + "agck_actor_editor.gd")
	if ActorEditorScript:
		_actor_editor = ActorEditorScript.new()
		_actor_editor.name = "👾 Actors"
		_actor_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_actor_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tab_container.add_child(_actor_editor)
		if _actor_editor.has_signal("actor_changed"):
			_actor_editor.actor_changed.connect(_on_actor_changed)

	# 3) Sound Editor
	var SoundEditorScript = load(AGCK_DIR + "agck_sound_editor.gd")
	if SoundEditorScript:
		_sound_editor = SoundEditorScript.new()
		_sound_editor.name = "🔊 Sounds"
		_sound_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sound_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tab_container.add_child(_sound_editor)

	# 4) Level Editor
	var LevelEditorScript = load(AGCK_DIR + "agck_level_editor.gd")
	if LevelEditorScript:
		_level_editor = LevelEditorScript.new()
		_level_editor.name = "🗺️ Levels"
		_level_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_level_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tab_container.add_child(_level_editor)
		# Sync actor names into level editor
		_sync_actor_names()

	# 5) Game Builder
	var GameBuilderScript = load(AGCK_DIR + "agck_game_builder.gd")
	if GameBuilderScript:
		_game_builder = GameBuilderScript.new()
		_game_builder.name = "🏗️ Build"
		_game_builder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_game_builder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tab_container.add_child(_game_builder)
		if _game_builder.has_signal("build_requested"):
			_game_builder.build_requested.connect(_on_build_requested)

	_view.add_child(_tab_container)


# ─── Lifecycle ───────────────────────────────────────────────

func _on_activated() -> void:
	print("AGCK: Plugin activated")

func _on_deactivated() -> void:
	print("AGCK: Plugin deactivated")

func _on_cleanup() -> void:
	_game_settings = null
	_actor_editor = null
	_sound_editor = null
	_level_editor = null
	_game_builder = null
	_tab_container = null


# ─── Data Flow ───────────────────────────────────────────────

func _on_data_changed(_key = null, _value = null) -> void:
	_dirty = true

func _on_actor_changed(_actor_id = null) -> void:
	_dirty = true
	_sync_actor_names()

func _sync_actor_names() -> void:
	if _actor_editor and _level_editor:
		var actors_data = _actor_editor.get_data()
		var names: Array = []
		for a in actors_data:
			names.append(a.get("name", "Actor"))
		if _level_editor.has_method("set_actor_names"):
			_level_editor.set_actor_names(names)

func _on_build_requested() -> void:
	print("AGCK: Build requested — assembling game data...")
	# Collect all data from sub-editors
	var game_data: Dictionary = {}
	if _game_settings:
		game_data["settings"] = _game_settings.get_data()
	if _actor_editor:
		game_data["actors"] = _actor_editor.get_data()
	if _sound_editor:
		game_data["sounds"] = _sound_editor.get_data()
	if _level_editor:
		game_data["levels"] = _level_editor.get_data()
	if _game_builder:
		game_data["build"] = _game_builder.get_data()
	# TODO: Pass game_data to the actual scene generator
	print("AGCK: Game data collected — ", game_data.size(), " sections")


# ─── Save / Load ─────────────────────────────────────────────

func save_project(path: String) -> bool:
	var game_data: Dictionary = {}
	if _game_settings:
		game_data["settings"] = _game_settings.get_data()
	if _actor_editor:
		game_data["actors"] = _actor_editor.get_data()
	if _sound_editor:
		game_data["sounds"] = _sound_editor.get_data()
	if _level_editor:
		game_data["levels"] = _level_editor.get_data()
	if _game_builder:
		game_data["build"] = _game_builder.get_data()

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
	print("AGCK: Project saved to ", path)
	return true


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

	if _game_settings and game_data.has("settings"):
		_game_settings.set_data(game_data["settings"])
	if _actor_editor and game_data.has("actors"):
		_actor_editor.set_data(game_data["actors"])
	if _sound_editor and game_data.has("sounds"):
		_sound_editor.set_data(game_data["sounds"])
	if _level_editor and game_data.has("levels"):
		_level_editor.set_data(game_data["levels"])
	if _game_builder and game_data.has("build"):
		_game_builder.set_data(game_data["build"])

	_project_path = path
	_dirty = false
	_sync_actor_names()
	print("AGCK: Project loaded from ", path)
	return true
