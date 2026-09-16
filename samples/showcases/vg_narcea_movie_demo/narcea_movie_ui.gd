extends PanelContainer
## Fake Narcea AI Pair panel for movie capture (not the real editor dock).

@onready var _provider: Label = $RootVBox/Chrome/ProviderRow/Provider
@onready var _segment_label: Label = $RootVBox/Chrome/ProviderRow/Segment
@onready var _refs_row: HBoxContainer = $RootVBox/Chrome/RefsRow
@onready var _prompt_label: RichTextLabel = $RootVBox/Body/PromptBlock/PromptText
@onready var _response_label: RichTextLabel = $RootVBox/Body/ResponseBlock/ResponseText
@onready var _apply_btn: Button = $RootVBox/Chrome/ApplyBtn
@onready var _status: Label = $RootVBox/Chrome/Status


func _ready() -> void:
	_apply_btn.visible = false
	_clear_refs()
	reset_panel()


func reset_panel() -> void:
	_prompt_label.text = ""
	_response_label.text = ""
	_apply_btn.visible = false
	_apply_btn.modulate = Color(1, 1, 1, 1)
	_status.text = "Ready"


func show_title(_headline: String, _subline: String, _provider: String) -> void:
	reset_panel()


func begin_segment(label: String, provider: String) -> void:
	reset_panel()
	_provider.text = provider
	_segment_label.text = label
	_status.text = "Waiting for prompt…"


func set_references(refs: Array) -> void:
	_clear_refs()
	for item in refs:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var chip := Label.new()
		chip.text = "🌐 %s" % str(item.get("label", "Reference"))
		chip.add_theme_font_size_override("font_size", 13)
		chip.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		_refs_row.add_child(chip)
	if refs.size() > 0:
		_status.text = "Reference attached — sending to Cursor…"


func play_prompt(text: String, chars_per_sec: float) -> void:
	_prompt_label.text = ""
	_status.text = "You →"
	await _type_into(_prompt_label, text, chars_per_sec)


func play_response(text: String, chars_per_sec: float) -> void:
	_response_label.text = ""
	_status.text = "⬡ Cursor (Composer) streaming…"
	await _type_into(_response_label, text, chars_per_sec)


func flash_apply() -> void:
	_apply_btn.visible = true
	_apply_btn.text = "Apply ✓"
	_status.text = "Applied to project"
	var tw := create_tween()
	tw.tween_property(_apply_btn, "modulate", Color(0.4, 1.0, 0.55, 1.0), 0.15)
	tw.tween_property(_apply_btn, "modulate", Color(1, 1, 1, 1), 0.35)


func show_code_review(path: String) -> void:
	var fname := path.get_file()
	_status.text = "Scrolling generated code — %s" % fname
	_response_label.text = "[i]Quick source preview[/i] — [color=#7ec8ff]%s[/color]" % path.replace("res://", "")


func show_end(end: Dictionary) -> void:
	reset_panel()
	_segment_label.text = "End card"
	_status.text = str(end.get("subline", ""))
	_prompt_label.text = "[i]Demonstration only — not a live IDE recording.[/i]"
	_response_label.text = str(end.get("panel_text", end.get("body", "")))


func _clear_refs() -> void:
	for c in _refs_row.get_children():
		c.queue_free()


func _type_into(label: RichTextLabel, full_text: String, chars_per_sec: float) -> void:
	var delay := 1.0 / maxf(chars_per_sec, 12.0)
	var shown := ""
	for i in full_text.length():
		if not is_inside_tree():
			return
		shown += full_text.substr(i, 1)
		label.text = shown
		await get_tree().create_timer(delay).timeout
