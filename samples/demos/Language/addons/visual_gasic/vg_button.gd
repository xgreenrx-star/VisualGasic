@tool
extends Button
## VGButton — VB6-faithful CommandButton control.
##
## Wraps Godot's Button with the standard VB6 CommandButton API.
## All native Button functionality is preserved — this only ADDS the VB6 layer.
##
## VB6-compatible API:
##   Properties: Caption, Style, Default, Cancel, Tag
##   Methods:    SetFocus
##   Events:     Click

# =============================================================================
# VB6 Signals (Events)
# =============================================================================

## Click — fires when the button is pressed (VB6: Click event).
signal Click()

# =============================================================================
# Style constants (match VB6)
# =============================================================================

const vbButtonStandard: int = 0    ## Text-only button
const vbButtonGraphical: int = 1   ## Button that can display an icon/picture

# =============================================================================
# Internal state
# =============================================================================

## Storage for common VB6 properties that the Form Designer writes to .tscn.
## Accepted silently so Godot's scene loader doesn't error on unknown props.
var _vb6_props: Dictionary = {}
var _default: bool = false
var _cancel: bool = false
var _style: int = 0

# =============================================================================
# VB6 Properties
# =============================================================================

## Caption — the button text (alias for .text).
var Caption: String:
	get: return text
	set(v): text = v

## Style — 0=Standard (text), 1=Graphical (can show icon).
@export_enum("Standard:0", "Graphical:1") var Style: int = 0:
	get: return _style
	set(v):
		_style = v
		# Graphical style allows flat appearance + icon
		flat = (_style == vbButtonGraphical)

## Default — if true, pressing Enter activates this button (VB6 convention).
## Sets up an Enter key shortcut.
@export var Default: bool = false:
	get: return _default
	set(v):
		_default = v
		_update_shortcuts()

## Cancel — if true, pressing Escape activates this button (VB6 convention).
## Sets up an Escape key shortcut.
@export var Cancel: bool = false:
	get: return _cancel
	set(v):
		_cancel = v
		_update_shortcuts()

## Tag — general-purpose string storage (VB6 convention).
@export var Tag: String = ""

# =============================================================================
# VB6 Methods
# =============================================================================

## SetFocus — give keyboard focus to this control.
func SetFocus() -> void:
	grab_focus()

# =============================================================================
# Construction
# =============================================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func _on_pressed() -> void:
	Click.emit()

func _update_shortcuts() -> void:
	var events: Array[InputEvent] = []
	if _default:
		var enter_ev := InputEventKey.new()
		enter_ev.keycode = KEY_ENTER
		events.append(enter_ev)
	if _cancel:
		var esc_ev := InputEventKey.new()
		esc_ev.keycode = KEY_ESCAPE
		events.append(esc_ev)
	if events.size() > 0:
		var sc := Shortcut.new()
		sc.events = events
		shortcut = sc
	else:
		shortcut = null

# =============================================================================
# VB6 Common Property Handlers (Form Designer round-trip)
# =============================================================================

## Accepts VB6 properties written by the C++ Form Designer serializer.
## Without this, Godot's .tscn loader errors on unknown properties.
func _set(property: StringName, value: Variant) -> bool:
	var p := String(property)
	match p:
		"Enabled":
			disabled = not value
			_vb6_props[p] = value
			return true
		"TabStop":
			focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
			_vb6_props[p] = value
			return true
		"TabIndex", "MousePointer", "Appearance", "BorderStyle", \
		"FontSize", "FontBold", "FontItalic":
			_vb6_props[p] = value
			return true
		"ToolTipText":
			tooltip_text = str(value)
			_vb6_props[p] = value
			return true
		"BackColor", "ForeColor":
			_vb6_props[p] = value
			return true
		"FontName":
			_vb6_props[p] = value
			return true
	return false

func _get(property: StringName) -> Variant:
	if _vb6_props.has(String(property)):
		return _vb6_props[String(property)]
	return null
