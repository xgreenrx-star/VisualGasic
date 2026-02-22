#ifndef VISUAL_GASIC_DATABASE_H
#define VISUAL_GASIC_DATABASE_H

// VGDatabase — SQLite database access via dynamic loading
// Usage in VisualGasic:
//   Dim db As New Database
//   db.Open "myapp.db"
//   db.Execute "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"
//   db.Execute "INSERT INTO users VALUES (1, 'Alice')"
//   Dim rs As Variant
//   rs = db.Query("SELECT * FROM users")
//   For Each row In rs
//       Print row("name")
//   Next
//   db.Close

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

class VGDatabase : public RefCounted {
    GDCLASS(VGDatabase, RefCounted);

    // SQLite function pointers (loaded via dlopen)
    void *sqlite_lib;
    void *db_handle;
    String db_path;
    bool is_open;
    String last_error;
    int last_changes;

    // SQLite function pointer types
    typedef int (*sqlite3_open_fn)(const char*, void**);
    typedef int (*sqlite3_close_fn)(void*);
    typedef int (*sqlite3_exec_fn)(void*, const char*, int(*)(void*,int,char**,char**), void*, char**);
    typedef void (*sqlite3_free_fn)(void*);
    typedef const char* (*sqlite3_errmsg_fn)(void*);
    typedef int (*sqlite3_prepare_v2_fn)(void*, const char*, int, void**, const char**);
    typedef int (*sqlite3_step_fn)(void*);
    typedef int (*sqlite3_finalize_fn)(void*);
    typedef int (*sqlite3_column_count_fn)(void*);
    typedef int (*sqlite3_column_type_fn)(void*, int);
    typedef const char* (*sqlite3_column_name_fn)(void*, int);
    typedef const char* (*sqlite3_column_text_fn)(void*, int);
    typedef int (*sqlite3_column_int_fn)(void*, int);
    typedef double (*sqlite3_column_double_fn)(void*, int);
    typedef int (*sqlite3_changes_fn)(void*);
    typedef int64_t (*sqlite3_last_insert_rowid_fn)(void*);
    typedef int (*sqlite3_bind_text_fn)(void*, int, const char*, int, void*);
    typedef int (*sqlite3_bind_int_fn)(void*, int, int);
    typedef int (*sqlite3_bind_double_fn)(void*, int, double);
    typedef int (*sqlite3_bind_null_fn)(void*, int);
    typedef int (*sqlite3_reset_fn)(void*);

    // Loaded function pointers
    sqlite3_open_fn fn_open;
    sqlite3_close_fn fn_close;
    sqlite3_exec_fn fn_exec;
    sqlite3_free_fn fn_free;
    sqlite3_errmsg_fn fn_errmsg;
    sqlite3_prepare_v2_fn fn_prepare;
    sqlite3_step_fn fn_step;
    sqlite3_finalize_fn fn_finalize;
    sqlite3_column_count_fn fn_column_count;
    sqlite3_column_type_fn fn_column_type;
    sqlite3_column_name_fn fn_column_name;
    sqlite3_column_text_fn fn_column_text;
    sqlite3_column_int_fn fn_column_int;
    sqlite3_column_double_fn fn_column_double;
    sqlite3_changes_fn fn_changes;
    sqlite3_last_insert_rowid_fn fn_last_insert_rowid;
    sqlite3_bind_text_fn fn_bind_text;
    sqlite3_bind_int_fn fn_bind_int;
    sqlite3_bind_double_fn fn_bind_double;
    sqlite3_bind_null_fn fn_bind_null;
    sqlite3_reset_fn fn_reset;

    bool load_sqlite_library();
    bool sqlite_loaded;

protected:
    static void _bind_methods();

public:
    VGDatabase();
    ~VGDatabase();

    // Core database operations
    bool open(const String &p_path);
    void close();
    bool execute(const String &p_sql);
    Array query(const String &p_sql);

    // Parameterized queries (SQL injection safe)
    bool execute_params(const String &p_sql, const Array &p_params);
    Array query_params(const String &p_sql, const Array &p_params);

    // Scalar query — returns single value
    Variant query_scalar(const String &p_sql);

    // Transaction support
    bool begin_transaction();
    bool commit();
    bool rollback();

    // Utility
    bool get_is_open() const { return is_open; }
    String get_last_error() const { return last_error; }
    int get_last_changes() const { return last_changes; }
    int64_t get_last_insert_id();
    bool table_exists(const String &p_table_name);
    Array get_tables();
    String get_path() const { return db_path; }

    // Convenience
    static bool is_sqlite_available();
};

#endif // VISUAL_GASIC_DATABASE_H
