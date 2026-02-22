// ============================================================================
// VGSignalHandler — OS signal handling (SIGINT, SIGTERM, SIGHUP, atexit)
// ============================================================================
#include "visual_gasic_signal_handler.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include <csignal>
#include <cstdlib>

#ifdef _WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
#else
    #include <unistd.h>
#endif

using namespace godot;

// ─── Static global instance pointer (for C callback) ──────────────────────

VGSignalHandler *VGSignalHandler::active_instance = nullptr;

// ─── C-level signal dispatcher ─────────────────────────────────────────────

static void vg_posix_signal_handler(int signum) {
    if (!VGSignalHandler::active_instance) return;
    switch (signum) {
        case SIGINT:  VGSignalHandler::active_instance->dispatch("SIGINT");  break;
        case SIGTERM: VGSignalHandler::active_instance->dispatch("SIGTERM"); break;
#ifndef _WIN32
        case SIGHUP:  VGSignalHandler::active_instance->dispatch("SIGHUP");  break;
        case SIGUSR1: VGSignalHandler::active_instance->dispatch("SIGUSR1"); break;
        case SIGUSR2: VGSignalHandler::active_instance->dispatch("SIGUSR2"); break;
#endif
        default: break;
    }
}

static void vg_atexit_handler() {
    if (VGSignalHandler::active_instance) {
        VGSignalHandler::active_instance->dispatch("EXIT");
    }
}

#ifdef _WIN32
static BOOL WINAPI vg_win_ctrl_handler(DWORD ctrl_type) {
    if (!VGSignalHandler::active_instance) return FALSE;
    switch (ctrl_type) {
        case CTRL_C_EVENT:
            VGSignalHandler::active_instance->dispatch("SIGINT");
            return TRUE;
        case CTRL_BREAK_EVENT:
            VGSignalHandler::active_instance->dispatch("SIGBREAK");
            return TRUE;
        case CTRL_CLOSE_EVENT:
        case CTRL_LOGOFF_EVENT:
        case CTRL_SHUTDOWN_EVENT:
            VGSignalHandler::active_instance->dispatch("SIGTERM");
            return TRUE;
        default:
            return FALSE;
    }
}
#endif

// ─── Constructor / Destructor ──────────────────────────────────────────────

VGSignalHandler::VGSignalHandler() : installed(false) {
    install_os_hooks();
}

VGSignalHandler::~VGSignalHandler() {
    uninstall_os_hooks();
}

void VGSignalHandler::install_os_hooks() {
    if (installed) return;
    active_instance = this;

    // POSIX signals
    std::signal(SIGINT,  vg_posix_signal_handler);
    std::signal(SIGTERM, vg_posix_signal_handler);
#ifndef _WIN32
    std::signal(SIGHUP,  vg_posix_signal_handler);
    std::signal(SIGUSR1, vg_posix_signal_handler);
    std::signal(SIGUSR2, vg_posix_signal_handler);
#endif

    // atexit
    std::atexit(vg_atexit_handler);

#ifdef _WIN32
    SetConsoleCtrlHandler(vg_win_ctrl_handler, TRUE);
#endif

    installed = true;
}

void VGSignalHandler::uninstall_os_hooks() {
    if (!installed) return;

    std::signal(SIGINT,  SIG_DFL);
    std::signal(SIGTERM, SIG_DFL);
#ifndef _WIN32
    std::signal(SIGHUP,  SIG_DFL);
    std::signal(SIGUSR1, SIG_DFL);
    std::signal(SIGUSR2, SIG_DFL);
#endif

#ifdef _WIN32
    SetConsoleCtrlHandler(vg_win_ctrl_handler, FALSE);
#endif

    if (active_instance == this) active_instance = nullptr;
    installed = false;
}

// ─── Handler Registration ──────────────────────────────────────────────────

void VGSignalHandler::on_interrupt(const Callable &p_handler) {
    handlers["SIGINT"] = p_handler;
}

void VGSignalHandler::on_terminate(const Callable &p_handler) {
    handlers["SIGTERM"] = p_handler;
}

void VGSignalHandler::on_hangup(const Callable &p_handler) {
    handlers["SIGHUP"] = p_handler;
}

void VGSignalHandler::on_user1(const Callable &p_handler) {
    handlers["SIGUSR1"] = p_handler;
}

void VGSignalHandler::on_user2(const Callable &p_handler) {
    handlers["SIGUSR2"] = p_handler;
}

void VGSignalHandler::on_exit(const Callable &p_handler) {
    handlers["EXIT"] = p_handler;
}

void VGSignalHandler::set_handler(const String &p_signal_name, const Callable &p_handler) {
    handlers[p_signal_name.to_upper()] = p_handler;
}

void VGSignalHandler::remove_handler(const String &p_signal_name) {
    handlers.erase(p_signal_name.to_upper());
}

bool VGSignalHandler::has_handler(const String &p_signal_name) const {
    return handlers.has(p_signal_name.to_upper());
}

Array VGSignalHandler::get_registered_signals() const {
    return handlers.keys();
}

// ─── Dispatch — called from C handler ──────────────────────────────────────

void VGSignalHandler::dispatch(const String &p_signal_name) {
    last_signal = p_signal_name;
    if (handlers.has(p_signal_name)) {
        Callable cb = handlers[p_signal_name];
        if (cb.is_valid()) {
            // Use call_deferred for thread safety — OS signals can arrive on any thread
            cb.call_deferred(p_signal_name);
        }
    }
}

// ─── Raise ─────────────────────────────────────────────────────────────────

void VGSignalHandler::raise_signal_by_name(const String &p_signal_name) {
    String upper = p_signal_name.to_upper();
    if (upper == "SIGINT")       { std::raise(SIGINT);  return; }
    if (upper == "SIGTERM")      { std::raise(SIGTERM); return; }
#ifndef _WIN32
    if (upper == "SIGHUP")       { std::raise(SIGHUP);  return; }
    if (upper == "SIGUSR1")      { std::raise(SIGUSR1); return; }
    if (upper == "SIGUSR2")      { std::raise(SIGUSR2); return; }
#endif
    // For unrecognised signals, just dispatch directly
    dispatch(upper);
}

// ─── Godot Bindings ────────────────────────────────────────────────────────

void VGSignalHandler::_bind_methods() {
    ClassDB::bind_method(D_METHOD("OnInterrupt", "handler"),  &VGSignalHandler::on_interrupt);
    ClassDB::bind_method(D_METHOD("OnTerminate", "handler"),  &VGSignalHandler::on_terminate);
    ClassDB::bind_method(D_METHOD("OnHangup", "handler"),     &VGSignalHandler::on_hangup);
    ClassDB::bind_method(D_METHOD("OnUser1", "handler"),      &VGSignalHandler::on_user1);
    ClassDB::bind_method(D_METHOD("OnUser2", "handler"),      &VGSignalHandler::on_user2);
    ClassDB::bind_method(D_METHOD("OnExit", "handler"),       &VGSignalHandler::on_exit);

    ClassDB::bind_method(D_METHOD("SetHandler", "signal_name", "handler"), &VGSignalHandler::set_handler);
    ClassDB::bind_method(D_METHOD("RemoveHandler", "signal_name"),         &VGSignalHandler::remove_handler);
    ClassDB::bind_method(D_METHOD("HasHandler", "signal_name"),            &VGSignalHandler::has_handler);
    ClassDB::bind_method(D_METHOD("GetRegisteredSignals"),                 &VGSignalHandler::get_registered_signals);

    ClassDB::bind_method(D_METHOD("Raise", "signal_name"), &VGSignalHandler::raise_signal_by_name);

    ClassDB::bind_method(D_METHOD("get_last_signal"), &VGSignalHandler::get_last_signal);
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "LastSignal"), "", "get_last_signal");

    ClassDB::bind_method(D_METHOD("get_is_installed"), &VGSignalHandler::get_is_installed);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsInstalled"), "", "get_is_installed");
}
