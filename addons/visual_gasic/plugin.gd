@tool
extends EditorPlugin

var export_plugin
var import_plugin

func _enter_tree():
    # We might need an EditorImportPlugin for .bas files to ensure they are imported as Resources
    # But currently they adhere to ScriptExtension, so ResourceLoader should handle them if registered.
    print("VisualGasic Editor Plugin Activated")

func _exit_tree():
    pass
