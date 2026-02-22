#ifndef VISUAL_GASIC_SIGNAL_HANDLER_H
#define VISUAL_GASIC_SIGNAL_HANDLER_H

// VGSignalHandler — OS-level signal handling (SIGINT, SIGTERM, etc.)
// Lets VG scripts register callbacks for process termination / Ctrl+C / etc.
//
// Usage in VisualGasic:
//   Dim sh As New VGSignalHandler
//   sh.OnInterrupt Callable(Me, "HandleCtrlC")
//   sh.OnTerminate Callable(Me, "GracefulShutdown")
//   sh.OnExit Callable(Me, "Cleanup")
//
//   ' Raise a signal manually
//   sh.Raise "SIGTERM"
//
//   ' Remove handler
//   sh.RemoveHandler "SIGINT"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

class VGSignalHandler : public RefCounted {
    GDCLASS(VGSignalHandler, RefCounted);

    // Map of signal name → callable
    Dictionary handlers;
    String last_signal;
    bool installed;

    // Internal: register OS-level hooks
    void install_os_hooks();
    void uninstall_os_hooks();

protected:
    static void _bind_methods();

public:
    VGSignalHandler();
    ~VGSignalHandler();

    // Register handlers for common signals
    void on_interrupt(const Callable &p_handler);   // SIGINT  / Ctrl+C
    void on_terminate(const Callable &p_handler);    // SIGTERM
    void on_hangup(const Callable &p_handler);       // SIGHUP  (Unix) — ignored on Windows
    void on_user1(const Callable &p_handler);        // SIGUSR1 (Unix)
    void on_user2(const Callable &p_handler);        // SIGUSR2 (Unix)
    void on_exit(const Callable &p_handler);         // atexit — fires on normal process exit

    // Generic
    void set_handler(const String &p_signal_name, const Callable &p_handler);
    void remove_handler(const String &p_signal_name);
    bool has_handler(const String &p_signal_name) const;
    Array get_registered_signals() const;

    // Raise a signal from VG code
    void raise_signal_by_name(const String &p_signal_name);

    // Status
    String get_last_signal() const { return last_signal; }
    bool get_is_installed() const { return installed; }

    // Called from the static C handler — dispatches to registered Callables
    void dispatch(const String &p_signal_name);

    // Global instance management
    static VGSignalHandler *active_instance;
};

#endif // VISUAL_GASIC_SIGNAL_HANDLER_H
