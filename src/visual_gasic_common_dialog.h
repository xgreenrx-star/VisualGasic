#ifndef VISUAL_GASIC_COMMON_DIALOG_H
#define VISUAL_GASIC_COMMON_DIALOG_H

// VGCommonDialog — VB6 CommonDialog control replacement
// Usage in VisualGasic:
//   Dim dlg As New CommonDialog
//   dlg.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
//   dlg.DialogTitle = "Open File"
//   dlg.ShowOpen
//   If dlg.FileName <> "" Then
//       Print "Selected: "; dlg.FileName
//   End If
//
//   dlg.ShowSave
//   dlg.ShowColor
//   dlg.ShowFont
//   dlg.ShowPrinter

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/classes/display_server.hpp>

using namespace godot;

class VGCommonDialog : public RefCounted {
    GDCLASS(VGCommonDialog, RefCounted);

    // File dialog properties
    String file_name;
    Array file_names;  // For multi-select
    String filter;
    String dialog_title;
    String initial_dir;
    int filter_index;
    bool multi_select;

    // Color dialog properties
    Color color;
    Array custom_colors;

    // Font dialog properties
    String font_name;
    float font_size;
    bool font_bold;
    bool font_italic;
    bool font_underline;
    Color font_color;

    // Dialog result
    bool cancelled;
    int dialog_type;  // Last shown dialog type

    // Internal completion tracking
    bool dialog_completed;
    void _on_file_selected(const String &p_path);
    void _on_files_selected(const PackedStringArray &p_paths);
    void _on_dir_selected(const String &p_path);

protected:
    static void _bind_methods();

public:
    VGCommonDialog();
    ~VGCommonDialog();

    // VB6 CommonDialog methods
    void show_open();
    void show_save();
    void show_color();
    void show_folder();

    // Properties
    void set_file_name(const String &p_name) { file_name = p_name; }
    String get_file_name() const { return file_name; }
    Array get_file_names() const { return file_names; }
    void set_filter(const String &p_filter) { filter = p_filter; }
    String get_filter() const { return filter; }
    void set_dialog_title(const String &p_title) { dialog_title = p_title; }
    String get_dialog_title() const { return dialog_title; }
    void set_initial_dir(const String &p_dir) { initial_dir = p_dir; }
    String get_initial_dir() const { return initial_dir; }
    void set_filter_index(int p_idx) { filter_index = p_idx; }
    int get_filter_index() const { return filter_index; }
    void set_multi_select(bool p_multi) { multi_select = p_multi; }
    bool get_multi_select() const { return multi_select; }

    // Color properties
    void set_color(const Color &p_color) { color = p_color; }
    Color get_color() const { return color; }

    // Font properties
    void set_font_name(const String &p_name) { font_name = p_name; }
    String get_font_name() const { return font_name; }
    void set_font_size(float p_size) { font_size = p_size; }
    float get_font_size() const { return font_size; }
    void set_font_bold(bool p_bold) { font_bold = p_bold; }
    bool get_font_bold() const { return font_bold; }

    // Status
    bool get_cancelled() const { return cancelled; }
};

#endif // VISUAL_GASIC_COMMON_DIALOG_H
