@tool
extends RefCounted
## Persistence for the AI editor-action approval mode.
##
## Three modes:
##   "auto"           — apply every action immediately (Copilot-style).
##   "current_buffer" — apply buffer edits in the open file silently;
##                      anything that touches a *different* file or creates
##                      a new file goes through a confirm dialog.  (default)
##   "always_confirm" — every action shows a confirm dialog.
##
## When mode == "auto" we also count successful edits and prompt the user
## every RECHECK_EVERY edits with "are you still happy with auto-apply?"
## so a runaway model can't silently churn through a project.

const CFG_PATH := "user://vg_ai_action_mode.cfg"
const RECHECK_EVERY := 25

const MODE_AUTO := "auto"
const MODE_BUFFER := "current_buffer"
const MODE_CONFIRM := "always_confirm"
const VALID_MODES := [MODE_AUTO, MODE_BUFFER, MODE_CONFIRM]

var _mode: String = ""               # empty == never picked
var _edits_since_recheck: int = 0
var _loaded := false


func _load_if_needed() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		var m: String = str(cfg.get_value("action", "mode", ""))
		if m in VALID_MODES:
			_mode = m
		_edits_since_recheck = int(cfg.get_value("action", "edits_since_recheck", 0))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("action", "mode", _mode)
	cfg.set_value("action", "edits_since_recheck", _edits_since_recheck)
	cfg.save(CFG_PATH)


## "" if the user has never picked a mode (first run). Otherwise one of
## MODE_AUTO / MODE_BUFFER / MODE_CONFIRM.
func get_mode() -> String:
	_load_if_needed()
	return _mode


func set_mode(mode: String) -> void:
	_load_if_needed()
	if not (mode in VALID_MODES):
		return
	_mode = mode
	_edits_since_recheck = 0
	_save()


func has_picked_mode() -> bool:
	return not get_mode().is_empty()


## Returns true if the caller should pop the comfort-check dialog now
## ("are you still happy with auto-apply?"). Only ever true in MODE_AUTO.
func should_recheck() -> bool:
	_load_if_needed()
	return _mode == MODE_AUTO and _edits_since_recheck >= RECHECK_EVERY


func note_edit_applied() -> void:
	_load_if_needed()
	if _mode != MODE_AUTO:
		return
	_edits_since_recheck += 1
	_save()


func mark_rechecked() -> void:
	_load_if_needed()
	_edits_since_recheck = 0
	_save()
