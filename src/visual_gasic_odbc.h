#ifndef VISUAL_GASIC_ODBC_H
#define VISUAL_GASIC_ODBC_H

// VGOdbc — Universal database access via ODBC
// Connects to ANY database that has an ODBC driver: SQL Server, PostgreSQL,
// MySQL, MariaDB, Oracle, Access, Excel, and more.
//
// Usage in VisualGasic:
//   ' Connect to a database
//   Dim db As New OdbcConnection
//   db.ConnectionString = "Driver={PostgreSQL};Server=localhost;Database=myapp;"
//   db.Open
//
//   ' Execute a query
//   db.Execute "INSERT INTO users (name, age) VALUES ('Alice', 30)"
//
//   ' Run a SELECT and read rows
//   Dim rows As Variant
//   rows = db.Query("SELECT * FROM users WHERE age > 25")
//   For Each row In rows
//       Print row("name"); " is "; row("age"); " years old"
//   Next
//
//   ' Parameterized queries (SQL injection safe)
//   rows = db.QueryParams("SELECT * FROM users WHERE name = ?", Array("Alice"))
//
//   ' Transactions
//   db.BeginTransaction
//   db.Execute "UPDATE accounts SET balance = balance - 100 WHERE id = 1"
//   db.Execute "UPDATE accounts SET balance = balance + 100 WHERE id = 2"
//   db.Commit
//
//   ' Clean up
//   db.Close
//
// ODBC Drivers:
//   Windows: Most databases pre-installed or available via ODBC admin
//   Linux:   Install via package manager, e.g. "apt install unixodbc libpq5"
//   macOS:   Install via Homebrew, e.g. "brew install unixodbc"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

class VGOdbc : public RefCounted {
    GDCLASS(VGOdbc, RefCounted);

    // ODBC handles (stored as void* to avoid #include <sql.h> in header)
    void *env_handle;    // SQLHENV
    void *conn_handle;   // SQLHDBC
    String connection_string;
    bool is_open;
    String last_error;
    int last_affected_rows;

    // ODBC library (loaded dynamically)
    void *odbc_lib;
    bool odbc_loaded;

    // ODBC function pointer types (simplified to void* for dynamic loading)
    // We load: SQLAllocHandle, SQLSetEnvAttr, SQLDriverConnect, SQLExecDirect,
    //          SQLFetch, SQLNumResultCols, SQLDescribeCol, SQLGetData,
    //          SQLFreeHandle, SQLDisconnect, SQLRowCount, SQLPrepare,
    //          SQLBindParameter, SQLExecute, SQLEndTran, SQLGetDiagRec
    typedef short (*sql_alloc_handle_fn)(short, void*, void**);
    typedef short (*sql_set_env_attr_fn)(void*, int, void*, int);
    typedef short (*sql_driver_connect_fn)(void*, void*, const char*, short, char*, short, short*, unsigned short);
    typedef short (*sql_exec_direct_fn)(void*, const char*, int);
    typedef short (*sql_fetch_fn)(void*);
    typedef short (*sql_num_result_cols_fn)(void*, short*);
    typedef short (*sql_describe_col_fn)(void*, unsigned short, char*, short, short*, short*, unsigned long*, short*, short*);
    typedef short (*sql_get_data_fn)(void*, unsigned short, short, void*, long, long*);
    typedef short (*sql_free_handle_fn)(short, void*);
    typedef short (*sql_disconnect_fn)(void*);
    typedef short (*sql_free_stmt_fn)(void*, unsigned short);
    typedef short (*sql_row_count_fn)(void*, long*);
    typedef short (*sql_prepare_fn)(void*, const char*, int);
    typedef short (*sql_bind_parameter_fn)(void*, unsigned short, short, short, short, unsigned long, short, void*, long, long*);
    typedef short (*sql_execute_fn)(void*);
    typedef short (*sql_end_tran_fn)(short, void*, short);
    typedef short (*sql_get_diag_rec_fn)(short, void*, short, char*, int*, char*, short, short*);
    typedef short (*sql_alloc_stmt_fn)(void*, void**);

    // Loaded function pointers
    sql_alloc_handle_fn fn_alloc_handle;
    sql_set_env_attr_fn fn_set_env_attr;
    sql_driver_connect_fn fn_driver_connect;
    sql_exec_direct_fn fn_exec_direct;
    sql_fetch_fn fn_fetch;
    sql_num_result_cols_fn fn_num_result_cols;
    sql_describe_col_fn fn_describe_col;
    sql_get_data_fn fn_get_data;
    sql_free_handle_fn fn_free_handle;
    sql_disconnect_fn fn_disconnect;
    sql_free_stmt_fn fn_free_stmt;
    sql_row_count_fn fn_row_count;
    sql_prepare_fn fn_prepare;
    sql_bind_parameter_fn fn_bind_parameter;
    sql_execute_fn fn_execute;
    sql_end_tran_fn fn_end_tran;
    sql_get_diag_rec_fn fn_get_diag_rec;

    bool load_odbc_library();
    void extract_error(const String &p_context, void *p_handle, short p_handle_type);

protected:
    static void _bind_methods();

public:
    VGOdbc();
    ~VGOdbc();

    // Connection management
    void set_connection_string(const String &p_cs);
    String get_connection_string() const { return connection_string; }
    bool open();
    bool open_with_string(const String &p_connection_string);
    void close();
    bool get_is_open() const { return is_open; }

    // Execute (INSERT, UPDATE, DELETE, DDL)
    bool execute(const String &p_sql);
    bool execute_params(const String &p_sql, const Array &p_params);

    // Query (SELECT — returns Array of Dictionary)
    Array query(const String &p_sql);
    Array query_params(const String &p_sql, const Array &p_params);

    // Scalar query — returns single value from first row, first column
    Variant query_scalar(const String &p_sql);

    // Transactions
    bool begin_transaction();
    bool commit();
    bool rollback();

    // Utility
    String get_last_error() const { return last_error; }
    int get_last_affected_rows() const { return last_affected_rows; }
    Array get_tables();
    bool table_exists(const String &p_table_name);

    // Convenience: list available ODBC drivers
    static Array list_drivers();
    static bool is_odbc_available();
};

#endif // VISUAL_GASIC_ODBC_H
