#include "visual_gasic_language.h"
#include "visual_gasic_script.h"

#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void vg_hot_reload_selftest(VisualGasicLanguage *language) {
	int passed = 0;
	int failed = 0;
	auto check = [&](bool condition, const char *message) {
		if (condition) {
			passed++;
		} else {
			failed++;
			UtilityFunctions::printerr("[HOT-RELOAD-SELFTEST] FAIL: ", message);
		}
	};
	const String path = "user://vg_hot_reload_selftest_" +
			String::num_int64(OS::get_singleton()->get_process_id()) + ".vg";
	auto write_source = [&](const String &source) {
		Ref<FileAccess> file = FileAccess::open(path, FileAccess::WRITE);
		if (file.is_null()) {
			return false;
		}
		file->store_string(source);
		file->flush();
		bool ok = file->get_error() == OK;
		file->close();
		return ok;
	};
	const String first = "Function FirstVersion() As Integer\nReturn 1\nEnd Function\n";
	const String second = "Function SecondVersion() As Integer\nReturn 2\nEnd Function\n";
	const String third = "Function ThirdVersion() As Integer\nReturn 3\nEnd Function\n";
	int initial_count = VisualGasicLanguage::get_live_script_count();
	{
		Ref<VisualGasicScript> script;
		script.instantiate();
		script->set_path(path);
		script->_set_source_code(first);
		check(script->_reload(false) == OK && script->_has_method("FirstVersion"),
				"initial script parses");
		if (write_source(second)) {
			language->_reload_all_scripts();
			check(script->_has_method("SecondVersion") && !script->_has_method("FirstVersion"),
					"reload-all reparses without reentrant registry deadlock");
		} else {
			check(false, "write reload-all fixture");
		}
		if (write_source(third)) {
			language->_reload_tool_script(script, true);
			language->_reload_tool_script(script, true);
			check(script->_has_method("SecondVersion"), "queued reload waits for frame");
			language->_frame();
			check(script->_has_method("ThirdVersion") && !script->_has_method("SecondVersion"),
					"frame processes duplicate queued reload safely");
			language->_reload_tool_script(script, true);
			language->_frame();
			check(script->_has_method("ThirdVersion"), "unchanged queued source remains valid");
			check(script->get_reference_count() == 1, "reload snapshots release their references");
		} else {
			check(false, "write queued-reload fixture");
		}
		Ref<VisualGasicScript> transient;
		transient.instantiate();
		transient->set_path(path + String(".transient"));
		transient->_set_source_code(first);
		check(transient->_reload(false) == OK, "transient script parses");
		language->_reload_tool_script(transient, true);
		transient.unref();
		language->_frame();
	}
	check(VisualGasicLanguage::get_live_script_count() == initial_count,
			"destroyed scripts leave neither registry entries nor queued dangling pointers");
	check(DirAccess::remove_absolute(path) == OK, "remove only the selftest fixture");
	UtilityFunctions::print("[HOT-RELOAD-SELFTEST] RESULTS: ", passed, " passed, ", failed, " failed");
}
