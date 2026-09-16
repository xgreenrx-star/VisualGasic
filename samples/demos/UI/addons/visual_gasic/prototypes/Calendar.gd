# Calendar.gd
# VB6-style Calendar control with date selection
# Configurable properties: Value (selected date), Year, Month
@tool
extends PanelContainer

signal date_selected(date: Dictionary)
signal month_changed(year: int, month: int)

## The currently selected date
@export var value: String = "":
	set(v):
		value = v
		if v.is_empty():
			_selected_day = 0
		else:
			var parts = v.split("/")
			if parts.size() >= 3:
				_current_month = int(parts[0])
				_selected_day = int(parts[1])
				_current_year = int(parts[2])
		_rebuild_calendar()
	get:
		if _selected_day > 0:
			return "%02d/%02d/%04d" % [_current_month, _selected_day, _current_year]
		return ""

## Current year displayed
@export var year: int = 2026:
	set(v):
		_current_year = v
		_rebuild_calendar()
	get:
		return _current_year

## Current month displayed (1-12)
@export_range(1, 12) var month: int = 2:
	set(v):
		_current_month = clampi(v, 1, 12)
		_rebuild_calendar()
	get:
		return _current_month

## Show week numbers
@export var show_week_numbers: bool = false:
	set(v):
		show_week_numbers = v
		_rebuild_calendar()

## First day of week (0=Sunday, 1=Monday)
@export_range(0, 1) var first_day_of_week: int = 0:
	set(v):
		first_day_of_week = v
		_rebuild_calendar()

## Highlight today
@export var highlight_today: bool = true

var _current_year: int = 2026
var _current_month: int = 2
var _selected_day: int = 0
var _days_grid: GridContainer
var _month_label: Label
var _day_buttons: Array[Button] = []

const MONTH_NAMES = ["", "January", "February", "March", "April", "May", "June",
					 "July", "August", "September", "October", "November", "December"]
const DAY_NAMES_SHORT = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

func _ready():
	# Initialize with current date if not set
	if _current_year == 0:
		var now = Time.get_datetime_dict_from_system()
		_current_year = now.year
		_current_month = now.month
	
	_build_ui()
	_rebuild_calendar()

func _build_ui():
	custom_minimum_size = Vector2(200, 200)
	
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)
	
	# Header with nav buttons
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var prev_btn = Button.new()
	prev_btn.text = "<"
	prev_btn.pressed.connect(_on_prev_month)
	header.add_child(prev_btn)
	
	_month_label = Label.new()
	_month_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_month_label)
	
	var next_btn = Button.new()
	next_btn.text = ">"
	next_btn.pressed.connect(_on_next_month)
	header.add_child(next_btn)
	
	# Day names header
	var days_header = HBoxContainer.new()
	vbox.add_child(days_header)
	
	for i in range(7):
		var day_idx = (i + first_day_of_week) % 7
		var lbl = Label.new()
		lbl.text = DAY_NAMES_SHORT[day_idx]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		days_header.add_child(lbl)
	
	# Days grid
	_days_grid = GridContainer.new()
	_days_grid.columns = 7
	_days_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_days_grid)
	
	# Create 42 day buttons (6 weeks max)
	_day_buttons.clear()
	for i in range(42):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(24, 24)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_day_pressed.bind(i))
		_days_grid.add_child(btn)
		_day_buttons.append(btn)

func _rebuild_calendar():
	if not _month_label or _day_buttons.is_empty():
		return
	
	# Update header
	_month_label.text = "%s %d" % [MONTH_NAMES[_current_month], _current_year]
	
	# Get first day of month and days in month
	var first_day = _get_day_of_week(_current_year, _current_month, 1)
	var days_in_month = _get_days_in_month(_current_year, _current_month)
	var days_in_prev_month = _get_days_in_month(_current_year if _current_month > 1 else _current_year - 1, 
												_current_month - 1 if _current_month > 1 else 12)
	
	# Adjust for first day of week setting
	var start_offset = (first_day - first_day_of_week + 7) % 7
	
	# Get today for highlighting
	var today = Time.get_datetime_dict_from_system()
	
	# Fill in days
	var day = 1
	var next_month_day = 1
	
	for i in range(42):
		var btn = _day_buttons[i]
		
		if i < start_offset:
			# Previous month days
			var prev_day = days_in_prev_month - start_offset + i + 1
			btn.text = str(prev_day)
			btn.modulate = Color(0.5, 0.5, 0.5, 1)
			btn.flat = true
		elif day <= days_in_month:
			# Current month days
			btn.text = str(day)
			btn.modulate = Color(1, 1, 1, 1)
			btn.flat = false
			
			# Highlight selected day
			if day == _selected_day:
				btn.modulate = Color(0.3, 0.5, 1, 1)
			# Highlight today
			elif highlight_today and day == today.day and _current_month == today.month and _current_year == today.year:
				btn.modulate = Color(1, 0.8, 0.3, 1)
			
			day += 1
		else:
			# Next month days
			btn.text = str(next_month_day)
			btn.modulate = Color(0.5, 0.5, 0.5, 1)
			btn.flat = true
			next_month_day += 1

func _on_prev_month():
	_current_month -= 1
	if _current_month < 1:
		_current_month = 12
		_current_year -= 1
	_selected_day = 0
	_rebuild_calendar()
	month_changed.emit(_current_year, _current_month)

func _on_next_month():
	_current_month += 1
	if _current_month > 12:
		_current_month = 1
		_current_year += 1
	_selected_day = 0
	_rebuild_calendar()
	month_changed.emit(_current_year, _current_month)

func _on_day_pressed(button_idx: int):
	var first_day = _get_day_of_week(_current_year, _current_month, 1)
	var start_offset = (first_day - first_day_of_week + 7) % 7
	var days_in_month = _get_days_in_month(_current_year, _current_month)
	
	var day = button_idx - start_offset + 1
	
	if day >= 1 and day <= days_in_month:
		_selected_day = day
		_rebuild_calendar()
		date_selected.emit({"year": _current_year, "month": _current_month, "day": _selected_day})

func _get_day_of_week(y: int, m: int, d: int) -> int:
	# Zeller's formula to get day of week (0=Sunday)
	if m < 3:
		m += 12
		y -= 1
	var k = y % 100
	var j = y / 100
	var h = (d + (13 * (m + 1)) / 5 + k + k / 4 + j / 4 - 2 * j) % 7
	return ((h + 6) % 7)  # Convert to 0=Sunday

func _get_days_in_month(y: int, m: int) -> int:
	match m:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			if (y % 4 == 0 and y % 100 != 0) or (y % 400 == 0):
				return 29
			return 28
	return 30

## Set the calendar to a specific date
func set_date(y: int, m: int, d: int):
	_current_year = y
	_current_month = clampi(m, 1, 12)
	_selected_day = clampi(d, 1, _get_days_in_month(_current_year, _current_month))
	_rebuild_calendar()

## Get the selected date as a Dictionary
func get_date() -> Dictionary:
	return {"year": _current_year, "month": _current_month, "day": _selected_day}

## Go to today's date
func go_to_today():
	var now = Time.get_datetime_dict_from_system()
	set_date(now.year, now.month, now.day)
