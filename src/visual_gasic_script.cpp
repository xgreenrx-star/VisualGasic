#include "visual_gasic_script.h"
#include "visual_gasic_language.h"
#include "visual_gasic_instance.h"
#include "visual_gasic_compiler.h"
#include "visual_gasic_optimizer.h"
#include <godot_cpp/godot.hpp>
#include <godot_cpp/classes/resource_loader.hpp>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

using namespace godot;

namespace {

String variant_preview(const Variant &value) {
    String preview = UtilityFunctions::var_to_str(value);
    preview = preview.replace("\n", " ");
    const int64_t max_len = 60;
    if (preview.length() > max_len) {
        preview = preview.substr(0, max_len - 3) + "...";
    }
    return preview;
}

String describe_constant(const BytecodeChunk *chunk, int idx) {
    if (!chunk) {
        return vformat("const[%d]", idx);
    }
    if (idx >= 0 && idx < chunk->constants.size()) {
        return vformat("const[%d]=%s", idx, variant_preview(chunk->constants[idx]));
    }
    return vformat("const[%d]=<out-of-range>", idx);
}

String describe_local_slot(const BytecodeChunk *chunk, int slot) {
    if (!chunk) {
        return vformat("slot[%d]", slot);
    }
    if (slot >= 0 && slot < chunk->local_names.size()) {
        return vformat("slot[%d]=%s", slot, chunk->local_names[slot]);
    }
    return vformat("slot[%d]", slot);
}

String opcode_name(uint8_t op) {
    switch (op) {
#define OP_NAME_CASE(name) case name: return #name
        OP_NAME_CASE(OP_CONSTANT);
        OP_NAME_CASE(OP_CONSTANT_LONG);
        OP_NAME_CASE(OP_POP);
        OP_NAME_CASE(OP_GET_GLOBAL);
        OP_NAME_CASE(OP_SET_GLOBAL);
        OP_NAME_CASE(OP_GET_LOCAL);
        OP_NAME_CASE(OP_SET_LOCAL);
        OP_NAME_CASE(OP_ADD);
        OP_NAME_CASE(OP_SUBTRACT);
        OP_NAME_CASE(OP_MULTIPLY);
        OP_NAME_CASE(OP_DIVIDE);
        OP_NAME_CASE(OP_NEGATE);
        OP_NAME_CASE(OP_CONCAT);
        OP_NAME_CASE(OP_MOD);
        OP_NAME_CASE(OP_INT_DIVIDE);
        OP_NAME_CASE(OP_LIKE);
        OP_NAME_CASE(OP_STRING_REPEAT);
        OP_NAME_CASE(OP_STRING_REPEAT_OUTER);
        OP_NAME_CASE(OP_INTEROP_SET_NAME_LEN);
        OP_NAME_CASE(OP_ADD_I64);
        OP_NAME_CASE(OP_ADD_I64_CONST);
        OP_NAME_CASE(OP_SUB_I64);
        OP_NAME_CASE(OP_SUB_I64_CONST);
        OP_NAME_CASE(OP_MUL_I64);
        OP_NAME_CASE(OP_MUL_I64_CONST);
        OP_NAME_CASE(OP_ADD_F64);
        OP_NAME_CASE(OP_SUB_F64);
        OP_NAME_CASE(OP_MUL_F64);
        OP_NAME_CASE(OP_DIV_F64);
        OP_NAME_CASE(OP_ACCUM_I64_MULADD_CONST);
        OP_NAME_CASE(OP_ADD_LOCAL_I64_STACK);
        OP_NAME_CASE(OP_SUB_LOCAL_I64_STACK);
        OP_NAME_CASE(OP_ADD_LOCAL_I64_CONST);
        OP_NAME_CASE(OP_SUB_LOCAL_I64_CONST);
        OP_NAME_CASE(OP_INC_LOCAL_I64);
        OP_NAME_CASE(OP_ARITH_SUM);
        OP_NAME_CASE(OP_BRANCH_SUM);
        OP_NAME_CASE(OP_SUM_ARRAY_I64);
        OP_NAME_CASE(OP_SUM_DICT_I64);
        OP_NAME_CASE(OP_ARRAY_FILL_I64_SEQ);
        OP_NAME_CASE(OP_ALLOC_FILL_I64);
        OP_NAME_CASE(OP_ALLOC_FILL_I64_OFFSET);
        OP_NAME_CASE(OP_ALLOC_FILL_REPEAT_I64);
        OP_NAME_CASE(OP_LEN);
        OP_NAME_CASE(OP_EQUAL);
        OP_NAME_CASE(OP_NOT_EQUAL);
        OP_NAME_CASE(OP_GREATER);
        OP_NAME_CASE(OP_LESS);
        OP_NAME_CASE(OP_GREATER_EQUAL);
        OP_NAME_CASE(OP_LESS_EQUAL);
        OP_NAME_CASE(OP_EQUAL_I64);
        OP_NAME_CASE(OP_NOT_EQUAL_I64);
        OP_NAME_CASE(OP_LESS_EQUAL_I64);
        OP_NAME_CASE(OP_NOT);
        OP_NAME_CASE(OP_AND);
        OP_NAME_CASE(OP_OR);
        OP_NAME_CASE(OP_XOR);
        OP_NAME_CASE(OP_JUMP);
        OP_NAME_CASE(OP_JUMP_IF_FALSE);
        OP_NAME_CASE(OP_JUMP_IF_TRUE);
        OP_NAME_CASE(OP_LOOP);
        OP_NAME_CASE(OP_CALL);
        OP_NAME_CASE(OP_CALL_BUILTIN);
        OP_NAME_CASE(OP_RETURN);
        OP_NAME_CASE(OP_RETURN_VALUE);
        OP_NAME_CASE(OP_PRINT);
        OP_NAME_CASE(OP_DEBUG_PRINT);
        OP_NAME_CASE(OP_NEW_ARRAY);
        OP_NAME_CASE(OP_NEW_ARRAY_I64);
        OP_NAME_CASE(OP_NEW_DICT);
        OP_NAME_CASE(OP_GET_ARRAY);
        OP_NAME_CASE(OP_SET_ARRAY);
        OP_NAME_CASE(OP_GET_ARRAY_UNCHECKED);
        OP_NAME_CASE(OP_SET_ARRAY_UNCHECKED);
        OP_NAME_CASE(OP_GET_ARRAY_FAST);
        OP_NAME_CASE(OP_SET_ARRAY_FAST);
        OP_NAME_CASE(OP_GET_ARRAY_FAST_UNCHECKED);
        OP_NAME_CASE(OP_SET_ARRAY_FAST_UNCHECKED);
        OP_NAME_CASE(OP_GET_DICT_FAST);
        OP_NAME_CASE(OP_SET_DICT_FAST);
        OP_NAME_CASE(OP_GET_DICT_TRUSTED);
        OP_NAME_CASE(OP_SET_DICT_TRUSTED);
        OP_NAME_CASE(OP_ARRAY_FILL_I64_OFFSET);
        OP_NAME_CASE(OP_GET_MEMBER);
        OP_NAME_CASE(OP_SET_MEMBER);
        OP_NAME_CASE(OP_NIL);
        OP_NAME_CASE(OP_TRUE);
        OP_NAME_CASE(OP_FALSE);
        OP_NAME_CASE(OP_ABS);
        OP_NAME_CASE(OP_SGN);
        OP_NAME_CASE(OP_REGISTER_WHENEVER);
        OP_NAME_CASE(OP_SUSPEND_WHENEVER);
        OP_NAME_CASE(OP_RESUME_WHENEVER);
        OP_NAME_CASE(OP_RESTORE_DATA);
        OP_NAME_CASE(OP_READ_DATA);
        OP_NAME_CASE(OP_ON_ERROR_RESUME_NEXT);
        OP_NAME_CASE(OP_ON_ERROR_GOTO);
        OP_NAME_CASE(OP_ON_ERROR_GOTO_0);
#undef OP_NAME_CASE
        default:
            return vformat("OP_UNKNOWN_%d", (int)op);
    }
}

int opcode_operand_length(uint8_t op) {
    switch (op) {
        // 1-byte operand: local slots, arg counts, flags
        case OP_GET_LOCAL:
        case OP_SET_LOCAL:
        case OP_ADD_LOCAL_I64_STACK:
        case OP_SUB_LOCAL_I64_STACK:
        case OP_INC_LOCAL_I64:
        case OP_BRANCH_SUM:
        case OP_GET_ARRAY:
        case OP_SET_ARRAY:
        case OP_GET_ARRAY_UNCHECKED:
        case OP_SET_ARRAY_UNCHECKED:
        case OP_GET_ARRAY_FAST:
        case OP_SET_ARRAY_FAST:
        case OP_GET_ARRAY_FAST_UNCHECKED:
        case OP_SET_ARRAY_FAST_UNCHECKED:
        case OP_GET_DICT_FAST:
        case OP_SET_DICT_FAST:
        case OP_GET_DICT_TRUSTED:
        case OP_SET_DICT_TRUSTED:
            return 1;
        // 2-byte operand: single 16-bit constant pool index
        case OP_CONSTANT:
        case OP_CONSTANT_LONG:
        case OP_GET_GLOBAL:
        case OP_SET_GLOBAL:
        case OP_GET_MEMBER:
        case OP_SET_MEMBER:
        case OP_ADD_I64_CONST:
        case OP_SUB_I64_CONST:
        case OP_MUL_I64_CONST:
        case OP_REGISTER_WHENEVER:
        case OP_SUSPEND_WHENEVER:
        case OP_RESUME_WHENEVER:
        case OP_ON_ERROR_GOTO:
        case OP_COERCE_TYPE:
            return 2;
        // 2-byte operand: non-const pairs (jump offsets, local+count, etc.)
        case OP_JUMP:
        case OP_JUMP_IF_FALSE:
        case OP_JUMP_IF_TRUE:
        case OP_LOOP:
        case OP_CALL_BUILTIN:
        case OP_SETUP_TRY:
        case OP_DEBUG_LINE:
        case OP_GOSUB:
        case OP_ITER_ARRAY:
        case OP_SET_DICT_LOCAL:
            return 2;
        // 3-byte operand: const16 + 1 byte count/slot
        case OP_CALL:
        case OP_METHOD_CALL:
        case OP_NEW_OBJECT:
        case OP_RAISE_EVENT:
        case OP_ADD_LOCAL_I64_CONST:
        case OP_SUB_LOCAL_I64_CONST:
        case OP_STRING_REPEAT_OUTER:
        case OP_INTEROP_SET_NAME_LEN:
        case OP_SET_DICT_GLOBAL:
        case OP_PARALLEL_FOR_BEGIN:
            return 3;
        // 4-byte operand: 2x const16
        case OP_ARITH_SUM:
            return 4;
        // 4-byte operand: 1 local + 1 const16
        case OP_ACCUM_I64_MULADD_CONST:
            return 4;
        // 5-byte operand: const16 + flag + body_len16
        case OP_TASK_RUN_BEGIN:
            return 5;
        // 7-byte operand: 3 local + const16 + 2 local
        case OP_ALLOC_FILL_REPEAT_I64:
            return 7;
        default:
            return 0;
    }
}

String describe_jump_target(uint8_t op, const Array &operands, int offset) {
    if (operands.size() < 2) {
        return String();
    }
    int hi = int(operands[0]);
    int lo = int(operands[1]);
    int delta = (hi << 8) | lo;
    int next_ip = offset + 3;
    int target = (op == OP_LOOP) ? (next_ip - delta) : (next_ip + delta);
    return vformat("delta=%d -> %04d", delta, target);
}

String describe_operands(uint8_t op, const Array &operands, const BytecodeChunk *chunk, int offset) {
    // Helper: read a 16-bit LE constant pool index from two consecutive operand bytes
    auto const16 = [&](int byte_offset) -> int {
        if (byte_offset + 1 >= operands.size()) return 0;
        return (int(operands[byte_offset + 1]) << 8) | int(operands[byte_offset]);
    };

    switch (op) {
        case OP_CONSTANT:
        case OP_CONSTANT_LONG:
            if (operands.size() >= 2) {
                return describe_constant(chunk, const16(0));
            }
            break;
        case OP_GET_GLOBAL:
        case OP_SET_GLOBAL:
            if (operands.size() >= 2) {
                return describe_constant(chunk, const16(0));
            }
            break;
        case OP_GET_LOCAL:
        case OP_SET_LOCAL:
        case OP_ADD_LOCAL_I64_STACK:
        case OP_SUB_LOCAL_I64_STACK:
        case OP_INC_LOCAL_I64:
        case OP_BRANCH_SUM:
            if (operands.size() >= 1) {
                return describe_local_slot(chunk, int(operands[0]));
            }
            break;
        case OP_ADD_LOCAL_I64_CONST:
        case OP_SUB_LOCAL_I64_CONST:
            // [LOCAL_SLOT] [CONST_LO] [CONST_HI]
            if (operands.size() >= 3) {
                int cidx = (int(operands[2]) << 8) | int(operands[1]);
                return vformat("%s, %s",
                    describe_local_slot(chunk, int(operands[0])),
                    describe_constant(chunk, cidx));
            }
            break;
        case OP_ADD_I64_CONST:
        case OP_SUB_I64_CONST:
        case OP_MUL_I64_CONST:
            if (operands.size() >= 2) {
                return describe_constant(chunk, const16(0));
            }
            break;
        case OP_ARITH_SUM:
            // [K_LO] [K_HI] [C_LO] [C_HI]
            if (operands.size() >= 4) {
                return vformat("k=%s, c=%s",
                    describe_constant(chunk, const16(0)),
                    describe_constant(chunk, const16(2)));
            }
            break;
        case OP_STRING_REPEAT_OUTER:
        case OP_INTEROP_SET_NAME_LEN:
            // [SLOT] [LIT_LO] [LIT_HI]
            if (operands.size() >= 3) {
                int cidx = (int(operands[2]) << 8) | int(operands[1]);
                return vformat("%s, %s",
                    describe_local_slot(chunk, int(operands[0])),
                    describe_constant(chunk, cidx));
            }
            break;
        case OP_JUMP:
        case OP_JUMP_IF_FALSE:
        case OP_JUMP_IF_TRUE:
        case OP_LOOP:
            return describe_jump_target(op, operands, offset);
        case OP_CALL:
            // [NAME_LO] [NAME_HI] [ARG_COUNT]
            if (operands.size() >= 3) {
                return vformat("%s, argc=%d",
                    describe_constant(chunk, const16(0)),
                    int(operands[2]));
            }
            break;
        case OP_CALL_BUILTIN:
            if (operands.size() >= 2) {
                return vformat("builtin=%d, argc=%d", int(operands[0]), int(operands[1]));
            }
            break;
        case OP_GET_ARRAY:
        case OP_SET_ARRAY:
        case OP_GET_ARRAY_UNCHECKED:
        case OP_SET_ARRAY_UNCHECKED:
        case OP_GET_ARRAY_FAST:
        case OP_SET_ARRAY_FAST:
        case OP_GET_ARRAY_FAST_UNCHECKED:
        case OP_SET_ARRAY_FAST_UNCHECKED:
        case OP_GET_DICT_FAST:
        case OP_SET_DICT_FAST:
        case OP_GET_DICT_TRUSTED:
        case OP_SET_DICT_TRUSTED:
            if (operands.size() >= 1) {
                return vformat("indices=%d", int(operands[0]));
            }
            break;
        case OP_GET_MEMBER:
        case OP_SET_MEMBER:
            if (operands.size() >= 2) {
                return describe_constant(chunk, const16(0));
            }
            break;
        case OP_ALLOC_FILL_REPEAT_I64:
            // [SUM_SLOT] [ARR_SLOT] [TMP_SLOT] [LIT_LO] [LIT_HI] [ITER_SLOT] [SIZE_SLOT]
            if (operands.size() >= 7) {
                int lit_idx = (int(operands[4]) << 8) | int(operands[3]);
                return vformat("sum=%s, arr=%s, tmp=%s, %s, iter=%s, size=%s",
                    describe_local_slot(chunk, int(operands[0])),
                    describe_local_slot(chunk, int(operands[1])),
                    describe_local_slot(chunk, int(operands[2])),
                    describe_constant(chunk, lit_idx),
                    describe_local_slot(chunk, int(operands[5])),
                    describe_local_slot(chunk, int(operands[6])));
            }
            break;
    }
    return String();
}

} // namespace

void VisualGasicScript::_bind_methods() {
    ClassDB::bind_method(D_METHOD("debug_dump_bytecode", "entry_point"), &VisualGasicScript::debug_dump_bytecode);
}

VisualGasicScript::~VisualGasicScript() {
    VisualGasicLanguage::unregister_script(this);
    if (ast_root) {
        delete ast_root;
    }
}

bool VisualGasicScript::_can_instantiate() const {
    // Typically true if the script is valid
    return true; 
}

Ref<Script> VisualGasicScript::_get_base_script() const {
    return base_script;
}

StringName VisualGasicScript::_get_global_name() const {
    // ClassName statement (v4.2.0) — register script globally so it can be
    // used by class_name in other scripts or instantiated from the editor.
    if (ast_root && !ast_root->class_name_vg.is_empty()) {
        return StringName(ast_root->class_name_vg);
    }
    return StringName();
}

bool VisualGasicScript::_inherits_script(const Ref<Script> &p_script) const {
    return false;
}

StringName VisualGasicScript::_get_instance_base_type() const {
    if (base_script.is_valid()) {
        return base_script->get_instance_base_type();
    }
    if (ast_root && !ast_root->inherits_path.is_empty()) {
        // If it's not a path (doesn't contain / or .), assume native type
        if (ast_root->inherits_path.find("/") == -1 && ast_root->inherits_path.find(".") == -1) {
            return StringName(ast_root->inherits_path);
        }
    }
    return "Node"; // Default
}

void *VisualGasicScript::_instance_create(Object *p_for_object) const {
    VisualGasicInstance *instance = memnew(VisualGasicInstance(Ref<VisualGasicScript>(this), p_for_object));
    return internal::gdextension_interface_script_instance_create3(VisualGasicInstance::get_script_instance_info(), instance);
}

bool VisualGasicScript::_instance_has(Object *p_object) const {
    // This is hard to check without tracking instances. 
    // Usually, strict tracking is needed, but for now we return false or check script attachment.
    // However, the Engine often calls this.
    return false; 
}

bool VisualGasicScript::_has_source_code() const {
    return true;
}

String VisualGasicScript::_get_source_code() const {
    return source_code;
}

#include <godot_cpp/classes/file_access.hpp>

// Helper to resolve includes
String resolve_includes(const String& path, const String& code, int depth = 0) {
    if (depth > 10) return code; // Prevent infinite recursion

    String result = "";
    PackedStringArray lines = code.split("\n");
    
    for(int i=0; i<lines.size(); i++) {
        String line = lines[i].strip_edges();
        if (line.begins_with("Include ")) {
             String file_name = line.substr(8).strip_edges().replace("\"", "");
             UtilityFunctions::print("Including file: ", file_name);
             
             // Check if path is absolute or relative
             String full_path = file_name;
             if (!full_path.contains("://")) {
                  // Relative to current script path
                  // We need the path of the script being loaded?
                  // path arg should be the directory of the current file being processed?
                  // But 'path' passed to us is... ?
             }
             
             if (FileAccess::file_exists(full_path)) {
                 String content = FileAccess::get_file_as_string(full_path);
                 result += resolve_includes(full_path, content, depth + 1) + "\n";
             } else {
                 UtilityFunctions::print("Include Error: File not found ", full_path);
                 result += "' Missing Include: " + full_path + "\n";
             }
        } else {
             result += lines[i] + "\n";
        }
    }
    return result;
}

void VisualGasicScript::_set_source_code(const String &p_code) {
    source_code = p_code;
    
    // Auto-Format
    // Since _set_source_code is called by Editor when typing or saving,
    // we can trigger format here.
    // However, triggering it on every keystroke is bad.
    // Godot Editor usually sets source code on save/focus lost?
    // Actually, TextEdit updates it frequently.
    // Let's only do it if explicitly requested via a Manual Tool or On Save hook.
    // But since we don't have On Save hook easily without editor plugin magic,
    // we will check formatting in the reload() which happens on save.
}

#include <godot_cpp/classes/project_settings.hpp>

Error VisualGasicScript::_reload(bool p_keep_state) {
    // EMERGENCY: Save source immediately for crash debugging
    if (get_path().is_empty() && source_code.length() > 3000) {
        Ref<FileAccess> debug_file = FileAccess::open("/tmp/vg_crash_script.vg", FileAccess::WRITE);
        if (debug_file.is_valid()) {
            debug_file->store_string(source_code);
            debug_file->close();
        }
    }
    
    // Register with language hot reload tracker (idempotent — set insert)
    VisualGasicLanguage::register_script(this);
    
    last_reload_had_error = false;
    clear_bytecode_cache();
    // Apply Formatting just before successful reload?
    format_source_code();
    
    // Reload logic: Validate tokens
    String processed_code = resolve_includes("", source_code);
    Vector<VisualGasicTokenizer::Token> tokens = tokenizer.tokenize(processed_code);
    // Scan ALL tokens for errors (not just the last — error tokens in the middle
    // can cause the parser to enter an invalid state and crash)
    for (int i = 0; i < tokens.size(); i++) {
        if (tokens[i].type == VisualGasicTokenizer::TOKEN_ERROR) {
            String err_msg = tokens[i].value;
            UtilityFunctions::print("Script Reload Error (Token): ", err_msg);
            last_reload_had_error = true;
            return ERR_PARSE_ERROR;
        }
    }
    
    // Re-parse
    // Ensure parser does not try to delete AST-owned nodes from its
    // tracked allocation lists when the script is torn down. Clear
    // the parser trackers first to avoid double-delete in the
    // parser destructor (parser is a member and will be destroyed
    // after this object).
    parser.clear_tracked_nodes();
    if (ast_root) delete ast_root;
    
    String path = get_path();
    if (path.is_empty()) {
        UtilityFunctions::print("[VG] WARNING: Parsing script with empty path, source length: ", source_code.length());
        // Save the problematic script for debugging
        Ref<FileAccess> f = FileAccess::open("/tmp/vg_crash_script.vg", FileAccess::WRITE);
        if (f.is_valid()) {
            f->store_string(source_code);
            f->close();
            UtilityFunctions::print("[VG] Saved crash script to /tmp/vg_crash_script.vg");
        }
    } else {
        UtilityFunctions::print("[VG] Parsing: ", path);
    }
    
    if (tokens.is_empty()) {
        UtilityFunctions::print("[VG] ERROR: Empty token list");
        last_reload_had_error = true;
        return ERR_PARSE_ERROR;
    }
    
    ast_root = parser.parse(tokens);
    UtilityFunctions::print("[VG] Parse completed, errors: ", parser.errors.size());
    
    if (parser.errors.size() > 0) {
         for (int i = 0; i < parser.errors.size(); i++) {
             UtilityFunctions::print("[VG] Parser Error: ", parser.errors[i].message, " at line ", parser.errors[i].line);
         }
         // Continue with partially-parsed AST (VB6-style: errors in one Sub
         // should not prevent other Subs from running).  Mark that we had
         // errors so the editor can show them, but do NOT bail out.
         last_reload_had_error = true;
    }
        if (!ast_root) {
           last_reload_had_error = true;
           return ERR_PARSE_ERROR;
        }

    // Handle Inheritance
    base_script.unref();
    if (ast_root && !ast_root->inherits_path.is_empty()) {
        if (ast_root->inherits_path.find("/") != -1 || ast_root->inherits_path.find(".") != -1) {
            // It is a path to a script
            base_script = ResourceLoader::get_singleton()->load(ast_root->inherits_path);
        }
    }
    
    // Scan Labels
    if (ast_root) {
        for(int i=0; i<ast_root->subs.size(); i++) {
            SubDefinition* sub = ast_root->subs[i];
            for(int j=0; j<sub->statements.size(); j++) {
                if (sub->statements[j]->type == STMT_LABEL) {
                    LabelStatement* lbl = (LabelStatement*)sub->statements[j];
                    sub->label_map[lbl->name] = j;
                }
            }
        }
    }
    
    return OK;
}

bool VisualGasicScript::_has_method(const StringName &p_method) const {
    if (ScriptExtension::_has_method(p_method)) {
        return true;
    }
    if (p_method == StringName("_OnSignal")) return true;
    if (p_method == StringName("_OnArraySignal")) return true;
    if (p_method == StringName("_OnGuiInput")) return true;
    if (p_method == StringName("_vg_resume_coroutine")) return true; // Await resume (v4.2.0)
    if (!ast_root) return false;
    
    String method_str = String(p_method);
    for(int i=0; i<ast_root->subs.size(); i++) {
        if (ast_root->subs[i]->name.nocasecmp_to(method_str) == 0) return true;
    }
    
    // Godot uses snake_case for virtual methods (e.g. "_unhandled_input")
    // while VG subs use PascalCase ("_UnhandledInput").  nocasecmp_to fails
    // for multi-word names because the underscores differ.
    // Convert snake_case → PascalCase and try again.
    if (method_str.begins_with("_") && method_str.length() >= 2 && method_str.find("_", 1) >= 0) {
        String pascal = "_";
        bool cap_next = true;
        for (int i = 1; i < method_str.length(); i++) {
            char32_t c = method_str[i];
            if (c == '_') {
                cap_next = true;
            } else {
                if (cap_next) {
                    if (c >= 'a' && c <= 'z') c = c - 'a' + 'A';
                    cap_next = false;
                }
                pascal += String::chr(c);
            }
        }
        for(int i=0; i<ast_root->subs.size(); i++) {
            if (ast_root->subs[i]->name.nocasecmp_to(pascal) == 0) return true;
        }
    }
    
    return false;
}

Dictionary VisualGasicScript::_get_method_info(const StringName &p_method) const {
    return Dictionary();
}

bool VisualGasicScript::_is_tool() const {
    return false;
}

bool VisualGasicScript::_is_valid() const {
    return !last_reload_had_error;
}

ScriptLanguage *VisualGasicScript::_get_language() const {
    return VisualGasicLanguage::get_singleton();
}

bool VisualGasicScript::_has_script_signal(const StringName &p_signal) const {
    if (!ast_root) return false;
    for(int i=0; i<ast_root->events.size(); i++) {
        if (ast_root->events[i]->name == p_signal) return true;
    }
    return false;
}

TypedArray<Dictionary> VisualGasicScript::_get_script_signal_list() const {
    TypedArray<Dictionary> signals;
    if (!ast_root) return signals;
    
    for(int i=0; i<ast_root->events.size(); i++) {
        Dictionary sig;
        sig["name"] = ast_root->events[i]->name;
        
        TypedArray<Dictionary> args;
        for(int j=0; j<ast_root->events[i]->arguments.size(); j++) {
            Dictionary arg;
            arg["name"] = ast_root->events[i]->arguments[j];
            arg["type"] = Variant::NIL; // Dynamic for now
            args.push_back(arg);
        }
        sig["args"] = args;
        signals.push_back(sig);
    }
    return signals;
}

bool VisualGasicScript::_has_property_default_value(const StringName &p_property) const {
    // Export variables with default values (v4.2.0)
    if (!ast_root) return false;
    for (int i = 0; i < ast_root->variables.size(); i++) {
        VariableDefinition* v = ast_root->variables[i];
        if (v->is_export && v->name == String(p_property) && v->default_value) {
            return true;
        }
    }
    return false;
}

Variant VisualGasicScript::_get_property_default_value(const StringName &p_property) const {
    // Export variables with default values (v4.2.0)
    if (!ast_root) return Variant();
    for (int i = 0; i < ast_root->variables.size(); i++) {
        VariableDefinition* v = ast_root->variables[i];
        if (v->is_export && v->name == String(p_property) && v->default_value) {
            // Evaluate static literal defaults
            if (v->default_value->type == ExpressionNode::LITERAL) {
                LiteralNode* lit = static_cast<LiteralNode*>(v->default_value);
                return lit->value;
            }
        }
    }
    return Variant();
}

void VisualGasicScript::_update_exports() {
}

TypedArray<Dictionary> VisualGasicScript::_get_script_method_list() const {
    return TypedArray<Dictionary>();
}

TypedArray<Dictionary> VisualGasicScript::_get_script_property_list() const {
    TypedArray<Dictionary> properties;
    if (!ast_root) return properties;

    for (int i = 0; i < ast_root->variables.size(); i++) {
        VariableDefinition* v = ast_root->variables[i];
        if (v->visibility == VIS_PUBLIC || v->is_export) {
            Dictionary prop;
            prop["name"] = v->name;
            int usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE;
            // Export flag (v4.2.0) — expose to Godot Inspector
            if (v->is_export) {
                usage |= PROPERTY_USAGE_EDITOR;
            }
            prop["usage"] = usage;
            
            // Map VB Types to Godot Types
            String t = v->type.to_lower();
            if (t == "integer" || t == "long") prop["type"] = Variant::INT;
            else if (t == "single" || t == "double" || t == "float") prop["type"] = Variant::FLOAT;
            else if (t == "string") prop["type"] = Variant::STRING;
            else if (t == "boolean") prop["type"] = Variant::BOOL;
            else if (t == "color") prop["type"] = Variant::COLOR;
            else if (t == "vector2") prop["type"] = Variant::VECTOR2;
            else if (t == "vector3") prop["type"] = Variant::VECTOR3;
            else if (t == "nodepath") prop["type"] = Variant::NODE_PATH;
            else prop["type"] = Variant::NIL; // Variant
            
            properties.push_back(prop);
        }
    }
    return properties;
}

int32_t VisualGasicScript::_get_member_line(const StringName &p_member) const {
    return -1;
}

Dictionary VisualGasicScript::_get_constants() const {
    return Dictionary();
}

TypedArray<StringName> VisualGasicScript::_get_members() const {
    return TypedArray<StringName>();
}

bool VisualGasicScript::_is_placeholder_fallback_enabled() const {
    return last_reload_had_error;
}

Variant VisualGasicScript::_get_rpc_config() const {
    return Variant();
}

bool VisualGasicScript::_has_static_method(const StringName &p_method) const {
    return false;
}

TypedArray<Dictionary> VisualGasicScript::_get_documentation() const {
    return TypedArray<Dictionary>();
}

void VisualGasicScript::clear_bytecode_cache() {
    bytecode.code.clear();
    bytecode.constants.clear();
    bytecode.lines.clear();
    bytecode.local_names.clear();
    bytecode.local_types.clear();
    bytecode.local_count = 0;
    bytecode_cache.clear();
    has_bytecode = false;
}

BytecodeChunk *VisualGasicScript::get_bytecode_for(const String &entry_point) {
    if (!ast_root || entry_point.is_empty()) {
        return nullptr;
    }

    String key = entry_point.to_lower();
    for (CompiledEntry &entry : bytecode_cache) {
        if (entry.name_lower == key) {
            // Return nullptr for entries that previously failed compilation
            if (entry.compile_failed) {
                return nullptr;
            }
            return &entry.chunk;
        }
    }

    VisualGasicCompiler compiler;
    BytecodeChunk compiled_chunk;
    compiled_chunk.code.clear();
    compiled_chunk.constants.clear();
    compiled_chunk.lines.clear();
    compiled_chunk.local_names.clear();
    compiled_chunk.local_types.clear();
    compiled_chunk.local_count = 0;

    if (!compiler.compile(ast_root, entry_point, &compiled_chunk)) {
        // Bytecode compilation failed - this is expected for some constructs
        // (e.g., method calls on objects). AST interpreter will handle it.
        // Cache the failure to avoid re-compiling on every call.
        CompiledEntry fail_entry;
        fail_entry.original_name = entry_point;
        fail_entry.name_lower = key;
        fail_entry.compile_failed = true;
        bytecode_cache.push_back(fail_entry);
        return nullptr;
    }

    // Run the bytecode peephole optimizer (v2.4.1)
    {
        VisualGasicOptimizer::optimize(&compiled_chunk, false);
    }

    CompiledEntry entry;
    entry.original_name = entry_point;
    entry.name_lower = key;
    entry.chunk = compiled_chunk;
    bytecode_cache.push_back(entry);

    bytecode = compiled_chunk;
    has_bytecode = true;

    return &bytecode_cache.back().chunk;
}

Dictionary VisualGasicScript::debug_dump_bytecode(const String &entry_point) {
    Dictionary info;
    BytecodeChunk *chunk = get_bytecode_for(entry_point);
    if (!chunk) {
        info["error"] = "No bytecode available";
        return info;
    }

    info["entry_point"] = entry_point;

    PackedByteArray code_bytes;
    code_bytes.resize(chunk->code.size());
    for (int i = 0; i < chunk->code.size(); i++) {
        code_bytes.set(i, chunk->code[i]);
    }
    info["code"] = code_bytes;

    PackedInt32Array line_info;
    line_info.resize(chunk->lines.size());
    for (int i = 0; i < chunk->lines.size(); i++) {
        line_info.set(i, chunk->lines[i]);
    }
    info["lines"] = line_info;

    PackedStringArray local_names;
    local_names.resize(chunk->local_names.size());
    for (int i = 0; i < chunk->local_names.size(); i++) {
        local_names.set(i, chunk->local_names[i]);
    }
    info["local_names"] = local_names;

    PackedByteArray local_types;
    local_types.resize(chunk->local_types.size());
    for (int i = 0; i < chunk->local_types.size(); i++) {
        local_types.set(i, chunk->local_types[i]);
    }
    info["local_types"] = local_types;
    info["local_count"] = chunk->local_count;

    Array constants;
    constants.resize(chunk->constants.size());
    for (int i = 0; i < chunk->constants.size(); i++) {
        constants[i] = chunk->constants[i];
    }
    info["constants"] = constants;

    Array instructions;
    int ip = 0;
    while (ip < chunk->code.size()) {
        uint8_t op = chunk->code[ip];
        Dictionary inst;
        inst["offset"] = ip;
        inst["opcode"] = op;
        inst["name"] = opcode_name(op);
        int line_number = (ip < chunk->lines.size()) ? chunk->lines[ip] : -1;
        inst["line"] = line_number;

        int operand_len = opcode_operand_length(op);
        Array operands;
        for (int i = 0; i < operand_len && (ip + 1 + i) < chunk->code.size(); i++) {
            operands.push_back((int)chunk->code[ip + 1 + i]);
        }
        inst["operands"] = operands;
        inst["detail"] = describe_operands(op, operands, chunk, ip);
        instructions.push_back(inst);

        ip += 1 + operand_len;
    }

    info["instructions"] = instructions;
    return info;
}
