// VGTimer — VB6 Timer control emulation
// Poll-based timer + static Timer() function (seconds since midnight)

#include "visual_gasic_timer.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/os.hpp>

using namespace godot;

void VGTimer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_interval", "ms"), &VGTimer::set_interval);
    ClassDB::bind_method(D_METHOD("get_interval"), &VGTimer::get_interval);
    ClassDB::bind_method(D_METHOD("set_enabled", "enabled"), &VGTimer::set_enabled);
    ClassDB::bind_method(D_METHOD("get_enabled"), &VGTimer::get_enabled);
    ClassDB::bind_method(D_METHOD("has_fired"), &VGTimer::has_fired);
    ClassDB::bind_method(D_METHOD("reset"), &VGTimer::reset);
    ClassDB::bind_method(D_METHOD("get_elapsed_ms"), &VGTimer::get_elapsed_ms);
    ClassDB::bind_static_method("VGTimer", D_METHOD("timer_function"), &VGTimer::timer_function);

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("HasFired"), &VGTimer::has_fired);
    ClassDB::bind_method(D_METHOD("Reset"), &VGTimer::reset);
    ClassDB::bind_method(D_METHOD("GetElapsedMs"), &VGTimer::get_elapsed_ms);

    ADD_PROPERTY(PropertyInfo(Variant::INT, "Interval"), "set_interval", "get_interval");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "Enabled"), "set_enabled", "get_enabled");
}

VGTimer::VGTimer() {
    interval_ms = 0;
    enabled = false;
    last_fire_ticks = Time::get_singleton()->get_ticks_msec();
    start_ticks = last_fire_ticks;
}

VGTimer::~VGTimer() {}

void VGTimer::set_interval(int p_ms) {
    interval_ms = p_ms;
}

int VGTimer::get_interval() const {
    return interval_ms;
}

void VGTimer::set_enabled(bool p_enabled) {
    enabled = p_enabled;
    if (p_enabled) {
        last_fire_ticks = Time::get_singleton()->get_ticks_msec();
    }
}

bool VGTimer::get_enabled() const {
    return enabled;
}

bool VGTimer::has_fired() {
    if (!enabled || interval_ms <= 0) return false;
    uint64_t now = Time::get_singleton()->get_ticks_msec();
    if (now - last_fire_ticks >= (uint64_t)interval_ms) {
        last_fire_ticks = now;
        return true;
    }
    return false;
}

void VGTimer::reset() {
    last_fire_ticks = Time::get_singleton()->get_ticks_msec();
}

int VGTimer::get_elapsed_ms() const {
    return (int)(Time::get_singleton()->get_ticks_msec() - start_ticks);
}

double VGTimer::timer_function() {
    // VB6 Timer() returns seconds since midnight as Single
    Dictionary dt = Time::get_singleton()->get_datetime_dict_from_system();
    int hour = dt["hour"];
    int minute = dt["minute"];
    int second = dt["second"];
    // Godot's datetime doesn't give sub-second precision via dict,
    // so add msec fraction from ticks
    uint64_t ticks = Time::get_singleton()->get_ticks_msec();
    double frac = (ticks % 1000) / 1000.0;
    return (double)(hour * 3600 + minute * 60 + second) + frac;
}
