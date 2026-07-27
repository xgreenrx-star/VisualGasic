@tool
## VGMusic — VG plugin wrapping Bosca Ceoil Blue (https://github.com/YuriSizov/boscaceoil-blue).
##
## Bosca's source is vendored verbatim under ./bosca/.  It depends on:
##   * The GDSiON GDExtension (loaded via libgdsion.gdextension at this
##     plugin's folder).
##   * A `Controller` autoload — registered automatically by
##     VGPluginManager when this plugin is enabled (see plugin.cfg
##     [autoloads] section).  First-time enable requires a VG restart.
##
## Because Controller is loaded eagerly at engine startup but Bosca's full
## initialization is heavy (audio driver, settings, MainWindow script
## hijack), Controller is patched to no-op until vgmusic_boot() is called.
## We call that here on first activation, then instantiate Main.tscn into
## our embedded view.

extends "res://addons/visual_gasic/vg_plugin_base.gd"

const _BOSCA_DIR := "res://addons/visual_gasic/plugins/vgmusic/bosca"
const _MAIN_SCENE_PATH := _BOSCA_DIR + "/Main.tscn"
const _CONTROLLER_SCRIPT_PATH := _BOSCA_DIR + "/globals/Controller.gd"

var _main_scene_instance: Node = null
var _bosca_theme: Theme = null
var _bosca_wrapper: VBoxContainer = null  # holds toolbar + main scene
var _export_toolbar: HBoxContainer = null # "Export to game project" bar
var _ffmpeg_path: String = ""             # cached ffmpeg path, empty = not found

# bosca/ carries an empty .gdignore (see commit ae10e36b — "don't import
# third-party tree") so Godot's project-wide class scanner never registers
# its `class_name` declarations (ExportMasterPopup, SongSaver, MMLExporter,
# ...) as global identifiers usable from outside the folder. Load these
# specific scripts by path instead, cached on first use.
var _export_master_popup_script: GDScript = null
var _song_saver_script: GDScript = null
var _mml_exporter_script: GDScript = null

func _ExportMasterPopup() -> GDScript:
	if _export_master_popup_script == null:
		_export_master_popup_script = load(_BOSCA_DIR + "/gui/widgets/popups/ExportMasterPopup.gd")
	return _export_master_popup_script

func _SongSaver() -> GDScript:
	if _song_saver_script == null:
		_song_saver_script = load(_BOSCA_DIR + "/io/SongSaver.gd")
	return _song_saver_script

func _MMLExporter() -> GDScript:
	if _mml_exporter_script == null:
		_mml_exporter_script = load(_BOSCA_DIR + "/io/MMLExporter.gd")
	return _mml_exporter_script


# ─── VG plugin metadata ──────────────────────────────────────────

func get_plugin_name() -> String:
	return "Bosca Ceoil"

func get_toolbar_icon() -> String:
	return "🎵"

func get_toolbar_color() -> Color:
	# Match the VG VB6 navy header so the toolbar button matches the IDE.
	return Color(0.0, 0.0, 0.5)

func get_toolbar_tooltip() -> String:
	return "Open Bosca Ceoil Blue — music tracker / chiptune maker."


# ─── UI build ────────────────────────────────────────────────────

func _build_ui() -> void:
	# Wrap _view contents in a VBoxContainer so we can stack the
	# export toolbar above the Bosca main scene.
	_bosca_wrapper = VBoxContainer.new()
	_bosca_wrapper.name = "BoscaWrapper"
	_bosca_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bosca_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.add_child(_bosca_wrapper)
	_build_export_toolbar()


func _build_export_toolbar() -> void:
	_export_toolbar = HBoxContainer.new()
	_export_toolbar.name = "VGExportToolbar"
	_export_toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_export_toolbar.add_theme_constant_override("separation", 6)
	_bosca_wrapper.add_child(_export_toolbar)

	var lbl := Label.new()
	lbl.text = "  Export to game:"
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_export_toolbar.add_child(lbl)

	var wav_btn := Button.new()
	wav_btn.text = "WAV"
	wav_btn.tooltip_text = "Export song as a WAV audio file (safe, works on all platforms)."
	wav_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wav_btn.pressed.connect(_on_export_wav_pressed)
	_export_toolbar.add_child(wav_btn)

	var ogg_btn := Button.new()
	ogg_btn.name = "OggExportBtn"
	ogg_btn.text = "OGG"
	ogg_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ogg_btn.pressed.connect(_on_export_ogg_pressed)
	_export_toolbar.add_child(ogg_btn)
	# Enable/disable OGG button once ffmpeg check runs on next idle frame.
	_refresh_ogg_button.call_deferred()

	var ceol_btn := Button.new()
	ceol_btn.text = ".ceol \u26a0"
	ceol_btn.tooltip_text = "Save as .ceol for GDSiON runtime synthesis (dynamic music). Requires GDSiON binaries in your export."
	ceol_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ceol_btn.pressed.connect(_on_export_ceol_pressed)
	_export_toolbar.add_child(ceol_btn)

	var sep := VSeparator.new()
	_export_toolbar.add_child(sep)

	var mml_btn := Button.new()
	mml_btn.text = "MML"
	mml_btn.tooltip_text = "Export as SiON MML — use with VGMusicPlayer node for dynamic in-game music synthesis."
	mml_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mml_btn.pressed.connect(_on_export_mml_pressed)
	_export_toolbar.add_child(mml_btn)


# ─── Activation / deactivation ───────────────────────────────────

func _on_activated() -> void:
	_ensure_main_scene()


func _on_deactivated() -> void:
	# Keep the scene loaded to preserve the user's in-progress song;
	# just hide it.
	if _view:
		_view.visible = false


func _on_cleanup() -> void:
	if is_instance_valid(_main_scene_instance):
		_main_scene_instance.queue_free()
	_main_scene_instance = null


# ─── Helpers ─────────────────────────────────────────────────────

## When Bosca's PopupManager CanvasLayer shows the ClickCatcher it covers
## the ENTIRE Godot editor viewport (full anchors on a CanvasLayer), painting
## a dark opaque-looking rect over everything and making the panel appear
## blank.  We fix this by:
##   1. Disconnecting the draw callback so the ClickCatcher is transparent
##      (it still intercepts clicks to dismiss popups).
##   2. Keeping the ClickCatcher confined to the Main panel rect by updating
##      its size whenever the panel resizes.
##
## Additionally, Godot theme lookup walks Control parents but stops at the
## CanvasLayer boundary, so OptionListPopup instances inside PopupManager
## never see the bosca project_theme.tres we set on the root MarginContainer.
## We fix this by:
##   3. Applying _bosca_theme directly to every OptionListPopup already in
##      the scene (the OptionPicker controls create them at _init time).
##   4. Watching PopupManager for new PopupAnchor children and applying
##      the theme to any Control child they contain (covers sub-popups and
##      any future popup added at runtime).
func _patch_popup_manager_for_embedded() -> void:
	if not is_instance_valid(_main_scene_instance):
		return
	var popup_mgr: Node = _main_scene_instance.get_node_or_null("PopupManager")
	if not popup_mgr:
		return
	var click_catcher: Control = popup_mgr.get_node_or_null("ClickCatcher")
	if not click_catcher:
		return

	# Remove the full-screen dark-overlay draw — popups dismiss just fine
	# without it because the ClickCatcher still receives mouse events.
	var draw_cb := Callable(popup_mgr, "_draw_catcher")
	if click_catcher.draw.is_connected(draw_cb):
		click_catcher.draw.disconnect(draw_cb)

	# Confine the ClickCatcher to the panel bounds instead of the full viewport.
	# Full-rect anchors on a CanvasLayer child expand to the host viewport size;
	# we reset to a fixed size matching our root control.
	click_catcher.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	var root_ctl := _main_scene_instance as Control
	if root_ctl:
		click_catcher.size = root_ctl.size
		if not root_ctl.resized.is_connected(_sync_click_catcher_size):
			root_ctl.resized.connect(_sync_click_catcher_size)

	# Apply bosca theme to any OptionListPopup already in the scene tree.
	# OptionPicker creates its _popup_control in _init, so those exist before
	# they're shown, but they're NOT yet under PopupManager — they sit detached
	# waiting to be shown.  Walk the full scene to find them.
	if _bosca_theme:
		_apply_bosca_theme_to_popups(_main_scene_instance)

	# Watch for future popup controls added to PopupManager at runtime
	# (sub-popups are created lazily and added as PopupAnchor children).
	if not popup_mgr.child_order_changed.is_connected(_on_popup_manager_changed):
		popup_mgr.child_order_changed.connect(_on_popup_manager_changed)


func _sync_click_catcher_size() -> void:
	if not is_instance_valid(_main_scene_instance):
		return
	var popup_mgr: Node = _main_scene_instance.get_node_or_null("PopupManager")
	if not popup_mgr:
		return
	var click_catcher: Control = popup_mgr.get_node_or_null("ClickCatcher")
	if not click_catcher:
		return
	var root_ctl := _main_scene_instance as Control
	if root_ctl:
		click_catcher.size = root_ctl.size


## Walk the node tree from `root` and apply _bosca_theme to every OptionListPopup
## that hasn't already had a theme explicitly set.  OptionPicker creates its
## _popup_control in _init (before the scene enters the tree), so those
## instances are detached nodes attached to OptionPicker — they live in the
## scene tree as children of the OptionPicker's parent hierarchy.
func _apply_bosca_theme_to_popups(root: Node) -> void:
	if not _bosca_theme:
		return
	# Walk the tree depth-first.
	for child in root.get_children():
		if child is Control:
			var ctrl := child as Control
			# OptionListPopup (class_name defined in Bosca); match by script name
			# to avoid a hard class_name dependency here.
			if ctrl.get_script() and ctrl.get_script().resource_path.ends_with("OptionListPopup.gd"):
				if not ctrl.theme:
					ctrl.theme = _bosca_theme
				# Also apply to all sub-popups stored in _popup_map (they are
				# detached nodes — never in the scene tree — so the tree walk
				# alone cannot reach them).
				var popup_map: Dictionary = ctrl.get("_popup_map") if ctrl.get("_popup_map") != null else {}
				for sub_popup in popup_map.values():
					if sub_popup is Control and not (sub_popup as Control).theme:
						(sub_popup as Control).theme = _bosca_theme
			# OptionPicker holds a detached _popup_control — access it by name.
			elif ctrl.has_meta("_popup_control"):
				pass # meta not used; fall through to child walk
		_apply_bosca_theme_to_popups(child)

	# Also check for a detached _popup_control on OptionPicker nodes.
	if root.get_script() and root.get_script().resource_path.ends_with("OptionPicker.gd"):
		var popup_ctrl = root.get("_popup_control")
		if popup_ctrl is Control:
			var pc := popup_ctrl as Control
			if not pc.theme:
				pc.theme = _bosca_theme
			# Recurse into the top-level popup's _popup_map sub-popups too.
			var popup_map: Dictionary = pc.get("_popup_map") if pc.get("_popup_map") != null else {}
			for sub_popup in popup_map.values():
				if sub_popup is Control and not (sub_popup as Control).theme:
					(sub_popup as Control).theme = _bosca_theme


## Called when children are added/removed from PopupManager at runtime.
## Applies the bosca theme to any newly added PopupAnchor's Control children
## (these are the OptionListPopup instances shown at runtime).
func _on_popup_manager_changed() -> void:
	if not _bosca_theme or not is_instance_valid(_main_scene_instance):
		return
	# Defer so the popup has been added to the PopupAnchor before we check.
	# PopupManager.add_child(anchor) fires child_order_changed, but
	# anchor.add_child(popup) happens on the very next line — still the same
	# frame — so deferring to the next idle frame ensures both are in place.
	_apply_theme_to_popup_manager_children.call_deferred()


func _apply_theme_to_popup_manager_children() -> void:
	if not _bosca_theme or not is_instance_valid(_main_scene_instance):
		return
	var popup_mgr: Node = _main_scene_instance.get_node_or_null("PopupManager")
	if not popup_mgr:
		return
	for anchor in popup_mgr.get_children():
		if anchor.name == "ClickCatcher":
			continue
		for popup_child in anchor.get_children():
			if popup_child is Control:
				var pc := popup_child as Control
				if not pc.theme:
					pc.theme = _bosca_theme


func _ensure_main_scene() -> void:
	if is_instance_valid(_main_scene_instance):
		_main_scene_instance.visible = true
		return

	# Boot Bosca's managers + audio driver lazily on first activation.
	# Controller is the autoload registered by VGPluginManager from
	# plugin.cfg's [autoloads] section.
	var ctrl := _get_or_create_controller()
	if ctrl == null:
		_show_error_label("VGMusic: failed to create Controller.\n\nThe plugin may not be enabled, or the script failed to load. Try restarting VisualGasic.")
		return

	if ctrl.has_method("vgmusic_boot"):
		ctrl.vgmusic_boot()

	var scene: PackedScene = load(_MAIN_SCENE_PATH)
	if scene == null:
		_show_error_label("VGMusic: failed to load Main.tscn at\n%s" % _MAIN_SCENE_PATH)
		return

	_main_scene_instance = scene.instantiate()
	if _main_scene_instance is Control:
		var ctl := _main_scene_instance as Control
		ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ctl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ctl.custom_minimum_size = Vector2(800, 600)
		# Apply Bosca's project theme to the embedded root so that theme
		# constants like NoteMap/note_height and NoteMap/border_width are
		# found during tree lookup.  Without this they resolve to 0 (the
		# engine fallback), making the note-map grid invisible (black).
		_bosca_theme = load(_BOSCA_DIR + "/gui/theme/project_theme.tres")
		if _bosca_theme:
			ctl.theme = _bosca_theme
	_bosca_wrapper.add_child(_main_scene_instance)
	_patch_popup_manager_for_embedded()


## Resolve (or create) the Controller node at /root/Controller.
##
## Godot only auto-instantiates project autoloads when running the
## project as a game; in the editor (where this plugin lives) /root
## stays empty unless the autoload script is @tool.  We don't want to
## mark Bosca's whole dependency chain @tool, so we instantiate the
## Controller manually the first time the plugin is activated.
##
## The autoload entry in project.godot is still required so GDScript
## resolves the global `Controller` identifier at parse time.
func _get_or_create_controller() -> Node:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var root: Node = (loop as SceneTree).root
	if root == null:
		return null
	var existing := root.get_node_or_null("Controller")
	if existing != null:
		return existing
	var script: GDScript = load(_CONTROLLER_SCRIPT_PATH)
	if script == null:
		return null
	var node: Node = Node.new()
	node.set_script(script)
	node.name = "Controller"
	root.add_child(node)
	return node


func _show_error_label(msg: String) -> void:
	if not is_instance_valid(_view):
		return
	# Clear any previous error and show the new one.
	for c in _view.get_children():
		c.queue_free()
	var lbl := Label.new()
	lbl.text = msg
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_view.add_child(lbl)


# ─── Export to game project ──────────────────────────────────────

## Return the Controller node from /root/Controller (the Bosca autoload).
func _get_controller() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if not loop:
		return null
	return loop.root.get_node_or_null("Controller")


## Check if ffmpeg is available and update the OGG button accordingly.
## Runs deferred so the toolbar nodes are fully in the tree.
func _refresh_ogg_button() -> void:
	if not is_instance_valid(_export_toolbar):
		return
	var ogg_btn := _export_toolbar.get_node_or_null("OggExportBtn") as Button
	if not ogg_btn:
		return

	# Cache the result so we don't re-probe on every activation.
	if _ffmpeg_path.is_empty():
		var output: Array = []
		# Quick version check; exits with 0 if ffmpeg is present.
		var code := OS.execute("ffmpeg", ["-version"], output, true, true)
		if code == 0:
			_ffmpeg_path = "ffmpeg"
		else:
			# Try common system paths on Linux/macOS.
			for p: String in ["/usr/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/snap/bin/ffmpeg", "/opt/homebrew/bin/ffmpeg"]:
				if FileAccess.file_exists(p):
					_ffmpeg_path = p
					break

	if _ffmpeg_path.is_empty():
		ogg_btn.disabled = true
		ogg_btn.tooltip_text = "Export as OGG (smaller, ideal for music).\n\u26a0 ffmpeg not found on PATH \u2014 install ffmpeg to enable OGG export."
	else:
		ogg_btn.disabled = false
		ogg_btn.tooltip_text = "Export as OGG via ffmpeg (smaller than WAV, ideal for in-game music)."


## WAV button: open our own save dialog so we control the path,
## then call through IOManager's confirmed path (preserves lock/unlock flow).
## After the async render finishes, auto-save a .ceol alongside the WAV.
func _on_export_wav_pressed() -> void:
	var ctrl := _get_controller()
	if not ctrl:
		return
	var song = ctrl.get("current_song")
	var io = ctrl.get("io_manager")
	var music_player = ctrl.get("music_player")
	if not song or not io or not music_player:
		push_warning("BoscaCeoil WAV export: Controller not ready.")
		return

	var safe_name: String = song.call("get_safe_filename", "wav") if song.has_method("get_safe_filename") else "song.wav"

	var wav_dialog := ctrl.call("get_file_dialog") as FileDialog
	wav_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	wav_dialog.title = "Export WAV File"
	wav_dialog.add_filter("*.wav", "Waveform Audio")
	wav_dialog.current_file = safe_name
	wav_dialog.file_selected.connect(_on_wav_path_selected, CONNECT_ONE_SHOT)
	ctrl.call("show_file_dialog", wav_dialog)


func _on_wav_path_selected(wav_path: String) -> void:
	var ctrl := _get_controller()
	if not ctrl:
		return
	var song = ctrl.get("current_song")
	var io = ctrl.get("io_manager")
	var music_player = ctrl.get("music_player")
	if not song or not io or not music_player:
		return

	# Build a full-song export config (loop start 0 → end of arrangement).
	var export_config = _ExportMasterPopup().ExportConfig.new()
	export_config.type = _ExportMasterPopup().ExportType.EXPORT_WAV
	export_config.loop_start = 0
	var arrangement = song.get("arrangement")
	export_config.loop_end = arrangement.get("timeline_length") if arrangement else 1

	# IOManager's _export_wav_song_confirmed: connects export_ended ONE_SHOT for
	# the WAV write itself, then kicks off start_exporting().  We connect OUR
	# .ceol auto-save callback afterwards — it fires second, after WAV is on disk.
	io.call("_export_wav_song_confirmed", wav_path, export_config)
	music_player.export_ended.connect(
		func() -> void: _auto_save_ceol_alongside(wav_path),
		CONNECT_ONE_SHOT
	)


## OGG button: ask for an output path, export WAV to a temp file,
## then convert with ffmpeg once the WAV render completes.
func _on_export_ogg_pressed() -> void:
	if _ffmpeg_path.is_empty():
		return  # Button should already be disabled; guard anyway.

	var ctrl := _get_controller()
	if not ctrl:
		return
	var song = ctrl.get("current_song")
	if not song:
		push_warning("BoscaCeoil export: no current song loaded.")
		return

	# Build a suggested file name from the song filename.
	var safe_name: String = song.call("get_safe_filename", "ogg") if song.has_method("get_safe_filename") else "song.ogg"

	var ogg_dialog := ctrl.call("get_file_dialog") as FileDialog
	ogg_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	ogg_dialog.title = "Export OGG File"
	ogg_dialog.add_filter("*.ogg", "OGG Vorbis Audio")
	ogg_dialog.current_file = safe_name
	ogg_dialog.file_selected.connect(_on_ogg_path_selected, CONNECT_ONE_SHOT)
	ctrl.call("show_file_dialog", ogg_dialog)


func _on_ogg_path_selected(ogg_path: String) -> void:
	var ctrl := _get_controller()
	if not ctrl:
		return
	var song = ctrl.get("current_song")
	var io  = ctrl.get("io_manager")
	var music_player = ctrl.get("music_player")
	if not song or not io or not music_player:
		return

	# Place the intermediate WAV next to the destination OGG so the
	# ffmpeg call is a simple same-directory operation.
	var temp_wav: String = ogg_path.get_basename() + ".tmp_vg_export.wav"

	# Build a minimal ExportConfig requesting WAV output.
	var export_config = _ExportMasterPopup().ExportConfig.new()
	export_config.type = _ExportMasterPopup().ExportType.EXPORT_WAV
	export_config.loop_start = 0
	var arrangement = song.get("arrangement")
	export_config.loop_end = arrangement.get("timeline_length") if arrangement else 1

	# _export_wav_song_confirmed: connects music_player.export_ended (ONE_SHOT)
	# for its own _save_wav_song handler, then calls start_exporting().
	# We connect OUR callback AFTER so it fires second (after the WAV is
	# written to disk by IOManager).
	io.call("_export_wav_song_confirmed", temp_wav, export_config)

	music_player.export_ended.connect(
		func() -> void: _on_ogg_wav_intermediate_saved(temp_wav, ogg_path),
		CONNECT_ONE_SHOT
	)


func _on_ogg_wav_intermediate_saved(temp_wav: String, ogg_path: String) -> void:
	# The intermediate WAV has been written; convert it to OGG with ffmpeg.
	# -y  : overwrite without prompting
	# -q:a 4 : VBR quality 4 (~128 kbps), good balance for chiptune
	var output: Array = []
	var exit_code := OS.execute(_ffmpeg_path, ["-y", "-i", temp_wav, "-q:a", "4", ogg_path], output, true, true)

	# Clean up the temp WAV regardless of success.
	if FileAccess.file_exists(temp_wav):
		DirAccess.remove_absolute(temp_wav)

	var ctrl := _get_controller()
	if exit_code != 0:
		push_error("BoscaCeoil OGG export failed (ffmpeg exit %d):\n%s" % [exit_code, "\n".join(output)])
		if ctrl:
			ctrl.call("update_status", "OGG EXPORT FAILED — see Output panel", 2)  # ERROR level
	else:
		print("BoscaCeoil: OGG exported to %s" % ogg_path)
		if ctrl:
			ctrl.call("update_status", "SONG EXPORTED AS OGG", 1)  # SUCCESS level
		# Auto-save the .ceol source alongside the OGG.
		_auto_save_ceol_alongside(ogg_path)


## Auto-save the current song as .ceol in the same directory as `exported_path`,
## using the same base filename.  Gives the user their editable source file
## automatically, co-located with the audio they just exported.
func _auto_save_ceol_alongside(exported_path: String) -> void:
	var ctrl := _get_controller()
	if not ctrl:
		return
	var song = ctrl.get("current_song")
	if not song:
		return

	var dir := exported_path.get_base_dir()
	var base := exported_path.get_file().get_basename()
	var ceol_path := dir.path_join(base + ".ceol")

	# SongSaver is a @tool class in Bosca — call it directly (it's always loaded
	# in the editor context since the plugin is active).
	var success: bool = _SongSaver().save(song, ceol_path)
	if success:
		print("BoscaCeoil: Auto-saved .ceol source to %s" % ceol_path)
		ctrl.call("update_status", ".ceol source saved alongside audio", 1)
	else:
		push_warning("BoscaCeoil: Auto-save .ceol failed for %s" % ceol_path)


## CEOL button: warn about GDSiON runtime requirement, then open Bosca's
## native Save As dialog if the user confirms.
func _on_export_ceol_pressed() -> void:
	var ctrl := _get_controller()
	if not ctrl:
		return

	var dlg := ConfirmationDialog.new()
	dlg.title = "Save as .ceol \u2014 Runtime playback warning"
	dlg.dialog_text = (
		".ceol files need GDSiON GDExtension to play back inside your exported game.\n\n"
		+ "This means:\n"
		+ "  \u2022  GDSiON binaries (~2\u20135 MB per platform) must ship with every export\n"
		+ "  \u2022  Playback may silently fail on platforms without a GDSiON binary\n"
		+ "  \u2022  Audio runs on the CPU synthesiser, not through Godot\u2019s AudioServer\n"
		+ "  \u2022  Godot bus effects (reverb, compressor, etc.) won\u2019t apply\n\n"
		+ "For maximum compatibility, use WAV or OGG export instead.\n\n"
		+ "Are you sure you want to save as .ceol?"
	)
	dlg.ok_button_text = "Yes, save as .ceol"

	dlg.confirmed.connect(func() -> void:
		dlg.queue_free()
		var io = ctrl.get("io_manager")
		if io:
			io.call("save_ceol_song", true)  # true = force Save As dialog
	, CONNECT_ONE_SHOT)

	# Add to the view so the dialog can render; it frees itself on close.
	dlg.canceled.connect(dlg.queue_free, CONNECT_ONE_SHOT)
	_view.add_child(dlg)
	dlg.popup_centered(Vector2i(620, 360))


## MML button: export the song as SiON MML — the format used by VGMusicPlayer
## for dynamic in-game synthesis.
func _on_export_mml_pressed() -> void:
	var ctrl := _get_controller()
	if not ctrl:
		return
	var song = ctrl.get("current_song")
	var io = ctrl.get("io_manager")
	if not song or not io:
		return

	var safe_name: String = song.call("get_safe_filename", "mml") if song.has_method("get_safe_filename") else "song.mml"

	var mml_dialog := ctrl.call("get_file_dialog") as FileDialog
	mml_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	mml_dialog.title = "Export SiON MML File (for VGMusicPlayer)"
	mml_dialog.add_filter("*.mml", "MML File")
	mml_dialog.current_file = safe_name
	mml_dialog.file_selected.connect(_on_mml_path_selected, CONNECT_ONE_SHOT)
	ctrl.call("show_file_dialog", mml_dialog)


func _on_mml_path_selected(mml_path: String) -> void:
	var ctrl := _get_controller()
	if not ctrl:
		return
	var song = ctrl.get("current_song")
	if not song:
		return

	var export_config = _ExportMasterPopup().ExportConfig.new()
	export_config.type = _ExportMasterPopup().ExportType.EXPORT_MML
	export_config.loop_start = 0
	var arrangement = song.get("arrangement")
	export_config.loop_end = arrangement.get("timeline_length") if arrangement else 1

	var success: bool = _MMLExporter().save(song, mml_path, export_config)
	if success:
		print("BoscaCeoil: MML exported to %s" % mml_path)
		ctrl.call("update_status", "SONG EXPORTED AS MML", 1)
		# Auto-save .ceol alongside the MML.
		_auto_save_ceol_alongside(mml_path)
	else:
		ctrl.call("update_status", "MML EXPORT FAILED", 2)
