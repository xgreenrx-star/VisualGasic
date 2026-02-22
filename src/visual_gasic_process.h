#ifndef VISUAL_GASIC_PROCESS_H
#define VISUAL_GASIC_PROCESS_H

// VGProcess — VB6-style Shell() and process management
// Usage in VisualGasic:
//   Dim pid As Long
//   pid = Shell("notepad.exe", vbNormalFocus)
//
//   Dim proc As New Process
//   proc.Start "ls", "-la /tmp"
//   Do While proc.IsRunning
//       DoEvents
//   Loop
//   Print proc.StdOut
//   Print "Exit code: "; proc.ExitCode

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

class VGProcess : public RefCounted {
    GDCLASS(VGProcess, RefCounted);

    // Process state
    int pid;
    int exit_code;
    bool running;
    String command;
    String arguments;
    String stdout_text;
    String stderr_text;
    String working_directory;

    // Pipe file descriptors (Linux)
    int stdin_fd;
    int stdout_fd;
    int stderr_fd;
    int child_pid;

protected:
    static void _bind_methods();

public:
    VGProcess();
    ~VGProcess();

    // Start a process
    int start(const String &p_command, const String &p_arguments = "");
    int start_with_args(const String &p_command, const Array &p_args);

    // Shell() — VB6-compatible quick launch, returns PID
    static int shell_execute(const String &p_command, int p_window_style = 1);

    // Process control
    void terminate();
    int wait_for_exit(int p_timeout_ms = -1);
    bool get_is_running();

    // I/O
    void write_stdin(const String &p_text);
    String read_stdout();
    String read_stderr();
    String read_all_stdout();
    String read_all_stderr();

    // Properties
    int get_pid() const { return child_pid; }
    int get_exit_code() const { return exit_code; }
    String get_command() const { return command; }
    void set_working_directory(const String &p_dir) { working_directory = p_dir; }
    String get_working_directory() const { return working_directory; }

    // Convenience: run and capture output in one call
    static String run_and_capture(const String &p_command, const String &p_arguments = "");
    static Dictionary run_with_status(const String &p_command, const String &p_arguments = "");
};

#endif // VISUAL_GASIC_PROCESS_H
