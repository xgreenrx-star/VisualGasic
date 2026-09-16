#ifndef VG_CLASSDB_GLOBALS_H
#define VG_CLASSDB_GLOBALS_H

#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/variant/string.hpp>

using namespace godot;

// Names that must compile as OP_GET_GLOBAL so bytecode VM can resolve
// ClassDB static types (VGSystem.GetEnv, System.GetEnv, …).
inline void vg_register_classdb_non_local_names(HashSet<String> &r_names) {
	static const char *names[] = {
		"process", "vgprocess",
		"database", "vgdatabase",
		"filesystemwatcher", "vgfilewatcher",
		"commondialog", "vgcommondialog",
		"winsock", "socket", "vgsocket",
		"systray", "vgsystray",
		"settings", "vgsettings",
		"filesystemobject", "vgfilesystemobject",
		"scriptingdictionary", "vgscriptingdict",
		"wscriptshell", "vgwscriptshell",
		"comobject", "vgcomobject",
		"httprequest", "xmlhttp", "vghttprequest",
		"collection", "vgcollection",
		"regexp", "vgregexp",
		"timer", "vbtimer", "vgtimer",
		"nativelibrary", "vgnativelibrary",
		"nativestruct", "vgnativestruct",
		"odbc", "vgodbc",
		"crypto", "vgcrypto",
		"xml", "vgxml",
		"zip", "vgzip",
		"task", "vgtask",
		"taskrunner", "vgtaskrunner",
		"system", "vgsystem",
		"signalhandler", "vgsignalhandler",
		"filepermissions", "vgfilepermissions",
		"memorybuffer", "vgmemorybuffer",
		"ipc", "vgipc",
		"androidbridge", "vgandroidbridge",
		"gpu", "vggpu", "visualgasicgpu",
		"ecs", "vgecs", "visualgasicecs",
		"recordset", "vgrecordset",
		nullptr
	};
	for (int i = 0; names[i]; i++) {
		r_names.insert(names[i]);
	}
}

#endif
