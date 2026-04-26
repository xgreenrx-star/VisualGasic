###################################################
# Part of Bosca Ceoil Blue                        #
# Copyright (c) 2025 Yuri Sizov and contributors  #
# Provided under MIT                              #
###################################################

@tool
class_name AccentedContentEffect extends RichTextEffect

var bbcode: String = "accent"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# Embedded under VG IDE: project theme may be null and "InfoPopup" type
	# may not be registered. Guard and fall back to a sensible default.
	var theme := ThemeDB.get_project_theme()
	if theme and theme.has_color("accent_color", "InfoPopup"):
		char_fx.color = theme.get_color("accent_color", "InfoPopup")
	else:
		char_fx.color = Color(0.4, 0.7, 1.0) # default accent
	return true
