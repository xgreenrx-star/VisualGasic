// VGDatabase — SQLite database access via dynamic loading of libsqlite3
// No compile-time dependency on SQLite — loaded at runtime via dlopen

#include "visual_gasic_database.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>

#ifdef __linux__
#include <dlfcn.h>
#include <stdint.h>
#elif defined(_WIN32)
#include <windows.h>
#endif

using namespace godot;

// SQLite constants
#define SQLITE_OK 0
#define SQLITE_ROW 100
#define SQLITE_DONE 101
#define SQLITE_INTEGER 1
#define SQLITE_FLOAT 2
#define SQLITE_TEXT 3
#define SQLITE_BLOB 4
#define SQLITE_NULL 5
#define SQLITE_TRANSIENT ((void*)(intptr_t)-1)

void VGDatabase::_bind_methods() {
    ClassDB::bind_method(D_METHOD("open", "path"), &VGDatabase::open);
    ClassDB::bind_method(D_METHOD("close"), &VGDatabase::close);
    ClassDB::bind_method(D_METHOD("execute", "sql"), &VGDatabase::execute);
    ClassDB::bind_method(D_METHOD("query", "sql"), &VGDatabase::query);
    ClassDB::bind_method(D_METHOD("execute_params", "sql", "params"), &VGDatabase::execute_params);
    ClassDB::bind_method(D_METHOD("query_params", "sql", "params"), &VGDatabase::query_params);
    ClassDB::bind_method(D_METHOD("query_scalar", "sql"), &VGDatabase::query_scalar);
    ClassDB::bind_method(D_METHOD("begin_transaction"), &VGDatabase::begin_transaction);
    ClassDB::bind_method(D_METHOD("commit"), &VGDatabase::commit);
    ClassDB::bind_method(D_METHOD("rollback"), &VGDatabase::rollback);
    ClassDB::bind_method(D_METHOD("get_is_open"), &VGDatabase::get_is_open);
    ClassDB::bind_method(D_METHOD("get_last_error"), &VGDatabase::get_last_error);
    ClassDB::bind_method(D_METHOD("get_last_changes"), &VGDatabase::get_last_changes);
    ClassDB::bind_method(D_METHOD("get_last_insert_id"), &VGDatabase::get_last_insert_id);
    ClassDB::bind_method(D_METHOD("table_exists", "table_name"), &VGDatabase::table_exists);
    ClassDB::bind_method(D_METHOD("get_tables"), &VGDatabase::get_tables);
    ClassDB::bind_method(D_METHOD("get_path"), &VGDatabase::get_path);
    ClassDB::bind_static_method("VGDatabase", D_METHOD("is_sqlite_available"), &VGDatabase::is_sqlite_available);

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("Open", "path"), &VGDatabase::open);
    ClassDB::bind_method(D_METHOD("Close"), &VGDatabase::close);
    ClassDB::bind_method(D_METHOD("Execute", "sql"), &VGDatabase::execute);
    ClassDB::bind_method(D_METHOD("Query", "sql"), &VGDatabase::query);
    ClassDB::bind_method(D_METHOD("ExecuteParams", "sql", "params"), &VGDatabase::execute_params);
    ClassDB::bind_method(D_METHOD("QueryParams", "sql", "params"), &VGDatabase::query_params);
    ClassDB::bind_method(D_METHOD("QueryScalar", "sql"), &VGDatabase::query_scalar);
    ClassDB::bind_method(D_METHOD("BeginTransaction"), &VGDatabase::begin_transaction);
    ClassDB::bind_method(D_METHOD("Commit"), &VGDatabase::commit);
    ClassDB::bind_method(D_METHOD("Rollback"), &VGDatabase::rollback);
    ClassDB::bind_method(D_METHOD("TableExists", "table_name"), &VGDatabase::table_exists);
    ClassDB::bind_method(D_METHOD("GetTables"), &VGDatabase::get_tables);
    ClassDB::bind_static_method("VGDatabase", D_METHOD("IsSQLiteAvailable"), &VGDatabase::is_sqlite_available);

    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsOpen"), "", "get_is_open");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "LastError"), "", "get_last_error");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Path"), "", "get_path");
}

VGDatabase::VGDatabase() {
    sqlite_lib = nullptr;
    db_handle = nullptr;
    is_open = false;
    sqlite_loaded = false;
    last_changes = 0;
    fn_open = nullptr;
    fn_close = nullptr;
    fn_exec = nullptr;
    fn_free = nullptr;
    fn_errmsg = nullptr;
    fn_prepare = nullptr;
    fn_step = nullptr;
    fn_finalize = nullptr;
    fn_column_count = nullptr;
    fn_column_type = nullptr;
    fn_column_name = nullptr;
    fn_column_text = nullptr;
    fn_column_int = nullptr;
    fn_column_double = nullptr;
    fn_changes = nullptr;
    fn_last_insert_rowid = nullptr;
    fn_bind_text = nullptr;
    fn_bind_int = nullptr;
    fn_bind_double = nullptr;
    fn_bind_null = nullptr;
    fn_reset = nullptr;
}

VGDatabase::~VGDatabase() {
    close();
#ifdef __linux__
    if (sqlite_lib) {
        dlclose(sqlite_lib);
        sqlite_lib = nullptr;
    }
#elif defined(_WIN32)
    if (sqlite_lib) {
        FreeLibrary((HMODULE)sqlite_lib);
        sqlite_lib = nullptr;
    }
#endif
}

bool VGDatabase::load_sqlite_library() {
    if (sqlite_loaded) return true;

#ifdef __linux__
    // Try common library names
    const char *lib_names[] = {
        "libsqlite3.so.0",
        "libsqlite3.so",
        "libsqlite3.so.0.8.6",
        nullptr
    };
    for (int i = 0; lib_names[i]; i++) {
        sqlite_lib = dlopen(lib_names[i], RTLD_LAZY);
        if (sqlite_lib) break;
    }
    if (!sqlite_lib) {
        last_error = "SQLite library not found. Install: sudo apt install libsqlite3-0";
        UtilityFunctions::printerr("[VGDatabase] ", last_error);
        return false;
    }

    // Load all function pointers
    #define LOAD_FN(name, type) fn_##name = (type)dlsym(sqlite_lib, "sqlite3_" #name); \
        if (!fn_##name) { last_error = String("Missing symbol: sqlite3_") + #name; return false; }

    LOAD_FN(open, sqlite3_open_fn);
    LOAD_FN(close, sqlite3_close_fn);
    LOAD_FN(exec, sqlite3_exec_fn);
    LOAD_FN(free, sqlite3_free_fn);
    LOAD_FN(errmsg, sqlite3_errmsg_fn);
    // prepare_v2 has underscore in name so load it directly
    fn_prepare = (sqlite3_prepare_v2_fn)dlsym(sqlite_lib, "sqlite3_prepare_v2");
    if (!fn_prepare) { last_error = "Missing symbol: sqlite3_prepare_v2"; return false; }
    LOAD_FN(step, sqlite3_step_fn);
    LOAD_FN(finalize, sqlite3_finalize_fn);
    LOAD_FN(column_count, sqlite3_column_count_fn);
    LOAD_FN(column_type, sqlite3_column_type_fn);
    LOAD_FN(column_name, sqlite3_column_name_fn);
    LOAD_FN(column_text, sqlite3_column_text_fn);
    LOAD_FN(column_int, sqlite3_column_int_fn);
    LOAD_FN(column_double, sqlite3_column_double_fn);
    LOAD_FN(changes, sqlite3_changes_fn);
    LOAD_FN(last_insert_rowid, sqlite3_last_insert_rowid_fn);
    LOAD_FN(bind_text, sqlite3_bind_text_fn);
    LOAD_FN(bind_int, sqlite3_bind_int_fn);
    LOAD_FN(bind_double, sqlite3_bind_double_fn);
    LOAD_FN(bind_null, sqlite3_bind_null_fn);
    LOAD_FN(reset, sqlite3_reset_fn);

    #undef LOAD_FN
#elif defined(_WIN32)
    sqlite_lib = (void*)LoadLibraryA("sqlite3.dll");
    if (!sqlite_lib) {
        last_error = "sqlite3.dll not found";
        return false;
    }
    // Similar GetProcAddress loading would go here
    last_error = "Windows SQLite loading not yet implemented";
    return false;
#else
    last_error = "Platform not supported for SQLite";
    return false;
#endif

    sqlite_loaded = true;
    UtilityFunctions::print("[VGDatabase] SQLite library loaded successfully");
    return true;
}

bool VGDatabase::open(const String &p_path) {
    if (is_open) close();

    if (!load_sqlite_library()) return false;

    // Resolve Godot paths (res://, user://) to absolute paths
    String abs_path = p_path;
    if (abs_path.begins_with("res://") || abs_path.begins_with("user://")) {
        abs_path = ProjectSettings::get_singleton()->globalize_path(abs_path);
    }

    int rc = fn_open(abs_path.utf8().get_data(), &db_handle);
    if (rc != SQLITE_OK) {
        if (db_handle && fn_errmsg) {
            last_error = String::utf8(fn_errmsg(db_handle));
        } else {
            last_error = "Failed to open database";
        }
        UtilityFunctions::printerr("[VGDatabase] Open failed: ", last_error);
        return false;
    }

    db_path = p_path;
    is_open = true;
    UtilityFunctions::print("[VGDatabase] Opened: ", abs_path);

    // Enable WAL mode for better concurrency
    execute("PRAGMA journal_mode=WAL");

    return true;
}

void VGDatabase::close() {
    if (is_open && db_handle && fn_close) {
        fn_close(db_handle);
        db_handle = nullptr;
        is_open = false;
        UtilityFunctions::print("[VGDatabase] Closed: ", db_path);
    }
}

bool VGDatabase::execute(const String &p_sql) {
    if (!is_open || !db_handle) {
        last_error = "Database not open";
        return false;
    }

    char *err_msg = nullptr;
    int rc = fn_exec(db_handle, p_sql.utf8().get_data(), nullptr, nullptr, &err_msg);
    if (rc != SQLITE_OK) {
        if (err_msg) {
            last_error = String::utf8(err_msg);
            fn_free(err_msg);
        }
        UtilityFunctions::printerr("[VGDatabase] Execute error: ", last_error);
        return false;
    }
    last_changes = fn_changes(db_handle);
    return true;
}

Array VGDatabase::query(const String &p_sql) {
    Array results;
    if (!is_open || !db_handle) {
        last_error = "Database not open";
        return results;
    }

    void *stmt = nullptr;
    int rc = fn_prepare(db_handle, p_sql.utf8().get_data(), -1, &stmt, nullptr);
    if (rc != SQLITE_OK) {
        last_error = String::utf8(fn_errmsg(db_handle));
        UtilityFunctions::printerr("[VGDatabase] Query prepare error: ", last_error);
        return results;
    }

    int col_count = fn_column_count(stmt);

    while (fn_step(stmt) == SQLITE_ROW) {
        Dictionary row;
        for (int i = 0; i < col_count; i++) {
            String col_name = String::utf8(fn_column_name(stmt, i));
            int col_type = fn_column_type(stmt, i);

            switch (col_type) {
                case SQLITE_INTEGER:
                    row[col_name] = fn_column_int(stmt, i);
                    break;
                case SQLITE_FLOAT:
                    row[col_name] = fn_column_double(stmt, i);
                    break;
                case SQLITE_TEXT: {
                    const char *text = fn_column_text(stmt, i);
                    row[col_name] = text ? String::utf8(text) : String();
                    break;
                }
                case SQLITE_NULL:
                    row[col_name] = Variant();
                    break;
                default:
                    row[col_name] = Variant();
                    break;
            }
        }
        results.push_back(row);
    }

    fn_finalize(stmt);
    return results;
}

bool VGDatabase::execute_params(const String &p_sql, const Array &p_params) {
    if (!is_open || !db_handle) {
        last_error = "Database not open";
        return false;
    }

    void *stmt = nullptr;
    int rc = fn_prepare(db_handle, p_sql.utf8().get_data(), -1, &stmt, nullptr);
    if (rc != SQLITE_OK) {
        last_error = String::utf8(fn_errmsg(db_handle));
        return false;
    }

    // Bind parameters (1-indexed in SQLite)
    for (int i = 0; i < p_params.size(); i++) {
        Variant param = p_params[i];
        switch (param.get_type()) {
            case Variant::INT:
                fn_bind_int(stmt, i + 1, (int)param);
                break;
            case Variant::FLOAT:
                fn_bind_double(stmt, i + 1, (double)param);
                break;
            case Variant::STRING: {
                CharString utf8 = String(param).utf8();
                fn_bind_text(stmt, i + 1, utf8.get_data(), utf8.length(), SQLITE_TRANSIENT);
                break;
            }
            case Variant::NIL:
                fn_bind_null(stmt, i + 1);
                break;
            default: {
                CharString utf8 = String(param).utf8();
                fn_bind_text(stmt, i + 1, utf8.get_data(), utf8.length(), SQLITE_TRANSIENT);
                break;
            }
        }
    }

    rc = fn_step(stmt);
    fn_finalize(stmt);

    if (rc != SQLITE_DONE && rc != SQLITE_ROW) {
        last_error = String::utf8(fn_errmsg(db_handle));
        return false;
    }

    last_changes = fn_changes(db_handle);
    return true;
}

Array VGDatabase::query_params(const String &p_sql, const Array &p_params) {
    Array results;
    if (!is_open || !db_handle) {
        last_error = "Database not open";
        return results;
    }

    void *stmt = nullptr;
    int rc = fn_prepare(db_handle, p_sql.utf8().get_data(), -1, &stmt, nullptr);
    if (rc != SQLITE_OK) {
        last_error = String::utf8(fn_errmsg(db_handle));
        return results;
    }

    for (int i = 0; i < p_params.size(); i++) {
        Variant param = p_params[i];
        switch (param.get_type()) {
            case Variant::INT:
                fn_bind_int(stmt, i + 1, (int)param);
                break;
            case Variant::FLOAT:
                fn_bind_double(stmt, i + 1, (double)param);
                break;
            case Variant::STRING: {
                CharString utf8 = String(param).utf8();
                fn_bind_text(stmt, i + 1, utf8.get_data(), utf8.length(), SQLITE_TRANSIENT);
                break;
            }
            case Variant::NIL:
                fn_bind_null(stmt, i + 1);
                break;
            default: {
                CharString utf8 = String(param).utf8();
                fn_bind_text(stmt, i + 1, utf8.get_data(), utf8.length(), SQLITE_TRANSIENT);
                break;
            }
        }
    }

    int col_count = fn_column_count(stmt);
    while (fn_step(stmt) == SQLITE_ROW) {
        Dictionary row;
        for (int i = 0; i < col_count; i++) {
            String col_name = String::utf8(fn_column_name(stmt, i));
            int col_type = fn_column_type(stmt, i);
            switch (col_type) {
                case SQLITE_INTEGER: row[col_name] = fn_column_int(stmt, i); break;
                case SQLITE_FLOAT: row[col_name] = fn_column_double(stmt, i); break;
                case SQLITE_TEXT: {
                    const char *t = fn_column_text(stmt, i);
                    row[col_name] = t ? String::utf8(t) : String();
                    break;
                }
                default: row[col_name] = Variant(); break;
            }
        }
        results.push_back(row);
    }
    fn_finalize(stmt);
    return results;
}

Variant VGDatabase::query_scalar(const String &p_sql) {
    Array rows = query(p_sql);
    if (rows.size() == 0) return Variant();
    Dictionary first_row = rows[0];
    Array keys = first_row.keys();
    if (keys.size() == 0) return Variant();
    return first_row[keys[0]];
}

bool VGDatabase::begin_transaction() { return execute("BEGIN TRANSACTION"); }
bool VGDatabase::commit() { return execute("COMMIT"); }
bool VGDatabase::rollback() { return execute("ROLLBACK"); }

int64_t VGDatabase::get_last_insert_id() {
    if (!is_open || !db_handle || !fn_last_insert_rowid) return -1;
    return fn_last_insert_rowid(db_handle);
}

bool VGDatabase::table_exists(const String &p_table_name) {
    Array params;
    params.push_back(p_table_name);
    Array rows = query_params("SELECT name FROM sqlite_master WHERE type='table' AND name=?", params);
    return rows.size() > 0;
}

Array VGDatabase::get_tables() {
    Array tables;
    Array rows = query("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
    for (int i = 0; i < rows.size(); i++) {
        Dictionary row = rows[i];
        tables.push_back(row["name"]);
    }
    return tables;
}

bool VGDatabase::is_sqlite_available() {
#ifdef __linux__
    void *lib = dlopen("libsqlite3.so.0", RTLD_LAZY);
    if (!lib) lib = dlopen("libsqlite3.so", RTLD_LAZY);
    if (lib) {
        dlclose(lib);
        return true;
    }
    return false;
#else
    return false;
#endif
}
