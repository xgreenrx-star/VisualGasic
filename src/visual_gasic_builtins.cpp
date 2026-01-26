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
#include <godot_cpp/classes/accept_dialog.hpp>
#include <godot_cpp/classes/confirmation_dialog.hpp>
#include <godot_cpp/classes/line_edit.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/tree_item.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>

using namespace godot;

namespace VisualGasicBuiltins {

Variant call_builtin_expr_evaluated(VisualGasicInstance *instance, const String &p_method, const Array &p_args, bool &r_handled);

bool call_builtin(VisualGasicInstance *instance, const String &p_method, const Array &p_args, Variant &r_ret, bool &r_found) {
    VG_PROFILE_CATEGORY("builtin_call", "builtins");
    VG_COUNT("builtin.function_calls");
    
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
    if (name.nocasecmp_to("LOF") == 0 && args.size() == 1) { r_handled = true; return instance->file_lof((int)args[0]); }
    if (name.nocasecmp_to("Loc") == 0 && args.size() == 1) { r_handled = true; return instance->file_loc((int)args[0]); }
    if (name.nocasecmp_to("EOF") == 0 && args.size() == 1) { r_handled = true; return instance->file_eof((int)args[0]); }
    if (name.nocasecmp_to("FreeFile") == 0) { r_handled = true; int range = 0; if (args.size()>0) range = (int)args[0]; return instance->file_free(range); }
    if (name.nocasecmp_to("FileLen") == 0 && args.size() == 1) { r_handled = true; return instance->file_len(String(args[0])); }
    if (name.nocasecmp_to("Dir") == 0) { r_handled = true; return instance->file_dir(args); }
    if (name.nocasecmp_to("Randomize") == 0) { r_handled = true; instance->randomize_seed(); return Variant(); }

    // If not handled here, leave r_handled false so caller can fallback
    return Variant();
}

Variant call_builtin_expr_evaluated(VisualGasicInstance *instance, const String &p_method, const Array &p_args, bool &r_handled) {
    r_handled = false;
    Array args = p_args;
    String name = p_method;

    if (name.nocasecmp_to("BenchFileIOFast") == 0 && args.size() == 2) {
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
    if (name == "Len" && args.size() == 1) { r_handled = true; return String(args[0]).length(); }
    if (name == "Left" && args.size() == 2) { r_handled = true; return String(args[0]).left((int)args[1]); }
    if (name == "Right" && args.size() == 2) { r_handled = true; return String(args[0]).right((int)args[1]); }
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

    // Math Library
    if (name == "Sin" && args.size() == 1) { r_handled = true; return UtilityFunctions::sin(args[0]); }
    if (name == "Cos" && args.size() == 1) { r_handled = true; return UtilityFunctions::cos(args[0]); }
    if (name == "Tan" && args.size() == 1) { r_handled = true; return UtilityFunctions::tan(args[0]); }
    if (name == "Log" && args.size() == 1) { r_handled = true; return UtilityFunctions::log(args[0]); }
    if (name == "Exp" && args.size() == 1) { r_handled = true; return UtilityFunctions::exp(args[0]); }
    if (name == "Atn" && args.size() == 1) { r_handled = true; return UtilityFunctions::atan(args[0]); }
    if (name == "Sqr" && args.size() == 1) { r_handled = true; return UtilityFunctions::sqrt(args[0]); }
    if (name == "Abs" && args.size() == 1) { 
        r_handled = true; 
        if (args[0].get_type() == Variant::INT) { int64_t v = (int64_t)args[0]; return v < 0 ? -v : v; }
        return UtilityFunctions::abs(args[0]); 
    }
    if (name == "Sgn" && args.size() == 1) { r_handled = true; double d = (double)args[0]; if (d>0) return (int64_t)1; if (d<0) return (int64_t)-1; return (int64_t)0; }
    if (name == "Int" && args.size() == 1) { r_handled = true; if (args[0].get_type() == Variant::INT) return (int64_t)args[0]; return UtilityFunctions::floor(args[0]); }
    if (name == "Rnd" && (args.size() == 0 || args.size() == 1)) { r_handled = true; return UtilityFunctions::randf(); }
    if (name.nocasecmp_to("Fix") == 0 && args.size() == 1) { r_handled = true; double v = (double)args[0]; return v < 0 ? ceil(v) : floor(v); }

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

    if (name.nocasecmp_to("CInt") == 0 && args.size() == 1) { r_handled = true; return (int64_t)llround((double)args[0]); }
    if (name.nocasecmp_to("CLng") == 0 && args.size() == 1) { r_handled = true; return (int64_t)llround((double)args[0]); }
    if (name.nocasecmp_to("CSng") == 0 && args.size() == 1) { r_handled = true; return (double)args[0]; }
    if (name.nocasecmp_to("CDbl") == 0 && args.size() == 1) { r_handled = true; return (double)args[0]; }
    if (name.nocasecmp_to("Fix") == 0 && args.size() == 1) { r_handled = true; double v = (double)args[0]; return v < 0 ? ceil(v) : floor(v); }
    if (name.nocasecmp_to("CBool") == 0 && args.size() == 1) { r_handled = true; return (bool)args[0]; }

    if (name.nocasecmp_to("Lerp") == 0 && args.size() == 3) { r_handled = true; double a = args[0]; double b = args[1]; double t = args[2]; return Math::lerp(a,b,t); }
    if (name.nocasecmp_to("Clamp") == 0 && args.size() == 3) { r_handled = true; double val = args[0]; double mn = args[1]; double mx = args[2]; return Math::clamp(val,mn,mx); }

    // String functions
    if (name.nocasecmp_to("StartsWith") == 0 && args.size() == 2) {
        r_handled = true;
        String text = String(args[0]);
        String prefix = String(args[1]);
        return text.begins_with(prefix);
    }
    
    if (name.nocasecmp_to("EndsWith") == 0 && args.size() == 2) {
        r_handled = true;
        String text = String(args[0]);
        String suffix = String(args[1]);
        return text.ends_with(suffix);
    }
    
    if (name.nocasecmp_to("PadLeft") == 0 && (args.size() == 2 || args.size() == 3)) {
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
    
    if (name.nocasecmp_to("PadRight") == 0 && (args.size() == 2 || args.size() == 3)) {
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
    if (name.nocasecmp_to("AllocFillI64") == 0 && args.size() == 1) {
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
    if (name.nocasecmp_to("AllocFillI64Sum") == 0 && args.size() == 1) {
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
    if (name.nocasecmp_to("Push") == 0 && args.size() == 2) {
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
    
    if (name.nocasecmp_to("Pop") == 0 && args.size() == 1) {
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
    
    if (name.nocasecmp_to("Slice") == 0 && args.size() >= 2) {
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
    if (name.nocasecmp_to("Sort") == 0 && args.size() == 1) {
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

    if (name.nocasecmp_to("Reverse") == 0 && args.size() == 1) {
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

    if (name.nocasecmp_to("IndexOf") == 0 && args.size() == 2) {
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

    if (name.nocasecmp_to("Contains") == 0 && args.size() == 2) {
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

    if (name.nocasecmp_to("Unique") == 0 && args.size() == 1) {
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

    if (name.nocasecmp_to("Flatten") == 0 && args.size() == 1) {
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
    
    if (name.nocasecmp_to("Push") == 0 && args.size() == 2) {
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
    
    if (name.nocasecmp_to("Pop") == 0 && args.size() == 1) {
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
    
    if (name.nocasecmp_to("Slice") == 0 && args.size() >= 2) {
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
    
    if (name.nocasecmp_to("Repeat") == 0 && args.size() == 2) {
        r_handled = true;
        Variant item = args[0];
        int count = int(args[1]);
        Array repeated;
        
        for (int i = 0; i < count; i++) {
            repeated.append(item);
        }
        return repeated;
    }
    
    if (name.nocasecmp_to("Zip") == 0 && args.size() == 2) {
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
    
    if (name.nocasecmp_to("Range") == 0 && (args.size() >= 2 && args.size() <= 3)) {
        r_handled = true;
        int start = int(args[0]);
        int end = int(args[1]);
        int step = args.size() == 3 ? int(args[2]) : 1;
        
        Array range;
        if (step > 0) {
            for (int i = start; i < end; i += step) {
                range.append(i);
            }
        } else if (step < 0) {
            for (int i = start; i > end; i += step) {
                range.append(i);
            }
        }
        return range;
    }
    
    // Dictionary functions
    if (name.nocasecmp_to("Keys") == 0 && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            return dict.keys();
        }
        return Array();
    }
    
    if (name.nocasecmp_to("Values") == 0 && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            return dict.values();
        }
        return Array();
    }
    
    if (name.nocasecmp_to("HasKey") == 0 && args.size() == 2) {
        r_handled = true;
        Variant input = args[0];
        Variant key = args[1];
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            return dict.has(key);
        }
        return false;
    }
    
    if (name.nocasecmp_to("Merge") == 0 && args.size() == 2) {
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
    
    if (name.nocasecmp_to("Remove") == 0 && args.size() == 2) {
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
    if (name.nocasecmp_to("IsArray") == 0 && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::ARRAY;
    }
    
    if (name.nocasecmp_to("IsDict") == 0 && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::DICTIONARY;
    }
    
    if (name.nocasecmp_to("IsString") == 0 && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::STRING;
    }
    
    if (name.nocasecmp_to("IsNumber") == 0 && args.size() == 1) {
        r_handled = true;
        Variant::Type type = args[0].get_type();
        return type == Variant::INT || type == Variant::FLOAT;
    }
    
    if (name.nocasecmp_to("IsNull") == 0 && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::NIL;
    }
    
    if (name.nocasecmp_to("TypeName") == 0 && args.size() == 1) {
        r_handled = true;
        return Variant::get_type_name(args[0].get_type());
    }
    
    // JSON functions
    if (name.nocasecmp_to("JsonStringify") == 0 && args.size() >= 1) {
        r_handled = true;
        Variant data = args[0];
        bool pretty = args.size() > 1 ? bool(args[1]) : false;
        String indent = pretty ? "\t" : "";
        return JSON::stringify(data, indent);
    }
    
    if (name.nocasecmp_to("JsonParse") == 0 && args.size() == 1) {
        r_handled = true;
        String json_str = String(args[0]);
        return JSON::parse_string(json_str);
    }
    
    // File system functions
    if (name.nocasecmp_to("FileExists") == 0 && args.size() == 1) {
        r_handled = true;
        String path = String(args[0]);
        return FileAccess::file_exists(path);
    }
    
    if (name.nocasecmp_to("DirExists") == 0 && args.size() == 1) {
        r_handled = true;
        String path = String(args[0]);
        return DirAccess::dir_exists_absolute(path);
    }
    
    if (name.nocasecmp_to("ReadAllText") == 0 && args.size() == 1) {
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
    
    if (name.nocasecmp_to("WriteAllText") == 0 && args.size() == 2) {
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
    
    if (name.nocasecmp_to("ReadLines") == 0 && args.size() == 1) {
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
    
    if (name.nocasecmp_to("Repeat") == 0 && args.size() == 2) {
        r_handled = true;
        Variant item = args[0];
        int count = int(args[1]);
        Array repeated;
        
        for (int i = 0; i < count; i++) {
            repeated.append(item);
        }
        return repeated;
    }
    
    if (name.nocasecmp_to("Zip") == 0 && args.size() == 2) {
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
    
    if (name.nocasecmp_to("Range") == 0 && (args.size() >= 2 && args.size() <= 3)) {
        r_handled = true;
        int start = int(args[0]);
        int end = int(args[1]);
        int step = args.size() == 3 ? int(args[2]) : 1;
        
        Array range;
        if (step > 0) {
            for (int i = start; i < end; i += step) {
                range.append(i);
            }
        } else if (step < 0) {
            for (int i = start; i > end; i += step) {
                range.append(i);
            }
        }
        return range;
    }

    // Dictionary Functions
    if (name.nocasecmp_to("Keys") == 0 && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            return dict.keys();
        }
        return Array();
    }
    
    if (name.nocasecmp_to("Values") == 0 && args.size() == 1) {
        r_handled = true;
        Variant input = args[0];
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            return dict.values();
        }
        return Array();
    }
    
    if (name.nocasecmp_to("HasKey") == 0 && args.size() == 2) {
        r_handled = true;
        Variant input = args[0];
        Variant key = args[1];
        if (input.get_type() == Variant::DICTIONARY) {
            Dictionary dict = input;
            return dict.has(key);
        }
        return false;
    }
    
    if (name.nocasecmp_to("DictMerge") == 0 && args.size() == 2) {
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
    
    if (name.nocasecmp_to("DictRemove") == 0 && args.size() == 2) {
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
    
    if (name.nocasecmp_to("DictClear") == 0 && args.size() == 1) {
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
    if (name.nocasecmp_to("IsArray") == 0 && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::ARRAY;
    }
    
    if (name.nocasecmp_to("IsDict") == 0 && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::DICTIONARY;
    }
    
    if (name.nocasecmp_to("IsString") == 0 && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::STRING;
    }
    
    if (name.nocasecmp_to("IsNumber") == 0 && args.size() == 1) {
        r_handled = true;
        Variant::Type type = args[0].get_type();
        return type == Variant::INT || type == Variant::FLOAT;
    }
    
    if (name.nocasecmp_to("IsNull") == 0 && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::NIL;
    }
    
    if (name.nocasecmp_to("TypeName") == 0 && args.size() == 1) {
        r_handled = true;
        return Variant::get_type_name(args[0].get_type());
    }

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
            instance->raise_runtime_error(msg, code);
            r_ret = Variant();
            return true;
        }
        return false;
    }

    // Delegate to object handler for object types
    return call_builtin_for_base_object(instance, p_base, p_method, p_args, r_ret);
}

} // namespace VisualGasicBuiltins
