#ifndef VISUAL_GASIC_SCRIPT_H
#define VISUAL_GASIC_SCRIPT_H

#include <vector>
#include <godot_cpp/classes/script_extension.hpp>
#include <godot_cpp/classes/script_language.hpp>
#include "visual_gasic_tokenizer.h"
#include "visual_gasic_parser.h" 
#include "visual_gasic_bytecode.h"

using namespace godot;

class VisualGasicScript : public ScriptExtension {
	GDCLASS(VisualGasicScript, ScriptExtension);

    String source_code;
    VisualGasicTokenizer tokenizer;
    VisualGasicParser parser;
    Ref<Script> base_script;
    bool last_reload_had_error = false;
    struct CompiledEntry {
        String original_name;
        String name_lower;
        BytecodeChunk chunk;
    };
    std::vector<CompiledEntry> bytecode_cache;

public:
    ModuleNode *ast_root = nullptr;
    BytecodeChunk bytecode; // For now single chunk for main module
    bool has_bytecode = false;

protected:
	static void _bind_methods();

public:
    virtual ~VisualGasicScript() {
        if (ast_root) {
            delete ast_root;
        }
    }

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

    // Tools
    void format_source_code();
    void clear_bytecode_cache();
    BytecodeChunk *get_bytecode_for(const String &entry_point);
    Dictionary debug_dump_bytecode(const String &entry_point);
};

#endif // VISUAL_GASIC_SCRIPT_H
