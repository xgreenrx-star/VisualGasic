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
	
	var importer = vb6_importer_script.new()
	
	# Read the .frm file
	var file = FileAccess.open(source_file, FileAccess.READ)
	if not file:
		push_error("Could not open FRM file: " + source_file)
		return ERR_FILE_CANT_OPEN
	
	var content = file.get_as_text()
	file.close()
	
	# Parse the form
	var form_data = importer.parse_frm_file(source_file)
	if form_data.is_empty():
		push_error("Failed to parse FRM file: " + source_file)
		return ERR_PARSE_ERROR
	
	# Create the scene
	var root_node = importer.create_godot_scene(form_data, options.get("preserve_layout", true))
	if not root_node:
		push_error("Failed to create scene from FRM: " + source_file)
		return ERR_CANT_CREATE
	
	# Generate .vg script if requested
	if options.get("convert_code", true):
		var vg_path = source_file.get_basename() + ".vg"
		var code_result = importer.convert_vb6_code(form_data.get("code", ""), form_data.get("name", "Form1"))
		if code_result and not code_result.is_empty():
			var vg_file = FileAccess.open(vg_path, FileAccess.WRITE)
			if vg_file:
				vg_file.store_string(code_result)
				vg_file.close()
				gen_files.append(vg_path)
	
	# Pack and save the scene
	var packed_scene = PackedScene.new()
	var pack_result = packed_scene.pack(root_node)
	root_node.queue_free()
	
	if pack_result != OK:
		push_error("Failed to pack scene: " + str(pack_result))
		return pack_result
	
	var save_result = ResourceSaver.save(packed_scene, save_path + "." + _get_save_extension())
	return save_result
