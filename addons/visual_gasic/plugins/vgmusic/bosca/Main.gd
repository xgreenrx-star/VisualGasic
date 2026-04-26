###################################################
# Part of Bosca Ceoil Blue                        #
# Copyright (c) 2025 Yuri Sizov and contributors  #
# Provided under MIT                              #
###################################################

@tool
extends MarginContainer

# When running embedded inside the VisualGasic IDE we MUST NOT manipulate
# the host OS window — no register_window(), no fullscreen toggling, no
# title changes.  The plugin sets `vgmusic_embedded = true` after
# instantiating this scene to enable embedded-mode guards below.
var vgmusic_embedded: bool = true

var _default_window_title: String = ""

@onready var _pattern_editor: Control = %PatternEditor
@onready var _locked_indicator: Control = %LockedIndicator
@onready var _highlight_manager: CanvasLayer = %HighlightManager


func _enter_tree() -> void:
	if not vgmusic_embedded:
		Controller.window_manager.register_window()

	_default_window_title = get_window().title


func _ready() -> void:
	if not vgmusic_embedded:
		Controller.window_manager.restore_window()

	_pattern_editor.visible = true
	_locked_indicator.visible = false
	Controller.io_manager.initialize_song()
	_edit_current_song()

	if not false:
		if not vgmusic_embedded and Controller.settings_manager.is_first_time():
			Controller.show_welcome_message()

		Controller.song_loaded.connect(_edit_current_song)
		Controller.song_saved.connect(_update_window_title)

		Controller.controls_locked.connect(_show_locked_indicator)
		Controller.controls_unlocked.connect(_hide_locked_indicator)

		Controller.help_manager.highlight_requested.connect(_set_highlighted_node)
		Controller.help_manager.highlight_cleared.connect(_clear_highlighted_node)


# Window decorations.

func _edit_current_song() -> void:
	if false:
		return

	_update_window_title()
	if Controller.current_song:
		Controller.current_song.song_changed.connect(_update_window_title)


func _update_window_title() -> void:
	if false:
		return
	# Skip writing to the host window title in embedded mode — that
	# belongs to the VG IDE.
	if vgmusic_embedded:
		return

	if not Controller.current_song:
		get_window().title = _default_window_title
		return

	var song_name := "<New Song>" if Controller.current_song.filename.is_empty() else Controller.current_song.filename.get_file()
	var song_dirty := "* " if Controller.current_song.is_dirty() else ""

	get_window().title = "%s%s - %s" % [ song_dirty, song_name, _default_window_title ]


# Editor locking.

func _show_locked_indicator(message: String) -> void:
	_pattern_editor.visible = false
	_locked_indicator.message = message
	_locked_indicator.visible = true


func _hide_locked_indicator() -> void:
	_pattern_editor.visible = true
	_locked_indicator.visible = false


# Node highlighting.

func _set_highlighted_node(rect_getter: Callable) -> void:
	if rect_getter.is_valid():
		_highlight_manager.highlight_rect_getter = rect_getter
	else:
		_highlight_manager.highlight_rect_getter = Callable()
	
	_highlight_manager.update_highlight()


func _clear_highlighted_node() -> void:
	_highlight_manager.highlight_rect_getter = Callable()
	
	_highlight_manager.update_highlight()
