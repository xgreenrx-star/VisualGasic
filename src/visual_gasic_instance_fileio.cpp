// File I/O operations extracted from visual_gasic_instance.cpp
#include "visual_gasic_instance.h"
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#if defined(_WIN32)
#include <windows.h>
#else
#include <unistd.h>
#endif

void VisualGasicInstance::file_kill(const String &p_path) {
	String path = p_path;
	if (!path.is_absolute_path()) {
		path = "user://" + path;
	}
	auto remove_file = [&](const String &file) -> Error {
		Error err = DirAccess::remove_absolute(file);
		if (err == OK) return OK;
		const String absolute = ProjectSettings::get_singleton()->globalize_path(file);
#if defined(_WIN32)
		if (DeleteFileW(reinterpret_cast<const wchar_t *>(absolute.utf16().get_data()))) return OK;
#else
		if (::unlink(absolute.utf8().get_data()) == 0) return OK;
#endif
		return err;
	};
	const String pattern = path.get_file();
	if (pattern.contains("*") || pattern.contains("?")) {
		const String folder = path.get_base_dir();
		Ref<DirAccess> directory = DirAccess::open(folder);
		if (directory.is_null()) {
			raise_error("Path not found: " + folder, 76);
			return;
		}
		directory->set_include_navigational(false);
		directory->set_include_hidden(true);
		Error err = directory->list_dir_begin();
		if (err != OK) {
			raise_error("Cannot enumerate Kill path: " + folder + " (Error " + String::num_int64(err) + ")", 76);
			return;
		}
		int matches = 0;
		Error last_error = OK;
		String entry = directory->get_next();
		while (!entry.is_empty()) {
			if (!directory->current_is_dir() && entry.matchn(pattern)) {
				matches++;
				err = remove_file(folder.path_join(entry));
				if (err != OK) last_error = err;
			}
			entry = directory->get_next();
		}
		directory->list_dir_end();
		if (last_error != OK) {
			raise_error("Kill failed: " + path + " (Error " + String::num_int64(last_error) + ")", 53);
		} else if (matches == 0) {
			raise_error("File not found: " + path, 53);
		}
		return;
	}
	Ref<DirAccess> parent = DirAccess::open(path.get_base_dir());
	const bool is_link = parent.is_valid() && parent->is_link(path.get_file());
	if (!is_link && DirAccess::dir_exists_absolute(path)) {
		raise_error("Kill cannot remove a directory: " + path, 75);
		return;
	}
	if (remove_file(path) != OK) {
		raise_error("File not found or cannot remove file: " + path, 53);
	}
}
