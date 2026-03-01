#include "visual_gasic_builtins.h"
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include "visual_gasic_expression_evaluator.h"
#include "visual_gasic_profiler.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/classes/accept_dialog.hpp>
#include <godot_cpp/classes/confirmation_dialog.hpp>
#include <godot_cpp/classes/line_edit.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/tree.hpp>
// System-level class headers for built-in function dispatch
#include "visual_gasic_process.h"
#include "visual_gasic_database.h"
#include "visual_gasic_settings.h"
#include "visual_gasic_com_interop.h"
#include "visual_gasic_timer.h"
#include "visual_gasic_collection.h"
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/tree_item.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/classes/reg_ex.hpp>
#include <godot_cpp/classes/reg_ex_match.hpp>
#include <thread>
#include <chrono>

using namespace godot;

namespace VisualGasicBuiltins {

// Static working directory for ChDir/CurDir (shared across all instances).
// We CANNOT use godot::String at file scope because its constructor runs
// during .so static-init before the Godot memory allocator is ready,
// which segfaults in the editor build.  Use a raw pointer + lazy init.
static String *s_current_working_dir = nullptr;

static String &get_cwd() {
    if (!s_current_working_dir) {
        s_current_working_dir = memnew(String("res://"));
    }
    return *s_current_working_dir;
}

static String variant_to_cstr(const Variant &src) {
    switch (src.get_type()) {
        case Variant::INT:
            return String::num_int64((int64_t)src);
        case Variant::FLOAT: {
            double value = (double)src;
            double rounded = Math::round(value);
            if (Math::is_equal_approx(value, rounded)) {
                return String::num_int64((int64_t)rounded);
            }
            return String::num(value);
        }
        default:
    
                // Fast path for case-insensitive builtin dispatch.
                // The normalized method name is cached to avoid repeated normalization.
            return String(src);
    }
}

Variant call_builtin_expr_evaluated(VisualGasicInstance *instance, const String &p_method, const Array &p_args, bool &r_handled);

bool call_builtin(VisualGasicInstance *instance, const String &p_method, const Array &p_args, Variant &r_ret, bool &r_found) {
    VG_PROFILE_CATEGORY("builtin_call", "builtins");
    VG_COUNT("builtin.function_calls");
    
    r_found = false;
    r_ret = Variant();

    if (!instance) return false;

    String method = p_method;

    // MsgBox - VB6-style message box with button options
    if (method.nocasecmp_to("MsgBox") == 0) {
        r_found = true;
        if (!instance->get_owner()) return true;
        Node *root = Object::cast_to<Node>(instance->get_owner());
        if (!root) return true;

        String msg = "";
        if (p_args.size() > 0) msg = String(p_args[0]);
        int buttons = 0;
        if (p_args.size() > 1) buttons = (int)p_args[1];
        String title = "VisualGasic";
        if (p_args.size() > 2) title = String(p_args[2]);

        // Button type is lowest 4 bits
        int btn_type = buttons & 0x0F;
        // Icon type is in bits 4-6 (can be used for future icon support)
        // int icon_type = buttons & 0x70;

        int result = 1; // Default vbOK

        if (btn_type == 0) { // vbOKOnly
            AcceptDialog *dlg = memnew(AcceptDialog);
            dlg->set_title(title);
            dlg->set_text(msg);
            dlg->set_ok_button_text("OK");
            root->add_child(dlg);
            dlg->popup_centered();
            while (dlg->is_visible() && dlg->is_inside_tree()) {
                DisplayServer::get_singleton()->process_events();
                OS::get_singleton()->delay_msec(10);
            }
            dlg->queue_free();
            result = 1; // vbOK
        } else if (btn_type == 1 || btn_type == 4) { // vbOKCancel or vbYesNo
            ConfirmationDialog *dlg = memnew(ConfirmationDialog);
            dlg->set_title(title);
            dlg->set_text(msg);
            if (btn_type == 4) {
                dlg->set_ok_button_text("Yes");
                dlg->set_cancel_button_text("No");
            } else {
                dlg->set_ok_button_text("OK");
                dlg->set_cancel_button_text("Cancel");
            }
            dlg->set_meta("_confirmed", false);
            dlg->connect("confirmed", Callable(dlg, "set_meta").bind("_confirmed", true));
            root->add_child(dlg);
            dlg->popup_centered();
            while (dlg->is_visible() && dlg->is_inside_tree()) {
                DisplayServer::get_singleton()->process_events();
                OS::get_singleton()->delay_msec(10);
            }
            bool confirmed = dlg->get_meta("_confirmed", false);
            if (btn_type == 4) {
                result = confirmed ? 6 : 7; // vbYes or vbNo
            } else {
                result = confirmed ? 1 : 2; // vbOK or vbCancel
            }
            dlg->queue_free();
        } else {
            // Default fallback
            AcceptDialog *dlg = memnew(AcceptDialog);
            dlg->set_title(title);
            dlg->set_text(msg);
            root->add_child(dlg);
            dlg->popup_centered();
            while (dlg->is_visible() && dlg->is_inside_tree()) {
                DisplayServer::get_singleton()->process_events();
                OS::get_singleton()->delay_msec(10);
            }
            dlg->queue_free();
            result = 1;
        }
        
        r_ret = result;
        return true;
    }

    if (method.nocasecmp_to("InputBox") == 0) {
        r_found = true;
        if (!instance->get_owner()) return true;
        Node *root = Object::cast_to<Node>(instance->get_owner());
        if (!root) return true;

        String prompt = "";
        if (p_args.size() > 0) prompt = String(p_args[0]);
        String title = "VisualGasic";
        if (p_args.size() > 1) title = String(p_args[1]);
        String def = "";
        if (p_args.size() > 2) def = String(p_args[2]);

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
        dialog->popup_centered();
        le->grab_focus();

        while (dialog->is_visible() && dialog->is_inside_tree()) {
            DisplayServer::get_singleton()->process_events();
            OS::get_singleton()->delay_msec(10);
        }

        String result = "";
        // No reliable meta-setting here; assume accepted if not visible
        result = le->get_text();
        dialog->queue_free();
        r_ret = result;
        return true;
    }

    // Convenience: statement-level AddChild(child) - adds the child to the instance owner
    if (method.nocasecmp_to("AddChild") == 0) {
        r_found = true;
        if (!instance->get_owner()) return true;
        Node *parent = Object::cast_to<Node>(instance->get_owner());
        if (!parent) return true;
        if (p_args.size() >= 1) {
            Object *child_obj = Object::cast_to<Object>(p_args[0]);
            if (child_obj) {
                Node *child = Object::cast_to<Node>(child_obj);
                if (child) parent->add_child(child);
            }
        }
        return true;
    }

    // Fallback: not handled here
    return false;
}

Variant call_builtin_expr(VisualGasicInstance *instance, CallExpression *call, bool &r_handled) {
    r_handled = false;
    Variant ret;
    if (!call) return Variant();

    // Evaluate call arguments using the instance evaluator
    Array args;
    for (int i = 0; i < call->arguments.size(); i++) {
        args.push_back(instance->evaluate_expression_for_builtins(call->arguments[i]));
    }

    String name = call->method_name;
    String lowercase_name = name.to_lower();
    const StringName method_key = StringName(lowercase_name);
#define METHOD_IS(literal) (method_key == StringName(literal))

    {
        bool handled_eval = false;
        Variant eval_res = call_builtin_expr_evaluated(instance, name, args, handled_eval);
        if (handled_eval) {
            r_handled = true;
            return eval_res;
        }
    }

    // String Library
    if (name == "Len" && args.size() == 1) {
        r_handled = true;
        return String(args[0]).length();
    }
    if (name == "Left" && args.size() == 2) {
        r_handled = true;
        return String(args[0]).left((int)args[1]);
    }
    if (name == "Right" && args.size() == 2) {
        r_handled = true;
        return String(args[0]).right((int)args[1]);
    }
    if (name == "Mid" && args.size() >= 2) {
        r_handled = true;
        String s = String(args[0]);
        int start = (int)args[1] - 1;
        if (start < 0) start = 0;
        if (args.size() == 3) return s.substr(start, (int)args[2]);
        return s.substr(start);
    }
    if (name == "UCase" && args.size() == 1) { r_handled = true; return String(args[0]).to_upper(); }
    if (name == "LCase" && args.size() == 1) { r_handled = true; return String(args[0]).to_lower(); }
    if (name == "Asc" && args.size() == 1) { r_handled = true; String s = args[0]; if (s.length()>0) return (int)s.unicode_at(0); return 0; }
    if (name == "Chr" && args.size() == 1) { r_handled = true; return String::chr((int)args[0]); }
    if (name == "Space" && args.size() == 1) { r_handled = true; int n = (int)args[0]; String s=""; for(int i=0;i<n;i++) s += " "; return s; }
    if (name == "String" && args.size() == 2) { r_handled = true; int n=(int)args[0]; String char_str = String(args[1]); String s=""; if (char_str.length()>0){ String c = char_str.substr(0,1); for(int i=0;i<n;i++) s+=c;} return s; }
    if (name == "Str" && args.size() == 1) { r_handled = true; return variant_to_cstr(args[0]); }
    if (name.nocasecmp_to("CStr") == 0 && args.size() == 1) { r_handled = true; return variant_to_cstr(args[0]); }
    if (name == "Val" && args.size() == 1) { r_handled = true; String s = args[0]; if (s.is_valid_float()) return s.to_float(); if (s.is_valid_int()) return s.to_int(); return 0.0; }
    if (METHOD_IS("strcomp") && args.size() >= 2) { r_handled = true; String s1 = args[0]; String s2 = args[1]; int mode = (args.size() >= 3) ? (int)args[2] : 0; int cmp = (mode == 1) ? s1.nocasecmp_to(s2) : s1.casecmp_to(s2); if (cmp < 0) return (int64_t)-1; if (cmp > 0) return (int64_t)1; return (int64_t)0; }
    if (METHOD_IS("instr") && args.size() == 2) { r_handled = true; String s1 = args[0]; String s2 = args[1]; int pos = s1.find(s2); if (pos==-1) return 0; return pos+1; }
    if (METHOD_IS("instrrev") && args.size() >= 2) { r_handled = true; String s1 = args[0]; String s2 = args[1]; int start = (args.size() >= 3) ? (int)args[2] - 1 : s1.length() - 1; if (start < 0 || start >= s1.length()) start = s1.length() - 1; int pos = s1.rfind(s2, start); if (pos == -1) return 0; return pos + 1; }
    if (METHOD_IS("replace") && args.size() == 3) { r_handled = true; return String(args[0]).replace(String(args[1]), String(args[2])); }
    if (METHOD_IS("trim") && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(); }
    if (METHOD_IS("ltrim") && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(true,false); }
    if (METHOD_IS("rtrim") && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(false,true); }
    if (METHOD_IS("strreverse") && args.size() == 1) { r_handled = true; String s = args[0]; String res=""; for(int i=s.length()-1;i>=0;i--) res += s[i]; return res; }
    if (METHOD_IS("hex") && args.size() == 1) { r_handled = true; int64_t val = (int64_t)args[0]; return String::num_int64(val,16).to_upper(); }
    if (METHOD_IS("oct") && args.size() == 1) { r_handled = true; int64_t val = (int64_t)args[0]; return String::num_int64(val,8); }
    if (METHOD_IS("split") && args.size() >= 2) { r_handled = true; return String(args[0]).split(String(args[1])); }
    if (METHOD_IS("join") && args.size() == 2) {
        r_handled = true;
        Variant v = args[0];
        if (v.get_type() == Variant::PACKED_STRING_ARRAY) {
            PackedStringArray psa = v;
            return String(args[1]).join(psa);
        }
        if (v.get_type() == Variant::ARRAY) {
            Array arr = v;
            PackedStringArray psa;
            for (int i=0;i<arr.size();i++) psa.push_back((String)arr[i]);
            return String(args[1]).join(psa);
        }
        return String();
    }

    // Array Helpers
    if (METHOD_IS("ubound") && args.size() >= 1) {
        r_handled = true;
        Variant v = args[0];
        if (v.get_type() == Variant::ARRAY) return ((Array)v).size() - 1;
        if (v.get_type() == Variant::PACKED_STRING_ARRAY) return ((PackedStringArray)v).size() - 1;
        if (v.get_type() == Variant::PACKED_INT32_ARRAY) return ((PackedInt32Array)v).size() - 1;
        if (v.get_type() == Variant::PACKED_FLOAT32_ARRAY) return ((PackedFloat32Array)v).size() - 1;
        if (v.get_type() == Variant::PACKED_INT64_ARRAY) return ((PackedInt64Array)v).size() - 1;
        if (v.get_type() == Variant::PACKED_FLOAT64_ARRAY) return ((PackedFloat64Array)v).size() - 1;
        return -1;
    }
    if (METHOD_IS("lbound") && args.size() >= 1) { r_handled = true; return 0; }

    // DATA Introspection Functions
    if (METHOD_IS("datacount")) {
        r_handled = true;
        if (args.size() >= 1) {
            // DataCount("label") — items in a specific labeled section
            String key = String(args[0]).to_lower();
            const Dictionary &ldi = instance->get_label_to_data_index();
            if (ldi.has(key)) {
                int start = (int)ldi[key];
                int end = instance->get_data_section_end(start);
                return end - start;
            }
            return 0; // label not found
        }
        // DataCount() — total items in the data tape
        return (int64_t)instance->get_data_count();
    }
    if (METHOD_IS("dataremain")) {
        r_handled = true;
        // DataRemain() — remaining items from pointer to end of tape
        int remain = instance->get_data_count() - instance->get_data_pointer();
        return remain > 0 ? remain : 0;
    }
    if (METHOD_IS("datasectioncount")) {
        r_handled = true;
        // DataSectionCount() — items in the current section the pointer is in
        int sec_start = instance->get_data_section_start();
        int sec_end = instance->get_data_section_end(sec_start);
        return sec_end - sec_start;
    }
    if (METHOD_IS("datasectionremain")) {
        r_handled = true;
        // DataSectionRemain() — remaining items from pointer to end of current section
        int sec_start = instance->get_data_section_start();
        int sec_end = instance->get_data_section_end(sec_start);
        int remain = sec_end - instance->get_data_pointer();
        return remain > 0 ? remain : 0;
    }
    if (METHOD_IS("datapointer")) {
        r_handled = true;
        return (int64_t)instance->get_data_pointer();
    }
    if (METHOD_IS("peekdata")) {
        r_handled = true;
        int abs_index = 0;
        if (args.size() == 1) {
            // PeekData(index) — absolute 0-based index into the data tape
            abs_index = (int)args[0];
        } else if (args.size() == 2) {
            // PeekData("label", offset) — offset relative to a labeled section
            String key = String(args[0]).to_lower();
            const Dictionary &ldi = instance->get_label_to_data_index();
            if (!ldi.has(key)) {
                instance->raise_runtime_error("PeekData: label '" + String(args[0]) + "' not found");
                return Variant();
            }
            abs_index = (int)ldi[key] + (int)args[1];
        } else {
            instance->raise_runtime_error("PeekData: expected 1 or 2 arguments");
            return Variant();
        }
        if (abs_index < 0 || abs_index >= instance->get_data_count()) {
            instance->raise_runtime_error("PeekData: index " + itos(abs_index) + " out of range (0.." + itos(instance->get_data_count() - 1) + ")");
            return Variant();
        }
        ExpressionNode* expr = instance->get_data_segment_at(abs_index);
        if (expr) {
            return instance->evaluate_expression_for_builtins(expr);
        }
        return Variant();
    }
    if (METHOD_IS("setdatapointer")) {
        r_handled = true;
        if (args.size() >= 1) {
            instance->set_data_pointer((int)args[0]);
        }
        return Variant();
    }
    if (METHOD_IS("datalabels")) {
        r_handled = true;
        return instance->get_label_to_data_index().keys();
    }
    if (METHOD_IS("datasectionname")) {
        r_handled = true;
        return instance->get_data_section_name();
    }
    if (METHOD_IS("datatoarray")) {
        r_handled = true;
        int start = 0;
        int end = instance->get_data_count();
        if (args.size() >= 1 && args[0].get_type() == Variant::STRING) {
            // DataToArray("label") — return items in that section
            String key = String(args[0]).to_lower();
            const Dictionary &ldi = instance->get_label_to_data_index();
            if (!ldi.has(key)) {
                instance->raise_runtime_error("DataToArray: label '" + String(args[0]) + "' not found");
                return Array();
            }
            start = (int)ldi[key];
            end = instance->get_data_section_end(start);
        } else if (args.size() >= 1) {
            // DataToArray(n) — read n items from current pointer
            start = instance->get_data_pointer();
            end = start + (int)args[0];
            if (end > instance->get_data_count()) end = instance->get_data_count();
        }
        Array result;
        for (int i = start; i < end; i++) {
            ExpressionNode* expr = instance->get_data_segment_at(i);
            if (expr) {
                result.push_back(instance->evaluate_expression_for_builtins(expr));
            }
        }
        return result;
    }

    // File / Dir Helpers (use instance wrappers)
    if (METHOD_IS("lof") && args.size() == 1) { r_handled = true; return instance->file_lof((int)args[0]); }
    if (METHOD_IS("loc") && args.size() == 1) { r_handled = true; return instance->file_loc((int)args[0]); }
    if (METHOD_IS("eof") && args.size() == 1) { r_handled = true; return instance->file_eof((int)args[0]); }
    if (METHOD_IS("freefile")) { r_handled = true; int range = 0; if (args.size()>0) range = (int)args[0]; return instance->file_free(range); }
    if (METHOD_IS("filelen") && args.size() == 1) { r_handled = true; return instance->file_len(String(args[0])); }
    if (METHOD_IS("dir")) { r_handled = true; return instance->file_dir(args); }
    if (METHOD_IS("randomize")) { r_handled = true; instance->randomize_seed(); return Variant(); }

    // ---- VB6 File/Directory Management ----
    if (METHOD_IS("mkdir") && args.size() >= 1) {
        r_handled = true;
        String path = String(args[0]);
        Ref<DirAccess> dir = DirAccess::open("res://");
        if (dir.is_valid()) {
            Error err = dir->make_dir_recursive(path);
            if (err != OK) {
                UtilityFunctions::printerr("MkDir: Failed to create directory '", path, "'");
            }
        }
        return Variant();
    }
    if (METHOD_IS("rmdir") && args.size() >= 1) {
        r_handled = true;
        String path = String(args[0]);
        Ref<DirAccess> dir = DirAccess::open("res://");
        if (dir.is_valid()) {
            Error err = dir->remove(path);
            if (err != OK) {
                UtilityFunctions::printerr("RmDir: Failed to remove directory '", path, "'");
            }
        }
        return Variant();
    }
    if (METHOD_IS("chdir") && args.size() >= 1) {
        r_handled = true;
        String path = String(args[0]);
        Ref<DirAccess> dir = DirAccess::open(path);
        if (dir.is_valid()) {
            get_cwd() = path;
        } else {
            UtilityFunctions::printerr("ChDir: Invalid path '", path, "'");
        }
        return Variant();
    }
    if (METHOD_IS("curdir") || METHOD_IS("curdir$")) {
        r_handled = true;
        return get_cwd();
    }
    if (METHOD_IS("filecopy") && args.size() >= 2) {
        r_handled = true;
        String src = String(args[0]);
        String dst = String(args[1]);
        Ref<DirAccess> dir = DirAccess::open("res://");
        if (dir.is_valid()) {
            Error err = dir->copy(src, dst);
            if (err != OK) {
                UtilityFunctions::printerr("FileCopy: Failed to copy '", src, "' to '", dst, "'");
            }
        }
        return Variant();
    }
    if (METHOD_IS("beep")) {
        r_handled = true;
        // Beep is a no-op in Godot (no system beep API), but we acknowledge the call
        UtilityFunctions::print("[VG] Beep");
        return Variant();
    }

    // ====================================================================
    // System-Level Built-in Functions (v2.9.0)
    // ====================================================================

    // Shell() — VB6-style process launch, returns PID
    if (METHOD_IS("shell") && args.size() >= 1) {
        r_handled = true;
        int window_style = args.size() > 1 ? (int)args[1] : 1;
        return VGProcess::shell_execute(args[0], window_style);
    }

    // GetSetting / SaveSetting / DeleteSetting — VB6 registry-style settings
    if (METHOD_IS("getsetting") && args.size() >= 3) {
        r_handled = true;
        String def = args.size() > 3 ? String(args[3]) : "";
        return VGSettings::get_setting(args[0], args[1], args[2], def);
    }
    if (METHOD_IS("savesetting") && args.size() >= 4) {
        r_handled = true;
        VGSettings::save_setting(args[0], args[1], args[2], args[3]);
        return Variant();
    }
    if (METHOD_IS("deletesetting") && args.size() >= 1) {
        r_handled = true;
        String section = args.size() > 1 ? String(args[1]) : "";
        String key = args.size() > 2 ? String(args[2]) : "";
        VGSettings::delete_setting(args[0], section, key);
        return Variant();
    }
    if (METHOD_IS("getallsettings") && args.size() >= 2) {
        r_handled = true;
        return VGSettings::get_all_settings(args[0], args[1]);
    }

    // CreateObject() — VB6 COM-style late-bound object creation
    if (METHOD_IS("createobject") && args.size() >= 1) {
        r_handled = true;
        return VGComInterop::create_object(args[0]);
    }

    // Environ() — VB6-style environment variable access
    if (METHOD_IS("environ") && args.size() >= 1) {
        r_handled = true;
        String var_name = args[0];
        if (OS::get_singleton()->has_environment(var_name)) {
            return OS::get_singleton()->get_environment(var_name);
        }
        return "";
    }
    if (METHOD_IS("environ$") && args.size() >= 1) {
        r_handled = true;
        String var_name = args[0];
        if (OS::get_singleton()->has_environment(var_name)) {
            return OS::get_singleton()->get_environment(var_name);
        }
        return "";
    }

    // SQLite availability check
    if (METHOD_IS("issqliteavailable")) {
        r_handled = true;
        return VGDatabase::is_sqlite_available();
    }

    // If not handled here, leave r_handled false so caller can fallback
#undef METHOD_IS
    return Variant();
}

Variant call_builtin_expr_evaluated(VisualGasicInstance *instance, const String &p_method, const Array &p_args, bool &r_handled) {
    r_handled = false;
    const Array &args = p_args;

    String lowercase_name = p_method;
    lowercase_name = lowercase_name.to_lower();
    const StringName method_key = StringName(lowercase_name);

    // Lowercase once so builtin dispatch stays O(1) per comparison.
#define METHOD_IS(literal) (method_key == StringName(literal))

    if (METHOD_IS("createnode") && args.size() == 1) {
        r_handled = true;
        String type = String(args[0]);
        if (ClassDB::class_exists(type) && ClassDB::can_instantiate(type)) {
            Object *obj = ClassDB::instantiate(type);
            if (obj) {
                return obj;
            }
        }
        return Variant();
    }

    // Built-in type constructors
    if (METHOD_IS("vector2")) {
        r_handled = true;
        if (args.size() == 0) return Vector2();
        if (args.size() == 2) return Vector2((real_t)(double)args[0], (real_t)(double)args[1]);
        return Vector2();
    }
    if (METHOD_IS("vector3")) {
        r_handled = true;
        if (args.size() == 0) return Vector3();
        if (args.size() == 3) return Vector3((real_t)(double)args[0], (real_t)(double)args[1], (real_t)(double)args[2]);
        return Vector3();
    }
    if (METHOD_IS("color")) {
        r_handled = true;
        if (args.size() == 0) return Color();
        if (args.size() == 1) {
            // Color("#hex") or Color("named")
            if (args[0].get_type() == Variant::STRING) {
                String s = args[0];
                if (s.begins_with("#")) return Color::html(s);
                return Color::named(s);
            }
            return Color();
        }
        if (args.size() == 3) return Color((float)(double)args[0], (float)(double)args[1], (float)(double)args[2]);
        if (args.size() == 4) return Color((float)(double)args[0], (float)(double)args[1], (float)(double)args[2], (float)(double)args[3]);
        return Color();
    }
    if (METHOD_IS("color8")) {
        r_handled = true;
        if (args.size() == 3) return Color((int)args[0] / 255.0f, (int)args[1] / 255.0f, (int)args[2] / 255.0f);
        if (args.size() == 4) return Color((int)args[0] / 255.0f, (int)args[1] / 255.0f, (int)args[2] / 255.0f, (int)args[3] / 255.0f);
        return Color();
    }
    // RGB() - VB6-style color function (0-255 per channel)
    if (METHOD_IS("rgb")) {
        r_handled = true;
        if (args.size() == 3) return Color((int)args[0] / 255.0f, (int)args[1] / 255.0f, (int)args[2] / 255.0f);
        return Color();
    }
    if (METHOD_IS("rect2")) {
        r_handled = true;
        if (args.size() == 4) return Rect2((real_t)(double)args[0], (real_t)(double)args[1], (real_t)(double)args[2], (real_t)(double)args[3]);
        return Rect2();
    }

    // Input functions
    if (METHOD_IS("iskeydown") && args.size() == 1) {
        r_handled = true;
        Key key = Key::KEY_NONE;
        if (args[0].get_type() == Variant::INT || args[0].get_type() == Variant::FLOAT) {
            key = (Key)(int)args[0];
        } else {
            String k = args[0];
            key = (Key)OS::get_singleton()->find_keycode_from_string(k);
        }
        return Input::get_singleton()->is_key_pressed(key);
    }
    if (METHOD_IS("getkey") && args.size() == 1) {
        r_handled = true;
        Key key = Key::KEY_NONE;
        if (args[0].get_type() == Variant::INT || args[0].get_type() == Variant::FLOAT) {
            key = (Key)(int)args[0];
        } else {
            String k = args[0];
            key = (Key)OS::get_singleton()->find_keycode_from_string(k);
        }
        return Input::get_singleton()->is_key_pressed(key);
    }
    if (METHOD_IS("ismousebuttondown") && args.size() == 1) {
        r_handled = true;
        int btn = args[0];
        return Input::get_singleton()->is_mouse_button_pressed((MouseButton)btn);
    }
    if (METHOD_IS("rnd") && args.size() == 0) {
        r_handled = true;
        return UtilityFunctions::randf();
    }
    if (METHOD_IS("rnd") && args.size() == 1) {
        r_handled = true;
        // VB6 Rnd() - if arg <= 0, returns 0 or reseeds, otherwise returns random
        double arg = (double)args[0];
        if (arg <= 0) return 0.0;
        return UtilityFunctions::randf();
    }
    if (METHOD_IS("randomize") && args.size() == 0) {
        r_handled = true;
        // Use current time as seed
        UtilityFunctions::randomize();
        return Variant();
    }
    if (METHOD_IS("randomize") && args.size() == 1) {
        r_handled = true;
        // Use provided seed value
        int64_t seed_val = (int64_t)args[0];
        UtilityFunctions::seed(seed_val);
        return Variant();
    }

    if (METHOD_IS("benchfileiofast") && args.size() == 2) {
        r_handled = true;
        int64_t iterations = (int64_t)args[0];
        int64_t size = (int64_t)args[1];
        if (iterations <= 0 || size <= 0) return (int64_t)0;

        String line;
        line = line.repeat(0);
        for (int64_t i = 0; i < size; i++) {
            line += "x";
        }

        Ref<FileAccess> file = FileAccess::open("user://bench_io_fast.txt", FileAccess::WRITE);
        if (file.is_valid()) {
            for (int64_t i = 0; i < iterations; i++) {
                file->store_line(line);
            }
            file->close();
        }

        Ref<FileAccess> read = FileAccess::open("user://bench_io_fast.txt", FileAccess::READ);
        String read_line;
        if (read.is_valid()) {
            read_line = read->get_line();
            read->close();
        }
        return (int64_t)read_line.length();
    }

    // String Library
    if (METHOD_IS("len") && args.size() == 1) { r_handled = true; return String(args[0]).length(); }
    if (METHOD_IS("left") && args.size() == 2) { r_handled = true; return String(args[0]).left((int)args[1]); }
    if (METHOD_IS("right") && args.size() == 2) { r_handled = true; return String(args[0]).right((int)args[1]); }
    if (METHOD_IS("mid") && args.size() >= 2) {
        r_handled = true;
        String s = String(args[0]);
        int start = (int)args[1] - 1;
        if (start < 0) start = 0;
        if (args.size() == 3) return s.substr(start, (int)args[2]);
        return s.substr(start);
    }
    if (METHOD_IS("ucase") && args.size() == 1) { r_handled = true; return String(args[0]).to_upper(); }
    if (METHOD_IS("lcase") && args.size() == 1) { r_handled = true; return String(args[0]).to_lower(); }
    if (METHOD_IS("asc") && args.size() == 1) { r_handled = true; String s = args[0]; if (s.length()>0) return (int)s.unicode_at(0); return 0; }
    if (METHOD_IS("chr") && args.size() == 1) { r_handled = true; return String::chr((int)args[0]); }
    if (METHOD_IS("space") && args.size() == 1) { r_handled = true; int n = (int)args[0]; String s=""; for(int i=0;i<n;i++) s += " "; return s; }
    if (METHOD_IS("string") && args.size() == 2) { r_handled = true; int n=(int)args[0]; String char_str = String(args[1]); String s=""; if (char_str.length()>0){ String c = char_str.substr(0,1); for(int i=0;i<n;i++) s+=c;} return s; }
    if (METHOD_IS("str") && args.size() == 1) { r_handled = true; return variant_to_cstr(args[0]); }
    if (METHOD_IS("cstr") && args.size() == 1) { r_handled = true; return variant_to_cstr(args[0]); }
    if (METHOD_IS("val") && args.size() == 1) { r_handled = true; String s = args[0]; if (s.is_valid_float()) return s.to_float(); if (s.is_valid_int()) return s.to_int(); return 0.0; }
    if (METHOD_IS("strcomp") && args.size() >= 2) { r_handled = true; String s1 = args[0]; String s2 = args[1]; int mode = (args.size() >= 3) ? (int)args[2] : 0; int cmp = (mode == 1) ? s1.nocasecmp_to(s2) : s1.casecmp_to(s2); if (cmp < 0) return (int64_t)-1; if (cmp > 0) return (int64_t)1; return (int64_t)0; }
    if (METHOD_IS("instr") && args.size() == 2) { r_handled = true; String s1 = args[0]; String s2 = args[1]; int pos = s1.find(s2); if (pos==-1) return 0; return pos+1; }
    if (METHOD_IS("instrrev") && args.size() >= 2) { r_handled = true; String s1 = args[0]; String s2 = args[1]; int start = (args.size() >= 3) ? (int)args[2] - 1 : s1.length() - 1; if (start < 0 || start >= s1.length()) start = s1.length() - 1; int pos = s1.rfind(s2, start); if (pos == -1) return 0; return pos + 1; }
    if (METHOD_IS("replace") && args.size() == 3) { r_handled = true; return String(args[0]).replace(String(args[1]), String(args[2])); }
    if (METHOD_IS("trim") && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(); }
    if (METHOD_IS("ltrim") && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(true,false); }
    if (METHOD_IS("rtrim") && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(false,true); }
    if (METHOD_IS("strreverse") && args.size() == 1) { r_handled = true; String s = args[0]; String res=""; for(int i=s.length()-1;i>=0;i--) res += s[i]; return res; }
    if (METHOD_IS("hex") && args.size() == 1) { r_handled = true; int64_t val = (int64_t)args[0]; return String::num_int64(val,16).to_upper(); }
    if (METHOD_IS("oct") && args.size() == 1) { r_handled = true; int64_t val = (int64_t)args[0]; return String::num_int64(val,8); }
    if (METHOD_IS("split") && args.size() >= 2) { r_handled = true; return String(args[0]).split(String(args[1])); }
    if (METHOD_IS("join") && args.size() == 2) {
        r_handled = true;
        Variant v = args[0];
        if (v.get_type() == Variant::PACKED_STRING_ARRAY) {
            PackedStringArray psa = v;
            return String(args[1]).join(psa);
        }
        if (v.get_type() == Variant::ARRAY) {
            Array arr = v;
            PackedStringArray psa;
            for (int i=0;i<arr.size();i++) psa.push_back((String)arr[i]);
            return String(args[1]).join(psa);
        }
        return String();
    }

    // Math Library
    if (METHOD_IS("sin") && args.size() == 1) { r_handled = true; return ::sin((double)args[0]); }
    if (METHOD_IS("cos") && args.size() == 1) { r_handled = true; return ::cos((double)args[0]); }
    if (METHOD_IS("tan") && args.size() == 1) { r_handled = true; return ::tan((double)args[0]); }
    if (METHOD_IS("log") && args.size() == 1) { r_handled = true; return ::log((double)args[0]); }
    if (METHOD_IS("exp") && args.size() == 1) { r_handled = true; return ::exp((double)args[0]); }
    if (METHOD_IS("atn") && args.size() == 1) { r_handled = true; return ::atan((double)args[0]); }
    if (METHOD_IS("sqr") && args.size() == 1) { r_handled = true; return ::sqrt((double)args[0]); }
    if (METHOD_IS("abs") && args.size() == 1) { 
        r_handled = true; 
        if (args[0].get_type() == Variant::INT) { int64_t v = (int64_t)args[0]; return v < 0 ? -v : v; }
        return ::fabs((double)args[0]); 
    }
    if (METHOD_IS("sgn") && args.size() == 1) { r_handled = true; double d = (double)args[0]; if (d>0) return (int64_t)1; if (d<0) return (int64_t)-1; return (int64_t)0; }
    if (METHOD_IS("int") && args.size() == 1) { r_handled = true; if (args[0].get_type() == Variant::INT) return (int64_t)args[0]; return (int64_t)floor((double)args[0]); }
    if (METHOD_IS("rnd") && (args.size() == 0 || args.size() == 1)) { r_handled = true; return UtilityFunctions::randf(); }
    if (METHOD_IS("randomize") && args.size() == 0) { r_handled = true; UtilityFunctions::randomize(); return Variant(); }
    if (METHOD_IS("randomize") && args.size() == 1) { r_handled = true; UtilityFunctions::seed((int64_t)args[0]); return Variant(); }
    if (METHOD_IS("fix") && args.size() == 1) { r_handled = true; double v = (double)args[0]; return v < 0 ? ceil(v) : floor(v); }

    if (METHOD_IS("round") && args.size() >= 1) {
        r_handled = true;
        double val = (double)args[0];
        if (args.size() > 1) {
            int digits = (int)args[1];
            double step = pow(10.0, -digits);
            return Math::snapped(val, step);
        }
        return round(val);
    }

    if (METHOD_IS("randrange") && args.size() == 2) {
        r_handled = true;
        float min = (float)args[0];
        float max = (float)args[1];
        return min + UtilityFunctions::randf() * (max - min);
    }

    if (METHOD_IS("cint") && args.size() == 1) { r_handled = true; return (int64_t)llround((double)args[0]); }
    if (METHOD_IS("clng") && args.size() == 1) { r_handled = true; return (int64_t)llround((double)args[0]); }
    if (METHOD_IS("csng") && args.size() == 1) { r_handled = true; return (double)args[0]; }
    if (METHOD_IS("cdbl") && args.size() == 1) { r_handled = true; return (double)args[0]; }
    if (METHOD_IS("cbool") && args.size() == 1) { r_handled = true; return (bool)args[0]; }
    if (METHOD_IS("cbyte") && args.size() == 1) { r_handled = true; int64_t v = (int64_t)args[0]; if (v < 0) v = 0; if (v > 255) v = 255; return v; }
    if (METHOD_IS("cdate") && args.size() == 1) {
        r_handled = true;
        // VB6 CDate converts various inputs to a date serial number
        // In Godot, we'll use Unix timestamp as the date representation
        Variant arg = args[0];
        if (arg.get_type() == Variant::STRING) {
            // Try to parse date string - for now return current time if parsing fails
            String s = arg;
            // Simple ISO format parsing: "YYYY-MM-DD" or similar
            Dictionary dt = Time::get_singleton()->get_datetime_dict_from_datetime_string(s, false);
            if (dt.size() > 0) {
                return Time::get_singleton()->get_unix_time_from_datetime_dict(dt);
            }
            return Time::get_singleton()->get_unix_time_from_system();
        }
        // If it's already a number, treat it as a Unix timestamp
        return (double)arg;
    }

    if (METHOD_IS("lerp") && args.size() == 3) { r_handled = true; double a = args[0]; double b = args[1]; double t = args[2]; return Math::lerp(a,b,t); }
    if (METHOD_IS("lerpf") && args.size() == 3) { r_handled = true; double a = args[0]; double b = args[1]; double t = args[2]; return Math::lerp(a,b,t); }
    if (METHOD_IS("clamp") && args.size() == 3) { r_handled = true; double val = args[0]; double mn = args[1]; double mx = args[2]; return Math::clamp(val,mn,mx); }
    if (METHOD_IS("clampf") && args.size() == 3) { r_handled = true; double val = args[0]; double mn = args[1]; double mx = args[2]; return Math::clamp(val,mn,mx); }
    if (METHOD_IS("is_zero_approx") && args.size() == 1) { r_handled = true; return Math::is_zero_approx((double)args[0]); }

    // Min/Max functions
    if (METHOD_IS("min") && args.size() == 2) { r_handled = true; double a = (double)args[0]; double b = (double)args[1]; return a < b ? a : b; }
    if (METHOD_IS("max") && args.size() == 2) { r_handled = true; double a = (double)args[0]; double b = (double)args[1]; return a > b ? a : b; }

    // IIf(condition, trueValue, falseValue) - Immediate If
    if (METHOD_IS("iif") && args.size() == 3) {
        r_handled = true;
        bool cond = (bool)args[0];
        return cond ? args[1] : args[2];
    }

    // Choose(index, val1, val2, ...) - 1-based index selection
    // Also handles boolean first arg: Choose(True, a, b) -> a, Choose(False, a, b) -> b
    if (METHOD_IS("choose") && args.size() >= 2) {
        r_handled = true;
        Variant first = args[0];
        // If first arg is boolean, treat as IIf(cond, args[1], args[2])
        if (first.get_type() == Variant::BOOL) {
            bool cond = (bool)first;
            if (cond && args.size() >= 2) return args[1];
            if (!cond && args.size() >= 3) return args[2];
            return Variant();
        }
        // Standard VB6 Choose: 1-based index into remaining args
        int64_t idx = (int64_t)first;
        if (idx >= 1 && idx <= (int64_t)(args.size() - 1)) {
            return args[idx]; // args[1] = first choice, args[2] = second, etc.
        }
        return Variant(); // Out of range returns Null
    }

    // Switch(expr1, val1, expr2, val2, ...) - returns val for first true expr
    if (METHOD_IS("switch") && args.size() >= 2) {
        r_handled = true;
        for (int i = 0; i + 1 < args.size(); i += 2) {
            if ((bool)args[i]) return args[i + 1];
        }
        return Variant();
    }

    // Vector math helpers (works for Vector2 or Vector3 depending on input types)
    if (METHOD_IS("vec3") && args.size() == 3) { r_handled = true; return Vector3(args[0], args[1], args[2]); }
    if (METHOD_IS("vec2") && args.size() == 2) { r_handled = true; return Vector2(args[0], args[1]); }

    if (METHOD_IS("vadd") && args.size() == 2) {
        r_handled = true;
        Variant a = args[0]; Variant b = args[1];
        if (a.get_type() == Variant::VECTOR3 && b.get_type() == Variant::VECTOR3) return Vector3(a) + Vector3(b);
        if (a.get_type() == Variant::VECTOR2 && b.get_type() == Variant::VECTOR2) return Vector2(a) + Vector2(b);
        return Variant();
    }
    if (METHOD_IS("vsub") && args.size() == 2) {
        r_handled = true;
        Variant a = args[0]; Variant b = args[1];
        if (a.get_type() == Variant::VECTOR3 && b.get_type() == Variant::VECTOR3) return Vector3(a) - Vector3(b);
        if (a.get_type() == Variant::VECTOR2 && b.get_type() == Variant::VECTOR2) return Vector2(a) - Vector2(b);
        return Variant();
    }
    if (METHOD_IS("vmul") && args.size() == 2) {
        r_handled = true;
        Variant a = args[0]; Variant b = args[1];
        if (a.get_type() == Variant::VECTOR3 && b.get_type() == Variant::FLOAT) return Vector3(a) * (double)b;
        if (a.get_type() == Variant::VECTOR3 && b.get_type() == Variant::INT) return Vector3(a) * (double)(int64_t)b;
        if (a.get_type() == Variant::VECTOR2 && b.get_type() == Variant::FLOAT) return Vector2(a) * (double)b;
        if (a.get_type() == Variant::VECTOR2 && b.get_type() == Variant::INT) return Vector2(a) * (double)(int64_t)b;
        return Variant();
    }
    if (METHOD_IS("vdot") && args.size() == 2) {
        r_handled = true;
        Variant a = args[0]; Variant b = args[1];
        if (a.get_type() == Variant::VECTOR3 && b.get_type() == Variant::VECTOR3) return Vector3(a).dot(Vector3(b));
        if (a.get_type() == Variant::VECTOR2 && b.get_type() == Variant::VECTOR2) return Vector2(a).dot(Vector2(b));
        return Variant();
    }
    if (METHOD_IS("vcross") && args.size() == 2) {
        r_handled = true;
        Variant a = args[0]; Variant b = args[1];
        if (a.get_type() == Variant::VECTOR3 && b.get_type() == Variant::VECTOR3) return Vector3(a).cross(Vector3(b));
        return Variant();
    }
    if (METHOD_IS("vlen") && args.size() == 1) {
        r_handled = true;
        Variant a = args[0];
        if (a.get_type() == Variant::VECTOR3) return Vector3(a).length();
        if (a.get_type() == Variant::VECTOR2) return Vector2(a).length();
        return Variant();
    }
    if (METHOD_IS("vnormalize") && args.size() == 1) {
        r_handled = true;
        Variant a = args[0];
        if (a.get_type() == Variant::VECTOR3) return Vector3(a).normalized();
        if (a.get_type() == Variant::VECTOR2) return Vector2(a).normalized();
        return Variant();
    }
    if (METHOD_IS("vdistance") && args.size() == 2) {
        r_handled = true;
        Variant a = args[0]; Variant b = args[1];
        if (a.get_type() == Variant::VECTOR3 && b.get_type() == Variant::VECTOR3) return Vector3(a).distance_to(Vector3(b));
        if (a.get_type() == Variant::VECTOR2 && b.get_type() == Variant::VECTOR2) return Vector2(a).distance_to(Vector2(b));
        return Variant();
    }
    if (METHOD_IS("vlerp") && args.size() == 3) {
        r_handled = true;
        Variant a = args[0]; Variant b = args[1]; double t = args[2];
        if (a.get_type() == Variant::VECTOR3 && b.get_type() == Variant::VECTOR3) return Vector3(a).lerp(Vector3(b), t);
        if (a.get_type() == Variant::VECTOR2 && b.get_type() == Variant::VECTOR2) return Vector2(a).lerp(Vector2(b), t);
        return Variant();
    }

    // Convenience property setter: SetProp(obj, "prop_name", value)
    if (METHOD_IS("setprop") && args.size() == 3) {
        r_handled = true;
        Variant obj_v = args[0];
        String prop = args[1];
        Variant val = args[2];
        if (obj_v.get_type() == Variant::OBJECT) {
            Object *o = obj_v;
            if (o) {
                o->set(prop, val);
                if (o->get(prop).get_type() == Variant::NIL) {
                    o->set(prop.to_snake_case(), val);
                }
            }
        }
        return Variant();
    }

    // String functions
    if (METHOD_IS("startswith") && args.size() == 2) {
        r_handled = true;
        String text = String(args[0]);
        String prefix = String(args[1]);
        return text.begins_with(prefix);
    }
    
    if (METHOD_IS("endswith") && args.size() == 2) {
        r_handled = true;
        String text = String(args[0]);
        String suffix = String(args[1]);
        return text.ends_with(suffix);
    }
    
    if (METHOD_IS("padleft") && (args.size() == 2 || args.size() == 3)) {
        r_handled = true;
        String text = String(args[0]);
        int length = int(args[1]);
        String pad_char = args.size() == 3 ? String(args[2]) : " ";
        if (pad_char.length() > 0) {
            while (text.length() < length) {
                text = pad_char.substr(0, 1) + text;
            }
        }
        return text;
    }
    
    if (METHOD_IS("padright") && (args.size() == 2 || args.size() == 3)) {
        r_handled = true;
        String text = String(args[0]);
        int length = int(args[1]);
        String pad_char = args.size() == 3 ? String(args[2]) : " ";
        if (pad_char.length() > 0) {
            while (text.length() < length) {
                text = text + pad_char.substr(0, 1);
            }
        }
        return text;
    }


    // Extended Array Functions
    if (METHOD_IS("allocfilli64") && args.size() == 1) {
        r_handled = true;
        int64_t count = (int64_t)args[0];
        if (count < 0) count = 0;
        PackedInt64Array arr;
        arr.resize((int)count);
        int64_t *w = arr.ptrw();
        for (int64_t i = 0; i < count; i++) {
            w[i] = i;
        }
        return arr;
    }
    if (METHOD_IS("allocfilli64sum") && args.size() == 1) {
        r_handled = true;
        int64_t count = (int64_t)args[0];
        if (count < 0) count = 0;
        PackedInt64Array arr;
        arr.resize((int)count);
        int64_t *w = arr.ptrw();
        for (int64_t i = 0; i < count; i++) {
            w[i] = i;
        }
        return count;
    }
    if (METHOD_IS("push") && args.size() == 2) {
        r_handled = true;
        Variant input = args[0];
        Variant new_item = args[1];
        if (input.get_type() == Variant::ARRAY) {
            Array arr = input;
            Array new_arr = arr.duplicate();
            new_arr.append(new_item);
            return new_arr;
        }
        return input;
    }
    
    if (METHOD_IS("pop") && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::ARRAY) {
            Array arr = input;
            if (arr.size() > 0) {
                return arr[arr.size() - 1];
            }
        }
        return Variant();
    }
    
    if (METHOD_IS("slice") && args.size() >= 2) {
        r_handled = true;
        Variant input = args[0];
        int start = int(args[1]);
        int end = args.size() > 2 ? int(args[2]) : -1;
        
        if (input.get_type() == Variant::ARRAY) {
            Array arr = input;
            Array sliced;
            if (end == -1) end = arr.size();
            
            for (int i = start; i < end && i < arr.size(); i++) {
                if (i >= 0) sliced.append(arr[i]);
            }
            return sliced;
        }
        return input;
    }
    if (METHOD_IS("sort") && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::ARRAY) {
            Array arr = input;
            Array sorted_arr = arr.duplicate();
            
            // Simple bubble sort for mixed types
            int n = sorted_arr.size();
            for (int i = 0; i < n - 1; i++) {
                for (int j = 0; j < n - i - 1; j++) {
                    Variant a = sorted_arr[j];
                    Variant b = sorted_arr[j + 1];
                    
                    // Compare based on type
                    bool should_swap = false;
                    if (a.get_type() == b.get_type()) {
                        if (a.get_type() == Variant::INT || a.get_type() == Variant::FLOAT) {
                            should_swap = (double)a > (double)b;
                        } else if (a.get_type() == Variant::STRING) {
                            should_swap = String(a).naturalnocasecmp_to(String(b)) > 0;
                        }
                    } else {
                        // Different types: convert to strings for comparison
                        should_swap = String(a).naturalnocasecmp_to(String(b)) > 0;
                    }
                    
                    if (should_swap) {
                        sorted_arr[j] = b;
                        sorted_arr[j + 1] = a;
                    }
                }
            }
            return sorted_arr;
        }
        return input;
    }

    if (METHOD_IS("reverse") && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::ARRAY) {
            Array arr = input;
            Array reversed_arr;
            for (int i = arr.size() - 1; i >= 0; i--) {
                reversed_arr.append(arr[i]);
            }
            return reversed_arr;
        }
        return input;
    }

    if (METHOD_IS("indexof") && args.size() == 2) {
        r_handled = true;
        Variant input = args[0];
        Variant search_val = args[1];
        if (input.get_type() == Variant::ARRAY) {
            Array arr = input;
            for (int i = 0; i < arr.size(); i++) {
                if (arr[i] == search_val) {
                    return i;
                }
            }
        }
        return -1;
    }

    if (METHOD_IS("contains") && args.size() == 2) {
        r_handled = true;
        Variant input = args[0];
        Variant search_val = args[1];
        
        // Handle string contains
        if (input.get_type() == Variant::STRING) {
            String text = String(input);
            String search = String(search_val);
            return text.contains(search);
        }
        
        // Handle array contains
        if (input.get_type() == Variant::ARRAY) {
            Array arr = input;
            for (int i = 0; i < arr.size(); i++) {
                if (arr[i] == search_val) {
                    return true;
                }
            }
        }
        return false;
    }

    if (METHOD_IS("unique") && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::ARRAY) {
            Array arr = input;
            Array unique_arr;
            for (int i = 0; i < arr.size(); i++) {
                bool found = false;
                for (int j = 0; j < unique_arr.size(); j++) {
                    if (unique_arr[j] == arr[i]) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    unique_arr.append(arr[i]);
                }
            }
            return unique_arr;
        }
        return input;
    }

    if (METHOD_IS("flatten") && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::ARRAY) {
            Array arr = input;
            Array flat_arr;
            for (int i = 0; i < arr.size(); i++) {
                if (arr[i].get_type() == Variant::ARRAY) {
                    Array sub_arr = arr[i];
                    for (int j = 0; j < sub_arr.size(); j++) {
                        flat_arr.append(sub_arr[j]);
                    }
                } else {
                    flat_arr.append(arr[i]);
                }
            }
            return flat_arr;
        }
        return input;
    }
    
    if (METHOD_IS("push") && args.size() == 2) {
        r_handled = true;
        Variant input = args[0];
        Variant new_item = args[1];
        if (input.get_type() == Variant::ARRAY) {
            Array arr = input;
            Array new_arr = arr.duplicate();
            new_arr.append(new_item);
            return new_arr;
        }
        return input;
    }
    
    if (METHOD_IS("pop") && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::ARRAY) {
            Array arr = input;
            if (arr.size() > 0) {
                return arr[arr.size() - 1];
            }
        }
        return Variant();
    }
    
    if (METHOD_IS("slice") && args.size() >= 2) {
        r_handled = true;
        Variant input = args[0];
        int start = int(args[1]);
        int end = args.size() > 2 ? int(args[2]) : -1;
        
        if (input.get_type() == Variant::ARRAY) {
            Array arr = input;
            Array sliced;
            if (end == -1) end = arr.size();
            
            for (int i = start; i < end && i < arr.size(); i++) {
                if (i >= 0) sliced.append(arr[i]);
            }
            return sliced;
        }
        return input;
    }
    
    if (METHOD_IS("repeat") && args.size() == 2) {
        r_handled = true;
        Variant item = args[0];
        int count = int(args[1]);
        Array repeated;
        
        for (int i = 0; i < count; i++) {
            repeated.append(item);
        }
        return repeated;
    }
    
    if (METHOD_IS("zip") && args.size() == 2) {
        r_handled = true;
        Variant input1 = args[0];
        Variant input2 = args[1];
        
        if (input1.get_type() == Variant::ARRAY && input2.get_type() == Variant::ARRAY) {
            Array arr1 = input1;
            Array arr2 = input2;
            Array zipped;
            
            int min_size = Math::min(arr1.size(), arr2.size());
            for (int i = 0; i < min_size; i++) {
                Array pair;
                pair.append(arr1[i]);
                pair.append(arr2[i]);
                zipped.append(pair);
            }
            return zipped;
        }
        return Array();
    }
    
    if (METHOD_IS("range") && (args.size() >= 2 && args.size() <= 3)) {
        r_handled = true;
        int start = int(args[0]);
        int end = int(args[1]);
        int step = args.size() == 3 ? int(args[2]) : 1;
        
        Array range;
        if (step > 0) {
            for (int i = start; i <= end; i += step) {
                range.append(i);
            }
        } else if (step < 0) {
            for (int i = start; i >= end; i += step) {
                range.append(i);
            }
        }
        return range;
    }
    
    // Dictionary functions
    if (METHOD_IS("keys") && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            return dict.keys();
        }
        return Array();
    }
    
    if (METHOD_IS("values") && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            return dict.values();
        }
        return Array();
    }
    
    if (METHOD_IS("haskey") && args.size() == 2) {
        r_handled = true;
        Variant input = args[0];
        Variant key = args[1];
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            return dict.has(key);
        }
        return false;
    }
    
    if (METHOD_IS("merge") && args.size() == 2) {
        r_handled = true;
        Variant input1 = args[0];
        Variant input2 = args[1];
        
        if (input1.get_type() == Variant::DICTIONARY && input2.get_type() == Variant::DICTIONARY) {
            Dictionary dict1 = input1;
            Dictionary dict2 = input2;
            Dictionary merged = dict1.duplicate();
            
            Array keys2 = dict2.keys();
            for (int i = 0; i < keys2.size(); i++) {
                merged[keys2[i]] = dict2[keys2[i]];
            }
            return merged;
        }
        return input1;
    }
    
    if (METHOD_IS("remove") && args.size() == 2) {
        r_handled = true;
        Variant input = args[0];
        Variant key = args[1];
        
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            Dictionary new_dict = dict.duplicate();
            new_dict.erase(key);
            return new_dict;
        }
        return input;
    }
    
    // Type checking functions
    if (METHOD_IS("isarray") && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::ARRAY;
    }
    
    if (METHOD_IS("isdict") && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::DICTIONARY;
    }
    
    if (METHOD_IS("isstring") && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::STRING;
    }
    
    if (METHOD_IS("isnumber") && args.size() == 1) {
        r_handled = true;
        Variant::Type type = args[0].get_type();
        return type == Variant::INT || type == Variant::FLOAT;
    }
    
    if (METHOD_IS("isnull") && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::NIL;
    }
    
    if (METHOD_IS("typename") && args.size() == 1) {
        r_handled = true;
        Variant::Type t = args[0].get_type();
        switch (t) {
            case Variant::INT: return "Integer";
            case Variant::FLOAT: return "Double";
            case Variant::STRING: return "String";
            case Variant::BOOL: return "Boolean";
            case Variant::ARRAY: return "Array";
            case Variant::DICTIONARY: return "Dictionary";
            case Variant::OBJECT: return "Object";
            case Variant::NIL: return "Nothing";
            default: return Variant::get_type_name(t);
        }
    }
    
    // VB6 type checking functions
    if (METHOD_IS("isnumeric") && args.size() == 1) {
        r_handled = true;
        Variant v = args[0];
        if (v.get_type() == Variant::INT || v.get_type() == Variant::FLOAT) return true;
        if (v.get_type() == Variant::STRING) {
            String s = String(v).strip_edges();
            if (s.is_empty()) return false;
            return s.is_valid_float() || s.is_valid_int();
        }
        return false;
    }
    
    // IsDate - checks if value can be converted to a date
    if (METHOD_IS("isdate") && args.size() == 1) {
        r_handled = true;
        Variant v = args[0];
        // In VB6, IsDate returns True if the expression can be converted to a date
        if (v.get_type() == Variant::NIL) return false;
        if (v.get_type() == Variant::STRING) {
            String s = String(v).strip_edges();
            if (s.is_empty()) return false;
            // Try to parse common date formats
            // VB6 accepts formats like "1/1/2000", "January 1, 2000", "2000-01-01"
            // For simplicity, check if it contains date-like patterns
            // Godot doesn't have built-in date parsing, so we'll do basic checks
            if (s.contains("/") || s.contains("-")) {
                // Check for numeric date pattern like 1/1/2000 or 2000-01-01
                PackedStringArray parts;
                if (s.contains("/")) parts = s.split("/");
                else parts = s.split("-");
                if (parts.size() >= 3) {
                    bool all_numeric = true;
                    for (int i = 0; i < parts.size() && i < 3; i++) {
                        if (!parts[i].strip_edges().is_valid_int()) {
                            all_numeric = false;
                            break;
                        }
                    }
                    return all_numeric;
                }
            }
            return false;
        }
        // Godot doesn't have a native Date type, but INT/FLOAT could be Unix timestamps
        if (v.get_type() == Variant::INT || v.get_type() == Variant::FLOAT) {
            // Consider numbers as potentially valid date serials (VB6 stores dates as doubles)
            return true;
        }
        return false;
    }
    
    // IsEmpty - checks if variable is uninitialized (Empty in VB6)
    if (METHOD_IS("isempty") && args.size() == 1) {
        r_handled = true;
        Variant v = args[0];
        // In VB6, Empty is the uninitialized state of a Variant
        // It's different from Null - Empty means "no value assigned yet"
        if (v.get_type() == Variant::NIL) return true;
        // Empty string is also considered "empty" in VB6 context
        if (v.get_type() == Variant::STRING && String(v).is_empty()) return true;
        // Zero numeric values are NOT empty in VB6 (0 is a value)
        return false;
    }
    
    // IsNull - checks if value is Null
    if (METHOD_IS("isnull") && args.size() == 1) {
        r_handled = true;
        Variant v = args[0];
        // In VB6, Null represents "no valid data" - distinct from Empty
        // In Godot/VisualGasic, NIL is the closest equivalent
        return v.get_type() == Variant::NIL;
    }
    
    // IsObject - checks if value is an object reference
    if (METHOD_IS("isobject") && args.size() == 1) {
        r_handled = true;
        Variant v = args[0];
        // Returns True if the expression represents an Object variable
        return v.get_type() == Variant::OBJECT || v.get_type() == Variant::DICTIONARY;
    }
    
    if (METHOD_IS("vartype") && args.size() == 1) {
        r_handled = true;
        // VB6 VarType constants: vbEmpty=0, vbNull=1, vbInteger=2, vbLong=3, vbSingle=4, vbDouble=5, vbString=8, vbObject=9, vbBoolean=11, vbVariant=12, vbArray=8192
        Variant::Type t = args[0].get_type();
        switch (t) {
            case Variant::NIL: return 1;  // vbNull
            case Variant::BOOL: return 11;  // vbBoolean
            case Variant::INT: return 3;  // vbLong
            case Variant::FLOAT: return 5;  // vbDouble
            case Variant::STRING: return 8;  // vbString
            case Variant::OBJECT: return 9;  // vbObject
            case Variant::ARRAY: return 8192 + 12;  // vbArray + vbVariant
            case Variant::DICTIONARY: return 9;  // vbObject (closest match)
            default: return 0;  // vbEmpty
        }
    }
    
    // ============================================
    // Date/Time Functions (VB6 compatible)
    // ============================================
    
    // Now - returns current date/time as a string (VB6 compatible format)
    if (METHOD_IS("now") && args.size() == 0) {
        r_handled = true;
        Dictionary datetime = Time::get_singleton()->get_datetime_dict_from_system();
        int year = (int)datetime["year"];
        int month = (int)datetime["month"];
        int day = (int)datetime["day"];
        int hour = (int)datetime["hour"];
        int minute = (int)datetime["minute"];
        int second = (int)datetime["second"];
        // Format: MM/DD/YYYY HH:MM:SS AM/PM (VB6 style)
        String ampm = hour >= 12 ? "PM" : "AM";
        int hour12 = hour % 12;
        if (hour12 == 0) hour12 = 12;
        return String::num_int64(month) + "/" + String::num_int64(day) + "/" + String::num_int64(year) + " " +
               String::num_int64(hour12) + ":" + (minute < 10 ? "0" : "") + String::num_int64(minute) + ":" + 
               (second < 10 ? "0" : "") + String::num_int64(second) + " " + ampm;
    }
    
    // Date - returns current date as string
    if (METHOD_IS("date") && args.size() == 0) {
        r_handled = true;
        Dictionary datetime = Time::get_singleton()->get_datetime_dict_from_system();
        int year = (int)datetime["year"];
        int month = (int)datetime["month"];
        int day = (int)datetime["day"];
        return String::num_int64(month) + "/" + String::num_int64(day) + "/" + String::num_int64(year);
    }
    
    // Time - returns current time as string
    if (METHOD_IS("time") && args.size() == 0) {
        r_handled = true;
        Dictionary datetime = Time::get_singleton()->get_datetime_dict_from_system();
        int hour = (int)datetime["hour"];
        int minute = (int)datetime["minute"];
        int second = (int)datetime["second"];
        String ampm = hour >= 12 ? "PM" : "AM";
        int hour12 = hour % 12;
        if (hour12 == 0) hour12 = 12;
        return String::num_int64(hour12) + ":" + (minute < 10 ? "0" : "") + String::num_int64(minute) + ":" + 
               (second < 10 ? "0" : "") + String::num_int64(second) + " " + ampm;
    }
    
    // Year(date) - extracts year from date string or serial
    if (METHOD_IS("year") && args.size() == 1) {
        r_handled = true;
        Variant v = args[0];
        if (v.get_type() == Variant::STRING) {
            String s = String(v);
            // Try to parse MM/DD/YYYY or YYYY-MM-DD
            if (s.contains("/")) {
                PackedStringArray parts = s.split("/");
                if (parts.size() >= 3) return (int64_t)parts[2].to_int();
            } else if (s.contains("-")) {
                PackedStringArray parts = s.split("-");
                if (parts.size() >= 1) return (int64_t)parts[0].to_int();
            }
        } else if (v.get_type() == Variant::INT || v.get_type() == Variant::FLOAT) {
            // Treat as Unix timestamp
            int64_t ts = (int64_t)v;
            Dictionary datetime = Time::get_singleton()->get_datetime_dict_from_unix_time(ts);
            return (int64_t)(int)datetime["year"];
        }
        return 0;
    }
    
    // Month(date) - extracts month from date string or serial
    if (METHOD_IS("month") && args.size() == 1) {
        r_handled = true;
        Variant v = args[0];
        if (v.get_type() == Variant::STRING) {
            String s = String(v);
            if (s.contains("/")) {
                PackedStringArray parts = s.split("/");
                if (parts.size() >= 1) return (int64_t)parts[0].to_int();
            } else if (s.contains("-")) {
                PackedStringArray parts = s.split("-");
                if (parts.size() >= 2) return (int64_t)parts[1].to_int();
            }
        } else if (v.get_type() == Variant::INT || v.get_type() == Variant::FLOAT) {
            int64_t ts = (int64_t)v;
            Dictionary datetime = Time::get_singleton()->get_datetime_dict_from_unix_time(ts);
            return (int64_t)(int)datetime["month"];
        }
        return 0;
    }
    
    // Day(date) - extracts day from date string or serial
    if (METHOD_IS("day") && args.size() == 1) {
        r_handled = true;
        Variant v = args[0];
        if (v.get_type() == Variant::STRING) {
            String s = String(v);
            if (s.contains("/")) {
                PackedStringArray parts = s.split("/");
                if (parts.size() >= 2) return (int64_t)parts[1].to_int();
            } else if (s.contains("-")) {
                PackedStringArray parts = s.split("-");
                if (parts.size() >= 3) return (int64_t)parts[2].to_int();
            }
        } else if (v.get_type() == Variant::INT || v.get_type() == Variant::FLOAT) {
            int64_t ts = (int64_t)v;
            Dictionary datetime = Time::get_singleton()->get_datetime_dict_from_unix_time(ts);
            return (int64_t)(int)datetime["day"];
        }
        return 0;
    }
    
    // Hour(time) - extracts hour from time string or serial
    if (METHOD_IS("hour") && args.size() == 1) {
        r_handled = true;
        Variant v = args[0];
        if (v.get_type() == Variant::STRING) {
            String s = String(v);
            String time_part = s;
            bool is_pm = s.to_upper().contains("PM");
            bool is_am = s.to_upper().contains("AM");
            
            // Handle date/time combo like "6/15/2024 2:30:45 PM"
            if (s.contains("/") && s.contains(" ")) {
                PackedStringArray dt_parts = s.split(" ");
                if (dt_parts.size() >= 2) {
                    // Skip the date part, get time portion
                    time_part = "";
                    for (int i = 1; i < dt_parts.size(); i++) {
                        if (dt_parts[i].contains(":")) {
                            time_part = dt_parts[i];
                            break;
                        }
                    }
                }
            }
            // Handle standalone time with AM/PM like "3:45:30 PM"
            else if (s.contains(":") && s.contains(" ")) {
                time_part = s.split(" ")[0];  // Get the time portion before AM/PM
            }
            
            // Parse HH:MM:SS
            if (time_part.contains(":")) {
                PackedStringArray parts = time_part.split(":");
                if (parts.size() >= 1) {
                    int h = parts[0].to_int();
                    // Check for AM/PM
                    if (is_pm && h != 12) h += 12;
                    else if (is_am && h == 12) h = 0;
                    return (int64_t)h;
                }
            }
        } else if (v.get_type() == Variant::INT || v.get_type() == Variant::FLOAT) {
            int64_t ts = (int64_t)v;
            Dictionary datetime = Time::get_singleton()->get_datetime_dict_from_unix_time(ts);
            return (int64_t)(int)datetime["hour"];
        }
        return 0;
    }
    
    // Minute(time) - extracts minute from time string or serial
    if (METHOD_IS("minute") && args.size() == 1) {
        r_handled = true;
        Variant v = args[0];
        if (v.get_type() == Variant::STRING) {
            String s = String(v);
            String time_part = s;
            
            // Handle date/time combo
            if (s.contains("/") && s.contains(" ")) {
                PackedStringArray dt_parts = s.split(" ");
                for (int i = 1; i < dt_parts.size(); i++) {
                    if (dt_parts[i].contains(":")) {
                        time_part = dt_parts[i];
                        break;
                    }
                }
            }
            // Handle standalone time with AM/PM
            else if (s.contains(":") && s.contains(" ")) {
                time_part = s.split(" ")[0];
            }
            
            if (time_part.contains(":")) {
                PackedStringArray parts = time_part.split(":");
                if (parts.size() >= 2) return (int64_t)parts[1].to_int();
            }
        } else if (v.get_type() == Variant::INT || v.get_type() == Variant::FLOAT) {
            int64_t ts = (int64_t)v;
            Dictionary datetime = Time::get_singleton()->get_datetime_dict_from_unix_time(ts);
            return (int64_t)(int)datetime["minute"];
        }
        return 0;
    }
    
    // Second(time) - extracts second from time string or serial
    if (METHOD_IS("second") && args.size() == 1) {
        r_handled = true;
        Variant v = args[0];
        if (v.get_type() == Variant::STRING) {
            String s = String(v);
            String time_part = s;
            
            // Handle date/time combo
            if (s.contains("/") && s.contains(" ")) {
                PackedStringArray dt_parts = s.split(" ");
                for (int i = 1; i < dt_parts.size(); i++) {
                    if (dt_parts[i].contains(":")) {
                        time_part = dt_parts[i];
                        break;
                    }
                }
            }
            // Handle standalone time with AM/PM
            else if (s.contains(":") && s.contains(" ")) {
                time_part = s.split(" ")[0];
            }
            
            if (time_part.contains(":")) {
                PackedStringArray parts = time_part.split(":");
                if (parts.size() >= 3) {
                    return (int64_t)parts[2].to_int();
                }
            }
        } else if (v.get_type() == Variant::INT || v.get_type() == Variant::FLOAT) {
            int64_t ts = (int64_t)v;
            Dictionary datetime = Time::get_singleton()->get_datetime_dict_from_unix_time(ts);
            return (int64_t)(int)datetime["second"];
        }
        return 0;
    }
    
    // DateSerial(year, month, day) - creates a date from components
    if (METHOD_IS("dateserial") && args.size() == 3) {
        r_handled = true;
        int year = (int)args[0];
        int month = (int)args[1];
        int day = (int)args[2];
        // Return as MM/DD/YYYY string (VB6 format)
        return String::num_int64(month) + "/" + String::num_int64(day) + "/" + String::num_int64(year);
    }
    
    // TimeSerial(hour, minute, second) - creates a time from components
    if (METHOD_IS("timeserial") && args.size() == 3) {
        r_handled = true;
        int hour = (int)args[0];
        int minute = (int)args[1];
        int second = (int)args[2];
        String ampm = hour >= 12 ? "PM" : "AM";
        int hour12 = hour % 12;
        if (hour12 == 0) hour12 = 12;
        return String::num_int64(hour12) + ":" + (minute < 10 ? "0" : "") + String::num_int64(minute) + ":" + 
               (second < 10 ? "0" : "") + String::num_int64(second) + " " + ampm;
    }
    
    // DateAdd(interval, number, date) - adds interval to date
    // Intervals: "yyyy" (year), "m" (month), "d" (day), "h" (hour), "n" (minute), "s" (second)
    if (METHOD_IS("dateadd") && args.size() == 3) {
        r_handled = true;
        String interval = String(args[0]).to_lower();
        int number = (int)args[1];
        String date_str = String(args[2]);
        
        // Parse the date
        int year = 0, month = 0, day = 0, hour = 0, minute = 0, second = 0;
        bool has_time = date_str.contains(":");
        
        // Parse date portion
        String date_part = date_str;
        String time_part = "";
        if (has_time && date_str.contains(" ")) {
            PackedStringArray dt_parts = date_str.split(" ");
            date_part = dt_parts[0];
            if (dt_parts.size() >= 2) time_part = dt_parts[1];
        }
        
        if (date_part.contains("/")) {
            PackedStringArray parts = date_part.split("/");
            if (parts.size() >= 3) {
                month = parts[0].to_int();
                day = parts[1].to_int();
                year = parts[2].to_int();
            }
        } else if (date_part.contains("-")) {
            PackedStringArray parts = date_part.split("-");
            if (parts.size() >= 3) {
                year = parts[0].to_int();
                month = parts[1].to_int();
                day = parts[2].to_int();
            }
        }
        
        // Parse time if present
        if (!time_part.is_empty() && time_part.contains(":")) {
            PackedStringArray parts = time_part.split(":");
            if (parts.size() >= 1) hour = parts[0].to_int();
            if (parts.size() >= 2) minute = parts[1].to_int();
            if (parts.size() >= 3) {
                String sec_str = parts[2];
                if (sec_str.contains(" ")) sec_str = sec_str.split(" ")[0];
                second = sec_str.to_int();
            }
            // Handle AM/PM
            if (time_part.to_upper().contains("PM") && hour != 12) hour += 12;
            else if (time_part.to_upper().contains("AM") && hour == 12) hour = 0;
        }
        
        // Apply the interval
        if (interval == "yyyy" || interval == "y") year += number;
        else if (interval == "m") month += number;
        else if (interval == "d") day += number;
        else if (interval == "h") hour += number;
        else if (interval == "n") minute += number;
        else if (interval == "s") second += number;
        
        // Normalize using Godot's time functions
        Dictionary dt;
        dt["year"] = year;
        dt["month"] = month;
        dt["day"] = day;
        dt["hour"] = hour;
        dt["minute"] = minute;
        dt["second"] = second;
        int64_t unix_ts = Time::get_singleton()->get_unix_time_from_datetime_dict(dt);
        Dictionary result = Time::get_singleton()->get_datetime_dict_from_unix_time(unix_ts);
        
        year = (int)result["year"];
        month = (int)result["month"];
        day = (int)result["day"];
        hour = (int)result["hour"];
        minute = (int)result["minute"];
        second = (int)result["second"];
        
        if (has_time) {
            String ampm = hour >= 12 ? "PM" : "AM";
            int hour12 = hour % 12;
            if (hour12 == 0) hour12 = 12;
            return String::num_int64(month) + "/" + String::num_int64(day) + "/" + String::num_int64(year) + " " +
                   String::num_int64(hour12) + ":" + (minute < 10 ? "0" : "") + String::num_int64(minute) + ":" + 
                   (second < 10 ? "0" : "") + String::num_int64(second) + " " + ampm;
        }
        return String::num_int64(month) + "/" + String::num_int64(day) + "/" + String::num_int64(year);
    }
    
    // DateDiff(interval, date1, date2) - returns difference between dates
    if (METHOD_IS("datediff") && args.size() == 3) {
        r_handled = true;
        String interval = String(args[0]).to_lower();
        String date1_str = String(args[1]);
        String date2_str = String(args[2]);
        
        // Helper lambda to parse date to unix timestamp
        auto parse_to_unix = [](const String& ds) -> int64_t {
            int year = 0, month = 1, day = 1, hour = 0, minute = 0, second = 0;
            String date_part = ds;
            String time_part = "";
            if (ds.contains(" ")) {
                PackedStringArray dt_parts = ds.split(" ");
                date_part = dt_parts[0];
                if (dt_parts.size() >= 2) time_part = dt_parts[1];
            }
            
            if (date_part.contains("/")) {
                PackedStringArray parts = date_part.split("/");
                if (parts.size() >= 3) {
                    month = parts[0].to_int();
                    day = parts[1].to_int();
                    year = parts[2].to_int();
                }
            } else if (date_part.contains("-")) {
                PackedStringArray parts = date_part.split("-");
                if (parts.size() >= 3) {
                    year = parts[0].to_int();
                    month = parts[1].to_int();
                    day = parts[2].to_int();
                }
            }
            
            if (!time_part.is_empty() && time_part.contains(":")) {
                PackedStringArray parts = time_part.split(":");
                if (parts.size() >= 1) hour = parts[0].to_int();
                if (parts.size() >= 2) minute = parts[1].to_int();
                if (parts.size() >= 3) {
                    String sec_str = parts[2];
                    if (sec_str.contains(" ")) sec_str = sec_str.split(" ")[0];
                    second = sec_str.to_int();
                }
                if (time_part.to_upper().contains("PM") && hour != 12) hour += 12;
                else if (time_part.to_upper().contains("AM") && hour == 12) hour = 0;
            }
            
            Dictionary dt;
            dt["year"] = year;
            dt["month"] = month;
            dt["day"] = day;
            dt["hour"] = hour;
            dt["minute"] = minute;
            dt["second"] = second;
            return Time::get_singleton()->get_unix_time_from_datetime_dict(dt);
        };
        
        int64_t ts1 = parse_to_unix(date1_str);
        int64_t ts2 = parse_to_unix(date2_str);
        int64_t diff_seconds = ts2 - ts1;
        
        if (interval == "s") return diff_seconds;
        if (interval == "n") return diff_seconds / 60;
        if (interval == "h") return diff_seconds / 3600;
        if (interval == "d") return diff_seconds / 86400;
        if (interval == "m") return diff_seconds / (86400 * 30);  // Approximate
        if (interval == "yyyy" || interval == "y") return diff_seconds / (86400 * 365);  // Approximate
        
        return diff_seconds;
    }
    
    // DatePart(interval, date) - extracts part of a date
    if (METHOD_IS("datepart") && args.size() == 2) {
        r_handled = true;
        String interval = String(args[0]).to_lower();
        String date_str = String(args[1]);
        
        int year = 0, month = 0, day = 0, hour = 0, minute = 0, second = 0;
        String date_part = date_str;
        String time_part = "";
        if (date_str.contains(" ")) {
            PackedStringArray dt_parts = date_str.split(" ");
            date_part = dt_parts[0];
            if (dt_parts.size() >= 2) time_part = dt_parts[1];
        }
        
        if (date_part.contains("/")) {
            PackedStringArray parts = date_part.split("/");
            if (parts.size() >= 3) {
                month = parts[0].to_int();
                day = parts[1].to_int();
                year = parts[2].to_int();
            }
        } else if (date_part.contains("-")) {
            PackedStringArray parts = date_part.split("-");
            if (parts.size() >= 3) {
                year = parts[0].to_int();
                month = parts[1].to_int();
                day = parts[2].to_int();
            }
        }
        
        if (!time_part.is_empty() && time_part.contains(":")) {
            PackedStringArray parts = time_part.split(":");
            if (parts.size() >= 1) hour = parts[0].to_int();
            if (parts.size() >= 2) minute = parts[1].to_int();
            if (parts.size() >= 3) {
                String sec_str = parts[2];
                if (sec_str.contains(" ")) sec_str = sec_str.split(" ")[0];
                second = sec_str.to_int();
            }
            if (time_part.to_upper().contains("PM") && hour != 12) hour += 12;
            else if (time_part.to_upper().contains("AM") && hour == 12) hour = 0;
        }
        
        if (interval == "yyyy" || interval == "y") return (int64_t)year;
        if (interval == "m") return (int64_t)month;
        if (interval == "d") return (int64_t)day;
        if (interval == "h") return (int64_t)hour;
        if (interval == "n") return (int64_t)minute;
        if (interval == "s") return (int64_t)second;
        
        return 0;
    }

    // Weekday(date, [firstDayOfWeek]) — returns 1..7 (Sunday=1 by default, VB6 convention)
    if (METHOD_IS("weekday") && args.size() >= 1) {
        r_handled = true;
        String date_str = String(args[0]);
        int first_dow = (args.size() >= 2) ? (int)args[1] : 1; // 1 = vbSunday
        // Parse MM/DD/YYYY
        PackedStringArray parts = date_str.split("/");
        if (parts.size() >= 3) {
            int m = parts[0].to_int(), d = parts[1].to_int(), y = parts[2].to_int();
            // Tomohiko Sakamoto's algorithm — returns 0=Sunday..6=Saturday
            static int t[] = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4};
            if (m < 3) y -= 1;
            int dow = (y + y/4 - y/100 + y/400 + t[m-1] + d) % 7; // 0=Sun
            // VB6: Sunday=1 with offset by firstDayOfWeek
            int result = ((dow - (first_dow - 1) + 7) % 7) + 1;
            return result;
        }
        return 1; // default Sunday
    }

    // WeekdayName(weekday, [abbreviate], [firstDayOfWeek])
    if (METHOD_IS("weekdayname") && args.size() >= 1) {
        r_handled = true;
        int wd = (int)args[0]; // 1-based (1=Sunday in VB6 default)
        bool abbr = (args.size() >= 2) ? (bool)args[1] : false;
        const char* names_full[] = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"};
        const char* names_abbr[] = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"};
        int idx = ((wd - 1) % 7 + 7) % 7;
        return String(abbr ? names_abbr[idx] : names_full[idx]);
    }

    // MonthName(month, [abbreviate])
    if (METHOD_IS("monthname") && args.size() >= 1) {
        r_handled = true;
        int m = (int)args[0]; // 1-based
        bool abbr = (args.size() >= 2) ? (bool)args[1] : false;
        const char* names_full[] = {"January","February","March","April","May","June",
                                    "July","August","September","October","November","December"};
        const char* names_abbr[] = {"Jan","Feb","Mar","Apr","May","Jun",
                                    "Jul","Aug","Sep","Oct","Nov","Dec"};
        if (m < 1 || m > 12) return String("");
        return String(abbr ? names_abbr[m-1] : names_full[m-1]);
    }

    // Format(value, format) - formats a value according to format string
    if (METHOD_IS("format") && args.size() >= 1) {
        r_handled = true;
        Variant value = args[0];
        String fmt = args.size() > 1 ? String(args[1]) : "";
        
        // Date/Time formatting
        if (value.get_type() == Variant::STRING && (String(value).contains("/") || String(value).contains(":"))) {
            String date_str = String(value);
            int year = 0, month = 0, day = 0, hour = 0, minute = 0, second = 0;
            bool has_am_pm = date_str.to_upper().contains("AM") || date_str.to_upper().contains("PM");
            bool is_pm = date_str.to_upper().contains("PM");
            
            String date_part = "";
            String time_part = "";
            
            // Check if it's just a time string (no date, but has colons) like "3:45:30 PM"
            if (!date_str.contains("/") && date_str.contains(":")) {
                // It's a time-only string
                if (date_str.contains(" ")) {
                    time_part = date_str.split(" ")[0];  // Get "3:45:30" from "3:45:30 PM"
                } else {
                    time_part = date_str;
                }
            }
            // Date and possibly time
            else if (date_str.contains(" ") && date_str.contains("/")) {
                PackedStringArray dt_parts = date_str.split(" ");
                date_part = dt_parts[0];
                // Find the time portion (part with colons)
                for (int i = 1; i < dt_parts.size(); i++) {
                    if (dt_parts[i].contains(":")) {
                        time_part = dt_parts[i];
                        break;
                    }
                }
            } else {
                date_part = date_str;
            }
            
            if (!date_part.is_empty() && date_part.contains("/")) {
                PackedStringArray parts = date_part.split("/");
                if (parts.size() >= 3) {
                    month = parts[0].to_int();
                    day = parts[1].to_int();
                    year = parts[2].to_int();
                }
            }
            
            if (!time_part.is_empty() && time_part.contains(":")) {
                PackedStringArray parts = time_part.split(":");
                if (parts.size() >= 1) hour = parts[0].to_int();
                if (parts.size() >= 2) minute = parts[1].to_int();
                if (parts.size() >= 3) {
                    String sec_str = parts[2];
                    if (sec_str.contains(" ")) sec_str = sec_str.split(" ")[0];
                    second = sec_str.to_int();
                }
                if (is_pm && hour != 12) hour += 12;
                else if (has_am_pm && !is_pm && hour == 12) hour = 0;
            }
            
            // Common VB6 format strings
            if (fmt.nocasecmp_to("Short Date") == 0) {
                return String::num_int64(month) + "/" + String::num_int64(day) + "/" + String::num_int64(year);
            }
            if (fmt.nocasecmp_to("Long Date") == 0) {
                static const char* months[] = {"", "January", "February", "March", "April", "May", "June",
                                               "July", "August", "September", "October", "November", "December"};
                if (month >= 1 && month <= 12) {
                    return String(months[month]) + " " + String::num_int64(day) + ", " + String::num_int64(year);
                }
            }
            if (fmt.nocasecmp_to("Short Time") == 0) {
                String ampm = hour >= 12 ? "PM" : "AM";
                int hour12 = hour % 12;
                if (hour12 == 0) hour12 = 12;
                return String::num_int64(hour12) + ":" + (minute < 10 ? "0" : "") + String::num_int64(minute) + " " + ampm;
            }
            if (fmt.nocasecmp_to("Long Time") == 0) {
                String ampm = hour >= 12 ? "PM" : "AM";
                int hour12 = hour % 12;
                if (hour12 == 0) hour12 = 12;
                return String::num_int64(hour12) + ":" + (minute < 10 ? "0" : "") + String::num_int64(minute) + ":" +
                       (second < 10 ? "0" : "") + String::num_int64(second) + " " + ampm;
            }
            
            // Custom format - basic substitution
            String result = fmt;
            result = result.replace("yyyy", String::num_int64(year));
            result = result.replace("yy", String::num_int64(year % 100).pad_zeros(2));
            result = result.replace("mm", String::num_int64(month).pad_zeros(2));
            result = result.replace("m", String::num_int64(month));
            result = result.replace("dd", String::num_int64(day).pad_zeros(2));
            result = result.replace("d", String::num_int64(day));
            result = result.replace("hh", String::num_int64(hour).pad_zeros(2));
            result = result.replace("h", String::num_int64(hour));
            result = result.replace("nn", String::num_int64(minute).pad_zeros(2));
            result = result.replace("n", String::num_int64(minute));
            result = result.replace("ss", String::num_int64(second).pad_zeros(2));
            result = result.replace("s", String::num_int64(second));
            return result;
        }
        
        // Number formatting
        if (value.get_type() == Variant::INT || value.get_type() == Variant::FLOAT) {
            double num = (double)value;
            
            if (fmt.nocasecmp_to("Currency") == 0 || fmt == "$") {
                // Format as currency
                bool negative = num < 0;
                num = Math::abs(num);
                String formatted = String::num(num, 2);
                // Add thousand separators
                int dot_pos = formatted.find(".");
                if (dot_pos == -1) dot_pos = formatted.length();
                String integer_part = formatted.substr(0, dot_pos);
                String decimal_part = dot_pos < formatted.length() ? formatted.substr(dot_pos) : "";
                String with_commas = "";
                int count = 0;
                for (int i = integer_part.length() - 1; i >= 0; i--) {
                    if (count > 0 && count % 3 == 0) with_commas = "," + with_commas;
                    with_commas = String::chr(integer_part[i]) + with_commas;
                    count++;
                }
                return (negative ? "($" : "$") + with_commas + decimal_part + (negative ? ")" : "");
            }
            if (fmt.nocasecmp_to("Percent") == 0 || fmt == "%") {
                return String::num(num * 100, 2) + "%";
            }
            if (fmt.nocasecmp_to("Scientific") == 0) {
                return String::num_scientific(num);
            }
            if (fmt.nocasecmp_to("Fixed") == 0) {
                return String::num(num, 2);
            }
            if (fmt.nocasecmp_to("Standard") == 0) {
                // Add thousand separators
                bool negative = num < 0;
                num = Math::abs(num);
                String formatted = String::num(num, 2);
                int dot_pos = formatted.find(".");
                if (dot_pos == -1) dot_pos = formatted.length();
                String integer_part = formatted.substr(0, dot_pos);
                String decimal_part = dot_pos < formatted.length() ? formatted.substr(dot_pos) : "";
                String with_commas = "";
                int count = 0;
                for (int i = integer_part.length() - 1; i >= 0; i--) {
                    if (count > 0 && count % 3 == 0) with_commas = "," + with_commas;
                    with_commas = String::chr(integer_part[i]) + with_commas;
                    count++;
                }
                return (negative ? "-" : "") + with_commas + decimal_part;
            }
            
            // Check for decimal format like "0.00" or "#,##0.00"
            if (fmt.contains(".")) {
                int decimals = fmt.length() - fmt.find(".") - 1;
                return String::num(num, decimals);
            }
            
            return String::num(num);
        }
        
        // Default: convert to string
        return String(value);
    }
    
    // Conversion functions
    if (METHOD_IS("oct") && args.size() == 1) {
        r_handled = true;
        int64_t val = (int64_t)args[0];
        return String::num_int64(val, 8);
    }
    
    if (METHOD_IS("hex") && args.size() == 1) {
        r_handled = true;
        int64_t val = (int64_t)args[0];
        return String::num_int64(val, 16).to_upper();
    }
    
    // JSON functions
    if (METHOD_IS("jsonstringify") && args.size() >= 1) {
        r_handled = true;
        Variant data = args[0];
        bool pretty = args.size() > 1 ? bool(args[1]) : false;
        String indent = pretty ? "\t" : "";
        return JSON::stringify(data, indent);
    }
    
    if (METHOD_IS("jsonparse") && args.size() == 1) {
        r_handled = true;
        String json_str = String(args[0]);
        return JSON::parse_string(json_str);
    }
    
    // File system functions
    if (METHOD_IS("fileexists") && args.size() == 1) {
        r_handled = true;
        String path = String(args[0]);
        return FileAccess::file_exists(path);
    }
    
    if (METHOD_IS("direxists") && args.size() == 1) {
        r_handled = true;
        String path = String(args[0]);
        return DirAccess::dir_exists_absolute(path);
    }
    
    if (METHOD_IS("readalltext") && args.size() == 1) {
        r_handled = true;
        String path = String(args[0]);
        Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
        if (file.is_valid()) {
            String content = file->get_as_text();
            file->close();
            return content;
        }
        return String();
    }
    
    if (METHOD_IS("writealltext") && args.size() == 2) {
        r_handled = true;
        String path = String(args[0]);
        String content = String(args[1]);
        Ref<FileAccess> file = FileAccess::open(path, FileAccess::WRITE);
        if (file.is_valid()) {
            file->store_string(content);
            file->close();
            return true;
        }
        return false;
    }
    
    if (METHOD_IS("readlines") && args.size() == 1) {
        r_handled = true;
        String path = String(args[0]);
        Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
        if (file.is_valid()) {
            Array lines;
            while (!file->eof_reached()) {
                lines.append(file->get_line());
            }
            file->close();
            return lines;
        }
        return Array();
    }
    
    if (METHOD_IS("repeat") && args.size() == 2) {
        r_handled = true;
        Variant item = args[0];
        int count = int(args[1]);
        Array repeated;
        
        for (int i = 0; i < count; i++) {
            repeated.append(item);
        }
        return repeated;
    }
    
    if (METHOD_IS("zip") && args.size() == 2) {
        r_handled = true;
        Variant input1 = args[0];
        Variant input2 = args[1];
        
        if (input1.get_type() == Variant::ARRAY && input2.get_type() == Variant::ARRAY) {
            Array arr1 = input1;
            Array arr2 = input2;
            Array zipped;
            
            int min_size = Math::min(arr1.size(), arr2.size());
            for (int i = 0; i < min_size; i++) {
                Array pair;
                pair.append(arr1[i]);
                pair.append(arr2[i]);
                zipped.append(pair);
            }
            return zipped;
        }
        return Array();
    }
    
    if (METHOD_IS("range") && (args.size() >= 2 && args.size() <= 3)) {
        r_handled = true;
        int start = int(args[0]);
        int end = int(args[1]);
        int step = args.size() == 3 ? int(args[2]) : 1;
        
        Array range;
        if (step > 0) {
            for (int i = start; i <= end; i += step) {
                range.append(i);
            }
        } else if (step < 0) {
            for (int i = start; i >= end; i += step) {
                range.append(i);
            }
        }
        return range;
    }

    // Dictionary Functions
    if (METHOD_IS("keys") && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            return dict.keys();
        }
        return Array();
    }
    
    if (METHOD_IS("values") && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            return dict.values();
        }
        return Array();
    }
    
    if (METHOD_IS("haskey") && args.size() == 2) {
        r_handled = true;
        Variant input = args[0];
        Variant key = args[1];
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            return dict.has(key);
        }
        return false;
    }
    
    if (METHOD_IS("dictmerge") && args.size() == 2) {
        r_handled = true;
        Variant input1 = args[0];
        Variant input2 = args[1];
        
        if (input1.get_type() == Variant::DICTIONARY && input2.get_type() == Variant::DICTIONARY) {
            Dictionary dict1 = input1;
            Dictionary dict2 = input2;
            Dictionary merged = dict1.duplicate();
            
            Array keys2 = dict2.keys();
            for (int i = 0; i < keys2.size(); i++) {
                merged[keys2[i]] = dict2[keys2[i]];
            }
            return merged;
        }
        return input1;
    }
    
    if (METHOD_IS("dictremove") && args.size() == 2) {
        r_handled = true;
        Variant input = args[0];
        Variant key = args[1];
        
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            Dictionary new_dict = dict.duplicate();
            new_dict.erase(key);
            return new_dict;
        }
        return input;
    }
    
    if (METHOD_IS("dictclear") && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            Dictionary new_dict;
            return new_dict;
        }
        return input;
    }

    // Type Checking Functions
    if (METHOD_IS("isarray") && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::ARRAY;
    }
    
    if (METHOD_IS("isdict") && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::DICTIONARY;
    }
    
    if (METHOD_IS("isstring") && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::STRING;
    }
    
    if (METHOD_IS("isnumber") && args.size() == 1) {
        r_handled = true;
        Variant::Type type = args[0].get_type();
        return type == Variant::INT || type == Variant::FLOAT;
    }
    
    if (METHOD_IS("isnull") && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::NIL;
    }
    
    if (METHOD_IS("typename") && args.size() == 1) {
        r_handled = true;
        Variant::Type t = args[0].get_type();
        switch (t) {
            case Variant::INT: return "Integer";
            case Variant::FLOAT: return "Double";
            case Variant::STRING: return "String";
            case Variant::BOOL: return "Boolean";
            case Variant::ARRAY: return "Array";
            case Variant::DICTIONARY: return "Dictionary";
            case Variant::OBJECT: return "Object";
            case Variant::NIL: return "Nothing";
            default: return Variant::get_type_name(t);
        }
    }

    // Array Helpers (duplicated here for bytecode access)
    if (METHOD_IS("ubound") && args.size() >= 1) {
        r_handled = true;
        Variant v = args[0];
        if (v.get_type() == Variant::ARRAY) return ((Array)v).size() - 1;
        if (v.get_type() == Variant::PACKED_STRING_ARRAY) return ((PackedStringArray)v).size() - 1;
        if (v.get_type() == Variant::PACKED_INT32_ARRAY) return ((PackedInt32Array)v).size() - 1;
        if (v.get_type() == Variant::PACKED_FLOAT32_ARRAY) return ((PackedFloat32Array)v).size() - 1;
        if (v.get_type() == Variant::PACKED_INT64_ARRAY) return ((PackedInt64Array)v).size() - 1;
        if (v.get_type() == Variant::PACKED_FLOAT64_ARRAY) return ((PackedFloat64Array)v).size() - 1;
        return -1;
    }
    if (METHOD_IS("lbound") && args.size() >= 1) { r_handled = true; return 0; }

    // DATA Introspection Functions (shared by tree-walk and bytecode)
    if (METHOD_IS("datacount")) {
        r_handled = true;
        if (args.size() >= 1) {
            String key = String(args[0]).to_lower();
            const Dictionary &ldi = instance->get_label_to_data_index();
            if (ldi.has(key)) {
                int start = (int)ldi[key];
                int end = instance->get_data_section_end(start);
                return end - start;
            }
            return 0;
        }
        return (int64_t)instance->get_data_count();
    }
    if (METHOD_IS("dataremain")) {
        r_handled = true;
        int remain = instance->get_data_count() - instance->get_data_pointer();
        return remain > 0 ? remain : 0;
    }
    if (METHOD_IS("datasectioncount")) {
        r_handled = true;
        int sec_start = instance->get_data_section_start();
        int sec_end = instance->get_data_section_end(sec_start);
        return sec_end - sec_start;
    }
    if (METHOD_IS("datasectionremain")) {
        r_handled = true;
        int sec_start = instance->get_data_section_start();
        int sec_end = instance->get_data_section_end(sec_start);
        int remain = sec_end - instance->get_data_pointer();
        return remain > 0 ? remain : 0;
    }
    if (METHOD_IS("datapointer")) {
        r_handled = true;
        return (int64_t)instance->get_data_pointer();
    }
    if (METHOD_IS("peekdata")) {
        r_handled = true;
        int abs_index = 0;
        if (args.size() == 1) {
            abs_index = (int)args[0];
        } else if (args.size() == 2) {
            String key = String(args[0]).to_lower();
            const Dictionary &ldi = instance->get_label_to_data_index();
            if (!ldi.has(key)) {
                instance->raise_runtime_error("PeekData: label '" + String(args[0]) + "' not found");
                return Variant();
            }
            abs_index = (int)ldi[key] + (int)args[1];
        } else {
            instance->raise_runtime_error("PeekData: expected 1 or 2 arguments");
            return Variant();
        }
        if (abs_index < 0 || abs_index >= instance->get_data_count()) {
            instance->raise_runtime_error("PeekData: index " + itos(abs_index) + " out of range (0.." + itos(instance->get_data_count() - 1) + ")");
            return Variant();
        }
        ExpressionNode* expr = instance->get_data_segment_at(abs_index);
        if (expr) {
            return instance->evaluate_expression_for_builtins(expr);
        }
        return Variant();
    }
    if (METHOD_IS("setdatapointer")) {
        r_handled = true;
        if (args.size() >= 1) {
            instance->set_data_pointer((int)args[0]);
        }
        return Variant();
    }
    if (METHOD_IS("datalabels")) {
        r_handled = true;
        return instance->get_label_to_data_index().keys();
    }
    if (METHOD_IS("datasectionname")) {
        r_handled = true;
        return instance->get_data_section_name();
    }
    if (METHOD_IS("datatoarray")) {
        r_handled = true;
        int start = 0;
        int end = instance->get_data_count();
        if (args.size() >= 1 && args[0].get_type() == Variant::STRING) {
            String key = String(args[0]).to_lower();
            const Dictionary &ldi = instance->get_label_to_data_index();
            if (!ldi.has(key)) {
                instance->raise_runtime_error("DataToArray: label '" + String(args[0]) + "' not found");
                return Array();
            }
            start = (int)ldi[key];
            end = instance->get_data_section_end(start);
        } else if (args.size() >= 1) {
            start = instance->get_data_pointer();
            end = start + (int)args[0];
            if (end > instance->get_data_count()) end = instance->get_data_count();
        }
        Array result;
        for (int i = start; i < end; i++) {
            ExpressionNode* expr = instance->get_data_segment_at(i);
            if (expr) {
                result.push_back(instance->evaluate_expression_for_builtins(expr));
            }
        }
        return result;
    }

    // ── Functional Programming: Map, Filter, Reduce, Any, All, Find ──
    if (METHOD_IS("map") && args.size() == 2) {
        r_handled = true;
        Array source = args[0];
        Dictionary lambda = args[1];
        Array result;
        for (int i = 0; i < source.size(); i++) {
            Array call_args;
            call_args.push_back(source[i]);
            result.push_back(instance->invoke_lambda(lambda, call_args));
        }
        return result;
    }

    if (METHOD_IS("filter") && args.size() == 2) {
        r_handled = true;
        Array source = args[0];
        Dictionary lambda = args[1];
        Array result;
        for (int i = 0; i < source.size(); i++) {
            Array call_args;
            call_args.push_back(source[i]);
            Variant v = instance->invoke_lambda(lambda, call_args);
            if ((bool)v) {
                result.push_back(source[i]);
            }
        }
        return result;
    }

    if (METHOD_IS("reduce") && args.size() >= 2) {
        r_handled = true;
        Array source = args[0];
        Dictionary lambda = args[1];
        Variant accumulator;
        int start_idx = 0;
        if (args.size() >= 3) {
            accumulator = args[2];
        } else if (source.size() > 0) {
            accumulator = source[0];
            start_idx = 1;
        }
        for (int i = start_idx; i < source.size(); i++) {
            Array call_args;
            call_args.push_back(accumulator);
            call_args.push_back(source[i]);
            accumulator = instance->invoke_lambda(lambda, call_args);
        }
        return accumulator;
    }

    if (METHOD_IS("any") && args.size() == 2) {
        r_handled = true;
        Array source = args[0];
        Dictionary lambda = args[1];
        for (int i = 0; i < source.size(); i++) {
            Array call_args;
            call_args.push_back(source[i]);
            if ((bool)instance->invoke_lambda(lambda, call_args)) {
                return true;
            }
        }
        return false;
    }

    if (METHOD_IS("all") && args.size() == 2) {
        r_handled = true;
        Array source = args[0];
        Dictionary lambda = args[1];
        for (int i = 0; i < source.size(); i++) {
            Array call_args;
            call_args.push_back(source[i]);
            if (!(bool)instance->invoke_lambda(lambda, call_args)) {
                return false;
            }
        }
        return true;
    }

    if (METHOD_IS("find") && args.size() == 2) {
        r_handled = true;
        Array source = args[0];
        Dictionary lambda = args[1];
        for (int i = 0; i < source.size(); i++) {
            Array call_args;
            call_args.push_back(source[i]);
            if ((bool)instance->invoke_lambda(lambda, call_args)) {
                return source[i];
            }
        }
        return Variant(); // Nothing if not found
    }

    // ---- QBColor(colorNumber) — VB6/QBasic 16-color palette ----
    if (METHOD_IS("qbcolor") && args.size() >= 1) {
        r_handled = true;
        int c = (int)args[0];
        // Standard QBasic 16-color palette → 0xRRGGBB
        static const int qb_palette[16] = {
            0x000000, 0x000080, 0x008000, 0x008080,
            0x800000, 0x800080, 0x808000, 0xC0C0C0,
            0x808080, 0x0000FF, 0x00FF00, 0x00FFFF,
            0xFF0000, 0xFF00FF, 0xFFFF00, 0xFFFFFF
        };
        if (c >= 0 && c < 16) return (int64_t)qb_palette[c];
        return (int64_t)0;
    }

    // ====================================================================
    // System-Level Built-in Functions (v2.9.0)
    // ====================================================================

    // Shell() — VB6-style process launch, returns PID
    if (METHOD_IS("shell") && args.size() >= 1) {
        r_handled = true;
        int window_style = args.size() > 1 ? (int)args[1] : 1;
        return VGProcess::shell_execute(args[0], window_style);
    }

    // GetSetting / SaveSetting / DeleteSetting — VB6 registry-style settings
    if (METHOD_IS("getsetting") && args.size() >= 3) {
        r_handled = true;
        String def = args.size() > 3 ? String(args[3]) : "";
        return VGSettings::get_setting(args[0], args[1], args[2], def);
    }
    if (METHOD_IS("savesetting") && args.size() >= 4) {
        r_handled = true;
        VGSettings::save_setting(args[0], args[1], args[2], args[3]);
        return Variant();
    }
    if (METHOD_IS("deletesetting") && args.size() >= 1) {
        r_handled = true;
        String section = args.size() > 1 ? String(args[1]) : "";
        String key = args.size() > 2 ? String(args[2]) : "";
        VGSettings::delete_setting(args[0], section, key);
        return Variant();
    }
    if (METHOD_IS("getallsettings") && args.size() >= 2) {
        r_handled = true;
        return VGSettings::get_all_settings(args[0], args[1]);
    }

    // CreateObject() — VB6 COM-style late-bound object creation
    if (METHOD_IS("createobject") && args.size() >= 1) {
        r_handled = true;
        return VGComInterop::create_object(args[0]);
    }

    // SQLite availability check
    if (METHOD_IS("issqliteavailable")) {
        r_handled = true;
        return VGDatabase::is_sqlite_available();
    }

    // ---- Environ(name) / Environ$(name) — read environment variable ----
    if ((METHOD_IS("environ") || METHOD_IS("environ$")) && args.size() >= 1) {
        r_handled = true;
        String var_name = String(args[0]);
        // Use Godot's OS.get_environment()
        if (OS::get_singleton()) {
            return OS::get_singleton()->get_environment(var_name);
        }
        return String("");
    }

    // ---- CurDir / CurDir$() — return current working directory ----
    if (METHOD_IS("curdir") || METHOD_IS("curdir$")) {
        r_handled = true;
        return get_cwd();
    }

    // Timer() — VB6 Timer function: returns seconds since midnight
    if (METHOD_IS("timer")) {
        r_handled = true;
        return VGTimer::timer_function();
    }

    // ================================================================
    // v3.3: New builtins
    // ================================================================

    // ---- Count() — array/dict length (eliminates UBound + 1) ----
    if (METHOD_IS("count") && args.size() == 1) {
        r_handled = true;
        if (args[0].get_type() == Variant::ARRAY) { Array a = args[0]; return (int64_t)a.size(); }
        if (args[0].get_type() == Variant::DICTIONARY) { Dictionary d = args[0]; return (int64_t)d.size(); }
        if (args[0].get_type() == Variant::STRING) { String s = args[0]; return (int64_t)s.length(); }
        return (int64_t)0;
    }

    // ---- Spc(n) — returns n spaces (Print formatting) ----
    if (METHOD_IS("spc") && args.size() == 1) {
        r_handled = true;
        int n = (int)(int64_t)args[0];
        if (n < 0) n = 0;
        String s;
        for (int i = 0; i < n; i++) s += " ";
        return s;
    }

    // ---- Tab(n) — returns spaces to reach column n (Print formatting) ----
    if (METHOD_IS("tab") && args.size() == 1) {
        r_handled = true;
        int n = (int)(int64_t)args[0];
        if (n < 0) n = 0;
        String s;
        for (int i = 0; i < n; i++) s += " ";
        return s;
    }

    // ---- Bitwise functions ----
    if (METHOD_IS("bitand") && args.size() == 2) { r_handled = true; return (int64_t)((int64_t)args[0] & (int64_t)args[1]); }
    if (METHOD_IS("bitor") && args.size() == 2) { r_handled = true; return (int64_t)((int64_t)args[0] | (int64_t)args[1]); }
    if (METHOD_IS("bitxor") && args.size() == 2) { r_handled = true; return (int64_t)((int64_t)args[0] ^ (int64_t)args[1]); }
    if (METHOD_IS("bitnot") && args.size() == 1) { r_handled = true; return (int64_t)(~(int64_t)args[0]); }
    if (METHOD_IS("bitshiftleft") && args.size() == 2) { r_handled = true; return (int64_t)((int64_t)args[0] << (int64_t)args[1]); }
    if (METHOD_IS("bitshiftright") && args.size() == 2) { r_handled = true; return (int64_t)((int64_t)args[0] >> (int64_t)args[1]); }

    // ---- Math: Ceiling, Floor, Atan2, PI, E ----
    if (METHOD_IS("ceiling") && args.size() == 1) { r_handled = true; return (int64_t)((int64_t)Math::ceil((double)args[0])); }
    if (METHOD_IS("floor") && args.size() == 1) { r_handled = true; return (int64_t)((int64_t)Math::floor((double)args[0])); }
    if (METHOD_IS("atan2") && args.size() == 2) { r_handled = true; return Math::atan2((double)args[0], (double)args[1]); }

    // ---- Array utility functions ----
    if (METHOD_IS("array.copy") && args.size() >= 2) {
        r_handled = true;
        Array src = args[0];
        int count = (args.size() >= 3) ? (int)(int64_t)args[2] : src.size();
        Array dst;
        dst.resize(count);
        for (int i = 0; i < count && i < src.size(); i++) dst[i] = src[i];
        return dst;
    }
    if (METHOD_IS("array.fill") && args.size() == 2) {
        r_handled = true;
        Array arr = args[0];
        Variant val = args[1];
        for (int i = 0; i < arr.size(); i++) arr[i] = val;
        return arr;
    }
    if (METHOD_IS("array.shuffle") && args.size() == 1) {
        r_handled = true;
        Array arr = args[0];
        arr.shuffle();
        return arr;
    }
    if (METHOD_IS("array.transpose") && args.size() == 1) {
        r_handled = true;
        Array grid = args[0];
        if (grid.size() == 0) return Array();
        Array row0 = grid[0];
        int rows = grid.size();
        int cols = row0.size();
        Array result;
        result.resize(cols);
        for (int c = 0; c < cols; c++) {
            Array new_row;
            new_row.resize(rows);
            for (int r = 0; r < rows; r++) {
                Array src_row = grid[r];
                new_row[r] = (c < src_row.size()) ? src_row[c] : Variant();
            }
            result[c] = new_row;
        }
        return result;
    }

    // ---- String utility functions ----
    if ((METHOD_IS("string.contains") || METHOD_IS("strcontains")) && args.size() == 2) {
        r_handled = true;
        return String(args[0]).find(String(args[1])) != -1;
    }
    if ((METHOD_IS("string.repeat") || METHOD_IS("strrepeat")) && args.size() == 2) {
        r_handled = true;
        String s = args[0];
        int n = (int)(int64_t)args[1];
        String result;
        for (int i = 0; i < n; i++) result += s;
        return result;
    }

    // ---- Sleep(ms) — blocking delay ----
    if (METHOD_IS("sleep") && args.size() == 1) {
        r_handled = true;
        int ms = (int)(int64_t)args[0];
        if (ms > 0) std::this_thread::sleep_for(std::chrono::milliseconds(ms));
        return Variant();
    }

    // ---- Debug.Assert (also callable as Assert) ----
    if (METHOD_IS("assert") && args.size() >= 1) {
        r_handled = true;
        bool cond = (bool)args[0];
        if (!cond) {
            String msg = (args.size() >= 2) ? String(args[1]) : "Assertion failed";
            UtilityFunctions::print("[VG] ASSERT FAILED: ", msg);
            instance->raise_runtime_error(msg, 999, "Debug.Assert");
        }
        return Variant();
    }

    // ---- RegExp support (VBScript-compatible API) ----
    if (METHOD_IS("regexp.test") && args.size() == 2) {
        r_handled = true;
        Ref<RegEx> re;
        re.instantiate();
        re->compile(String(args[0]));
        Ref<RegExMatch> m = re->search(String(args[1]));
        return m.is_valid();
    }
    if (METHOD_IS("regexp.execute") && args.size() == 2) {
        r_handled = true;
        Ref<RegEx> re;
        re.instantiate();
        re->compile(String(args[0]));
        TypedArray<RegExMatch> matches = re->search_all(String(args[1]));
        Array result;
        for (int i = 0; i < matches.size(); i++) {
            Ref<RegExMatch> m = matches[i];
            if (m.is_valid()) result.push_back(m->get_string());
        }
        return result;
    }
    if (METHOD_IS("regexp.replace") && args.size() == 3) {
        r_handled = true;
        Ref<RegEx> re;
        re.instantiate();
        re->compile(String(args[0]));
        return re->sub(String(args[1]), String(args[2]), true);
    }

    // ---- Enum helpers ----
    // Enum.Values("EnumName") — requires instance for AST access
    // Handled via virtual object in evaluate.inc

    // ---- StringBuilder ----
    // StringBuilder is implemented as a Dictionary-based object:
    //   {"__vg_stringbuilder": true, "__buffer": PackedStringArray}
    if (METHOD_IS("stringbuilder") || METHOD_IS("newstringbuilder")) {
        r_handled = true;
        Dictionary sb;
        sb["__vg_stringbuilder"] = true;
        sb["__buffer"] = Array();
        return sb;
    }

#undef METHOD_IS
    return Variant();
}

bool call_builtin_for_base_variable(VisualGasicInstance *instance, const String &p_base_name, const String &p_method, const Array &p_args, Variant &r_ret) {
    if (p_base_name == "Clipboard") {
        if (p_method == "GetText") {
            r_ret = DisplayServer::get_singleton()->clipboard_get();
            return true;
        }
        if (p_method == "SetText") {
            if (p_args.size() >= 1) DisplayServer::get_singleton()->clipboard_set(String(p_args[0]));
            r_ret = Variant();
            return true;
        }
        if (p_method == "Clear") {
            DisplayServer::get_singleton()->clipboard_set("");
            r_ret = Variant();
            return true;
        }
    }

    // App object — VB6 App.Path, App.Title, App.EXEName, App.Major, etc.
    if (p_base_name == "App") {
        if (p_method == "Path" || p_method == "path") {
            r_ret = OS::get_singleton()->get_executable_path().get_base_dir();
            return true;
        }
        if (p_method == "Title" || p_method == "title") {
            r_ret = ProjectSettings::get_singleton()->get_setting("application/config/name", String("VisualGasic App"));
            return true;
        }
        if (p_method == "EXEName" || p_method == "exename") {
            r_ret = OS::get_singleton()->get_executable_path().get_file();
            return true;
        }
        if (p_method == "Major" || p_method == "major") { r_ret = 1; return true; }
        if (p_method == "Minor" || p_method == "minor") { r_ret = 0; return true; }
        if (p_method == "Revision" || p_method == "revision") { r_ret = 0; return true; }
        if (p_method == "PrevInstance" || p_method == "previnstance") { r_ret = false; return true; }
        if (p_method == "ProductName" || p_method == "productname") {
            r_ret = ProjectSettings::get_singleton()->get_setting("application/config/name", String("VisualGasic App"));
            return true;
        }
        if (p_method == "CompanyName" || p_method == "companyname") {
            r_ret = String("");
            return true;
        }
        return false;
    }

    // Screen object — VB6 Screen.Width, Screen.Height
    if (p_base_name == "Screen") {
        if (p_method == "Width" || p_method == "width") {
            Vector2i size = DisplayServer::get_singleton()->screen_get_size();
            r_ret = size.x;
            return true;
        }
        if (p_method == "Height" || p_method == "height") {
            Vector2i size = DisplayServer::get_singleton()->screen_get_size();
            r_ret = size.y;
            return true;
        }
        if (p_method == "TwipsPerPixelX" || p_method == "twipsperpixelx") { r_ret = 1; return true; }
        if (p_method == "TwipsPerPixelY" || p_method == "twipsperpixely") { r_ret = 1; return true; }
        if (p_method == "MousePointer" || p_method == "mousepointer") { r_ret = 0; return true; }
        return false;
    }

    // ── Array namespace: Array.Copy, Array.Fill, Array.Shuffle, Array.Transpose ──
    if (p_base_name.nocasecmp_to("Array") == 0) {
        if (p_method.nocasecmp_to("Copy") == 0 && p_args.size() >= 1) {
            Array src = p_args[0];
            int count = (p_args.size() >= 2) ? (int)(int64_t)p_args[1] : src.size();
            Array dst;
            dst.resize(count);
            for (int i = 0; i < count && i < src.size(); i++) dst[i] = src[i];
            r_ret = dst;
            return true;
        }
        if (p_method.nocasecmp_to("Fill") == 0 && p_args.size() >= 2) {
            int size = (int)(int64_t)p_args[0];
            Variant val = p_args[1];
            Array arr;
            arr.resize(size);
            for (int i = 0; i < size; i++) arr[i] = val;
            r_ret = arr;
            return true;
        }
        if (p_method.nocasecmp_to("Shuffle") == 0 && p_args.size() >= 1) {
            Array arr = p_args[0];
            arr.shuffle();
            r_ret = arr;
            return true;
        }
        if (p_method.nocasecmp_to("Transpose") == 0 && p_args.size() >= 1) {
            Array grid = p_args[0];
            if (grid.size() == 0) { r_ret = Array(); return true; }
            Array row0 = grid[0];
            int rows = grid.size();
            int cols = row0.size();
            Array result;
            result.resize(cols);
            for (int c = 0; c < cols; c++) {
                Array new_row;
                new_row.resize(rows);
                for (int r = 0; r < rows; r++) {
                    Array src_row = grid[r];
                    new_row[r] = (c < src_row.size()) ? src_row[c] : Variant();
                }
                result[c] = new_row;
            }
            r_ret = result;
            return true;
        }
        return false;
    }

    // ── String namespace: String.Contains, String.Repeat ──
    if (p_base_name.nocasecmp_to("String") == 0) {
        if (p_method.nocasecmp_to("Contains") == 0 && p_args.size() == 2) {
            r_ret = String(p_args[0]).find(String(p_args[1])) != -1;
            return true;
        }
        if (p_method.nocasecmp_to("Repeat") == 0 && p_args.size() == 2) {
            String s = p_args[0];
            int n = (int)(int64_t)p_args[1];
            String result;
            for (int i = 0; i < n; i++) result += s;
            r_ret = result;
            return true;
        }
        return false;
    }

    // ── RegExp namespace: RegExp.Test, RegExp.Execute, RegExp.Replace ──
    if (p_base_name.nocasecmp_to("RegExp") == 0) {
        if (p_method.nocasecmp_to("Test") == 0 && p_args.size() == 2) {
            Ref<RegEx> re;
            re.instantiate();
            re->compile(String(p_args[1]));
            Ref<RegExMatch> m = re->search(String(p_args[0]));
            r_ret = m.is_valid();
            return true;
        }
        if (p_method.nocasecmp_to("Execute") == 0 && p_args.size() == 2) {
            Ref<RegEx> re;
            re.instantiate();
            re->compile(String(p_args[1]));
            TypedArray<RegExMatch> matches = re->search_all(String(p_args[0]));
            Array result;
            for (int i = 0; i < matches.size(); i++) {
                Ref<RegExMatch> m = matches[i];
                result.push_back(m->get_string());
            }
            r_ret = result;
            return true;
        }
        if (p_method.nocasecmp_to("Replace") == 0 && p_args.size() == 3) {
            Ref<RegEx> re;
            re.instantiate();
            re->compile(String(p_args[1]));
            r_ret = re->sub(String(p_args[0]), String(p_args[2]), true);
            return true;
        }
        return false;
    }

    // ── Debug namespace: Debug.Print, Debug.Assert ──
    if (p_base_name.nocasecmp_to("Debug") == 0) {
        if (p_method.nocasecmp_to("Print") == 0) {
            String msg;
            for (int i = 0; i < p_args.size(); i++) msg += String(p_args[i]);
            UtilityFunctions::print("[VG Debug] ", msg);
            r_ret = Variant();
            return true;
        }
        if (p_method.nocasecmp_to("Assert") == 0 && p_args.size() >= 1) {
            if (!(bool)p_args[0]) {
                String msg = (p_args.size() >= 2) ? String(p_args[1]) : String("Debug.Assert failed");
                instance->raise_runtime_error(msg, 0, "Debug.Assert");
            }
            r_ret = Variant();
            return true;
        }
        return false;
    }

    // Err object — VB6 Err.Raise, Err.Clear, Err.Number, Err.Description
    if (p_base_name == "Err") {
        if (p_method == "Raise" || p_method == "raise") {
            int err_num = p_args.size() >= 1 ? (int)p_args[0] : 0;
            String source = p_args.size() >= 2 ? String(p_args[1]) : String("");
            String desc = p_args.size() >= 3 ? String(p_args[2]) : String("Application-defined or object-defined error");
            instance->raise_runtime_error(desc, err_num, source);
            r_ret = Variant();
            return true;
        }
        if (p_method == "Clear" || p_method == "clear") {
            Dictionary &vars = instance->get_variables();
            if (vars.has("Err")) {
                Dictionary err;
                err["Number"] = 0;
                err["Description"] = String("");
                err["Source"] = String("");
                vars["Err"] = err;
            }
            instance->clear_error_state();
            r_ret = Variant();
            return true;
        }
        return false;
    }
    return false;
}

bool call_builtin_for_base_object(VisualGasicInstance *instance, const Variant &p_base, const String &p_method, const Array &p_args, Variant &r_ret) {
    // Only handle object-specific parts here; object is optional for composite handler.
    if (p_base.get_type() != Variant::OBJECT) return false;
    Object *obj = p_base;
    if (!obj) return false;

    // Tree specific helper: GetTextMatrix(row, col)
    if (obj->is_class("Tree") && p_method == "GetTextMatrix" && p_args.size() >= 2) {
        Tree *t = Object::cast_to<Tree>(obj);
        int row = (int)p_args[0];
        int col = (int)p_args[1];
        TreeItem *root = t->get_root();
        if (root && row >= 0 && row < root->get_child_count()) {
            TreeItem *it = root->get_child(row);
            r_ret = it->get_text(col);
            return true;
        }
        r_ret = String();
        return true;
    }

    // Tree helpers: SetTextMatrix(row, col, text), AddItem(text), RemoveItem(index)
    if (obj->is_class("Tree")) {
        Tree *t = Object::cast_to<Tree>(obj);
        if (p_method == "SetTextMatrix" && p_args.size() >= 3) {
            int row = (int)p_args[0];
            int col = (int)p_args[1];
            String text = p_args[2];
            TreeItem *root = t->get_root();
            if (root && row >= 0 && row < root->get_child_count()) {
                TreeItem *it = root->get_child(row);
                it->set_text(col, text);
            }
            r_ret = Variant();
            return true;
        }
        if (p_method == "AddItem" && p_args.size() >= 1) {
            TreeItem *root = t->get_root();
            if (root) {
                TreeItem *it = t->create_item(root);
                String text = p_args[0];
                PackedStringArray parts = text.split("\t");
                int cols = t->get_columns();
                for (int i = 0; i < parts.size(); i++) {
                    if (i < cols) it->set_text(i, parts[i]);
                }
            }
            r_ret = Variant();
            return true;
        }
        if (p_method == "RemoveItem" && p_args.size() == 1) {
            int idx = (int)p_args[0];
            TreeItem *root = t->get_root();
            if (root && idx >= 0 && idx < root->get_child_count()) {
                TreeItem *it = root->get_child(idx);
                memdelete(it);
            }
            r_ret = Variant();
            return true;
        }
    }

    // Connect helper: Connect(signal, target_method) on the object
    if (p_method.nocasecmp_to("Connect") == 0) {
        if (p_args.size() == 2) {
            String signal = p_args[0];
            String method = p_args[1];
            if (instance->get_owner()) {
                Error err = obj->connect(signal, Callable(instance->get_owner(), method));
                r_ret = (int)err;
                return true;
            }
            r_ret = 0;
            return true;
        } else if (p_args.size() == 3) {
            Object *source = p_args[0];
            String signal = p_args[1];
            String method = p_args[2];
            if (source) {
                Error err = source->connect(signal, Callable(instance->get_owner(), method));
                r_ret = (int)err;
                return true;
            }
            r_ret = 0;
            return true;
        }
    }

    return false;
}

bool call_builtin_for_base_variant(VisualGasicInstance *instance, const Variant &p_base, const String &p_method, const Array &p_args, Variant &r_ret) {
    // Handle DICTIONARY-based types
    if (p_base.get_type() == Variant::DICTIONARY) {
        Dictionary d = p_base;
        
        // ── StringBuilder dispatch ──
        if (d.has("__vg_stringbuilder")) {
            if (p_method.nocasecmp_to("Append") == 0 && p_args.size() >= 1) {
                Array buf = d["__buffer"];
                buf.push_back(String(p_args[0]));
                d["__buffer"] = buf;
                r_ret = d; // return self for chaining
                return true;
            }
            if (p_method.nocasecmp_to("AppendLine") == 0) {
                Array buf = d["__buffer"];
                if (p_args.size() >= 1) buf.push_back(String(p_args[0]));
                buf.push_back("\n");
                d["__buffer"] = buf;
                r_ret = d;
                return true;
            }
            if (p_method.nocasecmp_to("ToString") == 0) {
                Array buf = d["__buffer"];
                String result;
                for (int i = 0; i < buf.size(); i++) result += String(buf[i]);
                r_ret = result;
                return true;
            }
            if (p_method.nocasecmp_to("Length") == 0 || p_method.nocasecmp_to("Count") == 0) {
                Array buf = d["__buffer"];
                int len = 0;
                for (int i = 0; i < buf.size(); i++) len += String(buf[i]).length();
                r_ret = len;
                return true;
            }
            if (p_method.nocasecmp_to("Clear") == 0) {
                Array buf;
                d["__buffer"] = buf;
                r_ret = d;
                return true;
            }
            if (p_method.nocasecmp_to("Insert") == 0 && p_args.size() >= 2) {
                // Build full string, insert, rebuild
                Array buf = d["__buffer"];
                String full;
                for (int i = 0; i < buf.size(); i++) full += String(buf[i]);
                int pos = (int)p_args[0];
                if (pos < 0) pos = 0;
                if (pos > full.length()) pos = full.length();
                full = full.substr(0, pos) + String(p_args[1]) + full.substr(pos, full.length() - pos);
                Array new_buf;
                new_buf.push_back(full);
                d["__buffer"] = new_buf;
                r_ret = d;
                return true;
            }
            if (p_method.nocasecmp_to("Replace") == 0 && p_args.size() >= 2) {
                Array buf = d["__buffer"];
                String full;
                for (int i = 0; i < buf.size(); i++) full += String(buf[i]);
                full = full.replace(String(p_args[0]), String(p_args[1]));
                Array new_buf;
                new_buf.push_back(full);
                d["__buffer"] = new_buf;
                r_ret = d;
                return true;
            }
            return false;
        }
        if (p_method == "Clear") {
            if (d.has("Number") && d.has("Description")) {
                d["Number"] = 0;
                d["Description"] = "";
                d["Source"] = "";
                r_ret = Variant();
                return true;
            }
            d.clear();
            r_ret = Variant();
            return true;
        }
        // VB6 Scripting.Dictionary methods
        if (p_method.nocasecmp_to("Add") == 0 && p_args.size() >= 2) {
            d[p_args[0]] = p_args[1];
            r_ret = Variant();
            return true;
        }
        if (p_method.nocasecmp_to("Remove") == 0 && p_args.size() >= 1) {
            d.erase(p_args[0]);
            r_ret = Variant();
            return true;
        }
        if (p_method.nocasecmp_to("Exists") == 0 && p_args.size() >= 1) {
            r_ret = d.has(p_args[0]);
            return true;
        }
        if (p_method.nocasecmp_to("Item") == 0 && p_args.size() >= 1) {
            r_ret = d.has(p_args[0]) ? d[p_args[0]] : Variant();
            return true;
        }
        if (p_method.nocasecmp_to("Keys") == 0) {
            r_ret = d.keys();
            return true;
        }
        if (p_method.nocasecmp_to("Items") == 0 || p_method.nocasecmp_to("Values") == 0) {
            r_ret = d.values();
            return true;
        }
        if (p_method.nocasecmp_to("Count") == 0) {
            r_ret = d.size();
            return true;
        }
        if (p_method.nocasecmp_to("RemoveAll") == 0) {
            d.clear();
            r_ret = Variant();
            return true;
        }
        if (p_method == "Raise") {
            if (p_args.size() >= 1) d["Number"] = p_args[0];
            if (p_args.size() >= 2) d["Source"] = p_args[1];
            if (p_args.size() >= 3) d["Description"] = p_args[2];
            String msg = d.has("Description") ? (String)d["Description"] : "Runtime Error";
            int code = d.has("Number") ? (int)d["Number"] : 0;
            String source = d.has("Source") ? (String)d["Source"] : "";
            instance->raise_runtime_error(msg, code, source);
            r_ret = Variant();
            return true;
        }
        return false;
    }

    // Delegate to object handler for object types
    return call_builtin_for_base_object(instance, p_base, p_method, p_args, r_ret);
}

} // namespace VisualGasicBuiltins
