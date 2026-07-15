
// VisualGasic Python Bridge — Unified Facade
//
// This is the single C++ API surface that both Tier A (out-of-process worker)
// and Tier B (embedded CPython) backends implement. VG script code calls
// PyImport(), PyCallAsync(), and PyProcessBuffer() through this facade.
// The backend is selected at runtime via the vg/python/embedded_enabled
// project setting — the script never sees the difference.
//
// Phase 2/3 (shipped Jul 14): Real PyCallAsync via background thread + VGTask
// integration, binary data lane for PyProcessBuffer, Windows CreateProcess
// launch, auto-restart on crash, structured error model, project settings,
// PyEnvInfo / PyLastError / PyCallMany, and full test matrix.

#ifndef VISUAL_GASIC_PY_FACADE_H
#define VISUAL_GASIC_PY_FACADE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <queue>
#include <mutex>
#include <thread>
#include <atomic>

namespace godot {

// --------------------------------------------------------------------------
// PyAsyncTask — lightweight RefCounted task handle for PyCallAsync
// Mirrors VGTask's public surface (IsComplete, IsFailed, Result, ErrorMessage)
// so that VG's Await keyword can duck-type on these members without changes
// to the VG runtime.
// --------------------------------------------------------------------------
class PyAsyncTask : public RefCounted {
    GDCLASS(PyAsyncTask, RefCounted)

public:
    enum State { PENDING, RUNNING, COMPLETED, FAILED };

    PyAsyncTask();
    ~PyAsyncTask();

    // Run a callable on a background thread.
    void run(const Callable &p_callable);

    // Status inspection — these match VGTask's property names.
    bool get_is_complete() const;
    bool get_is_running() const;
    bool get_is_failed() const;
    String get_status() const;
    Variant get_result();
    String get_error() const;

protected:
    static void _bind_methods();
    friend class PyBridgeFacade;

private:
    std::atomic<int> state_{PENDING};
    std::mutex result_mutex_;
    Variant result_;
    String error_message_;
    std::thread worker_;
};

// --------------------------------------------------------------------------
// PyBridgeFacade — main Python bridge interface
// --------------------------------------------------------------------------
class PyBridgeFacade : public RefCounted {
    GDCLASS(PyBridgeFacade, RefCounted)

protected:
    static void _bind_methods();

public:
    PyBridgeFacade();
    ~PyBridgeFacade();

    // --- Initialization ---
    bool initialize_bridge();
    static bool is_available();
    String get_status();

    // --- Core API ---
    Variant py_import(const String &p_module_name);
    Variant py_call(const Variant &p_handle, const String &p_method, const Array &p_args);

    // PyCallAsync — non-blocking variant. Returns a Ref<PyAsyncTask> that can
    // be polled or Await-ed. The task completes when the worker responds.
    Variant py_call_async(const String &p_module, const String &p_method, const Array &p_args);

    // PyProcessBuffer — bulk binary data lane. Uses the binary framing protocol
    // (Phase 2) to avoid JSON overhead for large PackedByteArray / numpy arrays.
    Variant py_process_buffer(const Variant &p_handle, const String &p_method,
                              const PackedByteArray &p_buffer);

    // Shut down the backend cleanly.
    void shutdown();

    // --- Phase 3 additions ---
    // Returns a Dictionary with structured details about the last error.
    Dictionary py_last_error();

    // Returns environment info: interpreter path, Python version, capabilities.
    Dictionary py_env_info();

    // Batch call — executes multiple calls in a single round-trip.
    Array py_call_many(const Array &p_calls);

    // --- Project-settings-backed config (cached at init) ---
    int get_worker_timeout_ms() const { return worker_timeout_ms_; }
    int get_max_payload_bytes() const { return max_payload_bytes_; }
    bool get_auto_restart() const { return auto_restart_; }

private:
    // --- Tier A worker management ---
    bool launch_worker();
    void kill_worker();
    bool check_worker_alive();
    void queue_restart();

    // Send a JSON request (and optional trailing binary blob) to the worker
    // and wait for a response (with optional trailing binary blob returned).
    Dictionary send_request(const String &p_kind, const String &p_module,
                            const String &p_method, const Array &p_args);
    Dictionary send_request_binary(const String &p_kind, const String &p_module,
                                    const String &p_method, const Array &p_args,
                                    const PackedByteArray &p_blob,
                                    PackedByteArray &r_out_blob);

    // Low-level I/O
    bool write_to_worker(const String &p_json);
    bool write_to_worker_raw(const uint8_t *data, size_t len);
    String read_from_worker(int p_timeout_ms = -1);
    bool read_raw_from_worker(PackedByteArray &r_out, int p_timeout_ms = -1);

    // Framing helpers
    bool write_all(int fd, const uint8_t *data, size_t len);
    bool read_exact(int fd, uint8_t *buf, size_t len);

    // Platform I/O abstraction
    bool platform_write(int fd, const uint8_t *data, size_t len);
    int platform_read_with_timeout(int fd, uint8_t *buf, size_t len, int timeout_ms);

    String find_worker_script();

    // Internal helpers
    void close_worker_fds();
    static Dictionary make_error(const String &p_message);
#ifdef _WIN32
    bool launch_worker_windows(const String &p_script_path);
#endif

    // --- State ---
    bool initialized;
    bool embedded_mode;
    String status_message;

    // Tier A worker state
    int worker_pid;
    int worker_stdin_fd;
    int worker_stdout_fd;

    // Project settings cache
    int worker_timeout_ms_;
    int max_payload_bytes_;
    bool auto_restart_;

    // Request tracking
    std::mutex request_mutex;
    int next_request_id;
    std::vector<String> imported_modules;

    // Last error detail (Phase 3C)
    Dictionary last_error_details_;
};

} // namespace godot

#endif // VISUAL_GASIC_PY_FACADE_H
