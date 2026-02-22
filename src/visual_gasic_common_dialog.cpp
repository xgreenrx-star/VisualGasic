// VGCommonDialog — VB6 CommonDialog control replacement
// Wraps Godot's DisplayServer file dialogs and OS color picker

#include "visual_gasic_common_dialog.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/engine.hpp>

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

    // VB6-style aliases
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
}

VGCommonDialog::~VGCommonDialog() {
}

// Parse VB6-style filter string: "Description|*.ext|Description2|*.ext2"
// into Godot-style filters
static PackedStringArray parse_vb6_filter(const String &p_filter) {
    PackedStringArray godot_filters;
    if (p_filter.is_empty()) return godot_filters;

    PackedStringArray parts = p_filter.split("|");
    // VB6 format: pairs of (description, pattern)
    for (int i = 0; i + 1 < parts.size(); i += 2) {
        String desc = parts[i].strip_edges();
        String pattern = parts[i + 1].strip_edges();
        // Godot format: "*.ext ; Description"
        godot_filters.push_back(pattern + " ; " + desc);
    }
    // If odd number of parts, last one is just a pattern
    if (parts.size() % 2 == 1) {
        godot_filters.push_back(parts[parts.size() - 1].strip_edges());
    }
    return godot_filters;
}

void VGCommonDialog::show_open() {
    cancelled = true;
    dialog_type = 1;
    file_name = "";
    file_names.clear();

    // Use Godot's DisplayServer for native file dialog
    DisplayServer *ds = DisplayServer::get_singleton();
    if (!ds) {
        UtilityFunctions::printerr("[VGCommonDialog] DisplayServer not available");
        return;
    }

    // Try the native file dialog path using OS::execute for zenity/kdialog on Linux
#ifdef __linux__
    // Build zenity command
    String cmd = "zenity --file-selection";
    if (!dialog_title.is_empty()) {
        cmd += " --title=\"" + dialog_title + "\"";
    }
    if (!initial_dir.is_empty()) {
        cmd += " --filename=\"" + initial_dir + "/\"";
    }
    if (!filter.is_empty()) {
        // Parse VB6 filter and add as zenity filters
        PackedStringArray parts = filter.split("|");
        for (int i = 0; i + 1 < parts.size(); i += 2) {
            cmd += " --file-filter=\"" + parts[i].strip_edges() + " | " + parts[i + 1].strip_edges() + "\"";
        }
    }
    if (multi_select) {
        cmd += " --multiple --separator=\"|\"";
    }

    // Execute synchronously
    Array output;
    int exit_code = OS::get_singleton()->execute("sh", PackedStringArray({"-c", cmd}), output, true);

    if (exit_code == 0 && output.size() > 0) {
        String result = String(output[0]).strip_edges();
        if (!result.is_empty()) {
            cancelled = false;
            if (multi_select) {
                PackedStringArray files = result.split("|");
                for (int i = 0; i < files.size(); i++) {
                    file_names.push_back(files[i]);
                }
                if (files.size() > 0) file_name = files[0];
            } else {
                file_name = result;
            }
        }
    }
#endif
    UtilityFunctions::print("[VGCommonDialog] ShowOpen: ", cancelled ? "Cancelled" : file_name);
}

void VGCommonDialog::show_save() {
    cancelled = true;
    dialog_type = 2;
    file_name = "";

#ifdef __linux__
    String cmd = "zenity --file-selection --save --confirm-overwrite";
    if (!dialog_title.is_empty()) {
        cmd += " --title=\"" + dialog_title + "\"";
    }
    if (!initial_dir.is_empty()) {
        cmd += " --filename=\"" + initial_dir + "/\"";
    }
    if (!filter.is_empty()) {
        PackedStringArray parts = filter.split("|");
        for (int i = 0; i + 1 < parts.size(); i += 2) {
            cmd += " --file-filter=\"" + parts[i].strip_edges() + " | " + parts[i + 1].strip_edges() + "\"";
        }
    }

    Array output;
    int exit_code = OS::get_singleton()->execute("sh", PackedStringArray({"-c", cmd}), output, true);
    if (exit_code == 0 && output.size() > 0) {
        String result = String(output[0]).strip_edges();
        if (!result.is_empty()) {
            cancelled = false;
            file_name = result;
        }
    }
#endif
    UtilityFunctions::print("[VGCommonDialog] ShowSave: ", cancelled ? "Cancelled" : file_name);
}

void VGCommonDialog::show_color() {
    cancelled = true;
    dialog_type = 3;

#ifdef __linux__
    // Zenity color selection
    String hex = color.to_html(false);
    String cmd = "zenity --color-selection --color=\"#" + hex + "\"";
    if (!dialog_title.is_empty()) {
        cmd += " --title=\"" + dialog_title + "\"";
    }

    Array output;
    int exit_code = OS::get_singleton()->execute("sh", PackedStringArray({"-c", cmd}), output, true);
    if (exit_code == 0 && output.size() > 0) {
        String result = String(output[0]).strip_edges();
        if (!result.is_empty()) {
            cancelled = false;
            // Zenity returns "rgb(r,g,b)" or "#RRGGBB" format
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
#endif
    UtilityFunctions::print("[VGCommonDialog] ShowColor: ", cancelled ? "Cancelled" : color.to_html());
}

void VGCommonDialog::show_folder() {
    cancelled = true;
    dialog_type = 4;
    file_name = "";

#ifdef __linux__
    String cmd = "zenity --file-selection --directory";
    if (!dialog_title.is_empty()) {
        cmd += " --title=\"" + dialog_title + "\"";
    }
    if (!initial_dir.is_empty()) {
        cmd += " --filename=\"" + initial_dir + "/\"";
    }

    Array output;
    int exit_code = OS::get_singleton()->execute("sh", PackedStringArray({"-c", cmd}), output, true);
    if (exit_code == 0 && output.size() > 0) {
        String result = String(output[0]).strip_edges();
        if (!result.is_empty()) {
            cancelled = false;
            file_name = result;
        }
    }
#endif
    UtilityFunctions::print("[VGCommonDialog] ShowFolder: ", cancelled ? "Cancelled" : file_name);
}
