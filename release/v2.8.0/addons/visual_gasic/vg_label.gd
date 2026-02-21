@tool
extends Label
## VGLabel — VB6-faithful Label control.
##
## Wraps Godot's Label with the standard VB6 Label API.
## All native Label functionality is preserved — this only ADDS the VB6 layer.
##
## VB6-compatible API:
##   Properties: Caption, Alignment, AutoSize, WordWrap, BackStyle,
##               BorderStyle, Tag
##   Events:     Click, DblClick

# =============================================================================
# VB6 Signals (Events)
# =============================================================================

## Click — fires when the label is clicked (VB6: Click event).
signal Click()

## DblClick — fires when the label is double-clicked (VB6: DblClick event).
signal DblClick()

# =============================================================================
# Internal state
# =============================================================================

var _alignment_vb: int = 0     # 0=Left, 1=Right, 2=Center
var _auto_size: bool = false
var _word_wrap: bool = false
var _back_style: int = 0       # 0=Transparent, 1=Opaque
var _border_style: int = 0     # 0=None, 1=FixedSingle
var _back_color: Color = Color(0.94, 0.94, 0.94, 1.0)
var _last_click_time: int = 0

# =============================================================================
# VB6 Properties
# =============================================================================

## Caption — the label text (alias for .text).
var Caption: String:
	get: return text
	set(v): text = v

## Alignment — text alignment: 0=Left, 1=Right, 2=Center (VB6 convention).
@export_enum("Left:0", "Right:1", "Center:2") var Alignment: int = 0:
	get: return _alignment_vb
	set(v):
		_alignment_vb = v
		match v:
			0: horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			1: horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			2: horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

## AutoSize — if true, the label resizes to fit its text.
@export var AutoSize: bool = false:
	get: return _auto_size
	set(v):
		_auto_size = v
		clip_text = not _auto_size
		autowrap_mode = TextServer.AUTOWRAP_OFF if _auto_size else (TextServer.AUTOWRAP_WORD if _word_wrap else TextServer.AUTOWRAP_OFF)

## WordWrap — if true, text wraps to multiple lines.
@export var WordWrap: bool = false:
	get: return _word_wrap
	set(v):
		_word_wrap = v
		if _word_wrap:
			autowrap_mode = TextServer.AUTOWRAP_WORD
		else:
			autowrap_mode = TextServer.AUTOWRAP_OFF

## BackStyle — 0=Transparent (no background), 1=Opaque (draws BackColor).
@export_enum("Transparent:0", "Opaque:1") var BackStyle: int = 0:
	get: return _back_style
	set(v):
		_back_style = v
		_update_label_style()

## BackColor — background color when BackStyle=1 (Opaque).
@export var BackColor: Color = Color(0.94, 0.94, 0.94, 1.0):
	get: return _back_color
	set(v):
		_back_color = v
		_update_label_style()

## BorderStyle — 0=None, 1=FixedSingle (thin border around label).
@export_enum("None:0", "FixedSingle:1") var BorderStyle: int = 0:
	get: return _border_style
	set(v):
		_border_style = v
		_update_label_style()

## Tag — general-purpose string storage (VB6 convention).
@export var Tag: String = ""

# =============================================================================
# Construction
# =============================================================================

func _ready() -> void:
	# Only handle mouse events at runtime — not in the editor
	if not Engine.is_editor_hint():
		mouse_filter = Control.MOUSE_FILTER_STOP
	_update_label_style()

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var now := Time.get_ticks_msec()
		if now - _last_click_time < 400:
			DblClick.emit()
		else:
			Click.emit()
		_last_click_time = now

# =============================================================================
# Style management
# =============================================================================

func _update_label_style() -> void:
	var need_style := (_back_style == 1 or _border_style == 1)
	if need_style:
		var sb := StyleBoxFlat.new()
		sb.bg_color = _back_color if _back_style == 1 else Color(0, 0, 0, 0)
		if _border_style == 1:
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = Color(0.4, 0.4, 0.4, 1.0)
		sb.content_margin_left = 2
		sb.content_margin_right = 2
		add_theme_stylebox_override("normal", sb)
	else:
		remove_theme_stylebox_override("normal")
