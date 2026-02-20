@tool
extends Timer
## VGTimer — VB6-faithful Timer control.
##
## Wraps Godot's Timer with the standard VB6 Timer API.
## All native Timer functionality is preserved — this only ADDS the VB6 layer.
##
## VB6-compatible API:
##   Properties: Interval (milliseconds), Enabled (start/stop), Tag
##   Events:     timer_event (VB6: Timer event)
##
## Key difference from Godot: Interval is in MILLISECONDS (VB6 convention),
## not seconds. Setting Interval=0 disables the timer.

# =============================================================================
# VB6 Signals (Events)
# =============================================================================

## timer_event — fires each time the interval elapses (VB6: Timer event).
signal timer_event()

# =============================================================================
# Internal state
# =============================================================================

var _interval_ms: int = 1000
var _enabled: bool = true

# =============================================================================
# VB6 Properties
# =============================================================================

## Interval — timer period in milliseconds (VB6 convention).
## Setting to 0 disables the timer. Valid range: 0–2,147,483,647.
@export var Interval: int = 1000:
	get: return _interval_ms
	set(v):
		_interval_ms = maxi(v, 0)
		if _interval_ms > 0:
			wait_time = _interval_ms / 1000.0
		if is_inside_tree() and not Engine.is_editor_hint():
			if _interval_ms > 0 and _enabled:
				start()
			else:
				stop()

## Enabled — whether the timer is running.
## Setting to true starts the timer; false stops it.
var Enabled: bool:
	get: return _enabled
	set(v):
		_enabled = v
		if is_inside_tree() and not Engine.is_editor_hint():
			if _enabled and _interval_ms > 0:
				start()
			else:
				stop()

## Tag — general-purpose string storage (VB6 convention).
@export var Tag: String = ""

# =============================================================================
# Construction
# =============================================================================

func _ready() -> void:
	one_shot = false
	if not timeout.is_connected(_on_timeout):
		timeout.connect(_on_timeout)
	if _interval_ms > 0:
		wait_time = _interval_ms / 1000.0
	if not Engine.is_editor_hint() and _enabled and _interval_ms > 0:
		start()

func _on_timeout() -> void:
	timer_event.emit()
