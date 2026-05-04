@tool
extends AcceptDialog
class_name VGFirstRunDialog
## First-run welcome / project-type picker.
##
## Shown the very first time VisualGasic opens a project that contains no
## `.vg`, `.frm`, or `.vgform` files AND has no `vg/default_mode` set.
## The user's pick writes:
##   - vg/default_mode = "code" | "forms"
##   - vg/form_designer_enabled = true | false
##   - vg/first_run_completed = true
##
## Subsequent project opens read those settings and never show this dialog
## again (even if the user empties the project).
##
## Three options:
##   📝 Empty Code Project   — code editor first; Form Designer disabled
##   🎨 Form Application     — Form Designer first (legacy VB6-style flow)
##   🎮 AGCK Game            — code editor first; user can open AGCK manually
##
## Cancel / Esc is treated as "Empty Code Project" so a stray Esc doesn't
## leave the project in a half-configured state.

signal project_type_chosen(kind: String)  # "code" | "forms" | "agck"

const _TYPES := [
	{
		"kind": "code",
		"emoji": "📝",
		"title": "Empty Code Project",
		"blurb": "Start with a blank module in the code editor.\nBest for utilities, CLI tools, libraries, and most games.",
	},
	{
		"kind": "forms",
		"emoji": "🎨",
		"title": "Form Application",
		"blurb": "VB6-style: open the Form Designer with a blank Form1.\nBest for desktop GUI apps with buttons, labels, and dialogs.",
	},
	{
		"kind": "agck",
		"emoji": "🎮",
		"title": "AGCK Game Project",
		"blurb": "Code-first project with AGCK plugin available.\nOpen the AGCK panel to pick a game template.",
	},
]


func _init() -> void:
	title = "Welcome to VisualGasic"
	dialog_hide_on_ok = true
	dialog_close_on_escape = true
	min_size = Vector2(560, 320)
	exclusive = false
	# Hide the default OK button — we use our own typed buttons below.
	get_ok_button().visible = false


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var heading := Label.new()
	heading.text = "What kind of project is this?"
	heading.add_theme_font_size_override("font_size", 18)
	root.add_child(heading)

	var sub := Label.new()
	sub.text = "Pick a starting point. You can change this later under\nProject Settings → vg → default_mode and the Plugin Settings dialog."
	sub.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	root.add_child(sub)

	root.add_child(HSeparator.new())

	for entry in _TYPES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		root.add_child(row)

		var btn := Button.new()
		btn.text = "%s  %s" % [entry["emoji"], entry["title"]]
		btn.custom_minimum_size = Vector2(220, 64)
		btn.pressed.connect(_on_type_pressed.bind(entry["kind"]))
		row.add_child(btn)

		var blurb := Label.new()
		blurb.text = entry["blurb"]
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		blurb.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		row.add_child(blurb)


func _on_type_pressed(kind: String) -> void:
	project_type_chosen.emit(kind)
	hide()
	queue_free()


## Convenience: write the user's choice to ProjectSettings and save.
## Call this from the host plugin's signal handler.
static func apply_choice(kind: String) -> void:
	match kind:
		"code", "agck":
			ProjectSettings.set_setting("vg/default_mode", "code")
			ProjectSettings.set_setting("vg/form_designer_enabled", false)
		"forms":
			ProjectSettings.set_setting("vg/default_mode", "forms")
			ProjectSettings.set_setting("vg/form_designer_enabled", true)
		_:
			ProjectSettings.set_setting("vg/default_mode", "code")
			ProjectSettings.set_setting("vg/form_designer_enabled", false)
	ProjectSettings.set_setting("vg/first_run_completed", true)
	var err := ProjectSettings.save()
	if err != OK:
		push_warning("VGFirstRunDialog: ProjectSettings.save() returned " + str(err))
