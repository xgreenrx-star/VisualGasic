#include "visual_gasic_builtins.h"
#include "visual_gasic_expression_evaluator.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/accept_dialog.hpp>
#include <godot_cpp/classes/confirmation_dialog.hpp>
#include <godot_cpp/classes/line_edit.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/tree_item.hpp>

using namespace godot;

namespace VisualGasicBuiltins {

bool call_builtin(VisualGasicInstance *instance, const String &p_method, const Array &p_args, Variant &r_ret, bool &r_found) {
    r_found = false;
    r_ret = Variant();

    if (!instance) return false;

    String method = p_method;

    // Minimal set implemented here; the rest can be added as needed.
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

        AcceptDialog *dlg = memnew(AcceptDialog);
        dlg->set_title(title);
        dlg->set_text(msg);
        root->add_child(dlg);
        dlg->popup_centered();

        // Blocking modal loop (not ideal, but mirrors previous behavior)
        while (dlg->is_visible() && dlg->is_inside_tree()) {
            DisplayServer::get_singleton()->process_events();
            OS::get_singleton()->delay_msec(10);
        }
        dlg->queue_free();
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
    if (name == "Str" && args.size() == 1) { r_handled = true; return Variant(args[0]).stringify(); }
    if (name == "Val" && args.size() == 1) { r_handled = true; String s = args[0]; if (s.is_valid_float()) return s.to_float(); if (s.is_valid_int()) return s.to_int(); return 0.0; }
    if (name == "InStr" && args.size() == 2) { r_handled = true; String s1 = args[0]; String s2 = args[1]; int pos = s1.find(s2); if (pos==-1) return 0; return pos+1; }
    if (name == "Replace" && args.size() == 3) { r_handled = true; return String(args[0]).replace(String(args[1]), String(args[2])); }
    if (name == "Trim" && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(); }
    if (name == "LTrim" && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(true,false); }
    if (name == "RTrim" && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(false,true); }
    if (name == "StrReverse" && args.size() == 1) { r_handled = true; String s = args[0]; String res=""; for(int i=s.length()-1;i>=0;i--) res += s[i]; return res; }
    if (name == "Hex" && args.size() == 1) { r_handled = true; int64_t val = (int64_t)args[0]; return String::num_int64(val,16).to_upper(); }
    if (name == "Oct" && args.size() == 1) { r_handled = true; int64_t val = (int64_t)args[0]; return String::num_int64(val,8); }
    if (name == "Split" && args.size() >= 2) { r_handled = true; return String(args[0]).split(String(args[1])); }
    if (name == "Join" && args.size() == 2) {
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
    if (name == "UBound" && args.size() >= 1) {
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
    if (name == "LBound" && args.size() >= 1) { r_handled = true; return 0; }

    // File / Dir Helpers (use instance wrappers)
    if (name.nocasecmp_to("LOF") == 0 && args.size() == 1) { r_handled = true; return instance->builtin_lof((int)args[0]); }
    if (name.nocasecmp_to("Loc") == 0 && args.size() == 1) { r_handled = true; return instance->builtin_loc((int)args[0]); }
    if (name.nocasecmp_to("EOF") == 0 && args.size() == 1) { r_handled = true; return instance->builtin_eof((int)args[0]); }
    if (name.nocasecmp_to("FreeFile") == 0) { r_handled = true; int range = 0; if (args.size()>0) range = (int)args[0]; return instance->builtin_freefile(range); }
    if (name.nocasecmp_to("FileLen") == 0 && args.size() == 1) { r_handled = true; return instance->builtin_filelen(String(args[0])); }
    if (name.nocasecmp_to("Dir") == 0) { r_handled = true; return instance->builtin_dir(args); }
    if (name.nocasecmp_to("Randomize") == 0) { r_handled = true; instance->builtin_randomize(); return Variant(); }

    // If not handled here, leave r_handled false so caller can fallback
    return Variant();
}

Variant call_builtin_expr_evaluated(VisualGasicInstance *instance, const String &p_method, const Array &p_args, bool &r_handled) {
    r_handled = false;
    Array args = p_args;
    String name = p_method;

    // Math Library
    if (name == "Sin" && args.size() == 1) { r_handled = true; return UtilityFunctions::sin(args[0]); }
    if (name == "Cos" && args.size() == 1) { r_handled = true; return UtilityFunctions::cos(args[0]); }
    if (name == "Tan" && args.size() == 1) { r_handled = true; return UtilityFunctions::tan(args[0]); }
    if (name == "Log" && args.size() == 1) { r_handled = true; return UtilityFunctions::log(args[0]); }
    if (name == "Exp" && args.size() == 1) { r_handled = true; return UtilityFunctions::exp(args[0]); }
    if (name == "Atn" && args.size() == 1) { r_handled = true; return UtilityFunctions::atan(args[0]); }
    if (name == "Sqr" && args.size() == 1) { r_handled = true; return UtilityFunctions::sqrt(args[0]); }
    if (name == "Abs" && args.size() == 1) { r_handled = true; return UtilityFunctions::abs(args[0]); }
    if (name == "Sgn" && args.size() == 1) { r_handled = true; double d = (double)args[0]; if (d>0) return 1; if (d<0) return -1; return 0; }
    if (name == "Int" && args.size() == 1) { r_handled = true; return UtilityFunctions::floor(args[0]); }
    if (name == "Rnd" && (args.size() == 0 || args.size() == 1)) { r_handled = true; return UtilityFunctions::randf(); }

    if (name.nocasecmp_to("Round") == 0 && args.size() >= 1) {
        r_handled = true;
        double val = (double)args[0];
        if (args.size() > 1) {
            int digits = (int)args[1];
            double step = pow(10.0, -digits);
            return Math::snapped(val, step);
        }
        return round(val);
    }

    if (name.nocasecmp_to("RandRange") == 0 && args.size() == 2) {
        r_handled = true;
        float min = (float)args[0];
        float max = (float)args[1];
        return min + UtilityFunctions::randf() * (max - min);
    }

    if (name.nocasecmp_to("CInt") == 0 && args.size() == 1) { r_handled = true; return (int)round((double)args[0]); }
    if (name.nocasecmp_to("CDbl") == 0 && args.size() == 1) { r_handled = true; return (double)args[0]; }
    if (name.nocasecmp_to("CBool") == 0 && args.size() == 1) { r_handled = true; return (bool)args[0]; }

    if (name.nocasecmp_to("Lerp") == 0 && args.size() == 3) { r_handled = true; double a = args[0]; double b = args[1]; double t = args[2]; return Math::lerp(a,b,t); }
    if (name.nocasecmp_to("Clamp") == 0 && args.size() == 3) { r_handled = true; double val = args[0]; double mn = args[1]; double mx = args[2]; return Math::clamp(val,mn,mx); }

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
    // Handle DICTIONARY Err-like behavior
    if (p_base.get_type() == Variant::DICTIONARY) {
        Dictionary d = p_base;
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
        if (p_method == "Raise") {
            if (p_args.size() >= 1) d["Number"] = p_args[0];
            if (p_args.size() >= 2) d["Source"] = p_args[1];
            if (p_args.size() >= 3) d["Description"] = p_args[2];
            String msg = d.has("Description") ? (String)d["Description"] : "Runtime Error";
            int code = d.has("Number") ? (int)d["Number"] : 0;
            instance->raise_error_for_builtins(msg, code);
            r_ret = Variant();
            return true;
        }
        return false;
    }

    // Delegate to object handler for object types
    return call_builtin_for_base_object(instance, p_base, p_method, p_args, r_ret);
}

} // namespace VisualGasicBuiltins
