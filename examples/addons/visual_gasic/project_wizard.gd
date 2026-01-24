@tool
extends ConfirmationDialog
## Project Wizard for VisualGasic
## Creates new VB6-style projects from templates

signal project_created(project_path: String)

enum WizardType {
	STANDARD_EXE,
	DATABASE_APP,
	GAME_PROJECT,
	ACTIVEX_DLL,
	CUSTOM_CONTROL
}

var wizard_pages: Array[Control] = []
var current_page: int = 0

# UI elements
var page_container: VBoxContainer
var nav_buttons: HBoxContainer
var prev_btn: Button
var next_btn: Button
var finish_btn: Button
var page_label: Label

# Page 1: Choose wizard type
var wizard_type_list: ItemList
var wizard_description: RichTextLabel

# Page 2: Project settings
var project_name_edit: LineEdit
var project_location_edit: LineEdit
var browse_btn: Button

# Page 3: Options (varies by type)
var options_container: VBoxContainer

# Selected options
var selected_wizard_type: WizardType = WizardType.STANDARD_EXE
var project_name: String = "MyProject"
var project_location: String = ""
var create_forms: bool = true
var create_module: bool = true

func _ready() -> void:
	title = "VisualGasic Project Wizard"
	min_size = Vector2i(700, 550)
	size = Vector2i(700, 550)
	
	_setup_ui()
	_create_page_1_wizard_type()
	_create_page_2_project_settings()
	_create_page_3_options()
	_load_page(0)

func _setup_ui() -> void:
	# Main container - use get_vbox() for ConfirmationDialog
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)
	
	# Page label
	page_label = Label.new()
	page_label.add_theme_font_size_override("font_size", 16)
	page_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	main_vbox.add_child(page_label)
	
	var sep1 = HSeparator.new()
	sep1.custom_minimum_size.y = 4
	main_vbox.add_child(sep1)
	
	# Page container
	page_container = VBoxContainer.new()
	page_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_container.custom_minimum_size = Vector2(0, 350)
	main_vbox.add_child(page_container)
	
	var sep2 = HSeparator.new()
	sep2.custom_minimum_size.y = 4
	main_vbox.add_child(sep2)
	
	# Navigation buttons
	nav_buttons = HBoxContainer.new()
	nav_buttons.custom_minimum_size.y = 40
	
	main_vbox.add_child(HSeparator.new())
	
	# Navigation buttons
	nav_buttons = HBoxContainer.new()
	main_vbox.add_child(nav_buttons)
	
	prev_btn = Button.new()
	prev_btn.text = "< Previous"
	prev_btn.pressed.connect(_on_prev_pressed)
	nav_buttons.add_child(prev_btn)
	
	nav_buttons.add_child(Control.new()) # Spacer
	nav_buttons.get_child(-1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	next_btn = Button.new()
	next_btn.text = "Next >"
	next_btn.pressed.connect(_on_next_pressed)
	nav_buttons.add_child(next_btn)
	
	finish_btn = Button.new()
	finish_btn.text = "Finish"
	finish_btn.pressed.connect(_on_finish_pressed)
	finish_btn.visible = false
	nav_buttons.add_child(finish_btn)

func _create_page_1_wizard_type() -> void:
	var page = VBoxContainer.new()
	page.name = "WizardTypePage"
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var label = Label.new()
	label.text = "Select the type of project to create:"
	label.add_theme_font_size_override("font_size", 14)
	page.add_child(label)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = 10
	page.add_child(spacer1)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(hbox)
	
	# Wizard type list
	wizard_type_list = ItemList.new()
	wizard_type_list.custom_minimum_size = Vector2(250, 0)
	wizard_type_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wizard_type_list.add_item("Standard EXE", null, true)
	wizard_type_list.add_item("Database Application", null, true)
	wizard_type_list.add_item("Game Project", null, true)
	wizard_type_list.add_item("ActiveX DLL", null, true)
	wizard_type_list.add_item("Custom Control", null, true)
	wizard_type_list.select(0)
	wizard_type_list.item_selected.connect(_on_wizard_type_selected)
	hbox.add_child(wizard_type_list)
	
	# Description
	wizard_description = RichTextLabel.new()
	wizard_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wizard_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wizard_description.bbcode_enabled = true
	wizard_description.fit_content = true
	wizard_description.custom_minimum_size = Vector2(350, 0)
	_update_wizard_description(0)
	hbox.add_child(wizard_description)
	
	wizard_pages.append(page)

func _create_page_2_project_settings() -> void:
	var page = VBoxContainer.new()
	page.name = "ProjectSettingsPage"
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var label = Label.new()
	label.text = "Enter project details:"
	label.add_theme_font_size_override("font_size", 14)
	page.add_child(label)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = 20
	page.add_child(spacer1)
	
	# Project name
	var name_label = Label.new()
	name_label.text = "Project Name:"
	page.add_child(name_label)
	
	project_name_edit = LineEdit.new()
	project_name_edit.text = "MyProject"
	project_name_edit.placeholder_text = "Enter project name"
	project_name_edit.custom_minimum_size.y = 32
	page.add_child(project_name_edit)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 20
	page.add_child(spacer2)
	
	# Project location
	var location_label = Label.new()
	location_label.text = "Location:"
	page.add_child(location_label)
	
	var location_hbox = HBoxContainer.new()
	location_hbox.custom_minimum_size.y = 32
	page.add_child(location_hbox)
	
	project_location_edit = LineEdit.new()
	project_location_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	project_location_edit.text = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/VisualGasicProjects"
	location_hbox.add_child(project_location_edit)
	
	browse_btn = Button.new()
	browse_btn.text = "Browse..."
	browse_btn.custom_minimum_size = Vector2(100, 0)
	browse_btn.pressed.connect(_on_browse_pressed)
	location_hbox.add_child(browse_btn)
	
	wizard_pages.append(page)

func _create_page_3_options() -> void:
	var page = VBoxContainer.new()
	page.name = "OptionsPage"
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var label = Label.new()
	label.text = "Project options:"
	label.add_theme_font_size_override("font_size", 14)
	page.add_child(label)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = 20
	page.add_child(spacer1)
	
	options_container = VBoxContainer.new()
	options_container.add_theme_constant_override("separation", 10)
	page.add_child(options_container)
	
	# Common options
	var create_form_check = CheckBox.new()
	create_form_check.text = "Create default form (Form1.bas)"
	create_form_check.button_pressed = true
	create_form_check.toggled.connect(func(pressed): create_forms = pressed)
	options_container.add_child(create_form_check)
	
	var create_module_check = CheckBox.new()
	create_module_check.text = "Create code module (Module1.bas)"
	create_module_check.button_pressed = true
	create_module_check.toggled.connect(func(pressed): create_module = pressed)
	options_container.add_child(create_module_check)
	
	wizard_pages.append(page)

func _load_page(page_idx: int) -> void:
	current_page = page_idx
	
	# Hide all pages
	for child in page_container.get_children():
		child.visible = false
	
	# Show current page
	if page_idx >= 0 and page_idx < wizard_pages.size():
		if wizard_pages[page_idx].get_parent() != page_container:
			page_container.add_child(wizard_pages[page_idx])
		wizard_pages[page_idx].visible = true
	
	# Update navigation
	prev_btn.disabled = (page_idx == 0)
	next_btn.visible = (page_idx < wizard_pages.size() - 1)
	finish_btn.visible = (page_idx == wizard_pages.size() - 1)
	
	# Update page label
	page_label.text = "Step %d of %d" % [page_idx + 1, wizard_pages.size()]

func _on_wizard_type_selected(idx: int) -> void:
	selected_wizard_type = idx as WizardType
	_update_wizard_description(idx)

func _update_wizard_description(idx: int) -> void:
	var descriptions = [
		"[b]Standard EXE[/b]\n\nCreates a standard Windows executable application with a main form and basic event handling. Perfect for simple utilities and tools.",
		"[b]Database Application[/b]\n\nCreates a data-driven application with database connection setup, data grid, and CRUD operation templates. Includes boilerplate for ADO connections.",
		"[b]Game Project[/b]\n\nCreates a game project with game loop, input handling, and sprite management. Includes basic game state machine and collision detection helpers.",
		"[b]ActiveX DLL[/b]\n\nCreates a reusable component library (DLL) that can be used by other VB6 applications. Includes class module templates.",
		"[b]Custom Control[/b]\n\nCreates a custom user control with property pages and design-time support. Perfect for building reusable UI components."
	]
	
	if idx >= 0 and idx < descriptions.size():
		wizard_description.text = descriptions[idx]

func _on_prev_pressed() -> void:
	if current_page > 0:
		_load_page(current_page - 1)

func _on_next_pressed() -> void:
	if current_page < wizard_pages.size() - 1:
		# Validate current page
		if _validate_current_page():
			_load_page(current_page + 1)

func _on_browse_pressed() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.current_dir = project_location_edit.text
	file_dialog.dir_selected.connect(func(dir): project_location_edit.text = dir)
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(700, 500))

func _validate_current_page() -> bool:
	match current_page:
		1: # Project settings
			if project_name_edit.text.strip_edges().is_empty():
				_show_error("Please enter a project name")
				return false
			if project_location_edit.text.strip_edges().is_empty():
				_show_error("Please select a project location")
				return false
	return true

func _show_error(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Error"
	add_child(dialog)
	dialog.popup_centered()

func _on_finish_pressed() -> void:
	if not _validate_current_page():
		return
	
	project_name = project_name_edit.text.strip_edges()
	project_location = project_location_edit.text.strip_edges()
	
	_create_project()
	hide()

func _create_project() -> void:
	var full_path = project_location + "/" + project_name
	
	# Create directory
	DirAccess.make_dir_recursive_absolute(full_path)
	
	# Create project files based on wizard type
	match selected_wizard_type:
		WizardType.STANDARD_EXE:
			_create_standard_exe_project(full_path)
		WizardType.DATABASE_APP:
			_create_database_app_project(full_path)
		WizardType.GAME_PROJECT:
			_create_game_project(full_path)
		WizardType.ACTIVEX_DLL:
			_create_activex_dll_project(full_path)
		WizardType.CUSTOM_CONTROL:
			_create_custom_control_project(full_path)
	
	project_created.emit(full_path)
	print("Project created at: ", full_path)

func _create_standard_exe_project(path: String) -> void:
	if create_forms:
		var form_code = """' Form1.bas
Option Explicit

Private Sub Form_Load()
    Me.Caption = "%s"
    MsgBox "Welcome to %s!", vbInformation
End Sub
""" % [project_name, project_name]
		
		_save_file(path + "/Form1.bas", form_code)
	
	if create_module:
		var module_code = """' Module1.bas
Option Explicit

Public Sub Main()
    ' Application entry point
    Form1.Show
End Sub
"""
		_save_file(path + "/Module1.bas", module_code)
	
	# Create project file
	var project_code = """[Project]
Name=%s
Type=Exe32
Startup=Form1
""" % [project_name]
	
	_save_file(path + "/project.godot", project_code)

func _create_database_app_project(path: String) -> void:
	# TODO: Implement database template
	_create_standard_exe_project(path)

func _create_game_project(path: String) -> void:
	# TODO: Implement game template
	_create_standard_exe_project(path)

func _create_activex_dll_project(path: String) -> void:
	# TODO: Implement ActiveX DLL template
	_create_standard_exe_project(path)

func _create_custom_control_project(path: String) -> void:
	# TODO: Implement custom control template
	_create_standard_exe_project(path)

func _save_file(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
