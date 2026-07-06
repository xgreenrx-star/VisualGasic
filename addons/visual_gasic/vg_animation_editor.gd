# vg_animation_editor.gd
# VB6-style Animation Sequences editor for managing AnimationPlayer animations.
# Lists animations on selected nodes, allows playback control and import from .glb.
@tool
extends AcceptDialog

# VB6 theme palette
const VB6_PANEL_BG       = Color(0.941, 0.929, 0.910)
const VB6_TEXT           = Color(0.0, 0.0, 0.0)
const VB6_LIST_BG        = Color(1.0, 1.0, 1.0)
const VB6_BTN_FACE       = Color("#D4D0C8")
const VB6_ACTIVE_TITLE   = Color(0.0, 0.0, 0.5)

# UI references
var _anim_list: ItemList
var _track_tree: Tree
var _play_btn: Button
var _pause_btn: Button
var _stop_btn: Button
var _loop_check: CheckButton
var _speed_spin: SpinBox
var _time_slider: HSlider
var _time_label: Label
var _add_anim_btn: Button
var _remove_anim_btn: Button
var _rename_edit: LineEdit
var _import_btn: Button
var _import_dialog: FileDialog
var _add_key_btn: Button
var _new_anim_dialog: AcceptDialog

# State
var _target_node: Node = null
var _anim_player: AnimationPlayer = null
var _selected_anim: String = ""
var _is_playing: bool = false

func _init():
	title = "Animation Sequences"
	size = Vector2i(800, 520)
	unresizable = false
	ok_button_text = "Close"
	dialog_hide_on_ok = true

	var main_hbox = HBoxContainer.new()
	main_hbox.custom_minimum_size = Vector2(760, 430)
	main_hbox.add_theme_constant_override("separation", 8)
	add_child(main_hbox)

	# ── LEFT PANEL: Animation list ──
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 0.3
	main_hbox.add_child(left_vbox)

	var list_label = Label.new()
	list_label.text = "Animations:"
	left_vbox.add_child(list_label)

	_anim_list = ItemList.new()
	_anim_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_anim_list.item_selected.connect(_on_anim_selected)
	left_vbox.add_child(_anim_list)

	# Action buttons
	var btn_row1 = HBoxContainer.new()
	btn_row1.add_theme_constant_override("separation", 4)
	left_vbox.add_child(btn_row1)

	_add_anim_btn = Button.new()
	_add_anim_btn.text = "➕ New"
	_add_anim_btn.tooltip_text = "Create new animation"
	_add_anim_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_anim_btn.pressed.connect(_on_new_animation)
	btn_row1.add_child(_add_anim_btn)

	_remove_anim_btn = Button.new()
	_remove_anim_btn.text = "🗑 Delete"
	_remove_anim_btn.tooltip_text = "Delete selected animation"
	_remove_anim_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_remove_anim_btn.pressed.connect(_on_remove_animation)
	btn_row1.add_child(_remove_anim_btn)

	_import_btn = Button.new()
	_import_btn.text = "📦 Import..."
	_import_btn.tooltip_text = "Import animations from a .glb/.gltf file"
	_import_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_import_btn.pressed.connect(_on_import_animations)
	left_vbox.add_child(_import_btn)

	# ── RIGHT PANEL: Tracks + Timeline ──
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.7
	main_hbox.add_child(right_vbox)

	# Playback controls
	var playback_row = HBoxContainer.new()
	playback_row.add_theme_constant_override("separation", 4)
	right_vbox.add_child(playback_row)

	_play_btn = Button.new()
	_play_btn.text = "▶ Play"
	_play_btn.tooltip_text = "Play animation"
	_play_btn.pressed.connect(_on_play)
	playback_row.add_child(_play_btn)

	_pause_btn = Button.new()
	_pause_btn.text = "⏸ Pause"
	_pause_btn.tooltip_text = "Pause animation"
	_pause_btn.pressed.connect(_on_pause)
	playback_row.add_child(_pause_btn)

	_stop_btn = Button.new()
	_stop_btn.text = "⏹ Stop"
	_stop_btn.tooltip_text = "Stop and reset animation"
	_stop_btn.pressed.connect(_on_stop)
	playback_row.add_child(_stop_btn)

	playback_row.add_child(VSeparator.new())

	_loop_check = CheckButton.new()
	_loop_check.text = "Loop"
	_loop_check.button_pressed = true
	_loop_check.toggled.connect(_on_loop_toggled)
	playback_row.add_child(_loop_check)

	playback_row.add_child(VSeparator.new())

	var speed_label = Label.new()
	speed_label.text = "Speed:"
	playback_row.add_child(speed_label)

	_speed_spin = SpinBox.new()
	_speed_spin.min_value = 0.1
	_speed_spin.max_value = 5.0
	_speed_spin.step = 0.1
	_speed_spin.value = 1.0
	_speed_spin.custom_minimum_size.x = 70
	playback_row.add_child(_speed_spin)

	# Timeline slider
	var time_row = HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 4)
	right_vbox.add_child(time_row)

	_time_label = Label.new()
	_time_label.text = "0.00 / 0.00s"
	_time_label.custom_minimum_size.x = 100
	time_row.add_child(_time_label)

	_time_slider = HSlider.new()
	_time_slider.min_value = 0.0
	_time_slider.max_value = 1.0
	_time_slider.step = 0.01
	_time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_slider.value_changed.connect(_on_time_seek)
	time_row.add_child(_time_slider)

	# Track tree
	var tracks_label = Label.new()
	tracks_label.text = "Tracks:"
	right_vbox.add_child(tracks_label)

	_track_tree = Tree.new()
	_track_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track_tree.columns = 3
	_track_tree.set_column_title(0, "Track Path")
	_track_tree.set_column_title(1, "Type")
	_track_tree.set_column_title(2, "Keys")
	_track_tree.set_column_titles_visible(true)
	_track_tree.set_column_expand(0, true)
	_track_tree.set_column_expand(1, false)
	_track_tree.set_column_custom_minimum_width(1, 100)
	_track_tree.set_column_expand(2, false)
	_track_tree.set_column_custom_minimum_width(2, 60)
	right_vbox.add_child(_track_tree)

	# Add keyframe button
	var key_row = HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 4)
	right_vbox.add_child(key_row)

	_add_key_btn = Button.new()
	_add_key_btn.text = "🔑 Add Keyframe at Current Time"
	_add_key_btn.tooltip_text = "Insert a position/rotation/scale keyframe for the selected track"
	_add_key_btn.pressed.connect(_on_add_keyframe)
	key_row.add_child(_add_key_btn)

	# New animation name dialog
	_new_anim_dialog = AcceptDialog.new()
	_new_anim_dialog.title = "New Animation"
	_new_anim_dialog.size = Vector2i(350, 130)
	_rename_edit = LineEdit.new()
	_rename_edit.placeholder_text = "Animation name..."
	_rename_edit.custom_minimum_size = Vector2(300, 0)
	_new_anim_dialog.add_child(_rename_edit)
	_new_anim_dialog.confirmed.connect(_on_new_anim_confirmed)
	add_child(_new_anim_dialog)

	# Import dialog
	_import_dialog = FileDialog.new()
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.title = "Import Animations"
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.filters = PackedStringArray([
		"*.glb ; GLTF Binary",
		"*.gltf ; GLTF Text",
	])
	_import_dialog.size = Vector2i(700, 500)
	_import_dialog.file_selected.connect(_on_import_file_selected)
	add_child(_import_dialog)

	confirmed.connect(func(): queue_free())

func _ready():
	theme = _build_vb6_dialog_theme()

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

## Set the target node — we search it and its children for AnimationPlayer.
func set_target(node: Node) -> void:
	_target_node = node
	_anim_player = null
	_selected_anim = ""

	if node is AnimationPlayer:
		_anim_player = node
	else:
		# Search children for AnimationPlayer
		_anim_player = _find_animation_player(node)

	if not _anim_player:
		# Create one automatically
		_anim_player = AnimationPlayer.new()
		_anim_player.name = "AnimationPlayer"
		node.add_child(_anim_player)
		if Engine.is_editor_hint():
			_anim_player.owner = node.owner if node.owner else node

	_refresh_anim_list()

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found:
			return found
	return null

# ─────────────────────────────────────────────────────────────────────────────
# ANIMATION LIST
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_anim_list() -> void:
	_anim_list.clear()
	if not is_instance_valid(_anim_player):
		return

	var anim_names := _anim_player.get_animation_list()
	for anim_name in anim_names:
		if anim_name == "RESET":
			continue  # Skip the auto-generated RESET animation
		_anim_list.add_item(anim_name)

	if _anim_list.item_count > 0:
		_anim_list.select(0)
		_on_anim_selected(0)

func _on_anim_selected(index: int) -> void:
	if index < 0 or not is_instance_valid(_anim_player):
		return
	_selected_anim = _anim_list.get_item_text(index)
	_refresh_tracks()

	var anim := _anim_player.get_animation(_selected_anim)
	if anim:
		_time_slider.max_value = anim.length
		_time_label.text = "0.00 / %.2fs" % anim.length
		_loop_check.button_pressed = (anim.loop_mode != Animation.LOOP_NONE)

# ─────────────────────────────────────────────────────────────────────────────
# TRACK DISPLAY
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_tracks() -> void:
	_track_tree.clear()
	if not is_instance_valid(_anim_player) or _selected_anim.is_empty():
		return

	var anim := _anim_player.get_animation(_selected_anim)
	if not anim:
		return

	var root_item := _track_tree.create_item()

	for i in range(anim.get_track_count()):
		var track_path := anim.track_get_path(i)
		var track_type := anim.track_get_type(i)
		var key_count := anim.track_get_key_count(i)

		var type_name := "Unknown"
		match track_type:
			Animation.TYPE_VALUE: type_name = "Value"
			Animation.TYPE_POSITION_3D: type_name = "Position"
			Animation.TYPE_ROTATION_3D: type_name = "Rotation"
			Animation.TYPE_SCALE_3D: type_name = "Scale"
			Animation.TYPE_BLEND_SHAPE: type_name = "BlendShape"
			Animation.TYPE_METHOD: type_name = "Method"
			Animation.TYPE_BEZIER: type_name = "Bezier"
			Animation.TYPE_AUDIO: type_name = "Audio"
			Animation.TYPE_ANIMATION: type_name = "Animation"

		var item := _track_tree.create_item(root_item)
		item.set_text(0, str(track_path))
		item.set_text(1, type_name)
		item.set_text(2, str(key_count))
		item.set_metadata(0, i)  # Store track index

# ─────────────────────────────────────────────────────────────────────────────
# PLAYBACK CONTROLS
# ─────────────────────────────────────────────────────────────────────────────
func _on_play() -> void:
	if not is_instance_valid(_anim_player) or _selected_anim.is_empty():
		return
	_anim_player.speed_scale = _speed_spin.value
	_anim_player.play(_selected_anim)
	_is_playing = true

func _on_pause() -> void:
	if not is_instance_valid(_anim_player):
		return
	_anim_player.pause()
	_is_playing = false

func _on_stop() -> void:
	if not is_instance_valid(_anim_player):
		return
	_anim_player.stop()
	_is_playing = false
	_time_slider.value = 0.0

func _on_loop_toggled(pressed: bool) -> void:
	if not is_instance_valid(_anim_player) or _selected_anim.is_empty():
		return
	var anim := _anim_player.get_animation(_selected_anim)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if pressed else Animation.LOOP_NONE

func _on_time_seek(value: float) -> void:
	if not is_instance_valid(_anim_player) or _selected_anim.is_empty():
		return
	_anim_player.seek(value, true)
	var anim := _anim_player.get_animation(_selected_anim)
	if anim:
		_time_label.text = "%.2f / %.2fs" % [value, anim.length]

func _process(delta: float) -> void:
	if _is_playing and is_instance_valid(_anim_player) and _anim_player.is_playing():
		var pos := _anim_player.current_animation_position
		_time_slider.set_value_no_signal(pos)
		var anim := _anim_player.get_animation(_selected_anim)
		if anim:
			_time_label.text = "%.2f / %.2fs" % [pos, anim.length]

# ─────────────────────────────────────────────────────────────────────────────
# ANIMATION CRUD
# ─────────────────────────────────────────────────────────────────────────────
func _on_new_animation() -> void:
	_rename_edit.text = "NewAnimation"
	_new_anim_dialog.popup_centered()

func _on_new_anim_confirmed() -> void:
	if not is_instance_valid(_anim_player):
		return
	var anim_name := _rename_edit.text.strip_edges()
	if anim_name.is_empty():
		return

	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_NONE

	var lib := _anim_player.get_animation_library("")
	if not lib:
		lib = AnimationLibrary.new()
		_anim_player.add_animation_library("", lib)
	lib.add_animation(anim_name, anim)

	_refresh_anim_list()
	# Select the new animation
	for i in range(_anim_list.item_count):
		if _anim_list.get_item_text(i) == anim_name:
			_anim_list.select(i)
			_on_anim_selected(i)
			break

func _on_remove_animation() -> void:
	if not is_instance_valid(_anim_player) or _selected_anim.is_empty():
		return

	var lib := _anim_player.get_animation_library("")
	if lib and lib.has_animation(_selected_anim):
		lib.remove_animation(_selected_anim)

	_selected_anim = ""
	_refresh_anim_list()

func _on_add_keyframe() -> void:
	if not is_instance_valid(_anim_player) or _selected_anim.is_empty():
		return
	if not is_instance_valid(_target_node) or not _target_node is Node3D:
		return

	var anim := _anim_player.get_animation(_selected_anim)
	if not anim:
		return

	var time := _time_slider.value
	var node3d: Node3D = _target_node

	# Ensure position, rotation, and scale tracks exist
	var node_path := _anim_player.get_node(_anim_player.root_node).get_path_to(node3d)

	_ensure_track_and_add_key(anim, node_path, Animation.TYPE_POSITION_3D, time, node3d.position)
	_ensure_track_and_add_key(anim, node_path, Animation.TYPE_ROTATION_3D, time, node3d.quaternion)
	_ensure_track_and_add_key(anim, node_path, Animation.TYPE_SCALE_3D, time, node3d.scale)

	_refresh_tracks()
	print("[VGAnim] Added keyframe at %.2f for %s" % [time, str(node_path)])

func _ensure_track_and_add_key(anim: Animation, path: NodePath, type: int, time: float, value: Variant) -> void:
	# Find existing track
	var track_idx := -1
	for i in range(anim.get_track_count()):
		if anim.track_get_path(i) == path and anim.track_get_type(i) == type:
			track_idx = i
			break

	# Create track if not found
	if track_idx < 0:
		track_idx = anim.add_track(type)
		anim.track_set_path(track_idx, path)

	anim.track_insert_key(track_idx, time, value)

# ─────────────────────────────────────────────────────────────────────────────
# IMPORT ANIMATIONS FROM .GLB
# ─────────────────────────────────────────────────────────────────────────────
func _on_import_animations() -> void:
	_import_dialog.popup_centered()

func _on_import_file_selected(path: String) -> void:
	if path.is_empty() or not is_instance_valid(_anim_player):
		return

	# Copy file to project first if outside res://
	var project_root := ProjectSettings.globalize_path("res://")
	var filename := path.get_file()
	var dest_res := "res://models/" + filename

	if not path.begins_with(project_root):
		if not DirAccess.dir_exists_absolute("res://models"):
			DirAccess.make_dir_recursive_absolute("res://models")
		DirAccess.copy_absolute(path, ProjectSettings.globalize_path(dest_res))

		if Engine.is_editor_hint():
			var efs := EditorInterface.get_resource_filesystem()
			if efs:
				efs.scan()
				await efs.filesystem_changed
				await get_tree().create_timer(0.5).timeout
	else:
		dest_res = path.replace(project_root, "res://")

	# Load the scene and extract animations
	var scene := ResourceLoader.load(dest_res) as PackedScene
	if not scene:
		push_error("[VGAnim] Could not load: " + dest_res)
		return

	var temp_instance := scene.instantiate()
	var source_player := _find_animation_player(temp_instance)

	if not source_player:
		push_warning("[VGAnim] No AnimationPlayer found in imported scene")
		temp_instance.queue_free()
		return

	# Copy animations into our player
	var lib := _anim_player.get_animation_library("")
	if not lib:
		lib = AnimationLibrary.new()
		_anim_player.add_animation_library("", lib)

	var imported_count := 0
	for anim_name in source_player.get_animation_list():
		if anim_name == "RESET":
			continue
		var anim := source_player.get_animation(anim_name)
		if anim:
			var copy := anim.duplicate()
			lib.add_animation(anim_name, copy)
			imported_count += 1

	temp_instance.queue_free()
	_refresh_anim_list()
	print("[VGAnim] Imported %d animations from %s" % [imported_count, filename])

# ─────────────────────────────────────────────────────────────────────────────
# THEME
# ─────────────────────────────────────────────────────────────────────────────
func _build_vb6_dialog_theme() -> Theme:
	var t = Theme.new()

	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = VB6_PANEL_BG
	panel_sb.set_content_margin_all(8)
	t.set_stylebox("panel", "AcceptDialog", panel_sb)
	t.set_stylebox("panel", "PanelContainer", panel_sb)

	t.set_color("font_color", "Label", VB6_TEXT)
	t.set_color("font_color", "Button", VB6_TEXT)

	var list_sb = StyleBoxFlat.new()
	list_sb.bg_color = VB6_LIST_BG
	list_sb.border_color = Color(0.5, 0.5, 0.5)
	list_sb.set_border_width_all(1)
	t.set_stylebox("panel", "ItemList", list_sb)
	t.set_color("font_color", "ItemList", VB6_TEXT)

	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = VB6_BTN_FACE
	btn_sb.border_color = Color(0.5, 0.5, 0.5)
	btn_sb.set_border_width_all(1)
	btn_sb.set_corner_radius_all(2)
	btn_sb.set_content_margin_all(4)
	t.set_stylebox("normal", "Button", btn_sb)

	return t
