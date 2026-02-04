@tool
extends Control

# Visual Gasic CommonDialog Wrapper
# Behaves like the VB6 CommonDialog: An icon at design time, invisible at runtime (until Show is called).

@onready var dialog = $FileDialog
@onready var icon = $Icon

# Properties exposed to VisualGasic
var FileName: String:
	set(v): 
		if dialog: dialog.current_file = v
	get: 
		if dialog: return dialog.current_file
		return ""

var FileTitle: String: # Name without path
	get:
		if dialog: return dialog.current_file.get_file()
		return ""

var Filter: String:
	set(v):
		if dialog:
			# VB6 Format: "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
			# Godot Format: PackedStringArray("*.txt ; Text Files", "*.* ; All Files")
			var godot_filters = PackedStringArray()
			var parts = v.split("|")
			# Expect pairs: Description|Pattern
			var i = 0
			while i < parts.size() - 1:
				var desc = parts[i]
				var pat = parts[i+1]
				godot_filters.append(pat + " ; " + desc)
				i += 2
			dialog.filters = godot_filters
	get:
		return "WIP Filter Getter" # Complex to reverse

var DialogTitle: String:
	set(v):
		if dialog: dialog.title = v
	get:
		if dialog: return dialog.title
		return ""

var InitDir: String:
	set(v):
		if dialog: dialog.current_dir = v
	get:
		if dialog: return dialog.current_dir
		return ""

func _ready():
	if Engine.is_editor_hint():
		# In Editor: Show Icon
		visible = true
		if icon: icon.visible = true
	else:
		# In Runtime: Hide Control wrapper (so it doesn't block mouse), Icon invisible
		# The Dialog is a PopupWindow, so it handles its own visibility
		visible = false 

func ShowOpen():
	if dialog:
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dialog.show()

func ShowSave():
	if dialog:
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dialog.show()
