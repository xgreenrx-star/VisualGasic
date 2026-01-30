#include "visual_gasic_loader.h"
#include "visual_gasic_script.h"
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

// LOADER

PackedStringArray VisualGasicFormatLoader::_get_recognized_extensions() const  {
	PackedStringArray exts;
	exts.push_back("vg");
	return exts;
}

bool VisualGasicFormatLoader::_handles_type(const StringName &p_type) const {
	return (p_type == StringName("Script") || p_type == StringName("VisualGasicScript"));
}

String VisualGasicFormatLoader::_get_resource_type(const String &p_path) const {
	if (p_path.get_extension().to_lower() == "vg") {
		return "VisualGasicScript";
	}
	return "";
}

Variant VisualGasicFormatLoader::_load(const String &p_path, const String &p_original_path, bool p_use_sub_threads, int32_t p_cache_mode) const {
	Ref<VisualGasicScript> script;
	script.instantiate();

	Ref<FileAccess> f = FileAccess::open(p_path, FileAccess::READ);
	if (f.is_null()) {
		return Variant(); // Error
	}

	String source = f->get_as_text();
	script->set_source_code(source);
	f->close();

	// Reload with error handling to prevent crashes from malformed code
	Error err = script->reload(false);
	if (err != OK) {
		UtilityFunctions::print_rich("[color=red]Warning: Failed to load VisualGasic script: " + p_path + "[/color]");
		// Return the script anyway so it can be edited, but mark it as having errors
	}

	return script;
}

// SAVER

PackedStringArray VisualGasicFormatSaver::_get_recognized_extensions(const Ref<Resource> &p_resource) const {
	PackedStringArray exts;
	if (Object::cast_to<VisualGasicScript>(p_resource.ptr())) {
		exts.push_back("vg");
	}
	return exts;
}

bool VisualGasicFormatSaver::_recognize(const Ref<Resource> &p_resource) const {
	return Object::cast_to<VisualGasicScript>(p_resource.ptr()) != nullptr;
}

Error VisualGasicFormatSaver::_save(const Ref<Resource> &p_resource, const String &p_path, uint32_t p_flags) {
	Ref<VisualGasicScript> script = p_resource;
	if (script.is_null()) {
		return ERR_INVALID_PARAMETER;
	}

	Ref<FileAccess> f = FileAccess::open(p_path, FileAccess::WRITE);
	if (f.is_null()) {
		return ERR_FILE_CANT_OPEN;
	}

	f->store_string(script->get_source_code());
	f->close();

	return OK;
}
