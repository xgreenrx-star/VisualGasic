#ifndef VISUAL_GASIC_TEST_RUNNER_H
#define VISUAL_GASIC_TEST_RUNNER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>

class VisualGasicTestRunner : public godot::RefCounted {
    GDCLASS(VisualGasicTestRunner, godot::RefCounted);

protected:
    static void _bind_methods();

public:
    VisualGasicTestRunner() = default;
    godot::Dictionary run_bytecode_tests();
};

#endif // VISUAL_GASIC_TEST_RUNNER_H
