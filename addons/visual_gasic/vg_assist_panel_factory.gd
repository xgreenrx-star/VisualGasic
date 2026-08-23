@tool
extends RefCounted
## Builds the shared Help + Sprite tab panel used in VG IDE and floating window.

const SpritePanelScript := preload("res://addons/visual_gasic/vg_sprite_data_panel.gd")


static func create_panel() -> Dictionary:
	var root := VBoxContainer.new()
	root.name = "VGAssistPanel"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	# --- Help tab ---
	var help_box := VBoxContainer.new()
	help_box.name = "HelpTab"
	var help_scroll := ScrollContainer.new()
	help_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	help_box.add_child(help_scroll)
	var help_label := RichTextLabel.new()
	help_label.bbcode_enabled = true
	help_label.fit_content = true
	help_label.scroll_active = false
	help_label.selection_enabled = true
	help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_label.add_theme_font_size_override("normal_font_size", 11)
	help_label.add_theme_color_override("default_color", Color(0.1, 0.1, 0.1))
	var help_sb := StyleBoxFlat.new()
	help_sb.bg_color = Color(0.96, 0.95, 0.92)
	help_sb.content_margin_left = 6
	help_sb.content_margin_right = 4
	help_sb.content_margin_top = 4
	help_sb.content_margin_bottom = 4
	help_label.add_theme_stylebox_override("normal", help_sb)
	help_label.text = ""
	help_label.append_text("[color=#555555][i]Place the cursor on a keyword to see its documentation.[/i][/color]")
	help_scroll.add_child(help_label)
	tabs.add_child(help_box)
	tabs.set_tab_title(0, "Help")

	# --- Sprite tab ---
	var sprite_panel: VBoxContainer = SpritePanelScript.new()
	sprite_panel.name = "SpriteTab"
	tabs.add_child(sprite_panel)
	tabs.set_tab_title(1, "Sprite")

	return {
		"root": root,
		"tabs": tabs,
		"help_scroll": help_scroll,
		"help_label": help_label,
		"sprite_panel": sprite_panel,
		"state": {"last_keyword": ""},
	}
