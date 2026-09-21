// VGCommonDialog — VB6 CommonDialog control replacement
// Wraps Godot DisplayServer native dialogs with OS-shell and FileDialog fallbacks.

#include "visual_gasic_common_dialog.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/file_dialog.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/main_loop.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/memory.hpp>

using namespace godot;

void VGCommonDialog::_bind_methods() {
    ClassDB::bind_method(D_METHOD("show_open"), &VGCommonDialog::show_open);
    ClassDB::bind_method(D_METHOD("show_save"), &VGCommonDialog::show_save);
    ClassDB::bind_method(D_METHOD("show_color"), &VGCommonDialog::show_color);
    ClassDB::bind_method(D_METHOD("show_folder"), &VGCommonDialog::show_folder);

    ClassDB::bind_method(D_METHOD("set_file_name", "name"), &VGCommonDialog::set_file_name);
    ClassDB::bind_method(D_METHOD("get_file_name"), &VGCommonDialog::get_file_name);
    ClassDB::bind_method(D_METHOD("get_file_names"), &VGCommonDialog::get_file_names);
    ClassDB::bind_method(D_METHOD("set_filter", "filter"), &VGCommonDialog::set_filter);
    ClassDB::bind_method(D_METHOD("get_filter"), &VGCommonDialog::get_filter);
    ClassDB::bind_method(D_METHOD("set_dialog_title", "title"), &VGCommonDialog::set_dialog_title);
    ClassDB::bind_method(D_METHOD("get_dialog_title"), &VGCommonDialog::get_dialog_title);
    ClassDB::bind_method(D_METHOD("set_initial_dir", "dir"), &VGCommonDialog::set_initial_dir);
    ClassDB::bind_method(D_METHOD("get_initial_dir"), &VGCommonDialog::get_initial_dir);
    ClassDB::bind_method(D_METHOD("set_filter_index", "index"), &VGCommonDialog::set_filter_index);
    ClassDB::bind_method(D_METHOD("get_filter_index"), &VGCommonDialog::get_filter_index);
    ClassDB::bind_method(D_METHOD("set_multi_select", "multi"), &VGCommonDialog::set_multi_select);
    ClassDB::bind_method(D_METHOD("get_multi_select"), &VGCommonDialog::get_multi_select);
    ClassDB::bind_method(D_METHOD("set_color", "color"), &VGCommonDialog::set_color);
    ClassDB::bind_method(D_METHOD("get_color"), &VGCommonDialog::get_color);
    ClassDB::bind_method(D_METHOD("set_font_name", "name"), &VGCommonDialog::set_font_name);
    ClassDB::bind_method(D_METHOD("get_font_name"), &VGCommonDialog::get_font_name);
    ClassDB::bind_method(D_METHOD("set_font_size", "size"), &VGCommonDialog::set_font_size);
    ClassDB::bind_method(D_METHOD("get_font_size"), &VGCommonDialog::get_font_size);
    ClassDB::bind_method(D_METHOD("set_font_bold", "bold"), &VGCommonDialog::set_font_bold);
    ClassDB::bind_method(D_METHOD("get_font_bold"), &VGCommonDialog::get_font_bold);
    ClassDB::bind_method(D_METHOD("get_cancelled"), &VGCommonDialog::get_cancelled);

    ClassDB::bind_method(D_METHOD("_on_native_file_dialog", "status", "paths", "filter_index"), &VGCommonDialog::_on_native_file_dialog);
    ClassDB::bind_method(D_METHOD("_on_file_selected", "path"), &VGCommonDialog::_on_file_selected);
    ClassDB::bind_method(D_METHOD("_on_files_selected", "paths"), &VGCommonDialog::_on_files_selected);
    ClassDB::bind_method(D_METHOD("_on_dir_selected", "path"), &VGCommonDialog::_on_dir_selected);
    ClassDB::bind_method(D_METHOD("_on_file_dialog_canceled"), &VGCommonDialog::_on_file_dialog_canceled);
    ClassDB::bind_method(D_METHOD("_on_color_picked", "status", "color"), &VGCommonDialog::_on_color_picked);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "FileName"), "set_file_name", "get_file_name");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Filter"), "set_filter", "get_filter");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "DialogTitle"), "set_dialog_title", "get_dialog_title");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "InitDir"), "set_initial_dir", "get_initial_dir");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "FilterIndex"), "set_filter_index", "get_filter_index");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "MultiSelect"), "set_multi_select", "get_multi_select");
    ADD_PROPERTY(PropertyInfo(Variant::COLOR, "Color"), "set_color", "get_color");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "FontName"), "set_font_name", "get_font_name");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "FontSize"), "set_font_size", "get_font_size");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "FontBold"), "set_font_bold", "get_font_bold");

    ClassDB::bind_method(D_METHOD("ShowOpen"), &VGCommonDialog::show_open);
    ClassDB::bind_method(D_METHOD("ShowSave"), &VGCommonDialog::show_save);
    ClassDB::bind_method(D_METHOD("ShowColor"), &VGCommonDialog::show_color);
    ClassDB::bind_method(D_METHOD("ShowFolder"), &VGCommonDialog::show_folder);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "Cancelled"), "", "get_cancelled");
}

VGCommonDialog::VGCommonDialog() {
    filter_index = 0;
    multi_select = false;
    font_size = 12.0f;
    font_bold = false;
    font_italic = false;
    font_underline = false;
    font_color = Color(0, 0, 0, 1);
    cancelled = false;
    dialog_type = 0;
    dialog_completed = false;
    color = Color(1, 1, 1, 1);
    pending_fd = nullptr;
}

VGCommonDialog::~VGCommonDialog() {
}

// VB6 uses semicolons between extensions (*.txt;*.doc); Godot 4 uses commas (*.txt,*.doc).
static String vb6_pattern_to_godot(const String &p_pattern) {
    PackedStringArray exts = p_pattern.split(";");
    String result;
    for (int i = 0; i < exts.size(); i++) {
        String ext = exts[i].strip_edges();
        if (ext.is_empty()) {
            continue;
        }
        if (!result.is_empty()) {
            result += ",";
        }
        result += ext;
    }
    return result.is_empty() ? String("*.*") : result;
}

static String extension_glob_to_mime(const String &p_glob) {
    String ext = p_glob.strip_edges();
    if (ext.begins_with("*.")) {
        ext = ext.substr(2);
    }
    if (ext == "*" || ext == "*.*") {
        return "application/octet-stream";
    }
    if (ext == "png") {
        return "image/png";
    }
    if (ext == "jpg" || ext == "jpeg") {
        return "image/jpeg";
    }
    if (ext == "wav") {
        return "audio/wav";
    }
    if (ext == "ogg") {
        return "audio/ogg";
    }
    return "application/octet-stream";
}

static String godot_pattern_to_mime_list(const String &p_pattern) {
    PackedStringArray globs = p_pattern.split(",");
    String result;
    for (int i = 0; i < globs.size(); i++) {
        String mime = extension_glob_to_mime(globs[i]);
        if (!result.is_empty()) {
            result += ",";
        }
        result += mime;
    }
    return result;
}

static void apply_vb6_filters_to_filedialog(FileDialog *p_fd, const String &p_filter) {
    p_fd->clear_filters();
    if (p_filter.is_empty()) {
        return;
    }

    PackedStringArray parts = p_filter.split("|");
    for (int i = 0; i + 1 < parts.size(); i += 2) {
        String desc = parts[i].strip_edges();
        String pattern = vb6_pattern_to_godot(parts[i + 1].strip_edges());
        p_fd->add_filter(pattern, desc);
    }
}

// Build DisplayServer portal filters (pattern;description;mime) like FileDialog.update_filters().
static PackedStringArray build_portal_filters(const String &p_filter) {
    PackedStringArray portal_filters;
    if (p_filter.is_empty()) {
        return portal_filters;
    }

    DisplayServer *ds = DisplayServer::get_singleton();
    const bool with_mime = ds && ds->has_feature(DisplayServer::FEATURE_NATIVE_DIALOG_FILE_MIME);

    PackedStringArray parts = p_filter.split("|");
    for (int i = 0; i + 1 < parts.size(); i += 2) {
        String desc = parts[i].strip_edges();
        String flt = vb6_pattern_to_godot(parts[i + 1].strip_edges());
        String mime = with_mime ? godot_pattern_to_mime_list(flt) : String();
        String native_name = flt;
        if (with_mime && !mime.is_empty()) {
            native_name += ", " + mime;
        }
        if (desc.is_empty()) {
            portal_filters.push_back(flt + ";(" + native_name + ");" + mime);
        } else {
            portal_filters.push_back(flt + ";" + desc + " (" + native_name + ");" + mime);
        }
    }

    portal_filters.push_back("*.*;All Files (*.*);application/octet-stream");
    return portal_filters;
}

void VGCommonDialog::_reset_file_result() {
    cancelled = true;
    file_name = "";
    file_names.clear();
    filter_index = 0;
    dialog_completed = false;
}

void VGCommonDialog::_apply_file_result(bool p_ok, const PackedStringArray &p_paths, int p_filter_idx) {
    dialog_completed = true;
    filter_index = p_filter_idx;
    if (!p_ok || p_paths.is_empty()) {
        cancelled = true;
        return;
    }

    cancelled = false;
    file_names.clear();
    for (int i = 0; i < p_paths.size(); i++) {
        file_names.push_back(p_paths[i]);
    }
    file_name = p_paths[0];
}

void VGCommonDialog::_wait_for_dialog() {
    DisplayServer *ds = DisplayServer::get_singleton();
    if (!ds) {
        dialog_completed = true;
        return;
    }

    MainLoop *ml = Engine::get_singleton()->get_main_loop();
    const uint64_t deadline = Time::get_singleton()->get_ticks_msec() + 600000; // 10 minutes

    while (!dialog_completed && Time::get_singleton()->get_ticks_msec() < deadline) {
        if (ml && pending_fd) {
            ml->call("_process", 0.016);
        }
        ds->process_events();
    }

    if (pending_fd) {
        pending_fd->queue_free();
        pending_fd = nullptr;
    }
}

void VGCommonDialog::_on_native_file_dialog(bool p_status, const PackedStringArray &p_paths, int p_filter_idx) {
    _apply_file_result(p_status, p_paths, p_filter_idx);
}

void VGCommonDialog::_on_file_selected(const String &p_path) {
    PackedStringArray paths;
    paths.push_back(p_path);
    _apply_file_result(true, paths, filter_index);
}

void VGCommonDialog::_on_files_selected(const PackedStringArray &p_paths) {
    _apply_file_result(true, p_paths, filter_index);
}

void VGCommonDialog::_on_dir_selected(const String &p_path) {
    PackedStringArray paths;
    paths.push_back(p_path);
    _apply_file_result(true, paths, filter_index);
}

void VGCommonDialog::_on_file_dialog_canceled() {
    dialog_completed = true;
    cancelled = true;
}

void VGCommonDialog::_on_color_picked(bool p_status, const Color &p_picked) {
    dialog_completed = true;
    if (p_status) {
        cancelled = false;
        color = p_picked;
    } else {
        cancelled = true;
    }
}

bool VGCommonDialog::_show_display_server_file_dialog(DisplayServer::FileDialogMode p_mode) {
    DisplayServer *ds = DisplayServer::get_singleton();
    if (!ds || !ds->has_feature(DisplayServer::FEATURE_NATIVE_DIALOG_FILE)) {
        return false;
    }

    String current_dir = initial_dir;
    String current_file = file_name;
    if (current_dir.is_empty() && !current_file.is_empty()) {
        current_dir = current_file.get_base_dir();
        current_file = current_file.get_file();
    }
    if (current_dir.is_empty()) {
        current_dir = OS::get_singleton()->get_environment("HOME");
    }

    DisplayServer::FileDialogMode mode = p_mode;
    if (p_mode == DisplayServer::FILE_DIALOG_MODE_OPEN_FILE && multi_select) {
        mode = DisplayServer::FILE_DIALOG_MODE_OPEN_FILES;
    }

    PackedStringArray filters = build_portal_filters(filter);
    String title = dialog_title.is_empty() ? String("Select File") : dialog_title;

    Error err = ds->file_dialog_show(
            title,
            current_dir,
            current_file,
            false,
            mode,
            filters,
            callable_mp(this, &VGCommonDialog::_on_native_file_dialog));

    if (err != OK) {
        return false;
    }

    _wait_for_dialog();
    return dialog_completed;
}

bool VGCommonDialog::_show_os_shell_file_dialog(DisplayServer::FileDialogMode p_mode) {
    OS *os = OS::get_singleton();
    if (!os) {
        return false;
    }

    String os_name = os->get_name();
    String title = dialog_title.is_empty() ? String("Select File") : dialog_title;
    String dir = initial_dir;
    if (dir.is_empty() && !file_name.is_empty()) {
        dir = file_name.get_base_dir();
    }

    // --- Windows: PowerShell Open/SaveFileDialog ---
    if (os_name == "Windows") {
        String dotnet_filter = filter.is_empty() ? String("All Files (*.*)|*.*") : filter;
        String safe_title = title.replace("'", "''");
        String safe_filter = dotnet_filter.replace("'", "''");
        String safe_dir = dir.replace("'", "''");
        String safe_file = file_name.get_file().replace("'", "''");

        String dialog_type_name = "OpenFileDialog";
        if (p_mode == DisplayServer::FILE_DIALOG_MODE_SAVE_FILE) {
            dialog_type_name = "SaveFileDialog";
        }

        String ps_cmd = String("Add-Type -AssemblyName System.Windows.Forms; ")
                + "$dlg = New-Object System.Windows.Forms." + dialog_type_name + "; "
                + "$dlg.Title = '" + safe_title + "'; ";
        if (!safe_filter.is_empty()) {
            ps_cmd += "$dlg.Filter = '" + safe_filter + "'; ";
        }
        if (!safe_dir.is_empty()) {
            ps_cmd += "$dlg.InitialDirectory = '" + safe_dir + "'; ";
        }
        if (!safe_file.is_empty() && p_mode == DisplayServer::FILE_DIALOG_MODE_SAVE_FILE) {
            ps_cmd += "$dlg.FileName = '" + safe_file + "'; ";
        }
        if (p_mode == DisplayServer::FILE_DIALOG_MODE_OPEN_FILES && multi_select) {
            ps_cmd += "$dlg.Multiselect = $true; ";
        }
        if (p_mode == DisplayServer::FILE_DIALOG_MODE_OPEN_DIR) {
            ps_cmd = String("Add-Type -AssemblyName System.Windows.Forms; ")
                    + "$dlg = New-Object System.Windows.Forms.FolderBrowserDialog; "
                    + "$dlg.Description = '" + safe_title + "'; ";
            if (!safe_dir.is_empty()) {
                ps_cmd += "$dlg.SelectedPath = '" + safe_dir + "'; ";
            }
            ps_cmd += "if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $dlg.SelectedPath }";
        } else {
            String result_expr = (multi_select && p_mode != DisplayServer::FILE_DIALOG_MODE_SAVE_FILE)
                    ? String("$dlg.FileNames -join '|'")
                    : String("$dlg.FileName");
            ps_cmd += "if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { " + result_expr + " }";
        }

        PackedStringArray args;
        args.push_back("-NoProfile");
        args.push_back("-Command");
        args.push_back(ps_cmd);
        Array output;
        os->execute("powershell", args, output);

        if (output.size() > 0) {
            String result = String(output[0]).strip_edges();
            if (!result.is_empty()) {
                PackedStringArray paths;
                if (multi_select && p_mode != DisplayServer::FILE_DIALOG_MODE_SAVE_FILE) {
                    paths = result.split("|");
                } else {
                    paths.push_back(result);
                }
                _apply_file_result(true, paths, 0);
                return true;
            }
        }
        dialog_completed = true;
        return true;
    }

    // --- macOS: osascript choose file/folder ---
    if (os_name == "macOS") {
        String safe_title = title.replace("\\", "\\\\").replace("\"", "\\\"");
        String script;
        if (p_mode == DisplayServer::FILE_DIALOG_MODE_SAVE_FILE) {
            String default_name = file_name.get_file();
            if (default_name.is_empty()) {
                default_name = "untitled.txt";
            }
            String safe_name = default_name.replace("\\", "\\\\").replace("\"", "\\\"");
            script = "POSIX path of (choose file name with prompt \"" + safe_title + "\" default name \"" + safe_name + "\")";
        } else if (p_mode == DisplayServer::FILE_DIALOG_MODE_OPEN_DIR) {
            script = "POSIX path of (choose folder with prompt \"" + safe_title + "\")";
        } else {
            script = "POSIX path of (choose file with prompt \"" + safe_title + "\")";
        }

        PackedStringArray args;
        args.push_back("-e");
        args.push_back(script);
        Array output;
        int64_t exit_code = os->execute("osascript", args, output);
        if (exit_code == 0 && output.size() > 0) {
            String result = String(output[0]).strip_edges();
            if (!result.is_empty()) {
                PackedStringArray paths;
                paths.push_back(result);
                _apply_file_result(true, paths, 0);
                return true;
            }
        }
        dialog_completed = true;
        return true;
    }

    // --- Linux / FreeBSD: zenity → kdialog ---
    if (os_name == "Linux" || os_name == "FreeBSD") {
        String cmd;
        if (p_mode == DisplayServer::FILE_DIALOG_MODE_SAVE_FILE) {
            cmd = "zenity --file-selection --save --confirm-overwrite";
        } else if (p_mode == DisplayServer::FILE_DIALOG_MODE_OPEN_DIR) {
            cmd = "zenity --file-selection --directory";
        } else {
            cmd = "zenity --file-selection";
            if (multi_select) {
                cmd += " --multiple --separator=\"|\"";
            }
        }

        if (!title.is_empty()) {
            cmd += " --title=\"" + title + "\"";
        }
        if (!dir.is_empty()) {
            cmd += " --filename=\"" + dir + "/\"";
        }
        if (!filter.is_empty() && p_mode != DisplayServer::FILE_DIALOG_MODE_OPEN_DIR) {
            PackedStringArray parts = filter.split("|");
            for (int i = 0; i + 1 < parts.size(); i += 2) {
                cmd += " --file-filter=\"" + parts[i].strip_edges() + " | " + parts[i + 1].strip_edges() + "\"";
            }
        }
        if (!file_name.is_empty() && p_mode == DisplayServer::FILE_DIALOG_MODE_SAVE_FILE) {
            cmd += " --filename=\"" + file_name + "\"";
        }

        Array output;
        int exit_code = os->execute("sh", PackedStringArray({ "-c", cmd }), output, true);
        if (exit_code == 0 && output.size() > 0) {
            String result = String(output[0]).strip_edges();
            if (!result.is_empty()) {
                PackedStringArray paths;
                if (multi_select && p_mode != DisplayServer::FILE_DIALOG_MODE_SAVE_FILE) {
                    paths = result.split("|");
                } else {
                    paths.push_back(result);
                }
                _apply_file_result(true, paths, 0);
                return true;
            }
        }

        // kdialog fallback
        PackedStringArray w;
        w.push_back("kdialog");
        if (os->execute("which", w, Array()) == 0) {
            PackedStringArray kargs;
            if (p_mode == DisplayServer::FILE_DIALOG_MODE_SAVE_FILE) {
                kargs.push_back("--getsavefilename");
                kargs.push_back(dir.is_empty() ? file_name : dir.path_join(file_name.get_file()));
                kargs.push_back(filter.is_empty() ? "*.*" : filter);
            } else if (p_mode == DisplayServer::FILE_DIALOG_MODE_OPEN_DIR) {
                kargs.push_back("--getexistingdirectory");
                kargs.push_back(dir.is_empty() ? "." : dir);
            } else {
                kargs.push_back("--getopenfilename");
                kargs.push_back(dir.is_empty() ? "." : dir);
                kargs.push_back(filter.is_empty() ? "*.*" : filter);
            }
            kargs.push_back("--title");
            kargs.push_back(title);

            Array koutput;
            int kexit = os->execute("kdialog", kargs, koutput, true);
            if (kexit == 0 && koutput.size() > 0) {
                String result = String(koutput[0]).strip_edges();
                if (!result.is_empty()) {
                    PackedStringArray paths;
                    paths.push_back(result);
                    _apply_file_result(true, paths, 0);
                    return true;
                }
            }
        }

        dialog_completed = true;
        return true;
    }

    return false;
}

bool VGCommonDialog::_show_godot_file_dialog(DisplayServer::FileDialogMode p_mode) {
    MainLoop *ml = Engine::get_singleton()->get_main_loop();
    SceneTree *tree = Object::cast_to<SceneTree>(ml);
    if (!tree || !tree->get_root()) {
        return false;
    }

    FileDialog *fd = memnew(FileDialog);
    pending_fd = fd;
    fd->set_access(FileDialog::ACCESS_FILESYSTEM);
    fd->set_use_native_dialog(true);
    fd->set_title(dialog_title.is_empty() ? String("Select File") : dialog_title);

    if (!initial_dir.is_empty()) {
        fd->set_current_dir(initial_dir);
    } else if (!file_name.is_empty()) {
        fd->set_current_dir(file_name.get_base_dir());
    }
    if (!file_name.is_empty()) {
        fd->set_current_file(file_name.get_file());
    }

    apply_vb6_filters_to_filedialog(fd, filter);

    switch (p_mode) {
        case DisplayServer::FILE_DIALOG_MODE_SAVE_FILE:
            fd->set_file_mode(FileDialog::FILE_MODE_SAVE_FILE);
            break;
        case DisplayServer::FILE_DIALOG_MODE_OPEN_DIR:
            fd->set_file_mode(FileDialog::FILE_MODE_OPEN_DIR);
            break;
        case DisplayServer::FILE_DIALOG_MODE_OPEN_FILES:
            fd->set_file_mode(FileDialog::FILE_MODE_OPEN_FILES);
            break;
        default:
            fd->set_file_mode(multi_select ? FileDialog::FILE_MODE_OPEN_FILES : FileDialog::FILE_MODE_OPEN_FILE);
            break;
    }

    fd->connect("file_selected", callable_mp(this, &VGCommonDialog::_on_file_selected));
    fd->connect("files_selected", callable_mp(this, &VGCommonDialog::_on_files_selected));
    fd->connect("dir_selected", callable_mp(this, &VGCommonDialog::_on_dir_selected));
    fd->connect("canceled", callable_mp(this, &VGCommonDialog::_on_file_dialog_canceled));

    tree->get_root()->add_child(fd);
    fd->popup_centered();
    _wait_for_dialog();
    return dialog_completed;
}

void VGCommonDialog::_show_file_dialog(DisplayServer::FileDialogMode p_mode) {
    _reset_file_result();
    RenderingServer::get_singleton()->force_draw(true, 0.0);

    // Prefer Godot FileDialog native path — it builds portal-safe filter metadata (incl. MIME).
    if (_show_godot_file_dialog(p_mode)) {
        return;
    }
    if (_show_os_shell_file_dialog(p_mode)) {
        return;
    }
    if (_show_display_server_file_dialog(p_mode)) {
        return;
    }

    UtilityFunctions::printerr("[VGCommonDialog] No file dialog backend available on this platform");
    dialog_completed = true;
}

bool VGCommonDialog::_show_display_server_color_picker() {
    DisplayServer *ds = DisplayServer::get_singleton();
    if (!ds || !ds->has_feature(DisplayServer::FEATURE_NATIVE_COLOR_PICKER)) {
        return false;
    }

    dialog_completed = false;
    if (!ds->color_picker(callable_mp(this, &VGCommonDialog::_on_color_picked))) {
        return false;
    }

    _wait_for_dialog();
    return dialog_completed;
}

bool VGCommonDialog::_show_os_shell_color_picker() {
    OS *os = OS::get_singleton();
    if (!os) {
        return false;
    }

    String os_name = os->get_name();
    String title = dialog_title.is_empty() ? String("Choose Color") : dialog_title;

    if (os_name == "Linux" || os_name == "FreeBSD") {
        String hex = color.to_html(false);
        String cmd = "zenity --color-selection --color=\"#" + hex + "\"";
        if (!title.is_empty()) {
            cmd += " --title=\"" + title + "\"";
        }

        Array output;
        int exit_code = os->execute("sh", PackedStringArray({ "-c", cmd }), output, true);
        dialog_completed = true;
        if (exit_code == 0 && output.size() > 0) {
            String result = String(output[0]).strip_edges();
            if (!result.is_empty()) {
                cancelled = false;
                if (result.begins_with("rgb(")) {
                    result = result.replace("rgb(", "").replace(")", "");
                    PackedStringArray rgb = result.split(",");
                    if (rgb.size() >= 3) {
                        color = Color(rgb[0].strip_edges().to_float() / 255.0f,
                                rgb[1].strip_edges().to_float() / 255.0f,
                                rgb[2].strip_edges().to_float() / 255.0f);
                    }
                } else if (result.begins_with("#")) {
                    color = Color::html(result);
                }
            }
        }
        return true;
    }

    return false;
}

void VGCommonDialog::show_open() {
    dialog_type = 1;
    _show_file_dialog(DisplayServer::FILE_DIALOG_MODE_OPEN_FILE);
    UtilityFunctions::print("[VGCommonDialog] ShowOpen: ", cancelled ? "Cancelled" : file_name);
}

void VGCommonDialog::show_save() {
    dialog_type = 2;
    _show_file_dialog(DisplayServer::FILE_DIALOG_MODE_SAVE_FILE);
    UtilityFunctions::print("[VGCommonDialog] ShowSave: ", cancelled ? "Cancelled" : file_name);
}

void VGCommonDialog::show_folder() {
    dialog_type = 4;
    _show_file_dialog(DisplayServer::FILE_DIALOG_MODE_OPEN_DIR);
    UtilityFunctions::print("[VGCommonDialog] ShowFolder: ", cancelled ? "Cancelled" : file_name);
}

void VGCommonDialog::show_color() {
    cancelled = true;
    dialog_type = 3;
    dialog_completed = false;
    RenderingServer::get_singleton()->force_draw(true, 0.0);

    if (_show_display_server_color_picker()) {
        UtilityFunctions::print("[VGCommonDialog] ShowColor: ", cancelled ? "Cancelled" : color.to_html());
        return;
    }
    if (_show_os_shell_color_picker()) {
        UtilityFunctions::print("[VGCommonDialog] ShowColor: ", cancelled ? "Cancelled" : color.to_html());
        return;
    }

    UtilityFunctions::printerr("[VGCommonDialog] ShowColor: no color picker backend on this platform");
    dialog_completed = true;
    UtilityFunctions::print("[VGCommonDialog] ShowColor: Cancelled");
}
