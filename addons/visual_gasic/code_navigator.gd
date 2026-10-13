@tool
extends VBoxContainer
## Code Navigator — VB6-style Object/Event dropdowns above the code editor.
## In VB6, this bar sits directly above the code window with two dropdowns:
##   [Object ▼]  |  [Event ▼]
## Selecting an object populates the event list; selecting an event navigates
## to (or creates) the corresponding Sub handler in the .vg script.

const VGComboBox = preload("res://addons/visual_gasic/vg_combo_box.gd")
const VGCausalChain = preload("res://addons/visual_gasic/vg_causal_chain.gd")
const VGEvidenceView = preload("res://addons/visual_gasic/vg_evidence_view.gd")
const SpriteResolver = preload("res://addons/visual_gasic/vg_sprite_data_resolver.gd")
const SpriteUx = preload("res://addons/visual_gasic/vg_sprite_data_ux.gd")
const VectorResolver = preload("res://addons/visual_gasic/vg_vector_data_resolver.gd")

var editor_plugin  # EditorPlugin (untyped to allow test mocking)
var object_list  # VGComboBox — left dropdown (Object)
var event_list   # VGComboBox — right dropdown (Event/Procedure)
## Override .vg path pushed by the host when working inside the VG IDE's
## embedded code editor (where the file isn't open in Godot's script editor).
var _override_vg_path: String = ""
var _last_known_vg_path: String = ""  # Cached — survives transient null from get_current_script()
## Cache of Control children from the last time get_edited_scene_root() was non-null.
## Used when the scene root becomes temporarily inaccessible (e.g. Godot Script editor view).
var _cached_controls: Array = []  # Each element: {name: String, class_name: String}
## Pending selection to restore after the next refresh_objects() call.
## Set by select_object_and_event() so deferred refreshes don't clobber it.
var _pending_obj: String = ""
var _pending_event: String = ""

func set_override_vg_path(path: String) -> void:
	_override_vg_path = path

## Pre-populate the control cache directly from the caller (same pattern as VG IDE).
## Called from _poll_for_inject before set_main_screen_editor("Script") so the cache
## is always valid even when get_edited_scene_root() returns null afterward.
func set_cached_controls_from_scene(scene_root: Node) -> void:
	if not is_instance_valid(scene_root):
		return
	_cached_controls.clear()
	for child in scene_root.get_children():
		if child is Control:
			_cached_controls.append({"name": child.name, "class_name": child.get_class()})
var refresh_button: Button
var chain_button: Button
var _separator: VSeparator
var _nav_bar: HBoxContainer
var _debugger_plugin: EditorDebuggerPlugin = null
var _evidence_toggle: Button
var _evidence_panel: VBoxContainer
var _evidence_record: CheckButton
var _evidence_watch: Button
var _evidence_header: Label
var _evidence_banner: Label
var _evidence_columns: HBoxContainer
var _evidence_left: VBoxContainer
var _evidence_right: VBoxContainer
var _evidence_prompt: Label
var _evidence_view_model = VGEvidenceView.new()
var _evidence_view: Dictionary = {}
var _evidence_text := ""
var _evidence_path := ""
var _evidence_line := 0
var _evidence_run: Dictionary = {}
var _evidence_run_state := "none"
var _evidence_recording_override := -1
var _evidence_poll_timer: Timer
var _evidence_caret_timer: Timer
var _evidence_caret_key := ""
var _evidence_record_sync := false
var _current_break_file: String = ""
var _current_break_line: int = 0
var _change_toggle: Button
var _change_panel: VBoxContainer
var _change_body: RichTextLabel
var _change_pos := -1
var _change_queue: Array = []
var _change_results: Array = []
var _change_running := ""
var _change_timer: Timer
var _change_confirm: ConfirmationDialog
var _change_text := ""
var _change_card: Dictionary = {}
var _change_before_blob := ""
var _change_prompt: Label
var _change_summary: LineEdit
var _change_expect: CheckBox
var _change_keep: Button
var _change_section_row: HBoxContainer
var _change_section_label: Label
var _change_section_next: Button
var _change_page := 0
var _change_required: Array = []
var _change_reviewed: Array = []
var _change_seen_id := ""
var _change_file := ""

# Standard VB6 Events
const EVENTS_COMMON = ["Click", "DblClick", "MouseDown", "MouseUp", "MouseMove", "KeyDown", "KeyUp", "KeyPress"]
const EVENTS_BUTTON = ["Click", "MouseDown", "MouseUp", "MouseMove", "KeyDown", "KeyUp", "KeyPress"]
const EVENTS_TEXT = ["Change", "Click", "MouseDown", "MouseUp", "MouseMove", "KeyDown", "KeyUp", "KeyPress"]
const EVENTS_TIMER = ["Timer"]
const EVENTS_SCROLL = ["Change", "Scroll"]
const EVENTS_FORM = ["Load", "Unload", "Click", "MouseDown", "MouseUp", "MouseMove", "KeyDown", "KeyUp", "KeyPress", "Resize"]

# Dim colour for unimplemented event handlers (VB6 shows implemented in bold)
const COLOR_DIM := Color(0.45, 0.45, 0.5)
const COLOR_IMPORTED_PROC := Color(0.52, 0.78, 1.0)
const COLOR_SPRITE := Color(0.95, 0.78, 0.35)
const COLOR_VECTOR := Color(0.45, 0.82, 0.95)

func _init():
	name = "Code Navigator"
	size_flags_horizontal = SIZE_EXPAND_FILL
	_nav_bar = HBoxContainer.new()
	_nav_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	_nav_bar.custom_minimum_size = Vector2(0, 30)
	add_child(_nav_bar)
	
	# --- Object Dropdown (left half) ---
	object_list = VGComboBox.new()
	object_list.size_flags_horizontal = SIZE_EXPAND_FILL
	object_list.custom_minimum_size.x = 120
	object_list.item_selected.connect(_on_object_selected)
	_nav_bar.add_child(object_list)
	
	# --- Vertical Separator (VB6-style divider between the two dropdowns) ---
	_separator = VSeparator.new()
	_nav_bar.add_child(_separator)
	
	# --- Event Dropdown (right half) ---
	event_list = VGComboBox.new()
	event_list.size_flags_horizontal = SIZE_EXPAND_FILL
	event_list.custom_minimum_size.x = 120
	event_list.item_selected.connect(_on_event_selected)
	_nav_bar.add_child(event_list)
	
	# --- Refresh Button (compact icon button) ---
	refresh_button = Button.new()
	refresh_button.tooltip_text = "Refresh Object List"
	refresh_button.custom_minimum_size = Vector2(28, 28)
	refresh_button.pressed.connect(refresh_objects)
	_set_refresh_icon()
	_nav_bar.add_child(refresh_button)
	
	# --- Causal Chain Button (compact icon button) ---
	chain_button = Button.new()
	chain_button.tooltip_text = "Show Causal Chain"
	chain_button.custom_minimum_size = Vector2(28, 28)
	chain_button.pressed.connect(_show_causal_chain)
	_set_chain_icon()
	_nav_bar.add_child(chain_button)
	_build_evidence_section()
	_build_change_section()

func _notification(what):
	if what == NOTIFICATION_THEME_CHANGED:
		_set_refresh_icon.call_deferred()
		_set_chain_icon.call_deferred()
	elif what == NOTIFICATION_READY:
		_set_refresh_icon()
		_set_chain_icon()

func _set_refresh_icon():
	if not refresh_button:
		return
	var icon = refresh_button.get_theme_icon("Reload", "EditorIcons")
	if icon:
		refresh_button.icon = icon
	else:
		refresh_button.icon = null

func _set_chain_icon():
	if not chain_button:
		return
	var icon = chain_button.get_theme_icon("DebugAdapters", "EditorIcons")
	if icon:
		chain_button.icon = icon
	else:
		chain_button.icon = null

func setup(plugin: EditorPlugin):
	editor_plugin = plugin
	
	# Try to get the debugger plugin from the main plugin
	if plugin.has_method("get") and plugin.get("debugger_plugin"):
		set_debugger_plugin(plugin.debugger_plugin)
	
	refresh_objects()
	_ensure_evidence_timers()

func set_debugger_plugin(debugger: EditorDebuggerPlugin) -> void:
	"""Connect to debugger plugin to receive break notifications."""
	if _debugger_plugin:
		# Disconnect old signals
		if _debugger_plugin.has_signal("debug_break_hit") and _debugger_plugin.debug_break_hit.is_connected(_on_debug_break_hit):
			_debugger_plugin.debug_break_hit.disconnect(_on_debug_break_hit)
		if _debugger_plugin.has_signal("evidence_data_received") and _debugger_plugin.evidence_data_received.is_connected(_on_evidence_data):
			_debugger_plugin.evidence_data_received.disconnect(_on_evidence_data)
		if _debugger_plugin.has_signal("debug_session_stopped") and _debugger_plugin.debug_session_stopped.is_connected(_on_evidence_session_stopped):
			_debugger_plugin.debug_session_stopped.disconnect(_on_evidence_session_stopped)
	
	_debugger_plugin = debugger
	if _debugger_plugin and _debugger_plugin.has_signal("debug_break_hit"):
		_debugger_plugin.debug_break_hit.connect(_on_debug_break_hit)
	if _debugger_plugin and _debugger_plugin.has_signal("evidence_data_received") and not _debugger_plugin.evidence_data_received.is_connected(_on_evidence_data):
		_debugger_plugin.evidence_data_received.connect(_on_evidence_data)
	if _debugger_plugin and _debugger_plugin.has_signal("debug_session_stopped") and not _debugger_plugin.debug_session_stopped.is_connected(_on_evidence_session_stopped):
		_debugger_plugin.debug_session_stopped.connect(_on_evidence_session_stopped)

func _on_debug_break_hit(file: String, line: int) -> void:
	"""Called when a breakpoint or step is hit - navigate to the line."""
	_current_break_file = file
	_current_break_line = line
	# For .vg files, the main plugin handles navigation to the embedded code editor
	# via its own debug_break_hit handler. Only navigate here for non-.vg scripts.
	if not file.ends_with(".vg"):
		navigate_to_line(file, line)

func navigate_to_line(file_path: String, line: int) -> void:
	"""Navigate the script editor to a specific file and line."""
	if not editor_plugin:
		return
	
	if file_path.is_empty() or line <= 0:
		return
	
	# Load the script resource
	if not ResourceLoader.exists(file_path):
		return
	
	var script = load(file_path)
	if not script:
		return
	var ed_int = editor_plugin.get_editor_interface()
	
	# Switch to Script editor main screen first
	ed_int.set_main_screen_editor("Script")
	
	# Open script in editor and navigate to line
	ed_int.edit_script(script, line, 0)
	
	# Center the viewport on that line after a short delay
	call_deferred("_center_on_line", line)

func _center_on_line(line: int) -> void:
	"""Center the code editor viewport on the specified line."""
	if not editor_plugin:
		return
	
	var script_editor = editor_plugin.get_editor_interface().get_script_editor()
	if not script_editor:
		return
	
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return
	
	var code_edit = current_editor.get_base_editor() as CodeEdit
	if code_edit:
		# Line numbers in CodeEdit are 0-based
		code_edit.set_caret_line(line - 1)
		code_edit.set_caret_column(0)
		code_edit.center_viewport_to_caret()
		code_edit.grab_focus()

func refresh_objects():
	if not editor_plugin: 
		# print("CodeNavigator: No editor_plugin set.")
		return

	# If the currently open script is a .gd file, populate with its functions
	# and return early — .gd files don't have a VB6 object model.
	var script_editor = editor_plugin.get_editor_interface().get_script_editor()
	if script_editor:
		var current_script = script_editor.get_current_script()
		if current_script and current_script.resource_path.ends_with(".gd"):
			object_list.clear()
			event_list.clear()
			object_list.add_item("(General)")
			object_list.set_item_metadata(0, "(General)")
			object_list.select(0)
			_populate_gd_script_funcs({"type": "gd_script", "script": current_script})
			return
	
	# Remember selection
	var current_node_name = ""
	if object_list.item_count > 0 and object_list.selected >= 0:
		var meta = object_list.get_item_metadata(object_list.selected)
		if meta is Node and is_instance_valid(meta):
			current_node_name = meta.name
		elif meta is String:
			current_node_name = meta  # "(General)"
		elif meta is Dictionary:
			current_node_name = meta.get("name", "")  # cached_control or gd_script node name
	
	object_list.clear()

	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	# During a main-screen switch the root can be null OR valid-but-mid-teardown,
	# where get_children() returns Nil (this crashed the tree-walk below). In BOTH
	# cases rebuild from the cache that set_cached_controls_from_scene() populated
	# while the scene was still live — the same way the VG IDE feeds control names.
	var live_children = null
	if is_instance_valid(root):
		live_children = root.get_children()
	if live_children == null:
		# get_edited_scene_root() returns null in Script view and in the VG IDE.
		# If we have a cached node list from a previous 2D-view refresh, rebuild
		# the object model from that cache so dropdowns stay meaningful.
		if _cached_controls.size() > 0:
			# Add (General) first
			var gen_idx: int = object_list.item_count
			object_list.add_item("(General)")
			object_list.set_item_metadata(gen_idx, "(General)")
			# Add cached controls — format the label the same as the live tree walk
			# ("Button1 (CommandButton)") using the VB6 dialect name.
			var sorted_cache: Array = _cached_controls.duplicate()
			sorted_cache.sort_custom(func(a, b):
				return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
			)
			for entry in sorted_cache:
				var oidx: int = object_list.item_count
				object_list.add_item(VGIntelliSense.format_node_label(entry["name"], entry["class_name"]))
				object_list.set_item_metadata(oidx, {"type": "cached_control", "name": entry["name"], "class_name": entry["class_name"]})
			# Restore selection
			var sel_restored: bool = false
			if current_node_name != "":
				for i in object_list.item_count:
					var meta = object_list.get_item_metadata(i)
					var match_name: String = ""
					if meta is String:
						match_name = meta
					elif meta is Dictionary:
						match_name = meta.get("name", "")
					if match_name == current_node_name:
						object_list.select(i)
						_on_object_selected(i)
						sel_restored = true
						break
			if not sel_restored:
				object_list.select(0)
				_on_object_selected(0)
			_add_import_modules_section()
			_add_sprites_section()
			_add_vectors_section()
			_apply_pending_selection()
			return
		# No cache — fall back to (General)-only standalone module view
		var gen_only: int = object_list.item_count
		object_list.add_item("(General)")
		object_list.set_item_metadata(gen_only, "(General)")
		object_list.select(gen_only)
		event_list.clear()
		event_list.add_item("(Declarations)")
		event_list.set_item_metadata(0, {"type": "declarations"})
		var procedures := _parse_procedures(_get_current_vg_text())
		for proc in procedures:
			var display: String = proc["name"]
			if proc["kind"].begins_with("Property"):
				display += " [" + proc["kind"] + "]"
			var eidx: int = event_list.item_count
			event_list.add_item(display)
			event_list.set_item_metadata(eidx, {"type": "procedure", "line": proc["line"], "name": proc["name"], "kind": proc["kind"]})
		_append_imported_public_procedures_for_general({})
		_add_sprites_section()
		_add_vectors_section()
		if event_list.item_count > 0:
			event_list.select(0)
		_add_import_modules_section()
		return

	# Add (General) entry — VB6-style module-level declarations
	var general_idx = object_list.item_count
	object_list.add_item("(General)")
	object_list.set_item_metadata(general_idx, "(General)")
	
	# Add Objects — root first (as Form/game root), then filtered children
	_add_node_filtered(root, true)

	# Cache relevant children for when get_edited_scene_root() returns null.
	_cached_controls.clear()
	for child in live_children:
		var s = child.get_script()
		var sp: String = s.resource_path if s else ""
		if sp.ends_with(".vg"):
			continue  # skip VGASIC helper
		var cls: String = child.get_class() if child.get_class() else ""
		if cls.is_empty():
			continue
		if VGIntelliSense.is_relevant_node_class(cls):
			_cached_controls.append({"name": child.name, "class_name": cls})

	# Add Scene Scripts section — nodes with .gd scripts
	var gd_nodes: Array = []
	_collect_gd_script_nodes(root, gd_nodes)
	if gd_nodes.size() > 0:
		gd_nodes.sort_custom(func(a, b): return a.name.to_lower() < b.name.to_lower())
		var sep_idx = object_list.item_count
		object_list.add_item("\u2500\u2500 Scene Scripts \u2500\u2500")
		object_list.set_item_metadata(sep_idx, {"type": "separator"})
		# NOTE: VGComboBox has no set_item_disabled(); the separator is inert anyway
		# because _on_object_selected() returns early for {"type":"separator"}.
		for gd_node in gd_nodes:
			var s = gd_node.get_script()
			var label = gd_node.name + " (" + s.resource_path.get_file() + ")"
			var nidx = object_list.item_count
			object_list.add_item(label)
			object_list.set_item_metadata(nidx, {"type": "gd_script", "node": gd_node, "script": s})

	# Restore Selection
	var found = false
	if current_node_name != "":
		for i in object_list.item_count:
			var meta = object_list.get_item_metadata(i)
			var meta_name = ""
			if meta is String:
				meta_name = meta
			elif meta is Node and is_instance_valid(meta):
				meta_name = meta.name
			elif meta is Dictionary:
				meta_name = meta.get("name", "")
			if meta_name == current_node_name:
				object_list.select(i)
				_on_object_selected(i)
				found = true
				break
	
	# Select Form (Root) by default if nothing selected and nothing found
	if not found and object_list.item_count > 0:
		object_list.select(0)
		_on_object_selected(0)

	# Imported helper modules (VB6 Project Explorer → Modules)
	_add_import_modules_section()
	_add_sprites_section()
	_add_vectors_section()

	# Re-apply any pending programmatic selection (from Wire Event / double-click).
	# This runs AFTER the normal selection-restore so it always wins.
	_apply_pending_selection()

func _add_sprites_section() -> void:
	var vg_text := _get_current_vg_text()
	if vg_text.is_empty():
		return
	var blocks: Array = SpriteResolver.enumerate_blocks(vg_text)
	if blocks.is_empty():
		return
	var idx: int = object_list.item_count
	object_list.add_item("(Sprites)")
	object_list.set_item_metadata(idx, {"type": "sprites", "name": "(Sprites)"})
	object_list.set_item_custom_color(idx, COLOR_SPRITE)


func _add_vectors_section() -> void:
	var vg_text := _get_current_vg_text()
	if vg_text.is_empty():
		return
	var blocks: Array = VectorResolver.enumerate_blocks(vg_text)
	if blocks.is_empty():
		return
	var idx: int = object_list.item_count
	object_list.add_item("(Vectors)")
	object_list.set_item_metadata(idx, {"type": "vectors", "name": "(Vectors)"})
	object_list.set_item_custom_color(idx, COLOR_VECTOR)


func _populate_sprite_events() -> void:
	event_list.clear()
	var vg_text := _get_current_vg_text()
	var blocks: Array = SpriteResolver.enumerate_blocks(vg_text)
	for block in blocks:
		var label := str(block.get("label", ""))
		var label_line: int = int(block.get("label_line", -1))
		var full := SpriteResolver.resolve_at_line(vg_text, label_line)
		var w := int(full.get("w", 0))
		var h := int(full.get("h", 0))
		var pal := SpriteUx.palette_name(int(full.get("palette_id", 0)))
		var display := "%s  %d×%d  %s" % [label, w, h, pal]
		var eidx: int = event_list.item_count
		event_list.add_item(display)
		event_list.set_item_metadata(eidx, {
			"type": "sprite_block",
			"label": label,
			"line": label_line,
			"edit": false,
		})
		event_list.set_item_custom_color(eidx, COLOR_SPRITE)
		var eidx2: int = event_list.item_count
		event_list.add_item("  ✏ Edit %s…" % label)
		event_list.set_item_metadata(eidx2, {
			"type": "sprite_block",
			"label": label,
			"line": label_line,
			"edit": true,
		})
	if event_list.item_count > 0:
		event_list.select(0)


func _populate_vector_events() -> void:
	event_list.clear()
	var vg_text := _get_current_vg_text()
	var blocks: Array = VectorResolver.enumerate_blocks(vg_text)
	for block in blocks:
		var label := str(block.get("label", ""))
		var label_line: int = int(block.get("label_line", -1))
		var full := VectorResolver.resolve_at_line(vg_text, label_line)
		var vw := int(full.get("view_w", 0))
		var vh := int(full.get("view_h", 0))
		var shapes: Array = full.get("shapes", []) as Array
		var display := "%s  %d×%d  %d shape(s)" % [label, vw, vh, shapes.size()]
		var eidx: int = event_list.item_count
		event_list.add_item(display)
		event_list.set_item_metadata(eidx, {
			"type": "vector_block",
			"label": label,
			"line": label_line,
			"edit": false,
		})
		event_list.set_item_custom_color(eidx, COLOR_VECTOR)
		var eidx2: int = event_list.item_count
		event_list.add_item("  ✏ Edit %s…" % label)
		event_list.set_item_metadata(eidx2, {
			"type": "vector_block",
			"label": label,
			"line": label_line,
			"edit": true,
		})
	if event_list.item_count > 0:
		event_list.select(0)


func _add_import_modules_section() -> void:
	var vg_path := _get_current_vg_path()
	var vg_text := _get_current_vg_text()
	if vg_text.is_empty():
		return
	var imports: Array = VGGoToDefinition.parse_imports(vg_text, vg_path)
	if imports.is_empty():
		return
	# Skip if already added (refresh_objects clears object_list first)
	var sep_idx: int = object_list.item_count
	object_list.add_item("\u2500\u2500 Modules \u2500\u2500")
	object_list.set_item_metadata(sep_idx, {"type": "separator"})
	var sorted_imports: Array = imports.duplicate()
	sorted_imports.sort_custom(func(a, b):
		return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
	)
	for mod_info in sorted_imports:
		var mod_name := str(mod_info.get("name", ""))
		if mod_name.is_empty():
			continue
		var label := mod_name
		var mod_path := str(mod_info.get("path", ""))
		if not mod_path.is_empty():
			label += " (" + mod_path.get_file() + ")"
		var midx: int = object_list.item_count
		object_list.add_item(label)
		object_list.set_item_metadata(midx, {
			"type": "imported_module",
			"name": mod_name,
			"path": mod_path,
			"public_subs": mod_info.get("public_subs", []),
			"private_subs": mod_info.get("private_subs", []),
		})

func _add_node_filtered(node: Node, is_root: bool) -> void:
	## Add a node to the Object dropdown if it is relevant.
	## Root is always shown (as Form / game root). Children are filtered:
	## skip VGASIC script hosts, skip pure layout containers.
	if not node: return

	# Detect VGASIC script-host nodes: their script resource path ends with .vg
	var script = node.get_script()
	var script_path: String = script.resource_path if script else ""
	var has_vg_script: bool = script_path.ends_with(".vg")

	# For non-root children: skip the VGASIC helper node itself
	# (it hosts the script but is not a UI control or game object)
	if not is_root and has_vg_script:
		return

	# For non-root children: skip irrelevant layout-only classes
	if not is_root and not has_vg_script:
		if not VGIntelliSense.is_relevant_node_class(node.get_class()):
			return

	var label = VGIntelliSense.format_node_label(node.name, node.get_class())
	var idx = object_list.item_count
	object_list.add_item(label)
	object_list.set_item_metadata(idx, node)

	if not is_root:
		return
	# Walk children (one level deep) — sorted for large forms
	var children: Array = []
	for i in node.get_child_count():
		var child = node.get_child(i)
		if _should_list_object_child(child):
			children.append(child)
	children.sort_custom(func(a, b): return a.name.to_lower() < b.name.to_lower())
	for child in children:
		_add_node_filtered(child, false)

func _should_list_object_child(node: Node) -> bool:
	if not node:
		return false
	var script = node.get_script()
	var script_path: String = script.resource_path if script else ""
	if script_path.ends_with(".vg"):
		return false
	return VGIntelliSense.is_relevant_node_class(node.get_class())

func _append_imported_public_procedures_for_general(skip_names: Dictionary) -> void:
	var vg_path := _get_current_vg_path()
	var vg_text := _get_current_vg_text()
	if vg_text.is_empty():
		return
	var imports: Array = VGGoToDefinition.parse_imports(vg_text, vg_path)
	var merged: Array = []
	for mod_info in imports:
		var mod_name := str(mod_info.get("name", ""))
		var mod_path := str(mod_info.get("path", ""))
		for entry in mod_info.get("public_subs", []):
			var sname := str(entry.get("name", ""))
			if sname.is_empty():
				continue
			if skip_names.has(sname.to_lower()):
				continue
			merged.append({
				"display": sname + "  [" + mod_name + "]",
				"path": mod_path,
				"line": int(entry.get("line", 0)),
				"name": sname,
			})
	merged.sort_custom(func(a, b): return a["name"].to_lower() < b["name"].to_lower())
	for item in merged:
		var eidx: int = event_list.item_count
		event_list.add_item(item["display"])
		event_list.set_item_metadata(eidx, {
			"type": "imported_procedure",
			"path": item["path"],
			"line": item["line"],
			"name": item["name"],
			"visibility": "public",
		})
		event_list.set_item_custom_color(eidx, COLOR_IMPORTED_PROC)

func _get_current_vg_path() -> String:
	"""Get the .vg file path for the current scene."""
	if not editor_plugin:
		return ""
	# Host-pushed override (set when a .vg file is loaded in the embedded editor).
	if _override_vg_path != "" and FileAccess.file_exists(_override_vg_path):
		_last_known_vg_path = _override_vg_path
		return _override_vg_path
	# First try: get the currently edited script directly from the script editor.
	var script_editor = editor_plugin.get_editor_interface().get_script_editor()
	if script_editor:
		var current_script = script_editor.get_current_script()
		if current_script and current_script.resource_path.ends_with(".vg"):
			_last_known_vg_path = current_script.resource_path
			return _last_known_vg_path
	# Fallback: use cached path from the last time get_current_script() succeeded.
	# This handles transient null during screen transitions and scene reloads.
	if _last_known_vg_path != "" and FileAccess.file_exists(_last_known_vg_path):
		return _last_known_vg_path
	# Last resort: derive from scene path (form-designer context, no script tab).
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		return ""
	var scene_path = root.scene_file_path
	if scene_path.is_empty():
		return ""
	var bas_path = scene_path.get_basename() + ".vg"
	if FileAccess.file_exists(bas_path):
		return bas_path
	return ""

func _get_current_vg_text() -> String:
	"""Get the text content of the current .vg file from the editor buffer."""
	if not editor_plugin:
		return ""
	var script_editor = editor_plugin.get_editor_interface().get_script_editor()
	if script_editor:
		var current_editor = script_editor.get_current_editor()
		if current_editor:
			var code_edit = current_editor.get_base_editor()
			# Guard: code_edit.text can be empty on the first timer tick before
			# Godot finishes populating the CodeEdit buffer (timing issue).
			# Fall through to the disk fallback in that case.
			if code_edit and not code_edit.text.is_empty():
				return code_edit.text
	# Fallback: read from disk — used by VG IDE (file not in Godot's script
	# editor) and by Godot's editor when CodeEdit hasn't loaded text yet.
	var path = _get_current_vg_path()
	if path != "" and FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	return ""

func _parse_procedures(text: String) -> Array:
	"""Parse all Sub/Function/Property definitions from a .vg file.
	Returns an array of dictionaries: {name, kind, line, full_sig}
	   kind: 'Sub', 'Function', 'Property Get', 'Property Let', 'Property Set'
	"""
	var procedures: Array = []
	if text.is_empty():
		return procedures
	var lines = text.split("\n")
	# Regex patterns for procedure headers
	# Matches: [Public|Private] Sub|Function|Property Get|Let|Set  Name(...)
	for i in lines.size():
		var stripped = lines[i].strip_edges()
		var lower = stripped.to_lower()
		# Skip empty/comment lines
		if stripped.is_empty() or stripped.begins_with("'") or stripped.begins_with("REM "):
			continue
		# Strip access modifier
		var sig = stripped
		var sig_lower = lower
		if sig_lower.begins_with("public "):
			sig = sig.substr(7)
			sig_lower = sig_lower.substr(7)
		elif sig_lower.begins_with("private "):
			sig = sig.substr(8)
			sig_lower = sig_lower.substr(8)
		# Match procedure kinds
		var kind = ""
		var proc_name = ""
		if sig_lower.begins_with("sub "):
			kind = "Sub"
			proc_name = _extract_proc_name(sig.substr(4))
		elif sig_lower.begins_with("function "):
			kind = "Function"
			proc_name = _extract_proc_name(sig.substr(9))
		elif sig_lower.begins_with("property get "):
			kind = "Property Get"
			proc_name = _extract_proc_name(sig.substr(13))
		elif sig_lower.begins_with("property let "):
			kind = "Property Let"
			proc_name = _extract_proc_name(sig.substr(13))
		elif sig_lower.begins_with("property set "):
			kind = "Property Set"
			proc_name = _extract_proc_name(sig.substr(13))
		if kind != "" and proc_name != "":
			procedures.append({
				"name": proc_name,
				"kind": kind,
				"line": i,
				"full_sig": stripped
			})
	# Sort alphabetically by name (case-insensitive), then by kind
	procedures.sort_custom(func(a, b):
		var na = a["name"].to_lower()
		var nb = b["name"].to_lower()
		if na != nb:
			return na < nb
		return a["kind"] < b["kind"]
	)
	return procedures

func _parse_gd_functions(text: String) -> Array:
	"""Parse all func definitions from a .gd file.
	Returns [{name, line}] sorted by line order.
	"""
	var funcs: Array = []
	var regex = RegEx.new()
	regex.compile("^(?:static\\s+)?func\\s+(\\w+)\\s*\\(")
	var lines = text.split("\n")
	for i in lines.size():
		var result = regex.search(lines[i])
		if result:
			funcs.append({"name": result.get_string(1), "line": i})
	return funcs

func _collect_gd_script_nodes(node: Node, result: Array) -> void:
	"""Recursively collect nodes that have a .gd script attached."""
	if not node:
		return
	var script = node.get_script()
	if script and script.resource_path.ends_with(".gd"):
		result.append(node)
	for i in node.get_child_count():
		_collect_gd_script_nodes(node.get_child(i), result)

func _populate_gd_script_funcs(meta: Dictionary) -> void:
	"""Populate event_list with func definitions from a .gd script."""
	event_list.clear()
	var script = meta.get("script", null)
	if not script:
		return
	var path: String = script.resource_path
	if not FileAccess.file_exists(path):
		return
	var text = FileAccess.get_file_as_string(path)
	var funcs = _parse_gd_functions(text)
	if funcs.is_empty():
		var oidx = event_list.item_count
		event_list.add_item("[Open Script]")
		event_list.set_item_metadata(oidx, {"type": "gd_open", "path": path})
	else:
		for f in funcs:
			var eidx = event_list.item_count
			event_list.add_item(f["name"])
			event_list.set_item_metadata(eidx, {"type": "gd_func", "line": f["line"], "path": path})
	if event_list.item_count > 0:
		event_list.select(0)

func _extract_proc_name(after_keyword: String) -> String:
	"""Extract the procedure name from text after 'Sub '/'Function '/etc."""
	var s = after_keyword.strip_edges()
	# Name ends at '(' or space or end of string
	var end = s.length()
	for j in s.length():
		if s[j] == "(" or s[j] == " " or s[j] == "\t":
			end = j
			break
	var name = s.substr(0, end).strip_edges()
	if name.is_empty():
		return ""
	return name

## Selects the given object and event in the dropdowns programmatically.
## Called after Wire Event / double-click wires a new Sub so the dropdowns
## reflect the currently open procedure.
func select_object_and_event(obj_name: String, event_name: String) -> void:
	# Store as pending so any subsequent deferred refresh_objects() restores it.
	_pending_obj = obj_name
	_pending_event = event_name
	_apply_pending_selection()

func _apply_pending_selection() -> void:
	if _pending_obj.is_empty():
		return
	var obj_name := _pending_obj
	var event_name := _pending_event
	# Find the object in the object_list
	var obj_found := false
	for i in object_list.item_count:
		var meta = object_list.get_item_metadata(i)
		var name_match := false
		if meta is Node and is_instance_valid(meta) and meta.name == obj_name:
			name_match = true
		elif meta is String and meta == obj_name:
			name_match = true
		elif meta is Dictionary and meta.get("type") == "cached_control" and meta.get("name") == obj_name:
			name_match = true
		if name_match:
			object_list.select(i)
			_on_object_selected(i)
			obj_found = true
			break
	if not obj_found:
		return  # List not built yet — keep pending so next refresh tries again
	# Now find the event in the event_list
	for i in event_list.item_count:
		var emeta = event_list.get_item_metadata(i)
		var event_match := false
		if emeta is Dictionary:
			event_match = (emeta.get("event", "") == event_name or emeta.get("name", "") == obj_name + "_" + event_name)
		elif emeta is String:
			event_match = (emeta == event_name)
		if event_match:
			event_list.select(i)
			break
	# Clear pending only after successful selection
	_pending_obj = ""
	_pending_event = ""

func _on_object_selected(idx):
	event_list.clear()
	var meta = object_list.get_item_metadata(idx)

	if meta is Dictionary and meta.get("type", "") == "imported_module":
		_populate_import_module_events(meta)
		return

	if meta is Dictionary and meta.get("type", "") == "sprites":
		_populate_sprite_events()
		return

	if meta is Dictionary and meta.get("type", "") == "vectors":
		_populate_vector_events()
		return
	
	# Handle (General) selection — VB6 shows (Declarations) + standalone procedures only.
	# Control event handlers (Button1_Click, etc.) belong under their own object entry.
	if meta is String and meta == "(General)":
		event_list.add_item("(Declarations)")
		event_list.set_item_metadata(0, {"type": "declarations"})

		# Collect all known object names from the Object dropdown so we can exclude
		# procedures of the form <ObjectName>_<EventName>.
		var known_objects: Array = []
		for i in object_list.item_count:
			var ometa = object_list.get_item_metadata(i)
			var oname: String = ""
			if ometa is Node and is_instance_valid(ometa):
				oname = ometa.name
			elif ometa is Dictionary:
				oname = ometa.get("name", "")
			if not oname.is_empty() and oname != "(General)":
				known_objects.append(oname.to_lower())

		# Parse the .vg file — show only procedures that are NOT control event handlers
		var text = _get_current_vg_text()
		var procedures = _parse_procedures(text)
		var local_names: Dictionary = {}
		for proc in procedures:
			# Check: does the name start with "<KnownObject>_"?
			var pname_lower: String = proc["name"].to_lower()
			var is_event_handler: bool = false
			for oname in known_objects:
				if pname_lower.begins_with(oname + "_"):
					is_event_handler = true
					break
			if is_event_handler:
				continue
			local_names[pname_lower] = true
			var display = proc["name"]
			if proc["kind"].begins_with("Property"):
				display += " [" + proc["kind"] + "]"
			var eidx = event_list.item_count
			event_list.add_item(display)
			event_list.set_item_metadata(eidx, {"type": "procedure", "line": proc["line"], "name": proc["name"], "kind": proc["kind"]})
		_append_imported_public_procedures_for_general(local_names)
		if event_list.item_count > 0:
			event_list.select(0)
		return
	
	# Handle scene-script entries (nodes with .gd scripts) and cached controls
	if meta is Dictionary:
		var dtype = meta.get("type", "")
		if dtype == "separator":
			return
		elif dtype == "gd_script":
			_populate_gd_script_funcs(meta)
			return
		elif dtype == "cached_control":
			# Rebuild event list from class name (node not in tree, use cached class)
			var cls: String = meta.get("class_name", "")
			var events: Array = EVENTS_COMMON
			if cls in ["Button", "CheckButton", "LinkButton", "ToolButton", "CheckBox", "OptionButton"]:
				events = EVENTS_BUTTON
			elif cls in ["LineEdit"]:
				events = EVENTS_TEXT
			elif cls in ["TextEdit"]:
				events = EVENTS_TEXT
			elif cls in ["HScrollBar", "VScrollBar", "HSlider", "VSlider"]:
				events = EVENTS_SCROLL
			elif cls == "Timer":
				events = EVENTS_TIMER
			var text: String = _get_current_vg_text()
			var ctrl_name: String = meta.get("name", "")
			for evt in events:
				var eidx: int = event_list.item_count
				var has_handler: bool = text.contains("Sub " + ctrl_name + "_" + evt)
				event_list.add_item(evt)
				event_list.set_item_metadata(eidx, {"type": "event", "event": evt, "has_handler": has_handler})
			for i in event_list.item_count:
				var emeta = event_list.get_item_metadata(i)
				if emeta and emeta.has("has_handler") and not emeta["has_handler"]:
					event_list.set_item_custom_color(i, COLOR_DIM)
			if event_list.item_count > 0:
				event_list.select(0)
			return

	if not is_instance_valid(meta):
		# Object might have been deleted
		return

	var node = meta as Node
	if not node: return

	# Determine the VB6 event list for this node.
	# Root Control → "Form" events; game nodes + UI controls → VGIntelliSense lookup.
	var godot_class := node.get_class()
	var lookup_class := godot_class
	var scene_root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if node == scene_root and node is Control:
		lookup_class = "Form"

	var events: Array = VGIntelliSense.get_control_events(lookup_class)

	# Check which handlers already exist in the .vg file (VB6 shows these bold)
	var text = _get_current_vg_text()

	for evt in events:
		var eidx = event_list.item_count
		var handler_name = "Sub " + node.name + "_" + evt
		var has_handler = text.contains(handler_name)
		event_list.add_item(evt)
		event_list.set_item_metadata(eidx, {"type": "event", "event": evt, "has_handler": has_handler})

	# Dim unimplemented events; VB6 shows implemented handlers in bold
	for i in event_list.item_count:
		var emeta = event_list.get_item_metadata(i)
		if emeta and emeta.has("has_handler") and not emeta["has_handler"]:
			event_list.set_item_custom_color(i, COLOR_DIM)

	# Auto-select first event so the textbox is never blank
	if event_list.item_count > 0:
		event_list.select(0)

func _on_event_selected(idx):
	if idx < 0: return
	var obj_idx = object_list.selected
	if obj_idx < 0: return
	
	var event_meta = event_list.get_item_metadata(idx)
	var obj_meta = object_list.get_item_metadata(obj_idx)
	
	# --- Imported module procedure ---
	if obj_meta is Dictionary and obj_meta.get("type", "") == "imported_module":
		if event_meta and event_meta.get("type", "") == "imported_procedure":
			_navigate_to_module_procedure(str(event_meta.get("path", "")), int(event_meta.get("line", 0)))
		return

	# --- Inline *Sprite Data blocks ---
	if obj_meta is Dictionary and obj_meta.get("type", "") == "sprites":
		if event_meta is Dictionary and event_meta.get("type", "") == "sprite_block":
			_navigate_to_line_in_vg(int(event_meta.get("line", 0)))
			if bool(event_meta.get("edit", false)) and editor_plugin \
					and editor_plugin.has_method("_on_sprite_data_edit_requested"):
				var sec := SpriteResolver.resolve_at_line(
					_get_current_vg_text(), int(event_meta.get("line", 0))
				)
				if not sec.is_empty():
					editor_plugin._on_sprite_data_edit_requested(sec)
		return

	# --- Inline *Vector Data blocks ---
	if obj_meta is Dictionary and obj_meta.get("type", "") == "vectors":
		if event_meta is Dictionary and event_meta.get("type", "") == "vector_block":
			_navigate_to_line_in_vg(int(event_meta.get("line", 0)))
			if bool(event_meta.get("edit", false)) and editor_plugin \
					and editor_plugin.has_method("_on_vector_data_edit_requested"):
				var sec := VectorResolver.resolve_at_line(
					_get_current_vg_text(), int(event_meta.get("line", 0))
				)
				if not sec.is_empty():
					editor_plugin._on_vector_data_edit_requested(sec)
		return

	# --- (General) section ---
	if obj_meta is String and obj_meta == "(General)":
		if event_meta and event_meta.has("type"):
			if event_meta["type"] == "declarations":
				_navigate_to_declarations()
				return
			elif event_meta["type"] == "procedure":
				# Navigate directly to the procedure's line
				_navigate_to_line_in_vg(event_meta["line"])
				return
			elif event_meta["type"] == "imported_procedure":
				_navigate_to_module_procedure(str(event_meta.get("path", "")), int(event_meta.get("line", 0)))
				return
		return
	
	# --- GD script func entry ---
	if event_meta is Dictionary:
		var etype = event_meta.get("type", "")
		if etype == "gd_func":
			navigate_to_line(event_meta["path"], event_meta["line"] + 1)
			return
		elif etype == "gd_open":
			var script = load(event_meta["path"])
			if script:
				editor_plugin.get_editor_interface().edit_resource(script)
			return

	# --- Control event handler (live node or cached_control) ---
	var event_name: String = ""
	if event_meta is Dictionary:
		event_name = event_meta.get("event", event_list.get_item_text(idx).strip_edges())
	else:
		event_name = event_list.get_item_text(idx).strip_edges()

	# Cached control — no live node reference; navigate/create via path + name
	if obj_meta is Dictionary and obj_meta.get("type", "") == "cached_control":
		_navigate_to_handler_by_name(obj_meta.get("name", ""), event_name)
		return

	if not is_instance_valid(obj_meta):
		refresh_objects()
		return

	var node = obj_meta as Node
	if not node: return

	_navigate_to_handler(node, event_name)

func _populate_import_module_events(mod_meta: Dictionary) -> void:
	event_list.clear()
	var mod_path := str(mod_meta.get("path", ""))
	if not mod_path.is_empty():
		var open_idx: int = event_list.item_count
		event_list.add_item("(Open Module)")
		event_list.set_item_metadata(open_idx, {
			"type": "imported_procedure",
			"path": mod_path,
			"line": 0,
			"name": "(Open Module)",
		})
	var public_subs: Array = mod_meta.get("public_subs", []).duplicate()
	public_subs.sort_custom(func(a, b):
		return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
	)
	for entry in public_subs:
		var sname := str(entry.get("name", ""))
		if sname.is_empty():
			continue
		var eidx: int = event_list.item_count
		event_list.add_item(sname)
		event_list.set_item_metadata(eidx, {
			"type": "imported_procedure",
			"path": mod_path,
			"line": int(entry.get("line", 0)),
			"name": sname,
			"visibility": "public",
		})
	var private_subs: Array = mod_meta.get("private_subs", []).duplicate()
	private_subs.sort_custom(func(a, b):
		return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
	)
	for entry in private_subs:
		var pname := str(entry.get("name", ""))
		if pname.is_empty():
			continue
		var pidx: int = event_list.item_count
		event_list.add_item(pname + "  [Private]")
		event_list.set_item_metadata(pidx, {
			"type": "imported_procedure",
			"path": mod_path,
			"line": int(entry.get("line", 0)),
			"name": pname,
			"visibility": "private",
		})
		event_list.set_item_custom_color(pidx, COLOR_DIM)
	if event_list.item_count > 0:
		event_list.select(0)


func _navigate_to_module_procedure(mod_path: String, line: int) -> void:
	if mod_path.is_empty() or not editor_plugin:
		return
	if editor_plugin.has_method("open_module_in_embedded_editor"):
		editor_plugin.open_module_in_embedded_editor(mod_path, line)
		return
	navigate_to_line(mod_path, line + 1)


func _navigate_to_line_in_vg(line_number: int):
	"""Navigate to a specific line in the current .vg file."""
	if not editor_plugin:
		return
	var vg_path = _get_current_vg_path()
	if vg_path.is_empty():
		return
	var res = load(vg_path)
	if not res:
		return
	var ed_int = editor_plugin.get_editor_interface()
	ed_int.edit_resource(res)
	# Navigate to line in the editor buffer
	var script_editor = ed_int.get_script_editor()
	if not script_editor:
		return
	var current_editor = script_editor.get_current_editor()
	if not current_editor:
		return
	var code_edit = current_editor.get_base_editor()
	if code_edit:
		code_edit.set_caret_line(line_number)
		code_edit.set_caret_column(0)
		code_edit.center_viewport_to_caret()
		code_edit.grab_focus()

func _navigate_to_declarations():
	"""Navigate to the top of the .vg file (module-level declarations)."""
	if not editor_plugin:
		return
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		return
	var scene_path = root.scene_file_path
	if scene_path.is_empty():
		return
	var bas_path = scene_path.get_basename() + ".vg"
	if not FileAccess.file_exists(bas_path):
		return
	
	# Open and go to the top
	var res = load(bas_path)
	if not res:
		return
	var ed_int = editor_plugin.get_editor_interface()
	ed_int.edit_resource(res)
	
	var script_editor = ed_int.get_script_editor()
	var current_editor = script_editor.get_current_editor()
	if current_editor:
		var code_edit = current_editor.get_base_editor()
		if code_edit:
			# Find the first line that is NOT inside a Sub/Function — i.e. the declarations area
			var text = code_edit.text
			var lines = text.split("\n")
			var target_line = 0
			# Find first non-empty, non-comment line in the declarations area (before first Sub/Function)
			for i in lines.size():
				var stripped = lines[i].strip_edges().to_lower()
				if stripped.begins_with("sub ") or stripped.begins_with("function ") or \
				   stripped.begins_with("private sub") or stripped.begins_with("public sub") or \
				   stripped.begins_with("private function") or stripped.begins_with("public function"):
					break
				target_line = i
			code_edit.set_caret_line(target_line)
			code_edit.set_caret_column(0)
			code_edit.center_viewport_to_caret()
			code_edit.grab_focus()

func _navigate_to_handler_by_name(obj_name: String, event: String) -> void:
	## Navigate/create a handler when we only have the control name (no live node).
	## Used by the cached_control path.
	if obj_name.is_empty() or event.is_empty() or not editor_plugin:
		return
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	var scene_path: String = ""
	if is_instance_valid(root):
		scene_path = root.scene_file_path
	if scene_path.is_empty():
		var vg_path = _get_current_vg_path()
		if not vg_path.is_empty():
			_edit_and_goto(vg_path, "Sub " + obj_name + "_" + event, obj_name, event)
		return
	var bas_path = scene_path.get_basename() + ".vg"
	if not FileAccess.file_exists(bas_path):
		var f = FileAccess.open(bas_path, FileAccess.WRITE)
		if f:
			f.store_string("' Visual Gasic Form Script\nOption Explicit\n\n")
			f.close()
	_edit_and_goto(bas_path, "Sub " + obj_name + "_" + event, obj_name, event)

func _navigate_to_handler(node: Node, event: String):
	if not editor_plugin: return
	
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root: return
	
	# Logic similar to plugin
	var scene_path = root.scene_file_path
	if scene_path.is_empty(): 
		print("Save scene first.")
		return
		
	var bas_path = scene_path.get_basename() + ".vg"
	# Ensure file exists
	if not FileAccess.file_exists(bas_path):
		var f = FileAccess.open(bas_path, FileAccess.WRITE)
		f.store_string("' Visual Gasic Form Script\nOption Explicit\n\n")
		f.close()
	
	# Check content
	var content = FileAccess.get_file_as_string(bas_path)
	var sub_name = "Sub " + node.name + "_" + event
	
	# Open/Edit
	_edit_and_goto(bas_path, sub_name, node.name, event)

func _edit_and_goto(path: String, sub_name: String, obj_name: String, event_name: String):
	# 1. Open in Godot Editor
	if not ResourceLoader.exists(path):
		editor_plugin.get_editor_interface().get_resource_filesystem().scan()
		
	var res = load(path)
	if not res: return
	
	var ed_int = editor_plugin.get_editor_interface()
	ed_int.edit_resource(res)
	
	# 2. Modify Editor Buffer directly to avoid disk reload conflicts
	# This ensures the user sees the code immediately without "Reload from disk?"
	var script_editor = ed_int.get_script_editor()
	var current_editor = script_editor.get_current_editor()
	
	if current_editor:
		var code_edit = current_editor.get_base_editor()
		if code_edit:
			var text = code_edit.text
			
			if text.find(sub_name) == -1:
				# Append new stub — empty body, cursor will land inside it
				var new_code = "\nPrivate " + sub_name + "()\n\nEnd Sub\n"
				code_edit.text += new_code
				text = code_edit.text
			
			# Find line number
			var lines = text.split("\n")
			var line_no = -1
			for i in lines.size():
				if lines[i].strip_edges().begins_with(sub_name):
					line_no = i
					break
			
			if line_no != -1:
				# Place cursor on the blank line inside the Sub body
				var body_line = line_no + 1
				code_edit.set_caret_line(body_line)
				code_edit.set_caret_column(4)
				code_edit.center_viewport_to_caret()
				code_edit.grab_focus()

				# Refresh the event list so the new handler shows bold
				call_deferred("refresh_objects")

## Show the causal-chain report in a popup dialog.
## Triggered by the chain_button or from the main plugin.
func _show_causal_chain() -> void:
	if not editor_plugin:
		return
	
	var vg_text := _get_current_vg_text()
	if vg_text.is_empty():
		# No .vg file open — try to derive from the current scene.
		var root = editor_plugin.get_editor_interface().get_edited_scene_root()
		if not is_instance_valid(root):
			return
		var scene_path: String = root.scene_file_path
		if scene_path.is_empty():
			return
		var bas_path: String = scene_path.get_basename() + ".vg"
		if not FileAccess.file_exists(bas_path):
			return
		vg_text = FileAccess.get_file_as_string(bas_path)
		if vg_text.is_empty():
			return
	
	var chain := VGCausalChain.new()
	var report := chain.generate_chain_report(vg_text)
	
	# Open a dialog + text display
	_show_chain_dialog(report)

## Display the causal-chain report in a resizable dialog with a copy button.
func _show_chain_dialog(report: String) -> void:
	var window := AcceptDialog.new()
	window.title = "Causal Chain — " + _get_current_vg_path().get_file()
	window.dialog_autowrap = true
	window.min_size = Vector2(700, 500)
	window.exclusive = true
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.add_child(vbox)
	
	var label := Label.new()
	label.text = "Call chain for all event handlers in this form:"
	vbox.add_child(label)
	
	var text_edit := TextEdit.new()
	text_edit.text = report
	text_edit.editable = false
	text_edit.scroll_fit_content_height = false
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.deselect()
	vbox.add_child(text_edit)
	
	# Button row: Copy to Clipboard + Close
	var button_row := HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var chain_instance := VGCausalChain.new()  # fresh instance for clipboard access
	var copy_btn := Button.new()
	copy_btn.text = "Copy to Clipboard"
	copy_btn.pressed.connect(func():
		chain_instance.copy_to_clipboard(report)
		copy_btn.text = "Copied!"
		await window.get_tree().create_timer(1.5).timeout
		copy_btn.text = "Copy to Clipboard"
	)
	button_row.add_child(copy_btn)
	
	vbox.add_child(button_row)
	
	# Add to the editor viewport so it shows modally
	if editor_plugin:
		var ed_int: EditorInterface = editor_plugin.get_editor_interface()
		var base: Control = ed_int.get_base_control()
		base.add_child(window)
		window.popup_centered_clamped(Vector2i(750, 550))
		window.visibility_changed.connect(func():
			if not window.visible:
				window.queue_free()
		)
	else:
		window.popup_centered_clamped(Vector2i(750, 550))
		window.queue_free()

## Returns true if a .vg file is available for causal chain analysis.
## Used by the main plugin to enable/disable the toolbar button.
func has_vg_source() -> bool:
	var path := _get_current_vg_path()
	if path.is_empty():
		return false
	return FileAccess.file_exists(path)


func _build_evidence_section() -> void:
	_evidence_toggle = Button.new()
	_evidence_toggle.text = "Behavior evidence"
	_evidence_toggle.toggle_mode = true
	_evidence_toggle.toggled.connect(_on_evidence_toggled)
	_nav_bar.add_child(_evidence_toggle)
	_evidence_panel = VBoxContainer.new()
	_evidence_panel.visible = false
	_evidence_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(_evidence_panel)
	var controls := HBoxContainer.new()
	_evidence_panel.add_child(controls)
	_evidence_record = CheckButton.new()
	_evidence_record.text = "Record runs"
	_evidence_record.toggled.connect(_on_evidence_record_toggled)
	controls.add_child(_evidence_record)
	_evidence_watch = Button.new()
	_evidence_watch.text = "Watch"
	_evidence_watch.pressed.connect(_on_evidence_watch_pressed)
	controls.add_child(_evidence_watch)
	var refresh := Button.new()
	refresh.text = "Refresh"
	refresh.pressed.connect(_on_evidence_refresh_pressed)
	controls.add_child(refresh)
	var clear_button := Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(_on_evidence_clear_pressed)
	controls.add_child(clear_button)
	var copy_button := Button.new()
	copy_button.text = "Copy"
	copy_button.pressed.connect(_on_evidence_copy_pressed)
	controls.add_child(copy_button)
	_evidence_header = Label.new()
	_evidence_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_evidence_panel.add_child(_evidence_header)
	_evidence_banner = Label.new()
	_evidence_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_evidence_panel.add_child(_evidence_banner)
	_evidence_prompt = Label.new()
	_evidence_prompt.text = "Put the caret on a Whenever Section line."
	_evidence_panel.add_child(_evidence_prompt)
	_evidence_columns = HBoxContainer.new()
	_evidence_columns.size_flags_horizontal = SIZE_EXPAND_FILL
	_evidence_panel.add_child(_evidence_columns)
	_evidence_left = VBoxContainer.new()
	_evidence_left.size_flags_horizontal = SIZE_EXPAND_FILL
	_evidence_right = VBoxContainer.new()
	_evidence_right.size_flags_horizontal = SIZE_EXPAND_FILL
	_evidence_columns.add_child(_evidence_left)
	_evidence_columns.add_child(_evidence_right)
	_evidence_columns.visible = false
	_sync_record_checkbox()


func _ensure_evidence_timers() -> void:
	if _evidence_caret_timer == null:
		_evidence_caret_timer = Timer.new()
		_evidence_caret_timer.wait_time = 0.25
		_evidence_caret_timer.one_shot = true
		_evidence_caret_timer.timeout.connect(_on_evidence_caret_timeout)
		add_child(_evidence_caret_timer)
	if _evidence_poll_timer == null:
		_evidence_poll_timer = Timer.new()
		_evidence_poll_timer.wait_time = 1.0
		_evidence_poll_timer.timeout.connect(_on_evidence_poll_timeout)
		add_child(_evidence_poll_timer)


func _on_evidence_toggled(shown: bool) -> void:
	_evidence_panel.visible = shown
	if shown:
		_pull_caret_source()
		_rebuild_evidence()
		if _evidence_caret_timer != null and _evidence_caret_timer.is_stopped():
			_evidence_caret_timer.start()
	elif _evidence_caret_timer != null:
		_evidence_caret_timer.stop()
	_sync_evidence_poll()


func _on_evidence_caret_timeout() -> void:
	if _evidence_panel == null or not _evidence_panel.visible:
		return
	if _pull_caret_source():
		_rebuild_evidence()
	if _evidence_caret_timer != null:
		_evidence_caret_timer.start()


func _pull_caret_source() -> bool:
	if editor_plugin == null:
		return false
	var iface = editor_plugin.get_editor_interface()
	if iface == null:
		return false
	var script_editor = iface.get_script_editor()
	if script_editor == null:
		return false
	var current_editor = script_editor.get_current_editor()
	if current_editor == null:
		return false
	var code_edit := current_editor.get_base_editor() as CodeEdit
	if code_edit == null:
		return false
	var line := code_edit.get_caret_line() + 1
	var text := code_edit.text
	var path := ""
	var current_script = script_editor.get_current_script()
	if current_script:
		path = str(current_script.resource_path)
	var key := "%s\n%d\n%s" % [path, line, text]
	if key == _evidence_caret_key:
		return false
	_evidence_caret_key = key
	_evidence_text = text
	_evidence_line = line
	_evidence_path = path
	return true


func _sync_evidence_poll() -> void:
	if _evidence_poll_timer == null:
		return
	var want := _evidence_panel != null and _evidence_panel.visible and _recording_enabled() and _evidence_session_active()
	if want:
		if _evidence_poll_timer.is_stopped():
			_evidence_poll_timer.start()
	else:
		_evidence_poll_timer.stop()


func _evidence_session_active() -> bool:
	if _debugger_plugin == null or not _debugger_plugin.has_method("is_session_active"):
		return false
	return bool(_debugger_plugin.is_session_active())


func _on_evidence_poll_timeout() -> void:
	if not (_evidence_panel != null and _evidence_panel.visible and _recording_enabled() and _evidence_session_active()):
		_sync_evidence_poll()
		return
	if _debugger_plugin != null and _debugger_plugin.has_method("request_evidence_snapshot"):
		_debugger_plugin.request_evidence_snapshot()


func _on_evidence_data(snapshot: Dictionary) -> void:
	_evidence_run = snapshot.duplicate(true)
	if _debugger_plugin != null and _debugger_plugin.has_method("get_evidence_snapshot"):
		_evidence_run = _debugger_plugin.get_evidence_snapshot()
	if _debugger_plugin != null and _debugger_plugin.has_method("get_evidence_run_state"):
		_evidence_run_state = str(_debugger_plugin.get_evidence_run_state())
	_sync_evidence_poll()
	_rebuild_evidence()


func _on_evidence_session_stopped() -> void:
	if _debugger_plugin != null and _debugger_plugin.has_method("get_evidence_run_state"):
		_evidence_run_state = str(_debugger_plugin.get_evidence_run_state())
	_sync_evidence_poll()
	_rebuild_evidence()


func _recording_enabled() -> bool:
	if _evidence_recording_override >= 0:
		return _evidence_recording_override == 1
	if ProjectSettings.has_setting("vg/evidence/runtime_ring"):
		return bool(ProjectSettings.get_setting("vg/evidence/runtime_ring"))
	return false


func _sync_record_checkbox() -> void:
	if _evidence_record == null:
		return
	_evidence_record_sync = true
	_evidence_record.button_pressed = _recording_enabled()
	_evidence_record_sync = false


func _on_evidence_record_toggled(on: bool) -> void:
	if _evidence_record_sync:
		return
	_evidence_recording_override = -1
	ProjectSettings.set_setting("vg/evidence/runtime_ring", on)
	ProjectSettings.save()
	_sync_evidence_poll()
	_rebuild_evidence()


func _watch_names() -> PackedStringArray:
	var names := PackedStringArray()
	if not ProjectSettings.has_setting("vg/evidence/watch"):
		return names
	var current = ProjectSettings.get_setting("vg/evidence/watch")
	if current is PackedStringArray:
		return current
	if current is Array:
		for item in current:
			names.append(str(item))
	return names


func _watch_contains(variable: String) -> bool:
	for existing in _watch_names():
		if existing.to_lower() == variable.to_lower():
			return true
	return false


func _on_evidence_watch_pressed() -> void:
	var variable := ""
	if _evidence_watch != null:
		variable = _evidence_watch.text.trim_prefix("Watch ").strip_edges()
	if variable.is_empty() or variable == "Watch":
		return
	if _watch_contains(variable):
		return
	var names := _watch_names()
	names.append(variable)
	ProjectSettings.set_setting("vg/evidence/watch", names)
	ProjectSettings.save()
	_rebuild_evidence()


func _on_evidence_refresh_pressed() -> void:
	if _debugger_plugin != null and _debugger_plugin.has_method("request_evidence_snapshot"):
		_debugger_plugin.request_evidence_snapshot()
	if _debugger_plugin != null and _debugger_plugin.has_method("get_evidence_snapshot"):
		_evidence_run = _debugger_plugin.get_evidence_snapshot()
		_evidence_run_state = str(_debugger_plugin.get_evidence_run_state())
	_pull_caret_source()
	_rebuild_evidence()


func _on_evidence_clear_pressed() -> void:
	if _debugger_plugin != null and _debugger_plugin.has_method("clear_evidence_memory"):
		_debugger_plugin.clear_evidence_memory()
	_evidence_run = {}
	_evidence_run_state = "none"
	_rebuild_evidence()


func _on_evidence_copy_pressed() -> void:
	DisplayServer.clipboard_set(JSON.stringify(_evidence_view, "\t"))


func _on_evidence_row_pressed(file_path: String, line: int) -> void:
	navigate_to_line(file_path, line)


func set_evidence_source(text: String, caret_line: int, path: String) -> void:
	_evidence_text = text
	_evidence_line = caret_line
	_evidence_path = path
	_rebuild_evidence()


func set_evidence_run(run: Dictionary, run_state: String) -> void:
	_evidence_run = run
	_evidence_run_state = run_state
	_rebuild_evidence()


func set_evidence_recording_override(enabled: bool) -> void:
	_evidence_recording_override = 1 if enabled else 0
	_sync_evidence_poll()
	_rebuild_evidence()


func evidence_header_text() -> String:
	if _evidence_header == null:
		return ""
	return _evidence_header.text


func evidence_banner_text() -> String:
	if _evidence_banner == null:
		return ""
	return _evidence_banner.text


func evidence_prompt_text() -> String:
	if _evidence_prompt != null and _evidence_prompt.visible:
		return _evidence_prompt.text
	return ""


func evidence_row_statuses() -> Array:
	var statuses: Array = []
	for row in _evidence_view.get("rows", []):
		if typeof(row) == TYPE_DICTIONARY:
			statuses.append(str(row.get("runtime", "")))
	return statuses


func _whenever_section_at_line(text: String, line_number: int) -> String:
	var lines := text.split("\n")
	if line_number < 1 or line_number > lines.size():
		return ""
	var pattern := RegEx.new()
	if pattern.compile("(?i)^Whenever\\s+Section\\s+([A-Za-z_][A-Za-z0-9_]*)") != OK:
		return ""
	var found := pattern.search(lines[line_number - 1].strip_edges())
	if found == null:
		return ""
	return found.get_string(1)


func _rebuild_evidence() -> void:
	if _evidence_header == null:
		return
	var section := _whenever_section_at_line(_evidence_text, _evidence_line)
	if section.is_empty():
		_evidence_view = {}
		_evidence_header.text = ""
		_evidence_banner.text = ""
		_evidence_prompt.visible = true
		_evidence_prompt.text = "Put the caret on a Whenever Section line."
		_evidence_columns.visible = false
		_evidence_watch.visible = false
		_clear_evidence_rows()
		_sync_record_checkbox()
		return
	var chain = VGCausalChain.new()
	var report: Dictionary = chain.analyze(_evidence_text, [section], _evidence_path)
	_evidence_view = _evidence_view_model.build_view(report, _evidence_run, _evidence_run_state)
	var header: Dictionary = _evidence_view.get("header", {})
	_evidence_header.text = _format_evidence_header(header)
	_evidence_banner.text = _evidence_banners(header)
	_evidence_prompt.visible = false
	_evidence_columns.visible = true
	var variable := ""
	for root in report.get("roots", []):
		if typeof(root) == TYPE_DICTIONARY and str(root.get("kind", "")) == "whenever":
			variable = str(root.get("variable", ""))
			break
	_evidence_watch.visible = not variable.is_empty() and not _watch_contains(variable)
	_evidence_watch.text = "Watch " + variable
	_render_evidence_rows(_evidence_view.get("rows", []))
	_sync_record_checkbox()


func _format_evidence_header(header: Dictionary) -> String:
	var text := "%s  %s  fires %d  %s  dropped %d/%d" % [
		str(header.get("section", "")),
		str(header.get("root_status", "")),
		int(header.get("fire_count", 0)),
		str(header.get("run_state", "")),
		int(header.get("dropped", 0)),
		int(header.get("capacity", 0)),
	]
	if bool(header.get("stale", false)):
		text += "  stale"
	return text


func _evidence_banners(header: Dictionary) -> String:
	var lines := PackedStringArray()
	var has_run := not _evidence_run.is_empty() and str(_evidence_run.get("schema", "")) != ""
	if not _recording_enabled():
		if has_run:
			lines.append("Recording off. Showing the last captured run; new runs are not recorded.")
		else:
			lines.append("Recording off. Enable vg/evidence/runtime_ring and run the game.")
	elif not has_run:
		lines.append("No run yet.")
	if bool(header.get("stale", false)):
		lines.append("Source changed since this run (stale).")
	var dropped := int(header.get("dropped", 0))
	if dropped > 0:
		lines.append("Events dropped (%d). Raise vg/evidence/runtime_ring_capacity." % dropped)
	return "\n".join(lines)


func _risk_tags(risks: Array) -> String:
	var tags := ""
	for risk in risks:
		var label := ""
		match str(risk):
			"state write":
				label = "[write]"
			"early-return guard":
				label = "[guard]"
			"external effect":
				label = "[external]"
			"unresolved target":
				label = "[unresolved]"
		if not label.is_empty() and tags.find(label) < 0:
			tags += " " + label
	return tags


func _clear_evidence_rows() -> void:
	if _evidence_left == null or _evidence_right == null:
		return
	for child in _evidence_left.get_children():
		child.free()
	for child in _evidence_right.get_children():
		child.free()


func _render_evidence_rows(rows: Array) -> void:
	_clear_evidence_rows()
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = row
		var depth := int(item.get("depth", 0))
		var left := Button.new()
		left.alignment = HORIZONTAL_ALIGNMENT_LEFT
		left.flat = true
		var location := ""
		if int(item.get("line", 0)) > 0:
			location = "  %s:%d" % [str(item.get("file", "")), int(item.get("line", 0))]
		left.text = "  ".repeat(depth) + str(item.get("text", "")) + location + _risk_tags(item.get("risks", []))
		left.pressed.connect(_on_evidence_row_pressed.bind(str(item.get("file", "")), int(item.get("line", 0))))
		_evidence_left.add_child(left)
		var right := Label.new()
		var detail := ""
		for fact in item.get("detail", []):
			if not detail.is_empty():
				detail += " "
			detail += str(fact)
		right.text = str(item.get("runtime", ""))
		if not detail.is_empty():
			right.text += "  " + detail
		_evidence_right.add_child(right)


func _build_change_section() -> void:
	_change_toggle = Button.new()
	_change_toggle.text = "Last change"
	_change_toggle.toggle_mode = true
	_change_toggle.pressed.connect(_on_change_toggled)
	add_child(_change_toggle)
	_change_panel = VBoxContainer.new()
	_change_panel.visible = false
	add_child(_change_panel)
	var buttons := HBoxContainer.new()
	_change_panel.add_child(buttons)
	var run_btn := Button.new()
	run_btn.text = "Run checks"
	run_btn.pressed.connect(_on_change_run_checks)
	buttons.add_child(run_btn)
	var back_btn := Button.new()
	back_btn.text = "Roll back"
	back_btn.pressed.connect(_on_change_rollback_pressed)
	buttons.add_child(back_btn)
	var copy_btn := Button.new()
	copy_btn.text = "Copy"
	copy_btn.pressed.connect(_on_change_copy)
	buttons.add_child(copy_btn)
	var prev_btn := Button.new()
	prev_btn.text = "Previous"
	prev_btn.pressed.connect(_on_change_previous)
	buttons.add_child(prev_btn)
	var next_btn := Button.new()
	next_btn.text = "Next"
	next_btn.pressed.connect(_on_change_next)
	buttons.add_child(next_btn)
	_change_prompt = Label.new()
	_change_prompt.text = "What does this change do?"
	_change_panel.add_child(_change_prompt)
	_change_summary = LineEdit.new()
	_change_summary.placeholder_text = "Summarize the intended behavior in one sentence..."
	_change_summary.text_changed.connect(_on_change_summary_changed)
	_change_panel.add_child(_change_summary)
	_change_expect = CheckBox.new()
	_change_expect.text = "Save as protected expectation"
	_change_panel.add_child(_change_expect)
	_change_section_row = HBoxContainer.new()
	_change_section_row.visible = false
	_change_panel.add_child(_change_section_row)
	_change_section_label = Label.new()
	_change_section_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_change_section_row.add_child(_change_section_label)
	_change_section_next = Button.new()
	_change_section_next.text = "Next >"
	_change_section_next.pressed.connect(_on_change_section_next)
	_change_section_row.add_child(_change_section_next)
	_change_keep = Button.new()
	_change_keep.text = "Keep"
	_change_keep.disabled = true
	_change_keep.pressed.connect(_on_change_keep)
	_change_panel.add_child(_change_keep)
	_change_body = RichTextLabel.new()
	_change_body.fit_content = true
	_change_body.scroll_active = false
	_change_body.selection_enabled = true
	_change_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_change_body.custom_minimum_size = Vector2(0, 80)
	_change_panel.add_child(_change_body)
	_change_timer = Timer.new()
	_change_timer.wait_time = 0.1
	_change_timer.timeout.connect(_on_change_poll)
	add_child(_change_timer)
	_change_confirm = ConfirmationDialog.new()
	_change_confirm.ok_button_text = "Roll back"
	_change_confirm.confirmed.connect(_on_change_rollback_confirmed)
	add_child(_change_confirm)


func show_last_change() -> void:
	visible = true
	if _change_toggle != null:
		_change_toggle.button_pressed = true
	if _change_panel != null:
		_change_panel.visible = true
	var CS = load("res://addons/visual_gasic/vg_change_set.gd")
	var ids: Array = CS.list_ids() if CS != null else []
	_change_pos = ids.size() - 1
	_render_change_card()
	if _change_summary != null:
		_change_summary.grab_focus()


func _on_change_toggled(on: bool) -> void:
	if _change_panel != null:
		_change_panel.visible = on
	if on:
		_render_change_card()


func _render_change_card() -> void:
	if _change_body == null:
		return
	var CS = load("res://addons/visual_gasic/vg_change_set.gd")
	var Card = load("res://addons/visual_gasic/vg_change_card.gd")
	if CS == null or Card == null:
		return
	var ids: Array = CS.list_ids()
	if ids.is_empty():
		_change_text = "No change set is stored."
		_change_body.text = _change_text
		_change_card = {}
		_change_required = []
		_change_reviewed = []
		_change_file = ""
		if _change_section_row != null:
			_change_section_row.visible = false
		if _change_keep != null:
			_change_keep.disabled = true
		return
	if _change_pos < 0 or _change_pos >= ids.size():
		_change_pos = ids.size() - 1
	var manifest: Dictionary = CS.read_set(str(ids[_change_pos]))
	var before := {}
	var after := {}
	var before_blob := ""
	var file_path := ""
	for entry in manifest.get("entries", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var path := str(entry.get("path", ""))
		if not path.ends_with(".vg") or bool(entry.get("binary", false)):
			continue
		if file_path.is_empty():
			file_path = path
		var pre: PackedByteArray = CS.read_pre_bytes(str(manifest.get("id", "")), str(entry.get("pre_file", "")))
		before[path] = pre.get_string_from_utf8()
		before_blob += before[path] + "\n"
		if FileAccess.file_exists(path):
			var disk := FileAccess.get_file_as_bytes(path)
			if CS._sha(disk) == str(entry.get("post_hash", "")):
				after[path] = disk.get_string_from_utf8()
	var card: Dictionary = Card.build_card(manifest, {
		"reply": str(manifest.get("reply", "")),
		"before": before,
		"after": after,
		"snapshot": _evidence_run,
		"expectations": _change_expectations(manifest),
		"rollback_state": CS.preview(str(manifest.get("id", ""))),
	})
	_change_card = card
	_change_before_blob = before_blob
	_change_file = file_path
	_sync_change_gate(manifest, Card)
	_apply_live_summary(Card)


func _change_expectations(manifest: Dictionary) -> Dictionary:
	var Runner = load("res://addons/visual_gasic/vg_change_runner.gd")
	var project := ProjectSettings.globalize_path("res://")
	var scenarios: Array = Runner.scenario_rows(project) if Runner != null else []
	if scenarios.is_empty():
		return {"present": false, "rows": []}
	var ended := int(manifest.get("ended_unix", 0))
	var rows: Array = []
	for scenario in scenarios:
		var path := str(scenario.get("path", ""))
		var abs := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
		var status := "not run"
		var finished := 0
		if path.get_file() == _change_running:
			status = "running"
		for result in _change_results:
			if str(result.get("name", "")) == path.get_file():
				status = str(result.get("status", "incomplete"))
				finished = int(result.get("finished_unix", 0))
		if finished > 0 and ended > 0 and finished < ended:
			status = "stale"
		var current := ""
		if FileAccess.file_exists(abs):
			current = _change_sha(FileAccess.get_file_as_bytes(abs))
		rows.append({
			"name": path.get_file(),
			"status": status,
			"note": str(scenario.get("note", "")),
			"manifest_hash": str(scenario.get("sha256", "")),
			"scenario_hash": current,
			"finished_unix": finished,
		})
	return {"present": true, "rows": rows}


func _on_change_run_checks() -> void:
	var Runner = load("res://addons/visual_gasic/vg_change_runner.gd")
	if Runner == null:
		return
	var project := ProjectSettings.globalize_path("res://")
	_change_queue = Runner.scenario_rows(project)
	_change_results = []
	_change_running = ""
	_start_next_scenario()


func _start_next_scenario() -> void:
	var Runner = load("res://addons/visual_gasic/vg_change_runner.gd")
	if _change_queue.is_empty():
		_change_running = ""
		if _change_timer != null:
			_change_timer.stop()
		_render_change_card()
		return
	var row: Dictionary = _change_queue.pop_front()
	var path := str(row.get("path", ""))
	var script := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	_change_running = path.get_file()
	_render_change_card()
	var project := ProjectSettings.globalize_path("res://")
	if Runner == null or not Runner.start(project, script, ""):
		_change_results.append({
			"name": path.get_file(),
			"status": "incomplete",
			"finished_unix": int(Time.get_unix_time_from_system()),
		})
		_change_running = ""
		_start_next_scenario()
		return
	if _change_timer != null:
		_change_timer.start()


func _on_change_poll() -> void:
	var Runner = load("res://addons/visual_gasic/vg_change_runner.gd")
	if Runner == null:
		return
	var result: Dictionary = Runner.poll()
	if not bool(result.get("done", false)):
		return
	result["finished_unix"] = int(Time.get_unix_time_from_system())
	_change_results.append(result)
	_change_running = ""
	_start_next_scenario()


func _on_change_rollback_pressed() -> void:
	var CS = load("res://addons/visual_gasic/vg_change_set.gd")
	if CS == null or _change_confirm == null:
		return
	var ids: Array = CS.list_ids()
	if ids.is_empty() or _change_pos < 0 or _change_pos >= ids.size():
		return
	var manifest: Dictionary = CS.read_set(str(ids[_change_pos]))
	var lines := "Roll back these paths?\n"
	for entry in manifest.get("entries", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		lines += str(entry.get("path", entry.get("to", ""))) + "\n"
	for row in manifest.get("not_tracked", []):
		if typeof(row) == TYPE_DICTIONARY:
			lines += str(row.get("path", "")) + " (not tracked)\n"
	_change_confirm.dialog_text = lines
	_change_confirm.popup_centered()


func _on_change_rollback_confirmed() -> void:
	var CS = load("res://addons/visual_gasic/vg_change_set.gd")
	if CS == null:
		return
	var ids: Array = CS.list_ids()
	if _change_pos < 0 or _change_pos >= ids.size():
		return
	CS.rollback(str(ids[_change_pos]))
	_render_change_card()


func _on_change_copy() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(_change_text)


func _on_change_previous() -> void:
	_change_pos = maxi(_change_pos - 1, 0)
	_render_change_card()


func _on_change_next() -> void:
	var CS = load("res://addons/visual_gasic/vg_change_set.gd")
	var ids: Array = CS.list_ids() if CS != null else []
	if ids.is_empty():
		return
	_change_pos = mini(_change_pos + 1, ids.size() - 1)
	_render_change_card()


func _on_change_summary_changed(_text: String) -> void:
	var Card = load("res://addons/visual_gasic/vg_change_card.gd")
	if Card != null:
		_apply_live_summary(Card)


func _on_change_section_next() -> void:
	if _change_required.size() < 2:
		return
	_change_page = (_change_page + 1) % _change_required.size()
	_note_section_reviewed(str(_change_required[_change_page]))
	_update_section_label()
	_refresh_keep_button()


func _on_change_keep() -> void:
	if not Engine.is_editor_hint():
		try_keep()
		return
	var base := EditorInterface.get_base_control()
	var help = null
	if base != null and base.has_meta("visual_gasic_plugin_instance"):
		var plugin = base.get_meta("visual_gasic_plugin_instance")
		if plugin != null:
			help = plugin.get("_ai_help_panel")
	if help != null and help.has_method("_accept_kept_change"):
		help._accept_kept_change()
		return
	try_keep()


func try_keep() -> String:
	var Card = load("res://addons/visual_gasic/vg_change_card.gd")
	var sentence := ""
	if _change_summary != null:
		sentence = _change_summary.text.strip_edges()
	if Card == null or not Card.keep_ready(sentence, _change_reviewed, _change_required):
		return "Type what this change does, and view each changed section, before keeping."
	var CS = load("res://addons/visual_gasic/vg_change_set.gd")
	var ids: Array = CS.list_ids() if CS != null else []
	if ids.is_empty() or _change_pos < 0 or _change_pos >= ids.size():
		return ""
	CS.record_user_summary(str(ids[_change_pos]), sentence)
	if _change_expect != null and _change_expect.button_pressed:
		var Expectations = load("res://addons/visual_gasic/vg_expectations.gd")
		if Expectations != null:
			var exp = Expectations.new()
			exp.load_manifest(ProjectSettings.globalize_path("res://"))
			var sections: Array = _change_required.duplicate()
			if sections.is_empty():
				sections = [""]
			for section in sections:
				exp.append_audit_note(sentence, _change_file, str(section))
	return ""


func _sync_change_gate(manifest: Dictionary, Card) -> void:
	var id := str(manifest.get("id", ""))
	if id != _change_seen_id:
		_change_seen_id = id
		_change_reviewed = []
		_change_page = 0
		if _change_summary != null:
			var stored: Dictionary = manifest.get("user_summary", {})
			_change_summary.text = str(stored.get("text", "")) if typeof(stored) == TYPE_DICTIONARY else ""
		if _change_expect != null:
			_change_expect.button_pressed = false
	var static_section: Dictionary = _change_card.get("static", {})
	_change_required = Card.changed_section_names(static_section.get("rows", []))
	if _change_required.size() <= 1:
		if _change_section_row != null:
			_change_section_row.visible = false
		if _change_required.size() == 1:
			_note_section_reviewed(str(_change_required[0]))
		return
	if _change_page < 0 or _change_page >= _change_required.size():
		_change_page = 0
	_note_section_reviewed(str(_change_required[_change_page]))
	_update_section_label()


func _update_section_label() -> void:
	if _change_section_row == null or _change_section_label == null:
		return
	if _change_required.size() < 2:
		_change_section_row.visible = false
		return
	_change_section_row.visible = true
	_change_section_label.text = "Section %d of %d: %s" % [_change_page + 1, _change_required.size(), str(_change_required[_change_page])]


func _note_section_reviewed(section: String) -> void:
	if section.is_empty() or _change_reviewed.has(section):
		return
	_change_reviewed.append(section)


func _apply_live_summary(Card) -> void:
	if _change_card.is_empty() or _change_body == null:
		_refresh_keep_button()
		return
	var sentence := ""
	if _change_summary != null:
		sentence = _change_summary.text
	var stored: Dictionary = _change_card.get("user_summary", {})
	_change_card["user_summary"] = {
		"source": "user",
		"text": sentence,
		"timestamp": int(stored.get("timestamp", 0)) if typeof(stored) == TYPE_DICTIONARY else 0,
	}
	var static_section: Dictionary = _change_card.get("static", {})
	static_section["advisory"] = Card.advisory(sentence, static_section, _change_before_blob)
	_change_card["static"] = static_section
	_change_text = Card.to_text(_change_card)
	_change_body.text = _change_text
	_refresh_keep_button()


func _refresh_keep_button() -> void:
	if _change_keep == null:
		return
	var Card = load("res://addons/visual_gasic/vg_change_card.gd")
	var sentence := ""
	if _change_summary != null:
		sentence = _change_summary.text
	_change_keep.disabled = Card == null or not Card.keep_ready(sentence, _change_reviewed, _change_required)


func _change_sha(data: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()
