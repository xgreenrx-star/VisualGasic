#ifndef VG_SOURCE_MAP_H
#define VG_SOURCE_MAP_H

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/templates/vector.hpp>

using namespace godot;

// Maps one line of merged (Include-expanded) source to its original file/line.
struct VgSourceLineEntry {
	String file;
	int line = 1;
};

struct VgIncludeResolveResult {
	String code;
	Vector<VgSourceLineEntry> line_map;
};

// Expand Include directives and record merged-line → source-file mapping.
VgIncludeResolveResult vg_resolve_includes_with_map(const String &path, const String &code, int depth = 0);

// Resolve a 1-based merged line; falls back to root_path + merged_line when unmapped.
bool vg_resolve_source_location(const Vector<VgSourceLineEntry> &line_map, const String &root_path,
		int merged_line, String &out_file, int &out_line);

// Reverse lookup: source file + line → 1-based merged line (0 if not found).
int vg_resolve_merged_line(const Vector<VgSourceLineEntry> &line_map, const String &source_file,
		int source_line);

#endif // VG_SOURCE_MAP_H
