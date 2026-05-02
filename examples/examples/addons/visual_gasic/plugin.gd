@tool
extends EditorPlugin

var export_plugin
var import_plugin

func _enter_tree():
    # We might need an EditorImportPlugin for .bas files to ensure they are imported as Resources
    # But currently they adhere to ScriptExtension, so ResourceLoader should handle them if registered.
    print("VisualGasic Editor Plugin Activated")
    # Defer one frame so the editor finishes loading project settings
    # before we try to mutate + save them; saving from inside _enter_tree
    # races with Godot's own load and the write gets dropped.
    call_deferred("_bootstrap_project_settings")

# Pre-enable settings VG needs so the user doesn't have to hunt through
# Project Settings menus.  Audio capture in particular cannot be turned
# on mid-session, so we flip the flag at first activation and the user
# only needs to restart Godot once to start using voice mode.
func _bootstrap_project_settings():
    var changed := false
    if not ProjectSettings.get_setting("audio/driver/enable_input", false):
        ProjectSettings.set_setting("audio/driver/enable_input", true)
        ProjectSettings.set_initial_value("audio/driver/enable_input", false)
        changed = true
        print("VisualGasic: enabled audio/driver/enable_input — restart Godot once to activate voice-mode microphone.")
    if changed:
        var err := ProjectSettings.save()
        if err != OK:
            push_warning("VisualGasic: ProjectSettings.save() failed (err=%d); voice mode may need manual setup." % err)

func _exit_tree():
    pass
