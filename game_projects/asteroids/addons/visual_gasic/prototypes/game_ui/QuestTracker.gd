@tool
extends PanelContainer
## Game UI — Quest tracker sidebar showing active quests with objectives.

signal quest_clicked(quest_index: int)
signal objective_completed(quest_index: int, objective_index: int)

# ── VB6-style properties ──────────────────────────────────────

@export var TrackerTitle: String = "QUESTS":
	set(v):
		TrackerTitle = v
		if _title_label: _title_label.text = v

@export var QuestNames: String = "Find the Lost Sword,Defeat the Dragon":
	set(v):
		QuestNames = v
		_rebuild_quests()

@export var ShowObjectives: bool = true
@export var MaxVisible: int = 5
@export_enum("FadeIn", "SlideRight", "None") var ShowAnimation: int = 0
@export var TransitionSpeed: float = 0.3
@export var TitleColor: Color = Color(1.0, 0.85, 0.3)
@export var QuestColor: Color = Color(0.9, 0.9, 0.95)
@export var CompletedColor: Color = Color(0.5, 0.7, 0.5, 0.6)

var _title_label: Label
var _quest_vbox: VBoxContainer
var _tween: Tween

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for c in get_children(): c.queue_free()
	custom_minimum_size = Vector2(220, 120)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	style.border_color = Color(0.3, 0.35, 0.5, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = TrackerTitle
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", TitleColor)
	_title_label.uppercase = true
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	vbox.add_child(sep)

	_quest_vbox = VBoxContainer.new()
	_quest_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_quest_vbox)

	_rebuild_quests()

	if Engine.is_editor_hint():
		visible = true
		modulate = Color(1, 1, 1, 1)

func _rebuild_quests() -> void:
	if not _quest_vbox: return
	for c in _quest_vbox.get_children(): c.queue_free()

	var names := QuestNames.split(",")
	var objectives_list := [
		["Search the ancient ruins", "Speak to the blacksmith"],
		["Travel to Dragon Peak", "Slay the dragon", "Collect the reward"]
	]
	for i in range(mini(names.size(), MaxVisible)):
		var quest_vbox := VBoxContainer.new()
		quest_vbox.add_theme_constant_override("separation", 2)
		_quest_vbox.add_child(quest_vbox)

		var name_label := Label.new()
		name_label.text = "◆ " + names[i].strip_edges()
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", QuestColor)
		quest_vbox.add_child(name_label)

		if ShowObjectives and i < objectives_list.size():
			for obj in objectives_list[i]:
				var obj_label := Label.new()
				obj_label.text = "  ○ " + obj
				obj_label.add_theme_font_size_override("font_size", 10)
				obj_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
				quest_vbox.add_child(obj_label)
