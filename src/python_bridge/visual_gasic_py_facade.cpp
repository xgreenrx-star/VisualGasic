// VisualGasic Python Bridge — Unified Facade Implementation
//
// Phase 2: Tier A worker bootstrap. Launches python_worker.py as a subprocess
// via VGProcess, communicates with length-prefixed JSON messages over
// stdin/stdout pipes, and monitors for crashes with auto-restart.
//
// Key design decisions:
//   - Worker stdout = protocol channel (length-prefixed JSON frames)
//   - Worker stderr = diagnostic channel (printed to Godot console as-is)
//   - All I/O uses read_exact/write_all for framed safety (handles partial reads)
//   - Restart preserves imported module cache across worker deaths
//
// Phase 6+ will add embedded CPython (Tier B) behind VG_HAS_PYTHON.

#include "visual_gasic_py_facade.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/variant/char_string.hpp>

#include <cstdio>
#include <cstring>
#include <sstream>
#include <vector>
#include <algorithm>

#if defined(__linux__) || defined(__APPLE__)
#include <unistd.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <signal.h>
#include <fcntl.h>
#include <errno.h>
#include <poll.h>
#endif

using namespace godot;

// --------------------------------------------------------------------------
// Utility: read_exact / write_all (framing-safe I/O)
// --------------------------------------------------------------------------

bool PyBridgeFacade::write_all(int fd, const uint8_t *data, size_t len) {
    while (len > 0) {
        ssize_t n = ::write(fd, data, len);
        if (n < 0) {
            if (errno == EINTR) continue;
            return false;
        }
        data += n;
        len -= n;
    }
    return true;
}

bool PyBridgeFacade::read_exact(int fd, uint8_t *buf, size_t len) {
    while (len > 0) {
        ssize_t n = ::read(fd, buf, len);
        if (n < 0) {
            if (errno == EINTR) continue;
            return false;
        }
        if (n == 0) return false; // EOF
        buf += n;
        len -= n;
    }
    return true;
}

// --------------------------------------------------------------------------
// Lifecycle
// --------------------------------------------------------------------------

PyBridgeFacade::PyBridgeFacade() {
    initialized = false;
    embedded_mode = false;
    status_message = "Python bridge not initialized";
    worker_pid = -1;
    worker_stdin_fd = -1;
    worker_stdout_fd = -1;
    next_request_id = 1;
}

PyBridgeFacade::~PyBridgeFacade() {
    if (initialized) {
        shutdown();
    }
#if defined(__linux__) || defined(__APPLE__)
    if (worker_stdin_fd >= 0) { ::close(worker_stdin_fd); worker_stdin_fd = -1; }
    if (worker_stdout_fd >= 0) { ::close(worker_stdout_fd); worker_stdout_fd = -1; }
#endif
}

// --------------------------------------------------------------------------
// Binding
// --------------------------------------------------------------------------

void PyBridgeFacade::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize_bridge"), &PyBridgeFacade::initialize_bridge);
    ClassDB::bind_static_method("PyBridgeFacade", D_METHOD("is_available"),
                                &PyBridgeFacade::is_available);
    ClassDB::bind_method(D_METHOD("get_status"), &PyBridgeFacade::get_status);
    ClassDB::bind_method(D_METHOD("py_import", "module_name"), &PyBridgeFacade::py_import);
    ClassDB::bind_method(D_METHOD("py_call", "handle", "method", "args"), &PyBridgeFacade::py_call);
    ClassDB::bind_method(D_METHOD("py_call_async", "module", "method", "args"),
                         &PyBridgeFacade::py_call_async);
    ClassDB::bind_method(D_METHOD("py_process_buffer", "handle", "method", "buffer"),
                         &PyBridgeFacade::py_process_buffer);
    ClassDB::bind_method(D_METHOD("shutdown"), &PyBridgeFacade::shutdown);

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("InitializeBridge"), &PyBridgeFacade::initialize_bridge);
    ClassDB::bind_static_method("PyBridgeFacade", D_METHOD("IsAvailable"), &PyBridgeFacade::is_available);
    ClassDB::bind_method(D_METHOD("GetStatus"), &PyBridgeFacade::get_status);
    ClassDB::bind_method(D_METHOD("PyImport", "module_name"), &PyBridgeFacade::py_import);
    ClassDB::bind_method(D_METHOD("PyCall", "handle", "method", "args"), &PyBridgeFacade::py_call);
    ClassDB::bind_method(D_METHOD("PyCallAsync", "module", "method", "args"),
                         &PyBridgeFacade::py_call_async);
    ClassDB::bind_method(D_METHOD("PyProcessBuffer", "handle", "method", "buffer"),
                         &PyBridgeFacade::py_process_buffer);
}

// --------------------------------------------------------------------------
// Initialization
// --------------------------------------------------------------------------

bool PyBridgeFacade::initialize_bridge() {
    if (initialized) return true;

    // Check project setting for backend selection.
    bool embed = false;
    if (ProjectSettings::get_singleton()->has_setting("vg/python/embedded_enabled")) {
        embed = ProjectSettings::get_singleton()->get_setting("vg/python/embedded_enabled");
    }

    if (embed) {
#ifdef VG_HAS_PYTHON
        embedded_mode = true;
        status_message = "Tier B embedded CPython requested but not implemented (Phase 6)";
        initialized = false;
        UtilityFunctions::print("[PyBridgeFacade] ", status_message);
        return false;
#else
        embedded_mode = false;
        status_message = "Tier B requested but VG built without python=1. "
                         "Rebuild with 'scons python=1' or disable vg/python/embedded_enabled.";
        initialized = false;
        UtilityFunctions::printerr("[PyBridgeFacade] ", status_message);
        return false;
#endif
    }

    // Tier A — out-of-process worker (default)
    embedded_mode = false;

    if (!launch_worker()) {
        status_message = "Failed to launch Python worker. Ensure Python 3 is installed.";
        initialized = false;
        UtilityFunctions::printerr("[PyBridgeFacade] ", status_message);
        return false;
    }

    // Ping to verify connectivity
    Dictionary ping_response = send_request("ping", "", "", Array());
    if (ping_response.has("status") && String(ping_response["status"]) == "ok") {
        Dictionary value = ping_response["value"];
        String py_ver = value.has("python_version") ? String(value["python_version"]) : "unknown";
        status_message = "Tier A — worker connected (Python " + py_ver + ")";
        initialized = true;
        UtilityFunctions::print("[PyBridgeFacade] ", status_message);
        return true;
    }

    String err = ping_response.has("message") ? String(ping_response["message"]) : "unknown error";
    status_message = "Tier A — worker ping failed: " + err;
    initialized = false;
    kill_worker();
    UtilityFunctions::printerr("[PyBridgeFacade] ", status_message);
    return false;
}

bool PyBridgeFacade::is_available() {
    // Check if python3 or python is on PATH via popen
    FILE *fp = popen("python3 --version 2>/dev/null || python --version 2>/dev/null", "r");
    if (!fp) return false;
    char buf[128];
    bool found = fgets(buf, sizeof(buf), fp) != nullptr;
    pclose(fp);
    return found;
}

String PyBridgeFacade::get_status() {
    if (!initialized) return status_message;
    if (embedded_mode) return status_message;
    if (!check_worker_alive()) {
        return status_message + " [WORKER DIED]";
    }
    return status_message;
}

// --------------------------------------------------------------------------
// Worker lifecycle
// --------------------------------------------------------------------------

bool PyBridgeFacade::launch_worker() {
    String worker_script = find_worker_script();
    if (worker_script.is_empty()) {
        UtilityFunctions::printerr("[PyBridgeFacade] Cannot find python_worker.py");
        return false;
    }

#if defined(__linux__) || defined(__APPLE__)
    // Create pipes:
    //   stdin_pipe  = parent writes → child reads  (commands)
    //   stdout_pipe = child writes  → parent reads  (protocol responses)
    //   stderr is NOT redirected — child writes diagnostics to Godot console
    int stdin_pipe[2], stdout_pipe[2];
    if (pipe(stdin_pipe) < 0) {
        UtilityFunctions::printerr("[PyBridgeFacade] pipe() failed: ", strerror(errno));
        return false;
    }
    if (pipe(stdout_pipe) < 0) {
        ::close(stdin_pipe[0]);
        ::close(stdin_pipe[1]);
        UtilityFunctions::printerr("[PyBridgeFacade] pipe() failed: ", strerror(errno));
        return false;
    }

    pid_t pid = fork();
    if (pid < 0) {
        ::close(stdin_pipe[0]); ::close(stdin_pipe[1]);
        ::close(stdout_pipe[0]); ::close(stdout_pipe[1]);
        UtilityFunctions::printerr("[PyBridgeFacade] fork() failed: ", strerror(errno));
        return false;
    }

    if (pid == 0) {
        // --- Child process ---
        ::close(stdin_pipe[1]);  // Close write end (parent's side)
        ::close(stdout_pipe[0]); // Close read end (parent's side)

        // Wire pipes: child stdin ← parent writes, child stdout → parent reads
        dup2(stdin_pipe[0], STDIN_FILENO);
        dup2(stdout_pipe[1], STDOUT_FILENO);

        ::close(stdin_pipe[0]);
        ::close(stdout_pipe[1]);

        // stderr is NOT redirected — child's Python errors/warnings
        // appear directly in Godot's console for diagnostics.

        // Try python3 first, fall back to python
        CharString script_path = worker_script.utf8();
        execlp("python3", "python3", script_path.get_data(), nullptr);
        execlp("python", "python", script_path.get_data(), nullptr);

        // Both failed — write to stderr (visible in Godot console)
        const char *err_msg = "[PyBridgeFacade Worker] Python not found\n";
        ::write(STDERR_FILENO, err_msg, strlen(err_msg));
        _exit(127);
    }

    // --- Parent process ---
    ::close(stdin_pipe[0]);  // Close read end
    ::close(stdout_pipe[1]); // Close write end

    worker_stdin_fd = stdin_pipe[1];   // Write end → worker's stdin
    worker_stdout_fd = stdout_pipe[0]; // Read end ← worker's stdout
    worker_pid = (int)pid;

    UtilityFunctions::print("[PyBridgeFacade] Worker launched (PID ", worker_pid, ")");
    return true;

#elif defined(_WIN32)
    UtilityFunctions::printerr("[PyBridgeFacade] Windows worker launch not yet implemented");
    return false;
#else
    UtilityFunctions::printerr("[PyBridgeFacade] Worker launch not supported on this platform");
    return false;
#endif
}

void PyBridgeFacade::kill_worker() {
    if (worker_pid <= 0) return;

#if defined(__linux__) || defined(__APPLE__)
    // Graceful shutdown via IPC
    Dictionary shutdown_req;
    shutdown_req["kind"] = "shutdown";
    shutdown_req["request_id"] = 0;
    write_to_worker(JSON::stringify(shutdown_req));
    usleep(500000);

    // SIGTERM
    kill(worker_pid, SIGTERM);
    usleep(100000);

    // SIGKILL if still alive
    int status;
    if (waitpid(worker_pid, &status, WNOHANG) == 0) {
        kill(worker_pid, SIGKILL);
        waitpid(worker_pid, &status, 0);
    }
#endif

    if (worker_stdin_fd >= 0) { ::close(worker_stdin_fd); worker_stdin_fd = -1; }
    if (worker_stdout_fd >= 0) { ::close(worker_stdout_fd); worker_stdout_fd = -1; }

    UtilityFunctions::print("[PyBridgeFacade] Worker (PID ", worker_pid, ") terminated");
    worker_pid = -1;
}

bool PyBridgeFacade::check_worker_alive() {
    if (worker_pid <= 0) return false;

#if defined(__linux__) || defined(__APPLE__)
    int status;
    pid_t result = waitpid(worker_pid, &status, WNOHANG);
    if (result == 0) return true; // Still running

    if (WIFEXITED(status)) {
        UtilityFunctions::print("[PyBridgeFacade] Worker exited with code ", WEXITSTATUS(status));
    }
    worker_pid = -1;
    return false;
#else
    return false;
#endif
}

void PyBridgeFacade::queue_restart() {
    // Save module list *before* killing the worker
    std::vector<String> modules_to_reimport = imported_modules;

    UtilityFunctions::print("[PyBridgeFacade] Queueing worker restart (", modules_to_reimport.size(), " modules cached)...");
    kill_worker();

    if (launch_worker()) {
        // Re-import previously cached modules into the new worker
        for (const String &mod : modules_to_reimport) {
            Dictionary resp = send_request("import", mod, "", Array());
            if (resp.has("status") && String(resp["status"]) != "ok") {
                String err = resp.has("message") ? String(resp["message"]) : "unknown";
                UtilityFunctions::printerr("[PyBridgeFacade] Re-import of '", mod, "' failed: ", err);
            }
            // Restore cache entry
            if (std::find(imported_modules.begin(), imported_modules.end(), mod)
                == imported_modules.end()) {
                imported_modules.push_back(mod);
            }
        }
        status_message = "Tier A — worker restarted";
        initialized = true;
        UtilityFunctions::print("[PyBridgeFacade] Worker restarted successfully");
    } else {
        status_message = "Tier A — worker restart failed";
        initialized = false;
        UtilityFunctions::printerr("[PyBridgeFacade] Worker restart failed");
    }
}

// --------------------------------------------------------------------------
// IPC communication
// --------------------------------------------------------------------------

Dictionary PyBridgeFacade::send_request(const String &p_kind, const String &p_module,
                                         const String &p_method, const Array &p_args) {
    std::lock_guard<std::mutex> lock(request_mutex);

    if (!check_worker_alive()) {
        Dictionary err_resp;
        err_resp["status"] = "error";
        err_resp["message"] = "Worker not running";
        return err_resp;
    }

    int req_id = next_request_id++;

    // Build the JSON request
    Dictionary request;
    request["kind"] = p_kind;
    request["request_id"] = req_id;
    if (!p_module.is_empty()) request["module"] = p_module;
    if (!p_method.is_empty()) request["method"] = p_method;
    if (p_args.size() > 0) request["args"] = p_args;

    String json = JSON::stringify(request);
    if (!write_to_worker(json)) {
        Dictionary err_resp;
        err_resp["status"] = "error";
        err_resp["message"] = "Failed to write to worker";
        return err_resp;
    }

    // Read the response
    String response = read_from_worker(5000);
    if (response.is_empty()) {
        Dictionary err_resp;
        err_resp["status"] = "error";
        err_resp["message"] = "Worker timed out or disconnected";
        return err_resp;
    }

    // Parse JSON response
    Variant parsed = JSON::parse_string(response);
    if (parsed.get_type() != Variant::DICTIONARY) {
        Dictionary err_resp;
        err_resp["status"] = "error";
        err_resp["message"] = "Invalid JSON response from worker";
        return err_resp;
    }

    return parsed;
}

bool PyBridgeFacade::write_to_worker(const String &p_json) {
    if (worker_stdin_fd < 0) return false;

    CharString utf8 = p_json.utf8();
    uint32_t len = (uint32_t)utf8.length();

    // 4-byte length prefix (little-endian)
    uint8_t header[4];
    header[0] = len & 0xFF;
    header[1] = (len >> 8) & 0xFF;
    header[2] = (len >> 16) & 0xFF;
    header[3] = (len >> 24) & 0xFF;

    return write_all(worker_stdin_fd, header, 4)
        && write_all(worker_stdin_fd, (const uint8_t *)utf8.get_data(), len);
}

String PyBridgeFacade::read_from_worker(int p_timeout_ms) {
    if (worker_stdout_fd < 0) return "";

    // Poll for data availability
    struct pollfd pfd;
    pfd.fd = worker_stdout_fd;
    pfd.events = POLLIN;

    int ret = poll(&pfd, 1, p_timeout_ms);
    if (ret <= 0) return ""; // Timeout or error

    // Read the 4-byte length prefix via read_exact
    uint8_t header[4];
    if (!read_exact(worker_stdout_fd, header, 4)) return "";

    uint32_t payload_len = (uint32_t)header[0]
                         | ((uint32_t)header[1] << 8)
                         | ((uint32_t)header[2] << 16)
                         | ((uint32_t)header[3] << 24);

    if (payload_len == 0) return "";
    if (payload_len > 1024 * 1024) { // 1MB safety cap
        UtilityFunctions::printerr("[PyBridgeFacade] Response too large: ", payload_len, " bytes");
        return "";
    }

    // Read the payload via read_exact
    std::vector<char> buf(payload_len + 1, 0);
    if (!read_exact(worker_stdout_fd, (uint8_t *)buf.data(), payload_len)) return "";
    buf[payload_len] = '\0';

    return String::utf8(buf.data(), payload_len);
}

String PyBridgeFacade::find_worker_script() {
    String addon_paths[] = {
        "addons/visual_gasic/python_worker.py",
        "../addons/visual_gasic/python_worker.py",
        "../../addons/visual_gasic/python_worker.py",
    };

    for (const String &path : addon_paths) {
        if (FileAccess::file_exists(path)) {
            return path;
        }
    }

    String exe_path = OS::get_singleton()->get_executable_path().get_base_dir();
    String candidate = exe_path.path_join("addons/visual_gasic/python_worker.py");
    if (FileAccess::file_exists(candidate)) {
        return candidate;
    }

    return "";
}

// --------------------------------------------------------------------------
// Core API
// --------------------------------------------------------------------------

Variant PyBridgeFacade::py_import(const String &p_module_name) {
    if (!initialized) {
        UtilityFunctions::printerr("[PyBridgeFacade] Python bridge not initialized.");
        return Variant();
    }

    if (embedded_mode) {
        UtilityFunctions::printerr("[PyBridgeFacade] Tier B not yet implemented.");
        return Variant();
    }

    Dictionary response = send_request("import", p_module_name, "", Array());

    if (response.has("status") && String(response["status"]) == "ok") {
        // Add to cache if not already present
        if (std::find(imported_modules.begin(), imported_modules.end(), p_module_name)
            == imported_modules.end()) {
            imported_modules.push_back(p_module_name);
        }
        return p_module_name; // Module name is the opaque handle
    }

    String err = response.has("message") ? String(response["message"]) : "unknown error";
    UtilityFunctions::printerr("[PyBridgeFacade] Import failed for '", p_module_name, "': ", err);
    return Variant();
}

Variant PyBridgeFacade::py_call(const Variant &p_handle, const String &p_method,
                                 const Array &p_args) {
    if (!initialized) {
        UtilityFunctions::printerr("[PyBridgeFacade] Python bridge not initialized.");
        return Variant();
    }

    if (embedded_mode) {
        UtilityFunctions::printerr("[PyBridgeFacade] Tier B not yet implemented.");
        return Variant();
    }

    String module_name = p_handle;
    Dictionary response = send_request("call", module_name, p_method, p_args);

    if (response.has("status") && String(response["status"]) == "ok") {
        return response["value"];
    }

    String err = response.has("message") ? String(response["message"]) : "unknown error";
    UtilityFunctions::printerr("[PyBridgeFacade] Call failed: ", module_name, ".", p_method, ": ", err);
    return Variant();
}

Variant PyBridgeFacade::py_call_async(const String &p_module, const String &p_method,
                                       const Array &p_args) {
    if (!initialized) {
        UtilityFunctions::printerr("[PyBridgeFacade] Python bridge not initialized.");
        return Variant();
    }

    // Phase 3 will route through the VG async queue
    UtilityFunctions::print("[PyBridgeFacade] Async call to ", p_module, ".", p_method,
                            " — running synchronously (Phase 3 pending)");
    return py_call(p_module, p_method, p_args);
}

Variant PyBridgeFacade::py_process_buffer(const Variant &p_handle, const String &p_method,
                                           const PackedByteArray &p_buffer) {
    if (!initialized) {
        UtilityFunctions::printerr("[PyBridgeFacade] Python bridge not initialized.");
        return Variant();
    }

    // Phase 7 will add zero-copy binary transfer
    UtilityFunctions::print("[PyBridgeFacade] Buffer processing to ", p_method,
                            " — serializing as JSON (Phase 7 pending)");

    Array args;
    args.push_back(p_buffer);
    return py_call(p_handle, p_method, args);
}

void PyBridgeFacade::shutdown() {
    if (!initialized && worker_pid <= 0) return;

    UtilityFunctions::print("[PyBridgeFacade] Shutting down...");
    kill_worker();
    imported_modules.clear();
    initialized = false;
    status_message = "Python bridge shut down";
}
