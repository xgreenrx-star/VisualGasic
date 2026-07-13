// VisualGasic Python Bridge — Unified Facade
//
// This is the single C++ API surface that both Tier A (out-of-process worker)
// and Tier B (embedded CPython) backends implement. VG script code calls
// PyImport(), PyCallAsync(), and PyProcessBuffer() through this facade.
// The backend is selected at runtime via the vg/python/embedded_enabled
// project setting — the script never sees the difference.
//
// Phase 2: Tier A worker bootstrap. The facade launches python_worker.py
// as a subprocess via VGProcess, communicates over stdin/stdout with
// length-prefixed JSON messages, and monitors for crashes with auto-restart.

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

namespace godot {

class PyBridgeFacade : public RefCounted {
    GDCLASS(PyBridgeFacade, RefCounted)

protected:
    static void _bind_methods();

public:
    PyBridgeFacade();
    ~PyBridgeFacade();

    // --- Initialization ---
    // Called once at startup. Checks the vg/python/embedded_enabled project
    // setting to select Tier B (embedded, requires python=1 build flag) vs
    // Tier A (out-of-process worker, default). Returns true if the selected
    // backend initialized successfully.
    bool initialize_bridge();

    // Returns true if Python is available on this platform.
    // Tier A: true if python was found on PATH and worker started.
    // Tier B: true if VG_HAS_PYTHON was defined at compile time.
    static bool is_available();

    // Returns a human-readable description of the active backend and its state.
    // E.g. "Tier A — worker connected (Python 3.11)" or "Tier B — embedded
    // (Python 3.11)" or "Python not available — no interpreter found".
    String get_status();

    // --- Core API (identical across both tiers) ---
    // Set <var> = PyImport("module_name")
    // Returns a String handle (the module name) for Tier A.
    Variant py_import(const String &p_module_name);

    // <handle>.<method>(<args>)
    // Calls a method on a previously imported Python module.
    // The handle from py_import() is used to identify the module.
    Variant py_call(const Variant &p_handle, const String &p_method, const Array &p_args);

    // PyCallAsync(<module>, <method>, <args>)
    // Non-blocking variant — queues on the async job system and returns a
    // TaskHandle that can be Await-ed.
    Variant py_call_async(const String &p_module, const String &p_method, const Array &p_args);

    // PyProcessBuffer(<handle>, <method>, <buffer>)
    // Explicit bulk-data lane. Transfers buffer data over the IPC binary channel.
    Variant py_process_buffer(const Variant &p_handle, const String &p_method,
                              const PackedByteArray &p_buffer);

    // Shut down the backend cleanly. Sends shutdown to worker (Tier A) or
    // calls Py_Finalize() (Tier B).
    void shutdown();

private:
    // --- Tier A worker management ---
    bool launch_worker();
    void kill_worker();
    bool check_worker_alive();
    void queue_restart();

    // Send a JSON request to the worker and wait for response.
    // Returns the response Dictionary, or an error dict on timeout/failure.
    Dictionary send_request(const String &p_kind, const String &p_module,
                            const String &p_method, const Array &p_args);

    // Low-level: write a framed message to worker stdin, read from stdout.
    bool write_to_worker(const String &p_json);
    String read_from_worker(int p_timeout_ms = 5000);

    // Framing helpers: read/write exactly N bytes (handles partial I/O).
    bool write_all(int fd, const uint8_t *data, size_t len);
    bool read_exact(int fd, uint8_t *buf, size_t len);

    // Find the python_worker.py script bundled with the addon.
    String find_worker_script();

    // --- State ---
    bool initialized;
    bool embedded_mode; // true = Tier B, false = Tier A
    String status_message;

    // Tier A worker state
    int worker_pid;       // PID of the python worker subprocess (or -1)
    int worker_stdin_fd;  // Write end of pipe to worker stdin
    int worker_stdout_fd; // Read end of pipe from worker stdout

    // Request tracking
    std::mutex request_mutex;
    int next_request_id;
    String pending_response;

    // Import cache — track which modules have been imported
    // so py_import() can be called multiple times safely.
    std::vector<String> imported_modules;
};

} // namespace godot

#endif // VISUAL_GASIC_PY_FACADE_H
