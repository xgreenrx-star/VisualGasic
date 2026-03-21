#include "visual_gasic_recordset.h"
#include "visual_gasic_database.h"

using namespace godot;

VGRecordset::VGRecordset() {
    cursor = -1;
    is_open = false;
    in_add_new = false;
    in_edit = false;
}

VGRecordset::~VGRecordset() {
    close();
}

// =============================================================================
// Open / Close
// =============================================================================

void VGRecordset::open(const String &p_source, const Ref<VGDatabase> &p_db) {
    if (is_open) {
        close();
    }
    if (p_db.is_null() || !p_db->get_is_open()) {
        ERR_PRINT("VGRecordset::Open — database is not open");
        return;
    }
    db_ref = p_db;
    source_sql = p_source;
    table_name = _detect_table_name(p_source);

    // If source is just a table name (no SELECT), wrap it
    String sql = p_source.strip_edges();
    if (!sql.to_upper().begins_with("SELECT")) {
        sql = "SELECT * FROM " + sql;
    }

    rows = db_ref->query(sql);
    _extract_column_names();
    is_open = true;
    cursor = rows.size() > 0 ? 0 : -1;
    in_add_new = false;
    in_edit = false;
}

void VGRecordset::close() {
    if (in_add_new || in_edit) {
        cancel_update();
    }
    rows.clear();
    column_names = PackedStringArray();
    cursor = -1;
    is_open = false;
    db_ref = Ref<VGDatabase>();
    source_sql = "";
    table_name = "";
}

void VGRecordset::requery() {
    if (!is_open || db_ref.is_null()) {
        ERR_PRINT("VGRecordset::Requery — recordset is not open");
        return;
    }
    String sql = source_sql.strip_edges();
    if (!sql.to_upper().begins_with("SELECT")) {
        sql = "SELECT * FROM " + sql;
    }
    rows = db_ref->query(sql);
    _extract_column_names();
    cursor = rows.size() > 0 ? 0 : -1;
    in_add_new = false;
    in_edit = false;
}

// =============================================================================
// Navigation
// =============================================================================

void VGRecordset::move_first() {
    if (!is_open || rows.size() == 0) return;
    cursor = 0;
}

void VGRecordset::move_next() {
    if (!is_open) return;
    if (cursor < rows.size()) {
        cursor++;
    }
}

void VGRecordset::move_previous() {
    if (!is_open) return;
    if (cursor > 0) {
        cursor--;
    } else {
        cursor = -1; // BOF
    }
}

void VGRecordset::move_last() {
    if (!is_open || rows.size() == 0) return;
    cursor = rows.size() - 1;
}

void VGRecordset::move_to(int p_index) {
    if (!is_open) return;
    if (p_index < 0) {
        cursor = -1;
    } else if (p_index >= rows.size()) {
        cursor = rows.size();
    } else {
        cursor = p_index;
    }
}

// =============================================================================
// State
// =============================================================================

bool VGRecordset::get_bof() const {
    return cursor < 0 || rows.size() == 0;
}

bool VGRecordset::get_eof() const {
    return cursor >= rows.size() || rows.size() == 0;
}

int VGRecordset::get_record_count() const {
    return rows.size();
}

int VGRecordset::get_absolute_position() const {
    return cursor;
}

void VGRecordset::set_absolute_position(int p_pos) {
    move_to(p_pos);
}

// =============================================================================
// Fields Access
// =============================================================================

Variant VGRecordset::fields(const Variant &p_name_or_index) const {
    if (!is_open || get_bof() || get_eof()) {
        return Variant();
    }
    Dictionary row = rows[cursor];

    if (p_name_or_index.get_type() == Variant::STRING) {
        String name = p_name_or_index;
        if (row.has(name)) {
            return row[name];
        }
        // Case-insensitive fallback
        Array keys = row.keys();
        for (int i = 0; i < keys.size(); i++) {
            String k = keys[i];
            if (k.to_lower() == name.to_lower()) {
                return row[k];
            }
        }
        return Variant();
    } else if (p_name_or_index.get_type() == Variant::INT || p_name_or_index.get_type() == Variant::FLOAT) {
        int idx = p_name_or_index;
        if (idx >= 0 && idx < column_names.size()) {
            String key = column_names[idx];
            return row.get(key, Variant());
        }
        return Variant();
    }
    return Variant();
}

void VGRecordset::set_field(const String &p_name, const Variant &p_value) {
    if (!in_add_new && !in_edit) {
        ERR_PRINT("VGRecordset: Must call AddNew or Edit before setting field values");
        return;
    }
    edit_buffer[p_name] = p_value;
}

Dictionary VGRecordset::get_current_row() const {
    if (!is_open || get_bof() || get_eof()) {
        return Dictionary();
    }
    return rows[cursor];
}

Array VGRecordset::get_all_values(const String &p_field_name) const {
    Array result;
    for (int i = 0; i < rows.size(); i++) {
        Dictionary row = rows[i];
        if (row.has(p_field_name)) {
            result.append(row[p_field_name]);
        }
    }
    return result;
}

// =============================================================================
// Mutation
// =============================================================================

void VGRecordset::add_new() {
    if (!is_open) {
        ERR_PRINT("VGRecordset::AddNew — recordset is not open");
        return;
    }
    edit_buffer.clear();
    in_add_new = true;
    in_edit = false;
}

void VGRecordset::edit_record() {
    if (!is_open || get_bof() || get_eof()) {
        ERR_PRINT("VGRecordset::Edit — no current record");
        return;
    }
    edit_buffer = Dictionary(rows[cursor]); // Copy current row
    in_edit = true;
    in_add_new = false;
}

void VGRecordset::update() {
    if (!is_open || db_ref.is_null()) {
        ERR_PRINT("VGRecordset::Update — recordset is not open");
        return;
    }
    if (table_name.is_empty()) {
        ERR_PRINT("VGRecordset::Update — cannot determine table name for updates");
        return;
    }

    if (in_add_new) {
        // INSERT
        Array keys_arr = edit_buffer.keys();
        if (keys_arr.size() == 0) {
            in_add_new = false;
            return;
        }
        String cols = "";
        String vals = "";
        Array params;
        for (int i = 0; i < keys_arr.size(); i++) {
            if (i > 0) { cols += ", "; vals += ", "; }
            cols += String(keys_arr[i]);
            vals += "?";
            params.append(edit_buffer[keys_arr[i]]);
        }
        String sql = "INSERT INTO " + table_name + " (" + cols + ") VALUES (" + vals + ")";
        db_ref->execute_params(sql, params);
        in_add_new = false;
        edit_buffer.clear();
        requery();

    } else if (in_edit) {
        // UPDATE — build WHERE from original row values
        if (get_bof() || get_eof()) {
            ERR_PRINT("VGRecordset::Update — no current record to update");
            in_edit = false;
            return;
        }
        Dictionary original = rows[cursor];
        Dictionary where_dict = _build_where_clause();
        
        Array set_keys = edit_buffer.keys();
        String set_clause = "";
        Array params;
        for (int i = 0; i < set_keys.size(); i++) {
            String key = set_keys[i];
            // Skip columns that haven't changed
            if (original.has(key) && original[key] == edit_buffer[key]) continue;
            if (!set_clause.is_empty()) set_clause += ", ";
            set_clause += key + " = ?";
            params.append(edit_buffer[key]);
        }
        if (set_clause.is_empty()) {
            in_edit = false;
            edit_buffer.clear();
            return; // Nothing changed
        }

        String where_clause = String(where_dict.get("clause", ""));
        Array where_params = where_dict.get("params", Array());
        params.append_array(where_params);

        String sql = "UPDATE " + table_name + " SET " + set_clause;
        if (!where_clause.is_empty()) {
            sql += " WHERE " + where_clause;
        }
        db_ref->execute_params(sql, params);
        in_edit = false;
        edit_buffer.clear();
        int saved_pos = cursor;
        requery();
        move_to(saved_pos);
    }
}

void VGRecordset::delete_record() {
    if (!is_open || db_ref.is_null() || get_bof() || get_eof()) {
        ERR_PRINT("VGRecordset::Delete — no current record");
        return;
    }
    if (table_name.is_empty()) {
        ERR_PRINT("VGRecordset::Delete — cannot determine table name");
        return;
    }

    Dictionary where_dict = _build_where_clause();
    String where_clause = String(where_dict.get("clause", ""));
    Array where_params = where_dict.get("params", Array());

    String sql = "DELETE FROM " + table_name;
    if (!where_clause.is_empty()) {
        sql += " WHERE " + where_clause;
    }
    sql += " LIMIT 1"; // Safety: only delete one row
    db_ref->execute_params(sql, where_params);

    int saved_pos = cursor;
    requery();
    if (saved_pos >= rows.size() && rows.size() > 0) {
        cursor = rows.size() - 1;
    } else if (rows.size() == 0) {
        cursor = -1;
    }
}

void VGRecordset::cancel_update() {
    in_add_new = false;
    in_edit = false;
    edit_buffer.clear();
}

// =============================================================================
// Bookmark
// =============================================================================

int VGRecordset::get_bookmark() const {
    return cursor;
}

void VGRecordset::set_bookmark(int p_bookmark) {
    move_to(p_bookmark);
}

// =============================================================================
// Internal Helpers
// =============================================================================

void VGRecordset::_extract_column_names() {
    column_names = PackedStringArray();
    if (rows.size() > 0) {
        Dictionary first_row = rows[0];
        Array keys = first_row.keys();
        for (int i = 0; i < keys.size(); i++) {
            column_names.append(keys[i]);
        }
    }
}

String VGRecordset::_detect_table_name(const String &p_source) {
    String s = p_source.strip_edges();
    // If it's just a table name (no spaces, no keywords)
    if (!s.contains(" ") && !s.to_upper().begins_with("SELECT")) {
        return s;
    }
    // Try to extract FROM clause
    String upper = s.to_upper();
    int from_pos = upper.find("FROM ");
    if (from_pos >= 0) {
        String after_from = s.substr(from_pos + 5).strip_edges();
        // Take until whitespace, comma, or semicolon
        String tbl = "";
        for (int i = 0; i < after_from.length(); i++) {
            char32_t c = after_from[i];
            if (c == ' ' || c == ',' || c == ';' || c == '\n' || c == '\r' || c == '\t') break;
            tbl += String::chr(c);
        }
        return tbl;
    }
    return "";
}

Dictionary VGRecordset::_build_where_clause() {
    Dictionary result;
    if (get_bof() || get_eof()) {
        result["clause"] = "";
        result["params"] = Array();
        return result;
    }
    Dictionary row = rows[cursor];
    Array keys = row.keys();
    String clause = "";
    Array params;
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        if (!clause.is_empty()) clause += " AND ";
        Variant val = row[key];
        if (val.get_type() == Variant::NIL) {
            clause += key + " IS NULL";
        } else {
            clause += key + " = ?";
            params.append(val);
        }
    }
    result["clause"] = clause;
    result["params"] = params;
    return result;
}

// =============================================================================
// Godot Binding
// =============================================================================

void VGRecordset::_bind_methods() {
    // Open / Close
    ClassDB::bind_method(D_METHOD("open", "source", "database"), &VGRecordset::open);
    ClassDB::bind_method(D_METHOD("close"), &VGRecordset::close);
    ClassDB::bind_method(D_METHOD("requery"), &VGRecordset::requery);

    // Navigation
    ClassDB::bind_method(D_METHOD("move_first"), &VGRecordset::move_first);
    ClassDB::bind_method(D_METHOD("move_next"), &VGRecordset::move_next);
    ClassDB::bind_method(D_METHOD("move_previous"), &VGRecordset::move_previous);
    ClassDB::bind_method(D_METHOD("move_last"), &VGRecordset::move_last);
    ClassDB::bind_method(D_METHOD("move_to", "index"), &VGRecordset::move_to);

    // Fields
    ClassDB::bind_method(D_METHOD("fields", "name_or_index"), &VGRecordset::fields);
    ClassDB::bind_method(D_METHOD("set_field", "name", "value"), &VGRecordset::set_field);
    ClassDB::bind_method(D_METHOD("get_column_names"), &VGRecordset::get_column_names);
    ClassDB::bind_method(D_METHOD("get_field_count"), &VGRecordset::get_field_count);
    ClassDB::bind_method(D_METHOD("get_current_row"), &VGRecordset::get_current_row);
    ClassDB::bind_method(D_METHOD("get_all_values", "field_name"), &VGRecordset::get_all_values);

    // Mutation
    ClassDB::bind_method(D_METHOD("add_new"), &VGRecordset::add_new);
    ClassDB::bind_method(D_METHOD("update"), &VGRecordset::update);
    ClassDB::bind_method(D_METHOD("edit_record"), &VGRecordset::edit_record);
    ClassDB::bind_method(D_METHOD("delete_record"), &VGRecordset::delete_record);
    ClassDB::bind_method(D_METHOD("cancel_update"), &VGRecordset::cancel_update);

    // Property getters/setters (must be bound BEFORE ADD_PROPERTY)
    ClassDB::bind_method(D_METHOD("get_bof"), &VGRecordset::get_bof);
    ClassDB::bind_method(D_METHOD("get_eof"), &VGRecordset::get_eof);
    ClassDB::bind_method(D_METHOD("get_record_count"), &VGRecordset::get_record_count);
    ClassDB::bind_method(D_METHOD("get_absolute_position"), &VGRecordset::get_absolute_position);
    ClassDB::bind_method(D_METHOD("set_absolute_position", "pos"), &VGRecordset::set_absolute_position);
    ClassDB::bind_method(D_METHOD("get_is_open"), &VGRecordset::get_is_open);
    ClassDB::bind_method(D_METHOD("get_bookmark"), &VGRecordset::get_bookmark);
    ClassDB::bind_method(D_METHOD("set_bookmark", "bookmark"), &VGRecordset::set_bookmark);
    ClassDB::bind_method(D_METHOD("get_rows"), &VGRecordset::get_rows);

    // State properties
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "BOF"), "", "get_bof");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "EOF"), "", "get_eof");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "RecordCount"), "", "get_record_count");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "AbsolutePosition"), "set_absolute_position", "get_absolute_position");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsOpen"), "", "get_is_open");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "Bookmark"), "set_bookmark", "get_bookmark");
}
