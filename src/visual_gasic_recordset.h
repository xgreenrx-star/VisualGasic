#ifndef VISUAL_GASIC_RECORDSET_H
#define VISUAL_GASIC_RECORDSET_H

// VGRecordset — VB6 ADODB.Recordset-compatible cursor over SQLite query results
//
// Usage in VisualGasic:
//   Dim rs As New Recordset
//   rs.Open "SELECT * FROM users", db
//   Do While Not rs.EOF
//       Print rs.Fields("name")
//       rs.MoveNext
//   Loop
//   rs.Close
//
//   ' Or with AddNew/Update:
//   rs.Open "users", db
//   rs.AddNew
//   rs.Fields("name") = "Bob"
//   rs.Update

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

class VGDatabase;

class VGRecordset : public RefCounted {
    GDCLASS(VGRecordset, RefCounted);

    // Internal data
    Array rows;                     // Array of Dictionary (each row keyed by column name)
    PackedStringArray column_names; // Column names in order
    int cursor;                     // Current row index (-1 = BOF, rows.size() = EOF)
    bool is_open;
    String source_sql;              // Original SQL or table name
    String table_name;              // Resolved table name for mutations
    Ref<VGDatabase> db_ref;         // Reference to the database connection

    // Edit buffer for AddNew/Update
    Dictionary edit_buffer;
    bool in_add_new;
    bool in_edit;

    // Internal helpers
    void _extract_column_names();
    String _detect_table_name(const String &p_source);
    Dictionary _build_where_clause();

protected:
    static void _bind_methods();

public:
    VGRecordset();
    ~VGRecordset();

    // Open / Close
    void open(const String &p_source, const Ref<VGDatabase> &p_db);
    void close();
    void requery();

    // Navigation
    void move_first();
    void move_next();
    void move_previous();
    void move_last();
    void move_to(int p_index);

    // State
    bool get_bof() const;
    bool get_eof() const;
    int get_record_count() const;
    int get_absolute_position() const;
    void set_absolute_position(int p_pos);
    bool get_is_open() const { return is_open; }

    // Fields access
    Variant fields(const Variant &p_name_or_index) const;
    void set_field(const String &p_name, const Variant &p_value);
    PackedStringArray get_column_names() const { return column_names; }
    int get_field_count() const { return column_names.size(); }

    // Mutation
    void add_new();
    void update();
    void edit_record();
    void delete_record();
    void cancel_update();

    // Bulk access
    Array get_rows() const { return rows; }
    Dictionary get_current_row() const;
    Array get_all_values(const String &p_field_name) const;

    // Bookmark (simple integer bookmark)
    int get_bookmark() const;
    void set_bookmark(int p_bookmark);
};

#endif // VISUAL_GASIC_RECORDSET_H
