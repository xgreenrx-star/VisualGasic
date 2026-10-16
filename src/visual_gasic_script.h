#ifndef VISUAL_GASIC_SCRIPT_H
#define VISUAL_GASIC_SCRIPT_H

#include <vector>
#include <list>
#include <godot_cpp/classes/script_extension.hpp>
#include <godot_cpp/classes/script_language.hpp>
#include <godot_cpp/templates/hash_set.hpp>
#include "visual_gasic_tokenizer.h"
#include "visual_gasic_parser.h" 
#include "visual_gasic_bytecode.h"
#include "vg_source_map.h"

// Forward declaration for hot reload registry
class VisualGasicLanguage;

using namespace godot;

class VisualGasicScript : public ScriptExtension {
	GDCLASS(VisualGasicScript, ScriptExtension);

    String source_code;
    Vector<VgSourceLineEntry> source_line_map;
    // Flattened view of source_line_map for the VM's per-line debug bookkeeping:
    // source_line_file_ids[merged_line - 1] indexes source_files.  OP_LINE runs
    // for every executed statement; comparing one int against the previous
    // line's id lets it skip three String copies per line when the file has
    // not changed (it changes only at Include boundaries).
    Vector<int32_t> source_line_file_ids;
    Vector<String> source_files;
    void rebuild_source_file_index();
    VisualGasicTokenizer tokenizer;
    VisualGasicParser parser;
    Ref<Script> base_script;
    bool last_reload_had_error = false;
    struct CompiledEntry {
        String original_name;
        String name_lower;
        BytecodeChunk chunk;
        bool compile_failed = false;  // Cache compilation failures to avoid re-trying
    };
    // Use std::list instead of std::vector to avoid pointer invalidation when adding new entries
    // This is critical because execute_bytecode holds a pointer to a chunk while nested calls
    // may trigger compilation of other functions, which would invalidate pointers in a vector.
    std::list<CompiledEntry> bytecode_cache;

public:
    String include_host_path_hint; // format loader: path for Include when get_path() is empty
    ModuleNode *ast_root = nullptr;
    BytecodeChunk bytecode; // For now single chunk for main module
    bool has_bytecode = false;
    // Bumped by clear_bytecode_cache() (every reload).  Instances compare it
    // against the generation their chunk-keyed VM memos were built for and
    // drop them when it changes — a recompiled chunk may reuse a freed address.
    uint32_t bytecode_generation = 1;

protected:
	static void _bind_methods();

public:
    virtual ~VisualGasicScript();

    virtual bool _can_instantiate() const override;
    virtual Ref<Script> _get_base_script() const override;
    virtual StringName _get_global_name() const override;
    virtual bool _inherits_script(const Ref<Script> &p_script) const override;
    virtual StringName _get_instance_base_type() const override;
    virtual void *_instance_create(Object *p_for_object) const override;
    virtual bool _instance_has(Object *p_object) const override;
    virtual bool _has_source_code() const override;
    virtual String _get_source_code() const override;
    virtual void _set_source_code(const String &p_code) override;
    virtual Error _reload(bool p_keep_state) override;
    virtual bool _has_method(const StringName &p_method) const override;
    virtual Dictionary _get_method_info(const StringName &p_method) const override;
    virtual bool _is_tool() const override;
    virtual bool _is_valid() const override;
    virtual ScriptLanguage *_get_language() const override;
    virtual bool _has_script_signal(const StringName &p_signal) const override;
    virtual TypedArray<Dictionary> _get_script_signal_list() const override;
    virtual bool _has_property_default_value(const StringName &p_property) const override;
    virtual Variant _get_property_default_value(const StringName &p_property) const override;
    virtual void _update_exports() override;
    virtual TypedArray<Dictionary> _get_script_method_list() const override;
    virtual TypedArray<Dictionary> _get_script_property_list() const override;
    virtual int32_t _get_member_line(const StringName &p_member) const override;
    virtual Dictionary _get_constants() const override;
    virtual TypedArray<StringName> _get_members() const override;
    virtual bool _is_placeholder_fallback_enabled() const override;
    virtual Variant _get_rpc_config() const override;
    virtual bool _has_static_method(const StringName &p_method) const override;
    virtual TypedArray<Dictionary> _get_documentation() const override;
    bool has_reload_errors() const { return last_reload_had_error; }
    const Vector<VisualGasicParser::ParsingError>& get_parser_errors() const { return parser.errors; }
    const Vector<VgSourceLineEntry> &get_source_line_map() const { return source_line_map; }
    // Returns the source_files index for a merged line, or -1 when the line
    // belongs to the host script itself (no Include map, or out of range).
    // Also writes the original (pre-Include) line number to out_line.
    int source_file_id_for_line(int merged_line, int &out_line) const {
        if (merged_line <= 0 || source_line_file_ids.is_empty()) {
            out_line = merged_line;
            return -1;
        }
        int idx = merged_line - 1;
        if (idx >= source_line_file_ids.size()) idx = source_line_file_ids.size() - 1;
        out_line = source_line_map[idx].line;
        return source_line_file_ids[idx];
    }
    const String &source_file_by_id(int id) const { return source_files[id]; }
    bool resolve_source_location(int merged_line, String &out_file, int &out_line) const;
    int resolve_merged_line(const String &source_file, int source_line) const;

    // Tools
    void format_source_code();
    void clear_bytecode_cache();
    BytecodeChunk *get_bytecode_for(const String &entry_point, const HashSet<String>* extra_buffer_vars = nullptr, const Vector<ModuleNode*>* import_modules = nullptr);
    Dictionary debug_dump_bytecode(const String &entry_point);
};

#endif // VISUAL_GASIC_SCRIPT_H
