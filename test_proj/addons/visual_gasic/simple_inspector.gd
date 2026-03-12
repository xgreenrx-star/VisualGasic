@tool
extends VBoxContainer

# VB6-Style Property Inspector for Visual Gasic
# Shows properties similar to VB6's Properties Window
# Features: Object dropdown, Alphabetic/Categorized toggle, Description area

var editor_plugin: EditorPlugin
var property_grid: GridContainer
var _scroll_container: ScrollContainer
var current_node: Node
var rename_dialog: ConfirmationDialog
var _chk_unchecked_icon: ImageTexture
var _chk_checked_icon: ImageTexture
var _filter_edit: LineEdit  ## Search/filter input at top of properties
var _prop_row_index: int = 0  ## Row counter for zebra-striping
var old_name_for_rename: String = ""
var new_name_for_rename: String = ""

# === Form Designer mode ===
# When editing controls on the C++ FormDesigner canvas (not scene-tree nodes),
# we store the designer reference and the selected control index.
var _fd_mode: bool = false          # true = showing FormDesigner control props
var _fd_form_mode: bool = false     # true = showing form-level (not control) props
var _fd_designer = null             # Reference to VisualGasicFormDesigner instance
var _fd_control_index: int = -1     # Index of the control in the designer

# === VB6 UI: Object dropdown ===
var _object_dropdown: OptionButton
var _all_form_nodes: Array = []

# === VB6 UI: Alphabetic / Categorized toggle ===
var _view_mode: int = 1  # 0 = Alphabetic, 1 = Categorized
var _alpha_btn: Button
var _cat_btn: Button
# Store property data for alphabetic re-sort
var _property_entries: Array = []  # Array of {label, value, prop_key, type, category}

# === VB6 UI: Property description area ===
var _description_label: RichTextLabel
var _selected_prop_key: String = ""

# VB6-like property categories
const CATEGORY_APPEARANCE = "Appearance"
const CATEGORY_BEHAVIOR = "Behavior"
const CATEGORY_FONT = "Font"
const CATEGORY_POSITION = "Position"
const CATEGORY_MISC = "Misc"

# Property help descriptions (VB6-style)
const PROPERTY_DESCRIPTIONS: Dictionary = {
	"name": "Returns the name used in code to identify a control.",
	"text": "Returns/sets the text contained in the control.",
	"visible": "Returns/sets whether the control is visible at runtime.",
	"enabled": "Returns/sets a value that determines whether the control can respond to user-generated events.",
	"left": "Returns/sets the distance between the internal left edge of the control and the left edge of its container.",
	"top": "Returns/sets the distance between the internal top edge of the control and the top edge of its container.",
	"width": "Returns/sets the width of the control.",
	"height": "Returns/sets the height of the control.",
	"backcolor": "Returns/sets the background color used to display text and graphics in a control.",
	"forecolor": "Returns/sets the foreground color used to display text and graphics in a control.",
	"font_size": "Returns/sets the size of the font used in the control.",
	"tooltip_text": "Returns/sets the text displayed when the user pauses the mouse pointer over a control.",
	"tag": "Stores any extra data needed for your program. A general-purpose string.",
	"tabstop": "Returns/sets whether the user can use TAB to give the focus to a control.",
	"flat": "Returns/sets whether a Button appears 3D (raised) or flat.",
	"alignment": "Returns/sets the alignment of text in a Label control (Left, Center, Right).",
	"autosize": "Returns/sets whether a Label automatically resizes to fit its contents.",
	"wordwrap": "Returns/sets whether a Label wraps text to the next line.",
	"locked": "Returns/sets whether the control's content can be edited by the user.",
	"max_length": "Returns/sets the maximum number of characters a user can enter in the TextBox.",
	"secret": "Returns/sets whether the TextBox displays password characters instead of text.",
	"placeholder_text": "Returns/sets the grayed-out text displayed when the TextBox is empty.",
	"button_pressed": "Returns/sets the current state of a CheckBox or OptionButton.",
	"default": "Returns/sets whether a command button is the default button for a form.",
	"cancel": "Returns/sets whether a command button is the Cancel button for a form.",
	"opacity": "Returns/sets the opacity level of the control (0-100%).",
	"rotation": "Returns/sets the rotation angle of the control in degrees.",
	"scale_x": "Returns/sets the horizontal scale factor of the control.",
	"scale_y": "Returns/sets the vertical scale factor of the control.",
	"min_width": "Returns/sets the minimum width constraint for responsive layout.",
	"min_height": "Returns/sets the minimum height constraint for responsive layout.",
	"clip_contents": "Returns/sets whether child controls are clipped to the control boundary.",
	"anchor": "Returns/sets how the control is anchored to its parent for responsive layout.",
	"pivot": "Returns/sets the rotation/scale pivot point of the control.",
	"cursor": "Returns/sets the type of mouse pointer displayed when over the control.",
	"range_value": "Returns/sets the current value of a scrollbar, slider, or progress bar.",
	"range_min": "Returns/sets the minimum value of a scrollbar, slider, or progress bar.",
	"range_max": "Returns/sets the maximum value of a scrollbar, slider, or progress bar.",
	"range_step": "Returns/sets the increment amount for scrollbar or slider changes.",
	"show_percentage": "Returns/sets whether the ProgressBar displays its value as a percentage.",
	"spinbox_prefix": "Returns/sets the text displayed before the SpinBox value.",
	"spinbox_suffix": "Returns/sets the text displayed after the SpinBox value.",
	# Form Designer properties (VB6 complete set)
	"caption": "Returns/sets the text displayed in the control's title bar or on its face.",
	"borderstyle": "Returns/sets the border style for a control. 0=None, 1=Fixed Single.",
	"appearance": "Returns/sets whether a control is painted at run time with 3D effects. 0=Flat, 1=3D.",
	"startposition": "Returns/sets the position of a Form when it first appears. 0=Manual, 1=CenterOwner, 2=CenterScreen, 3=WindowsDefault.",
	"windowstate": "Returns/sets the visual state of the form at run time. 0=Normal, 1=Minimized, 2=Maximized.",
	"controlbox": "Returns/sets whether a Control-menu box is displayed on the form at run time.",
	"minbutton": "Returns/sets whether a form has a Minimize button.",
	"maxbutton": "Returns/sets whether a form has a Maximize button.",
	"moveable": "Returns/sets whether the form can be moved at run time.",
	"showintaskbar": "Returns/sets whether the form appears in the Windows taskbar.",
	"icon": "Returns/sets the icon displayed for a Form in the title bar and taskbar.",
	"keypreview": "Returns/sets whether keyboard events for the form are invoked before keyboard events for controls.",
	"autoredraw": "Returns/sets whether Form_Paint events are handled automatically.",
	"picturebox": "Returns/sets the graphic to be displayed in a PictureBox or Image control.",
	"stretch": "Returns/sets whether a graphic resizes to fit the size of an Image control.",
	"multiline": "Returns/sets whether a TextBox can accept multiple lines of text.",
	"scrollbars": "Returns/sets what type of scrollbars a control has. 0=None, 1=Horizontal, 2=Vertical, 3=Both.",
	"style": "Returns/sets the visual style of a control. 0=Standard, 1=Graphical.",
	"interval": "Returns/sets the number of milliseconds between calls to a Timer control's Timer event.",
	"sorted": "Returns/sets whether items in a ListBox are sorted alphabetically.",
	"multiselect": "Returns/sets whether a ListBox allows multiple selections. 0=None, 1=Simple, 2=Extended.",
	"columns": "Returns/sets the number of columns in a ListBox.",
	"tabindex": "Returns/sets the tab order of the control within its container.",
	"cancel_button": "Returns/sets whether a command button is the Cancel button for a form.",
	"default_button": "Returns/sets whether a command button is the default button for a form.",
	"index": "Returns the index of the control in the Form Designer's control array.",
	"windowtype": "Returns/sets the window type for the form. Game=SubViewport, Windows=Window, Linux=Window+CSD, Mac=Window+CSD.",
	"Opacity": "Returns/sets the opacity of the control (0 = fully transparent, 100 = fully opaque).",
	"Rotation": "Returns/sets the rotation of the control in degrees.",
	"ScaleX": "Returns/sets the horizontal scale factor of the control (1.0 = normal).",
	"ScaleY": "Returns/sets the vertical scale factor of the control (1.0 = normal).",
	"ClipContents": "Returns/sets whether child controls are clipped to this control's boundaries.",
	"MinWidth": "Returns/sets the minimum width constraint for the control.",
	"MinHeight": "Returns/sets the minimum height constraint for the control.",
	"Flat": "Returns/sets whether a Button appears 3D (raised) or flat.",
	"Icon": "Returns/sets the path to an icon texture displayed on the Button.",
	"IconAlignment": "Returns/sets which side of the Button the icon appears on (Left, Center, Right).",
	"VerticalAlignment": "Returns/sets the vertical alignment of text in a Label (Top, Center, Bottom).",
	"MaxLinesVisible": "Returns/sets the maximum number of visible lines in a Label. -1 means no limit.",
	"ClearButton": "Returns/sets whether the TextBox displays a clear (×) button when it contains text.",
	"SelectAllOnFocus": "Returns/sets whether all text is automatically selected when the TextBox receives focus.",
	"Editable": "Returns/sets whether the user can edit the content of the control.",
	"ShowPercentage": "Returns/sets whether a ProgressBar displays its value as a percentage.",
	"FillMode": "Returns/sets the fill direction of a ProgressBar (Left to Right, Right to Left, Top to Bottom, Bottom to Top).",
	"StretchMode": "Returns/sets how a PictureBox image is stretched to fit the control.",
	"FlipH": "Returns/sets whether the image is flipped horizontally.",
	"FlipV": "Returns/sets whether the image is flipped vertically.",
	"ShapeColor": "Returns/sets the fill color of a Shape (ColorRect) control.",
	"IconMode": "Returns/sets how icons are displayed in a ListBox (Top, Left).",
	"MaxColumns": "Returns/sets the maximum number of columns in a ListBox. 0 = as many as fit.",
	"FixedColumnWidth": "Returns/sets a fixed width for columns in a ListBox. 0 = auto.",
	"HideRoot": "Returns/sets whether the root item of a TreeView is hidden.",
	"HideFolding": "Returns/sets whether the folding arrows in a TreeView are hidden.",
	"CurrentTab": "Returns/sets the currently active tab index in a TabStrip control.",
	"TabAlignment": "Returns/sets the alignment of tabs (Left, Center, Right).",
	"Prefix": "Returns/sets the text displayed before the SpinBox value.",
	"Suffix": "Returns/sets the text displayed after the SpinBox value.",
	"Wrap": "Returns/sets whether a SpinBox wraps from Max to Min and vice versa.",
	"ListItems": "Returns/sets the items in the list, separated by | characters.",
	"FontUnderline": "Returns/sets whether the font is underlined.",
	"FontStrikethrough": "Returns/sets whether the font has a strikethrough.",
	# Game UI prototype properties
	"ItemCount": "Returns/sets the number of items (wedges) displayed in the control.",
	"Radius": "Returns/sets the outer radius of the control in pixels.",
	"ItemLabels": "Returns/sets comma-separated labels for each item (e.g. 'Attack,Defend,Magic').",
	"CenterRadius": "Returns/sets the radius of the center dead zone.",
	"SelectedIndex": "Returns/sets the currently selected item index (-1 = none).",
	"ShowAnimation": "Returns/sets the animation played when the control appears.",
	"HideAnimation": "Returns/sets the animation played when the control disappears.",
	"TransitionSpeed": "Returns/sets the animation duration in seconds.",
	"WedgeColor": "Returns/sets the default fill color for wedge segments.",
	"SelectedColor": "Returns/sets the highlight color for the selected wedge.",
	"BorderColor": "Returns/sets the color of wedge border lines.",
	"Value": "Returns/sets the current value of the control.",
	"MaxValue": "Returns/sets the maximum value of the control.",
	"BarColor": "Returns/sets the fill color of the progress/stat bar.",
	"TrailColor": "Returns/sets the trailing damage color of the stat bar.",
	"BackgroundColor": "Returns/sets the background color behind the bar.",
	"ShowLabel": "Returns/sets whether a text label is displayed on the bar.",
	"LabelFormat": "Returns/sets the label format string. Use {value} and {max} as placeholders.",
	"TrailDelay": "Returns/sets the delay before the trail bar catches up (seconds).",
	"Rows": "Returns/sets the number of rows in the grid.",
	"Columns": "Returns/sets the number of columns in the grid.",
	"SlotSize": "Returns/sets the size of each slot in pixels.",
	"SlotSpacing": "Returns/sets the spacing between slots in pixels.",
	"SlotColor": "Returns/sets the default background color of inventory slots.",
	"SlotHoverColor": "Returns/sets the highlight color when hovering over a slot.",
	"SelectedSlot": "Returns/sets the currently selected slot as 'row,col'.",
	"CurrentAmmo": "Returns/sets the current ammo count in the active clip.",
	"MaxClip": "Returns/sets the maximum ammo capacity of one clip.",
	"ReserveAmmo": "Returns/sets the total reserve ammo count.",
	"AmmoColor": "Returns/sets the text color for normal ammo display.",
	"LowAmmoColor": "Returns/sets the text color when ammo is below the low threshold.",
	"LowAmmoThreshold": "Returns/sets the fraction (0-1) below which ammo is considered low.",
	"IconText": "Returns/sets the text or emoji used as the ammo icon.",
	"Title": "Returns/sets the title text displayed at the top of the control.",
	"Buttons": "Returns/sets the button labels as a comma-separated list.",
	"DimColor": "Returns/sets the color of the dim overlay behind the menu.",
	"TitleFontSize": "Returns/sets the font size for the title text.",
	"ButtonFontSize": "Returns/sets the font size for button labels.",
	"ButtonMinWidth": "Returns/sets the minimum width of menu buttons.",
	"SpeakerName": "Returns/sets the name of the current speaker.",
	"DialogText": "Returns/sets the dialog text to display with typewriter effect.",
	"TypewriterSpeed": "Returns/sets the seconds between each character in the typewriter effect.",
	"CurrentXP": "Returns/sets the current experience points.",
	"MaxXP": "Returns/sets the XP required to reach the next level.",
	"Level": "Returns/sets the current character level.",
	"Segments": "Returns/sets the number of bar segments.",
	"BarHeight": "Returns/sets the height of the bar in pixels.",
	"BarWidth": "Returns/sets the width of the bar in pixels.",
	"FillColor": "Returns/sets the color of filled bar segments.",
	"EmptyColor": "Returns/sets the color of empty bar segments.",
	"SegmentBorderColor": "Returns/sets the border color between bar segments.",
	"FontSize": "Returns/sets the size of the font used in the control.",
}

func _init():
	name = "Properties"
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(100, 80)  # Reduced further for narrower right panel
	
	# === 1. Object Dropdown (VB6-style, at the very top) ===
	_object_dropdown = OptionButton.new()
	_object_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	_object_dropdown.clip_text = true
	_object_dropdown.custom_minimum_size.y = 24
	_object_dropdown.item_selected.connect(_on_object_dropdown_selected)
	add_child(_object_dropdown)
	
	# === 2. Alphabetic / Categorized toggle buttons ===
	var tab_bar = HBoxContainer.new()
	tab_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	
	_alpha_btn = Button.new()
	_alpha_btn.text = "A-Z"
	_alpha_btn.tooltip_text = "Alphabetic"
	_alpha_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	_alpha_btn.toggle_mode = true
	_alpha_btn.button_pressed = false
	_alpha_btn.pressed.connect(_on_alphabetic_pressed)
	tab_bar.add_child(_alpha_btn)
	
	_cat_btn = Button.new()
	_cat_btn.text = "≡"
	_cat_btn.tooltip_text = "Categorized"
	_cat_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	_cat_btn.toggle_mode = true
	_cat_btn.button_pressed = true
	_cat_btn.pressed.connect(_on_categorized_pressed)
	tab_bar.add_child(_cat_btn)
	
	add_child(tab_bar)
	
	# === 2b. Property filter/search box ===
	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = "🔍 Filter properties..."
	_filter_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_filter_edit.clear_button_enabled = true
	_filter_edit.custom_minimum_size.y = 22
	var filter_sb = StyleBoxFlat.new()
	filter_sb.bg_color = Color(1.0, 1.0, 1.0)
	filter_sb.border_color = Color(0.65, 0.64, 0.62)
	filter_sb.set_border_width_all(1)
	filter_sb.content_margin_left = 4
	filter_sb.content_margin_right = 4
	_filter_edit.add_theme_stylebox_override("normal", filter_sb)
	_filter_edit.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	_filter_edit.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.5))
	_filter_edit.add_theme_color_override("caret_color", Color(0.0, 0.0, 0.0))
	_filter_edit.add_theme_font_size_override("font_size", 11)
	_filter_edit.text_changed.connect(_on_filter_changed)
	add_child(_filter_edit)
	
	# === 3. Property grid (scrollable) — TwinBasic dark style ===
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll_container)
	
	# Style the vertical scrollbar so it's visible on the light background
	_scroll_container.get_v_scroll_bar().custom_minimum_size.x = 14
	var sb_grabber = StyleBoxFlat.new()
	sb_grabber.bg_color = Color(0.62, 0.61, 0.58)  # warm gray grabber
	sb_grabber.corner_radius_top_left = 3
	sb_grabber.corner_radius_top_right = 3
	sb_grabber.corner_radius_bottom_left = 3
	sb_grabber.corner_radius_bottom_right = 3
	var sb_grabber_hl = StyleBoxFlat.new()
	sb_grabber_hl.bg_color = Color(0.48, 0.47, 0.44)  # darker on hover
	sb_grabber_hl.corner_radius_top_left = 3
	sb_grabber_hl.corner_radius_top_right = 3
	sb_grabber_hl.corner_radius_bottom_left = 3
	sb_grabber_hl.corner_radius_bottom_right = 3
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.88, 0.87, 0.84)  # light track background
	sb_bg.corner_radius_top_left = 3
	sb_bg.corner_radius_top_right = 3
	sb_bg.corner_radius_bottom_left = 3
	sb_bg.corner_radius_bottom_right = 3
	_scroll_container.get_v_scroll_bar().add_theme_stylebox_override("grabber", sb_grabber)
	_scroll_container.get_v_scroll_bar().add_theme_stylebox_override("grabber_highlight", sb_grabber_hl)
	_scroll_container.get_v_scroll_bar().add_theme_stylebox_override("grabber_pressed", sb_grabber_hl)
	_scroll_container.get_v_scroll_bar().add_theme_stylebox_override("scroll", sb_bg)
	
	property_grid = GridContainer.new()
	property_grid.columns = 2
	property_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	property_grid.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll_container.add_child(property_grid)
	
	# === 4. Description area at the bottom ===
	var desc_sep = HSeparator.new()
	add_child(desc_sep)
	
	_description_label = RichTextLabel.new()
	_description_label.custom_minimum_size = Vector2(0, 48)
	_description_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_description_label.fit_content = false
	_description_label.scroll_active = true
	_description_label.bbcode_enabled = false
	_description_label.text = ""
	var desc_style = StyleBoxFlat.new()
	desc_style.bg_color = Color("#E8E5E0")  # warm off-white description bg
	desc_style.border_width_top = 1
	desc_style.border_width_left = 0
	desc_style.border_width_bottom = 0
	desc_style.border_width_right = 0
	desc_style.border_color = Color(0.72, 0.71, 0.68)
	desc_style.content_margin_left = 6
	desc_style.content_margin_right = 6
	desc_style.content_margin_top = 4
	desc_style.content_margin_bottom = 4
	_description_label.add_theme_stylebox_override("normal", desc_style)
	_description_label.add_theme_color_override("default_color", Color(0.15, 0.15, 0.15))  # dark text
	_description_label.add_theme_font_size_override("normal_font_size", 11)
	add_child(_description_label)

func setup(plugin: EditorPlugin):
	editor_plugin = plugin
	editor_plugin.get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

# === Object Dropdown Management ===

func _refresh_object_dropdown():
	"""Rebuild the object dropdown with all controls in the current form."""
	_object_dropdown.clear()
	_all_form_nodes.clear()
	
	if not editor_plugin or not is_instance_valid(editor_plugin):
		return
	
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		_object_dropdown.add_item("(No Form)")
		return
	
	_collect_nodes_recursive(root)
	
	for i in _all_form_nodes.size():
		var node = _all_form_nodes[i]
		if not is_instance_valid(node):
			continue
		var label = str(node.name) + "  " + str(node.get_class())
		_object_dropdown.add_item(label)
		_object_dropdown.set_item_metadata(_object_dropdown.item_count - 1, node)
	
	# Select the current_node in the dropdown
	_select_current_in_dropdown()

func _collect_nodes_recursive(node: Node):
	_all_form_nodes.append(node)
	for child in node.get_children():
		# Skip internal children like _FormBackground
		if not String(child.name).begins_with("_"):
			_collect_nodes_recursive(child)

func _select_current_in_dropdown():
	if not current_node:
		return
	for i in _all_form_nodes.size():
		if _all_form_nodes[i] == current_node:
			_object_dropdown.select(i)
			return

func _on_object_dropdown_selected(idx: int):
	if idx < 0 or idx >= _all_form_nodes.size():
		return
	var node = _all_form_nodes[idx]
	if not is_instance_valid(node):
		return
	# Select it in the editor
	if editor_plugin and is_instance_valid(editor_plugin):
		var selection = editor_plugin.get_editor_interface().get_selection()
		selection.clear()
		selection.add_node(node)

# === Alphabetic / Categorized Toggle ===

func _on_alphabetic_pressed():
	_view_mode = 0
	_alpha_btn.button_pressed = true
	_cat_btn.button_pressed = false
	if current_node:
		update_properties(current_node)

func _on_categorized_pressed():
	_view_mode = 1
	_alpha_btn.button_pressed = false
	_cat_btn.button_pressed = true
	if current_node:
		update_properties(current_node)

# === Selection Changed ===

func _on_selection_changed():
	if not is_instance_valid(editor_plugin):
		return
	var sel = editor_plugin.get_editor_interface().get_selection().get_selected_nodes()
	if sel.size() == 1:
		update_properties(sel[0])
	else:
		clear_properties()

func clear_properties():
	current_node = null
	_fd_mode = false
	_fd_form_mode = false
	_fd_designer = null
	_fd_control_index = -1
	_property_entries.clear()
	for c in property_grid.get_children():
		c.queue_free()
	_description_label.text = ""
	_refresh_object_dropdown()

# ==========================================================================
# Form Designer Mode — shows properties for a control on the C++ canvas
# ==========================================================================

## Called by visual_gasic_plugin.gd when a control is selected on the
## C++ FormDesigner canvas.  `info` is the Dictionary returned by
## FormDesigner.get_control_info(index).
func show_control_properties(info: Dictionary, designer = null, ctrl_index: int = -1) -> void:
	_fd_mode = true
	_fd_form_mode = false
	_fd_designer = designer
	_fd_control_index = ctrl_index
	current_node = null  # Not a scene-tree node
	_property_entries.clear()
	for c in property_grid.get_children():
		c.queue_free()
	_description_label.text = ""

	var ctrl_name: String = info.get("name", "")
	var ctrl_type: String = info.get("type", "")
	var props: Dictionary = info.get("properties", {})

	# Object dropdown — show "<Name>  <Type>"
	_object_dropdown.clear()
	_object_dropdown.add_item(ctrl_name + "  " + ctrl_type)

	# ===== (Name) — always first, like VB6 =====
	_property_entries.append({"label": "(Name)", "value": ctrl_name, "prop_key": "name", "type": "string", "category": ""})

	# ===== Appearance Properties =====
	# Caption / Text
	var text_val: String = info.get("text", "")
	if ctrl_type in ["Button", "Label", "CheckBox", "OptionButton", "GroupBox", "Frame"]:
		_property_entries.append({"label": "Caption", "value": text_val, "prop_key": "text", "type": "string", "category": CATEGORY_APPEARANCE})
	elif ctrl_type in ["LineEdit", "TextEdit", "RichTextLabel"]:
		_property_entries.append({"label": "Text", "value": text_val, "prop_key": "text", "type": "string", "category": CATEGORY_APPEARANCE})

	# BackColor / ForeColor — all visible controls
	var back_color = _fd_color_from_props(props, "BackColor", Color(0.85, 0.85, 0.85))
	var fore_color = _fd_color_from_props(props, "ForeColor", Color(0.0, 0.0, 0.0))
	if ctrl_type != "Timer":
		_property_entries.append({"label": "BackColor", "value": back_color, "prop_key": "BackColor", "type": "color", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "ForeColor", "value": fore_color, "prop_key": "ForeColor", "type": "color", "category": CATEGORY_APPEARANCE})

	# BorderStyle (Label, Panel, TextBox, PictureBox)
	if ctrl_type in ["Label", "Panel", "LineEdit", "TextEdit", "TextureRect", "Picture", "RichTextLabel"]:
		var bs = int(props.get("BorderStyle", 0))
		_property_entries.append({"label": "BorderStyle", "value": bs, "prop_key": "BorderStyle", "type": "fd_enum_borderstyle", "category": CATEGORY_APPEARANCE})

	# Appearance (3D / Flat) — most visual controls
	if ctrl_type != "Timer":
		var appearance_val = int(props.get("Appearance", 1))
		_property_entries.append({"label": "Appearance", "value": appearance_val, "prop_key": "Appearance", "type": "fd_enum_appearance", "category": CATEGORY_APPEARANCE})

	# Alignment (Label, LineEdit, TextEdit, CheckBox, OptionButton)
	if ctrl_type == "Label":
		var align_val = int(props.get("Alignment", 0))
		_property_entries.append({"label": "Alignment", "value": align_val, "prop_key": "Alignment", "type": "fd_enum_alignment", "category": CATEGORY_APPEARANCE})
	if ctrl_type in ["LineEdit", "TextEdit"]:
		var align_val = int(props.get("Alignment", 0))
		_property_entries.append({"label": "Alignment", "value": align_val, "prop_key": "Alignment", "type": "fd_enum_alignment", "category": CATEGORY_APPEARANCE})
	if ctrl_type in ["CheckBox", "OptionButton"]:
		var align_val = int(props.get("Alignment", 0))
		_property_entries.append({"label": "Alignment", "value": align_val, "prop_key": "Alignment", "type": "fd_enum_alignment", "category": CATEGORY_APPEARANCE})

	# AutoSize (Label, PictureBox)
	if ctrl_type in ["Label", "TextureRect", "Picture"]:
		_property_entries.append({"label": "AutoSize", "value": bool(props.get("AutoSize", false)), "prop_key": "AutoSize", "type": "bool", "category": CATEGORY_APPEARANCE})
	# WordWrap (Label, TextEdit)
	if ctrl_type in ["Label", "TextEdit", "RichTextLabel"]:
		_property_entries.append({"label": "WordWrap", "value": bool(props.get("WordWrap", false)), "prop_key": "WordWrap", "type": "bool", "category": CATEGORY_APPEARANCE})

	# Style (Button — graphical vs standard)
	if ctrl_type == "Button":
		_property_entries.append({"label": "Style", "value": int(props.get("Style", 0)), "prop_key": "Style", "type": "fd_enum_style", "category": CATEGORY_APPEARANCE})

	# --------- LineEdit / TextBox properties ---------
	if ctrl_type == "LineEdit":
		_property_entries.append({"label": "PasswordChar", "value": str(props.get("PasswordChar", "")), "prop_key": "PasswordChar", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "MaxLength", "value": int(props.get("MaxLength", 0)), "prop_key": "MaxLength", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Locked", "value": bool(props.get("Locked", false)), "prop_key": "Locked", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "PlaceholderText", "value": str(props.get("PlaceholderText", "")), "prop_key": "PlaceholderText", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "ClearButton", "value": bool(props.get("ClearButton", false)), "prop_key": "ClearButton", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "SelectAllOnFocus", "value": bool(props.get("SelectAllOnFocus", false)), "prop_key": "SelectAllOnFocus", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "RightToLeft", "value": bool(props.get("RightToLeft", false)), "prop_key": "RightToLeft", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "VirtualKeyboardEnabled", "value": bool(props.get("VirtualKeyboardEnabled", true)), "prop_key": "VirtualKeyboardEnabled", "type": "bool", "category": CATEGORY_BEHAVIOR})

	# --------- TextEdit properties ---------
	if ctrl_type == "TextEdit":
		_property_entries.append({"label": "MultiLine", "value": bool(props.get("MultiLine", true)), "prop_key": "MultiLine", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "ScrollBars", "value": int(props.get("ScrollBars", 3)), "prop_key": "ScrollBars", "type": "fd_enum_scrollbars", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Locked", "value": bool(props.get("Locked", false)), "prop_key": "Locked", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "Editable", "value": bool(props.get("Editable", true)), "prop_key": "Editable", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "MaxLength", "value": int(props.get("MaxLength", 0)), "prop_key": "MaxLength", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "PlaceholderText", "value": str(props.get("PlaceholderText", "")), "prop_key": "PlaceholderText", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "RightToLeft", "value": bool(props.get("RightToLeft", false)), "prop_key": "RightToLeft", "type": "bool", "category": CATEGORY_BEHAVIOR})

	# --------- RichTextLabel properties ---------
	if ctrl_type == "RichTextLabel":
		_property_entries.append({"label": "BbcodeEnabled", "value": bool(props.get("BbcodeEnabled", false)), "prop_key": "BbcodeEnabled", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "FitContent", "value": bool(props.get("FitContent", false)), "prop_key": "FitContent", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "ScrollActive", "value": bool(props.get("ScrollActive", true)), "prop_key": "ScrollActive", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "SelectionEnabled", "value": bool(props.get("SelectionEnabled", false)), "prop_key": "SelectionEnabled", "type": "bool", "category": CATEGORY_BEHAVIOR})

	# --------- Button properties ---------
	if ctrl_type == "Button":
		_property_entries.append({"label": "Flat", "value": bool(props.get("Flat", false)), "prop_key": "Flat", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Icon", "value": str(props.get("Icon", "")), "prop_key": "Icon", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "IconAlignment", "value": int(props.get("IconAlignment", 0)), "prop_key": "IconAlignment", "type": "fd_enum_iconalignment", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "ClipText", "value": bool(props.get("ClipText", false)), "prop_key": "ClipText", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "ExpandIcon", "value": bool(props.get("ExpandIcon", false)), "prop_key": "ExpandIcon", "type": "bool", "category": CATEGORY_APPEARANCE})

	# --------- Label properties ---------
	if ctrl_type == "Label":
		_property_entries.append({"label": "VerticalAlignment", "value": int(props.get("VerticalAlignment", 0)), "prop_key": "VerticalAlignment", "type": "fd_enum_valignment", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "MaxLinesVisible", "value": int(props.get("MaxLinesVisible", -1)), "prop_key": "MaxLinesVisible", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "ClipText", "value": bool(props.get("ClipText", false)), "prop_key": "ClipText", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "TextOverrunBehavior", "value": int(props.get("TextOverrunBehavior", 0)), "prop_key": "TextOverrunBehavior", "type": "number", "category": CATEGORY_APPEARANCE})

	# --------- CheckBox properties ---------
	if ctrl_type in ["CheckBox", "CheckButton"]:
		_property_entries.append({"label": "Value", "value": bool(props.get("Value", false)), "prop_key": "Value", "type": "bool", "category": CATEGORY_APPEARANCE})

	# --------- Range controls (ProgressBar, Slider, SpinBox, ScrollBar) ---------
	if ctrl_type in ["ProgressBar", "HSlider", "VSlider", "SpinBox", "HScrollBar", "VScrollBar"]:
		_property_entries.append({"label": "Value", "value": float(props.get("Value", 0)), "prop_key": "Value", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Min", "value": float(props.get("Min", 0)), "prop_key": "Min", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Max", "value": float(props.get("Max", 100)), "prop_key": "Max", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Step", "value": float(props.get("Step", 1)), "prop_key": "Step", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Rounded", "value": bool(props.get("Rounded", false)), "prop_key": "Rounded", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "AllowGreater", "value": bool(props.get("AllowGreater", false)), "prop_key": "AllowGreater", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "AllowLesser", "value": bool(props.get("AllowLesser", false)), "prop_key": "AllowLesser", "type": "bool", "category": CATEGORY_BEHAVIOR})

	# --------- Slider-specific ---------
	if ctrl_type in ["HSlider", "VSlider"]:
		_property_entries.append({"label": "TickCount", "value": int(props.get("TickCount", 0)), "prop_key": "TickCount", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "TicksOnBorders", "value": bool(props.get("TicksOnBorders", false)), "prop_key": "TicksOnBorders", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Scrollable", "value": bool(props.get("Scrollable", true)), "prop_key": "Scrollable", "type": "bool", "category": CATEGORY_BEHAVIOR})

	# --------- ScrollBar-specific ---------
	if ctrl_type in ["HScrollBar", "VScrollBar"]:
		_property_entries.append({"label": "Page", "value": float(props.get("Page", 0)), "prop_key": "Page", "type": "number", "category": CATEGORY_APPEARANCE})

	# --------- ProgressBar properties ---------
	if ctrl_type == "ProgressBar":
		_property_entries.append({"label": "ShowPercentage", "value": bool(props.get("ShowPercentage", true)), "prop_key": "ShowPercentage", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "FillMode", "value": int(props.get("FillMode", 0)), "prop_key": "FillMode", "type": "fd_enum_fillmode", "category": CATEGORY_APPEARANCE})

	# --------- SpinBox properties ---------
	if ctrl_type == "SpinBox":
		_property_entries.append({"label": "Prefix", "value": str(props.get("Prefix", "")), "prop_key": "Prefix", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Suffix", "value": str(props.get("Suffix", "")), "prop_key": "Suffix", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Wrap", "value": bool(props.get("Wrap", false)), "prop_key": "Wrap", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "Alignment", "value": int(props.get("Alignment", 0)), "prop_key": "Alignment", "type": "fd_enum_alignment", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Editable", "value": bool(props.get("Editable", true)), "prop_key": "Editable", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "UpdateOnTextChanged", "value": bool(props.get("UpdateOnTextChanged", false)), "prop_key": "UpdateOnTextChanged", "type": "bool", "category": CATEGORY_BEHAVIOR})

	# --------- PictureBox / TextureRect properties ---------
	if ctrl_type in ["TextureRect", "Picture"]:
		_property_entries.append({"label": "StretchMode", "value": int(props.get("StretchMode", 0)), "prop_key": "StretchMode", "type": "fd_enum_stretchmode", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "FlipH", "value": bool(props.get("FlipH", false)), "prop_key": "FlipH", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "FlipV", "value": bool(props.get("FlipV", false)), "prop_key": "FlipV", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Picture", "value": str(props.get("Picture", "")), "prop_key": "Picture", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Stretch", "value": bool(props.get("Stretch", false)), "prop_key": "Stretch", "type": "bool", "category": CATEGORY_APPEARANCE})

	# --------- ColorRect / Shape properties ---------
	if ctrl_type in ["ColorRect", "Shape"]:
		var shape_clr = _fd_color_from_props(props, "ShapeColor", Color(0.3, 0.3, 0.8))
		_property_entries.append({"label": "ShapeColor", "value": shape_clr, "prop_key": "ShapeColor", "type": "color", "category": CATEGORY_APPEARANCE})

	# --------- ItemList / ListBox properties ---------
	if ctrl_type == "ItemList":
		_property_entries.append({"label": "IconMode", "value": int(props.get("IconMode", 1)), "prop_key": "IconMode", "type": "fd_enum_iconmode", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "MaxColumns", "value": int(props.get("MaxColumns", 1)), "prop_key": "MaxColumns", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "FixedColumnWidth", "value": int(props.get("FixedColumnWidth", 0)), "prop_key": "FixedColumnWidth", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Sorted", "value": bool(props.get("Sorted", false)), "prop_key": "Sorted", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "MultiSelect", "value": int(props.get("MultiSelect", 0)), "prop_key": "MultiSelect", "type": "fd_enum_multiselect", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "Columns", "value": int(props.get("Columns", 0)), "prop_key": "Columns", "type": "number", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "AllowReselect", "value": bool(props.get("AllowReselect", false)), "prop_key": "AllowReselect", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "AutoHeight", "value": bool(props.get("AutoHeight", false)), "prop_key": "AutoHeight", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "FixedIconSize", "value": int(props.get("FixedIconSize", 0)), "prop_key": "FixedIconSize", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "SameColumnWidth", "value": bool(props.get("SameColumnWidth", false)), "prop_key": "SameColumnWidth", "type": "bool", "category": CATEGORY_APPEARANCE})

	# --------- OptionButton / ComboBox properties ---------
	if ctrl_type in ["OptionButton", "ComboBox", "VGComboBox"]:
		_property_entries.append({"label": "ListItems", "value": str(props.get("ListItems", "")), "prop_key": "ListItems", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Selected", "value": int(props.get("Selected", -1)), "prop_key": "Selected", "type": "number", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "FitToLongestItem", "value": bool(props.get("FitToLongestItem", true)), "prop_key": "FitToLongestItem", "type": "bool", "category": CATEGORY_APPEARANCE})

	# --------- Tree / TreeView properties ---------
	if ctrl_type in ["Tree", "TreeView"]:
		_property_entries.append({"label": "HideRoot", "value": bool(props.get("HideRoot", false)), "prop_key": "HideRoot", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "HideFolding", "value": bool(props.get("HideFolding", false)), "prop_key": "HideFolding", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Sorted", "value": bool(props.get("Sorted", false)), "prop_key": "Sorted", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "AllowReselect", "value": bool(props.get("AllowReselect", false)), "prop_key": "AllowReselect", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "AllowRmbSelect", "value": bool(props.get("AllowRmbSelect", false)), "prop_key": "AllowRmbSelect", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "SelectMode", "value": int(props.get("SelectMode", 0)), "prop_key": "SelectMode", "type": "number", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "Columns", "value": int(props.get("Columns", 1)), "prop_key": "Columns", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "ColumnTitlesVisible", "value": bool(props.get("ColumnTitlesVisible", false)), "prop_key": "ColumnTitlesVisible", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "ScrollHorizontalEnabled", "value": bool(props.get("ScrollHorizontalEnabled", true)), "prop_key": "ScrollHorizontalEnabled", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "ScrollVerticalEnabled", "value": bool(props.get("ScrollVerticalEnabled", true)), "prop_key": "ScrollVerticalEnabled", "type": "bool", "category": CATEGORY_BEHAVIOR})

	# --------- TabContainer / TabStrip properties ---------
	if ctrl_type in ["TabContainer", "TabStrip"]:
		_property_entries.append({"label": "CurrentTab", "value": int(props.get("CurrentTab", 0)), "prop_key": "CurrentTab", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "TabAlignment", "value": int(props.get("TabAlignment", 0)), "prop_key": "TabAlignment", "type": "fd_enum_tabalignment", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "ClipTabs", "value": bool(props.get("ClipTabs", true)), "prop_key": "ClipTabs", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "DragToRearrangeEnabled", "value": bool(props.get("DragToRearrangeEnabled", false)), "prop_key": "DragToRearrangeEnabled", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "TabCount", "value": int(props.get("TabCount", 0)), "prop_key": "TabCount", "type": "number", "category": CATEGORY_APPEARANCE})

	# --------- Panel properties ---------
	if ctrl_type == "Panel":
		_property_entries.append({"label": "ClipContents", "value": bool(props.get("ClipContents", false)), "prop_key": "ClipContents", "type": "bool", "category": CATEGORY_APPEARANCE})

	# --------- Timer properties ---------
	if ctrl_type == "Timer":
		_property_entries.append({"label": "Interval", "value": int(props.get("Interval", 1000)), "prop_key": "Interval", "type": "number", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "OneShot", "value": bool(props.get("OneShot", false)), "prop_key": "OneShot", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "Autostart", "value": bool(props.get("Autostart", false)), "prop_key": "Autostart", "type": "bool", "category": CATEGORY_BEHAVIOR})

	# --------- MenuBar properties ---------
	if ctrl_type == "MenuBar":
		_property_entries.append({"label": "Flat", "value": bool(props.get("Flat", false)), "prop_key": "Flat", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "SwitchOnHover", "value": bool(props.get("SwitchOnHover", true)), "prop_key": "SwitchOnHover", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "PreferGlobalMenu", "value": bool(props.get("PreferGlobalMenu", false)), "prop_key": "PreferGlobalMenu", "type": "bool", "category": CATEGORY_BEHAVIOR})

	# --------- TextureButton properties ---------
	if ctrl_type == "TextureButton":
		_property_entries.append({"label": "StretchMode", "value": int(props.get("StretchMode", 0)), "prop_key": "StretchMode", "type": "fd_enum_stretchmode", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "FlipH", "value": bool(props.get("FlipH", false)), "prop_key": "FlipH", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "FlipV", "value": bool(props.get("FlipV", false)), "prop_key": "FlipV", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "IgnoreTextureSize", "value": bool(props.get("IgnoreTextureSize", false)), "prop_key": "IgnoreTextureSize", "type": "bool", "category": CATEGORY_APPEARANCE})

	# --------- GroupBox / Frame properties ---------
	if ctrl_type in ["GroupBox", "Frame"]:
		_property_entries.append({"label": "ClipContents", "value": bool(props.get("ClipContents", false)), "prop_key": "ClipContents", "type": "bool", "category": CATEGORY_APPEARANCE})

	# --------- FileDialog properties ---------
	if ctrl_type == "FileDialog":
		_property_entries.append({"label": "FileMode", "value": int(props.get("FileMode", 0)), "prop_key": "FileMode", "type": "number", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "Filters", "value": str(props.get("Filters", "")), "prop_key": "Filters", "type": "string", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "CurrentDir", "value": str(props.get("CurrentDir", "")), "prop_key": "CurrentDir", "type": "string", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "CurrentFile", "value": str(props.get("CurrentFile", "")), "prop_key": "CurrentFile", "type": "string", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "ShowHiddenFiles", "value": bool(props.get("ShowHiddenFiles", false)), "prop_key": "ShowHiddenFiles", "type": "bool", "category": CATEGORY_BEHAVIOR})

	# --------- RadioButton properties ---------
	if ctrl_type == "RadioButton":
		_property_entries.append({"label": "Caption", "value": text_val, "prop_key": "text", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Value", "value": bool(props.get("Value", false)), "prop_key": "Value", "type": "bool", "category": CATEGORY_APPEARANCE})

	# --------- StatusBar properties ---------
	if ctrl_type == "StatusBar":
		_property_entries.append({"label": "SimpleText", "value": str(props.get("SimpleText", "Ready")), "prop_key": "SimpleText", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Style", "value": int(props.get("Style", 1)), "prop_key": "Style", "type": "number", "category": CATEGORY_APPEARANCE})

	# --------- Toolbar properties ---------
	if ctrl_type == "Toolbar":
		_property_entries.append({"label": "ButtonCount", "value": int(props.get("ButtonCount", 6)), "prop_key": "ButtonCount", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Flat", "value": bool(props.get("Flat", false)), "prop_key": "Flat", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Wrappable", "value": bool(props.get("Wrappable", true)), "prop_key": "Wrappable", "type": "bool", "category": CATEGORY_BEHAVIOR})

	# --------- ListView properties ---------
	if ctrl_type == "ListView":
		_property_entries.append({"label": "View", "value": int(props.get("View", 3)), "prop_key": "View", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Sorted", "value": bool(props.get("Sorted", false)), "prop_key": "Sorted", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "MultiSelect", "value": int(props.get("MultiSelect", 0)), "prop_key": "MultiSelect", "type": "fd_enum_multiselect", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "GridLines", "value": bool(props.get("GridLines", false)), "prop_key": "GridLines", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "FullRowSelect", "value": bool(props.get("FullRowSelect", false)), "prop_key": "FullRowSelect", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "LabelEdit", "value": int(props.get("LabelEdit", 0)), "prop_key": "LabelEdit", "type": "number", "category": CATEGORY_BEHAVIOR})

	# --------- Separator properties ---------
	# HSeparator / VSeparator have no special properties beyond the universals

	# ===== Game UI Prototype Properties (control-specific @exports) =====
	var scene_path: String = info.get("scene_path", "")
	if scene_path.contains("prototypes/game_ui/") or scene_path.contains("prototypes/"):
		_load_prototype_properties(scene_path, props, ctrl_type)

	# ===== Behavior Properties (universal) =====
	_property_entries.append({"label": "Enabled", "value": bool(props.get("Enabled", true)), "prop_key": "Enabled", "type": "bool", "category": CATEGORY_BEHAVIOR})
	_property_entries.append({"label": "Visible", "value": info.get("visible", true), "prop_key": "visible", "type": "bool", "category": CATEGORY_BEHAVIOR})
	if ctrl_type != "Timer":
		_property_entries.append({"label": "TabStop", "value": bool(props.get("TabStop", true)), "prop_key": "TabStop", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "TabIndex", "value": int(props.get("TabIndex", ctrl_index)), "prop_key": "TabIndex", "type": "number", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "FocusMode", "value": int(props.get("FocusMode", 2)), "prop_key": "FocusMode", "type": "number", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "MouseFilter", "value": int(props.get("MouseFilter", 0)), "prop_key": "MouseFilter", "type": "number", "category": CATEGORY_BEHAVIOR})

	# CausesValidation (VB6 classic)
	if ctrl_type in ["Button", "LineEdit", "TextEdit", "CheckBox", "OptionButton", "SpinBox"]:
		_property_entries.append({"label": "CausesValidation", "value": bool(props.get("CausesValidation", true)), "prop_key": "CausesValidation", "type": "bool", "category": CATEGORY_BEHAVIOR})

	# Default / Cancel (Button)
	if ctrl_type == "Button":
		_property_entries.append({"label": "Default", "value": bool(props.get("Default", false)), "prop_key": "Default", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "Cancel", "value": bool(props.get("Cancel", false)), "prop_key": "Cancel", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "DisabledFocusMode", "value": int(props.get("DisabledFocusMode", 0)), "prop_key": "DisabledFocusMode", "type": "number", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "KeepPressedOutside", "value": bool(props.get("KeepPressedOutside", false)), "prop_key": "KeepPressedOutside", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "ActionMode", "value": int(props.get("ActionMode", 1)), "prop_key": "ActionMode", "type": "number", "category": CATEGORY_BEHAVIOR})

	# ===== Font Properties =====
	if ctrl_type != "Timer":
		var font_name = str(props.get("FontName", "MS Sans Serif"))
		var font_size = int(props.get("FontSize", 8))
		var font_bold = bool(props.get("FontBold", false))
		var font_italic = bool(props.get("FontItalic", false))
		_property_entries.append({"label": "FontName", "value": font_name, "prop_key": "FontName", "type": "font_name", "category": CATEGORY_FONT})
		_property_entries.append({"label": "FontSize", "value": font_size, "prop_key": "FontSize", "type": "number", "category": CATEGORY_FONT})
		_property_entries.append({"label": "FontBold", "value": font_bold, "prop_key": "FontBold", "type": "bool", "category": CATEGORY_FONT})
		_property_entries.append({"label": "FontItalic", "value": font_italic, "prop_key": "FontItalic", "type": "bool", "category": CATEGORY_FONT})
		var font_underline = bool(props.get("FontUnderline", false))
		var font_strikethrough = bool(props.get("FontStrikethrough", false))
		_property_entries.append({"label": "FontUnderline", "value": font_underline, "prop_key": "FontUnderline", "type": "bool", "category": CATEGORY_FONT})
		_property_entries.append({"label": "FontStrikethrough", "value": font_strikethrough, "prop_key": "FontStrikethrough", "type": "bool", "category": CATEGORY_FONT})

	# ===== Position Properties =====
	_property_entries.append({"label": "Left", "value": int(info.get("x", 0)), "prop_key": "x", "type": "number", "category": CATEGORY_POSITION})
	_property_entries.append({"label": "Top", "value": int(info.get("y", 0)), "prop_key": "y", "type": "number", "category": CATEGORY_POSITION})
	_property_entries.append({"label": "Width", "value": int(info.get("width", 0)), "prop_key": "width", "type": "number", "category": CATEGORY_POSITION})
	_property_entries.append({"label": "Height", "value": int(info.get("height", 0)), "prop_key": "height", "type": "number", "category": CATEGORY_POSITION})

	# ===== Effects Properties (all visual controls) =====
	if ctrl_type != "Timer":
		_property_entries.append({"label": "Opacity", "value": int(props.get("Opacity", 100)), "prop_key": "Opacity", "type": "slider", "category": "Effects"})
		_property_entries.append({"label": "Rotation", "value": float(props.get("Rotation", 0.0)), "prop_key": "Rotation", "type": "number", "category": "Effects"})
		_property_entries.append({"label": "ScaleX", "value": float(props.get("ScaleX", 1.0)), "prop_key": "ScaleX", "type": "number", "category": "Effects"})
		_property_entries.append({"label": "ScaleY", "value": float(props.get("ScaleY", 1.0)), "prop_key": "ScaleY", "type": "number", "category": "Effects"})
		_property_entries.append({"label": "PivotOffsetX", "value": float(props.get("PivotOffsetX", 0.0)), "prop_key": "PivotOffsetX", "type": "number", "category": "Effects"})
		_property_entries.append({"label": "PivotOffsetY", "value": float(props.get("PivotOffsetY", 0.0)), "prop_key": "PivotOffsetY", "type": "number", "category": "Effects"})
		_property_entries.append({"label": "SelfModulate", "value": _fd_color_from_props(props, "SelfModulate", Color(1, 1, 1, 1)), "prop_key": "SelfModulate", "type": "color", "category": "Effects"})
		_property_entries.append({"label": "ShowBehindParent", "value": bool(props.get("ShowBehindParent", false)), "prop_key": "ShowBehindParent", "type": "bool", "category": "Effects"})

	# ===== Layout Properties (all visual controls) =====
	if ctrl_type != "Timer":
		_property_entries.append({"label": "MinWidth", "value": int(props.get("MinWidth", 0)), "prop_key": "MinWidth", "type": "number", "category": "Layout"})
		_property_entries.append({"label": "MinHeight", "value": int(props.get("MinHeight", 0)), "prop_key": "MinHeight", "type": "number", "category": "Layout"})
		_property_entries.append({"label": "ClipContents", "value": bool(props.get("ClipContents", false)), "prop_key": "ClipContents", "type": "bool", "category": "Layout"})
		_property_entries.append({"label": "SizeFlagsHorizontal", "value": int(props.get("SizeFlagsHorizontal", 1)), "prop_key": "SizeFlagsHorizontal", "type": "number", "category": "Layout"})
		_property_entries.append({"label": "SizeFlagsVertical", "value": int(props.get("SizeFlagsVertical", 1)), "prop_key": "SizeFlagsVertical", "type": "number", "category": "Layout"})
		_property_entries.append({"label": "GrowHorizontal", "value": int(props.get("GrowHorizontal", 1)), "prop_key": "GrowHorizontal", "type": "number", "category": "Layout"})
		_property_entries.append({"label": "GrowVertical", "value": int(props.get("GrowVertical", 1)), "prop_key": "GrowVertical", "type": "number", "category": "Layout"})
		_property_entries.append({"label": "LayoutDirection", "value": int(props.get("LayoutDirection", 0)), "prop_key": "LayoutDirection", "type": "number", "category": "Layout"})

	# ===== Misc Properties =====
	_property_entries.append({"label": "ToolTipText", "value": str(props.get("ToolTipText", "")), "prop_key": "ToolTipText", "type": "string", "category": CATEGORY_MISC})
	_property_entries.append({"label": "Tag", "value": str(props.get("Tag", "")), "prop_key": "Tag", "type": "string", "category": CATEGORY_MISC})
	if ctrl_type != "Timer":
		_property_entries.append({"label": "MousePointer", "value": int(props.get("MousePointer", 0)), "prop_key": "MousePointer", "type": "fd_enum_mousepointer", "category": CATEGORY_MISC})
		_property_entries.append({"label": "MouseDefaultCursorShape", "value": int(props.get("MouseDefaultCursorShape", 0)), "prop_key": "MouseDefaultCursorShape", "type": "number", "category": CATEGORY_MISC})
		_property_entries.append({"label": "ThemeTypeVariation", "value": str(props.get("ThemeTypeVariation", "")), "prop_key": "ThemeTypeVariation", "type": "string", "category": CATEGORY_MISC})
	_property_entries.append({"label": "Index", "value": ctrl_index, "prop_key": "index", "type": "readonly", "category": CATEGORY_MISC})

	# Render based on view mode
	if _view_mode == 0:
		_render_alphabetic()
	else:
		_render_categorized()

## Helper: extract a Color from the FormDesigner properties dictionary.
func _fd_color_from_props(props: Dictionary, key: String, default: Color) -> Color:
	if props.has(key):
		var v = props[key]
		if v is Color:
			return v
		if v is String and not v.is_empty():
			return Color(v)
	return default

# ==========================================================================
# Game UI Prototype — auto-discover @export properties from .gd scripts
# ==========================================================================

## Load @export properties from a Game UI prototype GDScript and add them
## to _property_entries under a category named after the control type.
func _load_prototype_properties(scene_path: String, props: Dictionary, ctrl_type: String) -> void:
	# Derive .gd path from .tscn scene path
	var gd_path := scene_path.replace(".tscn", ".gd")
	if not FileAccess.file_exists(gd_path):
		return

	var source := FileAccess.get_file_as_string(gd_path)
	if source.is_empty():
		return

	var category_name := ctrl_type  # e.g. "RadialMenu", "StatBar"
	var lines := source.split("\n")
	var pending_enum_items: PackedStringArray = []
	var pending_range_hint: String = ""

	for i in range(lines.size()):
		var line := lines[i].strip_edges()

		# Collect @export_enum / @export_range decorators (they precede the var line)
		if line.begins_with("@export_enum("):
			# May be on the same line as var, or a standalone decorator
			var paren_start := line.find("(") + 1
			var paren_end := line.find(")")
			if paren_end > paren_start:
				var enum_str := line.substr(paren_start, paren_end - paren_start)
				pending_enum_items = PackedStringArray()
				for item in enum_str.split(","):
					var clean := item.strip_edges().trim_prefix('"').trim_suffix('"')
					if not clean.is_empty():
						pending_enum_items.append(clean)
			# Check if var is on the SAME line (common pattern)
			var var_pos_same := line.find("var ")
			if var_pos_same < 0:
				continue  # decorator only — var is on next line

		if line.begins_with("@export_range("):
			var paren_start := line.find("(") + 1
			var paren_end := line.find(")")
			if paren_end > paren_start:
				pending_range_hint = line.substr(paren_start, paren_end - paren_start)
			var var_pos_same := line.find("var ")
			if var_pos_same < 0:
				continue

		if not line.begins_with("@export"):
			# Reset decorators if we hit a non-export line without consuming them
			if not line.is_empty() and not line.begins_with("#"):
				pending_enum_items = PackedStringArray()
				pending_range_hint = ""
			continue

		# Find "var " in the line
		var var_pos := line.find("var ")
		if var_pos < 0:
			continue

		var after_var := line.substr(var_pos + 4)  # e.g. "ItemCount: int = 6:"
		var colon_pos := after_var.find(":")
		if colon_pos < 0:
			pending_enum_items = PackedStringArray()
			pending_range_hint = ""
			continue

		var prop_name := after_var.substr(0, colon_pos).strip_edges()
		var rest := after_var.substr(colon_pos + 1).strip_edges()

		# Extract type and default value
		var eq_pos := rest.find("=")
		var type_str := ""
		var default_str := ""
		if eq_pos >= 0:
			type_str = rest.substr(0, eq_pos).strip_edges()
			default_str = rest.substr(eq_pos + 1).strip_edges()
			# Remove trailing colon (setter block)
			if default_str.ends_with(":"):
				default_str = default_str.substr(0, default_str.length() - 1).strip_edges()
		else:
			type_str = rest
			if type_str.ends_with(":"):
				type_str = type_str.substr(0, type_str.length() - 1).strip_edges()

		# Skip non-VB6 types (Texture2D, PackedScene, etc.) — show as string
		var inspector_type := "string"
		var value: Variant = ""

		# Handle @export_enum
		if pending_enum_items.size() > 0:
			# Build numbered items: ["0 - FadeIn", "1 - ScaleUp", "2 - None"]
			var numbered_items: Array = []
			for idx in range(pending_enum_items.size()):
				numbered_items.append(str(idx) + " - " + pending_enum_items[idx])
			inspector_type = "prototype_enum"
			var def_int := int(default_str) if not default_str.is_empty() and default_str.is_valid_int() else 0
			value = int(props.get(prop_name, def_int))
			_property_entries.append({
				"label": prop_name, "value": value, "prop_key": prop_name,
				"type": inspector_type, "category": category_name,
				"enum_items": numbered_items
			})
			pending_enum_items = PackedStringArray()
			pending_range_hint = ""
			continue

		match type_str:
			"int":
				inspector_type = "number"
				var def_int := int(default_str) if not default_str.is_empty() and default_str.is_valid_int() else 0
				value = int(props.get(prop_name, def_int))
			"float":
				inspector_type = "number"
				var def_float := float(default_str) if not default_str.is_empty() and default_str.is_valid_float() else 0.0
				value = float(props.get(prop_name, def_float))
			"String":
				inspector_type = "string"
				var def_str := default_str.trim_prefix('"').trim_suffix('"') if not default_str.is_empty() else ""
				value = str(props.get(prop_name, def_str))
			"Color":
				inspector_type = "color"
				var def_color := _parse_color_literal(default_str)
				value = _fd_color_from_props(props, prop_name, def_color)
			"bool":
				inspector_type = "bool"
				var def_bool := (default_str.strip_edges().to_lower() == "true") if not default_str.is_empty() else false
				value = bool(props.get(prop_name, def_bool))
			"Vector2i":
				inspector_type = "string"
				value = str(props.get(prop_name, default_str))
			"PackedStringArray":
				inspector_type = "string"
				var stored = props.get(prop_name, "")
				if stored is PackedStringArray:
					value = ",".join(stored)
				else:
					value = str(stored) if str(stored) != "" else default_str.trim_prefix('["').trim_suffix('"]').replace('", "', ',')
			"Texture2D":
				# Skip texture properties — can't edit in a text field meaningfully
				pending_enum_items = PackedStringArray()
				pending_range_hint = ""
				continue
			_:
				# Unknown type — show as string
				value = str(props.get(prop_name, default_str))

		_property_entries.append({
			"label": prop_name, "value": value, "prop_key": prop_name,
			"type": inspector_type, "category": category_name
		})
		pending_enum_items = PackedStringArray()
		pending_range_hint = ""

## Parse a Color literal like "Color(0.15, 0.18, 0.25, 0.9)" into a Color.
func _parse_color_literal(s: String) -> Color:
	if s.begins_with("Color(") and s.ends_with(")"):
		var inner := s.substr(6, s.length() - 7)
		var parts := inner.split(",")
		if parts.size() >= 4:
			return Color(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float(),
						 parts[2].strip_edges().to_float(), parts[3].strip_edges().to_float())
		elif parts.size() >= 3:
			return Color(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float(),
						 parts[2].strip_edges().to_float())
	return Color.WHITE

# ==========================================================================
# Form Designer Mode — shows FORM-LEVEL properties (VB6 style)
# ==========================================================================

## Called when user clicks the form background (no control selected).
## Displays VB6 form properties like Caption, BorderStyle, ControlBox, etc.
func show_form_properties(designer) -> void:
	_fd_mode = true
	_fd_form_mode = true
	_fd_designer = designer
	_fd_control_index = -1
	current_node = null
	_property_entries.clear()
	for c in property_grid.get_children():
		c.queue_free()
	_description_label.text = ""

	# Get all form properties from C++
	var props: Dictionary = designer.get_form_properties()
	var form_name: String = props.get("(Name)", "Form1")

	# Object dropdown — show "<Name>  Form"
	_object_dropdown.clear()
	_object_dropdown.add_item(form_name + "  Form")

	# ===== (Name) — always first =====
	_property_entries.append({"label": "(Name)", "value": form_name, "prop_key": "Caption", "type": "string", "category": ""})

	# ===== Appearance Properties =====
	_property_entries.append({"label": "Caption", "value": form_name, "prop_key": "Caption", "type": "string", "category": CATEGORY_APPEARANCE})

	var border_style: int = int(props.get("BorderStyle", 2))
	_property_entries.append({"label": "BorderStyle", "value": border_style, "prop_key": "BorderStyle", "type": "fd_enum_form_borderstyle", "category": CATEGORY_APPEARANCE})

	_property_entries.append({"label": "BackColor", "value": props.get("BackColor", Color(0.753, 0.753, 0.753)), "prop_key": "BackColor", "type": "color", "category": CATEGORY_APPEARANCE})
	_property_entries.append({"label": "ForeColor", "value": props.get("ForeColor", Color.BLACK), "prop_key": "ForeColor", "type": "color", "category": CATEGORY_APPEARANCE})

	# ===== Behavior Properties =====
	_property_entries.append({"label": "ControlBox", "value": bool(props.get("ControlBox", true)), "prop_key": "ControlBox", "type": "bool", "category": CATEGORY_BEHAVIOR})
	_property_entries.append({"label": "MinButton", "value": bool(props.get("MinButton", true)), "prop_key": "MinButton", "type": "bool", "category": CATEGORY_BEHAVIOR})
	_property_entries.append({"label": "MaxButton", "value": bool(props.get("MaxButton", true)), "prop_key": "MaxButton", "type": "bool", "category": CATEGORY_BEHAVIOR})
	_property_entries.append({"label": "Moveable", "value": bool(props.get("Moveable", true)), "prop_key": "Moveable", "type": "bool", "category": CATEGORY_BEHAVIOR})
	_property_entries.append({"label": "ShowInTaskbar", "value": bool(props.get("ShowInTaskbar", true)), "prop_key": "ShowInTaskbar", "type": "bool", "category": CATEGORY_BEHAVIOR})
	_property_entries.append({"label": "KeyPreview", "value": bool(props.get("KeyPreview", false)), "prop_key": "KeyPreview", "type": "bool", "category": CATEGORY_BEHAVIOR})
	_property_entries.append({"label": "AutoRedraw", "value": bool(props.get("AutoRedraw", true)), "prop_key": "AutoRedraw", "type": "bool", "category": CATEGORY_BEHAVIOR})

	var ws: int = int(props.get("WindowState", 0))
	_property_entries.append({"label": "WindowState", "value": ws, "prop_key": "WindowState", "type": "fd_enum_windowstate", "category": CATEGORY_BEHAVIOR})

	var sp: int = int(props.get("StartUpPosition", 2))
	_property_entries.append({"label": "StartUpPosition", "value": sp, "prop_key": "StartUpPosition", "type": "fd_enum_startposition", "category": CATEGORY_BEHAVIOR})

	# ===== Position Properties =====
	_property_entries.append({"label": "Width", "value": int(props.get("Width", 600)), "prop_key": "Width", "type": "number", "category": CATEGORY_POSITION})
	_property_entries.append({"label": "Height", "value": int(props.get("Height", 400)), "prop_key": "Height", "type": "number", "category": CATEGORY_POSITION})

	# ===== Misc Properties =====
	var wt: int = int(props.get("WindowType", 0))
	_property_entries.append({"label": "WindowType", "value": wt, "prop_key": "WindowType", "type": "fd_enum_windowtype", "category": CATEGORY_MISC})
	_property_entries.append({"label": "Icon", "value": str(props.get("Icon", "")), "prop_key": "Icon", "type": "string", "category": CATEGORY_MISC})

	# Render based on view mode
	if _view_mode == 0:
		_render_alphabetic()
	else:
		_render_categorized()

# === Description Area ===

func _show_description(prop_key: String):
	_selected_prop_key = prop_key
	var desc = PROPERTY_DESCRIPTIONS.get(prop_key, "")
	if desc.is_empty():
		_description_label.text = prop_key
	else:
		_description_label.text = desc

## Apply subtle zebra-stripe background to alternating rows.
func _apply_row_stripe(ctrl: Control) -> void:
	if _prop_row_index % 2 == 1:
		var stripe_sb = StyleBoxFlat.new()
		stripe_sb.bg_color = Color(0.93, 0.92, 0.89, 0.5)  # subtle warm tint on odd rows
		stripe_sb.content_margin_left = 2
		stripe_sb.content_margin_right = 2
		ctrl.add_theme_stylebox_override("normal", stripe_sb)

## Called when the filter text changes — re-renders properties matching the query.
func _on_filter_changed(_new_text: String) -> void:
	_rerender_properties()

## Re-render the current property list (respects filter and view mode).
func _rerender_properties() -> void:
	for c in property_grid.get_children():
		c.queue_free()
	_prop_row_index = 0
	if _view_mode == 0:
		_render_alphabetic()
	else:
		_render_categorized()

## Check if a property entry matches the current filter text.
func _entry_matches_filter(entry: Dictionary) -> bool:
	if not is_instance_valid(_filter_edit) or _filter_edit.text.strip_edges().is_empty():
		return true  # no filter active
	var query = _filter_edit.text.strip_edges().to_lower()
	var label_lower = entry.get("label", "").to_lower()
	var key_lower = entry.get("prop_key", "").to_lower()
	return query in label_lower or query in key_lower

func update_properties(node: Node):
	_property_entries.clear()
	for c in property_grid.get_children():
		c.queue_free()
	current_node = node
	_refresh_object_dropdown()
	_description_label.text = ""
	
	# Collect all property entries first
	_collect_properties(node)
	
	# Render based on view mode
	if _view_mode == 0:
		_render_alphabetic()
	else:
		_render_categorized()

func _collect_properties(node: Node):
	"""Collect all property entries into _property_entries array."""
	# ===== (Name) - Always first, like VB6 =====
	_property_entries.append({"label": "(Name)", "value": String(node.name), "prop_key": "name", "type": "string", "category": ""})
	
	# ===== Appearance Properties =====
	if "text" in node:
		_property_entries.append({"label": "Caption", "value": node.text, "prop_key": "text", "type": "string", "category": CATEGORY_APPEARANCE})
	
	if node is Control:
		var back_color = _get_back_color(node)
		_property_entries.append({"label": "BackColor", "value": back_color, "prop_key": "backcolor", "type": "color", "category": CATEGORY_APPEARANCE})
		var fore_color = _get_fore_color(node)
		_property_entries.append({"label": "ForeColor", "value": fore_color, "prop_key": "forecolor", "type": "color", "category": CATEGORY_APPEARANCE})
	
	if node is BaseButton:
		if "flat" in node:
			_property_entries.append({"label": "Flat", "value": node.flat, "prop_key": "flat", "type": "bool", "category": CATEGORY_APPEARANCE})
	
	if node is Label:
		_property_entries.append({"label": "Alignment", "value": node.horizontal_alignment, "prop_key": "alignment", "type": "alignment", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "AutoSize", "value": node.autowrap_mode == TextServer.AUTOWRAP_OFF, "prop_key": "autosize", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "WordWrap", "value": node.autowrap_mode != TextServer.AUTOWRAP_OFF, "prop_key": "wordwrap", "type": "bool", "category": CATEGORY_APPEARANCE})
	
	if node is LineEdit:
		_property_entries.append({"label": "Text", "value": node.text, "prop_key": "text", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "MaxLength", "value": node.max_length, "prop_key": "max_length", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "PasswordMode", "value": node.secret, "prop_key": "secret", "type": "bool", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Locked", "value": !node.editable, "prop_key": "locked", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "PlaceholderText", "value": node.placeholder_text, "prop_key": "placeholder_text", "type": "string", "category": CATEGORY_APPEARANCE})
	
	if node is ProgressBar:
		_property_entries.append({"label": "Value", "value": node.value, "prop_key": "range_value", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Min", "value": node.min_value, "prop_key": "range_min", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Max", "value": node.max_value, "prop_key": "range_max", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "ShowPercent", "value": node.show_percentage, "prop_key": "show_percentage", "type": "bool", "category": CATEGORY_APPEARANCE})
	
	if node is Slider:
		_property_entries.append({"label": "Value", "value": node.value, "prop_key": "range_value", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Min", "value": node.min_value, "prop_key": "range_min", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Max", "value": node.max_value, "prop_key": "range_max", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Step", "value": node.step, "prop_key": "range_step", "type": "number", "category": CATEGORY_APPEARANCE})
	
	if node is SpinBox:
		_property_entries.append({"label": "Value", "value": node.value, "prop_key": "range_value", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Min", "value": node.min_value, "prop_key": "range_min", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Max", "value": node.max_value, "prop_key": "range_max", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Step", "value": node.step, "prop_key": "range_step", "type": "number", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Prefix", "value": node.prefix, "prop_key": "spinbox_prefix", "type": "string", "category": CATEGORY_APPEARANCE})
		_property_entries.append({"label": "Suffix", "value": node.suffix, "prop_key": "spinbox_suffix", "type": "string", "category": CATEGORY_APPEARANCE})
	
	# ===== Behavior Properties =====
	if node is Control:
		_property_entries.append({"label": "Enabled", "value": _get_enabled(node), "prop_key": "enabled", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "Visible", "value": node.visible, "prop_key": "visible", "type": "bool", "category": CATEGORY_BEHAVIOR})
		_property_entries.append({"label": "TabStop", "value": node.focus_mode != Control.FOCUS_NONE, "prop_key": "tabstop", "type": "bool", "category": CATEGORY_BEHAVIOR})
	
	if node is BaseButton:
		var is_default = node.has_meta("vb_default") and node.get_meta("vb_default")
		_property_entries.append({"label": "Default", "value": is_default, "prop_key": "default", "type": "bool", "category": CATEGORY_BEHAVIOR})
		var is_cancel = node.has_meta("vb_cancel") and node.get_meta("vb_cancel")
		_property_entries.append({"label": "Cancel", "value": is_cancel, "prop_key": "cancel", "type": "bool", "category": CATEGORY_BEHAVIOR})
	
	if node is CheckBox or node is CheckButton:
		_property_entries.append({"label": "Value", "value": node.button_pressed, "prop_key": "button_pressed", "type": "bool", "category": CATEGORY_BEHAVIOR})
	
	# ===== Font Properties =====
	if node is Control:
		var font_size = node.get_theme_font_size("font_size") if node.has_theme_font_size("font_size") else 14
		_property_entries.append({"label": "FontSize", "value": font_size, "prop_key": "font_size", "type": "number", "category": CATEGORY_FONT})
	
	# ===== Position Properties =====
	if node is Control or node is Node2D:
		_property_entries.append({"label": "Left", "value": int(node.position.x), "prop_key": "left", "type": "number", "category": CATEGORY_POSITION})
		_property_entries.append({"label": "Top", "value": int(node.position.y), "prop_key": "top", "type": "number", "category": CATEGORY_POSITION})
		
	if node is Control:
		_property_entries.append({"label": "Width", "value": int(node.size.x), "prop_key": "width", "type": "number", "category": CATEGORY_POSITION})
		_property_entries.append({"label": "Height", "value": int(node.size.y), "prop_key": "height", "type": "number", "category": CATEGORY_POSITION})
	
	# ===== Layout Properties =====
	if node is Control:
		_property_entries.append({"label": "Anchor", "value": node, "prop_key": "anchor", "type": "anchor", "category": "Layout"})
		_property_entries.append({"label": "MinWidth", "value": int(node.custom_minimum_size.x), "prop_key": "min_width", "type": "number", "category": "Layout"})
		_property_entries.append({"label": "MinHeight", "value": int(node.custom_minimum_size.y), "prop_key": "min_height", "type": "number", "category": "Layout"})
		_property_entries.append({"label": "ClipContent", "value": node.clip_contents, "prop_key": "clip_contents", "type": "bool", "category": "Layout"})
	
	# ===== Effects Properties =====
	if node is Control or node is Node2D:
		_property_entries.append({"label": "Opacity", "value": int(node.modulate.a * 100), "prop_key": "opacity", "type": "slider", "category": "Effects"})
		_property_entries.append({"label": "Rotation", "value": int(rad_to_deg(node.rotation)), "prop_key": "rotation", "type": "number", "category": "Effects"})
		_property_entries.append({"label": "ScaleX", "value": node.scale.x, "prop_key": "scale_x", "type": "number", "category": "Effects"})
		_property_entries.append({"label": "ScaleY", "value": node.scale.y, "prop_key": "scale_y", "type": "number", "category": "Effects"})
	
	if node is Control:
		_property_entries.append({"label": "Pivot", "value": {"pivot": node.pivot_offset, "size": node.size}, "prop_key": "pivot", "type": "pivot", "category": "Effects"})
	
	# ===== Misc Properties =====
	if node is Control:
		_property_entries.append({"label": "ToolTipText", "value": node.tooltip_text, "prop_key": "tooltip_text", "type": "string", "category": CATEGORY_MISC})
		_property_entries.append({"label": "MousePointer", "value": node.mouse_default_cursor_shape, "prop_key": "cursor", "type": "cursor", "category": CATEGORY_MISC})
	
	var tag_value = node.get_meta("vb_tag", "") if node.has_meta("vb_tag") else ""
	_property_entries.append({"label": "Tag", "value": str(tag_value), "prop_key": "tag", "type": "string", "category": CATEGORY_MISC})

func _render_categorized():
	"""Render properties grouped by category with section headers."""
	_prop_row_index = 0
	# (Name) is always first
	for entry in _property_entries:
		if entry["category"] == "" and _entry_matches_filter(entry):
			_render_property_entry(entry)
	
	# Group by category — include dynamic categories from Game UI prototypes
	var static_cats := [CATEGORY_APPEARANCE]
	var dynamic_cats: Array = []
	var tail_cats := [CATEGORY_BEHAVIOR, CATEGORY_FONT, CATEGORY_POSITION, "Layout", "Effects", CATEGORY_MISC]
	var known_cats := static_cats + tail_cats
	for entry in _property_entries:
		var cat: String = entry.get("category", "")
		if cat != "" and cat not in known_cats and cat not in dynamic_cats:
			dynamic_cats.append(cat)
	var categories_order = static_cats + dynamic_cats + tail_cats
	for cat in categories_order:
		var cat_entries = _property_entries.filter(func(e): return e["category"] == cat and _entry_matches_filter(e))
		if cat_entries.size() > 0:
			_add_section_header(cat)
			for entry in cat_entries:
				_render_property_entry(entry)

func _render_alphabetic():
	"""Render all properties sorted alphabetically (no section headers)."""
	_prop_row_index = 0
	# (Name) is always first
	for entry in _property_entries:
		if entry["category"] == "" and _entry_matches_filter(entry):
			_render_property_entry(entry)
	
	# Sort remaining entries alphabetically
	var sorted_entries = _property_entries.filter(func(e): return e["category"] != "" and _entry_matches_filter(e))
	sorted_entries.sort_custom(func(a, b): return a["label"].to_lower() < b["label"].to_lower())
	for entry in sorted_entries:
		_render_property_entry(entry)

func _render_property_entry(entry: Dictionary):
	"""Render a single property entry to the grid."""
	var prop_key = entry["prop_key"]
	var label_text = entry["label"]
	var value = entry["value"]
	var type = entry["type"]
	
	match type:
		"color":
			_add_color_row(label_text, value, prop_key)
		"alignment":
			_add_alignment_row(label_text, value)
		"cursor":
			_add_cursor_row(label_text, value)
		"slider":
			_add_slider_row(label_text, value, prop_key)
		"anchor":
			_add_anchor_row(label_text, value)
		"pivot":
			_add_pivot_row(label_text, value["pivot"], value["size"])
		"readonly":
			_add_readonly_row(label_text, value)
		"fd_enum_borderstyle":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - None", "1 - Fixed Single"])
		"fd_enum_appearance":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - Flat", "1 - 3D"])
		"fd_enum_alignment":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - Left Justify", "1 - Right Justify", "2 - Center"])
		"fd_enum_style":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - Standard", "1 - Graphical"])
		"fd_enum_scrollbars":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - None", "1 - Horizontal", "2 - Vertical", "3 - Both"])
		"fd_enum_multiselect":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - None", "1 - Simple", "2 - Extended"])
		"fd_enum_mousepointer":
			_add_fd_enum_row(label_text, prop_key, value, [
				"0 - Default", "1 - Arrow", "2 - Crosshair", "3 - IBeam",
				"4 - Size All", "5 - Size NESW", "6 - Size NS",
				"7 - Size NWSE", "8 - Size WE", "9 - Up Arrow",
				"10 - Hourglass", "11 - No Drop", "12 - Hand"
			])
		"fd_enum_form_borderstyle":
			_add_fd_enum_row(label_text, prop_key, value, [
				"0 - None", "1 - Fixed Single", "2 - Sizable",
				"3 - Fixed Dialog", "4 - Fixed ToolWindow", "5 - Sizable ToolWindow"
			])
		"fd_enum_windowstate":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - Normal", "1 - Minimized", "2 - Maximized"])
		"fd_enum_startposition":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - Manual", "1 - CenterOwner", "2 - CenterScreen", "3 - Windows Default"])
		"fd_enum_windowtype":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - Game (SubViewport)", "1 - Windows", "2 - Linux/CSD", "3 - macOS"])
		"fd_enum_iconalignment":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - Left", "1 - Center", "2 - Right"])
		"fd_enum_valignment":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - Top", "1 - Center", "2 - Bottom"])
		"fd_enum_fillmode":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - Left to Right", "1 - Right to Left", "2 - Top to Bottom", "3 - Bottom to Top"])
		"fd_enum_stretchmode":
			_add_fd_enum_row(label_text, prop_key, value, [
				"0 - Scale", "1 - Tile", "2 - Keep", "3 - Keep Centered",
				"4 - Keep Aspect", "5 - Keep Aspect Centered", "6 - Keep Aspect Covered"
			])
		"fd_enum_iconmode":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - Top", "1 - Left"])
		"fd_enum_tabalignment":
			_add_fd_enum_row(label_text, prop_key, value, ["0 - Left", "1 - Center", "2 - Right"])
		"font_name":
			_add_font_name_row(label_text, value, prop_key)
		"prototype_enum":
			var enum_items: Array = entry.get("enum_items", [])
			_add_fd_enum_row(label_text, prop_key, value, enum_items)
		_:
			_add_prop_row(label_text, value, prop_key)

## Read-only display row (e.g., Index)
func _add_readonly_row(label_text: String, value):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 70
	lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	_apply_row_stripe(lbl)
	property_grid.add_child(lbl)
	var val_lbl = Label.new()
	val_lbl.text = str(value)
	val_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))  # dimmed readonly
	property_grid.add_child(val_lbl)
	_prop_row_index += 1

## FormDesigner enum dropdown row
func _add_fd_enum_row(label_text: String, prop_key: String, current_value: int, items: Array):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 70
	lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	var desc = PROPERTY_DESCRIPTIONS.get(prop_key, PROPERTY_DESCRIPTIONS.get(prop_key.to_lower(), ""))
	if not desc.is_empty():
		lbl.tooltip_text = desc
	_apply_row_stripe(lbl)
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_show_description(prop_key.to_lower())
	)
	property_grid.add_child(lbl)

	var opt = OptionButton.new()
	for item_text in items:
		opt.add_item(item_text)
	if current_value >= 0 and current_value < items.size():
		opt.select(current_value)
	opt.size_flags_horizontal = SIZE_EXPAND_FILL
	_style_option_button(opt)
	opt.item_selected.connect(func(idx): _apply_prop(prop_key, idx))
	property_grid.add_child(opt)
	_prop_row_index += 1

## Style an OptionButton and its popup for readability on the light Properties panel
func _style_option_button(opt: OptionButton):
	opt.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	opt.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.4))
	opt.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.4))
	opt.add_theme_color_override("font_focus_color", Color(0.1, 0.1, 0.1))
	var popup = opt.get_popup()
	popup.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	popup.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.96, 0.95, 0.93)
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_color = Color(0.55, 0.54, 0.52)
	popup.add_theme_stylebox_override("panel", panel_style)
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.0, 0.47, 0.84)  # blue highlight
	hover_style.corner_radius_top_left = 2
	hover_style.corner_radius_top_right = 2
	hover_style.corner_radius_bottom_left = 2
	hover_style.corner_radius_bottom_right = 2
	popup.add_theme_stylebox_override("hover", hover_style)

## Style a LineEdit for readability on the light Properties panel
func _style_line_edit(le: LineEdit):
	le.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	le.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.5))
	le.add_theme_color_override("caret_color", Color(0.0, 0.0, 0.0))
	le.add_theme_color_override("selection_color", Color(0.26, 0.52, 0.96, 0.4))
	var le_normal = StyleBoxFlat.new()
	le_normal.bg_color = Color(1.0, 1.0, 1.0)
	le_normal.border_width_top = 1
	le_normal.border_width_bottom = 1
	le_normal.border_width_left = 1
	le_normal.border_width_right = 1
	le_normal.border_color = Color(0.65, 0.64, 0.62)
	le_normal.content_margin_left = 4
	le_normal.content_margin_right = 4
	le.add_theme_stylebox_override("normal", le_normal)
	var le_focus = le_normal.duplicate()
	le_focus.border_color = Color(0.0, 0.47, 0.84)
	le.add_theme_stylebox_override("focus", le_focus)

## Returns the large step used for Shift+Up / Shift+Down on numeric fields.
## Position / size properties use 10; Interval uses 100; everything else uses 10.
func _get_numeric_shift_step(prop_key: String) -> float:
	var big_step_keys := ["Interval"]
	var medium_step_keys := ["x", "y", "width", "height", "Width", "Height",
		"left", "top", "Left", "Top", "Min", "Max", "Page",
		"MaxLength", "FixedColumnWidth", "FixedIconSize"]
	if prop_key in big_step_keys:
		return 100.0
	if prop_key in medium_step_keys:
		return 10.0
	return 10.0

## Create dark-on-white checkbox icons so unchecked boxes stay visible on the
## light Properties panel background. Godot's editor-theme icons are white-on-dark
## and become invisible when the panel uses a light style.
func _ensure_checkbox_icons():
	if _chk_unchecked_icon:
		return  # already built
	var sz := 16
	var border := Color(0.25, 0.25, 0.25)
	var fill   := Color(1.0, 1.0, 1.0)
	var check  := Color(0.0, 0.25, 0.6)

	# --- unchecked: white square with dark 1-px border ---
	var img_u := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img_u.fill(Color(0, 0, 0, 0))
	for x in sz:
		for y in sz:
			if x == 0 or x == sz - 1 or y == 0 or y == sz - 1:
				img_u.set_pixel(x, y, border)
			elif x >= 1 and x <= sz - 2 and y >= 1 and y <= sz - 2:
				img_u.set_pixel(x, y, fill)
	_chk_unchecked_icon = ImageTexture.create_from_image(img_u)

	# --- checked: same box plus a dark-blue checkmark ---
	var img_c := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img_c.fill(Color(0, 0, 0, 0))
	for x in sz:
		for y in sz:
			if x == 0 or x == sz - 1 or y == 0 or y == sz - 1:
				img_c.set_pixel(x, y, border)
			elif x >= 1 and x <= sz - 2 and y >= 1 and y <= sz - 2:
				img_c.set_pixel(x, y, fill)
	# Checkmark path (2-px thick): down-stroke 3,8→6,11  up-stroke 7,10→12,5
	var pts: Array[Vector2i] = [
		Vector2i(3,8), Vector2i(4,9), Vector2i(5,10), Vector2i(6,11),
		Vector2i(7,10), Vector2i(8,9), Vector2i(9,8), Vector2i(10,7), Vector2i(11,6), Vector2i(12,5),
		# second row (1 px up) for thickness
		Vector2i(3,7), Vector2i(4,8), Vector2i(5,9), Vector2i(6,10),
		Vector2i(7,9), Vector2i(8,8), Vector2i(9,7), Vector2i(10,6), Vector2i(11,5), Vector2i(12,4),
	]
	for p in pts:
		if p.x >= 1 and p.x < sz - 1 and p.y >= 1 and p.y < sz - 1:
			img_c.set_pixel(p.x, p.y, check)
	_chk_checked_icon = ImageTexture.create_from_image(img_c)

## Font name dropdown with common VB6 / system fonts
func _add_font_name_row(label_text: String, current_font: String, prop_key: String):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 70
	lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	var desc = PROPERTY_DESCRIPTIONS.get(prop_key, PROPERTY_DESCRIPTIONS.get(prop_key.to_lower(), ""))
	if not desc.is_empty():
		lbl.tooltip_text = desc
	_apply_row_stripe(lbl)
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_show_description(prop_key.to_lower())
	)
	property_grid.add_child(lbl)

	var fonts: Array = [
		"MS Sans Serif", "Arial", "Courier New", "Comic Sans MS",
		"Georgia", "Impact", "Lucida Console", "Segoe UI",
		"Tahoma", "Times New Roman", "Trebuchet MS", "Verdana",
		"Consolas", "Calibri", "Cambria", "Palatino Linotype",
		"Franklin Gothic Medium", "Book Antiqua", "Garamond",
		"Century Gothic", "Fixedsys", "Terminal", "System",
	]
	var opt = OptionButton.new()
	opt.size_flags_horizontal = SIZE_EXPAND_FILL
	opt.clip_text = true
	_style_option_button(opt)
	var selected_idx := 0
	for i in fonts.size():
		opt.add_item(fonts[i])
		if fonts[i].to_lower() == current_font.to_lower():
			selected_idx = i
	opt.select(selected_idx)
	opt.item_selected.connect(func(idx): _apply_prop(prop_key, fonts[idx]))
	opt.focus_entered.connect(func(): _show_description(prop_key.to_lower()))
	property_grid.add_child(opt)
	_prop_row_index += 1

func _add_section_header(title: String):
	var sep = HSeparator.new()
	sep.custom_minimum_size.y = 4
	property_grid.add_child(sep)
	
	var lbl = Label.new()
	lbl.text = title.to_upper()
	lbl.add_theme_color_override("font_color", Color("#003399"))  # navy blue section header
	property_grid.add_child(lbl)

func _add_prop_row(label_text: String, value, prop_key: String):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 70  # Reduced for narrower panels
	lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	# Non-intrusive hover tooltip with property description
	var desc = PROPERTY_DESCRIPTIONS.get(prop_key, PROPERTY_DESCRIPTIONS.get(prop_key.to_lower(), ""))
	if not desc.is_empty():
		lbl.tooltip_text = desc
	# Zebra-stripe background on odd rows
	_apply_row_stripe(lbl)
	lbl.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_show_description(prop_key)
	)
	property_grid.add_child(lbl)
	
	if value is bool:
		var chk = CheckBox.new()
		chk.button_pressed = value
		chk.flat = true
		chk.size_flags_horizontal = SIZE_EXPAND_FILL
		# Remove button-like chrome — show only the check indicator
		var empty_style = StyleBoxEmpty.new()
		chk.add_theme_stylebox_override("normal", empty_style)
		chk.add_theme_stylebox_override("hover", empty_style)
		chk.add_theme_stylebox_override("pressed", empty_style)
		chk.add_theme_stylebox_override("focus", empty_style)
		# Override icons with custom dark-on-white versions
		_ensure_checkbox_icons()
		chk.add_theme_icon_override("unchecked", _chk_unchecked_icon)
		chk.add_theme_icon_override("checked", _chk_checked_icon)
		chk.toggled.connect(func(v): _apply_prop(prop_key, v))
		chk.focus_entered.connect(func(): _show_description(prop_key))
		property_grid.add_child(chk)
	elif value is String:
		var txt = LineEdit.new()
		txt.text = value
		txt.size_flags_horizontal = SIZE_EXPAND_FILL
		_style_line_edit(txt)
		txt.text_submitted.connect(func(v): _apply_prop(prop_key, v))
		txt.focus_exited.connect(func(): _apply_prop(prop_key, txt.text))
		txt.focus_entered.connect(func(): _show_description(prop_key))
		property_grid.add_child(txt)
	elif value is float or value is int:
		var spin = SpinBox.new()
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.value = value
		spin.max_value = 10000
		spin.min_value = -10000
		spin.step = 1
		spin.size_flags_horizontal = SIZE_EXPAND_FILL
		_style_line_edit(spin.get_line_edit())
		spin.value_changed.connect(func(v): _apply_prop(prop_key, v))
		spin.get_line_edit().focus_entered.connect(func(): _show_description(prop_key))
		# Shift+Up/Down for larger increments (10 or 100 depending on property)
		var shift_step := _get_numeric_shift_step(prop_key)
		spin.get_line_edit().gui_input.connect(func(event: InputEvent):
			if event is InputEventKey and event.pressed and event.shift_pressed:
				if event.keycode == KEY_UP:
					spin.value += shift_step
					spin.get_line_edit().accept_event()
				elif event.keycode == KEY_DOWN:
					spin.value -= shift_step
					spin.get_line_edit().accept_event()
		)
		property_grid.add_child(spin)
	else:
		var placeholder = Label.new()
		placeholder.text = str(value)
		placeholder.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
		property_grid.add_child(placeholder)
	_prop_row_index += 1

func _add_color_row(label_text: String, color: Color, prop_key: String):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	var desc = PROPERTY_DESCRIPTIONS.get(prop_key, PROPERTY_DESCRIPTIONS.get(prop_key.to_lower(), ""))
	if not desc.is_empty():
		lbl.tooltip_text = desc
	_apply_row_stripe(lbl)
	property_grid.add_child(lbl)
	
	var color_btn = ColorPickerButton.new()
	color_btn.color = color
	color_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	color_btn.custom_minimum_size.y = 24
	color_btn.edit_alpha = true
	color_btn.color_changed.connect(func(c): _apply_prop(prop_key, c))
	_apply_row_stripe(color_btn)
	property_grid.add_child(color_btn)
	_prop_row_index += 1

func _add_alignment_row(label_text: String, alignment: int):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	var desc = PROPERTY_DESCRIPTIONS.get("alignment", "")
	if not desc.is_empty():
		lbl.tooltip_text = desc
	_apply_row_stripe(lbl)
	property_grid.add_child(lbl)
	
	var opt = OptionButton.new()
	opt.add_item("Left", 0)    # HORIZONTAL_ALIGNMENT_LEFT
	opt.add_item("Center", 1)  # HORIZONTAL_ALIGNMENT_CENTER
	opt.add_item("Right", 2)   # HORIZONTAL_ALIGNMENT_RIGHT
	opt.select(alignment)
	opt.size_flags_horizontal = SIZE_EXPAND_FILL
	_style_option_button(opt)
	opt.item_selected.connect(func(idx): _apply_prop("alignment", idx))
	property_grid.add_child(opt)
	_prop_row_index += 1

func _add_cursor_row(label_text: String, cursor: int):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	var desc = PROPERTY_DESCRIPTIONS.get("mousepointer", PROPERTY_DESCRIPTIONS.get("cursor", ""))
	if not desc.is_empty():
		lbl.tooltip_text = desc
	_apply_row_stripe(lbl)
	property_grid.add_child(lbl)
	
	var opt = OptionButton.new()
	opt.add_item("Default", Control.CURSOR_ARROW)
	opt.add_item("IBeam", Control.CURSOR_IBEAM)
	opt.add_item("Pointing Hand", Control.CURSOR_POINTING_HAND)
	opt.add_item("Cross", Control.CURSOR_CROSS)
	opt.add_item("Wait", Control.CURSOR_WAIT)
	opt.add_item("Busy", Control.CURSOR_BUSY)
	opt.add_item("Move", Control.CURSOR_MOVE)
	opt.add_item("SizeNS", Control.CURSOR_VSIZE)
	opt.add_item("SizeWE", Control.CURSOR_HSIZE)
	# Select current
	for i in opt.item_count:
		if opt.get_item_id(i) == cursor:
			opt.select(i)
			break
	opt.size_flags_horizontal = SIZE_EXPAND_FILL
	_style_option_button(opt)
	opt.item_selected.connect(func(idx): _apply_prop("cursor", opt.get_item_id(idx)))
	property_grid.add_child(opt)
	_prop_row_index += 1

func _add_slider_row(label_text: String, value: int, prop_key: String):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	var desc = PROPERTY_DESCRIPTIONS.get(prop_key, PROPERTY_DESCRIPTIONS.get(prop_key.to_lower(), ""))
	if not desc.is_empty():
		lbl.tooltip_text = desc
	_apply_row_stripe(lbl)
	property_grid.add_child(lbl)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = value
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 60
	
	var spin = SpinBox.new()
	spin.min_value = 0
	spin.max_value = 100
	spin.value = value
	spin.suffix = "%"
	spin.custom_minimum_size.x = 60
	
	slider.value_changed.connect(func(v): 
		spin.value = v
		_apply_prop(prop_key, v)
	)
	spin.value_changed.connect(func(v): 
		slider.value = v
		_apply_prop(prop_key, v)
	)
	
	hbox.add_child(slider)
	hbox.add_child(spin)
	property_grid.add_child(hbox)
	_prop_row_index += 1

func _add_anchor_row(label_text: String, node: Control):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	var desc = PROPERTY_DESCRIPTIONS.get("anchor", "")
	if not desc.is_empty():
		lbl.tooltip_text = desc
	_apply_row_stripe(lbl)
	property_grid.add_child(lbl)
	
	var opt = OptionButton.new()
	opt.add_item("None", 0)
	opt.add_item("Full Rect", 1)
	opt.add_item("Left Wide", 2)
	opt.add_item("Top Wide", 3)
	opt.add_item("Right Wide", 4)
	opt.add_item("Bottom Wide", 5)
	opt.add_item("Center", 6)
	opt.add_item("VCenter Wide", 7)
	opt.add_item("HCenter Wide", 8)
	
	# Detect current anchor preset
	var preset = _detect_anchor_preset(node)
	opt.select(preset)
	
	opt.size_flags_horizontal = SIZE_EXPAND_FILL
	_style_option_button(opt)
	opt.item_selected.connect(func(idx): _apply_prop("anchor", idx))
	property_grid.add_child(opt)
	_prop_row_index += 1

func _add_pivot_row(label_text: String, pivot: Vector2, size: Vector2):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	var desc = PROPERTY_DESCRIPTIONS.get("pivot", "")
	if not desc.is_empty():
		lbl.tooltip_text = desc
	_apply_row_stripe(lbl)
	property_grid.add_child(lbl)
	
	var opt = OptionButton.new()
	opt.add_item("Top-Left", 0)
	opt.add_item("Top-Center", 1)
	opt.add_item("Top-Right", 2)
	opt.add_item("Center-Left", 3)
	opt.add_item("Center", 4)
	opt.add_item("Center-Right", 5)
	opt.add_item("Bottom-Left", 6)
	opt.add_item("Bottom-Center", 7)
	opt.add_item("Bottom-Right", 8)
	
	# Detect current pivot
	var preset = _detect_pivot_preset(pivot, size)
	opt.select(preset)
	
	opt.size_flags_horizontal = SIZE_EXPAND_FILL
	_style_option_button(opt)
	opt.item_selected.connect(func(idx): _apply_prop("pivot", idx))
	property_grid.add_child(opt)
	_prop_row_index += 1

func _detect_anchor_preset(node: Control) -> int:
	# Simple detection based on anchor values
	if node.anchor_left == 0 and node.anchor_top == 0 and node.anchor_right == 0 and node.anchor_bottom == 0:
		return 0  # None (top-left)
	elif node.anchor_left == 0 and node.anchor_top == 0 and node.anchor_right == 1 and node.anchor_bottom == 1:
		return 1  # Full Rect
	elif node.anchor_left == 0 and node.anchor_right == 0:
		return 2  # Left Wide
	elif node.anchor_top == 0 and node.anchor_bottom == 0:
		return 3  # Top Wide
	elif node.anchor_left == 0.5 and node.anchor_right == 0.5:
		return 6  # Center
	return 0

func _detect_pivot_preset(pivot: Vector2, size: Vector2) -> int:
	if size.x <= 0 or size.y <= 0:
		return 0
	var px = pivot.x / size.x if size.x > 0 else 0
	var py = pivot.y / size.y if size.y > 0 else 0
	
	if px < 0.25 and py < 0.25:
		return 0  # Top-Left
	elif px > 0.75 and py < 0.25:
		return 2  # Top-Right
	elif px < 0.25 and py > 0.75:
		return 6  # Bottom-Left
	elif px > 0.75 and py > 0.75:
		return 8  # Bottom-Right
	elif py < 0.25:
		return 1  # Top-Center
	elif py > 0.75:
		return 7  # Bottom-Center
	elif px < 0.25:
		return 3  # Center-Left
	elif px > 0.75:
		return 5  # Center-Right
	return 4  # Center

func _get_enabled(node: Node) -> bool:
	if node is BaseButton:
		return !node.disabled
	elif node is LineEdit:
		return node.editable
	elif node is Control:
		return node.mouse_filter != Control.MOUSE_FILTER_IGNORE
	return true

func _apply_prop(prop_key: String, value):
	# --- Form Designer mode: route to C++ FormDesigner ---
	if _fd_mode:
		_apply_fd_prop(prop_key, value)
		return

	if not current_node:
		return
	
	match prop_key:
		"name":
			_handle_rename(String(current_node.name), str(value))
		"text":
			if "text" in current_node:
				current_node.text = value
		"visible":
			current_node.visible = value
		"enabled":
			if current_node is BaseButton:
				current_node.disabled = !value
			elif current_node is LineEdit:
				current_node.editable = value
		"tabstop":
			if current_node is Control:
				current_node.focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
		"left":
			current_node.position.x = value
		"top":
			current_node.position.y = value
		"width":
			if current_node is Control:
				current_node.size.x = value
		"height":
			if current_node is Control:
				current_node.size.y = value
		"tooltip_text":
			if current_node is Control:
				current_node.tooltip_text = str(value)
				print("VisualGasic: Set tooltip to '", value, "' on ", current_node.name)
		"tag":
			current_node.set_meta("vb_tag", value)
		"default":
			current_node.set_meta("vb_default", value)
			# Could also set up shortcut for Enter key
		"cancel":
			current_node.set_meta("vb_cancel", value)
			# Could also set up shortcut for Escape key
		"flat":
			if "flat" in current_node:
				current_node.flat = value
		"backcolor":
			_apply_back_color(value)
		"forecolor":
			_apply_fore_color(value)
		"alignment":
			if current_node is Label:
				current_node.horizontal_alignment = value
		"cursor":
			if current_node is Control:
				current_node.mouse_default_cursor_shape = value
		"max_length":
			if current_node is LineEdit:
				current_node.max_length = int(value)
		"secret":
			if current_node is LineEdit:
				current_node.secret = value
		"locked":
			if current_node is LineEdit:
				current_node.editable = !value
		"placeholder_text":
			if current_node is LineEdit:
				current_node.placeholder_text = value
		"button_pressed":
			if current_node is BaseButton:
				current_node.button_pressed = value
		"autosize":
			if current_node is Label:
				current_node.autowrap_mode = TextServer.AUTOWRAP_OFF if value else TextServer.AUTOWRAP_WORD_SMART
		"wordwrap":
			if current_node is Label:
				current_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if value else TextServer.AUTOWRAP_OFF
		"font_size":
			if current_node is Control:
				current_node.add_theme_font_size_override("font_size", int(value))
		# Modern properties
		"opacity":
			var mod = current_node.modulate
			mod.a = value / 100.0
			current_node.modulate = mod
		"rotation":
			current_node.rotation = deg_to_rad(value)
		"scale_x":
			current_node.scale.x = value
		"scale_y":
			current_node.scale.y = value
		"min_width":
			if current_node is Control:
				current_node.custom_minimum_size.x = value
		"min_height":
			if current_node is Control:
				current_node.custom_minimum_size.y = value
		"clip_contents":
			if current_node is Control:
				current_node.clip_contents = value
		"anchor":
			_apply_anchor_preset(int(value))
		"pivot":
			_apply_pivot_preset(int(value))
		# Range controls (ProgressBar, Slider, SpinBox)
		"range_value":
			if current_node is Range:
				current_node.value = value
		"range_min":
			if current_node is Range:
				current_node.min_value = value
		"range_max":
			if current_node is Range:
				current_node.max_value = value
		"range_step":
			if current_node is Range:
				current_node.step = value
		"show_percentage":
			if current_node is ProgressBar:
				current_node.show_percentage = value
		"spinbox_prefix":
			if current_node is SpinBox:
				current_node.prefix = value
		"spinbox_suffix":
			if current_node is SpinBox:
				current_node.suffix = value

# ==========================================================================
# Form Designer property application
# ==========================================================================

## Routes a property change to the C++ FormDesigner.
## In form mode (_fd_form_mode), uses set_form_property().
## In control mode, uses set_control_property().
func _apply_fd_prop(prop_key: String, value) -> void:
	if not is_instance_valid(_fd_designer):
		push_warning("VisualGasic Inspector: No FormDesigner for property change")
		return

	# Form-level properties go through set_form_property
	if _fd_form_mode:
		# If renaming the form (Caption / (Name) change), handle file rename first
		if prop_key == "Caption":
			var old_name: String = _fd_designer.get_form_name()
			var new_name: String = str(value).strip_edges()
			if new_name.is_empty():
				push_warning("VisualGasic Inspector: Form name cannot be empty")
				return
			if new_name != old_name and is_instance_valid(editor_plugin) and editor_plugin.has_method("handle_form_rename"):
				if not editor_plugin.handle_form_rename(old_name, new_name):
					push_warning("VisualGasic Inspector: Form rename failed — reverting")
					call_deferred("show_form_properties", _fd_designer)
					return
				# Rename succeeded — the plugin already called set_form_name + save_form_as,
				# so just refresh the inspector without calling set_form_property again.
				call_deferred("show_form_properties", _fd_designer)
				return

		_fd_designer.set_form_property(prop_key, value)
		print("VisualGasic Inspector: Set form property '", prop_key, "' = ", value)
		# Don't rebuild the grid — the C++ side already redraws the form.
		# Only refresh for Caption changes (which also update the (Name) display).
		if prop_key == "Caption":
			call_deferred("show_form_properties", _fd_designer)
		return

	if _fd_control_index < 0:
		push_warning("VisualGasic Inspector: No control index for property change")
		return

	# Map VB6-style property keys to what the C++ set_control_property expects
	match prop_key:
		"name":
			_fd_designer.set_control_property(_fd_control_index, "name", str(value))
		"text":
			_fd_designer.set_control_property(_fd_control_index, "text", str(value))
		"visible":
			_fd_designer.set_control_property(_fd_control_index, "visible", bool(value))
		"x":
			_fd_designer.set_control_property(_fd_control_index, "x", float(value))
		"y":
			_fd_designer.set_control_property(_fd_control_index, "y", float(value))
		"width":
			_fd_designer.set_control_property(_fd_control_index, "width", float(value))
		"height":
			_fd_designer.set_control_property(_fd_control_index, "height", float(value))
		_:
			# Everything else stored in the generic properties Dictionary
			_fd_designer.set_control_property(_fd_control_index, prop_key, value)

	print("VisualGasic Inspector: Set FD property '", prop_key, "' = ", value, " on control #", _fd_control_index)

## Get the current background color of a control
func _get_back_color(node: Control) -> Color:
	# Check for stored meta color first
	if node.has_meta("vb_backcolor"):
		return node.get_meta("vb_backcolor")
	# Try to get from theme stylebox
	if node.has_theme_stylebox_override("normal"):
		var style = node.get_theme_stylebox("normal")
		if style is StyleBoxFlat:
			return style.bg_color
	# Default gray
	return Color(0.8, 0.8, 0.8, 1.0)

## Get the current foreground (text) color of a control
func _get_fore_color(node: Control) -> Color:
	# Check for stored meta color first
	if node.has_meta("vb_forecolor"):
		return node.get_meta("vb_forecolor")
	# Try to get from theme color override
	if node.has_theme_color_override("font_color"):
		return node.get_theme_color("font_color")
	# Default black
	return Color(0.0, 0.0, 0.0, 1.0)

## Apply background color to a control using theme stylebox
func _apply_back_color(color: Color):
	if not current_node or not current_node is Control:
		return
	
	# Store for later retrieval
	current_node.set_meta("vb_backcolor", color)
	
	# For buttons (Button, CheckBox, etc.)
	if current_node is BaseButton:
		# Create styleboxes for all button states
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = color
		style_normal.set_corner_radius_all(3)
		style_normal.set_border_width_all(1)
		style_normal.border_color = color.darkened(0.2)
		style_normal.content_margin_left = 8
		style_normal.content_margin_right = 8
		style_normal.content_margin_top = 4
		style_normal.content_margin_bottom = 4
		
		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = color.lightened(0.1)
		style_hover.set_corner_radius_all(3)
		style_hover.set_border_width_all(1)
		style_hover.border_color = color.darkened(0.1)
		style_hover.content_margin_left = 8
		style_hover.content_margin_right = 8
		style_hover.content_margin_top = 4
		style_hover.content_margin_bottom = 4
		
		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = color.darkened(0.15)
		style_pressed.set_corner_radius_all(3)
		style_pressed.set_border_width_all(1)
		style_pressed.border_color = color.darkened(0.3)
		style_pressed.content_margin_left = 8
		style_pressed.content_margin_right = 8
		style_pressed.content_margin_top = 4
		style_pressed.content_margin_bottom = 4
		
		var style_disabled = StyleBoxFlat.new()
		style_disabled.bg_color = color.darkened(0.3)
		style_disabled.set_corner_radius_all(3)
		style_disabled.set_border_width_all(1)
		style_disabled.border_color = color.darkened(0.4)
		style_disabled.content_margin_left = 8
		style_disabled.content_margin_right = 8
		style_disabled.content_margin_top = 4
		style_disabled.content_margin_bottom = 4
		
		current_node.add_theme_stylebox_override("normal", style_normal)
		current_node.add_theme_stylebox_override("hover", style_hover)
		current_node.add_theme_stylebox_override("pressed", style_pressed)
		current_node.add_theme_stylebox_override("focus", style_hover)
		current_node.add_theme_stylebox_override("disabled", style_disabled)
		print("VisualGasic: Applied BackColor ", color, " to ", current_node.name)
	
	elif current_node is Panel:
		var style = StyleBoxFlat.new()
		style.bg_color = color
		current_node.add_theme_stylebox_override("panel", style)
	
	elif current_node is LineEdit:
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.set_border_width_all(1)
		style.border_color = Color(0.3, 0.3, 0.3)
		style.content_margin_left = 4
		style.content_margin_right = 4
		current_node.add_theme_stylebox_override("normal", style)
	
	elif current_node is Label:
		# Labels use a panel stylebox for background
		var style = StyleBoxFlat.new()
		style.bg_color = color
		current_node.add_theme_stylebox_override("normal", style)

## Apply foreground (text) color to a control
func _apply_fore_color(color: Color):
	if not current_node or not current_node is Control:
		return
	
	# Store for later retrieval
	current_node.set_meta("vb_forecolor", color)
	
	# Apply font color override
	current_node.add_theme_color_override("font_color", color)
	
	# For buttons, also set hover/pressed colors
	if current_node is BaseButton:
		current_node.add_theme_color_override("font_hover_color", color)
		current_node.add_theme_color_override("font_pressed_color", color)
		current_node.add_theme_color_override("font_focus_color", color)
		current_node.add_theme_color_override("font_disabled_color", color.darkened(0.3))
	
	# For LineEdit, set text color
	if current_node is LineEdit:
		current_node.add_theme_color_override("font_color", color)
		current_node.add_theme_color_override("font_placeholder_color", color.darkened(0.3))

## Apply anchor preset to control
func _apply_anchor_preset(preset: int):
	if not current_node or not current_node is Control:
		return
	
	match preset:
		0:  # None (top-left)
			current_node.anchor_left = 0
			current_node.anchor_top = 0
			current_node.anchor_right = 0
			current_node.anchor_bottom = 0
		1:  # Full Rect
			current_node.anchor_left = 0
			current_node.anchor_top = 0
			current_node.anchor_right = 1
			current_node.anchor_bottom = 1
			current_node.offset_left = 0
			current_node.offset_top = 0
			current_node.offset_right = 0
			current_node.offset_bottom = 0
		2:  # Left Wide
			current_node.anchor_left = 0
			current_node.anchor_top = 0
			current_node.anchor_right = 0
			current_node.anchor_bottom = 1
			current_node.offset_bottom = 0
		3:  # Top Wide
			current_node.anchor_left = 0
			current_node.anchor_top = 0
			current_node.anchor_right = 1
			current_node.anchor_bottom = 0
			current_node.offset_right = 0
		4:  # Right Wide
			current_node.anchor_left = 1
			current_node.anchor_top = 0
			current_node.anchor_right = 1
			current_node.anchor_bottom = 1
			current_node.offset_left = -current_node.size.x
			current_node.offset_bottom = 0
		5:  # Bottom Wide
			current_node.anchor_left = 0
			current_node.anchor_top = 1
			current_node.anchor_right = 1
			current_node.anchor_bottom = 1
			current_node.offset_top = -current_node.size.y
			current_node.offset_right = 0
		6:  # Center
			current_node.anchor_left = 0.5
			current_node.anchor_top = 0.5
			current_node.anchor_right = 0.5
			current_node.anchor_bottom = 0.5
			current_node.offset_left = -current_node.size.x / 2
			current_node.offset_top = -current_node.size.y / 2
			current_node.offset_right = current_node.size.x / 2
			current_node.offset_bottom = current_node.size.y / 2
		7:  # VCenter Wide
			current_node.anchor_left = 0
			current_node.anchor_top = 0.5
			current_node.anchor_right = 1
			current_node.anchor_bottom = 0.5
			current_node.offset_top = -current_node.size.y / 2
			current_node.offset_right = 0
			current_node.offset_bottom = current_node.size.y / 2
		8:  # HCenter Wide
			current_node.anchor_left = 0.5
			current_node.anchor_top = 0
			current_node.anchor_right = 0.5
			current_node.anchor_bottom = 1
			current_node.offset_left = -current_node.size.x / 2
			current_node.offset_right = current_node.size.x / 2
			current_node.offset_bottom = 0

## Apply pivot preset to control
func _apply_pivot_preset(preset: int):
	if not current_node or not current_node is Control:
		return
	
	var size = current_node.size
	match preset:
		0:  # Top-Left
			current_node.pivot_offset = Vector2(0, 0)
		1:  # Top-Center
			current_node.pivot_offset = Vector2(size.x / 2, 0)
		2:  # Top-Right
			current_node.pivot_offset = Vector2(size.x, 0)
		3:  # Center-Left
			current_node.pivot_offset = Vector2(0, size.y / 2)
		4:  # Center
			current_node.pivot_offset = Vector2(size.x / 2, size.y / 2)
		5:  # Center-Right
			current_node.pivot_offset = Vector2(size.x, size.y / 2)
		6:  # Bottom-Left
			current_node.pivot_offset = Vector2(0, size.y)
		7:  # Bottom-Center
			current_node.pivot_offset = Vector2(size.x / 2, size.y)
		8:  # Bottom-Right
			current_node.pivot_offset = Vector2(size.x, size.y)

## Handle control rename with optional script refactoring
func _handle_rename(old_name: String, new_name: String):
	if not current_node or old_name == new_name or new_name.is_empty():
		return
	
	# Validate the new name is not already in use
	var duplicate_node = _find_control_by_name(new_name)
	if duplicate_node and duplicate_node != current_node:
		_show_duplicate_name_error(new_name)
		# Refresh to restore original name in inspector
		update_properties(current_node)
		return
	
	# Validate the name is a valid identifier
	if not _is_valid_control_name(new_name):
		_show_invalid_name_error(new_name)
		update_properties(current_node)
		return
	
	# Store names for potential refactoring
	old_name_for_rename = old_name
	new_name_for_rename = new_name
	
	# Find associated .vg scripts that might reference this control
	var scripts_with_refs = _find_scripts_referencing_control(old_name)
	
	if scripts_with_refs.size() > 0:
		# Show dialog asking if user wants to update scripts
		_show_rename_refactor_dialog(old_name, new_name, scripts_with_refs)
	else:
		# No scripts reference this control, just rename directly
		current_node.name = new_name
		print("VisualGasic: Renamed '", old_name, "' to '", new_name, "'")

## Find a control by name in the current form
func _find_control_by_name(control_name: String) -> Node:
	if not editor_plugin or not is_instance_valid(editor_plugin):
		return null
	
	var edited_scene = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not edited_scene:
		return null
	
	# Check the root itself
	if edited_scene.name == control_name:
		return edited_scene
	
	# Search all descendants (case-insensitive like VB6)
	return _find_node_by_name_recursive(edited_scene, control_name)

func _find_node_by_name_recursive(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		if child.name.nocasecmp_to(target_name) == 0:
			return child
		var found = _find_node_by_name_recursive(child, target_name)
		if found:
			return found
	return null

## Validate that a control name is a valid VB identifier
func _is_valid_control_name(name: String) -> bool:
	if name.is_empty():
		return false
	
	# Must start with a letter
	var first_char = name[0]
	if not (first_char >= 'A' and first_char <= 'Z') and not (first_char >= 'a' and first_char <= 'z'):
		return false
	
	# Rest must be letters, digits, or underscores
	for i in range(1, name.length()):
		var c = name[i]
		var is_letter = (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z')
		var is_digit = c >= '0' and c <= '9'
		var is_underscore = c == '_'
		if not is_letter and not is_digit and not is_underscore:
			return false
	
	# Check for reserved VB keywords
	var reserved = ["Sub", "Function", "Dim", "If", "Then", "Else", "End", "For", "Next", 
		"Do", "Loop", "While", "Wend", "Select", "Case", "Me", "True", "False", "Nothing",
		"And", "Or", "Not", "Mod", "New", "As", "ByRef", "ByVal", "Private", "Public"]
	for keyword in reserved:
		if name.nocasecmp_to(keyword) == 0:
			return false
	
	return true

## Show error dialog for duplicate name
func _show_duplicate_name_error(name: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Duplicate Name"
	dialog.dialog_text = "A control named '" + name + "' already exists on this form.\n\nPlease choose a different name."
	dialog.ok_button_text = "OK"
	
	editor_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2(350, 120))
	
	# Auto cleanup
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

## Show error dialog for invalid name
func _show_invalid_name_error(name: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Invalid Name"
	dialog.dialog_text = "'" + name + "' is not a valid control name.\n\nControl names must:\n• Start with a letter (A-Z)\n• Contain only letters, numbers, and underscores\n• Not be a reserved keyword"
	dialog.ok_button_text = "OK"
	
	editor_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2(380, 160))
	
	# Auto cleanup
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

## Find all .vg scripts that reference a control name
func _find_scripts_referencing_control(control_name: String) -> Array:
	var scripts_found: Array = []
	
	if not editor_plugin or not is_instance_valid(editor_plugin):
		return scripts_found
	
	# Get the root of the current scene
	var edited_scene = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not edited_scene:
		return scripts_found
	
	# Cache of open editor buffers: script_path -> source text
	var open_editor_sources: Dictionary = {}
	
	# FIRST: Check ALL open scripts in the script editor (may have unsaved changes!)
	var script_editor = editor_plugin.get_editor_interface().get_script_editor()
	if script_editor:
		# Get list of open scripts
		var open_scripts = script_editor.get_open_scripts()
		var open_editors = script_editor.get_open_script_editors()
		
		# Match scripts to their editors by index
		for i in range(min(open_scripts.size(), open_editors.size())):
			var script = open_scripts[i]
			var editor_base = open_editors[i]
			
			if script and script.resource_path.ends_with(".vg"):
				var code_edit = _find_code_edit(editor_base)
				if code_edit:
					var source = code_edit.text
					var script_path = script.resource_path
					open_editor_sources[script_path] = source
					if _source_references_control(source, control_name):
						if not script_path in scripts_found:
							scripts_found.append(script_path)
							print("VisualGasic: Found reference in open editor: ", script_path.get_file())
	
	# Search for .vg scripts in the scene's directory
	var scene_path = edited_scene.scene_file_path
	if not scene_path.is_empty():
		var base_dir = scene_path.get_base_dir()
		var dir = DirAccess.open(base_dir)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".vg"):
					var full_path = base_dir.path_join(file_name)
					if not full_path in scripts_found:
						# Check if we already have this in open editors
						if full_path in open_editor_sources:
							# Already checked above
							pass
						else:
							# Read from disk
							var f = FileAccess.open(full_path, FileAccess.READ)
							if f:
								var source = f.get_as_text()
								f.close()
								if _source_references_control(source, control_name):
									scripts_found.append(full_path)
				file_name = dir.get_next()
			dir.list_dir_end()
	
	print("VisualGasic: Total scripts with references: ", scripts_found.size())
	return scripts_found

## Find CodeEdit widget inside a script editor base
func _find_code_edit(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node
	for child in node.get_children():
		var found = _find_code_edit(child)
		if found:
			return found
	return null

## Check if source code references a control name
func _source_references_control(source: String, control_name: String) -> bool:
	if source.is_empty():
		return false
	
	# Check for common VB patterns that reference controls:
	# - ControlName.Property
	# - ControlName_Event()
	# - Me.ControlName
	# - Controls("ControlName")
	
	var patterns = [
		control_name + ".",          # Property access
		control_name + "_",          # Event handler (e.g., Button1_Click)
		"Me." + control_name,        # Me.ControlName
		"\"" + control_name + "\"",  # String literal reference
	]
	
	for pattern in patterns:
		var pos = source.findn(pattern)
		if pos >= 0:  # Case-insensitive search
			return true
	
	return false

## Show confirmation dialog for rename refactoring
func _show_rename_refactor_dialog(old_name: String, new_name: String, scripts: Array):
	if rename_dialog and is_instance_valid(rename_dialog):
		rename_dialog.queue_free()
	
	rename_dialog = ConfirmationDialog.new()
	rename_dialog.title = "Rename Control"
	rename_dialog.dialog_text = "The following scripts reference '" + old_name + "':\n\n"
	
	for script_path in scripts:
		rename_dialog.dialog_text += "  • " + script_path.get_file() + "\n"
	
	rename_dialog.dialog_text += "\nRename '" + old_name + "' to '" + new_name + "'?"
	
	rename_dialog.ok_button_text = "Rename + Update Scripts"
	rename_dialog.cancel_button_text = "Cancel"
	
	# Add a third button for "Rename Only"
	rename_dialog.add_button("Rename Only", true, "rename_only")
	
	rename_dialog.confirmed.connect(_on_refactor_confirmed.bind(scripts))
	rename_dialog.canceled.connect(_on_refactor_cancelled)
	rename_dialog.custom_action.connect(_on_rename_only)
	
	# Add to editor
	editor_plugin.get_editor_interface().get_base_control().add_child(rename_dialog)
	rename_dialog.popup_centered(Vector2(400, 200))

## User confirmed: rename AND update scripts
func _on_refactor_confirmed(scripts: Array):
	if not current_node:
		return
	
	var old_name = old_name_for_rename
	var new_name = new_name_for_rename
	
	# Update all scripts
	var updated_count = 0
	for script_path in scripts:
		if _update_script_references(script_path, old_name, new_name):
			updated_count += 1
	
	# Now rename the control
	current_node.name = new_name
	
	print("VisualGasic: Renamed '", old_name, "' to '", new_name, "' and updated ", updated_count, " script(s)")
	
	# Refresh properties display
	update_properties(current_node)
	
	_cleanup_rename_dialog()

## User chose "Rename Only" - rename without updating scripts
func _on_rename_only(action: String):
	if action == "rename_only" and current_node:
		current_node.name = new_name_for_rename
		print("VisualGasic: Renamed '", old_name_for_rename, "' to '", new_name_for_rename, "' (scripts not updated)")
		update_properties(current_node)
	_cleanup_rename_dialog()

## User cancelled - don't rename at all
func _on_refactor_cancelled():
	print("VisualGasic: Rename cancelled")
	if current_node:
		update_properties(current_node)
	_cleanup_rename_dialog()

func _cleanup_rename_dialog():
	if rename_dialog and is_instance_valid(rename_dialog):
		rename_dialog.queue_free()
		rename_dialog = null
	old_name_for_rename = ""
	new_name_for_rename = ""

## Update references in a script file (or open editor buffer)
func _update_script_references(script_path: String, old_name: String, new_name: String) -> bool:
	# First, check if this script is currently open in the editor
	var script_editor = editor_plugin.get_editor_interface().get_script_editor() if editor_plugin else null
	var code_edit: CodeEdit = null
	var source: String = ""
	var is_open_in_editor := false
	
	if script_editor:
		# Get parallel arrays of scripts and editors
		var open_scripts = script_editor.get_open_scripts()
		var open_editors = script_editor.get_open_script_editors()
		
		for i in range(min(open_scripts.size(), open_editors.size())):
			var script = open_scripts[i]
			var editor_base = open_editors[i]
			if script and script.resource_path == script_path:
				# Found it - get the CodeEdit
				code_edit = _find_code_edit(editor_base)
				if code_edit:
					source = code_edit.text
					is_open_in_editor = true
					break
	
	# If not open in editor, read from disk
	if not is_open_in_editor:
		var f = FileAccess.open(script_path, FileAccess.READ)
		if not f:
			push_error("VisualGasic: Could not open " + script_path + " for reading")
			return false
		source = f.get_as_text()
		f.close()
	
	var original_source = source
	
	# Replace patterns using regex for proper word boundary matching
	var regex = RegEx.new()
	
	# Pattern 1: ControlName. (property access)
	regex.compile("(?i)\\b" + old_name + "\\.")
	source = regex.sub(source, new_name + ".", true)
	
	# Pattern 2: ControlName_ (event handlers like Button1_Click)
	regex.compile("(?i)\\b" + old_name + "_")
	source = regex.sub(source, new_name + "_", true)
	
	# Pattern 3: Me.ControlName (but not Me.ControlNameOther)
	regex.compile("(?i)Me\\." + old_name + "\\b")
	source = regex.sub(source, "Me." + new_name, true)
	
	# Pattern 4: "ControlName" string literals
	regex.compile("(?i)\"" + old_name + "\"")
	source = regex.sub(source, "\"" + new_name + "\"", true)
	
	if source == original_source:
		print("VisualGasic: No changes needed in ", script_path.get_file())
		return false  # No changes made
	
	# Apply the changes
	if is_open_in_editor and code_edit:
		# Update the editor buffer directly
		code_edit.text = source
		print("VisualGasic: Updated editor buffer for ", script_path.get_file())
	else:
		# Write to disk
		var f = FileAccess.open(script_path, FileAccess.WRITE)
		if not f:
			push_error("VisualGasic: Could not open " + script_path + " for writing")
			return false
		f.store_string(source)
		f.close()
		print("VisualGasic: Updated file on disk: ", script_path.get_file())
		
		# Signal editor to reload
		if editor_plugin and is_instance_valid(editor_plugin):
			editor_plugin.get_editor_interface().get_resource_filesystem().scan()
	
	return true
