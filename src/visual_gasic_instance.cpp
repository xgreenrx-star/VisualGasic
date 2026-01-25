#include <godot_cpp/classes/file_dialog.hpp>
#include <godot_cpp/classes/tween.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/area2d.hpp>
#include <godot_cpp/classes/collision_shape2d.hpp>
#include <godot_cpp/classes/rectangle_shape2d.hpp>
#include <godot_cpp/classes/circle_shape2d.hpp>
#include <godot_cpp/classes/timer.hpp>
#include <godot_cpp/classes/menu_button.hpp>
#include <godot_cpp/classes/popup_menu.hpp>
#include <godot_cpp/classes/h_box_container.hpp>
#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/base_button.hpp>
#include <godot_cpp/classes/line_edit.hpp>

// New Includes for Runtime Features
#include <godot_cpp/classes/accept_dialog.hpp>
#include <godot_cpp/classes/confirmation_dialog.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/time.hpp>

#include "visual_gasic_instance.h"
#include "visual_gasic_language.h"
#include "visual_gasic_parser.h" // For parsing data values at runtime
#include "visual_gasic_builtins.h"
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/godot.hpp> // For gde_interface and typdefs

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/config_file.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/sprite2d.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/canvas_item.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/theme_db.hpp>
#include <godot_cpp/classes/theme.hpp>
#include <godot_cpp/classes/gpu_particles2d.hpp>
#include <godot_cpp/classes/gpu_particles3d.hpp>
#include <godot_cpp/classes/particle_process_material.hpp>
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/classes/sprite3d.hpp>
#include <godot_cpp/classes/texture3d.hpp>
#include "gasic_ai_controller.h"
#include <godot_cpp/classes/character_body2d.hpp>
#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/collision_shape2d.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/circle_shape2d.hpp>
#include <godot_cpp/classes/sphere_shape3d.hpp>
#include <godot_cpp/classes/kinematic_collision2d.hpp>
#include <godot_cpp/classes/kinematic_collision3d.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/timer.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/box_mesh.hpp>
#include <godot_cpp/classes/sphere_mesh.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/classes/rigid_body2d.hpp>
#include <godot_cpp/classes/rigid_body3d.hpp>
#include <godot_cpp/classes/tween.hpp>
#include <godot_cpp/classes/property_tweener.hpp>
#include <godot_cpp/classes/progress_bar.hpp>
#include <godot_cpp/classes/h_slider.hpp>
#include <godot_cpp/classes/v_slider.hpp>
#include <godot_cpp/classes/text_edit.hpp>
#include <godot_cpp/classes/item_list.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/tree_item.hpp>
#include "visual_gasic_comm.h"




// Helper to access protected _owner of Object
class AccessObject : public Object {
public:
    static GDExtensionObjectPtr get_internal_ptr(Object *obj) {
        return obj ? ((AccessObject*)obj)->_owner : nullptr;
    }
};

VisualGasicInstance::VisualGasicInstance(Ref<VisualGasicScript> p_script, Object *p_owner) {
    script = p_script;
    owner = p_owner;
    error_state.mode = ErrorState::NONE;
    error_state.has_error = false;
    current_sub = nullptr;
    jump_target = -1;
    data_pointer = 0;
    
    option_compare_text = false;
    if (script.is_valid() && script->ast_root) {
        option_compare_text = script->ast_root->option_compare_text;
    }

    // Initialize Err Object
    Dictionary err_obj;
    err_obj["Number"] = 0;
    err_obj["Description"] = "";
    err_obj["Source"] = "";
    variables["Err"] = err_obj;

    // --- Global Constants (VB6 Style) ---
    // Colors
    variables["vbRed"] = Color(1, 0, 0);
    variables["vbGreen"] = Color(0, 1, 0);
    variables["vbBlue"] = Color(0, 0, 1);
    variables["vbBlack"] = Color(0, 0, 0);
    variables["vbWhite"] = Color(1, 1, 1);
    variables["vbYellow"] = Color(1, 1, 0);
    variables["vbCyan"] = Color(0, 1, 1);
    variables["vbMagenta"] = Color(1, 0, 1);
    
    // Keys (Mapped to Godot Key Enum values roughly)
    variables["vbKeyReturn"] = (int)Key::KEY_ENTER;
    variables["vbKeyEnter"] = (int)Key::KEY_ENTER;
    variables["vbKeySpace"] = (int)Key::KEY_SPACE;
    variables["vbKeyEscape"] = (int)Key::KEY_ESCAPE;
    variables["vbKeyUp"] = (int)Key::KEY_UP;
    variables["vbKeyDown"] = (int)Key::KEY_DOWN;
    variables["vbKeyLeft"] = (int)Key::KEY_LEFT;
    variables["vbKeyRight"] = (int)Key::KEY_RIGHT;
    
    // MsgBox
    variables["vbOK"] = 1;
    variables["vbCancel"] = 2;
    
    // Strings
    variables["vbTab"] = "\t";
    variables["vbCr"] = "\r";
    variables["vbLf"] = "\n";
    variables["vbCrLf"] = "\r\n";
    variables["vbNullString"] = "";

    // MSComm Constants
    variables["comNone"] = 0;
    variables["comXOnXOff"] = 1;
    variables["comRTS"] = 2;
    variables["comRTSXOnXOff"] = 3;

    // Initialize Global Variables from Script
    if (script.is_valid()) {
        VisualGasicScript *vs = Object::cast_to<VisualGasicScript>(script.ptr());
        if (vs && vs->ast_root) {
            // Module-level Variables
            // Note: Parser stores module level Dims in 'variables' (VariableDefinition) 
            // BUT parser.h says parse_program calls parse_statement... 
            // If they are Dims, they might be in global_statements as DimStatement?
            // Let's check ModuleNode struct again.
            // struct ModuleNode { Vector<VariableDefinition*> variables; ... }
            
            // If the parser separates Declared vars into 'variables', use that.
            // If it keeps them as STMT_DIM in global_statements, execute those.
            
            // Assuming Parser populates `variables` for explicit definitons:
            // (Current Parser implementation detail: It might put them in global_statements if not strictly separated)
            // But let's check AST if variables is used.
            // For now, let's try to Execute Global Statements (which includes DIMs).
            
            for(int i=0; i<vs->ast_root->variables.size(); i++) {
                 VariableDefinition *v = vs->ast_root->variables[i];
                 // Initialize to Correct Type
                 String t = v->type.to_lower();
                 if (t == "integer" || t == "long") variables[v->name] = (int)0;
                 else if (t == "single" || t == "double") variables[v->name] = (float)0.0;
                 else if (t == "string") variables[v->name] = "";
                 else if (t == "boolean") variables[v->name] = false;
                 else variables[v->name] = Variant(); // Init to Empty (Nil)
                 
                 UtilityFunctions::print("Initialized Global Var: ", v->name);
            }
            
            // Also execute global statements (like Dims not captured in definitions, or Options)
            // Warning: Don't execute imperative code here if untrusted? 
            // Basic usually has static declarative section.
            for(int i=0; i<vs->ast_root->global_statements.size(); i++) {
                Statement *stmt = vs->ast_root->global_statements[i];
                if (stmt->type == STMT_DIM) {
                     execute_statement(stmt);
                     DimStatement* ds = (DimStatement*)stmt;
                     UtilityFunctions::print("Executed Global Dim: ", ds->variable_name);
                }
                else if (stmt->type == STMT_CONST) {
                     execute_statement(stmt);
                }
            }
        }
    }

    // Auto-Enable Processing
    if (owner && script.is_valid()) {
        Node* node = Object::cast_to<Node>(owner);
        if (node) {
             UtilityFunctions::print("Checking process for node: ", node->get_name());
             
             // Check via AST directly to avoid has_method virtual dispatch issues
             bool has_process = false;
             bool has_physics = false;
             bool has_input = false;
             
             VisualGasicScript *vs = Object::cast_to<VisualGasicScript>(script.ptr());
             if (vs && vs->ast_root) {
                 for(int i=0; i<vs->ast_root->subs.size(); i++) {
                     String n = vs->ast_root->subs[i]->name;
                     if (n.nocasecmp_to("_Process") == 0) has_process = true;
                     if (n.nocasecmp_to("_PhysicsProcess") == 0) has_physics = true;
                     if (n.nocasecmp_to("_Input") == 0) has_input = true;
                 }
             }

             if (has_process) {
                 UtilityFunctions::print("VisualGasic: Enabling Process for ", node->get_name());
                 node->set_process(true);
             }
             
             if (has_physics) node->set_physics_process(true);
             if (has_input) node->set_process_input(true);
        } else {
             UtilityFunctions::print("VisualGasic: Owner is NOT a Node");
        }
    }

    // Initialize Struct Prototypes
    if (script.is_valid() && script->ast_root != nullptr) {
        
        // Initialize Global Constants
        for(int i=0; i<script->ast_root->constants.size(); i++) {
            ConstStatement* c = script->ast_root->constants[i];
            Variant val = evaluate_expression(c->value);
            variables[c->name] = val;
        }

        // Initialize Enums (as global constants)
        for(int i=0; i<script->ast_root->enums.size(); i++) {
             EnumDefinition* ed = script->ast_root->enums[i];
             // Register each member as global variable (constant)
             // We could also do EnumName_Member or just Member
             // For now, simple Member name (traditional Basic)
             for(int m=0; m<ed->values.size(); m++) {
                 variables[ed->values[m].name] = ed->values[m].value;
                 // Also register EnumName.Member?
                 // That would require a Dictionary for the enum itself?
                 // Let's do both if helpful, or just flat for now.
                 // Flat is safer for now.
             }
        }

        struct ProtoBuilder {
             ModuleNode* module;
             Dictionary cache;
             Vector<String> processing;
             
             Variant get_proto(String name) {
                 if (cache.has(name)) return cache[name];
                 
                 StructDefinition* def = nullptr;
                 for(int i=0; i<module->structs.size(); i++) {
                     if (module->structs[i]->name.nocasecmp_to(name) == 0) {
                         def = module->structs[i];
                         break;
                     }
                 }
                 
                 if (!def) return Variant(); 
                 
                 if (processing.has(name)) {
                      UtilityFunctions::print("Error: Recursive struct definition in ", name);
                      return Variant();
                 }
                 
                 processing.push_back(name);
                 
                 Dictionary dict;
                 for(int i=0; i<def->members.size(); i++) {
                     String mname = def->members[i].name;
                     String mtype = def->members[i].type;
                     
                     // UtilityFunctions::print("ProtoBuilder: Processing member ", mname, " of type ", mtype);

                     if (mtype.nocasecmp_to("Integer") == 0 || mtype.nocasecmp_to("Long") == 0) dict[mname] = 0;
                     else if (mtype.nocasecmp_to("String") == 0) dict[mname] = "";
                     else if (mtype.nocasecmp_to("Single") == 0 || mtype.nocasecmp_to("Double") == 0) dict[mname] = 0.0;
                     else {
                         Variant sub = get_proto(mtype);
                         if (sub.get_type() == Variant::DICTIONARY) {
                             dict[mname] = ((Dictionary)sub).duplicate(true);
                         } else {
                             dict[mname] = Variant(); 
                         }
                     }
                 }
                 
                 processing.erase(name);
                 cache[name] = dict;
                 return dict;
             }
        };
        
        ProtoBuilder builder;
        builder.module = script->ast_root;
        
        for(int i=0; i<script->ast_root->structs.size(); i++) {
             String name = script->ast_root->structs[i]->name;
             struct_prototypes[name] = builder.get_proto(name);
        }

        // Initialize Data Segments
        scan_data_sections(script->ast_root);
    }
}

void VisualGasicInstance::scan_data_sections(ModuleNode* root) {
    if (!root) return;

    data_segments.clear();
    label_to_data_index.clear();

    // Scan Subs (and Functions which are now subtypes of Subs)
    for(int i=0; i<root->subs.size(); i++) {
        collect_data_from_block(root->subs[i]->statements);
    }
    
    // Scan Global Statements (Data/Labels)
    collect_data_from_block(root->global_statements);
}

void VisualGasicInstance::collect_data_from_block(const Vector<Statement*>& block) {
    for(int i=0; i<block.size(); i++) {
        Statement* s = block[i];
        if (s->type == STMT_DATA) {
            DataStatement* data = (DataStatement*)s;
            for(int k=0; k<data->values.size(); k++) {
                data_segments.push_back(data->values[k]);
            }
        }
        if (s->type == STMT_LABEL) {
            LabelStatement* label = (LabelStatement*)s;
            label_to_data_index[label->name] = data_segments.size();
        }
        
        // Recursive blocks (If, Do, Loop, For, Select, With)
        if (s->type == STMT_IF) {
            IfStatement* ifs = (IfStatement*)s;
            collect_data_from_block(ifs->then_branch);
            collect_data_from_block(ifs->else_branch);
        }
        if (s->type == STMT_FOR) collect_data_from_block(((ForStatement*)s)->body);
        if (s->type == STMT_WHILE) collect_data_from_block(((WhileStatement*)s)->body);
        if (s->type == STMT_DO) collect_data_from_block(((DoStatement*)s)->body);
        if (s->type == STMT_WITH) collect_data_from_block(((WithStatement*)s)->body);
        if (s->type == STMT_SELECT) {
            SelectStatement* sel = (SelectStatement*)s;
            for(int c=0; c<sel->cases.size(); c++) {
                collect_data_from_block(sel->cases[c]->body);
            }
        }
    }
}

VisualGasicInstance::~VisualGasicInstance() {
    for(int i=0; i<runtime_data_nodes.size(); i++) {
        if (runtime_data_nodes[i]) delete runtime_data_nodes[i];
    }
}

Variant VisualGasicInstance::evaluate_expression_for_builtins(ExpressionNode* expr) {
    return _evaluate_expression_impl(expr);
}

Variant VisualGasicInstance::file_lof(int file_num) {
    if (open_files.has(file_num)) {
        Ref<FileAccess> fa = open_files[file_num];
        if (fa.is_valid()) return fa->get_length();
    }
    return 0;
}

Variant VisualGasicInstance::file_loc(int file_num) {
    if (open_files.has(file_num)) {
        Ref<FileAccess> fa = open_files[file_num];
        if (fa.is_valid()) return fa->get_position();
    }
    return 0;
}

Variant VisualGasicInstance::file_eof(int file_num) {
    if (open_files.has(file_num)) {
        Ref<FileAccess> fa = open_files[file_num];
        if (fa.is_valid()) return fa->eof_reached();
    }
    return true;
}

int VisualGasicInstance::file_free(int range) {
    int start = 1;
    if (range == 1) start = 256;
    for (int i = start; i < start + 255; i++) {
        if (!open_files.has(i)) return i;
    }
    raise_error("Too many files open");
    return 0;
}

Variant VisualGasicInstance::file_len(const String &path) {
    Ref<FileAccess> fa = FileAccess::open(path, FileAccess::READ);
    if (fa.is_valid()) return fa->get_length();
    return 0;
}

Variant VisualGasicInstance::file_dir(const Array &args) {
    if (args.size() >= 1) {
        String path = args[0];
        String folder = path.get_base_dir();
        if (folder.is_empty()) folder = "res://";
        dir_pattern = path.get_file();
        if (dir_pattern.is_empty()) dir_pattern = "*";
        current_dir = DirAccess::open(folder);
        if (current_dir.is_valid()) {
            current_dir->list_dir_begin();
            String f = current_dir->get_next();
            while (!f.is_empty()) {
                if (f != "." && f != ".." && f.matchn(dir_pattern)) return f;
                f = current_dir->get_next();
            }
        }
        return String();
    } else {
        if (current_dir.is_valid()) {
            String f = current_dir->get_next();
            while (!f.is_empty()) {
                if (f != "." && f != ".." && f.matchn(dir_pattern)) return f;
                f = current_dir->get_next();
            }
        }
        return String();
    }
}

void VisualGasicInstance::randomize_seed() {
    UtilityFunctions::randomize();
}

void VisualGasicInstance::raise_runtime_error(const String &p_msg, int p_code) {
    raise_error(p_msg, p_code);
}

bool VisualGasicInstance::set(const StringName &p_name, const Variant &p_value) {
    if (variables.has(p_name)) {
        variables[p_name] = p_value;
        return true;
    }
    // Check if it is a public variable defined in script, but not yet initialized in variables map
    // (Though we should init them in constructor)
    
    if (script.is_valid() && script->ast_root) {
        for(int i=0; i<script->ast_root->variables.size(); i++) {
            if (script->ast_root->variables[i]->name == p_name) {
                 variables[p_name] = p_value;
                 return true;
            }
        }
    }
    return false;
}

bool VisualGasicInstance::get(const StringName &p_name, Variant &r_ret) {
    if (variables.has(p_name)) {
        r_ret = variables[p_name];
        return true;
    }
    return false;
}

// Retrieve a variable by name into r_ret. Returns true if found.
bool VisualGasicInstance::get_variable(const String &p_name, Variant &r_ret) {
    if (variables.has(p_name)) {
        r_ret = variables[p_name];
        return true;
    }
    return false;
}

// Wrapper that forwards statement-level builtin calls to the centralized builtins module.
void VisualGasicInstance::dispatch_builtin_call(const String &p_method, const Array &p_args, bool &r_found) {
    r_found = false;
    Variant dummy_ret;
    bool handled = false;
    if (VisualGasicBuiltins::call_builtin(this, p_method, p_args, dummy_ret, handled)) {
        r_found = handled;
        return;
    }
    r_found = false;
}

const GDExtensionPropertyInfo *VisualGasicInstance::get_property_list(uint32_t *r_count) {
    if (!script.is_valid() || !script->ast_root) {
        *r_count = 0;
        return nullptr;
    }
    
    // We only list PUBLIC variables here
    Vector<VariableDefinition*> public_vars;
    for(int i=0; i<script->ast_root->variables.size(); i++) {
        if (script->ast_root->variables[i]->visibility == VIS_PUBLIC) {
            public_vars.push_back(script->ast_root->variables[i]);
        }
    }
    
    *r_count = public_vars.size();
    if (*r_count == 0) return nullptr;
    
    GDExtensionPropertyInfo *list = (GDExtensionPropertyInfo *)memalloc(sizeof(GDExtensionPropertyInfo) * (*r_count));
    
    for(uint32_t i=0; i<*r_count; i++) {
        VariableDefinition* v = public_vars[i];
        String name = v->name;
        String type = v->type.to_lower();
        
        list[i].name = memnew(StringName(name)); // StringName* ? No, structure has void* name
        // Wait, GDExtensionPropertyInfo structure:
        // GDExtensionStringNamePtr name;
        // GDExtensionVariantType type;
        // GDExtensionStringNamePtr class_name;
        // GDExtensionPropertyHint hint;
        // GDExtensionStringPtr hint_string;
        // uint32_t usage;
        
        // This memory management is tricky. We need to allocate StringNames that persist?
        // Actually, usually we return a C array.
        // Godot explicitly calls free_property_list.
        
        // The GDExtension C API expects pointers to opaque types.
        // We must construct them.
        
        // name
        StringName *sn = memnew(StringName(name));
        list[i].name = sn;
        
        // type
        if (type == "integer") list[i].type = GDEXTENSION_VARIANT_TYPE_INT;
        else if (type == "single" || type == "double") list[i].type = GDEXTENSION_VARIANT_TYPE_FLOAT;
        else if (type == "string") list[i].type = GDEXTENSION_VARIANT_TYPE_STRING;
        else if (type == "boolean") list[i].type = GDEXTENSION_VARIANT_TYPE_BOOL;
        else list[i].type = GDEXTENSION_VARIANT_TYPE_NIL;
        
        // class_name
        list[i].class_name = memnew(StringName());
        
        // hint
        list[i].hint = PROPERTY_HINT_NONE;
        
        // hint_string
        list[i].hint_string = memnew(String());
        
        // usage
        list[i].usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE;
    }
    
    return list;
}

void VisualGasicInstance::free_property_list(const GDExtensionPropertyInfo *p_list, uint32_t p_count) {
    if (p_list) {
        for(uint32_t i=0; i<p_count; i++) {
             memdelete((StringName*)p_list[i].name);
             memdelete((StringName*)p_list[i].class_name);
             memdelete((String*)p_list[i].hint_string);
        }
        memfree((void*)p_list);
    }
}

Variant::Type VisualGasicInstance::get_property_type(const StringName &p_name, bool *r_is_valid) {
    *r_is_valid = false;
    return Variant::NIL;
}

bool VisualGasicInstance::validate_property(GDExtensionPropertyInfo *p_property) {
    return false;
}

bool VisualGasicInstance::property_can_revert(const StringName &p_name) {
    return false;
}

bool VisualGasicInstance::property_get_revert(const StringName &p_name, Variant &r_ret) {
    return false;
}

Object *VisualGasicInstance::get_owner() {
    return owner;
}

Ref<Script> VisualGasicInstance::get_script() {
    return script;
}

bool VisualGasicInstance::is_placeholder() {
    return false;
}

Variant VisualGasicInstance::evaluate_expression(ExpressionNode* expr) {
    if (!expr) return Variant();

    if (expr->type == ExpressionNode::EXPRESSION_IIF) {
        IIfNode* iif = (IIfNode*)expr;
        Variant cond = evaluate_expression(iif->condition);
        if (cond.booleanize()) {
            return evaluate_expression(iif->true_part);
        } else {
            return evaluate_expression(iif->false_part);
        }
    }

    if (expr->type == ExpressionNode::WITH_CONTEXT) {
        if (with_stack.is_empty()) {
            raise_error("Invalid use of .Member outside With block");
            return Variant();
        }
        return with_stack[with_stack.size() - 1]; // Top of stack
    }
    
    if (expr->type == ExpressionNode::LITERAL) {
        return ((LiteralNode*)expr)->value;
    }
    if (expr->type == ExpressionNode::ME) {
        if (!owner) return Variant(); // Or error?
        // Note: owner is Object*. Returning it as Variant usually works but requires safety?
        // Godot-cpp Variant constructor from Object* should handle it.
        return owner;
    }
    if (expr->type == ExpressionNode::NEW) {
        NewNode* n = (NewNode*)expr;
        
        // MemoryBlock -> PackedByteArray
        if (n->class_name.nocasecmp_to("MemoryBlock") == 0) {
            int size = 0;
            if (n->args.size() > 0) {
                 Variant v = evaluate_expression(n->args[0]);
                 size = (int)v;
            }
            PackedByteArray pba;
            pba.resize(size);
            return pba;
        }

        if (n->class_name.nocasecmp_to("Dictionary") == 0) {
            return Dictionary();
        }
        
        // Custom Structs or Types?
        // Check struct definitions
        if (script.is_valid() && script->ast_root) {
            for(int i=0; i<script->ast_root->structs.size(); i++) {
                if (script->ast_root->structs[i]->name.nocasecmp_to(n->class_name) == 0) {
                     // Instantiate Struct (Dictionary)
                     // Re-use ProtoBuilder logic? Or simple manual create
                     Dictionary d;
                     StructDefinition* def = script->ast_root->structs[i];
                     for(int m=0; m<def->members.size(); m++) {
                         // Default init
                         d[def->members[m].name] = Variant(); // Better defaults later
                     }
                     return d;
                }
            }
        }
        
        // Try Godot ClassDB
        if (ClassDB::class_exists(n->class_name)) {
             Object* obj = ClassDB::instantiate(n->class_name);
             if (obj) return obj;
        }

        return Variant(); 
    }

    if (expr->type == ExpressionNode::VARIABLE) {
        String name = ((VariableNode*)expr)->name;
        
        if (name.nocasecmp_to("FreeFile") == 0) {
             for(int i=1; i<=255; i++) {
                 if (!open_files.has(i)) return i;
             }
             raise_error("Too many files open");
             return 0;
        }

        if (name.nocasecmp_to("Godot") == 0) {
            // Return a special marker? Or can we return Engine?
            // Engine is an Object.
            return Engine::get_singleton();
        }
        
        if (variables.has(name)) return variables[name];
        
        // Debug
        // UtilityFunctions::print("Variable not found in map: ", name);
        // UtilityFunctions::print("Map Keys: ", variables.keys());
        
        // Property Access on Owner
        if (owner) {
             Variant ret = owner->get(name);
             if (ret.get_type() != Variant::NIL) return ret;

             // Fallback: snake_case
             String snake = name.to_snake_case();
             ret = owner->get(snake);
             if (ret.get_type() != Variant::NIL) return ret;
        }

        // Check Autoloads (Globals)
        if (owner) {
             Node* owner_node = Object::cast_to<Node>(owner);
             if (owner_node && owner_node->is_inside_tree()) {
                 SceneTree *tree = owner_node->get_tree();
                 if (tree) {
                     Node* root = tree->get_root();
                     if (root && root->has_node(name)) {
                         return root->get_node<Node>(name);
                     }
                 }
                 // Try PascalCase -> snake_case? Autoloads are usually PascalCase though.
             }
        }
        
        return Variant();
    }
    if (expr->type == ExpressionNode::MEMBER_ACCESS) {
         MemberAccessNode* ma = (MemberAccessNode*)expr;
         Variant base = evaluate_expression(ma->base_object);
         
         if (base.get_type() == Variant::DICTIONARY) {
             Dictionary d = base;
             if (d.has(ma->member_name)) return d[ma->member_name];
         }
         
         // Generic Variant Member Access (Object, Vector2, etc.)
         bool valid = false;
         Variant ret = base.get_named(ma->member_name, valid);
         if (valid && (ret.get_type() != Variant::NIL || base.has_method(ma->member_name))) return ret;
         
         // Try lowercase (for Vector2.X -> x)
         if (!valid) {
              ret = base.get_named(ma->member_name.to_lower(), valid);
              if (valid) return ret;
         }
         
         if (base.get_type() == Variant::OBJECT) {
             Object* obj = base;
             String prop_name = ma->member_name;
             
             // VB6 Property Aliasing (Read)
             if (obj) {
                  if (obj->is_class("Node")) {
                      if (prop_name == "Caption") prop_name = "text";
                      
                      if (obj->is_class("Timer")) {
                          if (prop_name == "Interval") {
                              return (double)obj->get("wait_time") * 1000.0;
                          }
                          if (prop_name == "Enabled") {
                              return !Object::cast_to<Timer>(obj)->is_stopped();
                          }
                      }
                      
                      bool is_control = obj->is_class("Control");
                      bool is_2d = obj->is_class("Node2D");
                      bool is_range = obj->is_class("Range");

                      if (is_range) {
                           if (prop_name == "Min") return obj->get("min_value");
                           if (prop_name == "Max") return obj->get("max_value");
                           if (prop_name == "Value") return obj->get("value");
                      }
                      
                      if (is_control || is_2d) {
                          if (prop_name == "Left") {
                               if (is_control) return Object::cast_to<Control>(obj)->get_position().x;
                               if (is_2d) return Object::cast_to<Node2D>(obj)->get_position().x;
                          }
                          if (prop_name == "Top") {
                               if (is_control) return Object::cast_to<Control>(obj)->get_position().y;
                               if (is_2d) return Object::cast_to<Node2D>(obj)->get_position().y;
                          }
                      }
                      if (is_control) {
                          if (prop_name == "Width") return Object::cast_to<Control>(obj)->get_size().x;
                          if (prop_name == "Height") return Object::cast_to<Control>(obj)->get_size().y;
                          if (prop_name == "Visible") return Object::cast_to<Control>(obj)->is_visible();
                          
                          if (obj->is_class("Tree")) {
                               if (prop_name == "Rows") {
                                   Tree *t = Object::cast_to<Tree>(obj);
                                   return t->get_root() ? t->get_root()->get_child_count() : 0;
                               }
                               if (prop_name == "Cols") {
                                   return Object::cast_to<Tree>(obj)->get_columns();
                               }
                          }
                      }
                  }
             }

             if (obj) {
                 Variant val = obj->get(prop_name);
                 if (val.get_type() != Variant::NIL) return val;
                 
                 String snake = prop_name.to_snake_case();
                 val = obj->get(snake);
                 if (val.get_type() != Variant::NIL) return val;
             }
         }
         
         return Variant();
    }

    if (expr->type == ExpressionNode::ARRAY_ACCESS) {
         ArrayAccessNode* aa = (ArrayAccessNode*)expr;
         Variant base = evaluate_expression(aa->base);
         
         if (base.get_type() == Variant::DICTIONARY) {
             Dictionary d = base;
             if (aa->indices.size() > 0) {
                 Variant key = evaluate_expression(aa->indices[0]);
                 if (d.has(key)) return d[key];
                 return Variant(); // Or error?
             }
         }

         if (base.get_type() == Variant::ARRAY) {
             Variant container = base;
             for(int i=0; i<aa->indices.size(); i++) {
                 if (container.get_type() != Variant::ARRAY) return Variant();
                 Array arr = container;
                 int idx = evaluate_expression(aa->indices[i]);
                 if (idx >= 0 && idx < arr.size()) {
                     container = arr[idx];
                 } else {
                     raise_error("Subscript out of range");
                     return Variant();
                 }
             }
             return container;
         }
         
         if (aa->base->type == ExpressionNode::VARIABLE) {
             String func_name = ((VariableNode*)aa->base)->name;
             Array call_args; 
             for(int i=0; i<aa->indices.size(); i++) call_args.push_back(evaluate_expression(aa->indices[i]));
             
             bool found = false;
             Variant v_ret = call_internal(func_name, call_args, found);
             if (found) return v_ret;

             if (owner) {
                 if (owner->has_method(func_name)) return owner->callv(func_name, call_args);
                 String snake = func_name.to_snake_case();
                 if (owner->has_method(snake)) return owner->callv(snake, call_args);
             }
             
             if (func_name == "Len" && call_args.size() == 1) return String(call_args[0]).length();
             if (func_name == "Left" && call_args.size() == 2) return String(call_args[0]).left(call_args[1]);
             if (func_name == "Right" && call_args.size() == 2) return String(call_args[0]).right(call_args[1]);
             if (func_name == "Mid" && call_args.size() >= 2) {
                  String s = call_args[0]; int st = (int)call_args[1]-1; if(st<0)st=0; 
                  return (call_args.size()==3)?s.substr(st,call_args[2]):s.substr(st);
             }
             if (func_name == "InStr" && call_args.size() == 2) {
                 String s1 = call_args[0]; String s2 = call_args[1]; int pos = s1.find(s2);
                 return (pos == -1) ? 0 : pos + 1;
             }
             if (func_name == "Replace" && call_args.size() == 3) return String(call_args[0]).replace(call_args[1], call_args[2]);
             if (func_name == "UCase" && call_args.size() == 1) return String(call_args[0]).to_upper();
             if (func_name == "LCase" && call_args.size() == 1) return String(call_args[0]).to_lower();
             if (func_name == "Trim" && call_args.size() == 1) return String(call_args[0]).strip_edges();
             if (func_name == "StrReverse" && call_args.size() == 1) {
                  String s = call_args[0]; String res=""; for(int i=s.length()-1; i>=0; i--) res+=s[i]; return res;
             }
             
             if (func_name == "CType" && call_args.size() == 2) {
                 Variant val = call_args[0];
                 String type_name = String(call_args[1]).to_lower();
                 
                 if (type_name == "integer" || type_name == "int") return (int)val;
                 if (type_name == "long") return (int64_t)val;
                 if (type_name == "float" || type_name == "double" || type_name == "single") return (double)val;
                 if (type_name == "string") return String(val);
                 if (type_name == "boolean" || type_name == "bool") return (bool)val;
                 return val; 
             }
             if (func_name == "CInt" && call_args.size() == 1) return (int)call_args[0];
             if (func_name == "CLng" && call_args.size() == 1) return (int64_t)call_args[0];
             if (func_name == "CDbl" && call_args.size() == 1) return (double)call_args[0];
             if (func_name == "CStr" && call_args.size() == 1) return String(call_args[0]);
             if (func_name == "CBool" && call_args.size() == 1) return (bool)call_args[0];

             if (func_name.nocasecmp_to("Array") == 0) {
                 return call_args; 
             }
             // TwinBasic / Extended String Functions
             if (func_name == "Split" && call_args.size() >= 2) {
                 String s = call_args[0];
                 String delim = call_args[1];
                 PackedStringArray psa = s.split(delim);
                 Array ret;
                 for(int i=0; i<psa.size(); i++) ret.push_back(psa[i]);
                 return ret;
             }
             if (func_name == "Join" && call_args.size() >= 1) {
                 Variant source = call_args[0];
                 String delim = (call_args.size() >= 2) ? (String)call_args[1] : " ";
                 if (source.get_type() == Variant::ARRAY) {
                     Array arr = source;
                     String res = "";
                     for(int i=0; i<arr.size(); i++) {
                         if(i>0) res += delim;
                         res += String(arr[i]);
                     }
                     return res;
                 }
                 else if (source.get_type() == Variant::PACKED_STRING_ARRAY) {
                     PackedStringArray psa = source;
                     String res = "";
                     for(int i=0; i<psa.size(); i++) {
                         if(i>0) res += delim;
                         res += psa[i];
                     }
                     return res;
                 }
                 return "";
             }
             if (func_name == "Asc" && call_args.size() == 1) {
                 String s = call_args[0];
                 if (s.length() > 0) return (int)s.unicode_at(0);
                 return 0;
             }
             if (func_name == "Chr" && call_args.size() == 1) {
                 return String::chr((int)call_args[0]);
             }
             if (func_name == "Space" && call_args.size() == 1) {
                 int count = (int)call_args[0];
                 String s = "";
                 for(int i=0; i<count; i++) s += " ";
                 return s;
             }
             
             if (func_name == "WeakRef" && call_args.size() == 1) {
                 return UtilityFunctions::weakref(call_args[0]);
             }
             
             // Array Helpers
             if (func_name == "UBound" && call_args.size() >= 1) {
                 Variant v = call_args[0];
                 if (v.get_type() == Variant::ARRAY) return ((Array)v).size() - 1;
                 if (v.get_type() == Variant::PACKED_STRING_ARRAY) return ((PackedStringArray)v).size() - 1;
                 return -1; 
             }
             if (func_name == "LBound" && call_args.size() >= 1) {
                 return 0; // Always 0 base
             }

             // Math Helpers
             if (func_name == "Int" && call_args.size() == 1) return floor((double)call_args[0]);
             if (func_name == "Abs" && call_args.size() == 1) return abs((double)call_args[0]);
             if (func_name == "Rnd" && (call_args.size() == 0 || call_args.size() == 1)) return UtilityFunctions::randf();
             
             // Formatting
             if (func_name == "Format" && call_args.size() == 2) {
                 Variant val = call_args[0];
                 String fmt = call_args[1];
                 // Simple mapping: if fmt contains %, assume sprintf style.
                 if (fmt.contains("%")) {
                     Array a; a.push_back(val);
                     return fmt % a;
                 } 
                 // Else if "General Number" or standard VB formats, we simplify to String(val) for now or basic rounding
                 if (fmt == "Percent") return String::num(val, 2) + "%";
                 if (fmt == "Currency") return "$" + String::num(val, 2);
                 return String(val); // Fallback
             }

             // Dynamic Control Access
             if (func_name == "GetControl" && call_args.size() == 1) {
                 String name = call_args[0];
                 if (owner) {
                     Node *n = Object::cast_to<Node>(owner);
                     if (n) {
                         Node *found = n->find_child(name, true, false);
                         if (found) return found;
                     }
                 }
                 return Variant();
             }

             // Multimedia
             if (func_name == "LoadPicture" && call_args.size() == 1) {
                 String path = call_args[0];
                 if (!path.begins_with("res://") && !path.begins_with("user://")) path = "res://" + path;
                 return ResourceLoader::get_singleton()->load(path);
             }
             
             // Persistence Functions
             if (func_name == "GetSetting" && call_args.size() >= 3) {
                 String app = call_args[0];
                 String section = call_args[1];
                 String key = call_args[2];
                 Variant def_val = (call_args.size() >= 4) ? call_args[3] : Variant();
                 
                 Ref<ConfigFile> cfg;
                 cfg.instantiate();
                 String path = "user://vb_settings.cfg";
                 if (cfg->load(path) == OK) {
                     String real_section = app + "/" + section;
                     return cfg->get_value(real_section, key, def_val);
                 }
                 return def_val;
             }
             
             // Database Functions
             if (func_name == "OpenDatabase" && call_args.size() == 1) {
                 String path = call_args[0];
                 if (!path.begins_with("res://") && !path.begins_with("user://")) path = "user://" + path;
                 
                 Ref<FileAccess> f = FileAccess::open(path, FileAccess::READ);
                 if (f.is_valid()) {
                     Ref<JSON> json;
                     json.instantiate();
                     if (json->parse(f->get_as_text()) == OK) return json->get_data();
                     else raise_error("JSON Parse Error in database: " + path);
                 } else {
                     raise_error("Database file not found: " + path);
                 }
                 return Dictionary(); 
             }
             
             // InputBox Implementation
             if (func_name == "InputBox") {
                 String prompt = "";
                 if (call_args.size() > 0) prompt = call_args[0];
                 String title = "VisualGasic";
                 if (call_args.size() > 1) title = call_args[1];
                 String def = "";
                 if (call_args.size() > 2) def = call_args[2];

                 if (!owner || !Object::cast_to<Node>(owner)) {
                      return def;
                 }
                 Node *root = Object::cast_to<Node>(owner);
                 
                 AcceptDialog *dialog = memnew(AcceptDialog);
                 dialog->set_title(title);
                 
                 VBoxContainer *vbox = memnew(VBoxContainer);
                 Label *lbl = memnew(Label);
                 lbl->set_text(prompt);
                 vbox->add_child(lbl);
                 
                 LineEdit *le = memnew(LineEdit);
                 le->set_text(def);
                 vbox->add_child(le);
                 
                 dialog->add_child(vbox);
                 root->add_child(dialog);
                 
                 // Signal Magic: Connect 'confirmed' to set_meta('result_ok', true) on the dialog itself
                 dialog->set_meta("result_ok", false);
                 dialog->connect("confirmed", Callable(dialog, "set_meta").bind("result_ok", true));
                 
                 dialog->popup_centered();
                 le->grab_focus();
                 le->select_all();
                 
                 while (dialog->is_visible() && dialog->is_inside_tree()) {
                      DisplayServer::get_singleton()->process_events();
                      OS::get_singleton()->delay_msec(10);
                 }
                 
                 String result = "";
                 if ((bool)dialog->get_meta("result_ok")) {
                      result = le->get_text();
                 }
                 
                 dialog->queue_free();
                 return result;
             }
         }
         return Variant();
    }

    if (expr->type == ExpressionNode::EXPRESSION_CALL) {
        CallExpression* call = (CallExpression*)expr;
        
        // Delegate to centralized expression-level builtins first (they may evaluate arguments themselves)
        {
            bool _bg_handled = false;
            Variant _bg_res = VisualGasicBuiltins::call_builtin_expr(this, call, _bg_handled);
            if (_bg_handled) return _bg_res;
        }

        Array call_args;
        for(int i=0; i<call->arguments.size(); i++) {
            call_args.push_back(evaluate_expression(call->arguments[i]));
        }
        if (call->method_name.nocasecmp_to("CreateNode") == 0) {
             // Debug 
             // UtilityFunctions::print("DEBUG: Handling Call: ", call->method_name);
        }

        if (call->method_name.nocasecmp_to("Vector2") == 0 && call_args.size() == 2) {
             return Vector2(call_args[0], call_args[1]);
        }
        if (call->method_name.nocasecmp_to("TweenProperty") == 0 && call_args.size() == 4) {
             Object *obj = call_args[0];
             String prop = call_args[1];
             Variant final_val = call_args[2];
             double duration = call_args[3];
             if (obj && owner) {
                  Node *n = Object::cast_to<Node>(owner);
                  if (n) {
                       Ref<Tween> t = n->create_tween();
                       t->tween_property(obj, NodePath(prop), final_val, duration);
                       return t;
                  }
             }
             return Variant();
        }

        if (call->base_object) {
            // If base is a simple variable (eg. Clipboard) let builtins handle it first
            if (call->base_object->type == ExpressionNode::VARIABLE) {
                String var_name = ((VariableNode*)call->base_object)->name;
                Variant br;
                if (VisualGasicBuiltins::call_builtin_for_base_variable(this, var_name, call->method_name, call_args, br)) {
                    return br;
                }
            }

            Variant base = evaluate_expression(call->base_object);
            Variant br;
            if (VisualGasicBuiltins::call_builtin_for_base_variant(this, base, call->method_name, call_args, br)) {
                return br;
            }

            // Fallback: object method call (try direct, snake_case, or callp fallback)
            if (base.get_type() == Variant::OBJECT) {
                Object* obj = base;
                if (obj) {
                    if (obj->has_method(call->method_name)) return obj->callv(call->method_name, call_args);
                    String snake = call->method_name.to_snake_case();
                    if (obj->has_method(snake)) return obj->callv(snake, call_args);
                }
            }

             // Fallback for Variant types (Structs like Rect2, Vector2, etc.)
             if (base.get_type() != Variant::OBJECT && base.get_type() != Variant::NIL) {
                 String method_to_call = "";
                 if (base.has_method(call->method_name)) {
                     method_to_call = call->method_name;
                 } else {
                     String snake = call->method_name.to_snake_case();
                     if (base.has_method(snake)) {
                         method_to_call = snake;
                     }
                 }
                 
                 if (!method_to_call.is_empty()) {
                     GDExtensionCallError err;
                     Variant res;
                     
                     // Helper to manage arguments pointers
                     // We need to copy arguments to a stable container to take their addresses
                     Vector<Variant> args_store;
                     args_store.resize(call_args.size());
                     Variant *args_w = args_store.ptrw();

                     Vector<const Variant*> arg_ptrs;
                     arg_ptrs.resize(call_args.size());
                     const Variant **ptrs_w = arg_ptrs.ptrw();
                     
                     for(int i=0; i<call_args.size(); i++) {
                         args_w[i] = call_args[i];
                         ptrs_w[i] = &args_w[i];
                     }
                     
                     base.callp(method_to_call, ptrs_w, call_args.size(), res, err);
                     return res;
                 }
             }
        }

        // Check if it is an array access
        if (variables.has(call->method_name)) {
            Variant v = variables[call->method_name];
            bool is_array = (v.get_type() == Variant::ARRAY);
            bool is_packed = (v.get_type() >= Variant::PACKED_BYTE_ARRAY && v.get_type() <= Variant::PACKED_COLOR_ARRAY); // Range check for packed arrays?
            
            if (is_array) {
                // Multidimensional Read (Recursive for generic Array)
                Variant current = v;
                bool fail = false;
                for(int i=0; i<call_args.size(); i++) {
                    if (current.get_type() != Variant::ARRAY) {
                         fail = true; break;
                    }
                    Array arr = current;
                    int idx = call_args[i];
                    if (idx >= 0 && idx < arr.size()) {
                        current = arr[idx];
                    } else {
                        raise_error("Array subscript out of range");
                        return Variant();
                    }
                }
                if (!fail) return current;
            } else if (is_packed) {
                 // Single dimension access for Packed Arrays usually
                 if (call_args.size() == 1) {
                      int idx = call_args[0];
                      // Use Variant indexing
                      bool valid = false;
                      bool oob = false;
                      Variant res = v.get_indexed(idx, valid, oob);
                      if (oob) {
                          raise_error("Array subscript out of range");
                          return Variant();
                      }
                      if (valid) return res;
                 }
            } else if (v.get_type() == Variant::DICTIONARY) {
                Dictionary d = v;
                if (call_args.size() == 1) {
                    Variant key = call_args[0];
                    if (d.has(key)) return d[key];
                    return Variant();
                }
            }
        }

        // Built-in Connect function
        if (call->method_name == "Connect") {
             if (owner) {
                 if (call_args.size() == 2) {
                     String signal = call_args[0];
                     String method = call_args[1];
                     Callable callable = Callable(owner, method);
                     Error err = owner->connect(signal, callable);
                     return (int)err;
                 } else if (call_args.size() == 3) {
                     Object *source = call_args[0];
                     String signal = call_args[1];
                     String method = call_args[2];
                     if (source) {
                         Callable callable = Callable(owner, method);
                         Error err = source->connect(signal, callable);
                         return (int)err;
                     }
                 }
             }
        }
        
        // Expression-level builtins (strings, array helpers, file/dir, math, etc.)
        // are delegated to VisualGasicBuiltins::call_builtin_expr /
        // call_builtin_expr_evaluated earlier. This avoids duplicate
        // implementations here and keeps logic centralized.
        if (call->method_name.nocasecmp_to("Shell") == 0 && call_args.size() >= 1) {
             String cmd_line = call_args[0];
             // Parse command line (EXE + Args) VB6 Style
             String exe = "";
             Array args;
             
             int i = 0;
             while(i < cmd_line.length() && cmd_line[i] == ' ') i++;
             
             // Extract Exe
             if (i < cmd_line.length()) {
                 if (cmd_line[i] == '"') {
                     i++; // skip quote
                     while(i < cmd_line.length() && cmd_line[i] != '"') {
                         exe += cmd_line[i]; i++;
                     }
                     i++; // skip closing quote
                 } else {
                     while(i < cmd_line.length() && cmd_line[i] != ' ') {
                         exe += cmd_line[i]; i++;
                     }
                 }
             }
             
             // Extract Args
             while(i < cmd_line.length()) {
                  while(i < cmd_line.length() && cmd_line[i] == ' ') i++; 
                  if (i >= cmd_line.length()) break;
                  
                  String arg = "";
                  if (cmd_line[i] == '"') {
                       i++;
                       while(i < cmd_line.length() && cmd_line[i] != '"') {
                            arg += cmd_line[i]; i++;
                       }
                       i++;
                  } else {
                       while(i < cmd_line.length() && cmd_line[i] != ' ') {
                            arg += cmd_line[i]; i++;
                       }
                  }
                  args.push_back(arg);
             }
             
             return OS::get_singleton()->execute(exe, args);
        }

        // --- New Helpers ---
        if (call->method_name.nocasecmp_to("Sleep") == 0 && call_args.size() == 1) {
             int ms = (int)call_args[0];
             OS::get_singleton()->delay_msec(ms);
             return Variant();
        }
        if (call->method_name.nocasecmp_to("TypeName") == 0 && call_args.size() == 1) {
             Variant v = call_args[0];
             switch(v.get_type()) {
                 case Variant::NIL: return "Nothing";
                 case Variant::BOOL: return "Boolean";
                 case Variant::INT: return "Integer";
                 case Variant::FLOAT: return "Double";
                 case Variant::STRING: return "String";
                 case Variant::VECTOR2: return "Vector2";
                 case Variant::VECTOR3: return "Vector3";
                 case Variant::COLOR: return "Color";
                 case Variant::OBJECT: {
                     Object *obj = v;
                     if (obj) return obj->get_class();
                     return "Nothing";
                 } 
                 case Variant::DICTIONARY: return "Dictionary";
                 case Variant::ARRAY: return "Array";
                 default: return "Object"; // Simplified
             }
        }
        if (call->method_name.nocasecmp_to("IsNumeric") == 0 && call_args.size() == 1) {
             Variant v = call_args[0];
             if (v.get_type() == Variant::INT || v.get_type() == Variant::FLOAT) return true;
             if (v.get_type() == Variant::STRING) return String(v).is_valid_float();
             return false;
        }
        if (call->method_name.nocasecmp_to("IsObject") == 0 && call_args.size() == 1) {
             return call_args[0].get_type() == Variant::OBJECT || call_args[0].get_type() == Variant::NIL; 
        }
        if (call->method_name.nocasecmp_to("IsArray") == 0 && call_args.size() == 1) {
             Variant::Type t = call_args[0].get_type();
             return t == Variant::ARRAY || (t >= Variant::PACKED_BYTE_ARRAY && t <= Variant::PACKED_COLOR_ARRAY);
        }
        if (call->method_name.nocasecmp_to("Round") == 0 && call_args.size() >= 1) {
             double val = (double)call_args[0];
             if (call_args.size() > 1) {
                 int digits = (int)call_args[1];
                 double step = pow(10.0, -digits);
                 return Math::snapped(val, step);
             }
             return round(val);
        }
        if (call->method_name.nocasecmp_to("RandRange") == 0 && call_args.size() == 2) {
             float min = (float)call_args[0];
             float max = (float)call_args[1];
             return min + UtilityFunctions::randf() * (max - min);
        }
        if (call->method_name.nocasecmp_to("CInt") == 0 && call_args.size() == 1) return (int)round((double)call_args[0]);
        if (call->method_name.nocasecmp_to("CDbl") == 0 && call_args.size() == 1) return (double)call_args[0];
        if (call->method_name.nocasecmp_to("CBool") == 0 && call_args.size() == 1) return (bool)call_args[0];

        // --- GAP FILLERS ---
        if (call->method_name.nocasecmp_to("Lerp") == 0 && call_args.size() == 3) {
             double a = call_args[0];
             double b = call_args[1];
             double t = call_args[2];
             return Math::lerp(a, b, t);
        }
        if (call->method_name.nocasecmp_to("Clamp") == 0 && call_args.size() == 3) {
             double val = call_args[0];
             double min = call_args[1];
             double max = call_args[2];
             return Math::clamp(val, min, max);
        }
        if (call->method_name.nocasecmp_to("FileLen") == 0 && call_args.size() == 1) {
             String path = call_args[0];
             Ref<FileAccess> fa = FileAccess::open(path, FileAccess::READ);
             if (fa.is_valid()) return fa->get_length();
             return 0;
        }
        if (call->method_name.nocasecmp_to("Dir") == 0) {
             if (call_args.size() >= 1) {
                  // Dir(path, [attr]) - Start Iteration
                  String path = call_args[0];
                  
                  String folder = path.get_base_dir();
                  // If path is just "*.txt", base_dir might be empty, defaulting to valid res:// or user:// root? 
                  // In Godot, empty base dir of relative path depends on context. 
                  // Let's assume absolute paths or relative to res:// if not specified? 
                  // But standard DirAccess::open works with "res://".
                  if (folder.is_empty()) folder = "res://";
                  
                  dir_pattern = path.get_file();
                  if (dir_pattern.is_empty()) dir_pattern = "*"; // Default to all if folder only?
                  
                  current_dir = DirAccess::open(folder);
                  if (current_dir.is_valid()) {
                       current_dir->list_dir_begin(); 
                       String f = current_dir->get_next();
                       while (!f.is_empty()) {
                            if (f != "." && f != ".." && f.matchn(dir_pattern)) {
                                 return f;
                            }
                            f = current_dir->get_next();
                       }
                  }
                  return "";
             } else {
                  // Dir() - Next
                  if (current_dir.is_valid()) {
                       String f = current_dir->get_next();
                       while (!f.is_empty()) {
                            if (f != "." && f != ".." && f.matchn(dir_pattern)) {
                                 return f;
                            }
                            f = current_dir->get_next();
                       }
                  }
                  return "";
             }
        }
        if (call->method_name.nocasecmp_to("MsgBox") == 0 && call_args.size() >= 1) {
             String msg = call_args[0];
             int buttons = 0;
             if (call_args.size() >= 2) buttons = (int)call_args[1];
             String title = "VisualGasic";
             if (call_args.size() >= 3) title = call_args[2];

             if (!owner || !Object::cast_to<Node>(owner)) return 0;
             Node *root = Object::cast_to<Node>(owner);

             AcceptDialog *dlg = nullptr;
             
             // Determine Dialog Type
             if (buttons == 4 || buttons == 1) { // vbYesNo or vbOKCancel
                  ConfirmationDialog *cd = memnew(ConfirmationDialog);
                  if (buttons == 4) {
                       cd->get_ok_button()->set_text("Yes");
                       cd->get_cancel_button()->set_text("No");
                  }
                  dlg = cd;
             } else {
                  dlg = memnew(AcceptDialog);
             }
             
             dlg->set_title(title);
             dlg->set_text(msg);
             root->add_child(dlg);

             // Signal Magic
             dlg->set_meta("result_ok", false);
             dlg->connect("confirmed", Callable(dlg, "set_meta").bind("result_ok", true));

             dlg->popup_centered();
             
             while (dlg->is_visible() && dlg->is_inside_tree()) {
                  DisplayServer::get_singleton()->process_events();
                  OS::get_singleton()->delay_msec(10);
             }
             
             bool ok = (bool)dlg->get_meta("result_ok");
             dlg->queue_free(); // destroy immediately

             if (buttons == 4) return ok ? 6 : 7; // Yes=6, No=7
             if (buttons == 1) return ok ? 1 : 2; // OK=1, Cancel=2
             return 1; // vbOK
        }

        // Godot Types
        if (call->method_name == "Vector2" && call_args.size() == 2) {
            return Vector2(call_args[0], call_args[1]);
        }
        if (call->method_name == "Vector3" && call_args.size() == 3) {
            return Vector3(call_args[0], call_args[1], call_args[2]);
        }
        if (call->method_name == "Rect2" && call_args.size() == 4) {
            return Rect2(call_args[0], call_args[1], call_args[2], call_args[3]);
        }
        if (call->method_name == "Color" && call_args.size() >= 3) {
            float r = call_args[0];
            float g = call_args[1];
            float b = call_args[2];
            float a = call_args.size() > 3 ? (float)call_args[3] : 1.0f;
            return Color(r, g, b, a);
        }

        // Math Library
        if (call->method_name == "Sin" && call_args.size() == 1) return UtilityFunctions::sin(call_args[0]);
        if (call->method_name == "Cos" && call_args.size() == 1) return UtilityFunctions::cos(call_args[0]);
        if (call->method_name == "Tan" && call_args.size() == 1) return UtilityFunctions::tan(call_args[0]);
        if (call->method_name == "Log" && call_args.size() == 1) return UtilityFunctions::log(call_args[0]);
        if (call->method_name == "Exp" && call_args.size() == 1) return UtilityFunctions::exp(call_args[0]);
        if (call->method_name == "Atn" && call_args.size() == 1) return UtilityFunctions::atan(call_args[0]); // Atn is ArcTan
        if (call->method_name == "Sqr" && call_args.size() == 1) return UtilityFunctions::sqrt(call_args[0]);
        if (call->method_name == "Abs" && call_args.size() == 1) return UtilityFunctions::abs(call_args[0]);
        if (call->method_name == "Sgn" && call_args.size() == 1) {
             double d = (double)call_args[0];
             if (d > 0) return 1;
             if (d < 0) return -1;
             return 0;
        }
        if (call->method_name == "Int" && call_args.size() == 1) return UtilityFunctions::floor(call_args[0]); // Int usually floors
        if (call->method_name == "Rnd") return UtilityFunctions::randf(); // 0..1
        
        if (call->method_name.nocasecmp_to("EOF") == 0 && call_args.size() == 1) {
            int file_num = (int)call_args[0];
            if (open_files.has(file_num)) {
                 Ref<FileAccess> fa = open_files[file_num];
                 return fa->eof_reached();
            }
            return true; 
        }

        if (call->method_name.nocasecmp_to("FreeFile") == 0) {
             int start = 1;
             if (call_args.size() > 0) {
                 int range = (int)call_args[0];
                 if (range == 1) start = 256;
             }
             for(int i=start; i < start + 255; i++) {
                 if (!open_files.has(i)) return i;
             }
             raise_error("Too many files open");
             return 0;
        }
        if (call->method_name == "Randomize") {
            UtilityFunctions::randomize();
            return Variant();
        }

        // Date and Time Library
        if (call->method_name == "Now") {
             return Time::get_singleton()->get_datetime_dict_from_system();
        }
        if (call->method_name == "Date") {
             return Time::get_singleton()->get_date_dict_from_system();
        }
        if (call->method_name == "Time") {
             return Time::get_singleton()->get_time_dict_from_system();
        }
        if (call->method_name == "Timer") {
             return Time::get_singleton()->get_ticks_msec() / 1000.0;
        }
        if (call->method_name == "Year" && call_args.size() == 1) {
             Dictionary d = call_args[0];
             if (d.has("year")) return d["year"];
             return 0;
        }
        if (call->method_name == "Month" && call_args.size() == 1) {
             Dictionary d = call_args[0];
             if (d.has("month")) return d["month"];
             return 0;
        }
        if (call->method_name == "Day" && call_args.size() == 1) {
             Dictionary d = call_args[0];
             if (d.has("day")) return d["day"];
             return 0;
        }
        if (call->method_name == "Hour" && call_args.size() == 1) {
             Dictionary d = call_args[0];
             if (d.has("hour")) return d["hour"];
             return 0;
        }
        if (call->method_name == "Minute" && call_args.size() == 1) {
             Dictionary d = call_args[0];
             if (d.has("minute")) return d["minute"];
             return 0;
        }
        if (call->method_name == "Second" && call_args.size() == 1) {
             Dictionary d = call_args[0];
             if (d.has("second")) return d["second"];
             return 0;
        }

        // Godot Integration
        if (call->method_name == "Load" && call_args.size() == 1) {
             return ResourceLoader::get_singleton()->load(call_args[0]);
        }
        if (call->method_name == "LoadTexture" && call_args.size() == 1) {
             return ResourceLoader::get_singleton()->load(call_args[0]);
        }
        if (call->method_name == "LoadTexture3D" && call_args.size() == 1) {
             return ResourceLoader::get_singleton()->load(call_args[0]);
        }
        if (call->method_name == "LoadSprite" && call_args.size() == 1) {
             Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(call_args[0]);
             if (tex.is_valid()) {
                  Sprite2D *s = memnew(Sprite2D);
                  s->set_texture(tex);
                  return s;
             }
             return Variant(); 
        }

        if (call->method_name == "CreateMSComm") {
             MSComm *comm = memnew(MSComm);
             // MSComm is now RefCounted, so we don't add to tree.
             // It is managed by the variable (Variant) holding the Ref.
             return Ref<MSComm>(comm);
        }

        if (call->method_name == "CreateSprite" && call_args.size() == 1) {
             Variant arg = call_args[0];
             Ref<Texture2D> tex = arg;
             Sprite2D *s = memnew(Sprite2D);
             if (tex.is_valid()) s->set_texture(tex);
             return s;
        }

        if (call->method_name == "CreateProgressBar") {
             ProgressBar *pb = memnew(ProgressBar);
             if (call_args.size() >= 1) pb->set_min(call_args[0]);
             if (call_args.size() >= 2) pb->set_max(call_args[1]);
             if (call_args.size() >= 3) pb->set_value(call_args[2]);
             
             // Optional Position
             if (call_args.size() >= 5) {
                 pb->set_position(Vector2(call_args[3], call_args[4]));
                 pb->set_size(Vector2(200, 20)); // Default size
             } else {
                 pb->set_size(Vector2(200, 20));
                 pb->set_position(Vector2(50, 50));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(pb);
                      dynamic_nodes.push_back(pb->get_instance_id());
                 }
             }
             return pb;
        }

        if (call->method_name == "CreateSlider") {
             HSlider *s = memnew(HSlider);
             if (call_args.size() >= 1) s->set_min(call_args[0]);
             if (call_args.size() >= 2) s->set_max(call_args[1]);
             if (call_args.size() >= 3) s->set_value(call_args[2]);
             
             if (call_args.size() >= 5) {
                 s->set_position(Vector2(call_args[3], call_args[4]));
                 s->set_size(Vector2(200, 20));
             } else {
                 s->set_size(Vector2(200, 20));
                 s->set_position(Vector2(50, 100));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(s);
                      dynamic_nodes.push_back(s->get_instance_id());
                 }
             }
             return s;
        }

        if (call->method_name == "CreateListView") {
             ItemList *il = memnew(ItemList);
             
             if (call_args.size() >= 2) {
                 il->set_position(Vector2(call_args[0], call_args[1]));
                 il->set_size(Vector2(200, 150));
             } else {
                 il->set_position(Vector2(50, 150));
                 il->set_size(Vector2(200, 150));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(il);
                      dynamic_nodes.push_back(il->get_instance_id());
                 }
             }
             return il;
        }

        if (call->method_name == "CreateFlexGrid") {
             int rows = 2;
             int cols = 2;
             if (call_args.size() >= 1) rows = call_args[0];
             if (call_args.size() >= 2) cols = call_args[1];
             
             Tree *t = memnew(Tree);
             t->set_columns(cols);
             t->set_column_titles_visible(true);
             t->set_select_mode(Tree::SELECT_SINGLE);
             
             // Create Root (Hidden usually in FlexGrid context, but Tree needs one)
             TreeItem *root = t->create_item();
             
             // Create Rows
             for(int i=0; i<rows; i++) {
                 TreeItem *it = t->create_item(root);
                 // Initialize text?
             }
             
             if (call_args.size() >= 4) {
                 t->set_position(Vector2(call_args[2], call_args[3]));
                 t->set_size(Vector2(300, 200));
             } else {
                 t->set_position(Vector2(50, 200));
                 t->set_size(Vector2(300, 200));
             }
             
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(t);
                      dynamic_nodes.push_back(t->get_instance_id());
                 }
             }
             return t;
        }



        if (call->method_name == "CreateText" && call_args.size() >= 1) {
             String text = call_args[0];
             Label *l = memnew(Label);
             l->set_text(text);
             if (call_args.size() >= 3) {
                 l->set_position(Vector2(call_args[1], call_args[2]));
             }
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(l);
                      dynamic_nodes.push_back(l->get_instance_id());
                 }
             }
             return l;
        }

        if (call->method_name.nocasecmp_to("GetAxis") == 0 && call_args.size() == 2) {
             String neg = call_args[0];
             String pos = call_args[1];
             return Input::get_singleton()->get_axis(neg, pos);
        }

        if (call->method_name.nocasecmp_to("GetJoyAxis") == 0 && call_args.size() == 2) {
             int device = call_args[0];
             int axis = call_args[1];
             return Input::get_singleton()->get_joy_axis(device, (JoyAxis)axis);
        }

        if (call->method_name == "CreateParticles2D" && call_args.size() >= 1) {
             Variant arg = call_args[0];
             Ref<Material> mat;
             if (arg.get_type() == Variant::STRING) {
                 mat = ResourceLoader::get_singleton()->load(arg);
             } else if (arg.get_type() == Variant::OBJECT) {
                 mat = arg;
             }

             GPUParticles2D *p = memnew(GPUParticles2D);
             if (mat.is_valid()) p->set_process_material(mat);
             p->set_emitting(true); // Auto start

             if (call_args.size() >= 3) {
                 p->set_position(Vector2(call_args[1], call_args[2]));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(p);
                      dynamic_nodes.push_back(p->get_instance_id());
                 }
             }
             return p;
        }

        if (call->method_name == "CreateParticles3D" && call_args.size() >= 1) {
             Variant arg = call_args[0];
             Ref<Material> mat;
             if (arg.get_type() == Variant::STRING) {
                 mat = ResourceLoader::get_singleton()->load(arg);
             } else if (arg.get_type() == Variant::OBJECT) {
                 mat = arg;
             }

             GPUParticles3D *p = memnew(GPUParticles3D);
             if (mat.is_valid()) p->set_process_material(mat);
             p->set_emitting(true); // Auto start

             if (call_args.size() >= 4) {
                 p->set_position(Vector3(call_args[1], call_args[2], call_args[3]));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(p);
                      dynamic_nodes.push_back(p->get_instance_id());
                 }
             }
             return p;
        }

        if (call->method_name == "CreateMultiMeshInstance3D" && call_args.size() >= 1) {
             Variant arg = call_args[0];
             Ref<MultiMesh> mesh;
             if (arg.get_type() == Variant::STRING) {
                 mesh = ResourceLoader::get_singleton()->load(arg);
             } else if (arg.get_type() == Variant::OBJECT) {
                 mesh = arg;
             }
             
             MultiMeshInstance3D *m = memnew(MultiMeshInstance3D);
             if (mesh.is_valid()) m->set_multimesh(mesh);
             
             if (call_args.size() >= 4) {
                 m->set_position(Vector3(call_args[1], call_args[2], call_args[3]));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(m);
                      dynamic_nodes.push_back(m->get_instance_id());
                 }
             }
             return m;
        }

        if (call->method_name == "CreateTextureRect" && call_args.size() >= 1) {
             Variant arg = call_args[0];
             Ref<Texture2D> tex;
             if (arg.get_type() == Variant::STRING) {
                 tex = ResourceLoader::get_singleton()->load(arg);
             } else if (arg.get_type() == Variant::OBJECT) {
                 tex = arg;
             }
             
             TextureRect *tr = memnew(TextureRect);
             if (tex.is_valid()) tr->set_texture(tex);
             
             if (call_args.size() >= 3) {
                 tr->set_position(Vector2(call_args[1], call_args[2]));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(tr);
                      dynamic_nodes.push_back(tr->get_instance_id());
                 }
             }
             return tr;
        }

        if (call->method_name == "CreateSprite3D" && call_args.size() >= 1) {
             Variant arg = call_args[0];
             Ref<Texture2D> tex;
             if (arg.get_type() == Variant::STRING) {
                 tex = ResourceLoader::get_singleton()->load(arg);
             } else if (arg.get_type() == Variant::OBJECT) {
                 tex = arg;
             }
             
             Sprite3D *s = memnew(Sprite3D);
             if (tex.is_valid()) s->set_texture(tex);
             
             if (call_args.size() >= 4) {
                 s->set_position(Vector3(call_args[1], call_args[2], call_args[3]));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(s);
                      dynamic_nodes.push_back(s->get_instance_id());
                 }
             }
             return s;
        }

        if (call->method_name == "CreateNode" && call_args.size() == 1) {
             String type = call_args[0];
             UtilityFunctions::print("DEBUG: CreateNode called with type: '", type, "'");
             if (ClassDB::class_exists(type) && ClassDB::can_instantiate(type)) {
                  // Instantiate object using ClassDB
                  // Note: instantiate() returns Variant which wraps the Object*
                  Variant res = ClassDB::instantiate(type);
                  if (res.get_type() == Variant::OBJECT && (Object*)res == nullptr) {
                       UtilityFunctions::print("DEBUG: CreateNode returned NULL Object for type: ", type);
                  } else {
                       UtilityFunctions::print("DEBUG: CreateNode success: ", res);
                  }
                  return res;
             } else {
                 UtilityFunctions::print("DEBUG: CreateNode FAILED for type: '", type, "' Exists: ", ClassDB::class_exists(type), " CanInstantiate: ", ClassDB::can_instantiate(type));
             }
             return Variant();
        }
        if (call->method_name == "AddChild" && call_args.size() == 1) {
             Object *obj = call_args[0];
             Node *child = Object::cast_to<Node>(obj);
             if (child && owner) {
                  Node *parent = Object::cast_to<Node>(owner);
                  if (parent) {
                       parent->add_child(child);
                  }
             }
             return Variant();
        }

        if (call->method_name == "Instantiate" && call_args.size() == 1) {
             // Supports path or PackedScene
             Variant arg = call_args[0];
             Ref<PackedScene> scene;
             if (arg.get_type() == Variant::STRING) {
                  scene = ResourceLoader::get_singleton()->load(arg);
             } else if (arg.get_type() == Variant::OBJECT) {
                  scene = arg;
             }
             
             if (scene.is_valid()) {
                  return scene->instantiate();
             }
             return Variant(); 
        }

        if (call->method_name == "LoadShader" && call_args.size() == 1) {
             return ResourceLoader::get_singleton()->load(call_args[0]);
        }
        
        if (call->method_name == "CompileShader" && call_args.size() == 1) {
             String code = call_args[0];
             Ref<Shader> shader;
             shader.instantiate();
             shader->set_code(code);
             return shader;
        }
        
        if (call->method_name == "GetDelta" && call_args.size() == 0) {
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) return n->get_process_delta_time();
             }
             return 0.0;
        }

        // Input Handling
        if (call->method_name == "IsActionPressed" && call_args.size() == 1) {
            String action = call_args[0];
            return Input::get_singleton()->is_action_pressed(action);
        }
        if (call->method_name == "IsActionJustPressed" && call_args.size() == 1) {
            String action = call_args[0];
            return Input::get_singleton()->is_action_just_pressed(action);
        }
        if (call->method_name == "IsActionJustReleased" && call_args.size() == 1) {
            String action = call_args[0];
            return Input::get_singleton()->is_action_just_released(action);
        }
        if (call->method_name == "IsKeyPressed" && call_args.size() == 1) {
            int key = call_args[0];
            return Input::get_singleton()->is_key_pressed((Key)key);
        }
        if (call->method_name == "IsMouseButtonPressed" && call_args.size() == 1) {
            int btn = call_args[0];
            return Input::get_singleton()->is_mouse_button_pressed((MouseButton)btn);
        }
        if (call->method_name == "GetMousePosition" && call_args.size() == 0) {
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      Viewport *vp = n->get_viewport();
                      if (vp) return vp->get_mouse_position();
                 }
             }
             return DisplayServer::get_singleton()->mouse_get_position();
        }
        
        // Factory for Vector2
        if (call->method_name.nocasecmp_to("Vector2") == 0 && call_args.size() == 2) {
             return Vector2(call_args[0], call_args[1]);
        }

        if (call->method_name.nocasecmp_to("TweenProperty") == 0 && call_args.size() == 4) {
             Object *obj = call_args[0];
             String prop = call_args[1];
             Variant final_val = call_args[2];
             double duration = call_args[3];
             
             if (obj && owner) {
                  Node *n = Object::cast_to<Node>(owner);
                  if (n) {
                       Ref<Tween> t = n->create_tween();
                       t->tween_property(obj, NodePath(prop), final_val, duration);
                       return t;
                  }
             }
             return Variant();
        }

        if (call->method_name == "CreateFileDialog" || call->method_name == "CreateCommonDialog") {
             FileDialog *fd = memnew(FileDialog);
             fd->set_access(FileDialog::ACCESS_FILESYSTEM); 
             fd->set_file_mode(FileDialog::FILE_MODE_OPEN_FILE);
             fd->set_size(Vector2(600, 400));
             fd->set_title("Open File");
             
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                      n->add_child(fd);
                      dynamic_nodes.push_back(fd->get_instance_id());
                      fd->call_deferred("popup_centered");
                 }
             }
             return fd;
        }

        if (call->method_name == "HasCollided" && call_args.size() == 1) {
             Object *obj = call_args[0];
             CharacterBody2D *cb2d = Object::cast_to<CharacterBody2D>(obj);
             if (cb2d) {
                 return cb2d->get_slide_collision_count() > 0;
             }
             CharacterBody3D *cb3d = Object::cast_to<CharacterBody3D>(obj);
             if (cb3d) {
                 return cb3d->get_slide_collision_count() > 0;
             }
             return false;
        }

        if (call->method_name == "GetCollider" && call_args.size() == 1) {
             Object *obj = call_args[0];
             CharacterBody2D *cb2d = Object::cast_to<CharacterBody2D>(obj);
             if (cb2d && cb2d->get_slide_collision_count() > 0) {
                 Ref<KinematicCollision2D> col = cb2d->get_slide_collision(0);
                 if (col.is_valid()) return col->get_collider();
             }
             CharacterBody3D *cb3d = Object::cast_to<CharacterBody3D>(obj);
             if (cb3d && cb3d->get_slide_collision_count() > 0) {
                 Ref<KinematicCollision3D> col = cb3d->get_slide_collision(0);
                 if (col.is_valid()) return col->get_collider();
             }
             return Variant();
        }

        if (call->method_name == "CreateTrigger" && call_args.size() >= 4) {
             String name = call_args[0];
             double x = call_args[1];
             double y = call_args[2];
             double w = call_args[3];
             double h = (call_args.size() > 4) ? (double)call_args[4] : w;
             
             Area2D *area = memnew(Area2D);
             area->set_name(name);
             area->set_position(Vector2(x,y));
             
             CollisionShape2D *shape = memnew(CollisionShape2D);
             Ref<RectangleShape2D> rect;
             rect.instantiate();
             rect->set_size(Vector2(w, h));
             shape->set_shape(rect);
             area->add_child(shape);
             
             if (owner) {
                  Node *n = Object::cast_to<Node>(owner);
                  if (n) {
                      n->add_child(area);
                      dynamic_nodes.push_back(area->get_instance_id());
                      area->connect("body_entered", Callable(owner, "_OnSignal").bind(name, "Collision"));
                  }
             }
             return area;
        }

        if (call->method_name == "CreateTimer" && call_args.size() >= 1) {
             double interval = call_args[0]; // in seconds
             bool active = true;
             if (call_args.size() >= 2) active = call_args[1];
             
             Timer *t = memnew(Timer);
             t->set_wait_time(interval);
             t->set_autostart(active);
             t->set_one_shot(false);
             
             // Name? "Timer"+ID
             // We need a stable name/ID for the event binding if arguments don't provide it.
             // VB6 Timers were controls drawn on form with a name.
             // Here, CreateTimer needs to return the object so we can stop it.
             // But to hook up events.. "Sub MyTimer_Timer()"?
             // We need to know the variable name assigned to? We don't know that here.
             // User should probably Set Name property? 
             // Or allow CreateTimer("Name", Interval)
             
             String name = "TimerVal"; 
             if (call_args.size() == 3) name = call_args[3]; // Not ideal arg order
             
             // Better: Allow binding later via name set? 
             // Or assume user passes name as first arg: CreateTimer("MyTimer", 1000)
             
             if (call_args[0].get_type() == Variant::STRING) {
                  name = call_args[0];
                  interval = call_args[1];
                  if (call_args.size() >= 3) active = call_args[2];
                  t->set_wait_time(interval);
                  t->set_name(name);
             } else {
                  // Anonymous timer? Hard to bind events.
             }

             if (owner) {
                  Node *n = Object::cast_to<Node>(owner);
                  if (n) {
                      n->add_child(t);
                      dynamic_nodes.push_back(t->get_instance_id());
                      // Bind timeout
                      t->connect("timeout", Callable(owner, "_OnSignal").bind(name, "Timer"));
                      // Autostart handles it if in tree. If not, autostart=true will start it when it enters.
                      // No need to call start() manually.
                  }
             }
             return t;
        }
        
        if (call->method_name == "CreateMenu" && call_args.size() >= 1) {
             String title = call_args[0];
             String name = title; // Default name matches title
             if (call_args.size() >= 2) name = call_args[1];

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 CanvasItem *ci = Object::cast_to<CanvasItem>(n);
                 if (ci) {
                     // Find or Create MenuBar container
                     Node *menu_bar = n->find_child("VisualGasicMenuBar", false, false);
                     HBoxContainer *hbox = nullptr;
                     
                     if (!menu_bar) {
                         hbox = memnew(HBoxContainer);
                         hbox->set_name("VisualGasicMenuBar");
                         hbox->set_position(Vector2(0,0));
                         hbox->set_size(Vector2(1024, 30)); // Stretch later?
                         // Ideally anchored top
                         hbox->set_anchors_and_offsets_preset(Control::PRESET_TOP_WIDE);
                         n->add_child(hbox);
                     } else {
                         hbox = Object::cast_to<HBoxContainer>(menu_bar);
                     }
                     
                     if (hbox) {
                         MenuButton *mb = memnew(MenuButton);
                         mb->set_text(title);
                         mb->set_name(name);
                         mb->set_switch_on_hover(true);
                         hbox->add_child(mb);
                         
                         dynamic_nodes.push_back(mb->get_instance_id());
                         
                         // Return the PopupMenu so we can add items
                         return mb->get_popup();
                     }
                 }
             }
             return Variant();
        }

        if (call->method_name == "CreateActor2D" && call_args.size() >= 3) {
             String img_path = call_args[0];
             double x = call_args[1];
             double y = call_args[2];
             
             CharacterBody2D *body = memnew(CharacterBody2D);
             body->set_position(Vector2(x, y));
             
             // Sprite
             Sprite2D *sprite = memnew(Sprite2D);
             Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(img_path);
             if (tex.is_valid()) {
                 sprite->set_texture(tex);
                 // Collision Shape (Circle based on texture size approx)
                 CollisionShape2D *shape = memnew(CollisionShape2D);
                 Ref<CircleShape2D> circle;
                 circle.instantiate();
                 float radius = tex->get_width() / 2.0;
                 circle->set_radius(radius);
                 shape->set_shape(circle);
                 body->add_child(shape);
             } else {
                 // Fallback Shape
                 CollisionShape2D *shape = memnew(CollisionShape2D);
                 Ref<CircleShape2D> circle;
                 circle.instantiate();
                 circle->set_radius(20.0);
                 shape->set_shape(circle);
                 body->add_child(shape);
             }
             body->add_child(sprite);
             
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                     n->add_child(body);
                     dynamic_nodes.push_back(body->get_instance_id());
                 }
             }
             return body;
        }
        
        if (call->method_name == "CreateText" && call_args.size() >= 1) {
             String text = call_args[0];
             Label *l = memnew(Label);
             l->set_text(text);
             if (call_args.size() >= 2) {
                  // Only if vector?
                  if (call_args.size() == 2 && call_args[1].get_type() == Variant::VECTOR2) {
                       l->set_position(call_args[1]);
                  } else if (call_args.size() >= 3) {
                       l->set_position(Vector2(call_args[1], call_args[2]));
                  }
             }
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                     n->add_child(l);
                     dynamic_nodes.push_back(l->get_instance_id());
                 }
             }
             return l;
        }

        // --- NEW PRO FEATURES ---
        if (call->method_name.nocasecmp_to("CreateLabel") == 0 && call_args.size() >= 3) {
            String text = call_args[0];
            double x = call_args[1]; 
            double y = call_args[2];
            
            Label *l = memnew(Label);
            l->set_text(text);
            l->set_position(Vector2(x,y));
            
            if (owner) {
                Node *n = Object::cast_to<Node>(owner);
                if (n) {
                    n->add_child(l);
                    dynamic_nodes.push_back(l->get_instance_id());
                }
            }
            return l;
        }

        if (call->method_name.nocasecmp_to("CreateButton") == 0 && call_args.size() >= 3) {
             String text = call_args[0];
             double x = call_args[1];
             double y = call_args[2];
             
             Button *b = memnew(Button);
             b->set_text(text);
             b->set_position(Vector2(x, y));
             
             if (call_args.size() >= 4) {
                 // Callback Name
                 String callback = call_args[3];
                 // Bind "pressed" to _OnSignal (which calls BASIC sub)
                 b->connect("pressed", Callable(owner, "_OnSignal").bind(callback, ""));
             }

             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                     n->add_child(b);
                     dynamic_nodes.push_back(b->get_instance_id());
                 }
             }
             return b;
        }

        if (call->method_name.nocasecmp_to("CreateInput") == 0 && call_args.size() >= 3) {
             String text = call_args[0];
             double x = call_args[1];
             double y = call_args[2];
             
             LineEdit *le = memnew(LineEdit);
             le->set_text(text);
             le->set_position(Vector2(x,y));
             
             if (call_args.size() >= 4) {
                 double width = call_args[3];
                 le->set_size(Vector2(width, le->get_size().y));
             } else {
                 le->set_size(Vector2(100, le->get_size().y));
             }
             
             if (owner) {
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                     n->add_child(le);
                     dynamic_nodes.push_back(le->get_instance_id());
                 }
             }
             return le;
        }

        if (call->method_name.nocasecmp_to("GetKey") == 0 && call_args.size() == 1) {
            Key key = Key::KEY_NONE;
            if (call_args[0].get_type() == Variant::INT || call_args[0].get_type() == Variant::FLOAT) {
                key = (Key)(int)call_args[0];
            } else {
                String k = call_args[0];
                key = (Key)OS::get_singleton()->find_keycode_from_string(k);
            }
            return Input::get_singleton()->is_key_pressed(key);
        }
        if (call->method_name.nocasecmp_to("IsKeyDown") == 0 && call_args.size() == 1) {
            Key key = Key::KEY_NONE;
            if (call_args[0].get_type() == Variant::INT || call_args[0].get_type() == Variant::FLOAT) {
                key = (Key)(int)call_args[0];
            } else {
                String k = call_args[0];
                key = (Key)OS::get_singleton()->find_keycode_from_string(k);
            }
            return Input::get_singleton()->is_key_pressed(key);
        }
        if (call->method_name.nocasecmp_to("IsMouseButtonDown") == 0 && call_args.size() == 1) {
            int btn = call_args[0];
            return Input::get_singleton()->is_mouse_button_pressed((MouseButton)btn);
        }
        if (call->method_name.nocasecmp_to("GetMouseX") == 0) {
            if (owner) {
                Node *n = Object::cast_to<Node>(owner);
                if (n && n->get_viewport()) return n->get_viewport()->get_mouse_position().x;
            }
            return 0.0;
        }
        if (call->method_name.nocasecmp_to("GetMouseY") == 0) {
            if (owner) {
                Node *n = Object::cast_to<Node>(owner);
                if (n && n->get_viewport()) return n->get_viewport()->get_mouse_position().y;
            }
            return 0.0;
        }

        if (call->method_name.nocasecmp_to("IsOnFloor") == 0 && call_args.size() == 1) {
            Object *o = call_args[0];
            CharacterBody2D *cb2 = Object::cast_to<CharacterBody2D>(o);
            if (cb2) return cb2->is_on_floor();
            CharacterBody3D *cb3 = Object::cast_to<CharacterBody3D>(o);
            if (cb3) return cb3->is_on_floor();
            return false;
        }
        if (call->method_name.nocasecmp_to("GetCollisionCount") == 0 && call_args.size() == 1) {
            Object *o = call_args[0];
            CharacterBody2D *cb2 = Object::cast_to<CharacterBody2D>(o);
            if (cb2) return cb2->get_slide_collision_count();
            CharacterBody3D *cb3 = Object::cast_to<CharacterBody3D>(o);
            if (cb3) return cb3->get_slide_collision_count();
            return 0;
        }

        if (call->method_name == "GetAxis" && call_args.size() == 2) {
             return Input::get_singleton()->get_axis(call_args[0], call_args[1]);
        }
        
        if (call->method_name == "GetJoyAxis" && call_args.size() == 2) {
             return Input::get_singleton()->get_joy_axis(call_args[0], (JoyAxis)(int)call_args[1]);
        }

        if (call->method_name == "GetMousePos" && call_args.size() == 0) {
             // Return global or viewport position?
             // Viewport makes most sense for Canvas
             // But we need a node context.
             if (owner) {
                  CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                  // Check viewport availability to prevent crashes in headless/unititialized state
                  if (ci && ci->get_viewport()) return ci->get_local_mouse_position();
                  
                  Node *n = Object::cast_to<Node>(owner);
                  if (n) {
                       Viewport *vp = n->get_viewport();
                       if (vp) return vp->get_mouse_position();
                  }
             }
             return Vector2(0,0);
        }
        if (call->method_name == "GetGlobalMousePos" && call_args.size() == 0) {
             if (owner) {
                  CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                  if (ci && ci->get_viewport()) return ci->get_global_mouse_position();
             }
             // Or display server
             return DisplayServer::get_singleton()->mouse_get_position(); 
        }

        if (call->method_name.nocasecmp_to("Array") == 0) {
            return call_args;
        }

        // Try Internal Call
        bool found = false;
        Variant v_ret = call_internal(call->method_name, call_args, found);
        if (found) return v_ret;

        if (owner) {
             if (owner->has_method(call->method_name)) {
                 return owner->callv(call->method_name, call_args);
             }
             String snake = call->method_name.to_snake_case();
             if (owner->has_method(snake)) {
                 return owner->callv(snake, call_args);
             }
        }
        raise_error("Failed to call function " + call->method_name);
        return Variant();
    }
    if (expr->type == ExpressionNode::UNARY_OP) {
        UnaryOpNode* u = (UnaryOpNode*)expr;
        Variant val = evaluate_expression(u->operand);
        if (u->op.nocasecmp_to("Not") == 0) {
            return !val.booleanize();
        }
        if (u->op == "-") {
            // Unary Negation
            bool valid;
            Variant res;
            Variant::evaluate(Variant::OP_NEGATE, val, Variant(), res, valid);
            return res;
        }
        return Variant();
    }
    if (expr->type == ExpressionNode::BINARY_OP) {
        BinaryOpNode* bin = (BinaryOpNode*)expr;

        // Short-circuit operators
        if (bin->op.nocasecmp_to("AndAlso") == 0) {
             Variant l = evaluate_expression(bin->left);
             if (!l.booleanize()) return false;
             return evaluate_expression(bin->right).booleanize();
        }
        if (bin->op.nocasecmp_to("OrElse") == 0) {
             Variant l = evaluate_expression(bin->left);
             if (l.booleanize()) return true;
             return evaluate_expression(bin->right).booleanize();
        }

        Variant l = evaluate_expression(bin->left);
        Variant r = evaluate_expression(bin->right);
        
        String op = bin->op;
        Variant result;
        bool valid;
        
        if (op == "&") {
             return String(l) + String(r);
        }

        if (op == "**") {
             // Power
             return UtilityFunctions::pow(l, r);
        }
        if (op == "//") {
             // Floor Division
             double val = (double)l / (double)r;
             return floor(val);
        }
        
        if (op.nocasecmp_to("And") == 0) return l.booleanize() && r.booleanize();
        if (op.nocasecmp_to("Or") == 0) return l.booleanize() || r.booleanize();
        if (op.nocasecmp_to("Xor") == 0) return l.booleanize() != r.booleanize();
        if (op.nocasecmp_to("Is") == 0) {
             // Reference Comparison or Null check
             // In Godot, equality works for nulls.
             // But if we want Reference Identity, we check if they are same object.
             // If operands are Objects, compare pointers (Object::cast_to<Object>?)
             // Variant operator == on Objects compares IDs usually.
             
             // VB strict 'Is' means reference equality.
             // Variant::OP_EQUAL does deep compare for Dictionary/Array?
             // No, Dictionary/Array are by reference in Godot Variant.
             // So == should be fine.
             bool valid;
             Variant res;
             Variant::evaluate(Variant::OP_EQUAL, l, r, res, valid);
             return res;
        }
        
        Variant::Operator v_op = Variant::OP_ADD;
        if (op == "+") v_op = Variant::OP_ADD;
        else if (op == "-") v_op = Variant::OP_SUBTRACT;
        else if (op == "*") v_op = Variant::OP_MULTIPLY;
        else if (op == "/") v_op = Variant::OP_DIVIDE;
        else if (op == "=") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) == 0;
             }
             v_op = Variant::OP_EQUAL;
        }
        else if (op == "<") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) < 0;
             }
             v_op = Variant::OP_LESS;
        }
        else if (op == ">") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) > 0;
             }
             
             // Explicit numeric comparison to ensure correctness
             if ((l.get_type() == Variant::FLOAT || l.get_type() == Variant::INT) && 
                 (r.get_type() == Variant::FLOAT || r.get_type() == Variant::INT)) {
                  return (double)l > (double)r;
             }
             
             v_op = Variant::OP_GREATER;
             Variant::evaluate(v_op, l, r, result, valid);
             return result;
        }
        else if (op == "<=") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) <= 0;
             }
             v_op = Variant::OP_LESS_EQUAL;
        }
        else if (op == ">=") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) >= 0;
             }
             v_op = Variant::OP_GREATER_EQUAL;
        }
        else if (op == "<>") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) != 0;
             }
             v_op = Variant::OP_NOT_EQUAL;
        }
        else if (op == "!=") {
             if (option_compare_text && l.get_type() == Variant::STRING && r.get_type() == Variant::STRING) {
                 return String(l).nocasecmp_to(String(r)) != 0;
             }
             v_op = Variant::OP_NOT_EQUAL;
        }
        
        Variant::evaluate(v_op, l, r, result, valid);
        return result;
    }
    return Variant();
}

void VisualGasicInstance::execute_statement(Statement* stmt) {
    if (!stmt) return;
    
    switch (stmt->type) {
        case STMT_PASS: break; // Do nothing
        case STMT_PRINT: {
            PrintStatement* s = (PrintStatement*)stmt;
            Variant val = evaluate_expression(s->expression);
            if (s->file_number) {
                int fn = evaluate_expression(s->file_number);
                if (open_files.has(fn)) {
                     Ref<FileAccess> fa = open_files[fn];
                     fa->store_line(String(val));
                } else {
                     raise_error("Bad File Name or Number");
                }
            } else {
                UtilityFunctions::print(val);
            }
            break;
        }
        case STMT_CONST: {
            ConstStatement* s = (ConstStatement*)stmt;
            Variant val = evaluate_expression(s->value);
            variables[s->name] = val; // Treat as variable for now
            break;
        }
        case STMT_DO_EVENTS: {
             DisplayServer::get_singleton()->process_events();
             // Maybe also add a small delay if needed? OS::get_singleton()->delay_usec(1);
             break;
        }
        case STMT_DIM: {
            DimStatement* s = (DimStatement*)stmt;
            
            // Static handling: If variable exists, preserve it.
            // Note: In current architecture without stack frames, this persists across the instance lifetime.
            if (s->is_static && variables.has(s->variable_name)) {
                break;
            }
            
            if (s->array_sizes.size() > 0) {
                // Multidimensional: Create nested arrays
                Vector<int> dims;
                for(int i=0; i<s->array_sizes.size(); i++) {
                    dims.push_back((int)evaluate_expression(s->array_sizes[i]) + 1); // 0..N
                }
                
                struct ArrayBuilder {
                    static Array create(const Vector<int>& d, int depth, const String& type_name, const Dictionary& prototypes) {
                         Array a;
                         int size = d[depth];
                         a.resize(size);
                         if (depth < d.size() - 1) {
                             for(int i=0; i<size; i++) {
                                 a[i] = create(d, depth+1, type_name, prototypes);
                             }
                         } else {
                             // Leaf
                             if (!type_name.is_empty() && prototypes.has(type_name)) {
                                 for(int i=0; i<size; i++) {
                                     a[i] = ((Dictionary)prototypes[type_name]).duplicate(true);
                                 }
                             }
                         }
                         return a;
                    }
                };
                
                variables[s->variable_name] = ArrayBuilder::create(dims, 0, s->type_name, struct_prototypes);

            } else {
                if (s->initializer) {
                     Variant val = evaluate_expression(s->initializer);
                     if (!s->type_name.is_empty()) {
                         String t = s->type_name.to_lower();
                         if (t == "integer" || t == "long") val = (int64_t)val;
                         else if (t == "single" || t == "double") val = (double)val;
                         else if (t == "string") val = (String)val;
                         else if (t == "boolean") val = (bool)val;
                     }
                     variables[s->variable_name] = val;
                } else if (!s->type_name.is_empty()) {
                    if (struct_prototypes.has(s->type_name)) {
                        // Instantiate Struct
                        variables[s->variable_name] = ((Dictionary)struct_prototypes[s->type_name]).duplicate(true);
                    } else {
                        String t = s->type_name.to_lower();
                        if (t == "integer" || t == "long") variables[s->variable_name] = 0;
                        else if (t == "single" || t == "double") variables[s->variable_name] = 0.0;
                        else if (t == "string") variables[s->variable_name] = "";
                        else if (t == "boolean") variables[s->variable_name] = false;
                        else variables[s->variable_name] = Variant();
                    }
                } else {
                    variables[s->variable_name] = Variant();
                }
            }
            break;
        }
        case STMT_DATA: {
             // Do nothing at runtime, handled by scan
             break;
        }
        case STMT_READ: {
             ReadStatement* s = (ReadStatement*)stmt;
             for(int i=0; i<s->targets.size(); i++) {
                 if (data_pointer >= data_segments.size()) {
                     raise_error("Out of Data");
                     break;
                 }
                 Variant val = evaluate_expression(data_segments[data_pointer]);
                 data_pointer++;
                 assign_to_target(s->targets[i], val);
             }
             break;
        }
        case STMT_RESTORE: {
             RestoreStatement* s = (RestoreStatement*)stmt;
             if (s->label_name.is_empty()) {
                 data_pointer = 0;
             } else {
                 if (label_to_data_index.has(s->label_name)) {
                     data_pointer = (int)label_to_data_index[s->label_name];
                 } else {
                     raise_error("Label not found for Restore: " + s->label_name);
                 }
             }
             break;
        }
        case STMT_ASSIGNMENT: {
            AssignmentStatement* s = (AssignmentStatement*)stmt;
            Variant val = evaluate_expression(s->value);
            assign_to_target(s->target, val);
            break;
        }
        case STMT_IF: {
            IfStatement* s = (IfStatement*)stmt;
            if (evaluate_expression(s->condition).booleanize()) {
                for(int i=0; i<s->then_branch.size(); i++) execute_statement(s->then_branch[i]);
            } else {
                for(int i=0; i<s->else_branch.size(); i++) execute_statement(s->else_branch[i]);
            }
            break;
        }
        case STMT_WITH: {
             WithStatement* s = (WithStatement*)stmt;
             Variant context = evaluate_expression(s->expression);
             with_stack.push_back(context);
             
             for(int i=0; i<s->body.size(); i++) {
                 execute_statement(s->body[i]);
                 if (error_state.has_error || error_state.mode != ErrorState::NONE) break;
             }
             
             if (!with_stack.is_empty()) with_stack.remove_at(with_stack.size() - 1);
             break;
        }
        case STMT_FOR_EACH: {
             ForEachStatement* s = (ForEachStatement*)stmt;
             Variant col = evaluate_expression(s->collection);
             
             // Check if it is iterable? Array or Object (get_iter)?
             // Variant doesn't expose get_iter directly in GDExtension easily?
             // Array has iteration.
             // Dictionary has keys.
             // Objects might have _iter.
             
             // For now, support Array.
             if (col.get_type() == Variant::ARRAY) {
                 Array arr = col;
                 for(int i=0; i<arr.size(); i++) {
                     assign_variable(s->variable_name, arr[i]);
                     
                     for(int b=0; b<s->body.size(); b++) {
                         execute_statement(s->body[b]);
                         if (error_state.has_error) break;
                         // Handle Exit For?
                         if (error_state.mode == ErrorState::EXIT_FOR) break;
                         if (error_state.mode != ErrorState::NONE) break;
                     }
                     
                     if (error_state.has_error) break;
                     if (error_state.mode == ErrorState::EXIT_FOR) {
                         error_state.mode = ErrorState::NONE;
                         break;
                     }
                     if (error_state.mode != ErrorState::NONE) break;
                 }
             } else {
                 raise_error("For Each requires an Array (other types not supported yet)");
             }
             break;
        }
        
        case STMT_FOR: {
            ForStatement* s = (ForStatement*)stmt;
            String var = s->variable_name;
            Variant start = evaluate_expression(s->from_val);
            Variant end = evaluate_expression(s->to_val);
            Variant step = s->step_val ? evaluate_expression(s->step_val) : Variant(1);
            
            // UtilityFunctions::print("FOR Loop: ", var, " from ", start, " to ", end, " step ", step);

            assign_variable(var, start);
            
            int safety = 0;
            while (safety < 1000) {
                 Variant current = variables[var];
                 // UtilityFunctions::print("  Loop iter: ", current);

                 bool condition = false;
                 Variant res; bool valid;
                 if (double(step) >= 0) {
                     Variant::evaluate(Variant::OP_LESS_EQUAL, current, end, res, valid);
                     condition = res.booleanize();
                 } else {
                     Variant::evaluate(Variant::OP_GREATER_EQUAL, current, end, res, valid);
                     condition = res.booleanize();
                 }
                 
                 if (!condition) break;
                 
                 for(int i=0; i<s->body.size(); i++) {
                     execute_statement(s->body[i]);
                     if (error_state.has_error) break;
                 }
                 
                 if (error_state.has_error) {
                     if (error_state.mode == ErrorState::CONTINUE_FOR) {
                         error_state.has_error = false;
                         error_state.mode = ErrorState::NONE;
                         // Increment and continue
                         Variant res; bool valid;
                         Variant::evaluate(Variant::OP_ADD, variables[var], step, res, valid);
                         assign_variable(var, res);
                         safety++;
                         continue;
                     }

                     if (error_state.mode == ErrorState::EXIT_FOR) {
                         error_state.has_error = false;
                         error_state.mode = ErrorState::NONE;
                         break;
                     }
                     break; // Propagate other errors/exits
                 }
                 
                 Variant::evaluate(Variant::OP_ADD, variables[var], step, res, valid);
                 assign_variable(var, res);
                 safety++;
            }
            break;
        }
        case STMT_WHILE: {
            WhileStatement* s = (WhileStatement*)stmt;
            int safety = 0;
            while (safety < 10000) {
                if (!evaluate_expression(s->condition).booleanize()) break;
                for(int i=0; i<s->body.size(); i++) {
                    execute_statement(s->body[i]);
                    if (error_state.has_error) break;
                }
                
                if (error_state.has_error) {
                     if (error_state.mode == ErrorState::CONTINUE_WHILE || error_state.mode == ErrorState::CONTINUE_DO) {
                         error_state.has_error = false;
                         error_state.mode = ErrorState::NONE;
                         safety++;
                         continue; // Next iteration
                     }
                     if (error_state.mode == ErrorState::EXIT_DO) {
                         error_state.has_error = false;
                         error_state.mode = ErrorState::NONE;
                         break;
                     }
                     break;
                }
                
                safety++;
            }
            if (safety >= 10000) UtilityFunctions::print("Runtime: While loop limit reached.");
            break;
        }
        case STMT_DO: {
            DoStatement* s = (DoStatement*)stmt;
            int safety = 0;
            while (safety < 10000) {
                // Pre Check
                if (!s->is_post_condition && s->condition_type != DoStatement::NONE) {
                    bool res = evaluate_expression(s->condition).booleanize();
                    if (s->condition_type == DoStatement::WHILE && !res) break;
                    if (s->condition_type == DoStatement::UNTIL && res) break;
                }
                
                for(int i=0; i<s->body.size(); i++) {
                    execute_statement(s->body[i]);
                    if (error_state.has_error) break;
                }
                
                if (error_state.has_error) {
                     if (error_state.mode == ErrorState::CONTINUE_DO) {
                         error_state.has_error = false;
                         error_state.mode = ErrorState::NONE;
                         
                         // Handle Post-Condition Check for Continue Do
                         if (s->is_post_condition && s->condition_type != DoStatement::NONE) {
                             bool res = evaluate_expression(s->condition).booleanize();
                             if (s->condition_type == DoStatement::WHILE && !res) break;
                             if (s->condition_type == DoStatement::UNTIL && res) break;
                         }
                         
                         safety++;
                         continue;
                     }

                     if (error_state.mode == ErrorState::EXIT_DO) {
                         error_state.has_error = false;
                         error_state.mode = ErrorState::NONE;
                         break;
                     }
                     break; 
                }
                
                // Post Check
                if (s->is_post_condition && s->condition_type != DoStatement::NONE) {
                    bool res = evaluate_expression(s->condition).booleanize();
                    if (s->condition_type == DoStatement::WHILE && !res) break;
                    if (s->condition_type == DoStatement::UNTIL && res) break;
                }
                
                safety++;
            }
            if (safety >= 10000) UtilityFunctions::print("Runtime: Do loop limit reached.");
            break;
        }

        case STMT_RETURN: {
            ReturnStatement* ret = (ReturnStatement*)stmt;
            if (ret->return_value) {
                // If it's a function, we must assign to function name variable?
                // Or just set the return value register.
                // The current calling convention relies on Function Name = Value for returns.
                // The `execute` method returns Variant on completion.
                // If we are in a Function, we should probably set the return value if not already set by name?
                // Actually, current engine doesn't explicitly return variant from execute_block cleanly.
                // But `call_internal` returns `variables[func_name]` or last result?
                
                // Let's check `call_internal`.
                // It executes block and checks `variables[func_name]`.
                // So `Return X` => `variables[func_name] = X; Exit Function`
                
                if (current_sub) {
                    variables[current_sub->name] = evaluate_expression(ret->return_value);
                }
            }
            error_state.has_error = true; 
            error_state.mode = ErrorState::EXIT_SUB; 
            // EXIT_SUB works for Function too
            break;
        }
        
        case STMT_CONTINUE: {
            ContinueStatement* cont = (ContinueStatement*)stmt;
            error_state.has_error = true;
            if (cont->loop_type == ContinueStatement::FOR) error_state.mode = ErrorState::CONTINUE_FOR;
            else if (cont->loop_type == ContinueStatement::DO) error_state.mode = ErrorState::CONTINUE_DO;
            else if (cont->loop_type == ContinueStatement::WHILE) error_state.mode = ErrorState::CONTINUE_WHILE;
            else error_state.mode = ErrorState::NONE; // Unknown?
            break;
        }

        case STMT_CALL: {
            CallStatement* s = (CallStatement*)stmt;
            
            Array call_args;
            int arg_count = s->arguments.size();
            for(int i=0; i<arg_count; i++) {
                call_args.push_back(evaluate_expression(s->arguments[i]));
            }

            // Try centralized statement-level builtins first
            {
                Variant _bg_ret;
                bool _bg_found = false;
                if (VisualGasicBuiltins::call_builtin(this, s->method_name, call_args, _bg_ret, _bg_found)) {
                    if (_bg_found) break;
                }
            }

            if (s->method_name.nocasecmp_to("TweenProperty") == 0) {
                 if (call_args.size() == 4) {
                      Object *obj = call_args[0];
                      String prop = call_args[1];
                      Variant final_val = call_args[2];
                      double duration = call_args[3];
                      if (obj && owner) {
                           Node *n = Object::cast_to<Node>(owner);
                           if (n) {
                                Ref<Tween> t = n->create_tween();
                                t->tween_property(obj, NodePath(prop), final_val, duration);
                           }
                      }
                      break; 
                 }
            }


            if (s->base_object) {
                // Delegate variable-base builtins (Clipboard etc.) to centralized handler
                 if (s->base_object->type == ExpressionNode::VARIABLE) {
                     String var_name = ((VariableNode*)s->base_object)->name;
                     Variant _var_ret;
                     if (VisualGasicBuiltins::call_builtin_for_base_variable(this, var_name, s->method_name, call_args, _var_ret)) {
                         break;
                     }
                 }
                 
                Variant base = evaluate_expression(s->base_object);

                    // Let builtins handle dictionary/object cases first
                    {
                        Variant _bb_ret;
                        if (VisualGasicBuiltins::call_builtin_for_base_variant(this, base, s->method_name, call_args, _bb_ret)) {
                            break;
                        }
                    }
                
                    if (base.get_type() == Variant::OBJECT) {
                        Object* obj = base;
                    if (obj) {
                         // FlexGrid / Tree Helpers
                         if (obj->is_class("Tree")) {
                             if (s->method_name == "SetTextMatrix" && call_args.size() >= 3) {
                                 Tree *t = Object::cast_to<Tree>(obj);
                                 int row = call_args[0];
                                 int col = call_args[1];
                                 String text = call_args[2];
                                 
                                 // Access item. Tree items are hierarchical.
                                 // If used as simple grid, we assume flat list under root.
                                 // Row 0 is header usually? No, header is separate.
                                 // Let's assume Row indices match get_child index.
                                 TreeItem *root = t->get_root();
                                 if (root && row >= 0 && row < root->get_child_count()) {
                                     TreeItem *it = root->get_child(row);
                                     it->set_text(col, text);
                                 }
                                 break;
                             }
                             if (s->method_name == "AddItem" && call_args.size() >= 1) {
                                 Tree *t = Object::cast_to<Tree>(obj);
                                 TreeItem *root = t->get_root();
                                 if (root) {
                                     TreeItem *it = t->create_item(root);
                                     String text = call_args[0];
                                     // Split by tab? FlexGrid AddItem often supports tab separated columns
                                     PackedStringArray parts = text.split("\t");
                                     int cols = t->get_columns();
                                     for(int i=0; i<parts.size(); i++) {
                                         if (i < cols) it->set_text(i, parts[i]);
                                     }
                                 }
                                 break;
                             }
                             if (s->method_name == "RemoveItem" && call_args.size() == 1) {
                                  Tree *t = Object::cast_to<Tree>(obj);
                                  int idx = call_args[0];
                                  TreeItem *root = t->get_root();
                                  if (root && idx >= 0 && idx < root->get_child_count()) {
                                      // Tree doesn't have remove_child by index directly easily?
                                      // root->get_child(idx)->free(); // Memdelete?
                                      // In Godot, freeing the item removes it.
                                      TreeItem *it = root->get_child(idx);
                                      memdelete(it); 
                                  }
                                  break;
                             }
                         }


                         if (s->method_name.nocasecmp_to("Connect") == 0 && call_args.size() == 2) {
                             String signal = call_args[0];
                             String target = call_args[1];
                             if (owner) {
                                 if (obj->has_signal(signal)) {
                                     obj->connect(signal, Callable(owner, target));
                                 } else {
                                     UtilityFunctions::print("Runtime Warning: Signal '", signal, "' not found on object");
                                 }
                                 break;
                             }
                         }

                         // UtilityFunctions::print("Call on object: ", s->method_name);
                         if (obj->has_method(s->method_name)) {
                             obj->callv(s->method_name, call_args);
                         } else {
                             String snake = s->method_name.to_snake_case();
                             if (obj->has_method(snake)) {
                                 obj->callv(snake, call_args);
                             } else {
                                 // Handle 3D Shape special method calls?
                                 // e.g. Cube.LookAt(x,y,z) -> look_at
                                 if (s->method_name == "LookAt" && call_args.size() == 3) {
                                     Node3D *n3d = Object::cast_to<Node3D>(obj);
                                     if (n3d) {
                                         n3d->look_at(Vector3(call_args[0], call_args[1], call_args[2]));
                                         break; // Handled
                                     }
                                 }
                                 raise_error("Object does not have method " + s->method_name);
                             }
                         }
                    } else {
                        raise_error("Method call on null Object");
                    }
                } else {
                    // UtilityFunctions::print("Debug: Base type: ", base.get_type());
                    raise_error("Method call base is not an Object");
                }
            } else {            
                // Built-ins (Helpers for Statements that look like calls)
                if (s->method_name.nocasecmp_to("Connect") == 0 && call_args.size() == 3) {
                     Object *obj = call_args[0];
                     String signal_name = call_args[1];
                     String target_method = call_args[2];
                     
                     if (obj && owner) {
                          if (obj->has_signal(signal_name)) {
                              Callable callable = Callable(owner, target_method);
                              if (!obj->is_connected(signal_name, callable)) {
                                   obj->connect(signal_name, callable);
                              }
                          } else {
                              UtilityFunctions::print("Runtime Warning: Signal '", signal_name, "' not found on object");
                          }
                     }
                     break;
                }

                if (s->method_name.nocasecmp_to("Randomize") == 0) {
                    UtilityFunctions::randomize();
                    break;
                }
                if (s->method_name.nocasecmp_to("Beep") == 0) {
                    if (owner && Object::cast_to<Node>(owner)) {
                         Node *n = Object::cast_to<Node>(owner);
                         AudioStreamPlayer *player = memnew(AudioStreamPlayer);
                         AudioStreamWAV *wav = memnew(AudioStreamWAV);
                         wav->set_format(AudioStreamWAV::FORMAT_16_BITS);
                         wav->set_mix_rate(44100);
                         
                         int sample_rate = 44100;
                         float duration = 0.2f;
                         int frames = (int)(sample_rate * duration);
                         PackedByteArray pba;
                         pba.resize(frames * 2);
                         
                         for(int i=0; i<frames; i++) {
                              float t = (float)i / (float)sample_rate;
                              float wave = UtilityFunctions::sin(t * 880.0f * 2.0f * Math_PI); // 880Hz Beep
                              int16_t sample = (int16_t)(wave * 30000.0f);
                              pba.encode_s16(i * 2, sample);
                         }
                         
                         wav->set_data(pba);
                         player->set_stream(wav);
                         n->add_child(player);
                         player->play();
                         
                         // Auto-delete on finish
                         player->connect("finished", Callable(player, "queue_free"));
                    }
                    break;
                }
                if (s->method_name.nocasecmp_to("Sleep") == 0 && call_args.size() == 1) {
                     int ms = (int)call_args[0];
                     OS::get_singleton()->delay_msec(ms);
                     break;
                }
                if (s->method_name.nocasecmp_to("Shell") == 0 && call_args.size() >= 1) {
                     String cmd_line = call_args[0];
                     
                     String exe = "";
                     Array args;
                     int i = 0;
                     while(i < cmd_line.length() && cmd_line[i] == ' ') i++;
                     if (i < cmd_line.length()) {
                         if (cmd_line[i] == '"') {
                             i++;
                             while(i < cmd_line.length() && cmd_line[i] != '"') { exe += cmd_line[i]; i++; }
                             i++;
                         } else {
                             while(i < cmd_line.length() && cmd_line[i] != ' ') { exe += cmd_line[i]; i++; }
                         }
                     }
                     while(i < cmd_line.length()) {
                          while(i < cmd_line.length() && cmd_line[i] == ' ') i++; 
                          if (i >= cmd_line.length()) break;
                          String arg = "";
                          if (cmd_line[i] == '"') {
                               i++;
                               while(i < cmd_line.length() && cmd_line[i] != '"') { arg += cmd_line[i]; i++; }
                               i++;
                          } else {
                               while(i < cmd_line.length() && cmd_line[i] != ' ') { arg += cmd_line[i]; i++; }
                          }
                          args.push_back(arg);
                     }

                     OS::get_singleton()->execute(exe, args);
                     break;
                }
                if (s->method_name.nocasecmp_to("MkDir") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     DirAccess::make_dir_recursive_absolute(path);
                     break;
                }
                if (s->method_name.nocasecmp_to("RmDir") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     DirAccess::remove_absolute(path); // Or remove? remove_absolute likely maps to simple remove if folder? Godot behavior for DirAccess::remove on folder?
                     // Usually works on empty folder.
                     break;
                }
                
                // --- File System Extended ---
                if (s->method_name.nocasecmp_to("Kill") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     if (!path.begins_with("res://") && !path.begins_with("user://")) path = "user://" + path;
                     if (FileAccess::file_exists(path)) {
                         DirAccess::remove_absolute(path);
                     } else {
                         raise_error("File not found: " + path);
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("Name") == 0 && call_args.size() == 2) {
                     String p1 = call_args[0];
                     String p2 = call_args[1];
                     if (!p1.begins_with("res://") && !p1.begins_with("user://")) p1 = "user://" + p1;
                     if (!p2.begins_with("res://") && !p2.begins_with("user://")) p2 = "user://" + p2;
                     
                     if (DirAccess::rename_absolute(p1, p2) != OK) {
                         raise_error("Failed to rename file");
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("FileCopy") == 0 && call_args.size() == 2) {
                     String p1 = call_args[0];
                     String p2 = call_args[1];
                     if (!p1.begins_with("res://") && !p1.begins_with("user://")) p1 = "user://" + p1;
                     if (!p2.begins_with("res://") && !p2.begins_with("user://")) p2 = "user://" + p2;
                     
                     if (DirAccess::copy_absolute(p1, p2) != OK) {
                         raise_error("Failed to copy file");
                     }
                     break;
                }

                // --- Physics Commands ---
                if (s->method_name.nocasecmp_to("ApplyForce") == 0 && call_args.size() >= 3) {
                     Object *obj = call_args[0];
                     if (obj) {
                         double x = call_args[1];
                         double y = call_args[2];
                         if (obj->is_class("RigidBody2D")) {
                             Object::cast_to<RigidBody2D>(obj)->apply_force(Vector2(x, y));
                         } else if (obj->is_class("RigidBody3D")) {
                             double z = (call_args.size() >= 4) ? (double)call_args[3] : 0.0;
                             Object::cast_to<RigidBody3D>(obj)->apply_force(Vector3(x, y, z));
                         }
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("ApplyImpulse") == 0 && call_args.size() >= 3) {
                     Object *obj = call_args[0];
                     if (obj) {
                         double x = call_args[1];
                         double y = call_args[2];
                         if (obj->is_class("RigidBody2D")) {
                             Object::cast_to<RigidBody2D>(obj)->apply_impulse(Vector2(x, y));
                         } else if (obj->is_class("RigidBody3D")) {
                             double z = (call_args.size() >= 4) ? (double)call_args[3] : 0.0;
                             Object::cast_to<RigidBody3D>(obj)->apply_impulse(Vector3(x, y, z));
                         }
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("SetVelocity") == 0 && call_args.size() >= 3) {
                     Object *obj = call_args[0];
                     if (obj) {
                         double x = call_args[1];
                         double y = call_args[2];
                         if (obj->is_class("RigidBody2D")) {
                             Object::cast_to<RigidBody2D>(obj)->set_linear_velocity(Vector2(x, y));
                         } else if (obj->is_class("RigidBody3D")) {
                             double z = (call_args.size() >= 4) ? (double)call_args[3] : 0.0;
                             Object::cast_to<RigidBody3D>(obj)->set_linear_velocity(Vector3(x, y, z));
                         } else if (obj->is_class("CharacterBody2D")) {
                             Object::cast_to<CharacterBody2D>(obj)->set_velocity(Vector2(x, y));
                         } else if (obj->is_class("CharacterBody3D")) {
                             double z = (call_args.size() >= 4) ? (double)call_args[3] : 0.0;
                             Object::cast_to<CharacterBody3D>(obj)->set_velocity(Vector3(x, y, z));
                         }
                     }
                     break;
                }

                // --- Animation System ---
                if (s->method_name.nocasecmp_to("Animate") == 0 && call_args.size() >= 4) {
                     Object *obj = call_args[0];
                     String prop = call_args[1];
                     Variant val = call_args[2];
                     double dur = call_args[3];
                     
                     Node *n = Object::cast_to<Node>(obj);
                     if (n) {
                         // Property Aliasing for Tween
                         String actual_prop = prop;
                         if (prop == "Left") actual_prop = "position:x";
                         if (prop == "Top") actual_prop = "position:y";
                         if (prop == "Width") actual_prop = "size:x";
                         if (prop == "Height") actual_prop = "size:y";
                         if (prop == "Caption") actual_prop = "text";
                         if (prop == "Value") actual_prop = "value";
                         // Timer
                         if (n->is_class("Timer") && prop == "Interval") {
                             actual_prop = "wait_time";
                             val = (double)val / 1000.0;
                         }

                         Ref<Tween> tween = n->create_tween();
                         if (tween.is_valid()) {
                             tween->tween_property(n, actual_prop, val, dur);
                         }
                     }
                     break;
                }

                if (s->method_name.nocasecmp_to("MsgBox") == 0 && call_args.size() >= 1) {
                     String msg = call_args[0];
                     int buttons = 0;
                     if (call_args.size() >= 2) buttons = (int)call_args[1];
                     String title = "VisualGasic";
                     if (call_args.size() >= 3) title = call_args[2];

                     if (!owner || !Object::cast_to<Node>(owner)) {
                          break;
                     }
                     Node *root = Object::cast_to<Node>(owner);

                     AcceptDialog *dlg = nullptr;
                     bool is_confirm = false;

                     // Determine Dialog Type
                     if (buttons == 4 || buttons == 1) { // vbYesNo or vbOKCancel
                          ConfirmationDialog *cd = memnew(ConfirmationDialog);
                          if (buttons == 4) {
                               cd->get_ok_button()->set_text("Yes");
                               cd->get_cancel_button()->set_text("No");
                          }
                          dlg = cd;
                          is_confirm = true;
                     } else {
                          dlg = memnew(AcceptDialog);
                     }
                     
                     dlg->set_title(title);
                     dlg->set_text(msg);
                     root->add_child(dlg);

                     // Signal Magic
                     dlg->set_meta("result_ok", false);
                     dlg->connect("confirmed", Callable(dlg, "set_meta").bind("result_ok", true));

                     dlg->popup_centered();
                     
                     while (dlg->is_visible() && dlg->is_inside_tree()) {
                          DisplayServer::get_singleton()->process_events();
                          OS::get_singleton()->delay_msec(10);
                     }
                     
                     bool ok = (bool)dlg->get_meta("result_ok");
                     dlg->queue_free();
                     
                     // Return Value logic (though this is a Statement, VB6 MsgBox statement ignores return)
                     // If used as function, it's handled in expression parser.
                     // But here we might just block.
                     break;
                }

                // Persistence (Registry emulation via ConfigFile)
                if (s->method_name.nocasecmp_to("SaveSetting") == 0 && call_args.size() == 4) {
                     // SaveSetting(AppName, Section, Key, Value)
                     String app = call_args[0];
                     String section = call_args[1];
                     String key = call_args[2];
                     Variant val = call_args[3];
                     
                     Ref<ConfigFile> cfg;
                     cfg.instantiate();
                     String path = "user://vb_settings.cfg";
                     cfg->load(path); // Load existing
                     
                     // We prefix section with AppName to simulate registry structure
                     String real_section = app + "/" + section;
                     cfg->set_value(real_section, key, val);
                     cfg->save(path);
                     break;
                }

                // GetSetting and OpenDatabase moved to evaluate_expression as they return values.
                
                if (s->method_name.nocasecmp_to("SaveDatabase") == 0 && call_args.size() == 2) {
                     String path = call_args[0];
                     Variant data = call_args[1];
                     
                     if (!path.begins_with("res://") && !path.begins_with("user://")) {
                         path = "user://" + path;
                     }
                     Ref<FileAccess> f = FileAccess::open(path, FileAccess::WRITE);
                     if (f.is_valid()) {
                         String text = JSON::stringify(data, "\t");
                         f->store_string(text);
                     } else {
                         raise_error("Could not write to database: " + path);
                     }
                     break;
                }
                
                if (s->method_name.nocasecmp_to("LoadForm") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     if (!path.begins_with("res://")) path = "res://" + path;
                     
                     Ref<PackedScene> scene = ResourceLoader::get_singleton()->load(path);
                         if (scene.is_valid()) {
                         Node* new_form = scene->instantiate();
                         if (owner) {
                             Node* owner_node = Object::cast_to<Node>(owner);
                             if (owner_node && owner_node->is_inside_tree()) {
                                 SceneTree *tree = owner_node->get_tree();
                                 if (tree) {
                                     Node* root = tree->get_root();
                                     if (root) root->add_child(new_form);
                                 }
                             } else {
                                 // Not inside scene tree; skip adding for headless/test environments.
                             }
                         }
                     } else {
                         raise_error("Could not load form: " + path);
                     }
                     break;
                }

                if (s->method_name.nocasecmp_to("AddChild") == 0 && call_args.size() == 1) {
                     Object *obj = call_args[0];
                     Node *child = Object::cast_to<Node>(obj);
                     if (child && owner) {
                          Node *parent = Object::cast_to<Node>(owner);
                          if (parent) {
                               parent->add_child(child);
                               dynamic_nodes.push_back(child->get_instance_id());
                          }
                     }
                     break;
                }
                
                if (s->method_name.nocasecmp_to("CLS") == 0 || s->method_name.nocasecmp_to("ClearScreen") == 0) {
                     for(int i=0; i<dynamic_nodes.size(); i++) {
                         Object *obj = ObjectDB::get_instance(dynamic_nodes[i]);
                         if (obj) {
                             Node *n = Object::cast_to<Node>(obj);
                             if (n) n->queue_free();
                         }
                     }
                     dynamic_nodes.clear();
                     break;
                }
                
                // AI Helpers
                int cmd_ai = 0;
                Object *enemy = nullptr;
                Object *target = nullptr;
                double speed = 0;
                double stop_dist = 0;
                double radius = 0;
                Array points;
                bool loop = false;

                if (s->method_name.nocasecmp_to("AI_Chase") == 0 && call_args.size() >= 3) {
                    cmd_ai = 1;
                    enemy = call_args[0];
                    target = call_args[1];
                    speed = call_args[2];
                    if (call_args.size() >= 4) stop_dist = call_args[3];
                }
                else if (s->method_name.nocasecmp_to("AI_Wander") == 0 && call_args.size() >= 3) {
                    cmd_ai = 2;
                    enemy = call_args[0];
                    speed = call_args[1];
                    radius = call_args[2];
                }
                else if (s->method_name.nocasecmp_to("AI_Patrol") == 0 && call_args.size() >= 3) {
                     cmd_ai = 3;
                     enemy = call_args[0];
                     points = call_args[1];
                     speed = call_args[2];
                     if (call_args.size() >= 4) loop = call_args[3];
                }

                if (cmd_ai > 0 && enemy) {
                    Node *enemy_node = Object::cast_to<Node>(enemy);
                    if (enemy_node) {
                        GasicAIController *ai = nullptr;
                        TypedArray<Node> children = enemy_node->get_children();
                        for(int i=0; i<children.size(); i++) {
                            Node *c = Object::cast_to<Node>(children[i]);
                            if (c && c->is_class("GasicAIController")) {
                                ai = Object::cast_to<GasicAIController>(c);
                                break;
                            }
                        }
                        
                        if (!ai) {
                            ai = memnew(GasicAIController);
                            ai->set_name("GasicAI");
                            enemy_node->add_child(ai);
                        }
                        
                        if (cmd_ai == 1) ai->start_chase(target, speed, stop_dist);
                        if (cmd_ai == 2) ai->start_wander(speed, radius);
                        if (cmd_ai == 3) ai->start_patrol(points, speed, loop);
                    }
                    break;
                }
                
                if (s->method_name.nocasecmp_to("AI_Stop") == 0 && call_args.size() == 1) {
                }

                if (s->method_name.nocasecmp_to("AI_Stop") == 0 && call_args.size() == 1) {
                    Object *enemy = call_args[0];
                     if (enemy) {
                        Node *enemy_node = Object::cast_to<Node>(enemy);
                        if (enemy_node) {
                            TypedArray<Node> children = enemy_node->get_children();
                            for(int i=0; i<children.size(); i++) {
                                Node *c = Object::cast_to<Node>(children[i]);
                                if (c && c->is_class("GasicAIController")) {
                                    GasicAIController *ai = Object::cast_to<GasicAIController>(c);
                                    ai->stop();
                                    break;
                                }
                            }
                        }
                     }
                     break;
                }

                // Helper to create simple text label
                if (s->method_name.nocasecmp_to("CreateText") == 0 && call_args.size() >= 3) {
                     // CreateText(text, x, y, [out_var]) -> But this is a statement, so "CreateText "Hello", 10, 10"
                     // Ideally it returns the label object if possible?
                     // Commands in Basic usually don't return.
                     // But we can implement it as:
                     // Dim l
                     // Set l = CreateText("Hello", 10, 10) -> In Expression Evaluator?
                     // Let's implement it in Expression Evaluator instead.
                }

                if (s->method_name.nocasecmp_to("ChangeScene") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     if (owner) {
                          Node *n = Object::cast_to<Node>(owner);
                          if (n) {
                               SceneTree *tree = n->get_tree();
                               if (tree) {
                                    tree->change_scene_to_file(path);
                               }
                          }
                     }
                     break;
                }

                // Audio Helpers
                if (s->method_name.nocasecmp_to("PlayMusic") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     Ref<AudioStream> stream = ResourceLoader::get_singleton()->load(path);
                     if (stream.is_valid() && owner) {
                          Node *n = Object::cast_to<Node>(owner);
                          if (n) {
                               // Check existing
                               if (n->has_meta("__BG_MUSIC__")) {
                                   Object *old = n->get_meta("__BG_MUSIC__");
                                   if (old) {
                                       Node *old_n = Object::cast_to<Node>(old);
                                       if (old_n) old_n->queue_free();
                                   }
                               }
                               
                               AudioStreamPlayer *p = memnew(AudioStreamPlayer);
                               p->set_stream(stream);
                               p->set_autoplay(true);
                               // Loop? Resource loop mode determines it usually, or we can explicit loop.
                               // Godot 4: Loop is property of AudioStream (import settings) or WAV/OGG resource.
                               n->add_child(p);
                               n->set_meta("__BG_MUSIC__", p);
                          }
                     }
                     break;
                }

                if (s->method_name.nocasecmp_to("StopMusic") == 0) {
                     if (owner) {
                         Node *n = Object::cast_to<Node>(owner);
                         if (n && n->has_meta("__BG_MUSIC__")) {
                             Object *old = n->get_meta("__BG_MUSIC__");
                             if (old) {
                                  Node *old_n = Object::cast_to<Node>(old);
                                  if (old_n) old_n->queue_free();
                             }
                             n->remove_meta("__BG_MUSIC__");
                         }
                     }
                     break;
                }

                if (s->method_name.nocasecmp_to("AddMenuItem") == 0 && call_args.size() >= 3) {
                     Object *menu_obj = call_args[0];
                     if (menu_obj && menu_obj->is_class("PopupMenu")) {
                         PopupMenu *pm = Object::cast_to<PopupMenu>(menu_obj);
                         String text = call_args[1];
                         String callback = call_args[2];
                         
                         pm->add_item(text);
                         int idx = pm->get_item_count() - 1;
                         // Logic to bind index?
                         // We can bind "id_pressed(int)" to a dispatcher.
                         // But we need to know WHICH item triggered.
                         // Simple approach: Map ID to Callback name in metadata?
                         
                         // Or connect "id_pressed" to _OnSignal, and let it pass the ID.
                         // But we want to call specific callback.
                         
                         // Let's use metadata on the PopupMenu: Map<ID, CallbackName>
                         Dictionary callback_map;
                         if (pm->has_meta("callbacks")) {
                             callback_map = pm->get_meta("callbacks");
                         } else {
                             // First time: connect signal
                             pm->connect("id_pressed", Callable(owner, "_OnSignal").bind(pm->get_name(), "MenuClick")); 
                             // Wait, name of popup might be auto gen.
                         }
                         
                         // Let's assume the user handles "Menu_MenuClick(ID)".
                         // But user asked for specific callback.
                         // "Sub File_New_Click()"
                         
                         // We can store the callback name in the Item Meta?
                         // PopupMenu doesn't support item metadata easily until Godot 4.x?
                         // set_item_metadata(idx, metadata)
                         pm->set_item_metadata(idx, callback);
                         
                         // Ensure handler is connected
                         if (!pm->is_connected("id_pressed", Callable(owner, "_OnSignal"))) {
                             // Bind "Menu" as Name, "Click" as Event.
                             // But we need to dispatch dynamically based on metadata.
                             // Complex.
                             // Workaround: We bind to a special internal handler?
                             // No, let's use the Metadata approach.
                             // Modify _OnSignal to check for metadata if the sender is a PopupMenu?
                             // Or just bind to "Menu" and let VB user write:
                             // Sub Menu_MenuClick(ID)
                             //    Select Case ID ...
                             // End Sub
                             
                             // User Request: "AddMenuItem(Menu, Text, CallbackName)"
                             // This implies the callback is specific.
                             // VB6 style was Menu Editor -> Name -> Sub Name_Click().
                             
                             // Let's support: "Sub MyCallbackname(ItemText)"
                             // We need a trampoline.
                             // Let's rely on _OnSignal intercepting.
                         }
                         
                         // Store callback name in a Dictionary in the Menu object Meta
                         callback_map[idx] = callback;
                         pm->set_meta("callbacks", callback_map);
                     }
                     break;
                }
                
                if (s->method_name.nocasecmp_to("MoveAndSlide") == 0 && call_args.size() >= 1) {
                     Object *obj = call_args[0];
                     CharacterBody2D *cb2d = Object::cast_to<CharacterBody2D>(obj);
                     if (cb2d) {
                         cb2d->move_and_slide();
                         break;
                     }
                     CharacterBody3D *cb3d = Object::cast_to<CharacterBody3D>(obj);
                     if (cb3d) {
                         cb3d->move_and_slide();
                         break;
                     }
                     break;
                }

                if (s->method_name.nocasecmp_to("PlaySound") == 0 && call_args.size() == 1) {
                     String path = call_args[0];
                     Ref<AudioStream> stream = ResourceLoader::get_singleton()->load(path);
                     if (stream.is_valid() && owner) {
                          Node *n = Object::cast_to<Node>(owner);
                          if (n) {
                               AudioStreamPlayer *p = memnew(AudioStreamPlayer);
                               p->set_stream(stream);
                               p->set_autoplay(true);
                               // Auto-free when done? Not built-in for simple player.
                               // For now, just add child. It will leak if we spawn tons.
                               // Real BASIC engines manage channels.
                               // We can set it to free on finish signal?
                               // Connect "finished" to "queue_free".
                               p->connect("finished", Callable(p, "queue_free"));
                               n->add_child(p);
                          }
                     }
                     break;
                }
                
                if (s->method_name.nocasecmp_to("PlayTone") == 0 && call_args.size() >= 2) {
                    double freq = (double)call_args[0];
                    double dur_ms = (double)call_args[1];
                    int waveform = 0; // Sine default
                    if (call_args.size() >= 3) waveform = (int)call_args[2];

                    Ref<AudioStreamWAV> stream;
                    stream.instantiate();
                    
                    int mix_rate = 44100;
                    stream->set_mix_rate(mix_rate);
                    stream->set_format(AudioStreamWAV::FORMAT_16_BITS);
                    stream->set_stereo(false); // Mono

                    int samples = (int)(dur_ms * mix_rate / 1000.0);
                    if (samples > 0) {
                        PackedByteArray data;
                        data.resize(samples * 2); // 16-bit = 2 bytes

                        for (int i = 0; i < samples; ++i) {
                            double t = (double)i / mix_rate;
                            double val = 0.0;
                            // Use explicit PI constant
                            const double PI = 3.14159265358979323846;
                            
                            switch (waveform) {
                                case 1: // Square
                                    val = (sin(2.0 * PI * freq * t) > 0) ? 1.0 : -1.0;
                                    break;
                                case 2: // Sawtooth
                                    val = 2.0 * (t * freq - floor(t * freq + 0.5));
                                    break;
                                case 3: // Noise
                                    val = ((double)rand() / RAND_MAX) * 2.0 - 1.0; 
                                    break;
                                default: // Sine
                                    val = sin(2.0 * PI * freq * t);
                                    break;
                            }
                            
                            val *= 0.5; // Avoid clipping

                            int16_t sample_int = (int16_t)(val * 32767.0);
                            data[i * 2] = (uint8_t)(sample_int & 0xFF);
                            data[i * 2 + 1] = (uint8_t)((sample_int >> 8) & 0xFF);
                        }
                        stream->set_data(data);
                    }

                    if (owner) {
                         Node *n = Object::cast_to<Node>(owner);
                         if (n) {
                              AudioStreamPlayer *p = memnew(AudioStreamPlayer);
                              p->set_stream(stream);
                              p->set_autoplay(true);
                              p->connect("finished", Callable(p, "queue_free"));
                              n->add_child(p);
                         }
                    }
                     break;
                }

                // --- Immediate Drawing Commands ---
                // Works when called from OnDraw event
                if (s->method_name.nocasecmp_to("DrawLine") == 0 && call_args.size() >= 4) {
                     // DrawLine(x1, y1, x2, y2, [color], [width])
                     double x1 = call_args[0]; double y1 = call_args[1];
                     double x2 = call_args[2]; double y2 = call_args[3];
                     Color c = (call_args.size() > 4) ? (Color)call_args[4] : Color(1,1,1);
                     float width = (call_args.size() > 5) ? (float)call_args[5] : 1.0f;
                     
                     if (owner) {
                          CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                          if (ci) ci->draw_line(Vector2(x1, y1), Vector2(x2, y2), c, width);
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("DrawRect") == 0 && call_args.size() >= 4) {
                     // DrawRect(x, y, w, h, [color], [filled])
                     double x = call_args[0]; double y = call_args[1];
                     double w = call_args[2]; double h = call_args[3];
                     Color c = (call_args.size() > 4) ? (Color)call_args[4] : Color(1,1,1);
                     bool filled = (call_args.size() > 5) ? (bool)call_args[5] : true;
                     
                     if (owner) {
                          CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                          if (ci) ci->draw_rect(Rect2(x, y, w, h), c, filled);
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("DrawCircle") == 0 && call_args.size() >= 3) {
                     // DrawCircle(x, y, radius, [color])
                     double x = call_args[0]; double y = call_args[1];
                     float r = call_args[2];
                     Color c = (call_args.size() > 3) ? (Color)call_args[3] : Color(1,1,1);
                     
                     if (owner) {
                          CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                          if (ci) ci->draw_circle(Vector2(x,y), r, c);
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("DrawPixel") == 0 || s->method_name.nocasecmp_to("PSet") == 0) {
                     // PSet(x, y, color)
                     if (call_args.size() >= 3) {
                          double x = call_args[0]; double y = call_args[1];
                          Color c = call_args[2];
                          if (owner) {
                               CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                               // draw_primitive needs arrays. simpler to use draw_rect 1x1
                               if (ci) ci->draw_rect(Rect2(x, y, 1, 1), c, true);
                          }
                     }
                     break;
                }

                // --- 3D Primitive Shapes ---
                if (s->method_name.nocasecmp_to("CreateCube") == 0 && call_args.size() >= 3) {
                     // CreateCube(sx, sy, sz, [px, py, pz], [color])
                     // Arguments are complex to parse optionally, so let's check size.
                     double sx = call_args[0]; double sy = call_args[1]; double sz = call_args[2];
                     
                     MeshInstance3D *mi = memnew(MeshInstance3D);
                     Ref<BoxMesh> box; box.instantiate();
                     box->set_size(Vector3(sx, sy, sz));
                     
                     // Optional Color -> Material
                     int last_arg_idx = call_args.size() - 1;
                     if (call_args[last_arg_idx].get_type() == Variant::COLOR) {
                         Ref<StandardMaterial3D> mat; mat.instantiate();
                         mat->set_albedo((Color)call_args[last_arg_idx]);
                         box->set_material(mat);
                     }
                     
                     mi->set_mesh(box);
                     
                     // Position?
                     if (call_args.size() >= 6) { 
                         double px = call_args[3]; double py = call_args[4]; double pz = call_args[5];
                         mi->set_position(Vector3(px, py, pz));
                     }
                     
                     if (owner) {
                         Node* n = Object::cast_to<Node>(owner);
                         if (n) { n->add_child(mi); dynamic_nodes.push_back(mi->get_instance_id()); }
                     }
                     break;
                }
                
                if (s->method_name.nocasecmp_to("CreateSphere") == 0 && call_args.size() >= 1) {
                     float r = call_args[0];
                     
                     MeshInstance3D *mi = memnew(MeshInstance3D);
                     Ref<SphereMesh> sphere; sphere.instantiate();
                     sphere->set_radius(r);
                     sphere->set_height(r * 2);
                     
                     // Optional Color
                     int last_arg_idx = call_args.size() - 1;
                     if (call_args.size() > 1 && call_args[last_arg_idx].get_type() == Variant::COLOR) {
                         Ref<StandardMaterial3D> mat; mat.instantiate();
                         mat->set_albedo((Color)call_args[last_arg_idx]);
                         sphere->set_material(mat);
                     }
                     
                     if (call_args.size() >= 4) {
                         mi->set_position(Vector3(call_args[1], call_args[2], call_args[3]));
                     }
                     
                     mi->set_mesh(sphere);
                     
                     if (owner) {
                         Node* n = Object::cast_to<Node>(owner);
                         if (n) { n->add_child(mi); dynamic_nodes.push_back(mi->get_instance_id()); }
                     }
                     break;
                }

                // Shader Helpers
                if (s->method_name.nocasecmp_to("SetShader") == 0 && call_args.size() == 2) {
                     // SetShader(node, shader_or_null)
                     Object *obj = call_args[0];
                     CanvasItem *ci = Object::cast_to<CanvasItem>(obj);
                     if (ci) {
                         Variant sh = call_args[1];
                         if (sh.get_type() == Variant::OBJECT) {
                              Object *check_obj = sh;
                              if (check_obj) {
                                  Ref<Shader> shader = sh;
                                  if (shader.is_valid()) {
                                      Ref<ShaderMaterial> mat;
                                      mat.instantiate();
                                      mat->set_shader(shader);
                                      ci->set_material(mat);
                                  } else {
                                      // Maybe they passed a material?
                                      Ref<Material> mat_res = sh;
                                      if (mat_res.is_valid()) {
                                          ci->set_material(mat_res);
                                      }
                                  }
                              } else {
                                   // Null object variant
                                   ci->set_material(Ref<Material>());
                              }
                         } else {
                              // Clear shader if not object
                              ci->set_material(Ref<Material>());
                         }
                     }
                     break;
                }
                
                // Screen & Window
                if (s->method_name.nocasecmp_to("SetTitle") == 0 && call_args.size() == 1) {
                     String title = call_args[0];
                     if (owner) {
                          Node *n = Object::cast_to<Node>(owner);
                          if (n) {
                              Window *w = n->get_window();
                              if (w) w->set_title(title);
                          }
                     }
                     break;
                }
                if (s->method_name.nocasecmp_to("SetScreenSize") == 0 && call_args.size() == 2) {
                     int w_val = call_args[0];
                     int h_val = call_args[1];
                     if (owner) {
                          Node *n = Object::cast_to<Node>(owner);
                          if (n) {
                              Window *w = n->get_window();
                              if (w) w->set_size(Vector2i(w_val, h_val));
                          }
                     }
                     break;
                }
                
                // Text Drawing (Basic)
                if (s->method_name.nocasecmp_to("DrawText") == 0 && call_args.size() >= 2) {
                     // DrawText(pos, text, [color])
                     if (owner) {
                          CanvasItem *ci = Object::cast_to<CanvasItem>(owner);
                          if (ci) {
                               Vector2 pos = call_args[0];
                               String text = call_args[1];
                               Color col = Color(1,1,1,1);
                               if (call_args.size() > 2) col = call_args[2];
                               
                               // Get Default Font?
                               // ThemeDB does not exist in 4.x GDExtension bindings yet sometimes?
                               // Or maybe use Label's default font.
                               // Let's rely on CanvasItem default font logic which requires a font to be passed.
                               // Use ThemeDB::get_singleton()->get_fallback_font()
                               Ref<Font> font;
                               // We need to support loading font or uses default.
                               // For now, let's skip font arg and use a simple debug approach.
                               // If we can't get a font, we can't draw string easily in GDExtension without creating one.
                               // Actually, let's try to load a default font if user didn't provide one?
                               // Or just expose "LoadFont".
                               
                               // For this iteration, let's assume we need a font to draw string properly or it might fail/print nothing.
                               // But wait, Debug draw usually works.
                               ci->draw_string(Ref<Font>(), pos, text, HorizontalAlignment::HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col);
                          }
                     }
                     break;
                }

                // Try Internal Call
                bool found = false;
                call_internal(s->method_name, call_args, found);
                
                if (!found) {
                    if (owner) {
                        if (owner->has_method(s->method_name)) {
                             owner->callv(s->method_name, call_args);
                        } else {
                             UtilityFunctions::print("Runtime Error: Object does not have method ", s->method_name);
                        }
                    } else {
                         raise_error("No owner for method call");
                    }
                }
            }
            break;
        }
        case STMT_RAISE: {
             RaiseStatement* s = (RaiseStatement*)stmt;
             Variant v_code = evaluate_expression(s->error_code);
             int code = (int)v_code;
             String msg = "Application error";
             if (s->message) {
                 msg = (String)evaluate_expression(s->message);
             }
             raise_error(msg, code);
             break;
        }
        case STMT_WHENEVER_SECTION: {
            WheneverSectionStatement* s = (WheneverSectionStatement*)stmt;
            
            WheneverSection section;
            section.section_name = s->section_name;
            section.variable_name = s->variable_name;
            section.comparison_operator = s->comparison_operator;
            section.callback_procedures = s->callback_procedures;  // Copy all callbacks
            section.condition_expression = s->condition_expression;  // Copy expression reference
            
            // Set scope information
            if (s->is_local_scope) {
                section.scope_type = "local";
                section.scope_context = current_sub ? current_sub->name : "global";
            } else {
                section.scope_type = "global";
                section.scope_context = "";
            }
            
            section.is_active = true;
            
            if (s->comparison_value) {
                section.comparison_value = evaluate_expression(s->comparison_value);
            }
            
            if (s->comparison_value2) {
                section.comparison_value2 = evaluate_expression(s->comparison_value2);
            }
            
            // Initialize last_value with current variable value
            Variant current_value;
            if (get_variable(s->variable_name, current_value)) {
                section.last_value = current_value;
            }
            
            whenever_sections.push_back(section);
            break;
        }
        case STMT_SUSPEND_WHENEVER: {
            SuspendWheneverStatement* s = (SuspendWheneverStatement*)stmt;
            
            for (int i = 0; i < whenever_sections.size(); i++) {
                if (whenever_sections[i].section_name == s->section_name) {
                    whenever_sections.write[i].is_active = false;
                    break;
                }
            }
            break;
        }
        case STMT_RESUME_WHENEVER: {
            ResumeWheneverStatement* s = (ResumeWheneverStatement*)stmt;
            
            for (int i = 0; i < whenever_sections.size(); i++) {
                if (whenever_sections[i].section_name == s->section_name) {
                    whenever_sections.write[i].is_active = true;
                    break;
                }
            }
            break;
        }
        case STMT_TRY: {
            TryStatement* s = (TryStatement*)stmt;
            
            // Execute Try Block
            for(int i=0; i<s->try_block.size(); i++) {
                execute_statement(s->try_block[i]);
                if (error_state.has_error && error_state.mode == ErrorState::NONE) break; // Runtime Error
                if (error_state.mode != ErrorState::NONE && error_state.mode != ErrorState::GOTO_LABEL) break; // Break/Return/Exit
            }
            
            bool error_handled = false;
            if (error_state.has_error && error_state.mode == ErrorState::NONE) {
                 // Check if we need to capture the exception in a variable
                 if (!s->catch_var_name.is_empty()) {
                      Dictionary ex;
                      ex["Description"] = error_state.message;
                      ex["Number"] = error_state.code;
                      ex["Source"] = "VisualGasic"; 
                      assign_variable(s->catch_var_name, ex);
                 }

                 error_state.has_error = false; // Caught
                 error_handled = true;
                 
                 for(int i=0; i<s->catch_block.size(); i++) {
                     execute_statement(s->catch_block[i]);
                     if (error_state.has_error || error_state.mode != ErrorState::NONE) break;
                 }
            }
            
            // Finally Block
            ErrorState backup_state = error_state;
            
            // Temporarily clear state to run finally
            // If finally succeeds, we restore backup_state.
            // If finally fails/returns, it overwrites backup_state.
            
            error_state.has_error = false;
            error_state.mode = ErrorState::NONE;
            
            for(int i=0; i<s->finally_block.size(); i++) {
                 execute_statement(s->finally_block[i]);
                 if (error_state.has_error || error_state.mode != ErrorState::NONE) break;
            }
            
            if (!error_state.has_error && error_state.mode == ErrorState::NONE) {
                 // Restore previous state (e.g. Return from Try block, or Error propagated if not caught)
                 error_state = backup_state;
            }
            
            break;
        }
        case STMT_LABEL: break;
        case STMT_GOTO: {
             GotoStatement* s = (GotoStatement*)stmt;
             if (current_sub && current_sub->label_map.has(s->label_name)) {
                 jump_target = (int)current_sub->label_map[s->label_name] - 1;
             } else {
                 raise_error("Label not found: " + s->label_name);
             }
             break;
        }
        case STMT_ON_ERROR: {
             OnErrorStatement* s = (OnErrorStatement*)stmt;
             if (s->mode == OnErrorStatement::RESUME_NEXT) {
                 error_state.mode = ErrorState::RESUME_NEXT;
             } else {
                 error_state.mode = ErrorState::GOTO_LABEL;
                 error_state.label = s->label_name;
             }
             break;
        }
        case STMT_LOAD_DATA: {
            LoadDataStatement* s = (LoadDataStatement*)stmt;
            Variant v_path = evaluate_expression(s->path_expression);
            String path = v_path;
            
            if (!FileAccess::file_exists(path)) {
                 raise_error("LoadData: File not found: " + path, 200);
                 break;
            }
            
            Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
            if (file.is_null()) {
                raise_error("LoadData: Could not open file: " + path, 201);
                break;
            }
            
            String content = file->get_as_text();
            file->close();
            
            // Parse using static helper
            Vector<ExpressionNode*> new_data = VisualGasicParser::parse_data_values_from_text(content);
            
            // Append to data_segments
            // IMPORTANT: Who owns these new nodes? 
            // We should add them to a cleanup list in Instance.
            for(int i=0; i<new_data.size(); i++) {
                data_segments.push_back(new_data[i]);
                runtime_data_nodes.push_back(new_data[i]);
            }
            
            break;
        }
        case STMT_SELECT: {
            SelectStatement* s = (SelectStatement*)stmt;
            Variant val = evaluate_expression(s->expression);
            
            for(int i=0; i<s->cases.size(); i++) {
                CaseBlock* block = s->cases[i];
                bool match = false;
                
                if (block->is_else) {
                    match = true;
                } else {
                    for(int j=0; j<block->values.size(); j++) {
                        Variant c = evaluate_expression(block->values[j]);
                        bool valid; Variant res;
                        Variant::evaluate(Variant::OP_EQUAL, val, c, res, valid);
                        if (res.booleanize()) {
                            match = true;
                            break;
                        }
                    }
                }
                
                if (match) {
                    for(int k=0; k<block->body.size(); k++) execute_statement(block->body[k]);
                    break;
                }
            }
            break;
        }
        case STMT_SEEK: {
            SeekStatement* s = (SeekStatement*)stmt;
            int fn = (int)evaluate_expression(s->file_number);
            int pos = (int)evaluate_expression(s->position);
            
            if (open_files.has(fn)) {
                Ref<FileAccess> fa = open_files[fn];
                fa->seek(pos); // In Godot, seek is absolute from beginning
                if (fa->get_error() != Error::OK) {
                   raise_error("Seek Failed", 53); // File not found or IO Error? 53 is generic file error
                }
            } else {
                raise_error("Bad File Number", 52);
            }
            break;
        }
        case STMT_KILL: {
            KillStatement* s = (KillStatement*)stmt;
            String path = evaluate_expression(s->path);
            Error err = DirAccess::remove_absolute(path);
            if (err != Error::OK) {
                // If relative to "user://" implied? No, default behavior is exact path.
                // Try ProjectSettings globalize_path?
                // For now, raw path.
                raise_error("Kill Failed (Error " + String::num(err) + "): " + path, 53);
            }
            break;
        }
        case STMT_RAISE_EVENT: {
            RaiseEventStatement* s = (RaiseEventStatement*)stmt;
            if (owner) {
                // Check if signal exists on script?
                // Actually emit_signal checks this.
                // We need to pass args.
                // Godot's emit_signal takes variadic, but in C++ it's emit_signal(name, val1, val2...)
                // We have a version taking an array of variants? No?
                // We must use callv or similar?
                // Object::emit_signal is vararg.
                // But we can call "emit_signal" via call() which takes varargs?
                // Actually internal emit_signal takes a const Variant **p_args, int p_argcount.
                
                // Let's assume max args or use a helper. 
                // Using call("emit_signal", "name", arg1...) is clumsy.
                // AccessObject::get_internal_ptr(owner)->emit_signal(...)
                
                // Workaround: Use 'emit_signal' method dynamic call.
                // It requires arguments.
                
                Array args;
                args.push_back(s->expression_name);
                for(int i=0; i<s->arguments.size(); i++) {
                     args.push_back(evaluate_expression(s->arguments[i]));
                }
                
                bool err=false;
                // We can't easily call emit_signal with array without callv, but Object doesn't expose callv for everything.
                // Actually Object::emit_signal acts like a method.
                // But wait! There is no 'callv' on Object in C++.
                // We can use emit_signal exposed in godot-cpp, but it is variadic template.
                // We can't spread an array.
                
                // Fallback: Use 'emit_signal' via call()? No, emit_signal is not a script method usually.
                // However, GDScript `emit_signal` IS a method.
                // Correct way in GDExtension:
                int argc = args.size() - 1; // First is name
                StringName sname = s->expression_name;
                
                if (argc == 0) owner->emit_signal(sname);
                else if (argc == 1) owner->emit_signal(sname, args[1]);
                else if (argc == 2) owner->emit_signal(sname, args[1], args[2]);
                else if (argc == 3) owner->emit_signal(sname, args[1], args[2], args[3]);
                else if (argc == 4) owner->emit_signal(sname, args[1], args[2], args[3], args[4]);
                else if (argc == 5) owner->emit_signal(sname, args[1], args[2], args[3], args[4], args[5]);
                // Limit 5 args for now.
            }
            break;
        }


        case STMT_EXIT: {
            ExitStatement* s = (ExitStatement*)stmt;
            if (s->exit_type == ExitStatement::EXIT_SUB || s->exit_type == ExitStatement::EXIT_FUNCTION) {
                error_state.mode = ErrorState::EXIT_SUB;
            } else if (s->exit_type == ExitStatement::EXIT_FOR) {
                error_state.mode = ErrorState::EXIT_FOR;
            } else if (s->exit_type == ExitStatement::EXIT_DO) {
                error_state.mode = ErrorState::EXIT_DO;
            }
            error_state.has_error = true; // Signal interruption flow
            break;
        }
        case STMT_REDIM: {
            ReDimStatement* s = (ReDimStatement*)stmt;
            
            // Calculate Dims
            Vector<int> dims;
            for(int i=0; i<s->array_sizes.size(); i++) {
                dims.push_back((int)evaluate_expression(s->array_sizes[i]) + 1); // 0..N
            }
            
            if (s->preserve) {
                if (!variables.has(s->variable_name)) {
                     raise_error("ReDim Preserve require existing array");
                     break;
                }
                Variant v = variables[s->variable_name];
                if (v.get_type() != Variant::ARRAY) {
                    raise_error("Variable is not an array");
                    break;
                }
                
                // Only support 1D preserve for now (or recursion later?)
                // Support multi-dim preserve of LAST dimension is standard only.
                if (dims.size() == 1) {
                    Array arr = v;
                    arr.resize(dims[0]);
                    // Godot fills new with null. We might want defaults if we knew the type.
                    // But we don't track type metadata in Variant well.
                    // Assume user handles nulls or we accept nulls as 0/"" in future ops.
                    variables[s->variable_name] = arr;
                } else {
                    raise_error("ReDim Preserve only supported for 1D arrays currently");
                }
            } else {
                 // Clone ArrayBuilder logic
                 struct LocalArrayBuilder {
                    static Array create(const Vector<int>& d, int depth, const String& type_name, const Dictionary& prototypes) {
                         Array a;
                         int size = d[depth];
                         a.resize(size);
                         if (depth < d.size() - 1) {
                             for(int i=0; i<size; i++) {
                                 a[i] = create(d, depth+1, type_name, prototypes);
                             }
                         } else {
                             // Leaf: Try to init structs, otherwise null
                             if (!type_name.is_empty() && prototypes.has(type_name)) {
                                 for(int i=0; i<size; i++) {
                                     a[i] = ((Dictionary)prototypes[type_name]).duplicate(true);
                                 }
                             }
                         }
                         return a;
                    }
                };
                
                // We don't have type info in ReDimStatement directly in current Parser.
                // Assuming Variant arrays (nulls) unless we track variable types separately.
                // For now, type_name is empty.
                variables[s->variable_name] = LocalArrayBuilder::create(dims, 0, "", struct_prototypes);
            }
            break;
        }
        case STMT_OPEN: {
            OpenStatement* s = (OpenStatement*)stmt;
            String path = evaluate_expression(s->path);
            int fn = evaluate_expression(s->file_number);
            
            if (open_files.has(fn)) {
                raise_error("File already open: " + String::num(fn));
                break;
            }
            
            Ref<FileAccess> fa;
            if (s->mode == OpenStatement::MODE_INPUT) fa = FileAccess::open(path, FileAccess::READ);
            else if (s->mode == OpenStatement::MODE_OUTPUT) fa = FileAccess::open(path, FileAccess::WRITE);
            else if (s->mode == OpenStatement::MODE_APPEND) {
                 if (FileAccess::file_exists(path)) {
                     fa = FileAccess::open(path, FileAccess::READ_WRITE);
                     if (fa.is_valid()) fa->seek_end();
                 } else {
                     fa = FileAccess::open(path, FileAccess::WRITE);
                 }
            }
            
            if (fa.is_null()) { 
                 raise_error("Failed to open file: " + path);
            } else {
                 open_files[fn] = fa;
            }
            break;
        }
        case STMT_CLOSE: {
             CloseStatement* s = (CloseStatement*)stmt;
             if (s->file_number) {
                 int fn = evaluate_expression(s->file_number);
                 if (open_files.has(fn)) {
                      open_files.erase(fn); 
                 }
             } else {
                 open_files.clear();
             }
             break;
        }
        case STMT_INPUT: {
            InputStatement* s = (InputStatement*)stmt;
            if (s->file_number) {
                int fn = evaluate_expression(s->file_number);
                if (open_files.has(fn)) {
                    Ref<FileAccess> fa = open_files[fn];
                    if (s->is_line_input) {
                        String line = fa->get_line();
                        if (s->variables.size() > 0) {
                             assign_to_target(s->variables[0], line);
                        }
                    } else {
                        PackedStringArray values = fa->get_csv_line();
                        for(int i=0; i<s->variables.size() && i<values.size(); i++) {
                             Variant val = values[i];
                             if (String(val).is_valid_float()) val = String(val).to_float(); 
                             assign_to_target(s->variables[i], val); 
                        }
                    }
                } else {
                    raise_error("Bad File Name or Number");
                }
            }
            break;
        }
        case STMT_NAME: {
            NameStatement* s = (NameStatement*)stmt;
            String old_path = evaluate_expression(s->old_path);
            String new_path = evaluate_expression(s->new_path);
            Error err = DirAccess::rename_absolute(old_path, new_path);
            if (err != Error::OK) {
                raise_error("Name (Rename) Failed (Error " + String::num(err) + "): " + old_path + " -> " + new_path, 53);
            }
            break;
        }
        
        // === MULTITASKING STATEMENT EXECUTION ===
        case STMT_ASYNC_FUNCTION: {
            AsyncFunctionStatement* s = (AsyncFunctionStatement*)stmt;
            execute_async_function(s);
            break;
        }
        case STMT_AWAIT: {
            // This would be handled in expression evaluation, but could be a statement too
            break;
        }
        case STMT_TASK_RUN: {
            TaskRunStatement* s = (TaskRunStatement*)stmt;
            execute_task_run(s);
            break;
        }
        case STMT_TASK_WAIT: {
            TaskWaitStatement* s = (TaskWaitStatement*)stmt;
            execute_task_wait(s);
            break;
        }
        case STMT_PARALLEL_FOR: {
            ParallelForStatement* s = (ParallelForStatement*)stmt;
            execute_parallel_for(s);
            break;
        }
        case STMT_PARALLEL_SECTION: {
            ParallelSectionStatement* s = (ParallelSectionStatement*)stmt;
            execute_parallel_section(s);
            break;
        }
        
        case STMT_PATTERN_MATCH: {
            PatternMatchStatement* s = (PatternMatchStatement*)stmt;
            execute_pattern_match(s);
            break;
        }
        
        default: break;
    }
}

Variant VisualGasicInstance::call_internal(const String& p_method, const Array& p_args, bool &r_found) {
    r_found = false;
    if (!script.is_valid() || !script->ast_root) return Variant();

    SubDefinition *func = nullptr;
    for(int i=0; i<script->ast_root->subs.size(); i++) {
        if (script->ast_root->subs[i]->name.nocasecmp_to(p_method) == 0) {
            func = script->ast_root->subs[i];
            break;
        }
    }
    
    if (!func) return Variant();
    r_found = true;

    // Save Context
    SubDefinition* prev_sub = current_sub;
    int prev_jump = jump_target;
    ErrorState prev_error = error_state;
    
    // Arguments
    int max_params = func->parameters.size();
    // Use larger size if params exist, or args exist.
    // Actually we iterate params to define them.
    for(int i=0; i<max_params; i++) {
        Parameter& param = func->parameters.write[i];
        
        if (param.is_param_array) {
            Array rest;
            for(int k=i; k<p_args.size(); k++) {
                rest.push_back(p_args[k]);
            }
            variables[param.name] = rest;
            break; // ParamArray is always the last argument
        }
        
        if (i < p_args.size()) {
            Variant val = p_args[i];
             // Enforce Parameter Type
            if (!param.type_hint.is_empty()) {
                String t = param.type_hint.to_lower();
                if (t == "integer" || t == "long") val = (int64_t)val;
                else if (t == "single" || t == "double") val = (double)val;
                else if (t == "string") val = (String)val;
                else if (t == "boolean") val = (bool)val;
            }
            variables[param.name] = val;
        } else {
            if (param.is_optional) {
                variables[param.name] = param.default_value;
            } else {
                 UtilityFunctions::print("Runtime Error: Argument '", param.name, "' missing for ", func->name);
                 variables[param.name] = Variant(); // Default to Nil
            }
        }
    }
    
    // Init Return
    if (func->type == SubDefinition::TYPE_FUNCTION) {
        Variant init_val = Variant();
        if (!func->return_type.is_empty()) {
             String t = func->return_type.to_lower();
             if (t == "integer" || t == "long") init_val = (int64_t)0;
             else if (t == "single" || t == "double") init_val = 0.0;
             else if (t == "string") init_val = "";
             else if (t == "boolean") init_val = false;
        }
        variables[func->name] = init_val;
    }

    current_sub = func;
    error_state.mode = ErrorState::NONE;
    error_state.has_error = false;
    error_state.label = "";
    
    // Execute Loop
    for(int i=0; i<func->statements.size(); i++) {
        jump_target = -1;
        execute_statement(func->statements[i]);
        
        if (error_state.has_error) {
            if (error_state.mode == ErrorState::RESUME_NEXT) {
                error_state.has_error = false;
                continue;
            }
            if (error_state.mode == ErrorState::GOTO_LABEL) {
                error_state.has_error = false;
                if (func->label_map.has(error_state.label)) {
                    int idx = (int)func->label_map[error_state.label];
                    i = idx - 1; 
                    continue;
                }
                UtilityFunctions::print("Runtime Error: Error Handler Label '", error_state.label, "' not found.");
            }
            if (error_state.mode == ErrorState::EXIT_SUB) {
                error_state.has_error = false;
                break;
            }
            // Unhandled
            break;
        }
        
        if (jump_target != -1) {
            i = jump_target;
        }
    }
    
    Variant ret = Variant();
    if (func->type == SubDefinition::TYPE_FUNCTION) {
        if (variables.has(func->name)) ret = variables[func->name];
    }
    
    // Restore
    current_sub = prev_sub;
    jump_target = prev_jump;
    error_state = prev_error;
    
    return ret;
}

void VisualGasicInstance::call(const StringName &p_method, const Variant *const *p_args, GDExtensionInt p_argcount, Variant *r_return, GDExtensionCallError *r_error) {
    // Adapter
    Array args;
    for(int i=0; i<p_argcount; i++) args.push_back(*p_args[i]);
    
    // Intercept _OnSignal
    if (p_method == StringName("_OnSignal")) {
         // Args: [SignalArg1, ..., SignalArgN, Bound1, Bound2]
         // Bound args are at the END.
         // Standard Pattern: ObjectName, EventName
         
         if (args.size() >= 2) {
             String name = args[args.size()-2];
             String event = args[args.size()-1];
             String sub_name;
             
             if (event.is_empty()) {
                 sub_name = name; // Direct callback name
             } else {
                 sub_name = name + "_" + event; // e.g. "Timer1_Timer"
             }
             
             // Construct args for Sub
             // Everything BEFORE the last 2 args are the signal parameters
             Array sub_args;
             for(int i=0; i < args.size() - 2; i++) {
                 sub_args.push_back(args[i]);
             }
             
             // Special handling for MenuClick to support custom callbacks
             if (event == "MenuClick" && sub_args.size() > 0) {
                 int id = sub_args[0];
                 // Find menu node by name
                 // We assume owner is Node
                 Node *n = Object::cast_to<Node>(owner);
                 if (n) {
                     // Note: find_child is slow, but Menus are not high freq
                     Node *menu = n->find_child(name, true, false); 
                     if (menu) {
                         PopupMenu *pm = Object::cast_to<PopupMenu>(menu);
                         if (pm && pm->has_meta("callbacks")) {
                             Dictionary callback_map = pm->get_meta("callbacks");
                             if (callback_map.has(id)) {
                                 String callback = callback_map[id];
                                 if (!callback.is_empty()) {
                                     // Override target sub
                                     sub_name = callback;
                                     // Clear args? Helper usually doesn't take ID if it's specific.
                                     // "Sub OnExit()" vs "Sub OnExit(ID)"
                                     // Let's pass ID just in case.
                                 }
                             }
                         }
                     }
                 }
             }
             
             bool found = false;
             call_internal(sub_name, sub_args, found);
             
             if (r_return) *r_return = Variant();
             r_error->error = GDEXTENSION_CALL_OK;
             return;
         }
    }

    bool found = false;
    Variant ret = call_internal(String(p_method), args, found);
    
    if (found) {
        if (r_return) *r_return = ret;
        r_error->error = GDEXTENSION_CALL_OK;
    } else {
        r_error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
    }
}

void VisualGasicInstance::raise_error(String msg, int code) {
    // Update Err Object
    if (variables.has("Err")) {
        Variant v = variables["Err"];
        if (v.get_type() == Variant::DICTIONARY) {
             Dictionary err = v;
             err["Number"] = code;
             err["Description"] = msg;
             err["Source"] = "VisualGasic Runtime";
        }
    }

    if (error_state.has_error) return;
    error_state.has_error = true;
    error_state.message = msg;
    if (error_state.mode == ErrorState::NONE) {
        UtilityFunctions::print("Runtime Error ", code, ": ", msg);
    }
}



// Static Helper for Auto-Connection
static void _connect_vb_signals_recursive(Node* node, VisualGasicInstance* instance, Node* instance_owner) {
    if (!node) return;

    String name = node->get_name();
    String evt_name = "";
    String signal_name = "";
    
    // Debug Trace
    // UtilityFunctions::print("VisualGasic: Scanning ", name, " (", node->get_class(), ")");

    // Determine mapping using ClassDB or string checks for safety
    if (node->is_class("Button") || node->is_class("TextureButton") || node->is_class("CheckButton") || node->is_class("CheckBox") || Object::cast_to<BaseButton>(node)) {
        evt_name = "Click";
        signal_name = "pressed";
    } else if (node->is_class("LineEdit")) {
        evt_name = "Change";
        signal_name = "text_changed";
    } else if (node->is_class("TextEdit")) {
        evt_name = "Change";
        signal_name = "text_changed";
    } else if (node->is_class("HSlider") || node->is_class("VSlider")) {
        evt_name = "Change";
        signal_name = "value_changed";
    } else if (node->is_class("Timer")) {
        evt_name = "Timer";
        signal_name = "timeout";
    }
    
    if (!evt_name.is_empty()) {
        String sub_name = name + "_" + evt_name;
        // UtilityFunctions::print("VisualGasic: Found Candidate ", sub_name);

        // Check if script has this method
        Ref<Script> s = instance->get_script();
        VisualGasicScript *vs = Object::cast_to<VisualGasicScript>(s.ptr());
        
        bool has_it = false;
        if (vs) {
             has_it = vs->_has_method(sub_name);
             // UtilityFunctions::print("VisualGasic: Script Has Method? ", has_it);
        } else {
             // UtilityFunctions::print("VisualGasic: Script Cast Failed");
        }
        
        if (has_it) {
            Callable target(instance_owner, "_OnSignal");
            
            // Re-connect always safe? Check if connected
            if (!node->is_connected(signal_name, target)) {
                Array binds;
                binds.push_back(name);
                binds.push_back(evt_name);
                
                node->connect(signal_name, target.bindv(binds));
                // UtilityFunctions::print("VisualGasic: Auto-Wired ", sub_name);
            } else {
                // UtilityFunctions::print("VisualGasic: Already Wired.");
            }
        }
    }
    
    // Recurse children

    int cc = node->get_child_count();
    for(int i=0; i<cc; i++) {
        _connect_vb_signals_recursive(node->get_child(i), instance, instance_owner);
    }
}

void VisualGasicInstance::notification(int32_t p_what) {
    if (p_what == Node::NOTIFICATION_READY) {
         // Lazy Init Processing if needed (e.g. if ast was null in constructor)
         if (owner && script.is_valid()) {
             Node* node = Object::cast_to<Node>(owner);
             if (node) {
                 if (!node->is_processing() && script->has_method("_Process")) node->set_process(true);
                 if (!node->is_physics_processing() && script->has_method("_PhysicsProcess")) node->set_physics_process(true);
                 if (!node->is_processing_input() && script->has_method("_Input")) node->set_process_input(true);
                 
                 // Run Auto-Wire for Signals
                 _connect_vb_signals_recursive(node, this, node);
             }
         }

         if (script.is_valid() && script->has_method("_Ready")) {
             bool found;
             call_internal("_Ready", Array(), found);
         }
         
         // Run Auto-Wire again for nodes created in _Ready (Dynamic Controls)
         if (owner) {
             Node* node = Object::cast_to<Node>(owner);
             if (node) _connect_vb_signals_recursive(node, this, node);
         }
    }
    else if (p_what == Node::NOTIFICATION_PROCESS) {
         if (script.is_valid() && script->has_method("_Process")) {
             double delta = 0.0;
             if (owner) {
                 Node* node = Object::cast_to<Node>(owner);
                 if (node) delta = node->get_process_delta_time();
             }
             
             Array args; 
             args.push_back(delta);
             
             bool found;
             call_internal("_Process", args, found);
         }
    }
    else if (p_what == Node::NOTIFICATION_PHYSICS_PROCESS) {
         if (script.is_valid() && script->has_method("_PhysicsProcess")) {
             double delta = 0.0;
             if (owner) {
                 Node* node = Object::cast_to<Node>(owner);
                 if (node) delta = node->get_physics_process_delta_time();
             }
             
             Array args; 
             args.push_back(delta);
             
             bool found;
             call_internal("_PhysicsProcess", args, found);
         }
    }
    // Handle Drawing
    else if (p_what == CanvasItem::NOTIFICATION_DRAW) {
         if (script.is_valid() && script->has_method("OnDraw")) {
             bool found;
             Array args;
             call_internal("OnDraw", args, found);
         }
    }
}

void VisualGasicInstance::to_string(GDExtensionBool *r_is_valid, GDExtensionStringPtr r_out) {
    if (r_is_valid) *r_is_valid = true;
    // To properly write to r_out, we would need to call the constructor via interface.
    // For now, let's leave it to default.
}

// Static Wrappers

static GDExtensionBool instance_set(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name, GDExtensionConstVariantPtr p_value) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return instance->set(*(const StringName *)p_name, *(const Variant *)p_value);
}

static GDExtensionBool instance_get(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name, GDExtensionVariantPtr r_ret) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return instance->get(*(const StringName *)p_name, *(Variant *)r_ret);
}

static const GDExtensionPropertyInfo *instance_get_property_list(GDExtensionScriptInstanceDataPtr p_instance, uint32_t *r_count) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return instance->get_property_list(r_count);
}

static void instance_free_property_list(GDExtensionScriptInstanceDataPtr p_instance, const GDExtensionPropertyInfo *p_list, uint32_t p_count) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    instance->free_property_list(p_list, p_count);
}

static GDExtensionBool instance_property_can_revert(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return instance->property_can_revert(*(const StringName *)p_name);
}

static GDExtensionBool instance_property_get_revert(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name, GDExtensionVariantPtr r_ret) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return instance->property_get_revert(*(const StringName *)p_name, *(Variant *)r_ret);
}

static GDExtensionObjectPtr instance_get_owner(GDExtensionScriptInstanceDataPtr p_instance) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return AccessObject::get_internal_ptr(instance->get_owner());
}

static void instance_get_property_state(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionScriptInstancePropertyStateAdd p_add_func, void *p_userdata) {
}

static GDExtensionObjectPtr instance_get_language(GDExtensionScriptInstanceDataPtr p_instance) {
    VisualGasicLanguage *lang = VisualGasicLanguage::get_singleton();
    return AccessObject::get_internal_ptr(lang);
}

static GDExtensionScriptInstancePtr instance_get_script(GDExtensionScriptInstanceDataPtr p_instance) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    Ref<Script> script = instance->get_script();
    return script.is_valid() ? AccessObject::get_internal_ptr(script.ptr()) : nullptr;
}

static GDExtensionBool instance_is_placeholder(GDExtensionScriptInstanceDataPtr p_instance) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    return instance->is_placeholder();
}

static GDExtensionBool instance_has_method(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    Ref<Script> s = instance->get_script();
    VisualGasicScript *script = Object::cast_to<VisualGasicScript>(s.ptr());
    if (script) {
        return script->_has_method(*(const StringName *)p_name);
    }
    return false;
}

static void instance_call(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_method, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argcount, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    instance->call(*(const StringName *)p_method, (const Variant **)p_args, p_argcount, (Variant *)r_return, r_error);
}

static void instance_notification(GDExtensionScriptInstanceDataPtr p_instance, int32_t p_what, GDExtensionBool p_reversed) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    instance->notification(p_what);
}

static void instance_to_string(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionBool *r_is_valid, GDExtensionStringPtr r_out) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    instance->to_string(r_is_valid, r_out);
}

static void instance_ref_count_incremented(GDExtensionScriptInstanceDataPtr p_instance) {}
static GDExtensionBool instance_ref_count_decremented(GDExtensionScriptInstanceDataPtr p_instance) { return true; } 

static void instance_free(GDExtensionScriptInstanceDataPtr p_instance) {
    VisualGasicInstance *instance = (VisualGasicInstance *)p_instance;
    memdelete(instance);
}

const GDExtensionScriptInstanceInfo3 *VisualGasicInstance::get_script_instance_info() {
    static GDExtensionScriptInstanceInfo3 info;
    static bool initialized = false;
    
    if (!initialized) {
        info.set_func = instance_set;
        info.get_func = instance_get;
        info.get_property_list_func = instance_get_property_list;
        info.free_property_list_func = instance_free_property_list;
        info.property_can_revert_func = instance_property_can_revert;
        info.property_get_revert_func = instance_property_get_revert;
        
        info.get_owner_func = instance_get_owner;
        info.get_property_state_func = instance_get_property_state;
        info.get_method_list_func = nullptr; 
        info.free_method_list_func = nullptr;
        info.get_property_type_func = nullptr;
        info.validate_property_func = nullptr;

        info.get_script_func = instance_get_script;
        info.is_placeholder_func = instance_is_placeholder;
        info.has_method_func = instance_has_method;
        info.call_func = instance_call;
        info.notification_func = instance_notification;
        info.to_string_func = instance_to_string;
        
        info.refcount_incremented_func = instance_ref_count_incremented;
        info.refcount_decremented_func = instance_ref_count_decremented;
        info.get_language_func = instance_get_language;
        info.free_func = instance_free;
        
        info.get_method_argument_count_func = nullptr;
        info.set_fallback_func = nullptr;
        info.get_fallback_func = nullptr;

        initialized = true;
    }
    
    return &info;
}

void VisualGasicInstance::assign_variable(const String& name, Variant val) {
    if (script.is_valid() && script->ast_root && script->ast_root->option_explicit) {
         if (!variables.has(name)) {
             bool is_prop = false;
             if (owner) {
                 Variant current = owner->get(name);
                 if (current.get_type() != Variant::NIL) is_prop = true;
             }
             
             if (!is_prop) {
                 raise_error("Variable not defined: " + name + " (Option Explicit is On)");
                 return;
             }
         }
    }

    if (variables.has(name)) {
         Variant::Type target_type = variables[name].get_type();
         if (target_type == Variant::INT) {
             variables[name] = (int64_t)val;
         }
         else if (target_type == Variant::FLOAT) {
             variables[name] = (double)val;
         }
         else if (target_type == Variant::STRING) {
             variables[name] = (String)val;
         }
         else if (target_type == Variant::BOOL) {
             variables[name] = (bool)val;
         }
         else {
             variables[name] = val;
         }
    } else if (owner) {
         Variant current = owner->get(name);
         if (current.get_type() != Variant::NIL) {
             owner->set(name, val);
             return;
         }
         variables[name] = val;
    } else {
         variables[name] = val;
    }
    
    // Check Whenever sections for this variable
    check_whenever_conditions(name, val);
    
    // Check complex expression conditions
    check_expression_conditions();
}

void VisualGasicInstance::check_whenever_conditions(const String& variable_name, const Variant& new_value) {
    for (int i = 0; i < whenever_sections.size(); i++) {
        WheneverSection& section = whenever_sections.write[i];
        
        if (!section.is_active || section.variable_name != variable_name) {
            continue;
        }
        
        bool condition_met = false;
        
        if (section.comparison_operator.to_lower() == "changes") {
            // Always trigger if value changed
            condition_met = (section.last_value != new_value);
        }
        else if (section.comparison_operator.to_lower() == "becomes") {
            // Trigger if value becomes the specified value
            condition_met = (new_value == section.comparison_value);
        }
        else if (section.comparison_operator.to_lower() == "exceeds") {
            // Trigger if value exceeds the specified value
            double new_num = (double)new_value;
            double threshold = (double)section.comparison_value;
            condition_met = (new_num > threshold);
        }
        else if (section.comparison_operator.to_lower() == "below") {
            // Trigger if value is below the specified value
            double new_num = (double)new_value;
            double threshold = (double)section.comparison_value;
            condition_met = (new_num < threshold);
        }
        else if (section.comparison_operator.to_lower() == "between") {
            // Trigger if value is between two specified values
            double new_num = (double)new_value;
            double min_val = (double)section.comparison_value;
            double max_val = (double)section.comparison_value2;
            condition_met = (new_num >= min_val && new_num <= max_val);
        }
        else if (section.comparison_operator.to_lower() == "contains") {
            // Trigger if string/array contains the specified value
            String haystack = String(new_value);
            String needle = String(section.comparison_value);
            condition_met = haystack.contains(needle);
        }
        
        if (condition_met) {
            // Check debounce timing
            uint64_t current_time = Time::get_singleton()->get_ticks_msec();
            if (section.debounce_ms > 0 && (current_time - section.last_trigger_time) < section.debounce_ms) {
                // Skip this trigger due to debouncing
                section.last_value = new_value;  // Still update last value
                continue;
            }
            
            // Update last trigger time
            section.last_trigger_time = current_time;
            
            // Update last value for future comparisons
            section.last_value = new_value;
            
            // Call all callback procedures
            Array empty_args;
            for (int j = 0; j < section.callback_procedures.size(); j++) {
                bool found = false;
                call_internal(section.callback_procedures[j], empty_args, found);
                
                if (!found) {
                    UtilityFunctions::print("Warning: Whenever callback procedure '", section.callback_procedures[j], "' not found");
                }
            }
        } else {
            // Update last value even if condition wasn't met (for "changes" tracking)
            section.last_value = new_value;
        }
    }
}

void VisualGasicInstance::check_expression_conditions() {
    for (int i = 0; i < whenever_sections.size(); i++) {
        WheneverSection& section = whenever_sections.write[i];
        
        if (!section.is_active || !section.condition_expression) {
            continue;
        }
        
        // Check debounce timing
        uint64_t current_time = Time::get_singleton()->get_ticks_msec();
        if (section.debounce_ms > 0 && (current_time - section.last_trigger_time) < section.debounce_ms) {
            continue;
        }
        
        // Evaluate the complex expression
        Variant result = evaluate_expression(section.condition_expression);
        bool condition_met = (bool)result;
        
        if (condition_met) {
            // Update last trigger time
            section.last_trigger_time = current_time;
            
            // Call all callback procedures
            Array empty_args;
            for (int j = 0; j < section.callback_procedures.size(); j++) {
                bool found = false;
                call_internal(section.callback_procedures[j], empty_args, found);
                
                if (!found) {
                    UtilityFunctions::print("Warning: Whenever callback procedure '", section.callback_procedures[j], "' not found");
                }
            }
        }
    }
}

String VisualGasicInstance::get_whenever_status() const {
    String status = "Whenever System Status:\n";
    status += "Total Sections: " + String::num(whenever_sections.size()) + "\n";
    
    int active_count = 0;
    for (int i = 0; i < whenever_sections.size(); i++) {
        const WheneverSection& section = whenever_sections[i];
        if (section.is_active) active_count++;
        
        String state = section.is_active ? "Active" : "Suspended";
        String callbacks = "";
        for (int j = 0; j < section.callback_procedures.size(); j++) {
            if (j > 0) callbacks += ", ";
            callbacks += section.callback_procedures[j];
        }
        status += "- " + section.section_name + " (" + section.variable_name + " " + 
                 section.comparison_operator + ") -> " + callbacks + " [" + state + "]\n";
    }
    
    status += "Active Sections: " + String::num(active_count) + "\n";
    return status;
}

void VisualGasicInstance::clear_whenever_sections() {
    whenever_sections.clear();
}

int VisualGasicInstance::get_active_whenever_count() const {
    int count = 0;
    for (int i = 0; i < whenever_sections.size(); i++) {
        if (whenever_sections[i].is_active) count++;
    }
    return count;
}

void VisualGasicInstance::cleanup_scoped_whenever(const String& scope_type, const String& scope_context) {
    for (int i = whenever_sections.size() - 1; i >= 0; i--) {
        const WheneverSection& section = whenever_sections[i];
        if (section.scope_type == scope_type && section.scope_context == scope_context) {
            whenever_sections.remove_at(i);
        }
    }
}

void VisualGasicInstance::enter_scope(const String& scope_name) {
    scope_stack.push_back(scope_name);
}

void VisualGasicInstance::exit_scope(const String& scope_name) {
    if (!scope_stack.is_empty() && scope_stack[scope_stack.size() - 1] == scope_name) {
        scope_stack.remove_at(scope_stack.size() - 1);
        
        // Cleanup local Whenever sections for this scope
        cleanup_scoped_whenever("local", scope_name);
    }
}

void VisualGasicInstance::assign_to_target(ExpressionNode* target, Variant val) {
    if (target->type == ExpressionNode::VARIABLE) {
         String name = ((VariableNode*)target)->name;
         assign_variable(name, val);
    } 
    else if (target->type == ExpressionNode::MEMBER_ACCESS) {
         MemberAccessNode* ma = (MemberAccessNode*)target;
         Variant base = evaluate_expression(ma->base_object);
         
         // UtilityFunctions::print("Assignment to Member: ", ma->member_name, " Base Type: ", base.get_type());

         if (base.get_type() == Variant::DICTIONARY) {
             Dictionary dict = base;
             dict[ma->member_name] = val;
             // UtilityFunctions::print("Assigned to Dictionary Key: ", ma->member_name, " Value: ", val);
             // Dictionaries are RefCounted handles, so modification sticks.
         } 
         else if (base.get_type() == Variant::OBJECT) {
             Object* obj = base;
             String prop_name = ma->member_name;
             
             // VB6 Property Aliasing
             if (obj) {
                 if (obj->is_class("Tree")) {
                     if (prop_name == "Rows") {
                         Tree *t = Object::cast_to<Tree>(obj);
                         TreeItem *root = t->get_root();
                         if (root) {
                             int current = root->get_child_count();
                             int target = (int)val;
                             if (target > current) {
                                 for(int k=0; k < (target - current); k++) t->create_item(root);
                             } else if (target < current) {
                                  // Remove from end?
                                  while(root->get_child_count() > target) {
                                      memdelete(root->get_child(root->get_child_count() - 1));
                                  }
                             }
                         }
                         return;
                     }
                     if (prop_name == "Cols") {
                         Tree *t = Object::cast_to<Tree>(obj);
                         t->set_columns((int)val);
                         return;
                     }
                 }

                 if (obj->is_class("Node")) {
                      if (prop_name == "Caption") prop_name = "text";
                      else if (prop_name == "Tag") prop_name = "meta"; // Use meta for Tag? Or separate? 
                      
                      // Timer Compatibility
                      if (obj->is_class("Timer")) {
                          if (prop_name == "Interval") {
                               // VB6 Interval is ms, Godot wait_time is sec
                               double sec = (double)val / 1000.0;
                               obj->set("wait_time", sec);
                               return;
                          }
                          if (prop_name == "Enabled") {
                               bool en = (bool)val;
                               if (en) obj->call("start"); else obj->call("stop");
                               return;
                          }
                      }
                      
                      // Geometry Aliasing for Control/Node2D
                      bool is_control = obj->is_class("Control");
                      bool is_2d = obj->is_class("Node2D");
                      bool is_range = obj->is_class("Range");
                      
                      if (is_range) {
                           if (prop_name == "Min") { obj->set("min_value", val); return; }
                           if (prop_name == "Max") { obj->set("max_value", val); return; }
                           if (prop_name == "Value") { obj->set("value", val); return; }
                      }

                      if (is_control || is_2d) {
                          if (prop_name == "Left") {
                               if (is_control) { Control* c = Object::cast_to<Control>(obj); c->set_position(Vector2((double)val, c->get_position().y)); return; }
                               if (is_2d) { Node2D* n = Object::cast_to<Node2D>(obj); n->set_position(Vector2((double)val, n->get_position().y)); return; }
                          }
                          if (prop_name == "Top") {
                               if (is_control) { Control* c = Object::cast_to<Control>(obj); c->set_position(Vector2(c->get_position().x, (double)val)); return; }
                               if (is_2d) { Node2D* n = Object::cast_to<Node2D>(obj); n->set_position(Vector2(n->get_position().x, (double)val)); return; }
                          }
                      }
                      
                      if (is_control) {
                           Control* c = Object::cast_to<Control>(obj);
                           if (prop_name == "Width") { c->set_size(Vector2((double)val, c->get_size().y)); return; }
                           if (prop_name == "Height") { c->set_size(Vector2(c->get_size().x, (double)val)); return; }
                           if (prop_name == "Visible") { c->set_visible((bool)val); return; }
                      }
                 }
             }

             if (obj) {
                 obj->set(prop_name, val);
                 // Fallback to snake_case (e.g. Text -> text)
                 if (obj->get(prop_name).get_type() == Variant::NIL && obj->get(prop_name.to_snake_case()).get_type() != Variant::NIL) {
                      obj->set(prop_name.to_snake_case(), val);
                 }
             }
         }
         else {
             // Handling Value Types (Vector2, etc.) for L-Value assignment
             // E.g. V.x = 10. `base` is V (copy). `base.set_named("x", 10)` modifes copy.
             // We modify the base value, then write it back to the base object (recursively).
             
             bool valid = false;
             base.set_named(ma->member_name, val, valid);
             
             if (!valid) {
                 // Try snake_case fallback
                 base.set_named(ma->member_name.to_snake_case(), val, valid);
             }

             if (valid) {
                 assign_to_target(ma->base_object, base);
                 return;
             } else {
                  UtilityFunctions::print("DEBUG: set_named failed for member '", ma->member_name, "' on base type ", base.get_type());
             }
             
            UtilityFunctions::print("DEBUG: Runtime Error 5: Expression Type: ", ma->base_object->type);
             raise_error("Member assignment failed or not supported for this type: " + ma->member_name);
         }
    } 
    else if (target->type == ExpressionNode::ARRAY_ACCESS) {
         ArrayAccessNode* aa = (ArrayAccessNode*)target;
         Variant base = evaluate_expression(aa->base);

         if (base.get_type() == Variant::DICTIONARY) {
             if (aa->indices.size() > 0) {
                 Dictionary d = base;
                 Variant key = evaluate_expression(aa->indices[0]);
                 d[key] = val; // Dictionary copy? Or ref? 
                 // Dictionaries are passed by reference in Godot 4 usually, but Variant operator= might copy?
                 // Wait, Dictionary IS ref counted.
                 // But simply d[key] = val modifies d locally.
                 // Does it modify the original variable?
                 // If 'base' comes from 'evaluate_expression', it handles returning the variant.
                 // If base is a variable, we hold a ref.
                 // So modifying d modifies the underlying dictionary.
                 return;
             }
         }

         Variant container = base;
         bool fail = false;
         
         for(int i=0; i<aa->indices.size() - 1; i++) {
             if (container.get_type() != Variant::ARRAY) { fail=true; break; }
             Array arr = container;
             int idx = evaluate_expression(aa->indices[i]);
             if (idx >= 0 && idx < arr.size()) {
                 container = arr[idx];
             } else {
                 raise_error("Array subscript out of range");
                 fail = true; break;
             }
         }
         
         if (!fail && container.get_type() == Variant::ARRAY) {
              Array arr = container;
              int idx = evaluate_expression(aa->indices[aa->indices.size()-1]);
              if (idx >= 0 && idx < arr.size()) {
                  arr[idx] = val;
              } else {
                  raise_error("Array subscript out of range");
              }
         } else if (!fail) {
              raise_error("Expected Array for index access");
         }
    }
}

void VisualGasicInstance::execute_bytecode(BytecodeChunk* chunk) {
    if (!chunk) return;
    vm.ip = 0;
    vm.stack.clear();
    const uint8_t* code = chunk->code.ptr();
    int code_size = chunk->code.size();
    
    while(vm.ip < code_size) {
        uint8_t op = code[vm.ip++];
        switch(op) {
            case OP_CONSTANT: {
                uint8_t idx = code[vm.ip++];
                vm.stack.push_back(chunk->constants[idx]);
                break;
            }
            case OP_PRINT: {
                 if (vm.stack.size() > 0) {
                     Variant val = vm.stack[vm.stack.size()-1];
                     vm.stack.remove_at(vm.stack.size()-1); 
                     UtilityFunctions::print(val);
                     
                     // Console Redirection (Immediate Window)
                     if (owner) {
                         Node* owner_node = Object::cast_to<Node>(owner);
                         if (owner_node && owner_node->is_inside_tree()) {
                             Node* console = owner_node->get_tree()->get_root()->find_child("ImmediateWindow", true, false);
                             if (console && console->has_method("append_text")) {
                                 console->call("append_text", String(val) + "\n");
                             }
                             // Also try "DebugConsole"
                             else {
                                 Node* dbg = owner_node->get_tree()->get_root()->find_child("DebugConsole", true, false);
                                 if (dbg && dbg->has_method("append_text")) {
                                    dbg->call("append_text", String(val) + "\n");
                                 }
                             }
                         }
                     }
                 }
                 break;
            }
            case OP_ADD: {
                if (vm.stack.size() >= 2) {
                     Variant b = vm.stack[vm.stack.size()-1]; vm.stack.remove_at(vm.stack.size()-1);
                     Variant a = vm.stack[vm.stack.size()-1]; vm.stack.remove_at(vm.stack.size()-1);
                     bool valid; Variant res; Variant::evaluate(Variant::OP_ADD, a, b, res, valid);
                     vm.stack.push_back(res);
                }
                break;
            }
             case OP_SUBTRACT: {
                if (vm.stack.size() >= 2) {
                     Variant b = vm.stack[vm.stack.size()-1]; vm.stack.remove_at(vm.stack.size()-1);
                     Variant a = vm.stack[vm.stack.size()-1]; vm.stack.remove_at(vm.stack.size()-1);
                     bool valid; Variant res; Variant::evaluate(Variant::OP_SUBTRACT, a, b, res, valid);
                     vm.stack.push_back(res);
                }
                break;
            }
            case OP_RETURN: {
                return;
            }
            default:
                UtilityFunctions::print("VM: Unknown OpCode ", op);
                return;
        }
    }
}

// === MULTITASKING RUNTIME IMPLEMENTATION ===

void VisualGasicInstance::execute_async_function(AsyncFunctionStatement* async_func) {
    // For now, async functions run immediately (simplified implementation)
    // In full implementation, this would set up coroutine state
    
    CoroutineState coroutine;
    coroutine.function_name = async_func->function_name;
    coroutine.remaining_statements = async_func->body;
    coroutine.instruction_pointer = 0;
    
    // Create local scope for function parameters
    Dictionary backup_vars = variables;
    
    // Set parameter values (simplified)
    for (int i = 0; i < async_func->parameters.size(); i++) {
        variables[async_func->parameters[i]->name] = Variant(); // Default values
    }
    
    // Execute function body
    for (int i = 0; i < async_func->body.size(); i++) {
        execute_statement(async_func->body[i]);
        if (error_state.has_error || error_state.mode != ErrorState::NONE) {
            break;
        }
    }
    
    // Restore variables (simplified scope handling)
    variables = backup_vars;
}

Variant VisualGasicInstance::execute_await(ExpressionNode* expr) {
    // Evaluate the awaited expression
    Variant result = evaluate_expression(expr);
    
    // In real implementation, this would check if result is a Task/Promise
    // and yield execution until completion
    
    // For now, just return the result immediately
    return result;
}

void VisualGasicInstance::execute_task_run(TaskRunStatement* task) {
    TaskInfo task_info;
    task_info.task_name = task->task_name.is_empty() ? "Task_" + String::num(active_tasks.size()) : task->task_name;
    task_info.task_body = task->task_body;
    task_info.is_background = task->is_background;
    task_info.is_completed = false;
    
    // Add task to WorkerThreadPool (requires Godot 4.1+)
    // For now, execute synchronously as fallback
    if (Engine::get_singleton()->is_in_physics_frame()) {
        // Execute task body in background
        for (int i = 0; i < task->task_body.size(); i++) {
            execute_statement(task->task_body[i]);
            if (error_state.has_error || error_state.mode != ErrorState::NONE) {
                break;
            }
        }
        task_info.is_completed = true;
        task_info.result = Variant("Task completed");
    }
    
    active_tasks.push_back(task_info);
    task_results[task_info.task_name] = task_info.result;
}

void VisualGasicInstance::execute_task_wait(TaskWaitStatement* wait_stmt) {
    if (wait_stmt->wait_all) {
        // Wait for all specified tasks
        for (int i = 0; i < wait_stmt->task_names.size(); i++) {
            String task_name = wait_stmt->task_names[i];
            // Find and wait for task completion
            for (int j = 0; j < active_tasks.size(); j++) {
                if (active_tasks[j].task_name == task_name) {
                    // In real implementation, would wait for actual completion
                    break;
                }
            }
        }
    } else {
        // Wait for any task to complete (WaitAny)
        // Simplified: just check if any task is completed
        for (int i = 0; i < active_tasks.size(); i++) {
            if (active_tasks[i].is_completed) {
                break;
            }
        }
    }
}

struct ParallelForWorkerData {
    VisualGasicInstance* instance;
    ParallelForStatement* par_for;
    int start_index;
    int end_index;
    int step;
};

void VisualGasicInstance::execute_parallel_for(ParallelForStatement* par_for) {
    int start = (int)evaluate_expression(par_for->start_expr);
    int end = (int)evaluate_expression(par_for->end_expr);
    int step = par_for->step_expr ? (int)evaluate_expression(par_for->step_expr) : 1;
    
    // For safety, execute sequentially for now
    // In full implementation, would use WorkerThreadPool
    for (int i = start; (step > 0 ? i <= end : i >= end); i += step) {
        // Set loop variable
        variables[par_for->variable_name] = i;
        
        // Execute loop body
        for (int j = 0; j < par_for->body.size(); j++) {
            execute_statement(par_for->body[j]);
            if (error_state.has_error || error_state.mode != ErrorState::NONE) {
                break;
            }
        }
    }
}

void VisualGasicInstance::execute_parallel_section(ParallelSectionStatement* par_section) {
    // Execute section sequentially for safety
    // In full implementation, would distribute work across threads
    for (int i = 0; i < par_section->section_body.size(); i++) {
        execute_statement(par_section->section_body[i]);
        if (error_state.has_error || error_state.mode != ErrorState::NONE) {
            break;
        }
    }
}

void VisualGasicInstance::update_tasks() {
    // Check for completed tasks and clean up
    for (int i = active_tasks.size() - 1; i >= 0; i--) {
        if (active_tasks[i].is_completed) {
            // Task finished - could remove or keep for result access
        }
    }
}

// Static worker functions for thread pool integration
void VisualGasicInstance::_task_worker_function(void* user_data) {
    TaskInfo* task = static_cast<TaskInfo*>(user_data);
    // Execute task body in worker thread
    // This would require thread-safe execution context
}

void VisualGasicInstance::_parallel_worker_function(void* user_data, uint32_t index) {
    ParallelForWorkerData* data = static_cast<ParallelForWorkerData*>(user_data);
    // Execute parallel work item
    // This would require thread-safe variable access
}

// === ADVANCED TYPE SYSTEM RUNTIME ===

void VisualGasicInstance::execute_pattern_match(PatternMatchStatement* match_stmt) {
    Variant value = evaluate_expression(match_stmt->expression);
    
    Dictionary captured_vars;
    
    // Try each case in order
    for (int i = 0; i < match_stmt->cases.size(); i++) {
        MatchCase* match_case = match_stmt->cases[i];
        
        if (pattern_matches(match_case->pattern, value, captured_vars)) {
            // Save current variable state
            Dictionary backup_vars = variables;
            
            // Add captured variables to scope
            Array keys = captured_vars.keys();
            for (int j = 0; j < keys.size(); j++) {
                String key = keys[j];
                variables[key] = captured_vars[key];
            }
            
            // Execute case statements
            for (int j = 0; j < match_case->statements.size(); j++) {
                execute_statement(match_case->statements[j]);
                if (error_state.has_error || error_state.mode != ErrorState::NONE) {
                    break;
                }
            }
            
            // Restore variable state (remove captured vars)
            variables = backup_vars;
            return; // Exit after first match
        }
    }
    
    // No pattern matched - could be an error or have a default case
}

bool VisualGasicInstance::pattern_matches(Pattern* pattern, const Variant& value, Dictionary& captured_vars) {
    switch (pattern->type) {
        case Pattern::LITERAL_PATTERN: {
            return value == pattern->literal_value;
        }
        
        case Pattern::VARIABLE_PATTERN: {
            if (pattern->variable_name == "_") {
                return true; // Wildcard matches anything
            }
            captured_vars[pattern->variable_name] = value;
            return true;
        }
        
        case Pattern::TYPE_PATTERN: {
            // Check if value is of the expected type
            String value_type = Variant::get_type_name(value.get_type());
            bool type_matches = (value_type.to_lower() == pattern->type_name.to_lower());
            
            if (type_matches && pattern->sub_patterns.size() > 0) {
                // Destructure the value (simplified)
                if (value.get_type() == Variant::DICTIONARY) {
                    Dictionary dict = value;
                    Array keys = dict.keys();
                    
                    for (int i = 0; i < pattern->sub_patterns.size() && i < keys.size(); i++) {
                        Pattern* sub_pattern = pattern->sub_patterns[i];
                        if (sub_pattern->type == Pattern::VARIABLE_PATTERN) {
                            captured_vars[sub_pattern->variable_name] = dict[keys[i]];
                        }
                    }
                }
            }
            
            return type_matches;
        }
        
        case Pattern::GUARD_PATTERN: {
            // Guard expressions temporarily disabled
            // if (pattern->guard_expression) {
            //     Variant guard_result = evaluate_expression(pattern->guard_expression);
            //     return (bool)guard_result;
            // }
            return true;
        }
        
        default:
            return false;
    }
}

AdvancedType* VisualGasicInstance::infer_type(const Variant& value) {
    AdvancedType* type = new AdvancedType();
    
    switch (value.get_type()) {
        case Variant::INT:
            type->base_type = "Integer";
            break;
        case Variant::FLOAT:
            type->base_type = "Double";
            break;
        case Variant::STRING:
            type->base_type = "String";
            break;
        case Variant::BOOL:
            type->base_type = "Boolean";
            break;
        case Variant::ARRAY:
            type->base_type = "Array";
            type->kind = AdvancedType::ARRAY;
            break;
        case Variant::DICTIONARY:
            type->base_type = "Dictionary";
            break;
        default:
            type->base_type = "Object";
            break;
    }
    
    return type;
}

bool VisualGasicInstance::is_type_compatible(const AdvancedType* expected, const AdvancedType* actual) {
    if (!expected || !actual) return false;
    
    // Basic type compatibility
    if (expected->base_type == actual->base_type) return true;
    
    // Optional type compatibility
    if (expected->is_optional && actual->base_type == expected->base_type) {
        return true;
    }
    
    // Union type compatibility (simplified)
    if (expected->kind == AdvancedType::UNION) {
        for (int i = 0; i < expected->union_types.size(); i++) {
            if (is_type_compatible(expected->union_types[i], actual)) {
                return true;
            }
        }
    }
    
    return false;
}
