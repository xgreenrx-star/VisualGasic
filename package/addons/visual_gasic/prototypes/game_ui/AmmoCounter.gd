@tool
extends HBoxContainer
## Game UI — Ammo counter displaying clip / reserve like "30 / 120".

signal ammo_changed(current: int, reserve: int)
signal ammo_empty

# ── VB6-style properties ──────────────────────────────────────

@export var CurrentAmmo: int = 30:
	set(v):
		CurrentAmmo = maxi(v, 0)
		_update_display()
		ammo_changed.emit(CurrentAmmo, ReserveAmmo)
		if CurrentAmmo <= 0: ammo_empty.emit()

@export var MaxClip: int = 30
@export var ReserveAmmo: int = 120:
	set(v):
		ReserveAmmo = maxi(v, 0)
		_update_display()

@export var ShowIcon: bool = true:
	set(v):
		ShowIcon = v
		if _icon_label: _icon_label.visible = v

@export var AmmoColor: Color = Color(1.0, 1.0, 1.0):
	set(v):
		AmmoColor = v
		_update_display()

@export var LowAmmoColor: Color = Color(1.0, 0.3, 0.2):
	set(v):
		LowAmmoColor = v
		_update_display()

@export_range(0.0, 1.0, 0.05) var LowAmmoThreshold: float = 0.25
@export var FontSize: int = 16:
	set(v):
		FontSize = clampi(v, 8, 48)
		_update_display()

@export var IconText: String = "⊕":
	set(v):
		IconText = v
		if _icon_label: _icon_label.text = v

var _icon_label: Label
var _current_label: Label
var _slash_label: Label
var _reserve_label: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	custom_minimum_size = Vector2(110, 28)
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_CENTER

	# Icon
	_icon_label = Label.new()
	_icon_label.text = IconText
	_icon_label.add_theme_font_size_override("font_size", FontSize)
	_icon_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_icon_label.visible = ShowIcon
	add_child(_icon_label)

	# Current ammo
	_current_label = Label.new()
	_current_label.add_theme_font_size_override("font_size", FontSize)
	_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_current_label.custom_minimum_size = Vector2(32, 0)
	add_child(_current_label)

	# Slash
	_slash_label = Label.new()
	_slash_label.text = "/"
	_slash_label.add_theme_font_size_override("font_size", FontSize - 2)
	_slash_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	add_child(_slash_label)

	# Reserve
	_reserve_label = Label.new()
	_reserve_label.add_theme_font_size_override("font_size", FontSize - 2)
	_reserve_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	add_child(_reserve_label)

	_update_display()

func _update_display() -> void:
	if not _current_label: return
	var is_low := MaxClip > 0 and float(CurrentAmmo) / MaxClip <= LowAmmoThreshold
	var col: Color = LowAmmoColor if is_low else AmmoColor
	_current_label.text = str(CurrentAmmo)
	_current_label.add_theme_color_override("font_color", col)
	_current_label.add_theme_font_size_override("font_size", FontSize)
	if _reserve_label:
		_reserve_label.text = str(ReserveAmmo)
		_reserve_label.add_theme_font_size_override("font_size", FontSize - 2)

func reload() -> void:
	var needed := MaxClip - CurrentAmmo
	var take := mini(needed, ReserveAmmo)
	ReserveAmmo -= take
	CurrentAmmo += take

func fire(rounds: int = 1) -> void:
	CurrentAmmo = maxi(CurrentAmmo - rounds, 0)
