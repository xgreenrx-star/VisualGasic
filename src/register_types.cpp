#include "register_types.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/resource_saver.hpp>
#include <godot_cpp/classes/editor_plugin_registration.hpp>

#include "visual_gasic_language.h"
#include "visual_gasic_script.h"
#include "visual_gasic_loader.h"
#include "visual_gasic_editor_plugin.h"
#include "visual_gasic_toolbox.h"
#include "gasic_ai_controller.h"
#include "gasic_form.h"
#include "visual_gasic_comm.h"
#include "visual_gasic_benchmark.h"

using namespace godot;

static VisualGasicLanguage *visual_gasic_language = nullptr;
static Ref<VisualGasicFormatLoader> visual_gasic_loader;
static Ref<VisualGasicFormatSaver> visual_gasic_saver;

#include <godot_cpp/classes/project_settings.hpp>

void initialize_visual_gasic_module(ModuleInitializationLevel p_level) {
    if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        // Register Settings
        if (!ProjectSettings::get_singleton()->has_setting("visual_gasic/auto_format_iif")) {
            ProjectSettings::get_singleton()->set_setting("visual_gasic/auto_format_iif", false);
            ProjectSettings::get_singleton()->set_initial_value("visual_gasic/auto_format_iif", false);
        }

        ClassDB::register_class<VisualGasicLanguage>();
        ClassDB::register_class<VisualGasicScript>();
        ClassDB::register_class<VisualGasicFormatLoader>();
        ClassDB::register_class<VisualGasicFormatSaver>();
        ClassDB::register_class<GasicAIController>();
        ClassDB::register_class<GasicForm>();
        ClassDB::register_class<MSComm>();
        ClassDB::register_class<VisualGasicBenchmark>();
    
        visual_gasic_language = memnew(VisualGasicLanguage);
        Engine::get_singleton()->register_script_language(visual_gasic_language);
    
        visual_gasic_loader.instantiate();
        ResourceLoader::get_singleton()->add_resource_format_loader(visual_gasic_loader);
    
        visual_gasic_saver.instantiate();
        ResourceSaver::get_singleton()->add_resource_format_saver(visual_gasic_saver);
    }
    
    if (p_level == MODULE_INITIALIZATION_LEVEL_EDITOR) {
        ClassDB::register_class<VisualGasicToolbox>();
        ClassDB::register_class<VisualGasicToolButton>();
        // ClassDB::register_class<VisualGasicEditorPlugin>(); // Using GDScript plugin instead
        ClassDB::register_class<VisualGasicSyntaxHighlighter>();
        
        // EditorPlugins::add_by_type<VisualGasicEditorPlugin>();
    }
}

void uninitialize_visual_gasic_module(ModuleInitializationLevel p_level) {
    if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        if (visual_gasic_language) {
            Engine::get_singleton()->unregister_script_language(visual_gasic_language);
            memdelete(visual_gasic_language);
            visual_gasic_language = nullptr;
        }
        
        ResourceLoader::get_singleton()->remove_resource_format_loader(visual_gasic_loader);
        visual_gasic_loader.unref();

        ResourceSaver::get_singleton()->remove_resource_format_saver(visual_gasic_saver);
        visual_gasic_saver.unref();
    }
}

extern "C" {
// Initialization.
GDExtensionBool GDE_EXPORT visual_gasic_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_visual_gasic_module);
	init_obj.register_terminator(uninitialize_visual_gasic_module);
	// init_obj.set_min_api_level(4, 2);

	return init_obj.init();
}
}
