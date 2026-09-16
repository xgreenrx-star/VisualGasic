@tool
extends EditorImportPlugin
## FRM Import Plugin
##
## Handles importing VB6 .frm form files into Godot scenes.
## This integrates with Godot's import system to automatically
## convert .frm files when they are added to the project.

# =============================================================================
# IMPORT PLUGIN INTERFACE
# =============================================================================

func _get_importer_name() -> String:
	return "visual_gasic.frm_importer"

func _get_visible_name() -> String:
	return "VB6 Form"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["frm"])

func _get_save_extension() -> String:
	return "tscn"

func _get_resource_type() -> String:
	return "PackedScene"

func _get_preset_count() -> int:
	return 1

func _get_preset_name(preset_index: int) -> String:
	return "Default"

func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "convert_code",
			"default_value": true,
			"hint_string": "Also generate .vg script from form code"
		},
		{
			"name": "preserve_layout",
			"default_value": true,
			"hint_string": "Preserve VB6 control positions (scaled from twips)"
		},
		{
			"name": "import_images",
			"default_value": true,
			"hint_string": "Import embedded images as textures"
		}
	]

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _get_priority() -> float:
	return 1.0

func _get_import_order() -> int:
	return 0

# =============================================================================
# IMPORT IMPLEMENTATION
# =============================================================================

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	# Load the VB6 importer
	var vb6_importer_script = load("res://addons/visual_gasic/vb6_importer.gd")
	if not vb6_importer_script:
		push_error("Could not load VB6 importer script")
		return ERR_FILE_NOT_FOUND
	
	# Use the full import_form_file() API which handles:
	#   - parsing controls, properties, fonts, menus
	#   - control array detection and renaming
	#   - multiline TextBox post-processing
	#   - radio button grouping
	#   - .frx image extraction
	#   - signal auto-wiring into .tscn
	#   - VB6→VG code transformation
	var result: Dictionary = vb6_importer_script.import_form_file(source_file)
	
	if not result.get("success", false):
		var errors = result.get("errors", [])
		for e in errors:
			push_error("FRM Import: " + e)
		return ERR_PARSE_ERROR
	
	# import_form_file() saves the scene to res://start_forms/ and code to
	# res://mixed/.  Load the packed scene it created and re-save to the
	# Godot import system's expected save_path.
	var scene_path: String = result.get("scene_path", "")
	if scene_path == "":
		push_error("FRM Import: no scene path returned")
		return ERR_CANT_CREATE
	
	var packed_scene = load(scene_path) as PackedScene
	if not packed_scene:
		push_error("FRM Import: could not load generated scene: " + scene_path)
		return ERR_FILE_CANT_READ
	
	var save_result = ResourceSaver.save(packed_scene, save_path + "." + _get_save_extension())
	
	# Register the generated .vg file so Godot knows about it
	var code_path: String = result.get("code_path", "")
	if code_path != "":
		gen_files.append(code_path)
	
	return save_result
