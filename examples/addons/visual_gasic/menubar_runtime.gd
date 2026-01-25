@tool
extends MenuBar
## Runtime script for MenuBar to restore menu captions
## Automatically attached by the menu editor

func _ready():
	if Engine.is_editor_hint():
		return
	
	# Restore menu titles from metadata
	if has_meta("_menu_captions"):
		var captions_dict = get_meta("_menu_captions")
		for i in range(get_menu_count()):
			var popup = get_menu_popup(i)
			if popup and captions_dict.has(popup.name):
				var caption = captions_dict[popup.name]
				set_menu_title(i, caption)
				print("MenuBar: Restored caption '", caption, "' for menu ", i, " (", popup.name, ")")
	else:
		# Fallback: clean up names
		for i in range(get_menu_count()):
			var popup = get_menu_popup(i)
			if popup:
				var caption = popup.name
				if caption.begins_with("mnu"):
					caption = caption.substr(3)
				set_menu_title(i, caption)
