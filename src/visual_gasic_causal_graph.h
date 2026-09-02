#ifndef VISUAL_GASIC_CAUSAL_GRAPH_H
#define VISUAL_GASIC_CAUSAL_GRAPH_H

#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>

namespace godot {

/// Parse VG source via the AST and produce a causal-chain report Dictionary:
///   { "ok": bool, "report": String, "engine": "ast" }
/// On parse failure: { "ok": false, "report": "", "errors": [...] }
Dictionary vg_analyze_causal_graph(const String &p_code, const Array &p_roots);

} // namespace godot

#endif // VISUAL_GASIC_CAUSAL_GRAPH_H
