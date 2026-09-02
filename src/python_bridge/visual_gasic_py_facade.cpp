// VisualGasic Python Bridge — Unified Facade Implementation
//
// Phase 2/3 (shipped Jul 14): Real PyCallAsync via background thread + VGTask
// integration, binary data lane for PyProcessBuffer, Windows CreateProcess
// launch, auto-restart on crash, structured error model, project settings,
// PyEnvInfo / PyLastError / PyCallMany, and full test matrix.

#include "visual_gasic_py_facade.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/json.hpp>
#include "vg_json_typed.h"
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

#ifdef _WIN32
#include <windows.h>
#endif

using namespace godot;

// =========================================================================
// PyAsyncTask implementation
// =========================================================================

void PyAsyncTask::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_is_complete"), &PyAsyncTask::get_is_complete);
    ClassDB::bind_method(D_METHOD("get_is_running"), &PyAsyncTask::get_is_running);
    ClassDB::bind_method(D_METHOD("get_is_failed"), &PyAsyncTask::get_is_failed);
    ClassDB::bind_method(D_METHOD("get_status"), &PyAsyncTask::get_status);
    ClassDB::bind_method(D_METHOD("get_result"), &PyAsyncTask::get_result);
    ClassDB::bind_method(D_METHOD("get_error"), &PyAsyncTask::get_error);

    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsComplete"), "", "get_is_complete");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsRunning"), "", "get_is_running");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsFailed"), "", "get_is_failed");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Status"), "", "get_status");
    ADD_PROPERTY(PropertyInfo(Variant::NIL, "Result"), "", "get_result");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Error"), "", "get_error");
}

PyAsyncTask::PyAsyncTask() {
    state_.store(PENDING);
}

PyAsyncTask::~PyAsyncTask() {
    if (worker_.joinable()) worker_.join();
}

void PyAsyncTask::run(const Callable &p_callable) {
    if (state_.load() == RUNNING) return;
    if (worker_.joinable()) worker_.join();

    state_.store(RUNNING);

    worker_ = std::thread([this, p_callable]() {
        Variant res = p_callable.callv(Array());
        std::lock_guard<std::mutex> lock(result_mutex_);
        result_ = res;
        state_.store(COMPLETED);
    });
}

bool PyAsyncTask::get_is_complete() const { return state_.load() == COMPLETED; }
bool PyAsyncTask::get_is_running() const { return state_.load() == RUNNING; }
bool PyAsyncTask::get_is_failed() const { return state_.load() == FAILED; }

String PyAsyncTask::get_status() const {
    switch (state_.load()) {
        case PENDING: return "Pending";
        case RUNNING: return "Running";
        case COMPLETED: return "Completed";
        case FAILED: return "Failed";
    }
    return "Unknown";
}

Variant PyAsyncTask::get_result() {
    std::lock_guard<std::mutex> lock(result_mutex_);
    return result_;
}

String PyAsyncTask::get_error() const { return error_message_; }

// =========================================================================
// Platform I/O abstraction
// =========================================================================

#if defined(__linux__) || defined(__APPLE__)

bool PyBridgeFacade::platform_write(int fd, const uint8_t *data, size_t len) {
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

int PyBridgeFacade::platform_read_with_timeout(int fd, uint8_t *buf, size_t len, int timeout_ms) {
    if (timeout_ms > 0) {
        struct pollfd pfd;
        pfd.fd = fd;
        pfd.events = POLLIN;
        int ret = poll(&pfd, 1, timeout_ms);
        if (ret <= 0) return -1;
    }
    ssize_t n = ::read(fd, buf, len);
    if (n < 0) {
        if (errno == EINTR) return platform_read_with_timeout(fd, buf, len, timeout_ms);
        return -1;
    }
    if (n == 0) return -2;
    return (int)n;
}

#elif defined(_WIN32)

bool PyBridgeFacade::platform_write(int fd, const uint8_t *data, size_t len) {
    HANDLE h = (HANDLE)(intptr_t)fd;
    DWORD written;
    if (!WriteFile(h, data, (DWORD)len, &written, NULL)) return false;
    return (size_t)written == len;
}

int PyBridgeFacade::platform_read_with_timeout(int fd, uint8_t *buf, size_t len, int timeout_ms) {
    HANDLE h = (HANDLE)(intptr_t)fd;
    DWORD avail = 0;
    if (!PeekNamedPipe(h, NULL, 0, NULL, &avail, NULL)) return -1;
    if (avail == 0) {
        DWORD wait = WaitForSingleObject(h, timeout_ms > 0 ? (DWORD)timeout_ms : INFINITE);
        if (wait == WAIT_TIMEOUT) return -1;
        if (wait != WAIT_OBJECT_0) return -1;
        if (!PeekNamedPipe(h, NULL, 0, NULL, &avail, NULL)) return -1;
        if (avail == 0) return -2;
    }
    DWORD to_read = (DWORD)std::min((size_t)avail, len);
    DWORD read_count = 0;
    if (!ReadFile(h, buf, to_read, &read_count, NULL)) return -1;
    if (read_count == 0) return -2;
    return (int)read_count;
}

#else

bool PyBridgeFacade::platform_write(int, const uint8_t*, size_t) { return false; }
int PyBridgeFacade::platform_read_with_timeout(int, uint8_t*, size_t, int) { return -1; }

#endif

// --------------------------------------------------------------------------
// Framing-safe I/O wrappers
// --------------------------------------------------------------------------

bool PyBridgeFacade::write_all(int fd, const uint8_t *data, size_t len) {
    return platform_write(fd, data, len);
}

bool PyBridgeFacade::read_exact(int fd, uint8_t *buf, size_t len) {
    while (len > 0) {
        int n = platform_read_with_timeout(fd, buf, len, worker_timeout_ms_);
        if (n <= 0) return false;
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
    worker_timeout_ms_ = 5000;
    max_payload_bytes_ = 1024 * 1024;
    auto_restart_ = true;
}

PyBridgeFacade::~PyBridgeFacade() {
    if (initialized) shutdown();
    close_worker_fds();
}

void PyBridgeFacade::close_worker_fds() {
#if defined(__linux__) || defined(__APPLE__)
    if (worker_stdin_fd >= 0) { ::close(worker_stdin_fd); worker_stdin_fd = -1; }
    if (worker_stdout_fd >= 0) { ::close(worker_stdout_fd); worker_stdout_fd = -1; }
#elif defined(_WIN32)
    if (worker_stdin_fd >= 0) { CloseHandle((HANDLE)(intptr_t)worker_stdin_fd); worker_stdin_fd = -1; }
    if (worker_stdout_fd >= 0) { CloseHandle((HANDLE)(intptr_t)worker_stdout_fd); worker_stdout_fd = -1; }
#endif
}

// --------------------------------------------------------------------------
// Binding
// --------------------------------------------------------------------------

void PyBridgeFacade::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize_bridge"), &PyBridgeFacade::initialize_bridge);
    ClassDB::bind_static_method("PyBridgeFacade", D_METHOD("is_available"), &PyBridgeFacade::is_available);
    ClassDB::bind_method(D_METHOD("get_status"), &PyBridgeFacade::get_status);
    ClassDB::bind_method(D_METHOD("py_import", "module_name"), &PyBridgeFacade::py_import);
    ClassDB::bind_method(D_METHOD("py_call", "handle", "method", "args"), &PyBridgeFacade::py_call);
    ClassDB::bind_method(D_METHOD("py_call_async", "module", "method", "args"), &PyBridgeFacade::py_call_async);
    ClassDB::bind_method(D_METHOD("py_process_buffer", "handle", "method", "buffer"), &PyBridgeFacade::py_process_buffer);
    ClassDB::bind_method(D_METHOD("shutdown"), &PyBridgeFacade::shutdown);
    // Phase 3 additions
    ClassDB::bind_method(D_METHOD("py_last_error"), &PyBridgeFacade::py_last_error);
    ClassDB::bind_method(D_METHOD("py_env_info"), &PyBridgeFacade::py_env_info);
    ClassDB::bind_method(D_METHOD("py_call_many", "calls"), &PyBridgeFacade::py_call_many);
    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("InitializeBridge"), &PyBridgeFacade::initialize_bridge);
    ClassDB::bind_static_method("PyBridgeFacade", D_METHOD("IsAvailable"), &PyBridgeFacade::is_available);
    ClassDB::bind_method(D_METHOD("GetStatus"), &PyBridgeFacade::get_status);
    ClassDB::bind_method(D_METHOD("PyImport", "module_name"), &PyBridgeFacade::py_import);
    ClassDB::bind_method(D_METHOD("PyCall", "handle", "method", "args"), &PyBridgeFacade::py_call);
    ClassDB::bind_method(D_METHOD("PyCallAsync", "module", "method", "args"), &PyBridgeFacade::py_call_async);
    ClassDB::bind_method(D_METHOD("PyProcessBuffer", "handle", "method", "buffer"), &PyBridgeFacade::py_process_buffer);
    ClassDB::bind_method(D_METHOD("PyLastError"), &PyBridgeFacade::py_last_error);
    ClassDB::bind_method(D_METHOD("PyEnvInfo"), &PyBridgeFacade::py_env_info);
    ClassDB::bind_method(D_METHOD("PyCallMany", "calls"), &PyBridgeFacade::py_call_many);
}

Dictionary PyBridgeFacade::make_error(const String &p_message) {
    Dictionary err;
    err["status"] = "error";
    err["message"] = p_message;
    return err;
}

// --------------------------------------------------------------------------
// Initialization
// --------------------------------------------------------------------------

bool PyBridgeFacade::initialize_bridge() {
    if (initialized) return true;

    ProjectSettings *ps = ProjectSettings::get_singleton();
    if (ps->has_setting("vg/python/worker_timeout_ms"))
        worker_timeout_ms_ = (int)ps->get_setting("vg/python/worker_timeout_ms");
    if (ps->has_setting("vg/python/max_payload_bytes"))
        max_payload_bytes_ = (int)ps->get_setting("vg/python/max_payload_bytes");
    if (ps->has_setting("vg/python/auto_restart"))
        auto_restart_ = (bool)ps->get_setting("vg/python/auto_restart");

    bool embed = false;
    if (ps->has_setting("vg/python/embedded_enabled"))
        embed = ps->get_setting("vg/python/embedded_enabled");

    if (embed) {
#ifdef VG_HAS_PYTHON
        embedded_mode = true;
        status_message = "Tier B embedded CPython deferred";
        initialized = false;
        UtilityFunctions::print("[PyBridgeFacade] ", status_message);
        return false;
#else
        embedded_mode = false;
        status_message = "Tier B req. VG built without python=1";
        initialized = false;
        UtilityFunctions::printerr("[PyBridgeFacade] ", status_message);
        return false;
#endif
    }

    embedded_mode = false;
    if (!launch_worker()) {
        status_message = "Failed to launch Python worker. Ensure Python 3 is installed.";
        initialized = false;
        UtilityFunctions::printerr("[PyBridgeFacade] ", status_message);
        return false;
    }

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
#if defined(__linux__) || defined(__APPLE__)
    FILE *fp = popen("python3 --version 2>/dev/null || python --version 2>/dev/null", "r");
    if (!fp) return false;
    char buf[128];
    bool found = fgets(buf, sizeof(buf), fp) != nullptr;
    pclose(fp);
    return found;
#elif defined(_WIN32)
    FILE *fp = _popen("python --version 2>nul", "r");
    if (!fp) return false;
    char buf[128];
    bool found = fgets(buf, sizeof(buf), fp) != nullptr;
    _pclose(fp);
    return found;
#else
    return false;
#endif
}

String PyBridgeFacade::get_status() {
    if (!initialized) return status_message;
    if (embedded_mode) return status_message;
    if (!check_worker_alive()) return status_message + " [WORKER DIED]";
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
    int stdin_pipe[2], stdout_pipe[2];
    if (pipe(stdin_pipe) < 0) {
        UtilityFunctions::printerr("[PyBridgeFacade] pipe() failed: ", strerror(errno));
        return false;
    }
    if (pipe(stdout_pipe) < 0) {
        ::close(stdin_pipe[0]); ::close(stdin_pipe[1]);
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
        ::close(stdin_pipe[1]);
        ::close(stdout_pipe[0]);
        dup2(stdin_pipe[0], STDIN_FILENO);
        dup2(stdout_pipe[1], STDOUT_FILENO);
        ::close(stdin_pipe[0]);
        ::close(stdout_pipe[1]);
        CharString script_path = worker_script.utf8();
        execlp("python3", "python3", script_path.get_data(), nullptr);
        execlp("python", "python", script_path.get_data(), nullptr);
        const char *err_msg = "[PyBridgeFacade Worker] Python not found\n";
        ::write(STDERR_FILENO, err_msg, strlen(err_msg));
        _exit(127);
    }

    ::close(stdin_pipe[0]);
    ::close(stdout_pipe[1]);
    worker_stdin_fd = stdin_pipe[1];
    worker_stdout_fd = stdout_pipe[0];
    worker_pid = (int)pid;
    UtilityFunctions::print("[PyBridgeFacade] Worker launched (PID ", worker_pid, ")");
    return true;

#elif defined(_WIN32)
    return launch_worker_windows(worker_script);
#else
    UtilityFunctions::printerr("[PyBridgeFacade] Worker launch not supported");
    return false;
#endif
}

#ifdef _WIN32

bool PyBridgeFacade::launch_worker_windows(const String &p_script_path) {
    HANDLE h_stdin_rd, h_stdin_wr, h_stdout_rd, h_stdout_wr;
    SECURITY_ATTRIBUTES sa = { sizeof(SECURITY_ATTRIBUTES), NULL, TRUE };
    if (!CreatePipe(&h_stdin_rd, &h_stdin_wr, &sa, 0)) return false;
    if (!CreatePipe(&h_stdout_rd, &h_stdout_wr, &sa, 0)) {
        CloseHandle(h_stdin_rd); CloseHandle(h_stdin_wr);
        return false;
    }
    SetHandleInformation(h_stdin_wr, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(h_stdout_rd, HANDLE_FLAG_INHERIT, 0);

    CharString script_utf8 = p_script_path.utf8();
    // Build command: python <script_path>
    int wlen = MultiByteToWideChar(CP_UTF8, 0, script_utf8.get_data(), -1, NULL, 0);
    wchar_t *cmdline = (wchar_t*)alloca((wlen + 10) * sizeof(wchar_t));
    wcscpy(cmdline, L"python ");
    MultiByteToWideChar(CP_UTF8, 0, script_utf8.get_data(), -1, cmdline + 7, wlen + 3);

    PROCESS_INFORMATION pi = {0};
    STARTUPINFOW si = {0};
    si.cb = sizeof(STARTUPINFOW);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput = h_stdin_rd;
    si.hStdOutput = h_stdout_wr;
    si.hStdError = GetStdHandle(STD_ERROR_HANDLE);

    BOOL created = CreateProcessW(NULL, cmdline, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi);
    CloseHandle(h_stdin_rd);
    CloseHandle(h_stdout_wr);
    if (!created) {
        CloseHandle(h_stdin_wr);
        CloseHandle(h_stdout_rd);
        return false;
    }
    worker_stdin_fd = (int)(intptr_t)h_stdin_wr;
    worker_stdout_fd = (int)(intptr_t)h_stdout_rd;
    worker_pid = (int)pi.dwProcessId;
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return true;
}

#endif

void PyBridgeFacade::kill_worker() {
    if (worker_pid <= 0) return;

#if defined(__linux__) || defined(__APPLE__)
    Dictionary shutdown_req;
    shutdown_req["kind"] = "shutdown";
    shutdown_req["request_id"] = 0;
    write_to_worker(vg_json_stringify_typed(shutdown_req));

    int status;
    for (int i = 0; i < 50; i++) {
        if (waitpid(worker_pid, &status, WNOHANG) != 0) break;
        usleep(10000);
    }
    kill(worker_pid, SIGTERM);
    usleep(100000);
    if (waitpid(worker_pid, &status, WNOHANG) == 0) {
        kill(worker_pid, SIGKILL);
        waitpid(worker_pid, &status, 0);
    }
#elif defined(_WIN32)
    Dictionary shutdown_req;
    shutdown_req["kind"] = "shutdown";
    shutdown_req["request_id"] = 0;
    write_to_worker(vg_json_stringify_typed(shutdown_req));
    HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, (DWORD)worker_pid);
    if (hProcess) {
        WaitForSingleObject(hProcess, 500);
        TerminateProcess(hProcess, 1);
        CloseHandle(hProcess);
    }
#endif

    close_worker_fds();
    UtilityFunctions::print("[PyBridgeFacade] Worker (PID ", worker_pid, ") terminated");
    worker_pid = -1;
}

bool PyBridgeFacade::check_worker_alive() {
    if (worker_pid <= 0) return false;
#if defined(__linux__) || defined(__APPLE__)
    int status;
    pid_t result = waitpid(worker_pid, &status, WNOHANG);
    if (result == 0) return true;
    if (WIFEXITED(status))
        UtilityFunctions::print("[PyBridgeFacade] Worker exited with code ", WEXITSTATUS(status));
    else if (WIFSIGNALED(status))
        UtilityFunctions::print("[PyBridgeFacade] Worker killed by signal ", WTERMSIG(status));
    worker_pid = -1;
    return false;
#elif defined(_WIN32)
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, (DWORD)worker_pid);
    if (!hProcess) { worker_pid = -1; return false; }
    DWORD exit_code;
    if (!GetExitCodeProcess(hProcess, &exit_code)) { CloseHandle(hProcess); worker_pid = -1; return false; }
    CloseHandle(hProcess);
    if (exit_code == STILL_ACTIVE) return true;
    worker_pid = -1;
    return false;
#else
    return false;
#endif
}

void PyBridgeFacade::queue_restart() {
    std::vector<String> modules_to_reimport = imported_modules;
    UtilityFunctions::print("[PyBridgeFacade] Queueing worker restart (", modules_to_reimport.size(), " modules cached)...");
    kill_worker();
    if (launch_worker()) {
        for (const String &mod : modules_to_reimport) {
            Dictionary resp = send_request("import", mod, "", Array());
            if (resp.has("status") && String(resp["status"]) != "ok") {
                String err = resp.has("message") ? String(resp["message"]) : "unknown";
                UtilityFunctions::printerr("[PyBridgeFacade] Re-import of '", mod, "' failed: ", err);
            }
            if (std::find(imported_modules.begin(), imported_modules.end(), mod) == imported_modules.end())
                imported_modules.push_back(mod);
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
// IPC communication — Phase 2B: binary lane
// --------------------------------------------------------------------------

Dictionary PyBridgeFacade::send_request(const String &p_kind, const String &p_module,
                                         const String &p_method, const Array &p_args) {
    PackedByteArray dummy;
    return send_request_binary(p_kind, p_module, p_method, p_args, dummy, dummy);
}

Dictionary PyBridgeFacade::send_request_binary(const String &p_kind, const String &p_module,
                                                const String &p_method, const Array &p_args,
                                                const PackedByteArray &p_blob,
                                                PackedByteArray &r_out_blob) {
    std::lock_guard<std::mutex> lock(request_mutex);

    // Phase 3B: auto-restart
    if (!check_worker_alive()) {
        if (auto_restart_) {
            UtilityFunctions::print("[PyBridgeFacade] Worker dead, attempting restart...");
            queue_restart();
            if (!check_worker_alive()) {
                Dictionary err = make_error("Worker not running after restart");
                last_error_details_ = err;
                return err;
            }
        } else {
            Dictionary err = make_error("Worker not running");
            last_error_details_ = err;
            return err;
        }
    }

    int req_id = next_request_id++;

    Dictionary request;
    request["kind"] = p_kind;
    request["request_id"] = req_id;
    if (!p_module.is_empty()) request["module"] = p_module;
    if (!p_method.is_empty()) request["method"] = p_method;
    if (p_args.size() > 0) request["args"] = p_args;

    bool has_blob = p_blob.size() > 0;
    if (has_blob) {
        request["kind"] = "call_binary";
        request["blob_size"] = p_blob.size();
    }

    String json = vg_json_stringify_typed(request);
    if (!write_to_worker(json)) {
        Dictionary err = make_error("Failed to write to worker");
        last_error_details_ = err;
        return err;
    }

    // Send trailing binary blob
    if (has_blob) {
        uint32_t blob_len = (uint32_t)p_blob.size();
        uint8_t len_hdr[4];
        len_hdr[0] = blob_len & 0xFF;
        len_hdr[1] = (blob_len >> 8) & 0xFF;
        len_hdr[2] = (blob_len >> 16) & 0xFF;
        len_hdr[3] = (blob_len >> 24) & 0xFF;
        if (!write_all(worker_stdin_fd, len_hdr, 4) ||
            !write_all(worker_stdin_fd, p_blob.ptr(), p_blob.size())) {
            Dictionary err = make_error("Failed to write binary blob");
            last_error_details_ = err;
            return err;
        }
    }

    String response = read_from_worker(worker_timeout_ms_);
    if (response.is_empty()) {
        Dictionary err = make_error("Worker timed out or disconnected");
        last_error_details_ = err;
        return err;
    }

    Variant parsed;
    String parse_err;
    if (!vg_json_parse_typed(response, parsed, parse_err) ||
        parsed.get_type() != Variant::DICTIONARY) {
        Dictionary err = make_error(parse_err.is_empty()
            ? String("Invalid JSON response from worker")
            : (String("Invalid JSON response from worker: ") + parse_err));
        last_error_details_ = err;
        return err;
    }
    Dictionary resp_dict = parsed;

    // Read optional trailing binary blob from response
    if (resp_dict.has("kind") && String(resp_dict["kind"]) == "result_binary") {
        read_raw_from_worker(r_out_blob, worker_timeout_ms_);
    }

    // Phase 3C: Store last error details
    if (resp_dict.has("status") && String(resp_dict["status"]) == "error")
        last_error_details_ = resp_dict;
    else
        last_error_details_ = Dictionary();

    return resp_dict;
}

bool PyBridgeFacade::write_to_worker(const String &p_json) {
    if (worker_stdin_fd < 0) return false;
    CharString utf8 = p_json.utf8();
    uint32_t len = (uint32_t)utf8.length();
    uint8_t hdr[4];
    hdr[0] = len & 0xFF; hdr[1] = (len >> 8) & 0xFF;
    hdr[2] = (len >> 16) & 0xFF; hdr[3] = (len >> 24) & 0xFF;
    return write_all(worker_stdin_fd, hdr, 4) &&
           write_all(worker_stdin_fd, (const uint8_t*)utf8.get_data(), len);
}

bool PyBridgeFacade::write_to_worker_raw(const uint8_t *data, size_t len) {
    if (worker_stdin_fd < 0) return false;
    uint8_t hdr[4];
    hdr[0] = (uint32_t)len & 0xFF; hdr[1] = ((uint32_t)len >> 8) & 0xFF;
    hdr[2] = ((uint32_t)len >> 16) & 0xFF; hdr[3] = ((uint32_t)len >> 24) & 0xFF;
    return write_all(worker_stdin_fd, hdr, 4) && write_all(worker_stdin_fd, data, len);
}

String PyBridgeFacade::read_from_worker(int p_timeout_ms) {
    if (worker_stdout_fd < 0) return "";
    if (p_timeout_ms < 0) p_timeout_ms = worker_timeout_ms_;

    uint8_t hdr[4];
    if (!read_exact(worker_stdout_fd, hdr, 4)) return "";

    uint32_t payload_len = (uint32_t)hdr[0] | ((uint32_t)hdr[1] << 8) |
                           ((uint32_t)hdr[2] << 16) | ((uint32_t)hdr[3] << 24);
    if (payload_len == 0) return "";
    if (payload_len > (uint32_t)max_payload_bytes_) {
        UtilityFunctions::printerr("[PyBridgeFacade] Response too large: ", payload_len);
        return "";
    }

    std::string buf(payload_len + 1, '\0');
    if (!read_exact(worker_stdout_fd, (uint8_t*)buf.data(), payload_len)) return "";
    buf[payload_len] = '\0';
    return String::utf8(buf.data(), payload_len);
}

bool PyBridgeFacade::read_raw_from_worker(PackedByteArray &r_out, int p_timeout_ms) {
    if (worker_stdout_fd < 0) return false;
    if (p_timeout_ms < 0) p_timeout_ms = worker_timeout_ms_;

    uint8_t hdr[4];
    if (!read_exact(worker_stdout_fd, hdr, 4)) return false;
    uint32_t blob_len = (uint32_t)hdr[0] | ((uint32_t)hdr[1] << 8) |
                        ((uint32_t)hdr[2] << 16) | ((uint32_t)hdr[3] << 24);
    if (blob_len == 0) return true;
    if (blob_len > (uint32_t)max_payload_bytes_) {
        UtilityFunctions::printerr("[PyBridgeFacade] Binary blob too large: ", blob_len);
        return false;
    }
    r_out.resize(blob_len);
    return read_exact(worker_stdout_fd, r_out.ptrw(), blob_len);
}

String PyBridgeFacade::find_worker_script() {
    String paths[] = { "addons/visual_gasic/python_worker.py",
                       "../addons/visual_gasic/python_worker.py",
                       "../../addons/visual_gasic/python_worker.py" };
    for (const String &p : paths)
        if (FileAccess::file_exists(p)) return p;
    String exe_dir = OS::get_singleton()->get_executable_path().get_base_dir();
    String cand = exe_dir.path_join("addons/visual_gasic/python_worker.py");
    if (FileAccess::file_exists(cand)) return cand;
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
        if (std::find(imported_modules.begin(), imported_modules.end(), p_module_name)
            == imported_modules.end()) imported_modules.push_back(p_module_name);
        return p_module_name;
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
    String module_name = p_handle;
    Dictionary response = send_request("call", module_name, p_method, p_args);
    if (response.has("status") && String(response["status"]) == "ok")
        return response["value"];

    String err = response.has("message") ? String(response["message"]) : "unknown error";
    UtilityFunctions::printerr("[PyBridgeFacade] Call failed: ", module_name, ".", p_method, ": ", err);
    return Variant();
}
Dictionary PyBridgeFacade::py_last_error() {
    return last_error_details_;
}

Dictionary PyBridgeFacade::py_env_info() {
    Dictionary info;
    if (!initialized) {
        info["status"] = "not_initialized";
        return info;
    }
    info["python_version"] = status_message;
    info["backend"] = embedded_mode ? "tier_b" : "tier_a";
    info["worker_pid"] = worker_pid;
    info["imported_modules"] = Array();
    Array mods;
    for (const String &m : imported_modules) mods.push_back(m);
    info["imported_modules"] = mods;

    Dictionary ping = send_request("ping", "", "", Array());
    if (ping.has("status") && String(ping["status"]) == "ok") {
        Dictionary val = ping["value"];
        if (val.has("capabilities")) info["capabilities"] = val["capabilities"];
        if (val.has("python_version")) info["python_version"] = val["python_version"];
        if (val.has("python_executable")) info["python_executable"] = val["python_executable"];
    }

    Dictionary settings;
    settings["worker_timeout_ms"] = worker_timeout_ms_;
    settings["max_payload_bytes"] = max_payload_bytes_;
    settings["auto_restart"] = auto_restart_;
    info["settings"] = settings;
    return info;
}

Array PyBridgeFacade::py_call_many(const Array &p_calls) {
    Array results;
    if (!initialized) {
        UtilityFunctions::printerr("[PyBridgeFacade] Python bridge not initialized.");
        return results;
    }

    std::lock_guard<std::mutex> lock(request_mutex);
    if (!check_worker_alive()) {
        UtilityFunctions::printerr("[PyBridgeFacade] Worker not running for call_many");
        return results;
    }

    Array call_list;
    for (int i = 0; i < p_calls.size(); i++) {
        Dictionary call = p_calls[i];
        Dictionary entry;
        entry["module"] = call.has("module") ? call["module"] : "";
        entry["method"] = call.has("method") ? call["method"] : "";
        if (call.has("args")) { entry["args"] = call["args"]; } else { entry["args"] = Array(); }
        entry["kind"] = call.has("kind") ? call["kind"] : "call";
        call_list.push_back(entry);
    }

    Dictionary request;
    request["kind"] = "call_many";
    request["calls"] = call_list;
    request["request_id"] = next_request_id++;

    String json = vg_json_stringify_typed(request);
    if (!write_to_worker(json)) {
        UtilityFunctions::printerr("[PyBridgeFacade] Failed to write call_many");
        return results;
    }

    String response = read_from_worker(worker_timeout_ms_);
    if (response.is_empty()) {
        UtilityFunctions::printerr("[PyBridgeFacade] Timeout on call_many");
        return results;
    }

    Variant parsed;
    String parse_err;
    if (!vg_json_parse_typed(response, parsed, parse_err) ||
        parsed.get_type() != Variant::DICTIONARY) {
        UtilityFunctions::printerr("[PyBridgeFacade] call_many: " +
                                   (parse_err.is_empty() ? "Invalid JSON response from worker" :
                                    "Invalid JSON response from worker: " + parse_err));
        return results;
    }
    Dictionary resp_dict = parsed;
    if (resp_dict.has("status") && String(resp_dict["status"]) == "ok") {
        Array vals = resp_dict["value"];
        for (int i = 0; i < vals.size(); i++) results.push_back(vals[i]);
    } else {
        String err = resp_dict.has("message") ? String(resp_dict["message"]) : "unknown";
        UtilityFunctions::printerr("[PyBridgeFacade] call_many failed: ", err);
    }
    return results;
}

void PyBridgeFacade::shutdown() {
    if (!initialized && worker_pid <= 0) return;
    UtilityFunctions::print("[PyBridgeFacade] Shutting down...");
    kill_worker();
    imported_modules.clear();
    initialized = false;
    status_message = "Python bridge shut down";
}


Variant PyBridgeFacade::py_call_async(const String &p_module, const String &p_method,
                                       const Array &p_args) {
    if (!initialized) {
        UtilityFunctions::printerr("[PyBridgeFacade] Python bridge not initialized.");
        return Variant();
    }

    // Phase 2A: Real async via PyAsyncTask + background thread
    Ref<PyAsyncTask> task;
    task.instantiate();

    Ref<PyBridgeFacade> self_ref(this);

    // Initialize state
    {
        std::lock_guard<std::mutex> lock(task->result_mutex_);
        task->state_.store(PyAsyncTask::RUNNING);
    }

    // Spawn a thread to execute the remote call
    std::thread t([task, self_ref, p_module, p_method, p_args]() {
        Dictionary resp = self_ref->send_request("call", p_module, p_method, p_args);
        std::lock_guard<std::mutex> lock(task->result_mutex_);
        if (resp.has("status") && String(resp["status"]) == "ok") {
            task->result_ = resp["value"];
            task->state_.store(PyAsyncTask::COMPLETED);
        } else {
            task->error_message_ = resp.has("message") ? String(resp["message"]) : "unknown error";
            task->state_.store(PyAsyncTask::FAILED);
        }
    });
    t.detach();

    return task;
}

Variant PyBridgeFacade::py_process_buffer(const Variant &p_handle, const String &p_method,
                                           const PackedByteArray &p_buffer) {
    if (!initialized) {
        UtilityFunctions::printerr("[PyBridgeFacade] Python bridge not initialized.");
        return Variant();
    }

    // Phase 2B: Binary data lane
    UtilityFunctions::print("[PyBridgeFacade] Buffer processing — binary lane");

    String module_name = p_handle;
    Array args;
    Dictionary meta;
    meta["dtype"] = "uint8";
    meta["shape"] = Array::make((int64_t)p_buffer.size());
    meta["size"] = p_buffer.size();
    args.push_back(meta);

    PackedByteArray response_blob;
    Dictionary response = send_request_binary("call_binary", module_name, p_method,
                                               args, p_buffer, response_blob);
    if (response.has("status") && String(response["status"]) == "ok") {
        if (response_blob.size() > 0) return response_blob;
        return response["value"];
    }

    String err = response.has("message") ? String(response["message"]) : "unknown error";
    UtilityFunctions::printerr("[PyBridgeFacade] Buffer call failed: ", module_name, ".", p_method, ": ", err);
    return Variant();
}
