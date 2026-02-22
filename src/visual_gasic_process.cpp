// VGProcess — VB6-style Shell() and process management
// Full POSIX implementation using fork/exec/pipe

#include "visual_gasic_process.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/os.hpp>

#if defined(__linux__) || defined(__APPLE__)
#include <unistd.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <signal.h>
#include <fcntl.h>
#include <errno.h>
#include <poll.h>
#elif defined(_WIN32)
#include <windows.h>
#include <shellapi.h>
#include <stdio.h>
#endif

using namespace godot;

void VGProcess::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start", "command", "arguments"), &VGProcess::start, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("start_with_args", "command", "args"), &VGProcess::start_with_args);
    ClassDB::bind_static_method("VGProcess", D_METHOD("shell_execute", "command", "window_style"), &VGProcess::shell_execute, DEFVAL(1));
    ClassDB::bind_method(D_METHOD("terminate"), &VGProcess::terminate);
    ClassDB::bind_method(D_METHOD("wait_for_exit", "timeout_ms"), &VGProcess::wait_for_exit, DEFVAL(-1));
    ClassDB::bind_method(D_METHOD("get_is_running"), &VGProcess::get_is_running);
    ClassDB::bind_method(D_METHOD("write_stdin", "text"), &VGProcess::write_stdin);
    ClassDB::bind_method(D_METHOD("read_stdout"), &VGProcess::read_stdout);
    ClassDB::bind_method(D_METHOD("read_stderr"), &VGProcess::read_stderr);
    ClassDB::bind_method(D_METHOD("read_all_stdout"), &VGProcess::read_all_stdout);
    ClassDB::bind_method(D_METHOD("read_all_stderr"), &VGProcess::read_all_stderr);
    ClassDB::bind_method(D_METHOD("get_pid"), &VGProcess::get_pid);
    ClassDB::bind_method(D_METHOD("get_exit_code"), &VGProcess::get_exit_code);
    ClassDB::bind_method(D_METHOD("get_command"), &VGProcess::get_command);
    ClassDB::bind_method(D_METHOD("set_working_directory", "dir"), &VGProcess::set_working_directory);
    ClassDB::bind_method(D_METHOD("get_working_directory"), &VGProcess::get_working_directory);
    ClassDB::bind_static_method("VGProcess", D_METHOD("run_and_capture", "command", "arguments"), &VGProcess::run_and_capture, DEFVAL(""));
    ClassDB::bind_static_method("VGProcess", D_METHOD("run_with_status", "command", "arguments"), &VGProcess::run_with_status, DEFVAL(""));

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("Start", "command", "arguments"), &VGProcess::start, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("Terminate"), &VGProcess::terminate);
    ClassDB::bind_method(D_METHOD("WaitForExit", "timeout_ms"), &VGProcess::wait_for_exit, DEFVAL(-1));
    ClassDB::bind_method(D_METHOD("WriteStdin", "text"), &VGProcess::write_stdin);
    ClassDB::bind_method(D_METHOD("ReadStdout"), &VGProcess::read_stdout);
    ClassDB::bind_method(D_METHOD("ReadStderr"), &VGProcess::read_stderr);
    ClassDB::bind_method(D_METHOD("ReadAllStdout"), &VGProcess::read_all_stdout);
    ClassDB::bind_method(D_METHOD("ReadAllStderr"), &VGProcess::read_all_stderr);
    ClassDB::bind_static_method("VGProcess", D_METHOD("RunAndCapture", "command", "arguments"), &VGProcess::run_and_capture, DEFVAL(""));
    ClassDB::bind_static_method("VGProcess", D_METHOD("RunWithStatus", "command", "arguments"), &VGProcess::run_with_status, DEFVAL(""));

    ADD_PROPERTY(PropertyInfo(Variant::INT, "PID"), "", "get_pid");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "ExitCode"), "", "get_exit_code");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsRunning"), "", "get_is_running");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Command"), "", "get_command");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "WorkingDirectory"), "set_working_directory", "get_working_directory");
}

VGProcess::VGProcess() {
    pid = -1;
    exit_code = -1;
    running = false;
    stdin_fd = -1;
    stdout_fd = -1;
    stderr_fd = -1;
    child_pid = -1;
#ifdef _WIN32
    win_stdin_write = nullptr;
    win_stdout_read = nullptr;
    win_stderr_read = nullptr;
    win_process = nullptr;
    win_thread = nullptr;
#endif
}

VGProcess::~VGProcess() {
#if defined(__linux__) || defined(__APPLE__)
    if (stdin_fd >= 0) ::close(stdin_fd);
    if (stdout_fd >= 0) ::close(stdout_fd);
    if (stderr_fd >= 0) ::close(stderr_fd);
#elif defined(_WIN32)
    if (win_stdin_write) { CloseHandle(win_stdin_write); win_stdin_write = nullptr; }
    if (win_stdout_read) { CloseHandle(win_stdout_read); win_stdout_read = nullptr; }
    if (win_stderr_read) { CloseHandle(win_stderr_read); win_stderr_read = nullptr; }
    if (win_process) { CloseHandle(win_process); win_process = nullptr; }
    if (win_thread) { CloseHandle(win_thread); win_thread = nullptr; }
#endif
}

int VGProcess::start(const String &p_command, const String &p_arguments) {
#if defined(__linux__) || defined(__APPLE__)
    command = p_command;
    arguments = p_arguments;

    // Build the command string before fork
    String full_cmd = p_command;
    if (!p_arguments.is_empty()) {
        full_cmd += String(" ") + p_arguments;
    }

    // Create pipes for stdin, stdout, stderr
    int stdin_pipe[2], stdout_pipe[2], stderr_pipe[2];
    if (pipe(stdin_pipe) < 0 || pipe(stdout_pipe) < 0 || pipe(stderr_pipe) < 0) {
        UtilityFunctions::printerr("[VGProcess] Failed to create pipes: ", strerror(errno));
        return -1;
    }

    pid_t cpid = fork();
    if (cpid < 0) {
        UtilityFunctions::printerr("[VGProcess] Fork failed: ", strerror(errno));
        return -1;
    }

    if (cpid == 0) {
        // Child process
        ::close(stdin_pipe[1]);  // Close write end of stdin
        ::close(stdout_pipe[0]); // Close read end of stdout
        ::close(stderr_pipe[0]); // Close read end of stderr

        dup2(stdin_pipe[0], STDIN_FILENO);
        dup2(stdout_pipe[1], STDOUT_FILENO);
        dup2(stderr_pipe[1], STDERR_FILENO);

        ::close(stdin_pipe[0]);
        ::close(stdout_pipe[1]);
        ::close(stderr_pipe[1]);

        // Change working directory if set
        if (!working_directory.is_empty()) {
            chdir(working_directory.utf8().get_data());
        }

        // Execute via shell for proper argument parsing
        execl("/bin/sh", "sh", "-c", full_cmd.utf8().get_data(), (char*)nullptr);
        _exit(127); // exec failed
    }

    // Parent process
    ::close(stdin_pipe[0]);  // Close read end of stdin
    ::close(stdout_pipe[1]); // Close write end of stdout
    ::close(stderr_pipe[1]); // Close write end of stderr

    stdin_fd = stdin_pipe[1];
    stdout_fd = stdout_pipe[0];
    stderr_fd = stderr_pipe[0];
    child_pid = cpid;
    running = true;

    // Set stdout/stderr to non-blocking
    int flags = fcntl(stdout_fd, F_GETFL, 0);
    fcntl(stdout_fd, F_SETFL, flags | O_NONBLOCK);
    flags = fcntl(stderr_fd, F_GETFL, 0);
    fcntl(stderr_fd, F_SETFL, flags | O_NONBLOCK);

    UtilityFunctions::print("[VGProcess] Started PID ", child_pid, ": ", full_cmd);
    return child_pid;
#elif defined(_WIN32)
    command = p_command;
    arguments = p_arguments;

    String full_cmd = p_command;
    if (!p_arguments.is_empty()) {
        full_cmd += String(" ") + p_arguments;
    }

    // Create pipes for stdin, stdout, stderr
    SECURITY_ATTRIBUTES sa;
    sa.nLength = sizeof(SECURITY_ATTRIBUTES);
    sa.bInheritHandle = TRUE;
    sa.lpSecurityDescriptor = nullptr;

    HANDLE hStdinRead = nullptr, hStdinWrite = nullptr;
    HANDLE hStdoutRead = nullptr, hStdoutWrite = nullptr;
    HANDLE hStderrRead = nullptr, hStderrWrite = nullptr;

    if (!CreatePipe(&hStdinRead, &hStdinWrite, &sa, 0) ||
        !CreatePipe(&hStdoutRead, &hStdoutWrite, &sa, 0) ||
        !CreatePipe(&hStderrRead, &hStderrWrite, &sa, 0)) {
        UtilityFunctions::printerr("[VGProcess] Failed to create pipes");
        return -1;
    }

    // Ensure parent ends of pipes are not inherited
    SetHandleInformation(hStdinWrite, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(hStdoutRead, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(hStderrRead, HANDLE_FLAG_INHERIT, 0);

    STARTUPINFOW si;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput = hStdinRead;
    si.hStdOutput = hStdoutWrite;
    si.hStdError = hStderrWrite;

    PROCESS_INFORMATION pi;
    ZeroMemory(&pi, sizeof(pi));

    // Execute via cmd.exe for proper argument parsing
    String cmd_line = String("cmd.exe /c ") + full_cmd;
    Char16String wide_cmd = cmd_line.utf16();
    Char16String wide_dir;
    LPCWSTR lpDir = nullptr;
    if (!working_directory.is_empty()) {
        wide_dir = working_directory.utf16();
        lpDir = (LPCWSTR)wide_dir.get_data();
    }

    BOOL success = CreateProcessW(
        nullptr,
        (LPWSTR)wide_cmd.ptrw(),
        nullptr, nullptr,
        TRUE,
        CREATE_NO_WINDOW,
        nullptr,
        lpDir,
        &si, &pi
    );

    // Close child ends of pipes in parent
    CloseHandle(hStdinRead);
    CloseHandle(hStdoutWrite);
    CloseHandle(hStderrWrite);

    if (!success) {
        UtilityFunctions::printerr("[VGProcess] CreateProcess failed, error: ", (int64_t)GetLastError());
        CloseHandle(hStdinWrite);
        CloseHandle(hStdoutRead);
        CloseHandle(hStderrRead);
        return -1;
    }

    win_stdin_write = hStdinWrite;
    win_stdout_read = hStdoutRead;
    win_stderr_read = hStderrRead;
    win_process = pi.hProcess;
    win_thread = pi.hThread;
    child_pid = (int)pi.dwProcessId;
    running = true;

    UtilityFunctions::print("[VGProcess] Started PID ", child_pid, ": ", full_cmd);
    return child_pid;
#else
    UtilityFunctions::printerr("[VGProcess] Not implemented on this platform");
    return -1;
#endif
}

int VGProcess::start_with_args(const String &p_command, const Array &p_args) {
    String args_str;
    for (int i = 0; i < p_args.size(); i++) {
        if (i > 0) args_str += " ";
        String arg = p_args[i];
        // Quote arguments containing spaces
        if (arg.contains(" ")) {
            args_str += String("\"") + arg + String("\"");
        } else {
            args_str += arg;
        }
    }
    return start(p_command, args_str);
}

int VGProcess::shell_execute(const String &p_command, int p_window_style) {
#if defined(__linux__) || defined(__APPLE__)
    // Fire-and-forget process launch (like VB6 Shell())
    String cmd = p_command + String(" &");
    pid_t cpid = fork();
    if (cpid < 0) return -1;
    if (cpid == 0) {
        // Detach from parent
        setsid();
        execl("/bin/sh", "sh", "-c", p_command.utf8().get_data(), (char*)nullptr);
        _exit(127);
    }
    UtilityFunctions::print("[VG] Shell: PID ", (int64_t)cpid, " = ", p_command);
    return (int)cpid;
#elif defined(_WIN32)
    CharString utf8 = p_command.utf8();
    HINSTANCE result = ShellExecuteA(nullptr, "open", utf8.get_data(), nullptr, nullptr, p_window_style);
    if ((intptr_t)result > 32) {
        UtilityFunctions::print("[VG] Shell: ", p_command);
        return 0; // ShellExecuteA does not return a PID
    }
    return -1;
#else
    return -1;
#endif
}

void VGProcess::terminate() {
#if defined(__linux__) || defined(__APPLE__)
    if (child_pid > 0 && running) {
        kill(child_pid, SIGTERM);
        // Give it a moment, then force kill
        usleep(100000); // 100ms
        if (get_is_running()) {
            kill(child_pid, SIGKILL);
        }
        running = false;
        UtilityFunctions::print("[VGProcess] Terminated PID ", child_pid);
    }
#elif defined(_WIN32)
    if (win_process && running) {
        TerminateProcess(win_process, 1);
        running = false;
        UtilityFunctions::print("[VGProcess] Terminated PID ", child_pid);
    }
#endif
}

int VGProcess::wait_for_exit(int p_timeout_ms) {
#if defined(__linux__) || defined(__APPLE__)
    if (child_pid <= 0) return exit_code;

    int status;
    if (p_timeout_ms < 0) {
        // Wait indefinitely
        waitpid(child_pid, &status, 0);
    } else {
        // Poll with timeout
        int elapsed = 0;
        while (elapsed < p_timeout_ms) {
            pid_t result = waitpid(child_pid, &status, WNOHANG);
            if (result > 0) break;
            if (result < 0) break;
            usleep(10000); // 10ms
            elapsed += 10;
        }
        if (elapsed >= p_timeout_ms) {
            return -1; // Timeout
        }
    }

    if (WIFEXITED(status)) {
        exit_code = WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        exit_code = -WTERMSIG(status);
    }
    running = false;
    return exit_code;
#elif defined(_WIN32)
    if (!win_process) return exit_code;
    DWORD timeout = (p_timeout_ms < 0) ? INFINITE : (DWORD)p_timeout_ms;
    DWORD wait_result = WaitForSingleObject(win_process, timeout);
    if (wait_result == WAIT_OBJECT_0) {
        DWORD code = 0;
        GetExitCodeProcess(win_process, &code);
        exit_code = (int)code;
        running = false;
        return exit_code;
    }
    return -1; // Timeout or error
#else
    return -1;
#endif
}

bool VGProcess::get_is_running() {
#if defined(__linux__) || defined(__APPLE__)
    if (!running || child_pid <= 0) return false;
    int status;
    pid_t result = waitpid(child_pid, &status, WNOHANG);
    if (result > 0) {
        // Process has exited
        if (WIFEXITED(status)) {
            exit_code = WEXITSTATUS(status);
        }
        running = false;
        return false;
    }
    return true;
#elif defined(_WIN32)
    if (!running || !win_process) return false;
    DWORD wait_result = WaitForSingleObject(win_process, 0);
    if (wait_result == WAIT_OBJECT_0) {
        DWORD code = 0;
        GetExitCodeProcess(win_process, &code);
        exit_code = (int)code;
        running = false;
        return false;
    }
    return true;
#else
    return false;
#endif
}

void VGProcess::write_stdin(const String &p_text) {
#if defined(__linux__) || defined(__APPLE__)
    if (stdin_fd >= 0) {
        CharString utf8 = p_text.utf8();
        ::write(stdin_fd, utf8.get_data(), utf8.length());
    }
#elif defined(_WIN32)
    if (win_stdin_write) {
        CharString utf8 = p_text.utf8();
        DWORD written = 0;
        WriteFile(win_stdin_write, utf8.get_data(), utf8.length(), &written, nullptr);
    }
#endif
}

String VGProcess::read_stdout() {
#if defined(__linux__) || defined(__APPLE__)
    if (stdout_fd < 0) return "";
    char buf[4096];
    ssize_t n = ::read(stdout_fd, buf, sizeof(buf) - 1);
    if (n > 0) {
        buf[n] = '\0';
        return String::utf8(buf, n);
    }
    return "";
#elif defined(_WIN32)
    if (!win_stdout_read) return "";
    DWORD available = 0;
    if (!PeekNamedPipe(win_stdout_read, nullptr, 0, nullptr, &available, nullptr) || available == 0) {
        return "";
    }
    char buf[4096];
    DWORD to_read = (available < sizeof(buf) - 1) ? available : (DWORD)(sizeof(buf) - 1);
    DWORD n = 0;
    if (ReadFile(win_stdout_read, buf, to_read, &n, nullptr) && n > 0) {
        buf[n] = '\0';
        return String::utf8(buf, n);
    }
    return "";
#else
    return "";
#endif
}

String VGProcess::read_stderr() {
#if defined(__linux__) || defined(__APPLE__)
    if (stderr_fd < 0) return "";
    char buf[4096];
    ssize_t n = ::read(stderr_fd, buf, sizeof(buf) - 1);
    if (n > 0) {
        buf[n] = '\0';
        return String::utf8(buf, n);
    }
    return "";
#elif defined(_WIN32)
    if (!win_stderr_read) return "";
    DWORD available = 0;
    if (!PeekNamedPipe(win_stderr_read, nullptr, 0, nullptr, &available, nullptr) || available == 0) {
        return "";
    }
    char buf[4096];
    DWORD to_read = (available < sizeof(buf) - 1) ? available : (DWORD)(sizeof(buf) - 1);
    DWORD n = 0;
    if (ReadFile(win_stderr_read, buf, to_read, &n, nullptr) && n > 0) {
        buf[n] = '\0';
        return String::utf8(buf, n);
    }
    return "";
#else
    return "";
#endif
}

String VGProcess::read_all_stdout() {
#if defined(__linux__) || defined(__APPLE__)
    if (stdout_fd < 0) return "";

    // Set to blocking temporarily
    int flags = fcntl(stdout_fd, F_GETFL, 0);
    fcntl(stdout_fd, F_SETFL, flags & ~O_NONBLOCK);

    String result;
    char buf[4096];
    ssize_t n;
    while ((n = ::read(stdout_fd, buf, sizeof(buf) - 1)) > 0) {
        buf[n] = '\0';
        result += String::utf8(buf, n);
    }

    // Restore non-blocking
    fcntl(stdout_fd, F_SETFL, flags);
    return result;
#elif defined(_WIN32)
    if (!win_stdout_read) return "";
    String result;
    char buf[4096];
    DWORD n = 0;
    while (ReadFile(win_stdout_read, buf, sizeof(buf) - 1, &n, nullptr) && n > 0) {
        buf[n] = '\0';
        result += String::utf8(buf, n);
        n = 0;
    }
    return result;
#else
    return "";
#endif
}

String VGProcess::read_all_stderr() {
#if defined(__linux__) || defined(__APPLE__)
    if (stderr_fd < 0) return "";
    int flags = fcntl(stderr_fd, F_GETFL, 0);
    fcntl(stderr_fd, F_SETFL, flags & ~O_NONBLOCK);
    String result;
    char buf[4096];
    ssize_t n;
    while ((n = ::read(stderr_fd, buf, sizeof(buf) - 1)) > 0) {
        buf[n] = '\0';
        result += String::utf8(buf, n);
    }
    fcntl(stderr_fd, F_SETFL, flags);
    return result;
#elif defined(_WIN32)
    if (!win_stderr_read) return "";
    String result;
    char buf[4096];
    DWORD n = 0;
    while (ReadFile(win_stderr_read, buf, sizeof(buf) - 1, &n, nullptr) && n > 0) {
        buf[n] = '\0';
        result += String::utf8(buf, n);
        n = 0;
    }
    return result;
#else
    return "";
#endif
}

String VGProcess::run_and_capture(const String &p_command, const String &p_arguments) {
#if defined(__linux__) || defined(__APPLE__)
    String full_cmd = p_command;
    if (!p_arguments.is_empty()) {
        full_cmd += String(" ") + p_arguments;
    }
    FILE *fp = popen(full_cmd.utf8().get_data(), "r");
    if (!fp) return "";
    String result;
    char buf[4096];
    while (fgets(buf, sizeof(buf), fp)) {
        result += String::utf8(buf);
    }
    pclose(fp);
    return result;
#elif defined(_WIN32)
    String full_cmd = p_command;
    if (!p_arguments.is_empty()) {
        full_cmd += String(" ") + p_arguments;
    }
    FILE *fp = _popen(full_cmd.utf8().get_data(), "r");
    if (!fp) return "";
    String result;
    char buf[4096];
    while (fgets(buf, sizeof(buf), fp)) {
        result += String::utf8(buf);
    }
    _pclose(fp);
    return result;
#else
    return "";
#endif
}

Dictionary VGProcess::run_with_status(const String &p_command, const String &p_arguments) {
    Dictionary result;
#if defined(__linux__) || defined(__APPLE__)
    String full_cmd = p_command;
    if (!p_arguments.is_empty()) {
        full_cmd += String(" ") + p_arguments;
    }
    full_cmd += String(" 2>&1"); // Capture stderr too
    FILE *fp = popen(full_cmd.utf8().get_data(), "r");
    if (!fp) {
        result["output"] = "";
        result["exit_code"] = -1;
        return result;
    }
    String output;
    char buf[4096];
    while (fgets(buf, sizeof(buf), fp)) {
        output += String::utf8(buf);
    }
    int status = pclose(fp);
    result["output"] = output;
    result["exit_code"] = WEXITSTATUS(status);
#elif defined(_WIN32)
    String full_cmd = p_command;
    if (!p_arguments.is_empty()) {
        full_cmd += String(" ") + p_arguments;
    }
    full_cmd += String(" 2>&1");
    FILE *fp = _popen(full_cmd.utf8().get_data(), "r");
    if (!fp) {
        result["output"] = "";
        result["exit_code"] = -1;
        return result;
    }
    String output;
    char buf[4096];
    while (fgets(buf, sizeof(buf), fp)) {
        output += String::utf8(buf);
    }
    int status = _pclose(fp);
    result["output"] = output;
    result["exit_code"] = status;
#else
    result["output"] = "";
    result["exit_code"] = -1;
#endif
    return result;
}
