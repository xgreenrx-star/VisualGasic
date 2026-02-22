// VGOdbc — Universal ODBC database access via dynamic loading
// No compile-time dependency on ODBC — loaded at runtime via dlopen/LoadLibrary

#include "visual_gasic_odbc.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>

#if defined(__linux__) || defined(__APPLE__)
#include <dlfcn.h>
#elif defined(_WIN32)
#include <windows.h>
#endif

using namespace godot;

// ODBC constants
#define SQL_HANDLE_ENV 1
#define SQL_HANDLE_DBC 2
#define SQL_HANDLE_STMT 3
#define SQL_ATTR_ODBC_VERSION 200
#define SQL_OV_ODBC3 3
#define SQL_NTS (-3)
#define SQL_SUCCESS 0
#define SQL_SUCCESS_WITH_INFO 1
#define SQL_NO_DATA 100
#define SQL_FETCH_NEXT 1
#define SQL_C_CHAR 1
#define SQL_COMMIT 0
#define SQL_ROLLBACK 1
#define SQL_DRIVER_NOPROMPT 0
#define SQL_CLOSE 0
#define SQL_MAX_MESSAGE_LENGTH 512

void VGOdbc::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_connection_string", "cs"), &VGOdbc::set_connection_string);
    ClassDB::bind_method(D_METHOD("get_connection_string"), &VGOdbc::get_connection_string);
    ClassDB::bind_method(D_METHOD("open"), &VGOdbc::open);
    ClassDB::bind_method(D_METHOD("open_with_string", "connection_string"), &VGOdbc::open_with_string);
    ClassDB::bind_method(D_METHOD("close"), &VGOdbc::close);
    ClassDB::bind_method(D_METHOD("get_is_open"), &VGOdbc::get_is_open);
    ClassDB::bind_method(D_METHOD("execute", "sql"), &VGOdbc::execute);
    ClassDB::bind_method(D_METHOD("execute_params", "sql", "params"), &VGOdbc::execute_params);
    ClassDB::bind_method(D_METHOD("query", "sql"), &VGOdbc::query);
    ClassDB::bind_method(D_METHOD("query_params", "sql", "params"), &VGOdbc::query_params);
    ClassDB::bind_method(D_METHOD("query_scalar", "sql"), &VGOdbc::query_scalar);
    ClassDB::bind_method(D_METHOD("begin_transaction"), &VGOdbc::begin_transaction);
    ClassDB::bind_method(D_METHOD("commit"), &VGOdbc::commit);
    ClassDB::bind_method(D_METHOD("rollback"), &VGOdbc::rollback);
    ClassDB::bind_method(D_METHOD("get_last_error"), &VGOdbc::get_last_error);
    ClassDB::bind_method(D_METHOD("get_last_affected_rows"), &VGOdbc::get_last_affected_rows);
    ClassDB::bind_method(D_METHOD("get_tables"), &VGOdbc::get_tables);
    ClassDB::bind_method(D_METHOD("table_exists", "table_name"), &VGOdbc::table_exists);
    ClassDB::bind_static_method("VGOdbc", D_METHOD("list_drivers"), &VGOdbc::list_drivers);
    ClassDB::bind_static_method("VGOdbc", D_METHOD("is_odbc_available"), &VGOdbc::is_odbc_available);

    // VB6-style PascalCase aliases
    ClassDB::bind_method(D_METHOD("Open"), &VGOdbc::open);
    ClassDB::bind_method(D_METHOD("OpenWithString", "connection_string"), &VGOdbc::open_with_string);
    ClassDB::bind_method(D_METHOD("Close"), &VGOdbc::close);
    ClassDB::bind_method(D_METHOD("Execute", "sql"), &VGOdbc::execute);
    ClassDB::bind_method(D_METHOD("ExecuteParams", "sql", "params"), &VGOdbc::execute_params);
    ClassDB::bind_method(D_METHOD("Query", "sql"), &VGOdbc::query);
    ClassDB::bind_method(D_METHOD("QueryParams", "sql", "params"), &VGOdbc::query_params);
    ClassDB::bind_method(D_METHOD("QueryScalar", "sql"), &VGOdbc::query_scalar);
    ClassDB::bind_method(D_METHOD("BeginTransaction"), &VGOdbc::begin_transaction);
    ClassDB::bind_method(D_METHOD("Commit"), &VGOdbc::commit);
    ClassDB::bind_method(D_METHOD("Rollback"), &VGOdbc::rollback);
    ClassDB::bind_method(D_METHOD("TableExists", "table_name"), &VGOdbc::table_exists);
    ClassDB::bind_method(D_METHOD("GetTables"), &VGOdbc::get_tables);
    ClassDB::bind_static_method("VGOdbc", D_METHOD("ListDrivers"), &VGOdbc::list_drivers);
    ClassDB::bind_static_method("VGOdbc", D_METHOD("IsOdbcAvailable"), &VGOdbc::is_odbc_available);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "ConnectionString"), "set_connection_string", "get_connection_string");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsOpen"), "", "get_is_open");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "LastError"), "", "get_last_error");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "LastAffectedRows"), "", "get_last_affected_rows");
}

VGOdbc::VGOdbc() {
    env_handle = nullptr;
    conn_handle = nullptr;
    is_open = false;
    odbc_lib = nullptr;
    odbc_loaded = false;
    last_affected_rows = 0;

    fn_alloc_handle = nullptr;
    fn_set_env_attr = nullptr;
    fn_driver_connect = nullptr;
    fn_exec_direct = nullptr;
    fn_fetch = nullptr;
    fn_num_result_cols = nullptr;
    fn_describe_col = nullptr;
    fn_get_data = nullptr;
    fn_free_handle = nullptr;
    fn_disconnect = nullptr;
    fn_free_stmt = nullptr;
    fn_row_count = nullptr;
    fn_prepare = nullptr;
    fn_bind_parameter = nullptr;
    fn_execute = nullptr;
    fn_end_tran = nullptr;
    fn_get_diag_rec = nullptr;

    load_odbc_library();
}

VGOdbc::~VGOdbc() {
    close();

    // Free environment handle
    if (env_handle && fn_free_handle) {
        fn_free_handle(SQL_HANDLE_ENV, env_handle);
        env_handle = nullptr;
    }

#if defined(__linux__) || defined(__APPLE__)
    if (odbc_lib) {
        dlclose(odbc_lib);
        odbc_lib = nullptr;
    }
#elif defined(_WIN32)
    if (odbc_lib) {
        FreeLibrary((HMODULE)odbc_lib);
        odbc_lib = nullptr;
    }
#endif
}

bool VGOdbc::load_odbc_library() {
    if (odbc_loaded) return true;

#if defined(__linux__) || defined(__APPLE__)
    #if defined(__linux__)
    const char *lib_names[] = {
        "libodbc.so",
        "libodbc.so.2",
        "libodbc.so.1",
        nullptr
    };
    #else // __APPLE__
    const char *lib_names[] = {
        "libodbc.dylib",
        "libodbc.2.dylib",
        "/usr/local/lib/libodbc.dylib",
        "/opt/homebrew/lib/libodbc.dylib",
        nullptr
    };
    #endif

    for (int i = 0; lib_names[i]; i++) {
        odbc_lib = dlopen(lib_names[i], RTLD_LAZY);
        if (odbc_lib) break;
    }
    if (!odbc_lib) {
        last_error = "ODBC library not found. Install: sudo apt install unixodbc (Linux) or brew install unixodbc (macOS)";
        UtilityFunctions::printerr("[VGOdbc] ", last_error);
        return false;
    }

    // Load all function pointers
    #define LOAD_ODBC_FN(var, name, type) var = (type)dlsym(odbc_lib, name); \
        if (!var) { last_error = String("Missing ODBC symbol: ") + name; \
        UtilityFunctions::printerr("[VGOdbc] ", last_error); return false; }

    LOAD_ODBC_FN(fn_alloc_handle,   "SQLAllocHandle",    sql_alloc_handle_fn);
    LOAD_ODBC_FN(fn_set_env_attr,   "SQLSetEnvAttr",     sql_set_env_attr_fn);
    LOAD_ODBC_FN(fn_driver_connect, "SQLDriverConnect",  sql_driver_connect_fn);
    LOAD_ODBC_FN(fn_exec_direct,    "SQLExecDirect",     sql_exec_direct_fn);
    LOAD_ODBC_FN(fn_fetch,          "SQLFetch",          sql_fetch_fn);
    LOAD_ODBC_FN(fn_num_result_cols, "SQLNumResultCols", sql_num_result_cols_fn);
    LOAD_ODBC_FN(fn_describe_col,   "SQLDescribeCol",    sql_describe_col_fn);
    LOAD_ODBC_FN(fn_get_data,       "SQLGetData",        sql_get_data_fn);
    LOAD_ODBC_FN(fn_free_handle,    "SQLFreeHandle",     sql_free_handle_fn);
    LOAD_ODBC_FN(fn_disconnect,     "SQLDisconnect",     sql_disconnect_fn);
    LOAD_ODBC_FN(fn_row_count,      "SQLRowCount",       sql_row_count_fn);
    LOAD_ODBC_FN(fn_prepare,        "SQLPrepare",        sql_prepare_fn);
    LOAD_ODBC_FN(fn_bind_parameter, "SQLBindParameter",  sql_bind_parameter_fn);
    LOAD_ODBC_FN(fn_execute,        "SQLExecute",        sql_execute_fn);
    LOAD_ODBC_FN(fn_end_tran,       "SQLEndTran",        sql_end_tran_fn);
    LOAD_ODBC_FN(fn_get_diag_rec,   "SQLGetDiagRec",     sql_get_diag_rec_fn);

    // Optional: SQLFreeStmt (not critical)
    fn_free_stmt = (sql_free_stmt_fn)dlsym(odbc_lib, "SQLFreeStmt");

    #undef LOAD_ODBC_FN

#elif defined(_WIN32)
    odbc_lib = (void *)LoadLibraryA("odbc32.dll");
    if (!odbc_lib) {
        last_error = "odbc32.dll not found";
        UtilityFunctions::printerr("[VGOdbc] ", last_error);
        return false;
    }

    #define LOAD_ODBC_FN(var, name, type) var = (type)GetProcAddress((HMODULE)odbc_lib, name); \
        if (!var) { last_error = String("Missing ODBC symbol: ") + name; \
        UtilityFunctions::printerr("[VGOdbc] ", last_error); return false; }

    LOAD_ODBC_FN(fn_alloc_handle,   "SQLAllocHandle",    sql_alloc_handle_fn);
    LOAD_ODBC_FN(fn_set_env_attr,   "SQLSetEnvAttr",     sql_set_env_attr_fn);
    LOAD_ODBC_FN(fn_driver_connect, "SQLDriverConnect",  sql_driver_connect_fn);
    LOAD_ODBC_FN(fn_exec_direct,    "SQLExecDirect",     sql_exec_direct_fn);
    LOAD_ODBC_FN(fn_fetch,          "SQLFetch",          sql_fetch_fn);
    LOAD_ODBC_FN(fn_num_result_cols, "SQLNumResultCols", sql_num_result_cols_fn);
    LOAD_ODBC_FN(fn_describe_col,   "SQLDescribeCol",    sql_describe_col_fn);
    LOAD_ODBC_FN(fn_get_data,       "SQLGetData",        sql_get_data_fn);
    LOAD_ODBC_FN(fn_free_handle,    "SQLFreeHandle",     sql_free_handle_fn);
    LOAD_ODBC_FN(fn_disconnect,     "SQLDisconnect",     sql_disconnect_fn);
    LOAD_ODBC_FN(fn_row_count,      "SQLRowCount",       sql_row_count_fn);
    LOAD_ODBC_FN(fn_prepare,        "SQLPrepare",        sql_prepare_fn);
    LOAD_ODBC_FN(fn_bind_parameter, "SQLBindParameter",  sql_bind_parameter_fn);
    LOAD_ODBC_FN(fn_execute,        "SQLExecute",        sql_execute_fn);
    LOAD_ODBC_FN(fn_end_tran,       "SQLEndTran",        sql_end_tran_fn);
    LOAD_ODBC_FN(fn_get_diag_rec,   "SQLGetDiagRec",     sql_get_diag_rec_fn);

    fn_free_stmt = (sql_free_stmt_fn)GetProcAddress((HMODULE)odbc_lib, "SQLFreeStmt");

    #undef LOAD_ODBC_FN
#else
    last_error = "Platform not supported for ODBC";
    UtilityFunctions::printerr("[VGOdbc] ", last_error);
    return false;
#endif

    odbc_loaded = true;
    UtilityFunctions::print("[VGOdbc] ODBC library loaded successfully");
    return true;
}

void VGOdbc::extract_error(const String &p_context, void *p_handle, short p_handle_type) {
    if (!fn_get_diag_rec || !p_handle) {
        last_error = p_context + String(": Unknown error (no diagnostic available)");
        return;
    }

    char sql_state[6] = {0};
    int native_error = 0;
    char message[SQL_MAX_MESSAGE_LENGTH] = {0};
    short msg_len = 0;

    short ret = fn_get_diag_rec(p_handle_type, p_handle, 1,
                                 sql_state, &native_error,
                                 message, SQL_MAX_MESSAGE_LENGTH, &msg_len);

    if (ret == SQL_SUCCESS || ret == SQL_SUCCESS_WITH_INFO) {
        last_error = p_context + String(": [") + String::utf8(sql_state) + String("] ") + String::utf8(message);
    } else {
        last_error = p_context + String(": Unable to retrieve error details");
    }

    UtilityFunctions::printerr("[VGOdbc] ", last_error);
}

void VGOdbc::set_connection_string(const String &p_cs) {
    connection_string = p_cs;
}

bool VGOdbc::open() {
    if (is_open) {
        UtilityFunctions::print("[VGOdbc] Already connected, closing previous connection");
        close();
    }

    if (!odbc_loaded) {
        if (!load_odbc_library()) return false;
    }

    if (connection_string.is_empty()) {
        last_error = "Connection string is empty";
        UtilityFunctions::printerr("[VGOdbc] ", last_error);
        return false;
    }

    // Allocate environment handle
    short ret = fn_alloc_handle(SQL_HANDLE_ENV, nullptr, &env_handle);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        last_error = "Failed to allocate ODBC environment handle";
        UtilityFunctions::printerr("[VGOdbc] ", last_error);
        return false;
    }

    // Set ODBC version to 3.x
    ret = fn_set_env_attr(env_handle, SQL_ATTR_ODBC_VERSION, (void *)(intptr_t)SQL_OV_ODBC3, 0);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLSetEnvAttr", env_handle, SQL_HANDLE_ENV);
        fn_free_handle(SQL_HANDLE_ENV, env_handle);
        env_handle = nullptr;
        return false;
    }

    // Allocate connection handle
    ret = fn_alloc_handle(SQL_HANDLE_DBC, env_handle, &conn_handle);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLAllocHandle(DBC)", env_handle, SQL_HANDLE_ENV);
        fn_free_handle(SQL_HANDLE_ENV, env_handle);
        env_handle = nullptr;
        return false;
    }

    // Connect using driver connect string
    CharString cs_utf8 = connection_string.utf8();
    char out_conn[1024] = {0};
    short out_len = 0;

    ret = fn_driver_connect(conn_handle, nullptr,
                             cs_utf8.get_data(), (short)cs_utf8.length(),
                             out_conn, 1024, &out_len,
                             SQL_DRIVER_NOPROMPT);

    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLDriverConnect", conn_handle, SQL_HANDLE_DBC);
        fn_free_handle(SQL_HANDLE_DBC, conn_handle);
        fn_free_handle(SQL_HANDLE_ENV, env_handle);
        conn_handle = nullptr;
        env_handle = nullptr;
        return false;
    }

    is_open = true;
    UtilityFunctions::print("[VGOdbc] Connected successfully");
    return true;
}

bool VGOdbc::open_with_string(const String &p_connection_string) {
    set_connection_string(p_connection_string);
    return open();
}

void VGOdbc::close() {
    if (!is_open) return;

    if (conn_handle) {
        if (fn_disconnect) {
            fn_disconnect(conn_handle);
        }
        if (fn_free_handle) {
            fn_free_handle(SQL_HANDLE_DBC, conn_handle);
        }
        conn_handle = nullptr;
    }

    is_open = false;
    UtilityFunctions::print("[VGOdbc] Connection closed");
}

bool VGOdbc::execute(const String &p_sql) {
    if (!is_open || !conn_handle) {
        last_error = "Not connected to database";
        return false;
    }

    // Allocate statement handle
    void *stmt = nullptr;
    short ret = fn_alloc_handle(SQL_HANDLE_STMT, conn_handle, &stmt);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLAllocHandle(STMT)", conn_handle, SQL_HANDLE_DBC);
        return false;
    }

    // Execute SQL
    CharString sql_utf8 = p_sql.utf8();
    ret = fn_exec_direct(stmt, sql_utf8.get_data(), SQL_NTS);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLExecDirect", stmt, SQL_HANDLE_STMT);
        fn_free_handle(SQL_HANDLE_STMT, stmt);
        return false;
    }

    // Get affected row count
    long row_count = 0;
    fn_row_count(stmt, &row_count);
    last_affected_rows = (int)row_count;

    fn_free_handle(SQL_HANDLE_STMT, stmt);
    return true;
}

bool VGOdbc::execute_params(const String &p_sql, const Array &p_params) {
    if (!is_open || !conn_handle) {
        last_error = "Not connected to database";
        return false;
    }

    void *stmt = nullptr;
    short ret = fn_alloc_handle(SQL_HANDLE_STMT, conn_handle, &stmt);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLAllocHandle(STMT)", conn_handle, SQL_HANDLE_DBC);
        return false;
    }

    // Prepare statement
    CharString sql_utf8 = p_sql.utf8();
    ret = fn_prepare(stmt, sql_utf8.get_data(), SQL_NTS);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLPrepare", stmt, SQL_HANDLE_STMT);
        fn_free_handle(SQL_HANDLE_STMT, stmt);
        return false;
    }

    // Bind parameters — convert all to strings for simplicity with ODBC
    Vector<CharString> param_buffers;
    Vector<long> param_lengths;
    param_buffers.resize(p_params.size());
    param_lengths.resize(p_params.size());

    for (int i = 0; i < p_params.size(); i++) {
        Variant val = p_params[i];
        if (val.get_type() == Variant::NIL) {
            param_lengths.write[i] = -1; // SQL_NULL_DATA
            param_buffers.write[i] = CharString();
            fn_bind_parameter(stmt, (unsigned short)(i + 1),
                              1,  // SQL_PARAM_INPUT
                              SQL_C_CHAR, 12, // SQL_VARCHAR
                              0, 0,
                              nullptr, 0, &param_lengths.write[i]);
        } else {
            param_buffers.write[i] = String(val).utf8();
            param_lengths.write[i] = param_buffers[i].length();
            fn_bind_parameter(stmt, (unsigned short)(i + 1),
                              1,  // SQL_PARAM_INPUT
                              SQL_C_CHAR, 12, // SQL_VARCHAR
                              param_buffers[i].length(), 0,
                              (void *)param_buffers[i].get_data(),
                              param_buffers[i].length(),
                              &param_lengths.write[i]);
        }
    }

    // Execute
    ret = fn_execute(stmt);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLExecute", stmt, SQL_HANDLE_STMT);
        fn_free_handle(SQL_HANDLE_STMT, stmt);
        return false;
    }

    long row_count = 0;
    fn_row_count(stmt, &row_count);
    last_affected_rows = (int)row_count;

    fn_free_handle(SQL_HANDLE_STMT, stmt);
    return true;
}

Array VGOdbc::query(const String &p_sql) {
    Array results;
    if (!is_open || !conn_handle) {
        last_error = "Not connected to database";
        return results;
    }

    void *stmt = nullptr;
    short ret = fn_alloc_handle(SQL_HANDLE_STMT, conn_handle, &stmt);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLAllocHandle(STMT)", conn_handle, SQL_HANDLE_DBC);
        return results;
    }

    CharString sql_utf8 = p_sql.utf8();
    ret = fn_exec_direct(stmt, sql_utf8.get_data(), SQL_NTS);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLExecDirect", stmt, SQL_HANDLE_STMT);
        fn_free_handle(SQL_HANDLE_STMT, stmt);
        return results;
    }

    // Get column count
    short col_count = 0;
    fn_num_result_cols(stmt, &col_count);

    // Get column names
    Vector<String> col_names;
    for (short i = 1; i <= col_count; i++) {
        char col_name[256] = {0};
        short name_len = 0;
        short data_type = 0;
        unsigned long col_size = 0;
        short decimal_digits = 0;
        short nullable = 0;

        fn_describe_col(stmt, (unsigned short)i, col_name, 256, &name_len,
                        &data_type, &col_size, &decimal_digits, &nullable);
        col_names.push_back(String::utf8(col_name));
    }

    // Fetch rows
    while (fn_fetch(stmt) == SQL_SUCCESS) {
        Dictionary row;
        for (short i = 1; i <= col_count; i++) {
            char buffer[8192] = {0};
            long indicator = 0;

            ret = fn_get_data(stmt, (unsigned short)i, SQL_C_CHAR,
                              buffer, sizeof(buffer), &indicator);

            if (indicator == -1) { // SQL_NULL_DATA
                row[col_names[i - 1]] = Variant();
            } else if (ret == SQL_SUCCESS || ret == SQL_SUCCESS_WITH_INFO) {
                row[col_names[i - 1]] = String::utf8(buffer);
            } else {
                row[col_names[i - 1]] = Variant();
            }
        }
        results.push_back(row);
    }

    fn_free_handle(SQL_HANDLE_STMT, stmt);
    return results;
}

Array VGOdbc::query_params(const String &p_sql, const Array &p_params) {
    Array results;
    if (!is_open || !conn_handle) {
        last_error = "Not connected to database";
        return results;
    }

    void *stmt = nullptr;
    short ret = fn_alloc_handle(SQL_HANDLE_STMT, conn_handle, &stmt);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLAllocHandle(STMT)", conn_handle, SQL_HANDLE_DBC);
        return results;
    }

    // Prepare
    CharString sql_utf8 = p_sql.utf8();
    ret = fn_prepare(stmt, sql_utf8.get_data(), SQL_NTS);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLPrepare", stmt, SQL_HANDLE_STMT);
        fn_free_handle(SQL_HANDLE_STMT, stmt);
        return results;
    }

    // Bind parameters
    Vector<CharString> param_buffers;
    Vector<long> param_lengths;
    param_buffers.resize(p_params.size());
    param_lengths.resize(p_params.size());

    for (int i = 0; i < p_params.size(); i++) {
        Variant val = p_params[i];
        if (val.get_type() == Variant::NIL) {
            param_lengths.write[i] = -1;
            param_buffers.write[i] = CharString();
            fn_bind_parameter(stmt, (unsigned short)(i + 1),
                              1, SQL_C_CHAR, 12, 0, 0,
                              nullptr, 0, &param_lengths.write[i]);
        } else {
            param_buffers.write[i] = String(val).utf8();
            param_lengths.write[i] = param_buffers[i].length();
            fn_bind_parameter(stmt, (unsigned short)(i + 1),
                              1, SQL_C_CHAR, 12,
                              param_buffers[i].length(), 0,
                              (void *)param_buffers[i].get_data(),
                              param_buffers[i].length(),
                              &param_lengths.write[i]);
        }
    }

    // Execute
    ret = fn_execute(stmt);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLExecute", stmt, SQL_HANDLE_STMT);
        fn_free_handle(SQL_HANDLE_STMT, stmt);
        return results;
    }

    // Get column info
    short col_count = 0;
    fn_num_result_cols(stmt, &col_count);

    Vector<String> col_names;
    for (short i = 1; i <= col_count; i++) {
        char col_name[256] = {0};
        short name_len = 0;
        short data_type = 0;
        unsigned long col_size = 0;
        short decimal_digits = 0;
        short nullable = 0;
        fn_describe_col(stmt, (unsigned short)i, col_name, 256, &name_len,
                        &data_type, &col_size, &decimal_digits, &nullable);
        col_names.push_back(String::utf8(col_name));
    }

    // Fetch rows
    while (fn_fetch(stmt) == SQL_SUCCESS) {
        Dictionary row;
        for (short i = 1; i <= col_count; i++) {
            char buffer[8192] = {0};
            long indicator = 0;
            ret = fn_get_data(stmt, (unsigned short)i, SQL_C_CHAR,
                              buffer, sizeof(buffer), &indicator);
            if (indicator == -1) {
                row[col_names[i - 1]] = Variant();
            } else if (ret == SQL_SUCCESS || ret == SQL_SUCCESS_WITH_INFO) {
                row[col_names[i - 1]] = String::utf8(buffer);
            } else {
                row[col_names[i - 1]] = Variant();
            }
        }
        results.push_back(row);
    }

    fn_free_handle(SQL_HANDLE_STMT, stmt);
    return results;
}

Variant VGOdbc::query_scalar(const String &p_sql) {
    Array rows = query(p_sql);
    if (rows.size() == 0) return Variant();
    Dictionary first_row = rows[0];
    Array keys = first_row.keys();
    if (keys.size() == 0) return Variant();
    return first_row[keys[0]];
}

bool VGOdbc::begin_transaction() {
    // ODBC auto-commit is on by default; beginning a transaction
    // is implicit when you set auto-commit off. For simplicity,
    // we issue a SQL "BEGIN" command or rely on SQLEndTran.
    // Most ODBC drivers support this approach.
    return execute("BEGIN");
}

bool VGOdbc::commit() {
    if (!is_open || !conn_handle || !fn_end_tran) {
        last_error = "Not connected";
        return false;
    }

    short ret = fn_end_tran(SQL_HANDLE_DBC, conn_handle, SQL_COMMIT);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLEndTran(COMMIT)", conn_handle, SQL_HANDLE_DBC);
        return false;
    }
    return true;
}

bool VGOdbc::rollback() {
    if (!is_open || !conn_handle || !fn_end_tran) {
        last_error = "Not connected";
        return false;
    }

    short ret = fn_end_tran(SQL_HANDLE_DBC, conn_handle, SQL_ROLLBACK);
    if (ret != SQL_SUCCESS && ret != SQL_SUCCESS_WITH_INFO) {
        extract_error("SQLEndTran(ROLLBACK)", conn_handle, SQL_HANDLE_DBC);
        return false;
    }
    return true;
}

Array VGOdbc::get_tables() {
    Array tables;
    Array rows = query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name");
    for (int i = 0; i < rows.size(); i++) {
        Dictionary row = rows[i];
        Array keys = row.keys();
        if (keys.size() > 0) {
            tables.push_back(row[keys[0]]);
        }
    }
    return tables;
}

bool VGOdbc::table_exists(const String &p_table_name) {
    Array rows = query(String("SELECT table_name FROM information_schema.tables WHERE table_name = '") +
                       p_table_name.replace("'", "''") + String("' LIMIT 1"));
    return rows.size() > 0;
}

Array VGOdbc::list_drivers() {
    Array drivers;

#if defined(__linux__) || defined(__APPLE__)
    // Try to load ODBC and use SQLDrivers
    void *lib = nullptr;
    #if defined(__linux__)
    lib = dlopen("libodbc.so", RTLD_LAZY);
    if (!lib) lib = dlopen("libodbc.so.2", RTLD_LAZY);
    #else
    lib = dlopen("libodbc.dylib", RTLD_LAZY);
    if (!lib) lib = dlopen("/opt/homebrew/lib/libodbc.dylib", RTLD_LAZY);
    #endif

    if (!lib) return drivers;

    // Attempt to enumerate drivers via SQLDrivers
    typedef short (*sql_alloc_handle_t)(short, void *, void **);
    typedef short (*sql_set_env_attr_t)(void *, int, void *, int);
    typedef short (*sql_free_handle_t)(short, void *);
    typedef short (*sql_drivers_t)(void *, unsigned short, char *, short, short *, char *, short, short *);

    auto f_alloc = (sql_alloc_handle_t)dlsym(lib, "SQLAllocHandle");
    auto f_setenv = (sql_set_env_attr_t)dlsym(lib, "SQLSetEnvAttr");
    auto f_free = (sql_free_handle_t)dlsym(lib, "SQLFreeHandle");
    auto f_drivers = (sql_drivers_t)dlsym(lib, "SQLDrivers");

    if (f_alloc && f_setenv && f_free && f_drivers) {
        void *env = nullptr;
        if (f_alloc(SQL_HANDLE_ENV, nullptr, &env) == SQL_SUCCESS) {
            f_setenv(env, SQL_ATTR_ODBC_VERSION, (void *)(intptr_t)SQL_OV_ODBC3, 0);

            char driver_desc[256] = {0};
            char driver_attr[256] = {0};
            short desc_len = 0;
            short attr_len = 0;
            unsigned short direction = 2; // SQL_FETCH_FIRST

            while (f_drivers(env, direction, driver_desc, 256, &desc_len,
                             driver_attr, 256, &attr_len) == SQL_SUCCESS) {
                drivers.push_back(String::utf8(driver_desc));
                direction = SQL_FETCH_NEXT;
            }

            f_free(SQL_HANDLE_ENV, env);
        }
    }

    dlclose(lib);
#elif defined(_WIN32)
    // Windows: attempt via odbc32.dll
    void *lib = (void *)LoadLibraryA("odbc32.dll");
    if (!lib) return drivers;

    typedef short (*sql_alloc_handle_t)(short, void *, void **);
    typedef short (*sql_set_env_attr_t)(void *, int, void *, int);
    typedef short (*sql_free_handle_t)(short, void *);
    typedef short (*sql_drivers_t)(void *, unsigned short, char *, short, short *, char *, short, short *);

    auto f_alloc = (sql_alloc_handle_t)GetProcAddress((HMODULE)lib, "SQLAllocHandle");
    auto f_setenv = (sql_set_env_attr_t)GetProcAddress((HMODULE)lib, "SQLSetEnvAttr");
    auto f_free = (sql_free_handle_t)GetProcAddress((HMODULE)lib, "SQLFreeHandle");
    auto f_drivers = (sql_drivers_t)GetProcAddress((HMODULE)lib, "SQLDrivers");

    if (f_alloc && f_setenv && f_free && f_drivers) {
        void *env = nullptr;
        if (f_alloc(SQL_HANDLE_ENV, nullptr, &env) == SQL_SUCCESS) {
            f_setenv(env, SQL_ATTR_ODBC_VERSION, (void *)(intptr_t)SQL_OV_ODBC3, 0);

            char driver_desc[256] = {0};
            char driver_attr[256] = {0};
            short desc_len = 0;
            short attr_len = 0;
            unsigned short direction = 2; // SQL_FETCH_FIRST

            while (f_drivers(env, direction, driver_desc, 256, &desc_len,
                             driver_attr, 256, &attr_len) == SQL_SUCCESS) {
                drivers.push_back(String::utf8(driver_desc));
                direction = SQL_FETCH_NEXT;
            }

            f_free(SQL_HANDLE_ENV, env);
        }
    }

    FreeLibrary((HMODULE)lib);
#endif

    return drivers;
}

bool VGOdbc::is_odbc_available() {
#if defined(__linux__) || defined(__APPLE__)
    #if defined(__linux__)
    void *lib = dlopen("libodbc.so", RTLD_LAZY);
    if (!lib) lib = dlopen("libodbc.so.2", RTLD_LAZY);
    #else
    void *lib = dlopen("libodbc.dylib", RTLD_LAZY);
    if (!lib) lib = dlopen("/opt/homebrew/lib/libodbc.dylib", RTLD_LAZY);
    #endif
    if (lib) {
        dlclose(lib);
        return true;
    }
    return false;
#elif defined(_WIN32)
    HMODULE lib = LoadLibraryA("odbc32.dll");
    if (lib) {
        FreeLibrary(lib);
        return true;
    }
    return false;
#else
    return false;
#endif
}
