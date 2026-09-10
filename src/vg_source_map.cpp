#include "vg_source_map.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace {

bool vg_path_exists(const String &path) {
	if (path.is_empty()) {
		return false;
	}
	if (FileAccess::file_exists(path)) {
		return true;
	}
	ResourceLoader *loader = ResourceLoader::get_singleton();
	if (loader && path.begins_with("res://") && loader->exists(path)) {
		return true;
	}
	return false;
}

String vg_read_text_file(const String &path) {
	if (path.is_empty()) {
		return String();
	}
	if (FileAccess::file_exists(path)) {
		return FileAccess::get_file_as_string(path);
	}
	Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
	if (file.is_valid()) {
		return file->get_as_text();
	}
	return String();
}

String vg_resolve_include_path(const String &host_path, const String &file_name) {
	String full_path = file_name;
	if (full_path.contains("://")) {
		return full_path;
	}
	String base_dir = host_path.get_base_dir();
	if (!base_dir.is_empty()) {
		return base_dir.path_join(file_name);
	}
	// Fallback: host path missing (CACHE_MODE_IGNORE load) — try res:// + filename.
	ResourceLoader *loader = ResourceLoader::get_singleton();
	if (loader && loader->exists("res://" + file_name)) {
		return "res://" + file_name;
	}
	return file_name;
}

void append_merged_line(VgIncludeResolveResult &result, const String &file, int src_line, const String &line_text) {
	VgSourceLineEntry entry;
	entry.file = file;
	entry.line = src_line;
	result.line_map.push_back(entry);
	result.code += line_text;
	result.code += "\n";
}

} // namespace

VgIncludeResolveResult vg_resolve_includes_with_map(const String &path, const String &code, int depth) {
	VgIncludeResolveResult result;
	if (depth > 10) {
		PackedStringArray lines = code.split("\n");
		for (int i = 0; i < lines.size(); i++) {
			append_merged_line(result, path, i + 1, lines[i]);
		}
		return result;
	}

	PackedStringArray lines = code.split("\n");
	for (int i = 0; i < lines.size(); i++) {
		const int src_line = i + 1;
		String trimmed = lines[i].strip_edges();
		if (trimmed.begins_with("Include ")) {
			String file_name = trimmed.substr(8).strip_edges().replace("\"", "");
			String full_path = vg_resolve_include_path(path, file_name);

			if (vg_path_exists(full_path)) {
				String content = vg_read_text_file(full_path);
				if (content.is_empty() && !file_name.is_empty()) {
					UtilityFunctions::print("Include Error: Could not read ", full_path, " (host ", path, ")");
					append_merged_line(result, path, src_line, "' Missing Include: " + full_path);
					continue;
				}
				UtilityFunctions::print("Including file: ", file_name, " (from ", path, " -> ", full_path, ")");
				VgIncludeResolveResult included = vg_resolve_includes_with_map(full_path, content, depth + 1);
				result.code += included.code;
				for (int j = 0; j < included.line_map.size(); j++) {
					result.line_map.push_back(included.line_map[j]);
				}
				// Match legacy resolve_includes: extra newline after each Include block.
				result.code += "\n";
				VgSourceLineEntry synthetic;
				synthetic.file = path;
				synthetic.line = src_line;
				result.line_map.push_back(synthetic);
			} else {
				UtilityFunctions::print("Include Error: File not found ", full_path, " (host ", path, ")");
				append_merged_line(result, path, src_line, "' Missing Include: " + full_path);
			}
		} else {
			append_merged_line(result, path, src_line, lines[i]);
		}
	}
	return result;
}

bool vg_resolve_source_location(const Vector<VgSourceLineEntry> &line_map, const String &root_path,
		int merged_line, String &out_file, int &out_line) {
	if (merged_line <= 0) {
		return false;
	}
	if (line_map.is_empty()) {
		out_file = root_path;
		out_line = merged_line;
		return !root_path.is_empty();
	}
	int idx = merged_line - 1;
	if (idx >= line_map.size()) {
		idx = line_map.size() - 1;
	}
	if (idx < 0) {
		out_file = root_path;
		out_line = merged_line;
		return !root_path.is_empty();
	}
	out_file = line_map[idx].file;
	out_line = line_map[idx].line;
	return true;
}

int vg_resolve_merged_line(const Vector<VgSourceLineEntry> &line_map, const String &source_file,
		int source_line) {
	if (line_map.is_empty() || source_file.is_empty() || source_line <= 0) {
		return 0;
	}
	for (int i = 0; i < line_map.size(); i++) {
		if (line_map[i].line == source_line && line_map[i].file == source_file) {
			return i + 1;
		}
	}
	const String source_name = source_file.get_file();
	if (!source_name.is_empty()) {
		for (int i = 0; i < line_map.size(); i++) {
			if (line_map[i].line == source_line && line_map[i].file.get_file() == source_name) {
				return i + 1;
			}
		}
	}
	return 0;
}
