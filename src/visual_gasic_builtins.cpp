#include "visual_gasic_builtins.h"
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/theme_db.hpp>
#include <godot_cpp/classes/font.hpp>
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
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/tree.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/viewport_texture.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/texture2d.hpp>
// Pass 1 — math/utility wrappers (May 11 2026)
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/transform2d.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/plane.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/classes/fast_noise_lite.hpp>
#include <godot_cpp/classes/curve.hpp>
// Pass 2 — camera/audio namespace dispatch
#include <godot_cpp/classes/camera2d.hpp>
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/audio_stream_player2d.hpp>
#include <godot_cpp/classes/audio_stream_player3d.hpp>
#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/classes/audio_stream_generator.hpp>
#include <godot_cpp/classes/audio_stream_generator_playback.hpp>
#include <godot_cpp/classes/remote_transform2d.hpp>
#include <godot_cpp/classes/remote_transform3d.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/tween.hpp>
#include <godot_cpp/classes/property_tweener.hpp>
// Pass 3 — game-completeness wrappers
#include <godot_cpp/classes/animation_player.hpp>
#include <godot_cpp/classes/area2d.hpp>
#include <godot_cpp/classes/area3d.hpp>
#include <godot_cpp/classes/rigid_body2d.hpp>
#include <godot_cpp/classes/rigid_body3d.hpp>
#include <godot_cpp/classes/ray_cast2d.hpp>
#include <godot_cpp/classes/ray_cast3d.hpp>
#include <godot_cpp/classes/shape_cast2d.hpp>
#include <godot_cpp/classes/shape_cast3d.hpp>
#include <godot_cpp/classes/tile_map_layer.hpp>
#include <godot_cpp/classes/navigation_agent2d.hpp>
#include <godot_cpp/classes/navigation_agent3d.hpp>
#include <godot_cpp/classes/navigation_server2d.hpp>
#include <godot_cpp/classes/navigation_server3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state2d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters2d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/classes/physics_server2d.hpp>
#include <godot_cpp/classes/physics_server3d.hpp>
#include <godot_cpp/classes/world2d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/classes/animation.hpp>
// Pass 4 — app platform / phone sensors
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/os.hpp>
// Pass 5 — crypto / theme / js / shader / material / skeleton / video
#include <godot_cpp/classes/hashing_context.hpp>
#include <godot_cpp/classes/crypto.hpp>
#include <godot_cpp/classes/java_script_bridge.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/skeleton3d.hpp>
#include <godot_cpp/classes/skeleton2d.hpp>
#include <godot_cpp/classes/video_stream_player.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/style_box.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/marshalls.hpp>
// Pass 6 — gap filler verbs (Camera.FlashColor overlay)
#include <godot_cpp/classes/color_rect.hpp>
#include <godot_cpp/classes/canvas_layer.hpp>
#include <godot_cpp/classes/callback_tweener.hpp>
#include <godot_cpp/classes/video_stream.hpp>
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

// ---------------------------------------------------------------------------
// Native OS message box — cross-platform, blocking.
//
// Uses the appropriate native dialog tool on each platform:
//   Linux  : zenity (GTK) → kdialog (KDE) → OS::alert() fallback
//   Windows: PowerShell [System.Windows.Forms.MessageBox]
//   macOS  : osascript (AppleScript display dialog)
//   Other  : OS::alert() fallback (Android, iOS, Web)
//
// OS::execute() blocks the calling thread while the external dialog is open,
// and the window-manager renders it independently of Godot's render loop,
// so the dialog is always visible and interactive.
//
// Returns VB6-style result: vbOK=1, vbCancel=2, vbYes=6, vbNo=7
// btn_type: 0=vbOKOnly, 1=vbOKCancel, 4=vbYesNo, 5=vbRetryCancel
// ---------------------------------------------------------------------------
int native_msgbox(const String &p_msg, const String &p_title, int p_btn_type) {
    String os_name = OS::get_singleton()->get_name();

    // =================================================================
    //  Windows — PowerShell MessageBox
    // =================================================================
    if (os_name == "Windows") {
        // Map VB6 button type to .NET MessageBoxButtons enum name
        String buttons_enum = "OK";                  // default
        if (p_btn_type == 1) buttons_enum = "OKCancel";
        if (p_btn_type == 4) buttons_enum = "YesNo";

        // Escape single-quotes in message/title for PowerShell
        String safe_msg   = p_msg.replace("'", "''");
        String safe_title = p_title.replace("'", "''");

        String ps_cmd = String("Add-Type -AssemblyName System.Windows.Forms; ")
            + "[System.Windows.Forms.MessageBox]::Show('"
            + safe_msg + "', '" + safe_title + "', '"
            + buttons_enum + "')";

        PackedStringArray args;
        args.push_back("-NoProfile");
        args.push_back("-Command");
        args.push_back(ps_cmd);
        Array output;
        OS::get_singleton()->execute("powershell", args, output);

        // PowerShell prints the DialogResult enum name: OK, Cancel, Yes, No
        String result = (output.size() > 0) ? String(output[0]).strip_edges() : String("OK");
        if (result == "Yes")    return 6;
        if (result == "No")     return 7;
        if (result == "Cancel") return 2;
        return 1; // OK
    }

    // =================================================================
    //  macOS — osascript (AppleScript)
    // =================================================================
    if (os_name == "macOS") {
        // Escape double-quotes and backslashes for AppleScript strings
        String safe_msg   = p_msg.replace("\\", "\\\\").replace("\"", "\\\"");
        String safe_title = p_title.replace("\\", "\\\\").replace("\"", "\\\"");

        String script;
        if (p_btn_type == 4) { // vbYesNo
            script = "display dialog \"" + safe_msg + "\" with title \""
                + safe_title + "\" buttons {\"No\", \"Yes\"} default button \"Yes\"";
        } else if (p_btn_type == 1) { // vbOKCancel
            script = "display dialog \"" + safe_msg + "\" with title \""
                + safe_title + "\" buttons {\"Cancel\", \"OK\"} default button \"OK\"";
        } else { // vbOKOnly
            script = "display dialog \"" + safe_msg + "\" with title \""
                + safe_title + "\" buttons {\"OK\"} default button \"OK\"";
        }

        PackedStringArray args;
        args.push_back("-e");
        args.push_back(script);
        Array output;
        int64_t exit_code = OS::get_singleton()->execute("osascript", args, output);

        // exit_code != 0 means the user pressed Cancel (AppleScript raises error 128)
        if (exit_code != 0) {
            if (p_btn_type == 4) return 7; // No
            if (p_btn_type == 1) return 2; // Cancel
            return 1;
        }
        // Parse the "button returned:Yes" from output
        String out_str = (output.size() > 0) ? String(output[0]).strip_edges() : String("");
        if (out_str.find("No") >= 0)     return 7;
        if (out_str.find("Cancel") >= 0) return 2;
        if (out_str.find("Yes") >= 0)    return 6;
        return 1; // OK
    }

    // =================================================================
    //  Linux — zenity (GTK) → kdialog (KDE) → fallback
    // =================================================================
    if (os_name == "Linux" || os_name == "FreeBSD") {
        // --- Try zenity (GNOME / GTK) ---
        {
            PackedStringArray w;
            w.push_back("zenity");
            Array dummy;
            bool has_zenity = (OS::get_singleton()->execute("which", w, dummy) == 0);
            if (has_zenity) {
                PackedStringArray args;
                if (p_btn_type == 4) { // vbYesNo
                    args.push_back("--question");
                    args.push_back("--text=" + p_msg);
                    args.push_back("--title=" + p_title);
                    args.push_back("--ok-label=Yes");
                    args.push_back("--cancel-label=No");
                } else if (p_btn_type == 1) { // vbOKCancel
                    args.push_back("--question");
                    args.push_back("--text=" + p_msg);
                    args.push_back("--title=" + p_title);
                    args.push_back("--ok-label=OK");
                    args.push_back("--cancel-label=Cancel");
                } else { // vbOKOnly (default)
                    args.push_back("--info");
                    args.push_back("--text=" + p_msg);
                    args.push_back("--title=" + p_title);
                }
                Array output;
                int64_t exit_code = OS::get_singleton()->execute("zenity", args, output);
                if (p_btn_type == 4) return (exit_code == 0) ? 6 : 7;   // Yes / No
                if (p_btn_type == 1) return (exit_code == 0) ? 1 : 2;   // OK / Cancel
                return 1; // vbOK
            }
        }
        // --- Try kdialog (KDE / Qt) ---
        {
            PackedStringArray w;
            w.push_back("kdialog");
            Array dummy;
            bool has_kdialog = (OS::get_singleton()->execute("which", w, dummy) == 0);
            if (has_kdialog) {
                PackedStringArray args;
                args.push_back("--title");
                args.push_back(p_title);
                if (p_btn_type == 4) { // vbYesNo
                    args.push_back("--yesno");
                    args.push_back(p_msg);
                } else if (p_btn_type == 1) { // vbOKCancel
                    args.push_back("--warningcontinuecancel");
                    args.push_back(p_msg);
                } else { // vbOKOnly
                    args.push_back("--msgbox");
                    args.push_back(p_msg);
                }
                Array output;
                int64_t exit_code = OS::get_singleton()->execute("kdialog", args, output);
                if (p_btn_type == 4) return (exit_code == 0) ? 6 : 7;
                if (p_btn_type == 1) return (exit_code == 0) ? 1 : 2;
                return 1; // vbOK
            }
        }
    }

    // =================================================================
    //  Fallback for all platforms (Android, iOS, Web, or if nothing above worked)
    //  OS::alert() is OK-only but at least doesn't hang.
    // =================================================================
    OS::get_singleton()->alert(p_msg, p_title);
    if (p_btn_type == 4) return 6; // default Yes
    return 1; // vbOK
}

// ---------------------------------------------------------------------------
// Native OS text-input dialog — uses zenity (GTK) or kdialog (Qt/KDE).
// OS::execute() blocks the calling thread while the external dialog is open,
// and the window-manager renders it independently of Godot's render loop,
// so the dialog is always visible and interactive.
// ---------------------------------------------------------------------------
String native_input_box(const String &p_prompt, const String &p_title, const String &p_default) {
    // --- Try zenity (GNOME / GTK) -------------------------------------------
    {
        PackedStringArray args;
        args.push_back("--entry");
        args.push_back("--text=" + p_prompt);
        args.push_back("--title=" + p_title);
        if (!p_default.is_empty()) {
            args.push_back("--entry-text=" + p_default);
        }
        Array output;
        int64_t exit_code = OS::get_singleton()->execute("zenity", args, output);
        if (exit_code == 0) {
            return (output.size() > 0) ? String(output[0]).strip_edges() : String("");
        }
        // Distinguish "user cancelled" (zenity exists) from "not installed".
        PackedStringArray w;
        w.push_back("zenity");
        if (OS::get_singleton()->execute("which", w, Array()) == 0) {
            return String(""); // zenity exists — user pressed Cancel
        }
    }
    // --- Try kdialog (KDE / Qt) ---------------------------------------------
    {
        PackedStringArray args;
        args.push_back("--inputbox");
        args.push_back(p_prompt);
        if (!p_default.is_empty()) {
            args.push_back(p_default);
        }
        args.push_back("--title");
        args.push_back(p_title);
        Array output;
        int64_t exit_code = OS::get_singleton()->execute("kdialog", args, output);
        if (exit_code == 0) {
            return (output.size() > 0) ? String(output[0]).strip_edges() : String("");
        }
        PackedStringArray w;
        w.push_back("kdialog");
        if (OS::get_singleton()->execute("which", w, Array()) == 0) {
            return String(""); // kdialog exists — user pressed Cancel
        }
    }
    // No dialog tool available — return the default value as-is.
    return p_default;
}

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

// ── PrintForm (v3.5.0) ── VB6 PrintForm statement ──
// In VB6 this prints the current form to the default printer.
// In Godot we capture the viewport to an image and save it as PNG.
// Usage: PrintForm [optional form reference]
static bool _handle_print_form(VisualGasicInstance *instance, const Array &p_args) {
    if (!instance || !instance->get_owner()) return false;
    Node *owner_node = Object::cast_to<Node>(instance->get_owner());
    if (!owner_node || !owner_node->is_inside_tree()) return false;

    // Get the viewport to capture
    Viewport *vp = owner_node->get_viewport();
    if (!vp) return false;

    Ref<Image> img = vp->get_texture()->get_image();
    if (img.is_null()) return false;

    // Save to user://PrintForm_<timestamp>.png
    String timestamp = String::num_int64(Time::get_singleton()->get_ticks_msec());
    String path = String("user://PrintForm_") + timestamp + String(".png");
    img->save_png(path);
    UtilityFunctions::print("[PrintForm] Captured viewport to: ", path);
    return true;
}

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
        String msg = "";
        if (p_args.size() > 0) msg = String(p_args[0]);
        int buttons = 0;
        if (p_args.size() > 1) buttons = (int)p_args[1];
        String title = "VisualGasic";
        if (p_args.size() > 2) title = String(p_args[2]);

        // Button type is lowest 4 bits
        int btn_type = buttons & 0x0F;

        // Force Godot to render the current frame before blocking.
        // BackColor or other visual changes made before MsgBox won't
        // appear until the render loop runs, but OS::execute() blocks
        // the main thread, so we must flush one frame here.
        RenderingServer::get_singleton()->force_draw(true, 0.0);

        // Use native OS dialog — always works, doesn't hang the Godot loop
        r_ret = native_msgbox(msg, title, btn_type);
        return true;
    }

    if (method.nocasecmp_to("InputBox") == 0) {
        r_found = true;
        String prompt = (p_args.size() > 0) ? String(p_args[0]) : String("");
        String title  = (p_args.size() > 1) ? String(p_args[1]) : String("VisualGasic");
        String def    = (p_args.size() > 2) ? String(p_args[2]) : String("");
        // Flush pending visual changes before blocking on OS dialog
        RenderingServer::get_singleton()->force_draw(true, 0.0);
        r_ret = native_input_box(prompt, title, def);
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

    // PrintForm — VB6 print-current-form statement (v3.5.0)
    if (method.nocasecmp_to("PrintForm") == 0) {
        r_found = true;
        _handle_print_form(instance, p_args);
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
    if (METHOD_IS("instr") && args.size() >= 2) { r_handled = true; if (args.size() == 2) { String s1 = args[0]; String s2 = args[1]; int pos = s1.find(s2); if (pos==-1) return 0; return pos+1; } else { int start = (int)args[0]; String s1 = args[1]; String s2 = args[2]; if (start < 1) start = 1; if (start > s1.length()) return 0; int pos = s1.find(s2, start - 1); if (pos==-1) return 0; return pos+1; } }
    if (METHOD_IS("instrrev") && args.size() >= 2) { r_handled = true; String s1 = args[0]; String s2 = args[1]; int start = (args.size() >= 3) ? (int)args[2] - 1 : s1.length() - 1; if (start < 0 || start >= s1.length()) start = s1.length() - 1; int pos = s1.rfind(s2, start); if (pos == -1) return 0; return pos + 1; }
    if (METHOD_IS("replace") && args.size() == 3) { r_handled = true; return String(args[0]).replace(String(args[1]), String(args[2])); }
    if (METHOD_IS("trim") && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(); }
    if (METHOD_IS("ltrim") && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(true,false); }
    if (METHOD_IS("rtrim") && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(false,true); }
    if (METHOD_IS("strreverse") && args.size() == 1) { r_handled = true; String s = args[0]; String res=""; for(int i=s.length()-1;i>=0;i--) res += s[i]; return res; }
    if (METHOD_IS("hex") && args.size() == 1) { r_handled = true; int64_t val = (int64_t)args[0]; return String::num_int64(val,16).to_upper(); }
    if (METHOD_IS("oct") && args.size() == 1) { r_handled = true; int64_t val = (int64_t)args[0]; return String::num_int64(val,8); }
    if (METHOD_IS("split") && args.size() >= 2) { r_handled = true; PackedStringArray psa = String(args[0]).split(String(args[1])); Array ret; for (int i = 0; i < psa.size(); i++) { ret.push_back(psa[i]); } return ret; }
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

    // ── Pass 1: math built-in type constructors ─────────────────────────
    // Quaternion(x,y,z,w) | Quaternion() = identity
    if (METHOD_IS("quaternion")) {
        r_handled = true;
        if (args.size() == 0) return Quaternion();
        if (args.size() == 4) return Quaternion((real_t)(double)args[0], (real_t)(double)args[1], (real_t)(double)args[2], (real_t)(double)args[3]);
        return Quaternion();
    }
    // QuaternionFromEuler(x_rad, y_rad, z_rad) — rotation from Euler XYZ
    if (METHOD_IS("quaternionfromeuler") && args.size() == 3) {
        r_handled = true;
        Vector3 e((real_t)(double)args[0], (real_t)(double)args[1], (real_t)(double)args[2]);
        return Quaternion::from_euler(e);
    }
    // Basis() = identity (full Basis construction goes via Quaternion or methods on the value)
    if (METHOD_IS("basis")) {
        r_handled = true;
        if (args.size() == 0) return Basis();
        if (args.size() == 1) {
            // Basis from Quaternion
            Quaternion q = args[0];
            return Basis(q);
        }
        return Basis();
    }
    // Transform2D() | Transform2D(rotation_rad, origin_vec2) | Transform2D(rotation, scale, skew, origin)
    if (METHOD_IS("transform2d")) {
        r_handled = true;
        if (args.size() == 0) return Transform2D();
        if (args.size() == 2) {
            real_t rot = (real_t)(double)args[0];
            Vector2 origin = args[1];
            return Transform2D(rot, origin);
        }
        if (args.size() == 4) {
            real_t rot = (real_t)(double)args[0];
            Vector2 scale = args[1];
            real_t skew = (real_t)(double)args[2];
            Vector2 origin = args[3];
            return Transform2D(rot, scale, skew, origin);
        }
        return Transform2D();
    }
    // Transform3D() | Transform3D(basis, origin_vec3)
    if (METHOD_IS("transform3d")) {
        r_handled = true;
        if (args.size() == 0) return Transform3D();
        if (args.size() == 2) {
            Basis b = args[0];
            Vector3 origin = args[1];
            return Transform3D(b, origin);
        }
        return Transform3D();
    }
    // Plane(a, b, c, d) plane equation | Plane(normal_vec3, d) | Plane(normal_vec3)
    if (METHOD_IS("plane")) {
        r_handled = true;
        if (args.size() == 0) return Plane();
        if (args.size() == 1) {
            Vector3 n = args[0];
            return Plane(n, 0.0f);
        }
        if (args.size() == 2) {
            Vector3 n = args[0];
            return Plane(n, (real_t)(double)args[1]);
        }
        if (args.size() == 4) {
            return Plane((real_t)(double)args[0], (real_t)(double)args[1], (real_t)(double)args[2], (real_t)(double)args[3]);
        }
        return Plane();
    }
    // AABB() | AABB(position_vec3, size_vec3)
    if (METHOD_IS("aabb")) {
        r_handled = true;
        if (args.size() == 0) return AABB();
        if (args.size() == 2) {
            Vector3 pos = args[0];
            Vector3 size = args[1];
            return AABB(pos, size);
        }
        return AABB();
    }
    // NewRNG([seed]) — fresh RandomNumberGenerator (per-stream RNG)
    if (METHOD_IS("newrng")) {
        r_handled = true;
        Ref<RandomNumberGenerator> rng;
        rng.instantiate();
        if (args.size() == 1) rng->set_seed((uint64_t)(int64_t)args[0]);
        else rng->randomize();
        return rng;
    }
    // NewNoise([seed]) — FastNoiseLite generator (Perlin/Simplex etc.)
    if (METHOD_IS("newnoise")) {
        r_handled = true;
        Ref<FastNoiseLite> n;
        n.instantiate();
        if (args.size() == 1) n->set_seed((int32_t)(int64_t)args[0]);
        return n;
    }
    // NewCurve() — empty Curve, add points via Curve.add_point() / sample()
    if (METHOD_IS("newcurve")) {
        r_handled = true;
        Ref<Curve> c;
        c.instantiate();
        return c;
    }

    // ── Pass 1: global math/color verbs ─────────────────────────────────
    // Slerp(a, b, t) — overloaded: Quaternion / Vector3 / Vector2 / Color
    if (METHOD_IS("slerp") && args.size() == 3) {
        r_handled = true;
        Variant a = args[0]; Variant b = args[1]; real_t t = (real_t)(double)args[2];
        switch (a.get_type()) {
            case Variant::QUATERNION: { Quaternion qa = a; Quaternion qb = b; return qa.slerp(qb, t); }
            case Variant::VECTOR3:    { Vector3 va = a; Vector3 vb = b; return va.slerp(vb, t); }
            case Variant::VECTOR2:    { Vector2 va = a; Vector2 vb = b; return va.slerp(vb, t); }
            default: break;
        }
        return Variant();
    }
    // ColorFromHSV(h, s, v[, a]) — h/s/v in 0..1
    if (METHOD_IS("colorfromhsv")) {
        r_handled = true;
        if (args.size() >= 3) {
            float h = (float)(double)args[0];
            float s = (float)(double)args[1];
            float v = (float)(double)args[2];
            float a = (args.size() >= 4) ? (float)(double)args[3] : 1.0f;
            return Color::from_hsv(h, s, v, a);
        }
        return Color();
    }
    // ColorToHSV(c) — returns Dictionary {h, s, v, a}
    if (METHOD_IS("colortohsv") && args.size() == 1) {
        r_handled = true;
        Color c = args[0];
        Dictionary d;
        d["h"] = c.get_h();
        d["s"] = c.get_s();
        d["v"] = c.get_v();
        d["a"] = c.a;
        return d;
    }
    // Lighten(c, amount) / Darken(c, amount) — amount in 0..1
    if (METHOD_IS("lighten") && args.size() == 2) {
        r_handled = true;
        Color c = args[0];
        return c.lightened((float)(double)args[1]);
    }
    if (METHOD_IS("darken") && args.size() == 2) {
        r_handled = true;
        Color c = args[0];
        return c.darkened((float)(double)args[1]);
    }

    // ── Pass 2: Camera/Sound/Speaker namespace dispatch ─────────────────
    //
    // Compiler rewrites  Camera.Zoom(v)  →  OP_CALL "camera_zoom"  etc.
    // All Pass 2 builtin names are namespace-prefixed: camera_*, sound_*,
    // speaker_*. They operate on the active scene tree / AudioServer.
    //
    // Camera convention: every camera_* verb accepts an optional final
    // argument that overrides the "active" camera. When omitted, we use
    // SceneTree::get_root()->get_camera_2d() / get_camera_3d() — whichever
    // is current. 2D and 3D are picked by which one is active.
    //
    // Helper lambdas live inside one block; they capture `instance` only.
    {
        auto resolve_camera = [&](const Variant &override_cam) -> Object* {
            if (override_cam.get_type() == Variant::OBJECT) {
                Object *o = override_cam;
                if (o && (o->is_class("Camera2D") || o->is_class("Camera3D"))) return o;
            }
            if (!instance || !instance->get_owner()) return nullptr;
            Node *n = Object::cast_to<Node>(instance->get_owner());
            if (!n) return nullptr;
            SceneTree *st = n->get_tree();
            if (!st) return nullptr;
            Viewport *vp = st->get_root();
            if (!vp) return nullptr;
            Camera3D *c3 = vp->get_camera_3d();
            if (c3) return c3;
            Camera2D *c2 = vp->get_camera_2d();
            return c2;
        };

        // Camera.Position(pos[, h]) — set position (Vector2 or Vector3)
        if (METHOD_IS("camera_position") && args.size() >= 1) {
            r_handled = true;
            Variant override_h = (args.size() >= 2) ? args[args.size() - 1] : Variant();
            Object *cam = resolve_camera(override_h);
            if (!cam) return Variant();
            if (cam->is_class("Camera2D")) {
                Camera2D *c = Object::cast_to<Camera2D>(cam);
                c->set_position((Vector2)args[0]);
            } else if (cam->is_class("Camera3D")) {
                Camera3D *c = Object::cast_to<Camera3D>(cam);
                c->set_position((Vector3)args[0]);
            }
            return Variant();
        }
        // Camera.Zoom(v[, h]) — Vector2 for 2D, scalar fov-divisor for 3D unsupported
        if (METHOD_IS("camera_zoom") && args.size() >= 1) {
            r_handled = true;
            Variant override_h = (args.size() >= 2) ? args[args.size() - 1] : Variant();
            Object *cam = resolve_camera(override_h);
            if (!cam) return Variant();
            Camera2D *c = Object::cast_to<Camera2D>(cam);
            if (c) {
                if (args[0].get_type() == Variant::VECTOR2) {
                    c->set_zoom((Vector2)args[0]);
                } else {
                    float z = (float)(double)args[0];
                    c->set_zoom(Vector2(z, z));
                }
            }
            return Variant();
        }
        // Camera.Limits(left, top, right, bottom[, h]) — Camera2D pan clamps
        if (METHOD_IS("camera_limits") && args.size() >= 4) {
            r_handled = true;
            Variant override_h = (args.size() >= 5) ? args[args.size() - 1] : Variant();
            Object *cam = resolve_camera(override_h);
            Camera2D *c = Object::cast_to<Camera2D>(cam);
            if (c) {
                c->set_limit(SIDE_LEFT,   (int)args[0]);
                c->set_limit(SIDE_TOP,    (int)args[1]);
                c->set_limit(SIDE_RIGHT,  (int)args[2]);
                c->set_limit(SIDE_BOTTOM, (int)args[3]);
            }
            return Variant();
        }
        // Camera.FOV(degrees[, h]) — Camera3D field of view
        if (METHOD_IS("camera_fov") && args.size() >= 1) {
            r_handled = true;
            Variant override_h = (args.size() >= 2) ? args[args.size() - 1] : Variant();
            Object *cam = resolve_camera(override_h);
            Camera3D *c = Object::cast_to<Camera3D>(cam);
            if (c) c->set_fov((float)(double)args[0]);
            return Variant();
        }
        // Camera.MakeCurrent([h]) — mark camera as the active one
        if (METHOD_IS("camera_makecurrent")) {
            r_handled = true;
            Variant override_h = (args.size() >= 1) ? args[0] : Variant();
            Object *cam = resolve_camera(override_h);
            if (!cam) return Variant();
            Camera2D *c2 = Object::cast_to<Camera2D>(cam);
            if (c2) { c2->make_current(); return Variant(); }
            Camera3D *c3 = Object::cast_to<Camera3D>(cam);
            if (c3) { c3->make_current(); }
            return Variant();
        }
        // Camera.Rotation(radians_or_v3[, h]) — Camera2D scalar, Camera3D Vector3
        if (METHOD_IS("camera_rotation") && args.size() >= 1) {
            r_handled = true;
            Variant override_h = (args.size() >= 2) ? args[args.size() - 1] : Variant();
            Object *cam = resolve_camera(override_h);
            if (!cam) return Variant();
            if (cam->is_class("Camera2D")) {
                Object::cast_to<Camera2D>(cam)->set_rotation((float)(double)args[0]);
            } else if (cam->is_class("Camera3D")) {
                Object::cast_to<Camera3D>(cam)->set_rotation((Vector3)args[0]);
            }
            return Variant();
        }
        // Camera.Follow(target[, h]) — continuous follow via RemoteTransform.
        // Adds a RemoteTransform2D/3D child to `target` that mirrors its
        // transform onto the camera. Removes any previous follow link first.
        // Camera.Follow(Nothing[, h]) — stop following.
        if (METHOD_IS("camera_follow") && args.size() >= 1) {
            r_handled = true;
            Variant override_h = (args.size() >= 2) ? args[args.size() - 1] : Variant();
            Object *cam = resolve_camera(override_h);
            if (!cam) return Variant();
            Node *cam_node = Object::cast_to<Node>(cam);
            if (!cam_node) return Variant();

            // Clear any existing follow link tagged with metadata "__vg_follow"
            Node *prev_rt_owner = nullptr;
            if (cam_node->has_meta("__vg_follow_remote_path")) {
                NodePath p = cam_node->get_meta("__vg_follow_remote_path");
                if (cam_node->is_inside_tree()) {
                    Node *rt = cam_node->get_node_or_null(p);
                    if (rt) prev_rt_owner = rt;
                }
            }
            if (prev_rt_owner) {
                prev_rt_owner->queue_free();
                cam_node->remove_meta("__vg_follow_remote_path");
            }

            // Stop following if target is Nil
            if (args[0].get_type() == Variant::NIL) return Variant();

            Object *tgt_obj = args[0];
            Node *tgt = Object::cast_to<Node>(tgt_obj);
            if (!tgt) return Variant();

            if (cam->is_class("Camera2D") && tgt->is_class("Node2D")) {
                RemoteTransform2D *rt = memnew(RemoteTransform2D);
                rt->set_name("__vg_follow_rt");
                rt->set_update_rotation(false);
                rt->set_update_scale(false);
                tgt->add_child(rt);
                rt->set_remote_node(cam_node->get_path());
                cam_node->set_meta("__vg_follow_remote_path", NodePath("../" + String(tgt->get_name()) + "/__vg_follow_rt"));
            } else if (cam->is_class("Camera3D") && tgt->is_class("Node3D")) {
                RemoteTransform3D *rt = memnew(RemoteTransform3D);
                rt->set_name("__vg_follow_rt");
                rt->set_update_rotation(false);
                rt->set_update_scale(false);
                tgt->add_child(rt);
                rt->set_remote_node(cam_node->get_path());
                cam_node->set_meta("__vg_follow_remote_path", NodePath("../" + String(tgt->get_name()) + "/__vg_follow_rt"));
            }
            return Variant();
        }
        // Camera.Shake(intensity, duration[, h]) — quick stub: jitter offset
        // for `duration` seconds via a tween on the camera's offset property.
        if (METHOD_IS("camera_shake") && args.size() >= 2) {
            r_handled = true;
            Variant override_h = (args.size() >= 3) ? args[args.size() - 1] : Variant();
            Object *cam = resolve_camera(override_h);
            Node *cam_node = Object::cast_to<Node>(cam);
            if (!cam_node) return Variant();
            double intensity = (double)args[0];
            double duration  = (double)args[1];
            Ref<Tween> tw = cam_node->create_tween();
            if (tw.is_valid()) {
                // 8 random pokes spread over duration; final settles to (0,0)
                int steps = MAX(2, (int)(duration * 30.0));
                double step_dur = duration / steps;
                for (int i = 0; i < steps - 1; i++) {
                    Vector2 r(
                        ((double)rand() / RAND_MAX - 0.5) * 2.0 * intensity,
                        ((double)rand() / RAND_MAX - 0.5) * 2.0 * intensity);
                    tw->tween_property(cam_node, "offset", r, step_dur);
                }
                tw->tween_property(cam_node, "offset", Vector2(0, 0), step_dur);
            }
            return Variant();
        }

        // ── Sound.* — playback control ────────────────────────────────
        //
        // Sound.Play(path[, bus]) → handle (int, the AudioStreamPlayer ObjectID)
        // Sound.Stop(h), Sound.Pause(h), Sound.Resume(h), Sound.Seek(h, sec)
        // Sound.Volume(pct[, h]) — pct=0..100; when h omitted, sets the
        //   "Master" bus volume (so users with no handle still get a knob).
        // Sound.Pitch(scale, h), Sound.IsPlaying(h), Sound.Position(h) → sec
        //
        // Internally each Sound.Play() spawns an AudioStreamPlayer parented
        // to the owning Node. Auto-free on finished (unless Loop=True later).

        auto resolve_player = [&](const Variant &h) -> AudioStreamPlayer* {
            if (h.get_type() != Variant::INT) return nullptr;
            int64_t id = (int64_t)h;
            Object *o = ObjectDB::get_instance(ObjectID((uint64_t)id));
            return Object::cast_to<AudioStreamPlayer>(o);
        };

        if (METHOD_IS("sound_play") && args.size() >= 1) {
            r_handled = true;
            if (!instance || !instance->get_owner()) return Variant();
            Node *n = Object::cast_to<Node>(instance->get_owner());
            if (!n) return Variant();
            String path = args[0];
            Ref<AudioStream> stream = ResourceLoader::get_singleton()->load(path);
            if (!stream.is_valid()) return Variant();
            AudioStreamPlayer *p = memnew(AudioStreamPlayer);
            p->set_stream(stream);
            if (args.size() >= 2) {
                p->set_bus(StringName(String(args[1])));
            }
            p->set_autoplay(false);
            p->connect("finished", Callable(p, "queue_free"));
            n->add_child(p);
            p->play();
            return (int64_t)(uint64_t)p->get_instance_id();
        }
        if (METHOD_IS("sound_stop") && args.size() == 1) {
            r_handled = true;
            AudioStreamPlayer *p = resolve_player(args[0]);
            if (p) { p->stop(); p->queue_free(); }
            return Variant();
        }
        if (METHOD_IS("sound_pause") && args.size() == 1) {
            r_handled = true;
            AudioStreamPlayer *p = resolve_player(args[0]);
            if (p) p->set_stream_paused(true);
            return Variant();
        }
        if (METHOD_IS("sound_resume") && args.size() == 1) {
            r_handled = true;
            AudioStreamPlayer *p = resolve_player(args[0]);
            if (p) p->set_stream_paused(false);
            return Variant();
        }
        if (METHOD_IS("sound_seek") && args.size() == 2) {
            r_handled = true;
            AudioStreamPlayer *p = resolve_player(args[0]);
            if (p) p->seek((float)(double)args[1]);
            return Variant();
        }
        if (METHOD_IS("sound_isplaying") && args.size() == 1) {
            r_handled = true;
            AudioStreamPlayer *p = resolve_player(args[0]);
            return p ? p->is_playing() : false;
        }
        if (METHOD_IS("sound_position") && args.size() == 1) {
            r_handled = true;
            AudioStreamPlayer *p = resolve_player(args[0]);
            return p ? (double)p->get_playback_position() : 0.0;
        }
        // Sound.Pitch(scale[, h]) — h optional; without h, no-op (per-handle only)
        if (METHOD_IS("sound_pitch") && args.size() >= 2) {
            r_handled = true;
            double scale = (double)args[0];
            AudioStreamPlayer *p = resolve_player(args[1]);
            if (p) p->set_pitch_scale((float)scale);
            return Variant();
        }
        // Sound.Volume(pct[, h]) — pct 0..100; without h, sets "Master" bus
        if (METHOD_IS("sound_volume") && args.size() >= 1) {
            r_handled = true;
            double pct = (double)args[0];
            float db = (pct <= 0.0) ? -80.0f : (float)(20.0 * log10(pct / 100.0));
            if (args.size() >= 2) {
                AudioStreamPlayer *p = resolve_player(args[1]);
                if (p) p->set_volume_db(db);
            } else {
                AudioServer *as = AudioServer::get_singleton();
                if (as) {
                    int idx = as->get_bus_index(StringName("Master"));
                    if (idx >= 0) as->set_bus_volume_db(idx, db);
                }
            }
            return Variant();
        }

        // ── Speaker.* — audio bus controls (Godot calls these "buses") ──
        //
        // Speaker.Volume(name[, pct]) — get if pct omitted, else set
        // Speaker.Mute(name, bool)
        // Speaker.IsMuted(name) → Boolean
        // Speaker.Solo(name, bool)
        // Speaker.Exists(name) → Boolean
        // Speaker.Count() → number of buses
        // Speaker.Name(index) → bus name at index
        //
        // pct 0..100 maps to dB via linear_to_db(pct/100).

        if (METHOD_IS("speaker_volume") && args.size() >= 1) {
            r_handled = true;
            AudioServer *as = AudioServer::get_singleton();
            if (!as) return Variant();
            String name = args[0];
            int idx = as->get_bus_index(StringName(name));
            if (idx < 0) return Variant();
            if (args.size() == 1) {
                // get → percent
                float db = as->get_bus_volume_db(idx);
                double pct = pow(10.0, db / 20.0) * 100.0;
                return pct;
            }
            double pct = (double)args[1];
            float db = (pct <= 0.0) ? -80.0f : (float)(20.0 * log10(pct / 100.0));
            as->set_bus_volume_db(idx, db);
            return Variant();
        }
        if (METHOD_IS("speaker_mute") && args.size() == 2) {
            r_handled = true;
            AudioServer *as = AudioServer::get_singleton();
            if (!as) return Variant();
            int idx = as->get_bus_index(StringName(String(args[0])));
            if (idx >= 0) as->set_bus_mute(idx, (bool)args[1]);
            return Variant();
        }
        if (METHOD_IS("speaker_ismuted") && args.size() == 1) {
            r_handled = true;
            AudioServer *as = AudioServer::get_singleton();
            if (!as) return false;
            int idx = as->get_bus_index(StringName(String(args[0])));
            return (idx >= 0) ? as->is_bus_mute(idx) : false;
        }
        if (METHOD_IS("speaker_solo") && args.size() == 2) {
            r_handled = true;
            AudioServer *as = AudioServer::get_singleton();
            if (!as) return Variant();
            int idx = as->get_bus_index(StringName(String(args[0])));
            if (idx >= 0) as->set_bus_solo(idx, (bool)args[1]);
            return Variant();
        }
        if (METHOD_IS("speaker_exists") && args.size() == 1) {
            r_handled = true;
            AudioServer *as = AudioServer::get_singleton();
            if (!as) return false;
            return as->get_bus_index(StringName(String(args[0]))) >= 0;
        }
        if (METHOD_IS("speaker_count")) {
            r_handled = true;
            AudioServer *as = AudioServer::get_singleton();
            return as ? as->get_bus_count() : 0;
        }
        if (METHOD_IS("speaker_name") && args.size() == 1) {
            r_handled = true;
            AudioServer *as = AudioServer::get_singleton();
            if (!as) return String();
            int idx = (int)args[0];
            if (idx < 0 || idx >= as->get_bus_count()) return String();
            return String(as->get_bus_name(idx));
        }

        // ── SoundGen.* — AudioStreamGenerator real-time synthesis ────────────
        //
        // SoundGen.Open(mix_rate, buffer_length)  → handle (Long)
        //   Creates an AudioStreamGenerator + AudioStreamPlayer, starts playing,
        //   returns the player's ObjectID as a handle.
        //   mix_rate     : samples/second (e.g. 44100.0)
        //   buffer_length: ring-buffer length in seconds (e.g. 0.1)
        //
        // SoundGen.Close(h)
        //   Stops and frees the stream player.
        //
        // SoundGen.Available(h)  → Integer
        //   Number of stereo frames that can be pushed without blocking.
        //   Call each _Process() and push exactly this many frames.
        //
        // SoundGen.PushMono(h, sample)
        //   Pushes one mono sample (Single) as a stereo frame (L=R=sample).
        //   Call inside a For loop: For i = 0 To SoundGen.Available(h) - 1
        //
        // SoundGen.PushStereo(h, left, right)
        //   Pushes one stereo frame (two Singles).

        auto resolve_gen_playback = [&](const Variant &h) -> AudioStreamGeneratorPlayback* {
            if (h.get_type() != Variant::INT) return nullptr;
            int64_t id = (int64_t)h;
            Object *o = ObjectDB::get_instance(ObjectID((uint64_t)id));
            AudioStreamPlayer *p = Object::cast_to<AudioStreamPlayer>(o);
            if (!p) return nullptr;
            Ref<AudioStreamPlayback> pb = p->get_stream_playback();
            if (!pb.is_valid()) return nullptr;
            return Object::cast_to<AudioStreamGeneratorPlayback>(pb.ptr());
        };

        if (METHOD_IS("soundgen_open") && args.size() >= 2) {
            r_handled = true;
            if (!instance || !instance->get_owner()) return Variant();
            Node *n = Object::cast_to<Node>(instance->get_owner());
            if (!n) return Variant();
            float mix_rate = (float)(double)args[0];
            float buf_len  = (float)(double)args[1];
            Ref<AudioStreamGenerator> gen;
            gen.instantiate();
            gen->set_mix_rate(mix_rate);
            gen->set_buffer_length(buf_len);
            AudioStreamPlayer *p = memnew(AudioStreamPlayer);
            p->set_stream(gen);
            n->add_child(p);
            p->play();
            return (int64_t)(uint64_t)p->get_instance_id();
        }
        if (METHOD_IS("soundgen_close") && args.size() == 1) {
            r_handled = true;
            if (args[0].get_type() == Variant::INT) {
                int64_t id = (int64_t)args[0];
                Object *o = ObjectDB::get_instance(ObjectID((uint64_t)id));
                AudioStreamPlayer *p = Object::cast_to<AudioStreamPlayer>(o);
                if (p) { p->stop(); p->queue_free(); }
            }
            return Variant();
        }
        if (METHOD_IS("soundgen_available") && args.size() == 1) {
            r_handled = true;
            AudioStreamGeneratorPlayback *pb = resolve_gen_playback(args[0]);
            return pb ? (int)pb->get_frames_available() : 0;
        }
        if (METHOD_IS("soundgen_pushmono") && args.size() == 2) {
            r_handled = true;
            AudioStreamGeneratorPlayback *pb = resolve_gen_playback(args[0]);
            if (pb) {
                float s = (float)(double)args[1];
                pb->push_frame(Vector2(s, s));
            }
            return Variant();
        }
        if (METHOD_IS("soundgen_pushstereo") && args.size() == 3) {
            r_handled = true;
            AudioStreamGeneratorPlayback *pb = resolve_gen_playback(args[0]);
            if (pb) {
                float l = (float)(double)args[1];
                float r = (float)(double)args[2];
                pb->push_frame(Vector2(l, r));
            }
            return Variant();
        }
        // SoundGen.PushMonoBuffer(h, samples)
        //   Push an entire PackedFloat32Array as mono frames in one call.
        //   Dramatically cheaper than calling PushMono N times — the tight
        //   native loop skips all VG dispatch overhead per sample.
        //   Only pushes min(samples.size(), frames_available) frames; does
        //   NOT push silence for the remainder (caller manages that).
        if (METHOD_IS("soundgen_pushmonobuffer") && args.size() == 2) {
            r_handled = true;
            AudioStreamGeneratorPlayback *pb = resolve_gen_playback(args[0]);
            if (pb) {
                PackedFloat32Array buf = (PackedFloat32Array)args[1];
                int n = (int)buf.size();
                int avail = (int)pb->get_frames_available();
                if (n > avail) n = avail;
                const float *rd = buf.ptr();
                for (int ii = 0; ii < n; ++ii) {
                    float s = rd[ii];
                    pb->push_frame(Vector2(s, s));
                }
            }
            return Variant();
        }
        // SoundGen.PushStereoBuffer(h, samples)
        //   Push a PackedFloat32Array as stereo frames.  Samples are
        //   interleaved: [L0, R0, L1, R1, ...].  Pushes
        //   min(samples.size()/2, frames_available) frames.
        if (METHOD_IS("soundgen_pushstereobuffer") && args.size() == 2) {
            r_handled = true;
            AudioStreamGeneratorPlayback *pb = resolve_gen_playback(args[0]);
            if (pb) {
                PackedFloat32Array buf = (PackedFloat32Array)args[1];
                int total = (int)buf.size();
                int frames = total / 2;
                int avail = (int)pb->get_frames_available();
                if (frames > avail) frames = avail;
                const float *rd = buf.ptr();
                for (int ii = 0; ii < frames; ++ii) {
                    pb->push_frame(Vector2(rd[ii * 2], rd[ii * 2 + 1]));
                }
            }
            return Variant();
        }

        // SoundGen.FillVoices(h, sample_rate,
        //   arp_phase, arp_freq,
        //   kick_active, kick_t, kick_dur,
        //   noise_active, noise_t, noise_decay)
        // → PackedFloat32Array [new_arp_phase, new_kick_t, new_noise_t]
        //
        // Synthesizes exactly SoundGen.Available() mono frames in C++ — no
        // VG loop overhead.  Mixes three voices:
        //   1. Square-wave arpeggio  (always on)
        //   2. Bass kick sine-sweep  (when kick_active != 0)
        //   3. White-noise burst     (when noise_active != 0)
        // Pushes frames directly into the ring-buffer and returns updated
        // phase/time state so VG can advance its globals.
        if (METHOD_IS("soundgen_fillvoices") && args.size() == 10) {
            r_handled = true;
            AudioStreamGeneratorPlayback *pb = resolve_gen_playback(args[0]);
            PackedFloat32Array result;
            result.resize(3);
            float new_arp_phase = (float)(double)args[2];
            float new_kick_t    = (float)(double)args[6];
            float new_noise_t   = (float)(double)args[8];
            result[0] = new_arp_phase;
            result[1] = new_kick_t;
            result[2] = new_noise_t;
            if (!pb) return result;

            float sample_rate  = (float)(double)args[1];
            float arp_phase    = (float)(double)args[2];
            float arp_freq     = (float)(double)args[3];
            bool  kick_active  = (bool)args[4];
            float kick_t       = (float)(double)args[5];
            float kick_dur     = (float)(double)args[6];
            bool  noise_active = (bool)args[7];
            float noise_t      = (float)(double)args[8];
            float noise_decay  = (float)(double)args[9];

            float inv_sr       = 1.0f / sample_rate;
            float phase_inc    = arp_freq * inv_sr;
            int   n_frames     = (int)pb->get_frames_available();

            // Simple LCG for noise — fast, deterministic, no heap alloc
            uint32_t rng = 12345u + (uint32_t)(noise_t * 44100.0f);

            for (int i = 0; i < n_frames; ++i) {
                float t_offset = i * inv_sr;

                // Voice 1: square arpeggio
                arp_phase += phase_inc;
                if (arp_phase >= 1.0f) arp_phase -= 1.0f;
                float samp = (arp_phase < 0.5f) ? 0.10f : -0.10f;

                // Voice 2: bass kick (sine sweep 120→40 Hz)
                if (kick_active) {
                    float kt  = kick_t + t_offset;
                    float env = 1.0f - kt / kick_dur;
                    if (env < 0.0f) env = 0.0f;
                    float freq = 120.0f - 80.0f * (kt / kick_dur);
                    samp += Math::sin(kt * freq * Math_TAU) * env * 0.65f;
                }

                // Voice 3: white noise burst
                if (noise_active) {
                    rng = rng * 1664525u + 1013904223u;
                    float n01 = (float)(rng >> 1) / (float)0x7FFFFFFFu - 1.0f;
                    float nt  = noise_t + t_offset;
                    float env = Math::exp(-noise_decay * nt);
                    samp += n01 * env * 0.50f;
                }

                pb->push_frame(Vector2(samp, samp));
            }

            result[0] = arp_phase;
            result[1] = kick_t + n_frames * inv_sr;
            result[2] = noise_t + n_frames * inv_sr;
            return result;
        }

        // SoundGen.FillVoices4(h, sample_rate,
        //   lead_f, lead_phase,
        //   bass_f, bass_phase,
        //   arp_f,  arp_phase,
        //   hihat_active, hihat_t, hihat_inv_sr)
        // → PackedFloat32Array [new_lead_phase, new_bass_phase, new_arp_phase, new_hihat_t]
        // Synthesizes exactly SoundGen.Available() mono frames in C++ for all 4 voices:
        //   Voice 1: square lead  (±0.11 at 50% duty)
        //   Voice 2: sine bass    (×0.18)
        //   Voice 3: square arp   (±0.07 at 50% duty)
        //   Voice 4: noise hi-hat (exponential decay ×0.05)
        // Pushes PCM directly into the ring-buffer.  Returns updated phase state.
        if (METHOD_IS("soundgen_fillvoices4") && (args.size() == 11 || args.size() == 14)) {
            r_handled = true;
            AudioStreamGeneratorPlayback *pb = resolve_gen_playback(args[0]);
            PackedFloat32Array result4;
            bool has_kick = (args.size() >= 14);
            result4.resize(has_kick ? 5 : 4);
            float lp = (float)(double)args[3];
            float bp = (float)(double)args[5];
            float ap = (float)(double)args[7];
            float ht = (float)(double)args[9];
            bool  kick_on_  = has_kick && (bool)args[11];
            float kick_t_   = has_kick ? (float)(double)args[12] : 0.0f;
            float kick_dur_ = has_kick ? (float)(double)args[13] : 0.3f;
            result4[0] = lp; result4[1] = bp; result4[2] = ap; result4[3] = ht;
            if (has_kick) result4[4] = kick_t_;
            if (!pb) return result4;

            float sr         = (float)(double)args[1];
            float lead_f     = (float)(double)args[2];
            float bass_f     = (float)(double)args[4];
            float arp_f      = (float)(double)args[6];
            bool  hihat_on   = (bool)args[8];
            float hihat_inv  = (float)(double)args[10];
            float inv_sr     = 1.0f / sr;
            float lead_inc   = lead_f  * inv_sr;
            float bass_inc   = bass_f  * inv_sr;
            float arp_inc    = arp_f   * inv_sr;
            int   nf         = (int)pb->get_frames_available();
            uint32_t rng     = 12345u + (uint32_t)(ht * sr);
            // Note envelope: fast attack (5ms), exponential decay to sustain ~0.6
            float env_attack = 1.0f / (0.005f * sr);  // per-sample attack increment
            static float note_env = 1.0f;              // persists across calls via rng seed trick
            // We use lp position as proxy: if lp < lead_inc*nf it's a new note
            float note_env_val = 1.0f - Math::exp(-lp * 12.0f); // smooth attack based on phase

            for (int i = 0; i < nf; ++i) {
                float s = 0.0f;
                float env = 1.0f - Math::exp(-lp * 8.0f); // per-sample envelope via phase proxy

                // Voice 1: triangle lead (softer than square)
                if (lead_f > 0.0f) {
                    lp += lead_inc;
                    if (lp >= 1.0f) lp -= 1.0f;
                    float tri = (lp < 0.5f) ? (4.0f * lp - 1.0f) : (3.0f - 4.0f * lp);
                    s += tri * 0.13f;
                }

                // Voice 2: sine bass
                if (bass_f > 0.0f) {
                    bp += bass_inc;
                    if (bp >= 1.0f) bp -= 1.0f;
                    s += Math::sin(bp * Math_TAU) * 0.16f;
                }

                // Voice 3: sawtooth arp
                if (arp_f > 0.0f) {
                    ap += arp_inc;
                    if (ap >= 1.0f) ap -= 1.0f;
                    s += (ap * 2.0f - 1.0f) * 0.05f;
                }

                // Voice 4: noise hi-hat (exponential decay)
                if (hihat_on) {
                    rng = rng * 1664525u + 1013904223u;
                    float n01 = (float)(int32_t)rng / (float)0x7FFFFFFF;
                    float henv = Math::exp(-ht * 100.0f);
                    s += n01 * henv * 0.045f;
                    ht += hihat_inv;
                    if (henv < 0.001f) hihat_on = false;
                }

                // Voice 5: heartbeat kick drum (sine sweep 100→25 Hz, fast linear decay)
                if (kick_on_) {
                    float kt = kick_t_ + i * inv_sr;
                    if (kt < kick_dur_) {
                        float env = 1.0f - kt / kick_dur_;
                        float freq = 100.0f - 75.0f * (kt / kick_dur_);
                        s += Math::sin(kt * freq * Math_TAU) * env * 0.32f;
                    }
                }

                // Soft-clip to prevent clipping (tanh limiter)
                s = Math::tanh(s * 1.4f) / 1.4f;

                pb->push_frame(Vector2(s, s));
            }

            result4[0] = lp;
            result4[1] = bp;
            result4[2] = ap;
            result4[3] = ht;
            if (has_kick) result4[4] = kick_t_ + nf * inv_sr;
            return result4;
        }
    }

    // ── Pass 3: game-completeness namespaces ────────────────────────────
    //
    // Animation.* — AnimationPlayer control
    // Physics.*   — one-shot ray/force/impulse/torque + Push/Pull/Spin verbs
    // Ray.*       — placed RayCast2D/3D node accessors
    // Cell.*      — TileMapLayer cell read/write
    // Nav.*       — NavigationAgent + path query
    //
    // Every namespace verb operates on a passed-in node handle (no implicit
    // "active" — these are scene-specific). Returns Variant() / false / 0
    // when the handle is invalid so user code keeps running.
    {
        // ── Animation.* ───────────────────────────────────────────────
        // Animation.Play(player, name [, speed])
        // Animation.Stop(player [, keepState])
        // Animation.Pause(player), Animation.Resume(player)
        // Animation.Seek(player, seconds [, update])
        // Animation.Speed(player, scale)         — playback speed
        // Animation.Current(player) As String    — current anim name
        // Animation.IsPlaying(player) As Boolean
        // Animation.Length(player [, name]) As Double — anim length in sec
        auto resolve_anim = [&](const Variant &h) -> AnimationPlayer* {
            if (h.get_type() != Variant::OBJECT) return nullptr;
            Object *o = h;
            return Object::cast_to<AnimationPlayer>(o);
        };
        if (METHOD_IS("animation_play") && args.size() >= 2) {
            r_handled = true;
            AnimationPlayer *p = resolve_anim(args[0]);
            if (!p) return Variant();
            String name = args[1];
            double speed = (args.size() >= 3) ? (double)args[2] : 1.0;
            p->play(StringName(name), -1.0f, (float)speed, false);
            return Variant();
        }
        if (METHOD_IS("animation_stop") && args.size() >= 1) {
            r_handled = true;
            AnimationPlayer *p = resolve_anim(args[0]);
            if (!p) return Variant();
            bool keep = (args.size() >= 2) ? (bool)args[1] : false;
            p->stop(keep);
            return Variant();
        }
        if (METHOD_IS("animation_pause") && args.size() == 1) {
            r_handled = true;
            AnimationPlayer *p = resolve_anim(args[0]);
            if (p) p->pause();
            return Variant();
        }
        if (METHOD_IS("animation_resume") && args.size() == 1) {
            r_handled = true;
            AnimationPlayer *p = resolve_anim(args[0]);
            // Godot has no "resume"; replay current anim from its position.
            if (p) p->play(p->get_assigned_animation(), -1.0f, p->get_speed_scale(), false);
            return Variant();
        }
        if (METHOD_IS("animation_seek") && args.size() >= 2) {
            r_handled = true;
            AnimationPlayer *p = resolve_anim(args[0]);
            if (!p) return Variant();
            bool update = (args.size() >= 3) ? (bool)args[2] : true;
            p->seek((double)args[1], update);
            return Variant();
        }
        if (METHOD_IS("animation_speed") && args.size() == 2) {
            r_handled = true;
            AnimationPlayer *p = resolve_anim(args[0]);
            if (p) p->set_speed_scale((float)(double)args[1]);
            return Variant();
        }
        if (METHOD_IS("animation_current") && args.size() == 1) {
            r_handled = true;
            AnimationPlayer *p = resolve_anim(args[0]);
            return p ? String(p->get_current_animation()) : String();
        }
        if (METHOD_IS("animation_isplaying") && args.size() == 1) {
            r_handled = true;
            AnimationPlayer *p = resolve_anim(args[0]);
            return p ? p->is_playing() : false;
        }
        if (METHOD_IS("animation_length") && args.size() >= 1) {
            r_handled = true;
            AnimationPlayer *p = resolve_anim(args[0]);
            if (!p) return 0.0;
            String name = (args.size() >= 2) ? String(args[1]) : String(p->get_current_animation());
            if (name.is_empty()) return 0.0;
            Ref<Animation> a = p->get_animation(StringName(name));
            return a.is_valid() ? (double)a->get_length() : 0.0;
        }

        // ── Physics.* — one-shot space queries + force verbs ──────────
        //
        // Physics.Ray(from, to[, mask]) returns Dictionary:
        //   { Hit: Bool, Collider: Object, Point: V2/V3, Normal: V2/V3, Distance: Double }
        // The 2D/3D dimension is picked from the type of `from`.
        //
        // Physics.Impulse(body, vec[, pos])  Physics.Force(body, vec[, pos])
        // Physics.Torque(body, n)
        //
        // Verbs aliases (registered separately below as global verbs):
        //   Push(body, vec) = Impulse, Pull(body, vec) = Force, Spin(body, n) = Torque
        if (METHOD_IS("physics_ray") && args.size() >= 2) {
            r_handled = true;
            if (!instance || !instance->get_owner()) return Dictionary();
            Node *owner_node = Object::cast_to<Node>(instance->get_owner());
            if (!owner_node) return Dictionary();
            uint32_t mask = (args.size() >= 3) ? (uint32_t)(int)args[2] : 0xFFFFFFFFu;
            Dictionary out;

            if (args[0].get_type() == Variant::VECTOR2) {
                Viewport *vp = owner_node->get_viewport();
                if (!vp) { out["Hit"] = false; return out; }
                Ref<World2D> w = vp->find_world_2d();
                if (!w.is_valid()) { out["Hit"] = false; return out; }
                PhysicsDirectSpaceState2D *ss = PhysicsServer2D::get_singleton()->space_get_direct_state(w->get_space());
                if (!ss) { out["Hit"] = false; return out; }
                Ref<PhysicsRayQueryParameters2D> q;
                q.instantiate();
                q->set_from((Vector2)args[0]);
                q->set_to((Vector2)args[1]);
                q->set_collision_mask(mask);
                Dictionary r = ss->intersect_ray(q);
                if (r.is_empty()) { out["Hit"] = false; return out; }
                out["Hit"]      = true;
                out["Collider"] = r.get("collider", Variant());
                out["Point"]    = r.get("position", Variant());
                out["Normal"]   = r.get("normal", Variant());
                Vector2 from2 = args[0], pt2 = r.get("position", Vector2());
                out["Distance"] = (double)from2.distance_to(pt2);
                return out;
            }
            if (args[0].get_type() == Variant::VECTOR3) {
                Node3D *n3 = Object::cast_to<Node3D>(owner_node);
                // Need a Node3D context to fetch the 3D world; walk up if needed
                Node *n = owner_node;
                while (n && !n3) { n = n->get_parent(); n3 = Object::cast_to<Node3D>(n); }
                if (!n3) { out["Hit"] = false; return out; }
                Ref<World3D> w = n3->get_world_3d();
                if (!w.is_valid()) { out["Hit"] = false; return out; }
                PhysicsDirectSpaceState3D *ss = PhysicsServer3D::get_singleton()->space_get_direct_state(w->get_space());
                if (!ss) { out["Hit"] = false; return out; }
                Ref<PhysicsRayQueryParameters3D> q;
                q.instantiate();
                q->set_from((Vector3)args[0]);
                q->set_to((Vector3)args[1]);
                q->set_collision_mask(mask);
                Dictionary r = ss->intersect_ray(q);
                if (r.is_empty()) { out["Hit"] = false; return out; }
                out["Hit"]      = true;
                out["Collider"] = r.get("collider", Variant());
                out["Point"]    = r.get("position", Variant());
                out["Normal"]   = r.get("normal", Variant());
                Vector3 from3 = args[0], pt3 = r.get("position", Vector3());
                out["Distance"] = (double)from3.distance_to(pt3);
                return out;
            }
            out["Hit"] = false;
            return out;
        }
        // Shared force/impulse/torque dispatcher.
        auto apply_force = [&](Object *o, int kind, const Variant &amount, const Variant &pos_off) {
            // kind: 0=impulse, 1=force (central), 2=torque
            if (!o) return;
            if (o->is_class("RigidBody2D")) {
                RigidBody2D *b = Object::cast_to<RigidBody2D>(o);
                if (kind == 0) {
                    Vector2 imp = amount;
                    if (pos_off.get_type() == Variant::VECTOR2) b->apply_impulse(imp, (Vector2)pos_off);
                    else b->apply_central_impulse(imp);
                } else if (kind == 1) {
                    Vector2 f = amount;
                    if (pos_off.get_type() == Variant::VECTOR2) b->apply_force(f, (Vector2)pos_off);
                    else b->apply_central_force(f);
                } else if (kind == 2) {
                    b->apply_torque_impulse((double)amount);
                }
            } else if (o->is_class("RigidBody3D")) {
                RigidBody3D *b = Object::cast_to<RigidBody3D>(o);
                if (kind == 0) {
                    Vector3 imp = amount;
                    if (pos_off.get_type() == Variant::VECTOR3) b->apply_impulse(imp, (Vector3)pos_off);
                    else b->apply_central_impulse(imp);
                } else if (kind == 1) {
                    Vector3 f = amount;
                    if (pos_off.get_type() == Variant::VECTOR3) b->apply_force(f, (Vector3)pos_off);
                    else b->apply_central_force(f);
                } else if (kind == 2) {
                    b->apply_torque_impulse((Vector3)amount);
                }
            }
        };
        if (METHOD_IS("physics_impulse") && args.size() >= 2) {
            r_handled = true;
            apply_force(args[0], 0, args[1], (args.size() >= 3) ? args[2] : Variant());
            return Variant();
        }
        if (METHOD_IS("physics_force") && args.size() >= 2) {
            r_handled = true;
            apply_force(args[0], 1, args[1], (args.size() >= 3) ? args[2] : Variant());
            return Variant();
        }
        if (METHOD_IS("physics_torque") && args.size() == 2) {
            r_handled = true;
            apply_force(args[0], 2, args[1], Variant());
            return Variant();
        }

        // ── Ray.* — placed RayCast2D/3D node accessors ────────────────
        auto ray2 = [&](const Variant &h) -> RayCast2D* {
            return (h.get_type() == Variant::OBJECT) ? Object::cast_to<RayCast2D>((Object*)h) : nullptr;
        };
        auto ray3 = [&](const Variant &h) -> RayCast3D* {
            return (h.get_type() == Variant::OBJECT) ? Object::cast_to<RayCast3D>((Object*)h) : nullptr;
        };
        if (METHOD_IS("ray_hit") && args.size() == 1) {
            r_handled = true;
            RayCast2D *r2 = ray2(args[0]); if (r2) return r2->is_colliding();
            RayCast3D *r3 = ray3(args[0]); if (r3) return r3->is_colliding();
            return false;
        }
        if (METHOD_IS("ray_collider") && args.size() == 1) {
            r_handled = true;
            RayCast2D *r2 = ray2(args[0]); if (r2) return r2->get_collider();
            RayCast3D *r3 = ray3(args[0]); if (r3) return r3->get_collider();
            return Variant();
        }
        if (METHOD_IS("ray_point") && args.size() == 1) {
            r_handled = true;
            RayCast2D *r2 = ray2(args[0]); if (r2) return r2->get_collision_point();
            RayCast3D *r3 = ray3(args[0]); if (r3) return r3->get_collision_point();
            return Variant();
        }
        if (METHOD_IS("ray_normal") && args.size() == 1) {
            r_handled = true;
            RayCast2D *r2 = ray2(args[0]); if (r2) return r2->get_collision_normal();
            RayCast3D *r3 = ray3(args[0]); if (r3) return r3->get_collision_normal();
            return Variant();
        }
        if (METHOD_IS("ray_enable") && args.size() == 2) {
            r_handled = true;
            RayCast2D *r2 = ray2(args[0]); if (r2) { r2->set_enabled((bool)args[1]); return Variant(); }
            RayCast3D *r3 = ray3(args[0]); if (r3) { r3->set_enabled((bool)args[1]); }
            return Variant();
        }
        if (METHOD_IS("ray_target") && args.size() == 2) {
            r_handled = true;
            // Set target_position
            RayCast2D *r2 = ray2(args[0]); if (r2) { r2->set_target_position((Vector2)args[1]); return Variant(); }
            RayCast3D *r3 = ray3(args[0]); if (r3) { r3->set_target_position((Vector3)args[1]); }
            return Variant();
        }
        if (METHOD_IS("ray_forceupdate") && args.size() == 1) {
            r_handled = true;
            RayCast2D *r2 = ray2(args[0]); if (r2) { r2->force_raycast_update(); return Variant(); }
            RayCast3D *r3 = ray3(args[0]); if (r3) { r3->force_raycast_update(); }
            return Variant();
        }

        // ── Cell.* — TileMapLayer access (Godot 4.4+ split layer model) ─
        // Cell.Get(layer, x, y) As Dictionary {Source, AtlasX, AtlasY, Alt}
        //   (Empty cell → Source = -1)
        // Cell.Set(layer, x, y, source, atlasX, atlasY[, alt])
        // Cell.Clear(layer, x, y)
        // Cell.ClearAll(layer)
        // Cell.Used(layer) As Array of Vector2
        auto resolve_layer = [&](const Variant &h) -> TileMapLayer* {
            return (h.get_type() == Variant::OBJECT) ? Object::cast_to<TileMapLayer>((Object*)h) : nullptr;
        };
        if (METHOD_IS("cell_get") && args.size() == 3) {
            r_handled = true;
            TileMapLayer *lyr = resolve_layer(args[0]);
            Dictionary d;
            d["Source"] = -1; d["AtlasX"] = -1; d["AtlasY"] = -1; d["Alt"] = 0;
            if (!lyr) return d;
            Vector2i pos((int)args[1], (int)args[2]);
            int src = lyr->get_cell_source_id(pos);
            d["Source"] = src;
            Vector2i atlas = lyr->get_cell_atlas_coords(pos);
            d["AtlasX"] = atlas.x; d["AtlasY"] = atlas.y;
            d["Alt"] = lyr->get_cell_alternative_tile(pos);
            return d;
        }
        if (METHOD_IS("cell_set") && args.size() >= 6) {
            r_handled = true;
            TileMapLayer *lyr = resolve_layer(args[0]);
            if (!lyr) return Variant();
            Vector2i pos((int)args[1], (int)args[2]);
            int src = (int)args[3];
            Vector2i atlas((int)args[4], (int)args[5]);
            int alt = (args.size() >= 7) ? (int)args[6] : 0;
            lyr->set_cell(pos, src, atlas, alt);
            return Variant();
        }
        if (METHOD_IS("cell_clear") && args.size() == 3) {
            r_handled = true;
            TileMapLayer *lyr = resolve_layer(args[0]);
            if (lyr) lyr->set_cell(Vector2i((int)args[1], (int)args[2]), -1);
            return Variant();
        }
        if (METHOD_IS("cell_clearall") && args.size() == 1) {
            r_handled = true;
            TileMapLayer *lyr = resolve_layer(args[0]);
            if (lyr) lyr->clear();
            return Variant();
        }
        if (METHOD_IS("cell_used") && args.size() == 1) {
            r_handled = true;
            TileMapLayer *lyr = resolve_layer(args[0]);
            if (!lyr) return Array();
            TypedArray<Vector2i> used = lyr->get_used_cells();
            Array out;
            for (int i = 0; i < used.size(); i++) {
                Vector2i c = used[i];
                out.push_back(Vector2(c.x, c.y));
            }
            return out;
        }

        // ── Nav.* — NavigationAgent driving ────────────────────────────
        // Nav.SetTarget(agent, pos)         — sets target_position
        // Nav.NextPos(agent) As V2/V3       — next path step (call inside _Process)
        // Nav.Distance(agent) As Double     — meters to target
        // Nav.Reached(agent) As Boolean     — is_navigation_finished
        // Nav.Path(agent) As Array          — full path point list
        auto nav2 = [&](const Variant &h) -> NavigationAgent2D* {
            return (h.get_type() == Variant::OBJECT) ? Object::cast_to<NavigationAgent2D>((Object*)h) : nullptr;
        };
        auto nav3 = [&](const Variant &h) -> NavigationAgent3D* {
            return (h.get_type() == Variant::OBJECT) ? Object::cast_to<NavigationAgent3D>((Object*)h) : nullptr;
        };
        if (METHOD_IS("nav_settarget") && args.size() == 2) {
            r_handled = true;
            NavigationAgent2D *a2 = nav2(args[0]);
            if (a2) { a2->set_target_position((Vector2)args[1]); return Variant(); }
            NavigationAgent3D *a3 = nav3(args[0]);
            if (a3) a3->set_target_position((Vector3)args[1]);
            return Variant();
        }
        if (METHOD_IS("nav_nextpos") && args.size() == 1) {
            r_handled = true;
            NavigationAgent2D *a2 = nav2(args[0]); if (a2) return a2->get_next_path_position();
            NavigationAgent3D *a3 = nav3(args[0]); if (a3) return a3->get_next_path_position();
            return Variant();
        }
        if (METHOD_IS("nav_distance") && args.size() == 1) {
            r_handled = true;
            NavigationAgent2D *a2 = nav2(args[0]); if (a2) return (double)a2->distance_to_target();
            NavigationAgent3D *a3 = nav3(args[0]); if (a3) return (double)a3->distance_to_target();
            return 0.0;
        }
        if (METHOD_IS("nav_reached") && args.size() == 1) {
            r_handled = true;
            NavigationAgent2D *a2 = nav2(args[0]); if (a2) return a2->is_navigation_finished();
            NavigationAgent3D *a3 = nav3(args[0]); if (a3) return a3->is_navigation_finished();
            return true;
        }
        if (METHOD_IS("nav_path") && args.size() == 1) {
            r_handled = true;
            NavigationAgent2D *a2 = nav2(args[0]);
            if (a2) {
                PackedVector2Array path = a2->get_current_navigation_path();
                Array out;
                for (int i = 0; i < path.size(); i++) out.push_back(path[i]);
                return out;
            }
            NavigationAgent3D *a3 = nav3(args[0]);
            if (a3) {
                PackedVector3Array path = a3->get_current_navigation_path();
                Array out;
                for (int i = 0; i < path.size(); i++) out.push_back(path[i]);
                return out;
            }
            return Array();
        }
    }

    // ── Pass 3: global verb aliases for force ──────────────────────────
    // Push(body, vec[, pos]) = Physics.Impulse
    // Pull(body, vec[, pos]) = Physics.Force
    // Spin(body, n)          = Physics.Torque
    // Only match when the first argument is a physics Object, not an Array/Dict.
    if ((METHOD_IS("push") || METHOD_IS("pull") || METHOD_IS("spin")) && args.size() >= 2
            && args[0].get_type() == Variant::OBJECT) {
        r_handled = true;
        Object *o = args[0];
        // Inline force application (same dispatch as physics_*)
        int kind = METHOD_IS("push") ? 0 : (METHOD_IS("pull") ? 1 : 2);
        Variant pos_off = (args.size() >= 3) ? args[2] : Variant();
        if (o->is_class("RigidBody2D")) {
            RigidBody2D *b = Object::cast_to<RigidBody2D>(o);
            if (kind == 0) {
                Vector2 imp = args[1];
                if (pos_off.get_type() == Variant::VECTOR2) b->apply_impulse(imp, (Vector2)pos_off);
                else b->apply_central_impulse(imp);
            } else if (kind == 1) {
                Vector2 f = args[1];
                if (pos_off.get_type() == Variant::VECTOR2) b->apply_force(f, (Vector2)pos_off);
                else b->apply_central_force(f);
            } else {
                b->apply_torque_impulse((double)args[1]);
            }
        } else if (o->is_class("RigidBody3D")) {
            RigidBody3D *b = Object::cast_to<RigidBody3D>(o);
            if (kind == 0) {
                Vector3 imp = args[1];
                if (pos_off.get_type() == Variant::VECTOR3) b->apply_impulse(imp, (Vector3)pos_off);
                else b->apply_central_impulse(imp);
            } else if (kind == 1) {
                Vector3 f = args[1];
                if (pos_off.get_type() == Variant::VECTOR3) b->apply_force(f, (Vector3)pos_off);
                else b->apply_central_force(f);
            } else {
                b->apply_torque_impulse((Vector3)args[1]);
            }
        }
        return Variant();
    }

    // ── Pass 4: App platform / phone sensors ───────────────────────────
    //
    // Screen.*     — DisplayServer wrappers
    // Joypad.*     — gamepad polling
    // Sensor.*     — accel/gyro/magnet/gravity/tilt (Android/iOS automatic)
    // Permission.* — Android runtime permission API
    // Vibrate      — global verb
    // GPS.* / Steps.* — stubbed (return safe defaults; platform plugin
    //                  can publish real values via a future Variant API)
    {
        // Sensor units flag: false = "game" (Gs, deg/sec), true = "metric"
        // (m/s², rad/s). Default per user choice = "game".
        static bool s_sensor_metric = false;
        const double RAD2DEG = 57.29577951308232;
        const double G_TO_MS2 = 9.80665;

        // ── Screen.* ─────────────────────────────────────────────────
        if (METHOD_IS("screen_width")) {
            r_handled = true;
            DisplayServer *ds = DisplayServer::get_singleton();
            return ds ? (int64_t)ds->screen_get_size().x : (int64_t)0;
        }
        if (METHOD_IS("screen_height")) {
            r_handled = true;
            DisplayServer *ds = DisplayServer::get_singleton();
            return ds ? (int64_t)ds->screen_get_size().y : (int64_t)0;
        }
        if (METHOD_IS("screen_dpi")) {
            r_handled = true;
            DisplayServer *ds = DisplayServer::get_singleton();
            return ds ? (int64_t)ds->screen_get_dpi() : (int64_t)96;
        }
        if (METHOD_IS("screen_orientation")) {
            r_handled = true;
            DisplayServer *ds = DisplayServer::get_singleton();
            if (!ds) return String("landscape");
            // Returns "portrait" if height > width, else "landscape"
            Vector2i sz = ds->screen_get_size();
            return String(sz.y > sz.x ? "portrait" : "landscape");
        }
        if (METHOD_IS("screen_keepon") && args.size() == 1) {
            r_handled = true;
            DisplayServer *ds = DisplayServer::get_singleton();
            if (ds) ds->screen_set_keep_on((bool)args[0]);
            return Variant();
        }
        if (METHOD_IS("screen_fullscreen") && args.size() == 1) {
            r_handled = true;
            DisplayServer *ds = DisplayServer::get_singleton();
            if (ds) {
                DisplayServer::WindowMode m = (bool)args[0]
                    ? DisplayServer::WINDOW_MODE_FULLSCREEN
                    : DisplayServer::WINDOW_MODE_WINDOWED;
                ds->window_set_mode(m);
            }
            return Variant();
        }
        if (METHOD_IS("screen_isfullscreen")) {
            r_handled = true;
            DisplayServer *ds = DisplayServer::get_singleton();
            if (!ds) return false;
            DisplayServer::WindowMode m = ds->window_get_mode();
            return m == DisplayServer::WINDOW_MODE_FULLSCREEN ||
                   m == DisplayServer::WINDOW_MODE_EXCLUSIVE_FULLSCREEN;
        }

        // ── Joypad.* ─────────────────────────────────────────────────
        // Joypad.Connected(device) As Boolean
        // Joypad.Name(device) As String
        // Joypad.Axis(device, axisIndex) As Double  (-1.0..1.0)
        // Joypad.Button(device, buttonIndex) As Boolean
        if (METHOD_IS("joypad_connected") && args.size() == 1) {
            r_handled = true;
            Input *in = Input::get_singleton();
            return in ? in->is_joy_known((int)args[0]) : false;
        }
        if (METHOD_IS("joypad_name") && args.size() == 1) {
            r_handled = true;
            Input *in = Input::get_singleton();
            return in ? in->get_joy_name((int)args[0]) : String();
        }
        if (METHOD_IS("joypad_axis") && args.size() == 2) {
            r_handled = true;
            Input *in = Input::get_singleton();
            if (!in) return 0.0;
            return (double)in->get_joy_axis((int)args[0], (JoyAxis)(int)args[1]);
        }
        if (METHOD_IS("joypad_button") && args.size() == 2) {
            r_handled = true;
            Input *in = Input::get_singleton();
            if (!in) return false;
            return in->is_joy_button_pressed((int)args[0], (JoyButton)(int)args[1]);
        }

        // ── Sensor.* ─────────────────────────────────────────────────
        // Sensor.Units("game"|"metric") — set unit system for following reads
        // Sensor.Accel() As Vector3   — Gs or m/s²
        // Sensor.Gyro() As Vector3    — deg/sec or rad/sec
        // Sensor.Magnet() As Vector3  — µT (always)
        // Sensor.Gravity() As Vector3 — Gs or m/s² (gravity-only component)
        // Sensor.Tilt() As Double     — degrees from upright (0 = flat phone)
        if (METHOD_IS("sensor_units") && args.size() == 1) {
            r_handled = true;
            String u = String(args[0]).to_lower();
            s_sensor_metric = (u == "metric");
            return Variant();
        }
        if (METHOD_IS("sensor_accel")) {
            r_handled = true;
            Input *in = Input::get_singleton();
            if (!in) return Vector3();
            Vector3 v = in->get_accelerometer();
            if (!s_sensor_metric) v /= (float)G_TO_MS2;
            return v;
        }
        if (METHOD_IS("sensor_gyro")) {
            r_handled = true;
            Input *in = Input::get_singleton();
            if (!in) return Vector3();
            Vector3 v = in->get_gyroscope();
            if (!s_sensor_metric) v *= (float)RAD2DEG;
            return v;
        }
        if (METHOD_IS("sensor_magnet")) {
            r_handled = true;
            Input *in = Input::get_singleton();
            return in ? in->get_magnetometer() : Vector3();
        }
        if (METHOD_IS("sensor_gravity")) {
            r_handled = true;
            Input *in = Input::get_singleton();
            if (!in) return Vector3();
            Vector3 v = in->get_gravity();
            if (!s_sensor_metric) v /= (float)G_TO_MS2;
            return v;
        }
        if (METHOD_IS("sensor_tilt")) {
            r_handled = true;
            Input *in = Input::get_singleton();
            if (!in) return 0.0;
            Vector3 a = in->get_accelerometer();
            // Tilt = angle between -Y (upright) and accel vector projected on Y-Z.
            // Use atan2(x, -y) for phone "tilt around vertical" feel.
            return (double)Math::atan2(a.x, -a.y) * RAD2DEG;
        }

        // ── Permission.* ─────────────────────────────────────────────
        // Permission.Has("camera") As Boolean
        // Permission.Request("camera")           — fires-and-forgets; the
        //                                         OS resolves async and we
        //                                         dispatch Permission_Granted
        //                                         / Permission_Denied subs.
        // Permission.All() As Array              — currently granted list
        //
        // Common names: "camera", "microphone", "location", "storage",
        //               "android.permission.ACCESS_FINE_LOCATION", etc.
        if (METHOD_IS("permission_has") && args.size() == 1) {
            r_handled = true;
            OS *os = OS::get_singleton();
            if (!os) return false;
            String name = args[0];
            PackedStringArray granted = os->get_granted_permissions();
            // Accept short forms.
            String full = name;
            if (!full.begins_with("android.permission.")) {
                if (name == "camera") full = "android.permission.CAMERA";
                else if (name == "microphone") full = "android.permission.RECORD_AUDIO";
                else if (name == "location") full = "android.permission.ACCESS_FINE_LOCATION";
                else if (name == "storage") full = "android.permission.READ_EXTERNAL_STORAGE";
            }
            for (int i = 0; i < granted.size(); i++) {
                if (granted[i] == name || granted[i] == full) return true;
            }
            // Desktop: no permission model → return True so user code runs.
            String pn = os->get_name();
            if (pn != "Android" && pn != "iOS") return true;
            return false;
        }
        if (METHOD_IS("permission_request") && args.size() == 1) {
            r_handled = true;
            OS *os = OS::get_singleton();
            if (!os) return false;
            String name = args[0];
            String full = name;
            if (!full.begins_with("android.permission.")) {
                if (name == "camera") full = "android.permission.CAMERA";
                else if (name == "microphone") full = "android.permission.RECORD_AUDIO";
                else if (name == "location") full = "android.permission.ACCESS_FINE_LOCATION";
                else if (name == "storage") full = "android.permission.READ_EXTERNAL_STORAGE";
            }
            // request_permission returns immediately; outcome dispatched async
            // via OS's on_request_permissions_result signal in Godot. The user's
            // Sub Permission_Granted(name) / Permission_Denied(name) get called
            // via the auto-wire when that signal fires (wired below).
            //
            // On Android we prefer the VGAndroidPlugin path — its
            // permission_granted / permission_denied signals carry the
            // permission name as a String argument (Godot's OS signal does
            // not in 4.6 GDExtension).
            Engine *eng = Engine::get_singleton();
            if (eng && eng->has_singleton("VGAndroidPlugin")) {
                Object *p = eng->get_singleton("VGAndroidPlugin");
                if (p) {
                    p->call("requestPermission", name);
                    return true;
                }
            }
            return os->request_permission(full);
        }
        if (METHOD_IS("permission_all")) {
            r_handled = true;
            OS *os = OS::get_singleton();
            if (!os) return Array();
            PackedStringArray g = os->get_granted_permissions();
            Array a;
            for (int i = 0; i < g.size(); i++) a.push_back(g[i]);
            return a;
        }

        // ── Vibrate verb (global) ─────────────────────────────────────
        // Vibrate ms                 — short buzz, default amplitude
        // Vibrate ms, amplitude      — 0.0..1.0
        if (METHOD_IS("vibrate") && args.size() >= 1) {
            r_handled = true;
            Input *in = Input::get_singleton();
            if (!in) return Variant();
            int ms = (int)args[0];
            float amp = (args.size() >= 2) ? (float)(double)args[1] : -1.0f;
            in->vibrate_handheld(ms, amp);
            return Variant();
        }

        // ── GPS.* / Steps.* — routed through Android plugin singleton ──
        // On Android the bundled VGAndroidPlugin (addons/visual_gasic_android)
        // registers a Godot singleton named "VGAndroidPlugin" exposing
        // getLat / getLng / getAlt / getSpeed / getAccuracy /
        // getStepsToday / getStepsTotal / resetSteps + startGps / startSteps.
        // On every other platform Engine::has_singleton("VGAndroidPlugin")
        // returns false and we fall through to the safe zero/-1 stubs.
        auto _vg_android = []() -> Object* {
            Engine *eng = Engine::get_singleton();
            if (!eng) return nullptr;
            if (!eng->has_singleton("VGAndroidPlugin")) return nullptr;
            return eng->get_singleton("VGAndroidPlugin");
        };
        if (METHOD_IS("gps_lat")) {
            r_handled = true;
            Object *p = _vg_android();
            if (p) { p->call("startGps"); return (double)p->call("getLat"); }
            return 0.0;
        }
        if (METHOD_IS("gps_lng")) {
            r_handled = true;
            Object *p = _vg_android();
            if (p) { p->call("startGps"); return (double)p->call("getLng"); }
            return 0.0;
        }
        if (METHOD_IS("gps_alt")) {
            r_handled = true;
            Object *p = _vg_android();
            if (p) { p->call("startGps"); return (double)p->call("getAlt"); }
            return 0.0;
        }
        if (METHOD_IS("gps_speed")) {
            r_handled = true;
            Object *p = _vg_android();
            if (p) { p->call("startGps"); return (double)p->call("getSpeed"); }
            return 0.0;
        }
        if (METHOD_IS("gps_accuracy")) {
            r_handled = true;
            Object *p = _vg_android();
            if (p) { p->call("startGps"); return (double)p->call("getAccuracy"); }
            return -1.0; // negative = unknown
        }
        if (METHOD_IS("steps_total")) {
            r_handled = true;
            Object *p = _vg_android();
            if (p) { p->call("startSteps"); return (int64_t)(int)p->call("getStepsTotal"); }
            return (int64_t)0;
        }
        if (METHOD_IS("steps_today")) {
            r_handled = true;
            Object *p = _vg_android();
            if (p) { p->call("startSteps"); return (int64_t)(int)p->call("getStepsToday"); }
            return (int64_t)0;
        }
        if (METHOD_IS("steps_reset")) {
            r_handled = true;
            Object *p = _vg_android();
            if (p) p->call("resetSteps");
            return Variant();
        }
    }

    // ── Pass 5: pro features ────────────────────────────────────────────
    //
    // Crypto.*   — hashing, HMAC, random bytes, base64 (+ global aliases)
    // Theme.*    — Control theme overrides
    // JS.*       — JavaScript bridge for HTML5 export
    // Shader.*   — ShaderMaterial parameter access
    // Material.* — create ShaderMaterial from shader code
    // Skeleton.* — Skeleton3D bone access
    // Bone.*     — per-bone pose helpers
    // Video.*    — VideoStreamPlayer control
    {
        // Helper: PackedByteArray → lowercase hex string
        auto bytes_to_hex = [](const PackedByteArray &b) -> String {
            String out;
            const uint8_t *p = b.ptr();
            for (int i = 0; i < b.size(); i++) {
                static const char *h = "0123456789abcdef";
                char buf[3] = { h[(p[i] >> 4) & 0xF], h[p[i] & 0xF], 0 };
                out += String(buf);
            }
            return out;
        };
        // Helper: any Variant → PackedByteArray (String→utf8, ByteArray→pass)
        auto to_bytes = [](const Variant &v) -> PackedByteArray {
            if (v.get_type() == Variant::PACKED_BYTE_ARRAY) return v;
            String s = v;
            return s.to_utf8_buffer();
        };
        auto hash_with = [&](HashingContext::HashType t, const Variant &input) -> String {
            Ref<HashingContext> hc;
            hc.instantiate();
            hc->start(t);
            hc->update(to_bytes(input));
            return bytes_to_hex(hc->finish());
        };

        // ── Crypto.* + global verb aliases ─────────────────────────────
        if (METHOD_IS("crypto_sha256") || METHOD_IS("sha256")) {
            r_handled = true;
            if (args.size() < 1) return String();
            return hash_with(HashingContext::HASH_SHA256, args[0]);
        }
        if (METHOD_IS("crypto_sha1") || METHOD_IS("sha1")) {
            r_handled = true;
            if (args.size() < 1) return String();
            return hash_with(HashingContext::HASH_SHA1, args[0]);
        }
        if (METHOD_IS("crypto_md5") || METHOD_IS("md5")) {
            r_handled = true;
            if (args.size() < 1) return String();
            return hash_with(HashingContext::HASH_MD5, args[0]);
        }
        if (METHOD_IS("crypto_hmac") && args.size() >= 2) {
            r_handled = true;
            // Crypto.HMAC(key, msg [, "sha256"|"sha1"])
            Ref<Crypto> c;
            c.instantiate();
            HashingContext::HashType t = HashingContext::HASH_SHA256;
            if (args.size() >= 3) {
                String alg = String(args[2]).to_lower();
                if (alg == "sha1") t = HashingContext::HASH_SHA1;
                else if (alg == "md5") t = HashingContext::HASH_MD5;
            }
            PackedByteArray sig = c->hmac_digest(t, to_bytes(args[0]), to_bytes(args[1]));
            return bytes_to_hex(sig);
        }
        if (METHOD_IS("crypto_randombytes") || METHOD_IS("randombytes")) {
            r_handled = true;
            int n = (args.size() >= 1) ? (int)args[0] : 16;
            Ref<Crypto> c;
            c.instantiate();
            return c->generate_random_bytes(n);
        }
        if (METHOD_IS("crypto_base64encode") || METHOD_IS("base64encode")) {
            r_handled = true;
            if (args.size() < 1) return String();
            Marshalls *m = Marshalls::get_singleton();
            if (!m) return String();
            if (args[0].get_type() == Variant::PACKED_BYTE_ARRAY) {
                return m->raw_to_base64(args[0]);
            }
            return m->utf8_to_base64(String(args[0]));
        }
        if (METHOD_IS("crypto_base64decode") || METHOD_IS("base64decode")) {
            r_handled = true;
            if (args.size() < 1) return String();
            Marshalls *m = Marshalls::get_singleton();
            if (!m) return String();
            // Default: decode to UTF-8 string. Pass True as 2nd arg for raw bytes.
            bool raw = (args.size() >= 2) ? (bool)args[1] : false;
            if (raw) return m->base64_to_raw(String(args[0]));
            return m->base64_to_utf8(String(args[0]));
        }

        // ── Theme.* — Control theme overrides ──────────────────────────
        auto as_control = [&](const Variant &h) -> Control* {
            return (h.get_type() == Variant::OBJECT) ? Object::cast_to<Control>((Object*)h) : nullptr;
        };
        if (METHOD_IS("theme_color") && args.size() == 2) {
            r_handled = true;
            Control *c = as_control(args[0]);
            return c ? c->get_theme_color(StringName(String(args[1]))) : Color();
        }
        if (METHOD_IS("theme_font") && args.size() == 2) {
            r_handled = true;
            Control *c = as_control(args[0]);
            return c ? Variant(c->get_theme_font(StringName(String(args[1])))) : Variant();
        }
        if (METHOD_IS("theme_constant") && args.size() == 2) {
            r_handled = true;
            Control *c = as_control(args[0]);
            return c ? (int64_t)c->get_theme_constant(StringName(String(args[1]))) : (int64_t)0;
        }
        if (METHOD_IS("theme_setcolor") && args.size() == 3) {
            r_handled = true;
            Control *c = as_control(args[0]);
            if (c) c->add_theme_color_override(StringName(String(args[1])), (Color)args[2]);
            return Variant();
        }
        if (METHOD_IS("theme_setfont") && args.size() == 3) {
            r_handled = true;
            Control *c = as_control(args[0]);
            if (c && args[2].get_type() == Variant::OBJECT) {
                Ref<Font> f = Object::cast_to<Font>((Object*)args[2]);
                if (f.is_valid()) c->add_theme_font_override(StringName(String(args[1])), f);
            }
            return Variant();
        }
        if (METHOD_IS("theme_setconstant") && args.size() == 3) {
            r_handled = true;
            Control *c = as_control(args[0]);
            if (c) c->add_theme_constant_override(StringName(String(args[1])), (int)args[2]);
            return Variant();
        }
        if (METHOD_IS("theme_setstyle") && args.size() == 3) {
            r_handled = true;
            Control *c = as_control(args[0]);
            if (c && args[2].get_type() == Variant::OBJECT) {
                Ref<StyleBox> s = Object::cast_to<StyleBox>((Object*)args[2]);
                if (s.is_valid()) c->add_theme_stylebox_override(StringName(String(args[1])), s);
            }
            return Variant();
        }
        if (METHOD_IS("theme_setfontsize") && args.size() == 3) {
            r_handled = true;
            Control *c = as_control(args[0]);
            if (c) c->add_theme_font_size_override(StringName(String(args[1])), (int)args[2]);
            return Variant();
        }

        // ── JS.* — JavaScriptBridge (HTML5 export only) ────────────────
        // On native platforms returns Variant() / empty string.
        if (METHOD_IS("js_eval") && args.size() >= 1) {
            r_handled = true;
            JavaScriptBridge *js = JavaScriptBridge::get_singleton();
            if (!js) return Variant();
            bool use_global = (args.size() >= 2) ? (bool)args[1] : false;
            return js->eval(String(args[0]), use_global);
        }
        if (METHOD_IS("js_call") && args.size() >= 1) {
            r_handled = true;
            JavaScriptBridge *js = JavaScriptBridge::get_singleton();
            if (!js) return Variant();
            // Build "funcName(JSON.parse('a'), JSON.parse('b'), ...)" call
            String fn = args[0];
            String code = fn + "(";
            for (int i = 1; i < args.size(); i++) {
                if (i > 1) code += ",";
                Variant v = args[i];
                if (v.get_type() == Variant::STRING) {
                    String s = v;
                    code += "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
                } else {
                    code += String(v);
                }
            }
            code += ")";
            return js->eval(code, true);
        }
        if (METHOD_IS("js_get") && args.size() == 1) {
            r_handled = true;
            JavaScriptBridge *js = JavaScriptBridge::get_singleton();
            if (!js) return Variant();
            return js->eval(String(args[0]), true);
        }

        // ── Shader.* / Material.* ──────────────────────────────────────
        auto as_shader_mat = [&](const Variant &h) -> Ref<ShaderMaterial> {
            Ref<ShaderMaterial> m;
            if (h.get_type() == Variant::OBJECT) {
                ShaderMaterial *sm = Object::cast_to<ShaderMaterial>((Object*)h);
                if (sm) m = Ref<ShaderMaterial>(sm);
            }
            return m;
        };
        if (METHOD_IS("shader_param") && args.size() == 3) {
            r_handled = true;
            Ref<ShaderMaterial> m = as_shader_mat(args[0]);
            if (m.is_valid()) m->set_shader_parameter(StringName(String(args[1])), args[2]);
            return Variant();
        }
        if (METHOD_IS("shader_getparam") && args.size() == 2) {
            r_handled = true;
            Ref<ShaderMaterial> m = as_shader_mat(args[0]);
            return m.is_valid() ? m->get_shader_parameter(StringName(String(args[1]))) : Variant();
        }
        if (METHOD_IS("material_new") && args.size() == 1) {
            r_handled = true;
            // Material.New("shader_code") → ShaderMaterial
            Ref<Shader> s; s.instantiate();
            s->set_code(String(args[0]));
            Ref<ShaderMaterial> m; m.instantiate();
            m->set_shader(s);
            return Variant(m);
        }
        if (METHOD_IS("material_setshader") && args.size() == 2) {
            r_handled = true;
            Ref<ShaderMaterial> m = as_shader_mat(args[0]);
            if (m.is_valid() && args[1].get_type() == Variant::OBJECT) {
                Ref<Shader> s = Object::cast_to<Shader>((Object*)args[1]);
                if (s.is_valid()) m->set_shader(s);
            }
            return Variant();
        }

        // ── Skeleton.* / Bone.* — Skeleton3D access ────────────────────
        auto as_skel = [&](const Variant &h) -> Skeleton3D* {
            return (h.get_type() == Variant::OBJECT) ? Object::cast_to<Skeleton3D>((Object*)h) : nullptr;
        };
        if (METHOD_IS("skeleton_count") && args.size() == 1) {
            r_handled = true;
            Skeleton3D *s = as_skel(args[0]);
            return s ? (int64_t)s->get_bone_count() : (int64_t)0;
        }
        if (METHOD_IS("skeleton_name") && args.size() == 2) {
            r_handled = true;
            Skeleton3D *s = as_skel(args[0]);
            return s ? s->get_bone_name((int)args[1]) : String();
        }
        if (METHOD_IS("skeleton_reset") && args.size() == 1) {
            r_handled = true;
            Skeleton3D *s = as_skel(args[0]);
            if (s) s->reset_bone_poses();
            return Variant();
        }
        if (METHOD_IS("bone_find") && args.size() == 2) {
            r_handled = true;
            Skeleton3D *s = as_skel(args[0]);
            return s ? (int64_t)s->find_bone(String(args[1])) : (int64_t)-1;
        }
        if (METHOD_IS("bone_pos") && args.size() == 2) {
            r_handled = true;
            Skeleton3D *s = as_skel(args[0]);
            return s ? s->get_bone_pose_position((int)args[1]) : Vector3();
        }
        if (METHOD_IS("bone_rot") && args.size() == 2) {
            r_handled = true;
            Skeleton3D *s = as_skel(args[0]);
            return s ? s->get_bone_pose_rotation((int)args[1]) : Quaternion();
        }
        if (METHOD_IS("bone_scale") && args.size() == 2) {
            r_handled = true;
            Skeleton3D *s = as_skel(args[0]);
            return s ? s->get_bone_pose_scale((int)args[1]) : Vector3(1, 1, 1);
        }
        if (METHOD_IS("bone_setpos") && args.size() == 3) {
            r_handled = true;
            Skeleton3D *s = as_skel(args[0]);
            if (s) s->set_bone_pose_position((int)args[1], (Vector3)args[2]);
            return Variant();
        }
        if (METHOD_IS("bone_setrot") && args.size() == 3) {
            r_handled = true;
            Skeleton3D *s = as_skel(args[0]);
            if (s) s->set_bone_pose_rotation((int)args[1], (Quaternion)args[2]);
            return Variant();
        }
        if (METHOD_IS("bone_setscale") && args.size() == 3) {
            r_handled = true;
            Skeleton3D *s = as_skel(args[0]);
            if (s) s->set_bone_pose_scale((int)args[1], (Vector3)args[2]);
            return Variant();
        }
        if (METHOD_IS("bone_lookat") && args.size() == 3) {
            r_handled = true;
            // Bone.LookAt(skel, idx, targetPos) — points the bone's +Y at target.
            // Simplified: compute world-space direction in the skeleton's local
            // frame and apply as a pose rotation.
            Skeleton3D *s = as_skel(args[0]);
            if (!s) return Variant();
            int idx = (int)args[1];
            Vector3 target = args[2];
            Vector3 here = s->get_bone_global_pose(idx).origin;
            Vector3 dir = (target - here).normalized();
            if (dir.length_squared() < 1e-8f) return Variant();
            // Quat that rotates +Y to dir
            Vector3 up(0, 1, 0);
            float dot = up.dot(dir);
            Quaternion q;
            if (dot > 0.99999f) {
                q = Quaternion();
            } else if (dot < -0.99999f) {
                q = Quaternion(Vector3(1, 0, 0), Math_PI);
            } else {
                Vector3 axis = up.cross(dir).normalized();
                float angle = Math::acos(dot);
                q = Quaternion(axis, angle);
            }
            s->set_bone_pose_rotation(idx, q);
            return Variant();
        }

        // ── Video.* — VideoStreamPlayer control ────────────────────────
        auto as_vid = [&](const Variant &h) -> VideoStreamPlayer* {
            return (h.get_type() == Variant::OBJECT) ? Object::cast_to<VideoStreamPlayer>((Object*)h) : nullptr;
        };
        if (METHOD_IS("video_play") && args.size() == 1) {
            r_handled = true;
            VideoStreamPlayer *v = as_vid(args[0]);
            if (v) v->play();
            return Variant();
        }
        if (METHOD_IS("video_stop") && args.size() == 1) {
            r_handled = true;
            VideoStreamPlayer *v = as_vid(args[0]);
            if (v) v->stop();
            return Variant();
        }
        if (METHOD_IS("video_pause") && args.size() == 1) {
            r_handled = true;
            VideoStreamPlayer *v = as_vid(args[0]);
            if (v) v->set_paused(true);
            return Variant();
        }
        if (METHOD_IS("video_resume") && args.size() == 1) {
            r_handled = true;
            VideoStreamPlayer *v = as_vid(args[0]);
            if (v) v->set_paused(false);
            return Variant();
        }
        if (METHOD_IS("video_seek") && args.size() == 2) {
            r_handled = true;
            VideoStreamPlayer *v = as_vid(args[0]);
            if (v) v->set_stream_position((double)args[1]);
            return Variant();
        }
        if (METHOD_IS("video_position") && args.size() == 1) {
            r_handled = true;
            VideoStreamPlayer *v = as_vid(args[0]);
            return v ? (double)v->get_stream_position() : 0.0;
        }
        if (METHOD_IS("video_length") && args.size() == 1) {
            r_handled = true;
            VideoStreamPlayer *v = as_vid(args[0]);
            // VideoStream has no public length API in 4.x; return 0 if unknown.
            return v ? (double)v->get_stream_length() : 0.0;
        }
        if (METHOD_IS("video_isplaying") && args.size() == 1) {
            r_handled = true;
            VideoStreamPlayer *v = as_vid(args[0]);
            return v ? v->is_playing() : false;
        }
        if (METHOD_IS("video_volume") && args.size() == 2) {
            r_handled = true;
            VideoStreamPlayer *v = as_vid(args[0]);
            if (v) {
                // pct (0..100) → dB
                double pct = (double)args[1];
                double db = (pct <= 0.0) ? -80.0 : 20.0 * Math::log(pct / 100.0) / Math::log(10.0);
                v->set_volume_db((float)db);
            }
            return Variant();
        }

        // ── Pass 6 gap-fillers (aspirational verbs surfaced May 11 2026) ──
        // Camera.PanTo(pos, time[, h]) — tween Camera2D.position to `pos`.
        //   pos: Vector2 or Vector3 (matches resolve_camera kind).
        if (METHOD_IS("camera_panto") && args.size() >= 2) {
            r_handled = true;
            Variant override_h = (args.size() >= 3) ? args[args.size() - 1] : Variant();
            Object *cam = nullptr;
            // Inline camera resolve (resolve_camera is in another scope).
            if (override_h.get_type() == Variant::OBJECT) {
                Object *o = override_h;
                if (o && (o->is_class("Camera2D") || o->is_class("Camera3D"))) cam = o;
            }
            if (!cam && instance && instance->get_owner()) {
                Node *n = Object::cast_to<Node>(instance->get_owner());
                if (n && n->get_tree() && n->get_tree()->get_root()) {
                    Viewport *vp = n->get_tree()->get_root();
                    Camera3D *c3 = vp->get_camera_3d();
                    if (c3) cam = c3;
                    else cam = vp->get_camera_2d();
                }
            }
            Node *cn = Object::cast_to<Node>(cam);
            if (!cn) return Variant();
            double dur = (double)args[1];
            Ref<Tween> tw = cn->create_tween();
            if (tw.is_valid()) tw->tween_property(cn, "position", args[0], dur);
            return Variant();
        }
        // Camera.Bounce(amount[, h]) — quick vertical bounce on camera offset.
        if (METHOD_IS("camera_bounce") && args.size() >= 1) {
            r_handled = true;
            Variant override_h = (args.size() >= 2) ? args[args.size() - 1] : Variant();
            Object *cam = nullptr;
            if (override_h.get_type() == Variant::OBJECT) {
                Object *o = override_h;
                if (o && (o->is_class("Camera2D") || o->is_class("Camera3D"))) cam = o;
            }
            if (!cam && instance && instance->get_owner()) {
                Node *n = Object::cast_to<Node>(instance->get_owner());
                if (n && n->get_tree() && n->get_tree()->get_root()) {
                    Viewport *vp = n->get_tree()->get_root();
                    Camera3D *c3 = vp->get_camera_3d();
                    if (c3) cam = c3;
                    else cam = vp->get_camera_2d();
                }
            }
            Node *cn = Object::cast_to<Node>(cam);
            if (!cn) return Variant();
            double amt = (double)args[0];
            Ref<Tween> tw = cn->create_tween();
            if (tw.is_valid()) {
                tw->tween_property(cn, "offset", Vector2(0.0, amt), 0.08);
                tw->tween_property(cn, "offset", Vector2(0.0, 0.0), 0.12);
            }
            return Variant();
        }
        // Camera.FlashColor(color[, duration]) — fade a fullscreen ColorRect.
        // Duration defaults to 0.25s. Removes itself on tween finish.
        if (METHOD_IS("camera_flashcolor") && args.size() >= 1) {
            r_handled = true;
            if (!instance || !instance->get_owner()) return Variant();
            Node *owner_node = Object::cast_to<Node>(instance->get_owner());
            if (!owner_node) return Variant();
            Color col = (args[0].get_type() == Variant::COLOR) ? (Color)args[0] : Color(1, 1, 1, 1);
            double dur = (args.size() >= 2) ? (double)args[1] : 0.25;
            CanvasLayer *cl = memnew(CanvasLayer);
            cl->set_layer(1024); // top
            ColorRect *cr = memnew(ColorRect);
            cr->set_color(col);
            cr->set_anchors_preset(Control::PRESET_FULL_RECT);
            cr->set_mouse_filter(Control::MOUSE_FILTER_IGNORE);
            cl->add_child(cr);
            owner_node->add_child(cl);
            Ref<Tween> tw = cr->create_tween();
            if (tw.is_valid()) {
                tw->tween_property(cr, "modulate:a", 0.0, dur);
                tw->tween_callback(Callable(cl, "queue_free"));
            } else {
                cl->queue_free();
            }
            return Variant();
        }

        // Crypto.Hex(s) / Crypto.FromHex(s) — string ↔ hex round-trip.
        if (METHOD_IS("crypto_hex") && args.size() >= 1) {
            r_handled = true;
            String s = args[0];
            PackedByteArray b = s.to_utf8_buffer();
            String out;
            const char *hex = "0123456789abcdef";
            for (int i = 0; i < b.size(); i++) {
                uint8_t v = b[i];
                out += String::chr(hex[(v >> 4) & 0xF]);
                out += String::chr(hex[v & 0xF]);
            }
            return out;
        }
        if (METHOD_IS("crypto_fromhex") && args.size() >= 1) {
            r_handled = true;
            String s = String(args[0]).to_lower();
            PackedByteArray b;
            for (int i = 0; i + 1 < s.length(); i += 2) {
                char32_t hi = s[i], lo = s[i + 1];
                auto nib = [](char32_t c) -> int {
                    if (c >= '0' && c <= '9') return (int)(c - '0');
                    if (c >= 'a' && c <= 'f') return 10 + (int)(c - 'a');
                    return -1;
                };
                int h = nib(hi), l = nib(lo);
                if (h < 0 || l < 0) continue;
                b.push_back((uint8_t)((h << 4) | l));
            }
            return String::utf8((const char *)b.ptr(), b.size());
        }
        // Crypto.Base64(s) — short alias for Crypto.Base64Encode(s).
        if (METHOD_IS("crypto_base64") && args.size() >= 1) {
            r_handled = true;
            Marshalls *m = Marshalls::get_singleton();
            if (!m) return String();
            if (args[0].get_type() == Variant::PACKED_BYTE_ARRAY) {
                return m->raw_to_base64(args[0]);
            }
            return m->utf8_to_base64(String(args[0]));
        }

        // Physics.Gravity(vec) — set global gravity vector + magnitude.
        //   Vector2 → 2D ProjectSettings; Vector3 → 3D ProjectSettings.
        // Physics.Bounce(value) — set global default bounce on world boundary.
        //   Value 0.0..1.0; sets PhysicsMaterial restitution on a runtime-
        //   reachable default material (best-effort; persistent set via
        //   ProjectSettings would require a reload).
        if (METHOD_IS("physics_gravity") && args.size() >= 1) {
            r_handled = true;
            ProjectSettings *ps = ProjectSettings::get_singleton();
            if (!ps) return Variant();
            if (args[0].get_type() == Variant::VECTOR2) {
                Vector2 g = args[0];
                double mag = g.length();
                Vector2 dir = (mag > 0.0) ? (g / mag) : Vector2(0, 1);
                ps->set_setting("physics/2d/default_gravity_vector", dir);
                ps->set_setting("physics/2d/default_gravity", mag);
            } else if (args[0].get_type() == Variant::VECTOR3) {
                Vector3 g = args[0];
                double mag = g.length();
                Vector3 dir = (mag > 0.0) ? (g / mag) : Vector3(0, -1, 0);
                ps->set_setting("physics/3d/default_gravity_vector", dir);
                ps->set_setting("physics/3d/default_gravity", mag);
            }
            return Variant();
        }
        if (METHOD_IS("physics_bounce") && args.size() >= 1) {
            r_handled = true;
            ProjectSettings *ps = ProjectSettings::get_singleton();
            if (!ps) return Variant();
            double b = CLAMP((double)args[0], 0.0, 1.0);
            // No global Godot "default bounce" setting — store it in a
            // VG-private key so user code can introspect.  Per-body
            // PhysicsMaterial is still the supported mechanism.
            ps->set_setting("visual_gasic/physics/default_bounce", b);
            return Variant();
        }

        // Ray.Cast2D(from2, to2[, mask]) / Ray.Cast3D(from3, to3[, mask]) —
        // one-shot raycast that returns the same Dictionary shape as
        // Physics.Ray.  Reuses physics_ray's machinery by re-dispatching.
        if ((METHOD_IS("ray_cast2d") || METHOD_IS("ray_cast3d")) && args.size() >= 2) {
            r_handled = true;
            if (!instance || !instance->get_owner()) return Dictionary();
            Node *owner_node = Object::cast_to<Node>(instance->get_owner());
            if (!owner_node) return Dictionary();
            uint32_t mask = (args.size() >= 3) ? (uint32_t)(int)args[2] : 0xFFFFFFFFu;
            Dictionary out;
            bool is_2d = METHOD_IS("ray_cast2d");
            if (is_2d) {
                Viewport *vp = owner_node->get_viewport();
                if (!vp) { out["Hit"] = false; return out; }
                Ref<World2D> w = vp->find_world_2d();
                if (!w.is_valid()) { out["Hit"] = false; return out; }
                PhysicsDirectSpaceState2D *ss = PhysicsServer2D::get_singleton()->space_get_direct_state(w->get_space());
                if (!ss) { out["Hit"] = false; return out; }
                Ref<PhysicsRayQueryParameters2D> q; q.instantiate();
                q->set_from((Vector2)args[0]);
                q->set_to((Vector2)args[1]);
                q->set_collision_mask(mask);
                Dictionary r = ss->intersect_ray(q);
                if (r.is_empty()) { out["Hit"] = false; return out; }
                out["Hit"]      = true;
                out["Collider"] = r.get("collider", Variant());
                out["Point"]    = r.get("position", Variant());
                out["Normal"]   = r.get("normal", Variant());
                Vector2 from2 = args[0], pt2 = r.get("position", Vector2());
                out["Distance"] = (double)from2.distance_to(pt2);
                return out;
            } else {
                Node *n = owner_node;
                Node3D *n3 = Object::cast_to<Node3D>(owner_node);
                while (n && !n3) { n = n->get_parent(); n3 = Object::cast_to<Node3D>(n); }
                if (!n3) { out["Hit"] = false; return out; }
                Ref<World3D> w = n3->get_world_3d();
                if (!w.is_valid()) { out["Hit"] = false; return out; }
                PhysicsDirectSpaceState3D *ss = PhysicsServer3D::get_singleton()->space_get_direct_state(w->get_space());
                if (!ss) { out["Hit"] = false; return out; }
                Ref<PhysicsRayQueryParameters3D> q; q.instantiate();
                q->set_from((Vector3)args[0]);
                q->set_to((Vector3)args[1]);
                q->set_collision_mask(mask);
                Dictionary r = ss->intersect_ray(q);
                if (r.is_empty()) { out["Hit"] = false; return out; }
                out["Hit"]      = true;
                out["Collider"] = r.get("collider", Variant());
                out["Point"]    = r.get("position", Variant());
                out["Normal"]   = r.get("normal", Variant());
                Vector3 from3 = args[0], pt3 = r.get("position", Vector3());
                out["Distance"] = (double)from3.distance_to(pt3);
                return out;
            }
        }

        // Joypad.IsConnected(idx) — alias of Joypad.Connected.
        if (METHOD_IS("joypad_isconnected") && args.size() == 1) {
            r_handled = true;
            Input *in = Input::get_singleton();
            return in ? in->is_joy_known((int)args[0]) : false;
        }
        // Joypad.Stick("left"|"right", idx) → Vector2(axisX, axisY).
        if (METHOD_IS("joypad_stick") && args.size() == 2) {
            r_handled = true;
            Input *in = Input::get_singleton();
            if (!in) return Vector2();
            String side = String(args[0]).to_lower();
            int dev = (int)args[1];
            int ax_x = (side == "right") ? (int)JOY_AXIS_RIGHT_X : (int)JOY_AXIS_LEFT_X;
            int ax_y = (side == "right") ? (int)JOY_AXIS_RIGHT_Y : (int)JOY_AXIS_LEFT_Y;
            return Vector2(
                (real_t)in->get_joy_axis(dev, (JoyAxis)ax_x),
                (real_t)in->get_joy_axis(dev, (JoyAxis)ax_y));
        }

        // Animation.Loop(player, name, bool) — set loop mode of an Animation
        // resource on the given AnimationPlayer.
        if (METHOD_IS("animation_loop") && args.size() == 3) {
            r_handled = true;
            if (args[0].get_type() != Variant::OBJECT) return Variant();
            AnimationPlayer *p = Object::cast_to<AnimationPlayer>((Object *)args[0]);
            if (!p) return Variant();
            String name = args[1];
            Ref<Animation> a = p->get_animation(StringName(name));
            if (a.is_valid()) {
                a->set_loop_mode(((bool)args[2]) ? Animation::LOOP_LINEAR : Animation::LOOP_NONE);
            }
            return Variant();
        }

        // Sensor.Magnetometer — alias of Sensor.Magnet (µT triplet).
        if (METHOD_IS("sensor_magnetometer")) {
            r_handled = true;
            Input *in = Input::get_singleton();
            return in ? in->get_magnetometer() : Vector3();
        }

        // Theme.Set(ctl, key, value) / Theme.Get(ctl, key) — auto-pick the
        // theme override category from the value's type.
        if (METHOD_IS("theme_set") && args.size() == 3) {
            r_handled = true;
            if (args[0].get_type() != Variant::OBJECT) return Variant();
            Control *c = Object::cast_to<Control>((Object *)args[0]);
            if (!c) return Variant();
            StringName key = StringName(String(args[1]));
            Variant v = args[2];
            switch (v.get_type()) {
                case Variant::COLOR:
                    c->add_theme_color_override(key, (Color)v);
                    break;
                case Variant::INT:
                    c->add_theme_constant_override(key, (int)v);
                    break;
                case Variant::OBJECT: {
                    Object *o = v;
                    Ref<Font> f = Object::cast_to<Font>(o);
                    if (f.is_valid()) { c->add_theme_font_override(key, f); break; }
                    Ref<StyleBox> sb = Object::cast_to<StyleBox>(o);
                    if (sb.is_valid()) { c->add_theme_stylebox_override(key, sb); break; }
                    break;
                }
                default: break;
            }
            return Variant();
        }
        if (METHOD_IS("theme_get") && args.size() == 2) {
            r_handled = true;
            if (args[0].get_type() != Variant::OBJECT) return Variant();
            Control *c = Object::cast_to<Control>((Object *)args[0]);
            if (!c) return Variant();
            StringName key = StringName(String(args[1]));
            if (c->has_theme_color(key))    return c->get_theme_color(key);
            if (c->has_theme_constant(key)) return (int64_t)c->get_theme_constant(key);
            if (c->has_theme_font(key))     return Variant(c->get_theme_font(key));
            if (c->has_theme_stylebox(key)) return Variant(c->get_theme_stylebox(key));
            if (c->has_theme_font_size(key))return (int64_t)c->get_theme_font_size(key);
            return Variant();
        }

        // Shader.Set / Shader.Get — friendlier pair for shader_param /
        // shader_getparam. Accepts a ShaderMaterial directly OR any
        // CanvasItem/GeometryInstance3D whose `material`/`material_override`
        // is a ShaderMaterial.
        auto as_shader_material_loose = [&](const Variant &h) -> Ref<ShaderMaterial> {
            Ref<ShaderMaterial> m;
            if (h.get_type() != Variant::OBJECT) return m;
            Object *o = h;
            ShaderMaterial *direct = Object::cast_to<ShaderMaterial>(o);
            if (direct) { m = Ref<ShaderMaterial>(direct); return m; }
            // Try common material slot names.
            Variant slot = o->get("material");
            if (slot.get_type() == Variant::OBJECT) {
                ShaderMaterial *sm = Object::cast_to<ShaderMaterial>((Object *)slot);
                if (sm) { m = Ref<ShaderMaterial>(sm); return m; }
            }
            slot = o->get("material_override");
            if (slot.get_type() == Variant::OBJECT) {
                ShaderMaterial *sm = Object::cast_to<ShaderMaterial>((Object *)slot);
                if (sm) { m = Ref<ShaderMaterial>(sm); }
            }
            return m;
        };
        if (METHOD_IS("shader_set") && args.size() == 3) {
            r_handled = true;
            Ref<ShaderMaterial> m = as_shader_material_loose(args[0]);
            if (m.is_valid()) m->set_shader_parameter(StringName(String(args[1])), args[2]);
            return Variant();
        }
        if (METHOD_IS("shader_get") && args.size() == 2) {
            r_handled = true;
            Ref<ShaderMaterial> m = as_shader_material_loose(args[0]);
            return m.is_valid() ? m->get_shader_parameter(StringName(String(args[1]))) : Variant();
        }

        // Video.Play(player, path) — 2-arg form: load stream from path,
        // assign, play. Pairs with the existing 1-arg `Video.Play(player)`.
        if (METHOD_IS("video_play") && args.size() >= 2) {
            r_handled = true;
            VideoStreamPlayer *v = as_vid(args[0]);
            if (!v) return Variant();
            String path = args[1];
            Ref<VideoStream> stream = ResourceLoader::get_singleton()->load(path);
            if (stream.is_valid()) {
                v->set_stream(stream);
                v->play();
            }
            return Variant();
        }
    }

    // GetThemeDefaultFont() — returns fallback font for Godot-style DrawString calls
    if (METHOD_IS("getthemedefaultfont")) {
        r_handled = true;
        return Variant(ThemeDB::get_singleton()->get_fallback_font());
    }

    // InputBox(prompt[, title][, default]) — modal text input dialog, returns String
    if (METHOD_IS("inputbox")) {
        r_handled = true;
        String prompt = (args.size() > 0) ? String(args[0]) : String("");
        String title  = (args.size() > 1) ? String(args[1]) : String("VisualGasic");
        String def    = (args.size() > 2) ? String(args[2]) : String("");
        return native_input_box(prompt, title, def);
    }

    // ── Image / Texture creation builtins (BASIC-style) ──────────────────
    // CreateImage(width, height[, color]) — returns an Image (RGBA8)
    if (METHOD_IS("createimage") && args.size() >= 2) {
        r_handled = true;
        int w = (int)args[0], h = (int)args[1];
        if (w < 1) w = 1;
        if (h < 1) h = 1;
        if (w > 4096) w = 4096;
        if (h > 4096) h = 4096;
        Ref<Image> img = Image::create_empty(w, h, false, Image::FORMAT_RGBA8);
        if (img.is_valid()) {
            Color fill_col = Color(1, 1, 1, 1); // white by default
            if (args.size() > 2) fill_col = (Color)args[2];
            img->fill(fill_col);
        }
        return img;
    }
    // CreateTexture(image) — creates an ImageTexture from an Image
    // CreateTexture(width, height[, color]) — shortcut: create Image + ImageTexture in one call
    if (METHOD_IS("createtexture") && args.size() >= 1) {
        r_handled = true;
        if (args[0].get_type() == Variant::OBJECT) {
            // CreateTexture(image) — wrap existing Image in ImageTexture
            Ref<Image> img = args[0];
            if (img.is_valid()) {
                Ref<ImageTexture> tex = ImageTexture::create_from_image(img);
                return tex;
            }
        } else if (args.size() >= 2) {
            // CreateTexture(width, height[, color]) — convenience shortcut
            int w = (int)args[0], h = (int)args[1];
            if (w < 1) w = 1; if (h < 1) h = 1;
            if (w > 4096) w = 4096; if (h > 4096) h = 4096;
            Ref<Image> img = Image::create_empty(w, h, false, Image::FORMAT_RGBA8);
            if (img.is_valid()) {
                Color fill_col = Color(1, 1, 1, 1);
                if (args.size() > 2) fill_col = (Color)args[2];
                img->fill(fill_col);
                Ref<ImageTexture> tex = ImageTexture::create_from_image(img);
                return tex;
            }
        }
        return Variant();
    }
    // ImageToTexture(image) — alias for CreateTexture(image)
    if (METHOD_IS("imagetotexture") && args.size() == 1) {
        r_handled = true;
        if (args[0].get_type() == Variant::OBJECT) {
            Ref<Image> img = args[0];
            if (img.is_valid()) {
                return ImageTexture::create_from_image(img);
            }
        }
        return Variant();
    }
    // GetImagePixel(image, x, y) — returns Color at pixel
    if (METHOD_IS("getimagepixel") && args.size() == 3) {
        r_handled = true;
        if (args[0].get_type() == Variant::OBJECT) {
            Ref<Image> img = args[0];
            if (img.is_valid()) {
                int x = (int)args[1], y = (int)args[2];
                if (x >= 0 && x < img->get_width() && y >= 0 && y < img->get_height()) {
                    return img->get_pixel(x, y);
                }
            }
        }
        return Color(0, 0, 0, 0);
    }
    // ImageWidth(image) / ImageHeight(image) — get image dimensions
    if (METHOD_IS("imagewidth") && args.size() == 1) {
        r_handled = true;
        if (args[0].get_type() == Variant::OBJECT) {
            Ref<Image> img = args[0];
            if (img.is_valid()) return img->get_width();
        }
        return 0;
    }
    if (METHOD_IS("imageheight") && args.size() == 1) {
        r_handled = true;
        if (args[0].get_type() == Variant::OBJECT) {
            Ref<Image> img = args[0];
            if (img.is_valid()) return img->get_height();
        }
        return 0;
    }
    // TextureWidth(texture) / TextureHeight(texture) — get texture dimensions
    if (METHOD_IS("texturewidth") && args.size() == 1) {
        r_handled = true;
        if (args[0].get_type() == Variant::OBJECT) {
            Ref<Texture2D> tex = args[0];
            if (tex.is_valid()) return tex->get_width();
        }
        return 0;
    }
    if (METHOD_IS("textureheight") && args.size() == 1) {
        r_handled = true;
        if (args[0].get_type() == Variant::OBJECT) {
            Ref<Texture2D> tex = args[0];
            if (tex.is_valid()) return tex->get_height();
        }
        return 0;
    }
    // GetTextureImage(texture) — extract Image data from a Texture2D
    if (METHOD_IS("gettextureimage") && args.size() == 1) {
        r_handled = true;
        if (args[0].get_type() == Variant::OBJECT) {
            Ref<Texture2D> tex = args[0];
            if (tex.is_valid()) {
                return tex->get_image();
            }
        }
        return Variant();
    }
    // SaveImage(image, path) — save Image to PNG file
    if (METHOD_IS("saveimage") && args.size() == 2) {
        r_handled = true;
        if (args[0].get_type() == Variant::OBJECT) {
            Ref<Image> img = args[0];
            if (img.is_valid()) {
                String path = args[1];
                if (!path.begins_with("res://") && !path.begins_with("user://")) path = "user://" + path;
                img->save_png(path);
                return true;
            }
        }
        return false;
    }
    // LoadImage(path) — load Image from file (not a texture — for pixel manipulation)
    if (METHOD_IS("loadimage") && args.size() == 1) {
        r_handled = true;
        String path = args[0];
        if (!path.begins_with("res://") && !path.begins_with("user://")) path = "res://" + path;
        Ref<Image> img;
        img.instantiate();
        if (img->load(path) == OK) {
            // Ensure RGBA8 format for pixel operations
            if (img->get_format() != Image::FORMAT_RGBA8) img->convert(Image::FORMAT_RGBA8);
            return img;
        }
        return Variant();
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
    if (METHOD_IS("instr") && args.size() >= 2) { r_handled = true; if (args.size() == 2) { String s1 = args[0]; String s2 = args[1]; int pos = s1.find(s2); if (pos==-1) return 0; return pos+1; } else { int start = (int)args[0]; String s1 = args[1]; String s2 = args[2]; if (start < 1) start = 1; if (start > s1.length()) return 0; int pos = s1.find(s2, start - 1); if (pos==-1) return 0; return pos+1; } }
    if (METHOD_IS("instrrev") && args.size() >= 2) { r_handled = true; String s1 = args[0]; String s2 = args[1]; int start = (args.size() >= 3) ? (int)args[2] - 1 : s1.length() - 1; if (start < 0 || start >= s1.length()) start = s1.length() - 1; int pos = s1.rfind(s2, start); if (pos == -1) return 0; return pos + 1; }
    if (METHOD_IS("replace") && args.size() == 3) { r_handled = true; return String(args[0]).replace(String(args[1]), String(args[2])); }
    if (METHOD_IS("trim") && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(); }
    if (METHOD_IS("ltrim") && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(true,false); }
    if (METHOD_IS("rtrim") && args.size() == 1) { r_handled = true; return String(args[0]).strip_edges(false,true); }
    if (METHOD_IS("strreverse") && args.size() == 1) { r_handled = true; String s = args[0]; String res=""; for(int i=s.length()-1;i>=0;i--) res += s[i]; return res; }
    if (METHOD_IS("hex") && args.size() == 1) { r_handled = true; int64_t val = (int64_t)args[0]; return String::num_int64(val,16).to_upper(); }
    if (METHOD_IS("oct") && args.size() == 1) { r_handled = true; int64_t val = (int64_t)args[0]; return String::num_int64(val,8); }
    if (METHOD_IS("split") && args.size() >= 2) { r_handled = true; PackedStringArray psa = String(args[0]).split(String(args[1])); Array ret; for (int i = 0; i < psa.size(); i++) { ret.push_back(psa[i]); } return ret; }
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
    if (METHOD_IS("clnglng") && args.size() == 1) { r_handled = true; return (int64_t)llround((double)args[0]); }
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
        if (a.get_type() == Variant::FLOAT && b.get_type() == Variant::VECTOR3) return Vector3(b) * (double)a;
        if (a.get_type() == Variant::INT && b.get_type() == Variant::VECTOR3) return Vector3(b) * (double)(int64_t)a;
        if (a.get_type() == Variant::FLOAT && b.get_type() == Variant::VECTOR2) return Vector2(b) * (double)a;
        if (a.get_type() == Variant::INT && b.get_type() == Variant::VECTOR2) return Vector2(b) * (double)(int64_t)a;
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

    // ============================================
    // VB6 Compatibility Functions (v4.2.0)
    // ============================================

    // Point(image, x, y) — VB6-style alias for GetImagePixel
    if ((METHOD_IS("point")) && args.size() == 3) {
        r_handled = true;
        if (args[0].get_type() == Variant::OBJECT) {
            Ref<Image> img = args[0];
            if (img.is_valid()) {
                int x = (int)args[1], y = (int)args[2];
                if (x >= 0 && x < img->get_width() && y >= 0 && y < img->get_height()) {
                    return img->get_pixel(x, y);
                }
            }
        }
        return Color(0, 0, 0, 0);
    }

    // SavePicture image, path — VB6-style alias for SaveImage
    if (METHOD_IS("savepicture") && args.size() == 2) {
        r_handled = true;
        if (args[0].get_type() == Variant::OBJECT) {
            Ref<Image> img = args[0];
            if (img.is_valid()) {
                String path = args[1];
                if (!path.begins_with("res://") && !path.begins_with("user://")) path = "user://" + path;
                img->save_png(path);
                return true;
            }
        }
        return false;
    }

    // Error n — raise runtime error with error number
    if (METHOD_IS("error") && args.size() >= 1) {
        r_handled = true;
        int code = (int)args[0];
        // Standard VB6 error descriptions
        String desc;
        switch (code) {
            case 5: desc = "Invalid procedure call or argument"; break;
            case 6: desc = "Overflow"; break;
            case 7: desc = "Out of memory"; break;
            case 9: desc = "Subscript out of range"; break;
            case 11: desc = "Division by zero"; break;
            case 13: desc = "Type mismatch"; break;
            case 14: desc = "Out of string space"; break;
            case 28: desc = "Out of stack space"; break;
            case 35: desc = "Sub or Function not defined"; break;
            case 48: desc = "Error in loading DLL"; break;
            case 52: desc = "Bad file name or number"; break;
            case 53: desc = "File not found"; break;
            case 54: desc = "Bad file mode"; break;
            case 55: desc = "File already open"; break;
            case 57: desc = "Device I/O error"; break;
            case 58: desc = "File already exists"; break;
            case 61: desc = "Disk full"; break;
            case 62: desc = "Input past end of file"; break;
            case 67: desc = "Too many files"; break;
            case 68: desc = "Device unavailable"; break;
            case 70: desc = "Permission denied"; break;
            case 71: desc = "Disk not ready"; break;
            case 75: desc = "Path/File access error"; break;
            case 76: desc = "Path not found"; break;
            case 91: desc = "Object variable or With block variable not set"; break;
            case 94: desc = "Invalid use of Null"; break;
            case 380: desc = "Invalid property value"; break;
            case 422: desc = "Property not found"; break;
            case 424: desc = "Object required"; break;
            case 429: desc = "ActiveX component can't create object"; break;
            case 438: desc = "Object doesn't support this property or method"; break;
            case 440: desc = "Automation error"; break;
            case 445: desc = "Object doesn't support this action"; break;
            case 448: desc = "Named argument not found"; break;
            case 449: desc = "Argument not optional"; break;
            case 450: desc = "Wrong number of arguments or invalid property assignment"; break;
            case 451: desc = "Property let procedure not defined"; break;
            case 452: desc = "Invalid ordinal"; break;
            case 453: desc = "Specified DLL function not found"; break;
            case 457: desc = "This key is already associated with an element of this collection"; break;
            case 458: desc = "Variable uses an Automation type not supported in VG"; break;
            case 481: desc = "Invalid picture"; break;
            case 482: desc = "Printer error"; break;
            default: desc = "Application-defined or object-defined error"; break;
        }
        if (args.size() >= 2) desc = String(args[1]); // Optional custom description
        instance->raise_runtime_error(desc, code);
        return Variant();
    }

    // Error$([errornumber]) — return error description for error number
    if ((METHOD_IS("error$") || METHOD_IS("errordesc")) && args.size() >= 0) {
        r_handled = true;
        if (args.size() >= 1) {
            int code = (int)args[0];
            switch (code) {
                case 5: return String("Invalid procedure call or argument");
                case 6: return String("Overflow");
                case 7: return String("Out of memory");
                case 9: return String("Subscript out of range");
                case 11: return String("Division by zero");
                case 13: return String("Type mismatch");
                case 52: return String("Bad file name or number");
                case 53: return String("File not found");
                case 54: return String("Bad file mode");
                case 55: return String("File already open");
                case 62: return String("Input past end of file");
                case 70: return String("Permission denied");
                case 75: return String("Path/File access error");
                case 76: return String("Path not found");
                case 91: return String("Object variable or With block variable not set");
                case 94: return String("Invalid use of Null");
                case 424: return String("Object required");
                case 438: return String("Object doesn't support this property or method");
                default: return String("Application-defined or object-defined error");
            }
        }
        // No args: return current error description
        if (instance->get_variables().has("Err")) {
            Variant v = instance->get_variables()["Err"];
            if (v.get_type() == Variant::DICTIONARY) {
                Dictionary err = v;
                if (err.has("Description")) return err["Description"];
            }
        }
        return String("");
    }

    // Reset — close all open files
    if (METHOD_IS("reset") && args.size() == 0) {
        r_handled = true;
        instance->get_open_files().clear();
        return Variant();
    }

    // IsMissing(var) — returns True if an Optional parameter was not supplied
    if (METHOD_IS("ismissing") && args.size() == 1) {
        r_handled = true;
        return args[0].get_type() == Variant::NIL;
    }

    // Erl — returns the line number where the last error occurred
    if (METHOD_IS("erl") && args.size() == 0) {
        r_handled = true;
        return (int64_t)instance->get_error_line();
    }

    // LSet(string, length) — left-aligns string within a space of given length
    if (METHOD_IS("lset") && args.size() == 2) {
        r_handled = true;
        String s = args[0];
        int length = (int)args[1];
        if (s.length() >= length) return s.left(length);
        String result = s;
        for (int i = s.length(); i < length; i++) result += " ";
        return result;
    }

    // RSet(string, length) — right-aligns string within a space of given length
    if (METHOD_IS("rset") && args.size() == 2) {
        r_handled = true;
        String s = args[0];
        int length = (int)args[1];
        if (s.length() >= length) return s.right(length);
        String result;
        for (int i = s.length(); i < length; i++) result += " ";
        result += s;
        return result;
    }

    // ChrW(charcode) — Unicode character from code point (alias for Chr in VG, since Godot is Unicode)
    if (METHOD_IS("chrw") && args.size() == 1) {
        r_handled = true;
        return String::chr((int)args[0]);
    }

    // AscW(string) — Unicode code point of first character (alias for Asc in VG)
    if (METHOD_IS("ascw") && args.size() == 1) {
        r_handled = true;
        String s = args[0];
        if (s.length() > 0) return (int64_t)s.unicode_at(0);
        return (int64_t)0;
    }

    // DateValue(datestring) — extracts the date portion from a date/time string
    if (METHOD_IS("datevalue") && args.size() == 1) {
        r_handled = true;
        String s = String(args[0]).strip_edges();
        // If it contains a space (date + time), take the date part
        if (s.contains(" ")) {
            PackedStringArray parts = s.split(" ");
            s = parts[0];
        }
        // Validate it looks like a date (contains / or -)
        if (s.contains("/") || s.contains("-")) {
            return s;
        }
        return s; // Return as-is
    }

    // TimeValue(timestring) — extracts the time portion from a date/time string
    if (METHOD_IS("timevalue") && args.size() == 1) {
        r_handled = true;
        String s = String(args[0]).strip_edges();
        // If it contains a space (date + time), take the time part(s)
        if (s.contains(" ") && s.contains(":")) {
            PackedStringArray parts = s.split(" ");
            String result;
            for (int i = 0; i < parts.size(); i++) {
                if (parts[i].contains(":")) {
                    result = parts[i];
                    // Append AM/PM if next part is one
                    if (i + 1 < parts.size()) {
                        String next = parts[i + 1].to_upper();
                        if (next == "AM" || next == "PM") {
                            result += " " + parts[i + 1];
                        }
                    }
                    return result;
                }
            }
        }
        return s; // Already a time string
    }

    // StrConv(string, conversion) — string conversion
    // vbUpperCase = 1, vbLowerCase = 2, vbProperCase = 3
    if (METHOD_IS("strconv") && args.size() >= 2) {
        r_handled = true;
        String s = args[0];
        int conv = (int)args[1];
        if (conv == 1) return s.to_upper(); // vbUpperCase
        if (conv == 2) return s.to_lower(); // vbLowerCase
        if (conv == 3) { // vbProperCase — capitalize first letter of each word
            String result;
            bool cap_next = true;
            for (int i = 0; i < s.length(); i++) {
                char32_t c = s[i];
                if (cap_next && c >= 'a' && c <= 'z') {
                    result += String::chr(c - 32);
                    cap_next = false;
                } else {
                    result += String::chr(c);
                    cap_next = (c == ' ' || c == '\t' || c == '\n' || c == '-' || c == '\'');
                }
            }
            return result;
        }
        if (conv == 64) return s; // vbUnicode — already Unicode in Godot
        if (conv == 128) return s; // vbFromUnicode — noop in Godot
        return s;
    }

    // FormatNumber(expression[, numDigitsAfterDecimal[, includeLeadingDigit[, useParensForNegativeNumbers[, groupDigits]]]])
    if (METHOD_IS("formatnumber") && args.size() >= 1) {
        r_handled = true;
        double num = (double)args[0];
        int decimals = (args.size() >= 2) ? (int)args[1] : 2;
        bool leading = (args.size() >= 3) ? (bool)args[2] : true;
        bool parens = (args.size() >= 4) ? (bool)args[3] : false;
        bool group = (args.size() >= 5) ? (bool)args[4] : true;

        bool negative = num < 0;
        if (negative) num = -num;
        String result = String::num(num, decimals);

        if (group) {
            // Add thousand separators
            int dot_pos = result.find(".");
            String int_part = (dot_pos >= 0) ? result.left(dot_pos) : result;
            String dec_part = (dot_pos >= 0) ? result.substr(dot_pos) : "";
            String grouped;
            int count = 0;
            for (int i = int_part.length() - 1; i >= 0; i--) {
                if (count > 0 && count % 3 == 0) grouped = "," + grouped;
                grouped = String::chr(int_part[i]) + grouped;
                count++;
            }
            result = grouped + dec_part;
        }

        if (!leading && result.begins_with("0.")) {
            result = result.substr(1);
        }

        if (negative) {
            result = parens ? ("(" + result + ")") : ("-" + result);
        }
        return result;
    }

    // FormatCurrency(expression[, numDigitsAfterDecimal[, includeLeadingDigit[, useParensForNegativeNumbers[, groupDigits]]]])
    if (METHOD_IS("formatcurrency") && args.size() >= 1) {
        r_handled = true;
        double num = (double)args[0];
        int decimals = (args.size() >= 2) ? (int)args[1] : 2;
        bool parens = (args.size() >= 4) ? (bool)args[3] : false;
        bool group = (args.size() >= 5) ? (bool)args[4] : true;

        bool negative = num < 0;
        if (negative) num = -num;
        String result = String::num(num, decimals);

        if (group) {
            int dot_pos = result.find(".");
            String int_part = (dot_pos >= 0) ? result.left(dot_pos) : result;
            String dec_part = (dot_pos >= 0) ? result.substr(dot_pos) : "";
            String grouped;
            int count = 0;
            for (int i = int_part.length() - 1; i >= 0; i--) {
                if (count > 0 && count % 3 == 0) grouped = "," + grouped;
                grouped = String::chr(int_part[i]) + grouped;
                count++;
            }
            result = grouped + dec_part;
        }

        if (negative) {
            result = parens ? ("($" + result + ")") : ("-$" + result);
        } else {
            result = "$" + result;
        }
        return result;
    }

    // FormatPercent(expression[, numDigitsAfterDecimal[, includeLeadingDigit[, useParensForNegativeNumbers[, groupDigits]]]])
    if (METHOD_IS("formatpercent") && args.size() >= 1) {
        r_handled = true;
        double num = (double)args[0] * 100.0;
        int decimals = (args.size() >= 2) ? (int)args[1] : 2;
        bool parens = (args.size() >= 4) ? (bool)args[3] : false;

        bool negative = num < 0;
        if (negative) num = -num;
        String result = String::num(num, decimals) + "%";

        if (negative) {
            result = parens ? ("(" + result + ")") : ("-" + result);
        }
        return result;
    }

    // FileDateTime(pathname) — returns the date/time a file was last modified
    if (METHOD_IS("filedatetime") && args.size() == 1) {
        r_handled = true;
        String path = args[0];
        if (!path.begins_with("res://") && !path.begins_with("user://")) path = "res://" + path;
        uint64_t mod_time = FileAccess::get_modified_time(path);
        if (mod_time > 0) {
            Dictionary datetime = Time::get_singleton()->get_datetime_dict_from_unix_time(mod_time);
            int year = (int)datetime["year"];
            int month = (int)datetime["month"];
            int day = (int)datetime["day"];
            int hour = (int)datetime["hour"];
            int minute = (int)datetime["minute"];
            int second = (int)datetime["second"];
            String ampm = hour >= 12 ? "PM" : "AM";
            int hour12 = hour % 12;
            if (hour12 == 0) hour12 = 12;
            return String::num_int64(month) + "/" + String::num_int64(day) + "/" + String::num_int64(year) + " " +
                   String::num_int64(hour12) + ":" + (minute < 10 ? "0" : "") + String::num_int64(minute) + ":" +
                   (second < 10 ? "0" : "") + String::num_int64(second) + " " + ampm;
        }
        return String("");
    }

    // TextWidth(text[, fontSize]) — returns width of text in pixels using default font
    if (METHOD_IS("textwidth") && args.size() >= 1) {
        r_handled = true;
        String text = args[0];
        int font_size = (args.size() >= 2) ? (int)args[1] : 16;
        Ref<Font> font = ThemeDB::get_singleton()->get_fallback_font();
        if (font.is_valid()) {
            Vector2 size = font->get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size);
            return (int64_t)size.x;
        }
        return (int64_t)(text.length() * font_size); // Rough fallback
    }

    // TextHeight(text[, fontSize]) — returns height of text in pixels using default font
    if (METHOD_IS("textheight") && args.size() >= 1) {
        r_handled = true;
        String text = args[0];
        int font_size = (args.size() >= 2) ? (int)args[1] : 16;
        Ref<Font> font = ThemeDB::get_singleton()->get_fallback_font();
        if (font.is_valid()) {
            Vector2 size = font->get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size);
            return (int64_t)size.y;
        }
        return (int64_t)font_size; // Rough fallback
    }

    // Input$(n, filenumber) — read n characters from file
    if ((METHOD_IS("input$") || METHOD_IS("inputstr")) && args.size() == 2) {
        r_handled = true;
        int n = (int)args[0];
        int fn = (int)args[1];
        if (instance->get_open_files().has(fn)) {
            Ref<FileAccess> fa = instance->get_open_files()[fn];
            if (fa.is_valid()) {
                String result;
                for (int i = 0; i < n && !fa->eof_reached(); i++) {
                    result += String::chr(fa->get_8());
                }
                return result;
            }
        }
        instance->raise_runtime_error("Bad file name or number", 52);
        return String("");
    }

    // CallByName(object, procname, calltype[, args...])
    // calltype: 1=Method, 2=Get, 4=Let
    if (METHOD_IS("callbyname") && args.size() >= 3) {
        r_handled = true;
        Variant obj = args[0];
        String proc_name = args[1];
        int call_type = (int)args[2];

        if (obj.get_type() == Variant::DICTIONARY) {
            Dictionary dict = obj;
            if (call_type == 2) { // vbGet
                if (dict.has(proc_name)) return dict[proc_name];
                return Variant();
            } else if (call_type == 4) { // vbLet
                if (args.size() >= 4) dict[proc_name] = args[3];
                return Variant();
            }
        }
        // For method calls (vbMethod=1), try to call as a VG sub/function
        if (call_type == 1) {
            Array call_args;
            for (int i = 3; i < args.size(); i++) call_args.push_back(args[i]);
            return instance->call_method_by_name(proc_name, call_args);
        }
        return Variant();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ── Financial Functions (VB6-compatible) ─────────────────────────────────
    // ══════════════════════════════════════════════════════════════════════════

    // Pmt(rate, nper, pv[, fv][, type]) — Periodic payment for a loan/annuity
    if (METHOD_IS("pmt") && args.size() >= 3) {
        r_handled = true;
        double rate = (double)args[0];
        double nper = (double)args[1];
        double pv   = (double)args[2];
        double fv   = (args.size() > 3) ? (double)args[3] : 0.0;
        int    due  = (args.size() > 4) ? (int)args[4] : 0; // 0=end, 1=beginning
        
        if (rate == 0.0) {
            return -(pv + fv) / nper;
        }
        double temp = Math::pow(1.0 + rate, nper);
        double pmt = (rate * (fv + pv * temp)) / ((1.0 + rate * due) * (1.0 - temp));
        return pmt;
    }

    // FV(rate, nper, pmt[, pv][, type]) — Future value
    if (METHOD_IS("fv") && args.size() >= 3) {
        r_handled = true;
        double rate = (double)args[0];
        double nper = (double)args[1];
        double pmt  = (double)args[2];
        double pv   = (args.size() > 3) ? (double)args[3] : 0.0;
        int    due  = (args.size() > 4) ? (int)args[4] : 0;
        
        if (rate == 0.0) {
            return -(pv + pmt * nper);
        }
        double temp = Math::pow(1.0 + rate, nper);
        double fv_result = -pv * temp - pmt * (1.0 + rate * due) * (temp - 1.0) / rate;
        return fv_result;
    }

    // PV(rate, nper, pmt[, fv][, type]) — Present value
    if (METHOD_IS("pv") && args.size() >= 3) {
        r_handled = true;
        double rate = (double)args[0];
        double nper = (double)args[1];
        double pmt  = (double)args[2];
        double fv   = (args.size() > 3) ? (double)args[3] : 0.0;
        int    due  = (args.size() > 4) ? (int)args[4] : 0;
        
        if (rate == 0.0) {
            return -(fv + pmt * nper);
        }
        double temp = Math::pow(1.0 + rate, nper);
        double pv_result = -(fv + pmt * (1.0 + rate * due) * (temp - 1.0) / rate) / temp;
        return pv_result;
    }

    // NPV(rate, values()) — Net present value
    if (METHOD_IS("npv") && args.size() >= 2) {
        r_handled = true;
        double rate = (double)args[0];
        Array values;
        if (args[1].get_type() == Variant::ARRAY) {
            values = args[1];
        } else {
            // Remaining args are the cash flow values
            for (int i = 1; i < args.size(); i++) values.push_back(args[i]);
        }
        double npv = 0.0;
        for (int i = 0; i < values.size(); i++) {
            npv += (double)values[i] / Math::pow(1.0 + rate, (double)(i + 1));
        }
        return npv;
    }

    // IRR(values()[, guess]) — Internal rate of return (Newton-Raphson)
    if (METHOD_IS("irr") && args.size() >= 1) {
        r_handled = true;
        Array values;
        if (args[0].get_type() == Variant::ARRAY) {
            values = args[0];
        } else {
            for (int i = 0; i < args.size() - ((args.size() > 1 && args[args.size()-1].get_type() != Variant::ARRAY) ? 1 : 0); i++) {
                if (args[i].get_type() == Variant::ARRAY) { values = args[i]; break; }
            }
            if (values.size() == 0) {
                for (int i = 0; i < args.size(); i++) values.push_back(args[i]);
            }
        }
        double guess = (args.size() > 1 && args[args.size()-1].get_type() != Variant::ARRAY) ? (double)args[args.size()-1] : 0.1;
        
        double rate = guess;
        for (int iter = 0; iter < 100; iter++) {
            double npv = 0.0, dnpv = 0.0;
            for (int i = 0; i < values.size(); i++) {
                double v = (double)values[i];
                double p = Math::pow(1.0 + rate, (double)i);
                npv += v / p;
                if (i > 0) dnpv -= i * v / (p * (1.0 + rate));
            }
            if (Math::abs(dnpv) < 1e-15) break;
            double new_rate = rate - npv / dnpv;
            if (Math::abs(new_rate - rate) < 1e-10) { rate = new_rate; break; }
            rate = new_rate;
        }
        return rate;
    }

    // Rate(nper, pmt, pv[, fv][, type][, guess]) — Interest rate per period (Newton-Raphson)
    if (METHOD_IS("rate") && args.size() >= 3) {
        r_handled = true;
        double nper = (double)args[0];
        double pmt  = (double)args[1];
        double pv   = (double)args[2];
        double fv   = (args.size() > 3) ? (double)args[3] : 0.0;
        int    due  = (args.size() > 4) ? (int)args[4] : 0;
        double guess = (args.size() > 5) ? (double)args[5] : 0.1;
        
        double rate = guess;
        for (int iter = 0; iter < 100; iter++) {
            double temp = Math::pow(1.0 + rate, nper);
            double f_val, f_deriv;
            if (rate == 0.0) {
                f_val = pv + pmt * nper + fv;
                f_deriv = pmt * nper * (nper - 1.0) / 2.0;
            } else {
                double pmt_factor = (1.0 + rate * due) * (temp - 1.0) / rate;
                f_val = pv * temp + pmt * pmt_factor + fv;
                // Derivative
                double dt_dr = nper * Math::pow(1.0 + rate, nper - 1.0);
                double dpf_dr = (1.0 + rate * due) * (dt_dr * rate - (temp - 1.0)) / (rate * rate)
                              + due * (temp - 1.0) / rate;
                f_deriv = pv * dt_dr + pmt * dpf_dr;
            }
            if (Math::abs(f_deriv) < 1e-15) break;
            double new_rate = rate - f_val / f_deriv;
            if (Math::abs(new_rate - rate) < 1e-10) { rate = new_rate; break; }
            rate = new_rate;
        }
        return rate;
    }

    // NPER(rate, pmt, pv[, fv][, type]) — Number of periods
    if (METHOD_IS("nper") && args.size() >= 3) {
        r_handled = true;
        double rate = (double)args[0];
        double pmt  = (double)args[1];
        double pv   = (double)args[2];
        double fv   = (args.size() > 3) ? (double)args[3] : 0.0;
        int    due  = (args.size() > 4) ? (int)args[4] : 0;
        
        if (rate == 0.0) {
            if (pmt == 0.0) return Variant(); // Error
            return -(pv + fv) / pmt;
        }
        double pmt_adj = pmt * (1.0 + rate * due);
        double nper_result = Math::log((-fv * rate + pmt_adj) / (pv * rate + pmt_adj)) / Math::log(1.0 + rate);
        return nper_result;
    }

    // SLN(cost, salvage, life) — Straight-line depreciation
    if (METHOD_IS("sln") && args.size() >= 3) {
        r_handled = true;
        double cost    = (double)args[0];
        double salvage = (double)args[1];
        double life    = (double)args[2];
        if (life == 0.0) { instance->raise_runtime_error("SLN: Life cannot be zero"); return Variant(); }
        return (cost - salvage) / life;
    }

    // SYD(cost, salvage, life, period) — Sum-of-years-digits depreciation
    if (METHOD_IS("syd") && args.size() >= 4) {
        r_handled = true;
        double cost    = (double)args[0];
        double salvage = (double)args[1];
        double life    = (double)args[2];
        double period  = (double)args[3];
        if (life <= 0.0) { instance->raise_runtime_error("SYD: Life must be positive"); return Variant(); }
        double syd_total = life * (life + 1.0) / 2.0;
        return (cost - salvage) * (life - period + 1.0) / syd_total;
    }

    // DDB(cost, salvage, life, period[, factor]) — Double declining balance depreciation
    if (METHOD_IS("ddb") && args.size() >= 4) {
        r_handled = true;
        double cost    = (double)args[0];
        double salvage = (double)args[1];
        double life    = (double)args[2];
        double period  = (double)args[3];
        double factor  = (args.size() > 4) ? (double)args[4] : 2.0;
        
        if (life <= 0.0) { instance->raise_runtime_error("DDB: Life must be positive"); return Variant(); }
        double book_value = cost;
        double rate_ddb = factor / life;
        double depreciation = 0.0;
        for (int p = 1; p <= (int)period; p++) {
            depreciation = book_value * rate_ddb;
            if (book_value - depreciation < salvage) {
                depreciation = book_value - salvage;
            }
            if (depreciation < 0.0) depreciation = 0.0;
            book_value -= depreciation;
        }
        return depreciation;
    }

    // IPmt(rate, per, nper, pv[, fv][, type]) — Interest portion of a payment
    if (METHOD_IS("ipmt") && args.size() >= 4) {
        r_handled = true;
        double rate = (double)args[0];
        double per  = (double)args[1];
        double nper = (double)args[2];
        double pv   = (double)args[3];
        double fv   = (args.size() > 4) ? (double)args[4] : 0.0;
        int    due  = (args.size() > 5) ? (int)args[5] : 0;
        
        // Calculate total payment first
        double pmt_val;
        if (rate == 0.0) {
            pmt_val = -(pv + fv) / nper;
        } else {
            double temp = Math::pow(1.0 + rate, nper);
            pmt_val = (rate * (fv + pv * temp)) / ((1.0 + rate * due) * (1.0 - temp));
        }
        
        // Calculate balance at period (per-1)
        double balance;
        if (rate == 0.0) {
            balance = pv + pmt_val * (per - 1.0);
        } else {
            double temp1 = Math::pow(1.0 + rate, per - 1.0);
            balance = pv * temp1 + pmt_val * (1.0 + rate * due) * (temp1 - 1.0) / rate;
        }
        
        double ipmt_val = balance * rate;
        if (due == 1 && per == 1.0) ipmt_val = 0.0; // First period, beginning: no interest yet
        return ipmt_val;
    }

    // PPmt(rate, per, nper, pv[, fv][, type]) — Principal portion of a payment
    if (METHOD_IS("ppmt") && args.size() >= 4) {
        r_handled = true;
        double rate = (double)args[0];
        double per  = (double)args[1];
        double nper = (double)args[2];
        double pv   = (double)args[3];
        double fv   = (args.size() > 4) ? (double)args[4] : 0.0;
        int    due  = (args.size() > 5) ? (int)args[5] : 0;
        
        // Total payment
        double pmt_val;
        if (rate == 0.0) {
            pmt_val = -(pv + fv) / nper;
        } else {
            double temp = Math::pow(1.0 + rate, nper);
            pmt_val = (rate * (fv + pv * temp)) / ((1.0 + rate * due) * (1.0 - temp));
        }
        
        // Interest portion
        double balance;
        if (rate == 0.0) {
            balance = pv + pmt_val * (per - 1.0);
        } else {
            double temp1 = Math::pow(1.0 + rate, per - 1.0);
            balance = pv * temp1 + pmt_val * (1.0 + rate * due) * (temp1 - 1.0) / rate;
        }
        double ipmt_val = balance * rate;
        if (due == 1 && per == 1.0) ipmt_val = 0.0;
        
        return pmt_val - ipmt_val; // PPmt = Pmt - IPmt
    }

    // MIRR(values(), finance_rate, reinvest_rate) — Modified internal rate of return
    if (METHOD_IS("mirr") && args.size() >= 3) {
        r_handled = true;
        Array values;
        if (args[0].get_type() == Variant::ARRAY) {
            values = args[0];
        } else {
            instance->raise_runtime_error("MIRR: First argument must be an array of cash flows");
            return Variant();
        }
        double finance_rate  = (double)args[1];
        double reinvest_rate = (double)args[2];
        int n = values.size();
        if (n < 2) { instance->raise_runtime_error("MIRR: Need at least 2 cash flows"); return Variant(); }
        
        // PV of negative cash flows (at finance_rate)
        // FV of positive cash flows (at reinvest_rate)
        double pv_neg = 0.0, fv_pos = 0.0;
        for (int i = 0; i < n; i++) {
            double v = (double)values[i];
            if (v < 0.0) {
                pv_neg += v / Math::pow(1.0 + finance_rate, (double)i);
            } else {
                fv_pos += v * Math::pow(1.0 + reinvest_rate, (double)(n - 1 - i));
            }
        }
        if (pv_neg == 0.0) { instance->raise_runtime_error("MIRR: No negative cash flows"); return Variant(); }
        
        double mirr = Math::pow(-fv_pos / pv_neg, 1.0 / (double)(n - 1)) - 1.0;
        return mirr;
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

    // ── Printer object (v3.5.0) ── VB6 Printer.Print, Printer.EndDoc, etc.
    // In a game engine context, "printing" renders to a viewport or outputs text.
    // These are stubs that log output and return success values so VB6 code
    // that references the Printer object compiles and runs without errors.
    if (p_base_name == "Printer" || p_base_name == "printer") {
        if (p_method == "Print" || p_method == "print") {
            // Printer.Print text — output to console (stub)
            String text;
            for (int i = 0; i < p_args.size(); i++) {
                if (i > 0) text += " ";
                text += String(p_args[i]);
            }
            UtilityFunctions::print("[Printer] ", text);
            r_ret = Variant();
            return true;
        }
        if (p_method == "EndDoc" || p_method == "enddoc") {
            UtilityFunctions::print("[Printer] EndDoc — document sent to printer (stub)");
            r_ret = Variant();
            return true;
        }
        if (p_method == "NewPage" || p_method == "newpage") {
            UtilityFunctions::print("[Printer] NewPage");
            r_ret = Variant();
            return true;
        }
        if (p_method == "KillDoc" || p_method == "killdoc") {
            UtilityFunctions::print("[Printer] KillDoc — print job cancelled (stub)");
            r_ret = Variant();
            return true;
        }
        if (p_method == "Circle" || p_method == "circle") {
            r_ret = Variant();
            return true;
        }
        if (p_method == "Line" || p_method == "line") {
            r_ret = Variant();
            return true;
        }
        if (p_method == "PaintPicture" || p_method == "paintpicture") {
            r_ret = Variant();
            return true;
        }
        if (p_method == "PSet" || p_method == "pset") {
            r_ret = Variant();
            return true;
        }
        // Printer properties (read)
        if (p_method == "Font" || p_method == "font") {
            r_ret = String("Arial");
            return true;
        }
        if (p_method == "FontSize" || p_method == "fontsize" || p_method == "Font.Size") {
            r_ret = 12;
            return true;
        }
        if (p_method == "FontBold" || p_method == "fontbold" || p_method == "Font.Bold") {
            r_ret = false;
            return true;
        }
        if (p_method == "FontItalic" || p_method == "fontitalic" || p_method == "Font.Italic") {
            r_ret = false;
            return true;
        }
        if (p_method == "Orientation" || p_method == "orientation") {
            r_ret = 1; // vbPRORPortrait = 1
            return true;
        }
        if (p_method == "Copies" || p_method == "copies") {
            r_ret = 1;
            return true;
        }
        if (p_method == "Page" || p_method == "page") {
            r_ret = 1;
            return true;
        }
        if (p_method == "CurrentX" || p_method == "currentx") {
            r_ret = 0;
            return true;
        }
        if (p_method == "CurrentY" || p_method == "currenty") {
            r_ret = 0;
            return true;
        }
        if (p_method == "ScaleWidth" || p_method == "scalewidth") {
            r_ret = 8500; // Default 8.5" in twips
            return true;
        }
        if (p_method == "ScaleHeight" || p_method == "scaleheight") {
            r_ret = 11000; // Default 11" in twips
            return true;
        }
        if (p_method == "hDC" || p_method == "hdc") {
            r_ret = 0; // No device context in Godot
            return true;
        }
        if (p_method == "ColorMode" || p_method == "colormode") {
            r_ret = 1; // vbPRCMMonochrome = 1
            return true;
        }
        if (p_method == "PaperSize" || p_method == "papersize") {
            r_ret = 1; // vbPRPSLetter = 1
            return true;
        }
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
    // ── SoundGen.* — real-time audio generator namespace ────────────────
    if (p_base_name == "SoundGen") {
        auto resolve_gen_pb = [&](const Variant &h) -> AudioStreamGeneratorPlayback* {
            if (h.get_type() != Variant::INT) return nullptr;
            int64_t id = (int64_t)h;
            Object *o = ObjectDB::get_instance(ObjectID((uint64_t)id));
            AudioStreamPlayer *p = Object::cast_to<AudioStreamPlayer>(o);
            if (!p) return nullptr;
            Ref<AudioStreamPlayback> pb = p->get_stream_playback();
            if (!pb.is_valid()) return nullptr;
            return Object::cast_to<AudioStreamGeneratorPlayback>(pb.ptr());
        };
        if (p_method == "Open" && p_args.size() >= 2) {
            if (!instance || !instance->get_owner()) { r_ret = (int64_t)0; return true; }
            Node *n = Object::cast_to<Node>(instance->get_owner());
            if (!n) { r_ret = (int64_t)0; return true; }
            float mix_rate = (float)(double)p_args[0];
            float buf_len  = (float)(double)p_args[1];
            Ref<AudioStreamGenerator> gen;
            gen.instantiate();
            gen->set_mix_rate(mix_rate);
            gen->set_buffer_length(buf_len);
            AudioStreamPlayer *player = memnew(AudioStreamPlayer);
            player->set_stream(gen);
            n->add_child(player);
            player->play();
            r_ret = (int64_t)(uint64_t)player->get_instance_id();
            return true;
        }
        if (p_method == "Close" && p_args.size() == 1) {
            if (p_args[0].get_type() == Variant::INT) {
                int64_t id = (int64_t)p_args[0];
                Object *o = ObjectDB::get_instance(ObjectID((uint64_t)id));
                AudioStreamPlayer *p = Object::cast_to<AudioStreamPlayer>(o);
                if (p) { p->stop(); p->queue_free(); }
            }
            r_ret = Variant();
            return true;
        }
        if (p_method == "Available" && p_args.size() == 1) {
            AudioStreamGeneratorPlayback *pb = resolve_gen_pb(p_args[0]);
            r_ret = pb ? (int)pb->get_frames_available() : 0;
            return true;
        }
        if (p_method == "PushMono" && p_args.size() == 2) {
            AudioStreamGeneratorPlayback *pb = resolve_gen_pb(p_args[0]);
            if (pb) { float s = (float)(double)p_args[1]; pb->push_frame(Vector2(s, s)); }
            r_ret = Variant();
            return true;
        }
        if (p_method == "PushStereo" && p_args.size() == 3) {
            AudioStreamGeneratorPlayback *pb = resolve_gen_pb(p_args[0]);
            if (pb) { float l = (float)(double)p_args[1]; float r = (float)(double)p_args[2]; pb->push_frame(Vector2(l, r)); }
            r_ret = Variant();
            return true;
        }
        // SoundGen.FillVoices(h, sample_rate,
        //   arp_phase, arp_freq,
        //   kick_active, kick_dur,
        //   noise_active, noise_t, noise_decay)
        // → Array [new_arp_phase, new_kick_t, new_noise_t]
        if (p_method == "FillVoices" && p_args.size() == 10) {
            AudioStreamGeneratorPlayback *pb = resolve_gen_pb(p_args[0]);
            PackedFloat32Array ret3;
            ret3.resize(3);
            float ap = (float)(double)p_args[2];
            float kt = (float)(double)p_args[5];
            float nt = (float)(double)p_args[8];
            ret3[0] = ap; ret3[1] = kt; ret3[2] = nt;
            if (!pb) { r_ret = ret3; return true; }

            float sr          = (float)(double)p_args[1];
            float arp_freq    = (float)(double)p_args[3];
            bool  kick_active = (bool)p_args[4];
            float kick_dur    = (float)(double)p_args[6];
            bool  noise_act   = (bool)p_args[7];
            float noise_decay = (float)(double)p_args[9];
            float inv_sr      = 1.0f / sr;
            float phase_inc   = arp_freq * inv_sr;
            int   nf          = (int)pb->get_frames_available();
            uint32_t rng      = 12345u + (uint32_t)(nt * sr);

            for (int i = 0; i < nf; ++i) {
                float toff = i * inv_sr;
                ap += phase_inc;
                if (ap >= 1.0f) ap -= 1.0f;
                float s = (ap < 0.5f) ? 0.10f : -0.10f;
                if (kick_active) {
                    float k = kt + toff;
                    float env = 1.0f - k / kick_dur;
                    if (env < 0.0f) env = 0.0f;
                    s += Math::sin(k * (120.0f - 80.0f * (k / kick_dur)) * Math_TAU) * env * 0.65f;
                }
                if (noise_act) {
                    rng = rng * 1664525u + 1013904223u;
                    float n01 = (float)(int32_t)rng / (float)0x7FFFFFFF;
                    float env = Math::exp(-noise_decay * (nt + toff));
                    s += n01 * env * 0.50f;
                }
                pb->push_frame(Vector2(s, s));
            }
            ret3[0] = ap;
            ret3[1] = kt + nf * inv_sr;
            ret3[2] = nt + nf * inv_sr;
            r_ret = ret3;
            return true;
        }
        // SoundGen.FillVoices4(h, sample_rate, lead_f, lead_phase, bass_f, bass_phase,
        //                       arp_f, arp_phase, hihat_active, hihat_t, hihat_inv_sr)
        // → PackedFloat32Array [new_lead_phase, new_bass_phase, new_arp_phase, new_hihat_t]
        if (p_method == "FillVoices4" && (p_args.size() == 11 || p_args.size() == 14)) {
            AudioStreamGeneratorPlayback *pb = resolve_gen_pb(p_args[0]);
            PackedFloat32Array ret4;
            bool has_kick = (p_args.size() >= 14);
            ret4.resize(has_kick ? 5 : 4);
            float lp = (float)(double)p_args[3];
            float bp = (float)(double)p_args[5];
            float ap = (float)(double)p_args[7];
            float ht = (float)(double)p_args[9];
            bool  kick_on_  = has_kick && (bool)p_args[11];
            float kick_t_   = has_kick ? (float)(double)p_args[12] : 0.0f;
            float kick_dur_ = has_kick ? (float)(double)p_args[13] : 0.3f;
            ret4[0] = lp; ret4[1] = bp; ret4[2] = ap; ret4[3] = ht;
            if (has_kick) ret4[4] = kick_t_;
            if (!pb) { r_ret = ret4; return true; }

            float sr        = (float)(double)p_args[1];
            float lead_f    = (float)(double)p_args[2];
            float bass_f    = (float)(double)p_args[4];
            float arp_f     = (float)(double)p_args[6];
            bool  hihat_on  = (bool)p_args[8];
            float hihat_inv = (float)(double)p_args[10];
            float inv_sr    = 1.0f / sr;
            float lead_inc  = lead_f * inv_sr;
            float bass_inc  = bass_f * inv_sr;
            float arp_inc   = arp_f  * inv_sr;
            int   nf        = (int)pb->get_frames_available();
            uint32_t rng    = 12345u + (uint32_t)(ht * sr);

            for (int i = 0; i < nf; ++i) {
                float s = 0.0f;
                // Voice 1: triangle lead
                if (lead_f > 0.0f) {
                    lp += lead_inc; if (lp >= 1.0f) lp -= 1.0f;
                    float tri = (lp < 0.5f) ? (4.0f * lp - 1.0f) : (3.0f - 4.0f * lp);
                    s += tri * 0.13f;
                }
                // Voice 2: sine bass
                if (bass_f > 0.0f) {
                    bp += bass_inc; if (bp >= 1.0f) bp -= 1.0f;
                    s += Math::sin(bp * Math_TAU) * 0.16f;
                }
                // Voice 3: sawtooth arp
                if (arp_f > 0.0f) {
                    ap += arp_inc; if (ap >= 1.0f) ap -= 1.0f;
                    s += (ap * 2.0f - 1.0f) * 0.05f;
                }
                // Voice 4: noise hi-hat (exponential decay)
                if (hihat_on) {
                    rng = rng * 1664525u + 1013904223u;
                    float n01 = (float)(int32_t)rng / (float)0x7FFFFFFF;
                    float env = Math::exp(-ht * 100.0f);
                    s += n01 * env * 0.045f;
                    ht += hihat_inv;
                    if (env < 0.001f) hihat_on = false;
                }
                // Voice 5: heartbeat kick drum (sine sweep 100→25 Hz, fast linear decay)
                if (kick_on_) {
                    float kt = kick_t_ + i * inv_sr;
                    if (kt < kick_dur_) {
                        float env = 1.0f - kt / kick_dur_;
                        float freq = 100.0f - 75.0f * (kt / kick_dur_);
                        s += Math::sin(kt * freq * Math_TAU) * env * 0.32f;
                    }
                }
                // Soft-clip to prevent clipping (tanh limiter)
                s = Math::tanh(s * 1.4f) / 1.4f;
                pb->push_frame(Vector2(s, s));
            }
            ret4[0] = lp; ret4[1] = bp; ret4[2] = ap; ret4[3] = ht;
            if (has_kick) ret4[4] = kick_t_ + nf * inv_sr;
            r_ret = ret4;
            return true;
        }
        return false;
    }

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

        // ── Builtin namespace sentinel (set by OP_GET_GLOBAL for SoundGen et al.) ──
        if (d.has("__vg_namespace")) {
            String ns = String(d["__vg_namespace"]);
            return call_builtin_for_base_variable(instance, ns, p_method, p_args, r_ret);
        }

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
