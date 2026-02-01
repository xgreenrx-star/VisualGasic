@tool
extends EditorImportPlugin

func _get_importer_name():
	return "visual_gasic.vb6.form"

func _get_visible_name():
	return "VB6 Form"

func _get_recognized_extensions():
	return ["frm"]

func _get_save_extension():
	return "tscn" # We import as a PackedScene

func _get_resource_type():
	return "PackedScene"
    
func _get_preset_count():
	return 1
    
func _get_preset_name(preset_index):
	return "Default"

func _get_import_options(path, preset_index):
	return []
    
func _get_priority():
	return 1.0
    
func _get_import_order():
	return 0

func _import(source_file, save_path, options, r_platform_variants, r_gen_files):
	# Load the Helper
	var importer = load("res://addons/visual_gasic/vb6_importer.gd")
	if !importer:
		return ERR_CANT_CREATE
		
	var root = Control.new()
	root.name = source_file.get_file().get_basename()
	
	# Import Logic
	var code = importer.import_form(source_file, root, root)
	
	# Pack
	var packed = PackedScene.new()
	var err = packed.pack(root)
	if err != OK:
		return err
		
	# Save the Scene file to the .godot/imported location (Godot handles this via return)
	var filename = save_path + "." + _get_save_extension()
	err = ResourceSaver.save(packed, filename)
	if err != OK:
		return err
		
	# Handle the CODE sidecar
	# Importers shouldn't write to source folder, but for legacy migration usage it's often desired.
	# However, strictly, we should probably embed the code as metadata OR write a generated script.
	# Let's write the .vg file to the source directory IF it doesn't exist?
	# Or better: Save it as a string in the scene metadata 'vb_code'
	
	# To be safe and compliant with Godot Import system, we just map the Visuals.
	# The user can use the Tool Menu for the "Project conversion" which handles Code.
	# But let's try to save the .vg file next to the source if possible.
	
    # NOTE: Writing to source_file directory during import can cause import loops if not careful.
	# We will skip writing the .vg file in the automatic importer to avoid loops.
    # The automatic importer is just for viewing/using the Form Layout.
	
	root.queue_free()
	return OK
