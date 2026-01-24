@tool
extends EditorPlugin

var export_plugin
var import_plugin
var form_designer
var project_wizard

func _enter_tree():
    # We might need an EditorImportPlugin for .bas files to ensure they are imported as Resources
    # But currently they adhere to ScriptExtension, so ResourceLoader should handle them if registered.
    print("VisualGasic Editor Plugin Activated")
    
    # Load Form Designer plugin
    var FormDesignerScript = load("res://addons/visual_gasic/form_designer.gd")
    if FormDesignerScript:
        form_designer = FormDesignerScript.new()
        add_child(form_designer)
        print("Form Designer activated")
    
    # Create Project Wizard (but don't show it yet)
    var ProjectWizardScript = load("res://addons/visual_gasic/project_wizard.gd")
    if ProjectWizardScript:
        project_wizard = ProjectWizardScript.new()
        add_child(project_wizard)
        print("Project Wizard loaded")
        
        # Add menu item to show the wizard
        add_tool_menu_item("New VisualGasic Project...", _show_project_wizard)

func _exit_tree():
    if form_designer:
        remove_child(form_designer)
        form_designer.queue_free()
    
    if project_wizard:
        remove_tool_menu_item("New VisualGasic Project...")
        remove_child(project_wizard)
        project_wizard.queue_free()

func _show_project_wizard():
    if project_wizard:
        project_wizard.popup_centered()
