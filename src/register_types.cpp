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
#include "visual_gasic_draw_benchmark.h"
#include "visual_gasic_vector_draw_benchmark.h"
#include "visual_gasic_test_runner.h"
#include "visual_gasic_immediate.h"
#include "visual_gasic_debugger.h"
#include "visual_gasic_form_designer.h"
#include "visual_gasic_process.h"
#include "visual_gasic_database.h"
#include "visual_gasic_fswatcher.h"
#include "visual_gasic_common_dialog.h"
#include "visual_gasic_socket.h"
#include "visual_gasic_systray.h"
#include "visual_gasic_settings.h"
#include "visual_gasic_vector_canvas.h"
#include "visual_gasic_com_interop.h"
#include "visual_gasic_http.h"
#include "visual_gasic_collection.h"
#include "visual_gasic_regex.h"
#include "visual_gasic_timer.h"

// v3.0 – system-integration features
#include "visual_gasic_ffi.h"
#include "visual_gasic_odbc.h"
#include "visual_gasic_crypto.h"
#include "visual_gasic_xml.h"
#include "visual_gasic_zip.h"
#include "visual_gasic_task.h"
#include "visual_gasic_package.h"

// v4.3 – database controls
#include "visual_gasic_recordset.h"

// v3.1 – system-level programming
#include "visual_gasic_system.h"
#include "visual_gasic_signal_handler.h"
#include "visual_gasic_file_permissions.h"
#include "visual_gasic_memory_buffer.h"
#include "visual_gasic_ipc.h"
#include "visual_gasic_android_bridge.h"

// v3.2 – GPU computing & ECS
#include "visual_gasic_gpu.h"
#include "visual_gasic_ecs.h"

// v6.0 – Python integration bridge (PyImport / PyCallAsync)
#include "python_bridge/visual_gasic_py_facade.h"

// v6.1 – native emulator CPU cores (VGCpuCore family)
#include "cpu_cores/visual_gasic_cpu_6502.h"
#include "cpu_cores/visual_gasic_c64_machine.h"

// v3.2 – LSP integration (binding rework complete)
#include "visual_gasic_lsp.h"

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
        ClassDB::register_class<VisualGasicDrawBenchmark>();
        ClassDB::register_class<VisualGasicTestRunner>();
        ClassDB::register_class<VisualGasicImmediate>();
        ClassDB::register_class<VisualGasicDebugger>();
        ClassDB::register_class<VGVectorCanvas2D>();
        ClassDB::register_class<VisualGasicVectorDrawBenchmark>();

        // System-level classes (v2.9.0)
        ClassDB::register_class<VGProcess>();
        ClassDB::register_class<VGDatabase>();
        ClassDB::register_class<VGFileWatcher>();
        ClassDB::register_class<VGCommonDialog>();
        ClassDB::register_class<VGSocket>();
        ClassDB::register_class<VGSysTray>();
        ClassDB::register_class<VGSettings>();
        ClassDB::register_class<VGComObject>();
        ClassDB::register_class<VGFileSystemObject>();
        ClassDB::register_class<VGScriptingDict>();
        ClassDB::register_class<VGWScriptShell>();
        ClassDB::register_class<VGComInterop>();

        // v2.10.0 classes
        ClassDB::register_class<VGHttpRequest>();
        ClassDB::register_class<VGCollection>();
        ClassDB::register_class<VGRegEx>();
        ClassDB::register_class<VGRegExMatch>();
        ClassDB::register_class<VGTimer>();

        // v3.0 – system-integration classes
        ClassDB::register_class<VGNativeLibrary>();   // libffi: load .so/.dll, call C functions
        ClassDB::register_class<VGNativeStruct>();    // libffi: C struct layout helper
        ClassDB::register_class<VGOdbc>();            // ODBC database connectivity
        ClassDB::register_class<VGCrypto>();          // Hashing, AES, Base64, HMAC
        ClassDB::register_class<VGXml>();             // XML read / write / XPath
        ClassDB::register_class<VGZip>();             // ZIP archive read / write
        ClassDB::register_class<VGTask>();            // Single async task
        ClassDB::register_class<VGTaskRunner>();      // Parallel task runner
        ClassDB::register_class<VisualGasicPackage>();// Package manager

        // v3.1 – system-level programming
        ClassDB::register_class<VGSystem>();           // Hostname, CPU, RAM, disk, OS, uptime, env
        ClassDB::register_class<VGSignalHandler>();    // SIGINT/SIGTERM/SIGHUP + atexit
        ClassDB::register_class<VGFilePermissions>();  // chmod, chown, symlink, file locking
        ClassDB::register_class<VGMemoryBuffer>();     // Raw Peek/Poke byte buffer
        ClassDB::register_class<VGIPC>();              // Named pipes, domain sockets, shared mem
        ClassDB::register_class<VGAndroidBridge>();    // JNI bridge for Android APIs

        // v3.2 – GPU computing & ECS
        ClassDB::register_class<VisualGasicGPU>();      // SIMD vector math, CPU fallback
        ClassDB::register_class<VisualGasicECS>();      // Dictionary-based ECS

        // v3.2 – LSP integration
        ClassDB::register_class<VisualGasicLSP>();      // Language server: completions, hover, definitions

        // v4.3 – database controls
        ClassDB::register_class<VGRecordset>();          // ADODB.Recordset-compatible cursor

        // v6.0 – Python integration
        ClassDB::register_class<PyBridgeFacade>();        // PyImport / PyCallAsync bridge

        // v6.1 – native emulator CPU cores
        ClassDB::register_class<VGCpu6502>();             // Reentrant 6502/6510 core for emulator projects
        ClassDB::register_class<VGC64Machine>();          // Fully-native C64 (CPU+bus+VIC+CIA) for full-speed emulation

        // Register project settings for Python integration
        if (!ProjectSettings::get_singleton()->has_setting("vg/python/embedded_enabled")) {
            ProjectSettings::get_singleton()->set_setting("vg/python/embedded_enabled", false);
            ProjectSettings::get_singleton()->set_initial_value("vg/python/embedded_enabled", false);
        }

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
        ClassDB::register_class<VisualGasicFormDesigner>();
        
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
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}
