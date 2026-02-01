@tool
extends AcceptDialog

# Form template types based on VB6 and modern IDEs
enum FormType {
	BLANK,           # Simple blank form
	DIALOG,          # Dialog with OK/Cancel buttons
	ABOUT,           # About box with app info
	SPLASH,          # Splash screen
	LOGIN,           # Login form with username/password
	MAIN_MENU,       # Form with menu bar
	DATA_ENTRY,      # Form with common data entry controls
	MDI_PARENT,      # MDI (Multiple Document Interface) parent
	MDI_CHILD        # MDI child form
}

var selected_type: FormType = FormType.BLANK
var form_templates = {}

func _ready():
	title = "New Form"
	size = Vector2(500, 450)
	ok_button_text = "Create"
	
	_setup_ui()
	_init_templates()

func _setup_ui():
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Title label
	var lbl_title = Label.new()
	lbl_title.text = "Select a form template:"
	lbl_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_title)
	
	# Form type list
	var list = ItemList.new()
	list.name = "FormTypeList"
	list.custom_minimum_size = Vector2(0, 200)
	list.add_item("Blank Form - Empty form ready for controls")
	list.add_item("Dialog Form - Form with OK and Cancel buttons")
	list.add_item("About Box - Standard about dialog")
	list.add_item("Splash Screen - Startup splash screen")
	list.add_item("Login Form - Username and password entry")
	list.add_item("Main Form with Menu - Form with menu bar")
	list.add_item("Data Entry Form - Form with common data controls")
	list.add_item("MDI Parent Form - Multiple Document Interface parent")
	list.add_item("MDI Child Form - MDI child window")
	list.select(0)
	list.item_selected.connect(_on_item_selected)
	vbox.add_child(list)
	
	# Description
	var lbl_desc_title = Label.new()
	lbl_desc_title.text = "Description:"
	lbl_desc_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl_desc_title)
	
	var desc = RichTextLabel.new()
	desc.name = "DescriptionLabel"
	desc.custom_minimum_size = Vector2(0, 100)
	desc.bbcode_enabled = true
	desc.scroll_active = false
	desc.fit_content = true
	vbox.add_child(desc)
	
	_update_description(0)

func _on_item_selected(index: int):
	selected_type = index as FormType
	_update_description(index)

func _update_description(index: int):
	var desc_label = get_node("MarginContainer/VBoxContainer/DescriptionLabel") as RichTextLabel
	if not desc_label:
		return
	
	var descriptions = [
		"[b]Blank Form[/b]\nA simple empty form with no controls. Perfect for creating custom layouts from scratch.",
		
		"[b]Dialog Form[/b]\nA form pre-configured with OK and Cancel buttons at the bottom right. Ideal for simple input dialogs and confirmations.",
		
		"[b]About Box[/b]\nA standard About dialog with placeholders for application name, version, copyright, and description. Includes an OK button.",
		
		"[b]Splash Screen[/b]\nA borderless form designed for application startup screens. Typically shows a logo and loading message.",
		
		"[b]Login Form[/b]\nA form with username and password text boxes, and Login/Cancel buttons. Ready for authentication logic.",
		
		"[b]Main Form with Menu[/b]\nA form with a menu bar pre-configured with File and Help menus, including common menu items (New, Open, Save, Exit, About).",
		
		"[b]Data Entry Form[/b]\nA form with common data entry controls laid out in a grid: labels, text boxes, and navigation buttons (First, Previous, Next, Last, Save).",
		
		"[b]MDI Parent Form[/b]\nA Multiple Document Interface parent form that can contain multiple child forms. Includes Window menu for managing child forms.",
		
		"[b]MDI Child Form[/b]\nA child form designed to be displayed within an MDI parent. Can be tiled, cascaded, or maximized within the parent."
	]
	
	desc_label.text = descriptions[index] if index < descriptions.size() else ""

func _init_templates():
	# Blank form template
	form_templates[FormType.BLANK] = {
		"size": Vector2(400, 300),
		"controls": [],
		"code": """' Form_Load event
Sub Form_Load()
	' Initialize form
End Sub
"""
	}
	
	# Dialog form template
	form_templates[FormType.DIALOG] = {
		"size": Vector2(400, 200),
		"controls": [
			{"type": "Button", "name": "btnOK", "text": "OK", "position": Vector2(220, 150), "size": Vector2(80, 30)},
			{"type": "Button", "name": "btnCancel", "text": "Cancel", "position": Vector2(310, 150), "size": Vector2(80, 30)}
		],
		"code": """' Form_Load event
Sub Form_Load()
	' Initialize dialog
End Sub

Sub btnOK_Click()
	' Handle OK button
	Me.Hide()
End Sub

Sub btnCancel_Click()
	' Handle Cancel button
	Me.Hide()
End Sub
"""
	}
	
	# About box template
	form_templates[FormType.ABOUT] = {
		"size": Vector2(400, 250),
		"controls": [
			{"type": "Label", "name": "lblAppName", "text": "Application Name", "position": Vector2(20, 20), "size": Vector2(360, 30)},
			{"type": "Label", "name": "lblVersion", "text": "Version 1.0", "position": Vector2(20, 55), "size": Vector2(360, 20)},
			{"type": "Label", "name": "lblCopyright", "text": "Copyright © 2026", "position": Vector2(20, 80), "size": Vector2(360, 20)},
			{"type": "Label", "name": "lblDescription", "text": "Description of your application", "position": Vector2(20, 110), "size": Vector2(360, 80)},
			{"type": "Button", "name": "btnOK", "text": "OK", "position": Vector2(160, 200), "size": Vector2(80, 30)}
		],
		"code": """' Form_Load event
Sub Form_Load()
	lblAppName.Text = "My Application"
	lblVersion.Text = "Version 1.0.0"
	lblCopyright.Text = "Copyright © 2026 Your Company"
	lblDescription.Text = "This is a sample application."
End Sub

Sub btnOK_Click()
	Me.Hide()
End Sub
"""
	}
	
	# Splash screen template
	form_templates[FormType.SPLASH] = {
		"size": Vector2(500, 300),
		"borderless": true,
		"controls": [
			{"type": "Label", "name": "lblTitle", "text": "Application Title", "position": Vector2(150, 100), "size": Vector2(200, 40)},
			{"type": "Label", "name": "lblLoading", "text": "Loading...", "position": Vector2(200, 250), "size": Vector2(100, 20)}
		],
		"code": """' Form_Load event
Sub Form_Load()
	' Center the form
	' Show for 3 seconds then close
	' You can add a Timer here
End Sub
"""
	}
	
	# Login form template
	form_templates[FormType.LOGIN] = {
		"size": Vector2(350, 200),
		"controls": [
			{"type": "Label", "name": "lblUsername", "text": "Username:", "position": Vector2(20, 30), "size": Vector2(80, 20)},
			{"type": "TextEdit", "name": "txtUsername", "text": "", "position": Vector2(110, 28), "size": Vector2(200, 25)},
			{"type": "Label", "name": "lblPassword", "text": "Password:", "position": Vector2(20, 70), "size": Vector2(80, 20)},
			{"type": "TextEdit", "name": "txtPassword", "text": "", "position": Vector2(110, 68), "size": Vector2(200, 25)},
			{"type": "Button", "name": "btnLogin", "text": "Login", "position": Vector2(140, 140), "size": Vector2(90, 30)},
			{"type": "Button", "name": "btnCancel", "text": "Cancel", "position": Vector2(240, 140), "size": Vector2(90, 30)}
		],
		"code": """' Form_Load event
Sub Form_Load()
	txtPassword.PasswordMode = True
End Sub

Sub btnLogin_Click()
	Dim username As String
	Dim password As String
	
	username = txtUsername.Text
	password = txtPassword.Text
	
	If username = "admin" And password = "password" Then
		Print "Login successful!"
		Me.Hide()
	Else
		MsgBox "Invalid username or password", vbExclamation, "Login Failed"
	End If
End Sub

Sub btnCancel_Click()
	Me.Hide()
End Sub
"""
	}
	
	# Main form with menu template
	form_templates[FormType.MAIN_MENU] = {
		"size": Vector2(600, 400),
		"has_menu": true,
		"controls": [],
		"code": """' Form_Load event
Sub Form_Load()
	' Initialize main form
	' Menu items will be auto-wired
End Sub

' File menu handlers
Sub mnuFileNew_Click()
	Print "New file"
End Sub

Sub mnuFileOpen_Click()
	Print "Open file"
End Sub

Sub mnuFileSave_Click()
	Print "Save file"
End Sub

Sub mnuFileExit_Click()
	' Exit application
	GetTree().Quit()
End Sub

' Help menu handlers
Sub mnuHelpAbout_Click()
	MsgBox "My Application v1.0", vbInformation, "About"
End Sub
"""
	}
	
	# Data entry form template
	form_templates[FormType.DATA_ENTRY] = {
		"size": Vector2(500, 400),
		"controls": [
			{"type": "Label", "name": "lblName", "text": "Name:", "position": Vector2(20, 30), "size": Vector2(100, 20)},
			{"type": "TextEdit", "name": "txtName", "text": "", "position": Vector2(130, 28), "size": Vector2(300, 25)},
			{"type": "Label", "name": "lblAddress", "text": "Address:", "position": Vector2(20, 70), "size": Vector2(100, 20)},
			{"type": "TextEdit", "name": "txtAddress", "text": "", "position": Vector2(130, 68), "size": Vector2(300, 25)},
			{"type": "Label", "name": "lblCity", "text": "City:", "position": Vector2(20, 110), "size": Vector2(100, 20)},
			{"type": "TextEdit", "name": "txtCity", "text": "", "position": Vector2(130, 108), "size": Vector2(200, 25)},
			{"type": "Label", "name": "lblState", "text": "State:", "position": Vector2(20, 150), "size": Vector2(100, 20)},
			{"type": "TextEdit", "name": "txtState", "text": "", "position": Vector2(130, 148), "size": Vector2(100, 25)},
			{"type": "Button", "name": "btnFirst", "text": "|<", "position": Vector2(20, 330), "size": Vector2(60, 30)},
			{"type": "Button", "name": "btnPrevious", "text": "<", "position": Vector2(90, 330), "size": Vector2(60, 30)},
			{"type": "Button", "name": "btnNext", "text": ">", "position": Vector2(160, 330), "size": Vector2(60, 30)},
			{"type": "Button", "name": "btnLast", "text": ">|", "position": Vector2(230, 330), "size": Vector2(60, 30)},
			{"type": "Button", "name": "btnSave", "text": "Save", "position": Vector2(350, 330), "size": Vector2(80, 30)}
		],
		"code": """' Form_Load event
Sub Form_Load()
	' Load first record
	LoadRecord(0)
End Sub

Sub LoadRecord(index As Integer)
	' Load data from your data source
	' Update the text boxes
End Sub

Sub btnFirst_Click()
	LoadRecord(0)
End Sub

Sub btnPrevious_Click()
	' Navigate to previous record
End Sub

Sub btnNext_Click()
	' Navigate to next record
End Sub

Sub btnLast_Click()
	' Navigate to last record
End Sub

Sub btnSave_Click()
	' Save current record
	Print "Saving record..."
End Sub
"""
	}
	
	# MDI Parent template
	form_templates[FormType.MDI_PARENT] = {
		"size": Vector2(800, 600),
		"is_mdi_parent": true,
		"has_menu": true,
		"controls": [],
		"code": """' Form_Load event
Sub Form_Load()
	' Initialize MDI parent
End Sub

' Window menu handlers
Sub mnuWindowCascade_Click()
	' Cascade child windows
End Sub

Sub mnuWindowTileHorizontal_Click()
	' Tile windows horizontally
End Sub

Sub mnuWindowTileVertical_Click()
	' Tile windows vertically
End Sub

Sub mnuWindowCloseAll_Click()
	' Close all child windows
End Sub
"""
	}
	
	# MDI Child template
	form_templates[FormType.MDI_CHILD] = {
		"size": Vector2(400, 300),
		"is_mdi_child": true,
		"controls": [],
		"code": """' Form_Load event
Sub Form_Load()
	' Initialize MDI child
End Sub

Sub Form_Resize()
	' Handle resize within MDI parent
End Sub
"""
	}

func get_selected_template():
	return form_templates.get(selected_type, form_templates[FormType.BLANK])
