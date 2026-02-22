// VGTimer — VB6 Timer control emulation
// Wraps Godot's Timer node with VB6-style Interval/Enabled properties

#ifndef VISUAL_GASIC_TIMER_H
#define VISUAL_GASIC_TIMER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class VGTimer : public RefCounted {
    GDCLASS(VGTimer, RefCounted)

protected:
    static void _bind_methods();

public:
    VGTimer();
    ~VGTimer();

    // VB6 Timer API
    void set_interval(int p_ms);
    int get_interval() const;
    void set_enabled(bool p_enabled);
    bool get_enabled() const;

    // Check if timer has fired (poll-based for non-node usage)
    bool has_fired();
    void reset();
    int get_elapsed_ms() const;

    // Static: VB6 Timer() function — seconds since midnight
    static double timer_function();

private:
    int interval_ms;
    bool enabled;
    uint64_t last_fire_ticks;
    uint64_t start_ticks;
};

} // namespace godot

#endif // VISUAL_GASIC_TIMER_H
