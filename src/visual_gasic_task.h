#ifndef VISUAL_GASIC_TASK_H
#define VISUAL_GASIC_TASK_H

// VGTask — Godot-registered async task system
// Exposes the internal TaskScheduler to VisualGasic scripts.
//
// Usage in VisualGasic:
//   ' Run a function asynchronously
//   Dim task As New Task
//   task.RunAsync AddressOf HeavyWork
//
//   ' Check status
//   If task.IsComplete Then
//       Print "Result: "; task.Result
//   End If
//
//   ' Run multiple tasks in parallel
//   Dim runner As New TaskRunner
//   runner.Add AddressOf Task1
//   runner.Add AddressOf Task2
//   runner.Add AddressOf Task3
//   runner.RunAll
//
//   Do While Not runner.AllComplete
//       DoEvents
//   Loop
//
//   ' Get results
//   For i = 0 To runner.Count - 1
//       Print runner.Result(i)
//   Next

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <functional>
#include <vector>

using namespace godot;

// ─── VGTask: single async operation ────────────────────────────────────────
class VGTask : public RefCounted {
    GDCLASS(VGTask, RefCounted);

    enum State { PENDING, RUNNING, COMPLETED, FAILED, CANCELLED };

    std::atomic<int> state;
    Variant result;
    String error_message;
    Callable work_callable;
    std::thread worker;
    std::mutex result_mutex;

protected:
    static void _bind_methods();

public:
    VGTask();
    ~VGTask();

    // Run a callable on a background thread
    void run_async(const Callable &p_callable);
    void run_async_with_args(const Callable &p_callable, const Array &p_args);

    // Delayed execution
    void run_delayed(const Callable &p_callable, double p_delay_seconds);

    // Status
    bool get_is_complete() const;
    bool get_is_running() const;
    bool get_is_failed() const;
    bool get_is_cancelled() const;
    String get_status() const;

    // Cancel (cooperative — sets flag, task must check)
    void cancel();
    bool get_is_cancelled_flag() const;

    // Result
    Variant get_result();
    String get_error() const { return error_message; }

    // Wait synchronously (blocks current thread — use sparingly)
    Variant wait_for_result(int p_timeout_ms = -1);
};

// ─── VGTaskRunner: run multiple tasks in parallel ──────────────────────────
class VGTaskRunner : public RefCounted {
    GDCLASS(VGTaskRunner, RefCounted);

    struct TaskEntry {
        Callable callable;
        Array args;
        Variant result;
        String error;
        std::atomic<int> state{0}; // 0=pending, 1=running, 2=complete, 3=failed
    };

    std::vector<TaskEntry *> tasks;
    std::vector<std::thread> workers;
    std::mutex tasks_mutex;
    int max_threads;

protected:
    static void _bind_methods();

public:
    VGTaskRunner();
    ~VGTaskRunner();

    // Add tasks to the pool
    void add(const Callable &p_callable);
    void add_with_args(const Callable &p_callable, const Array &p_args);

    // Execute all tasks
    void run_all();
    void run_all_limited(int p_max_threads);

    // Status
    bool get_all_complete() const;
    int get_complete_count() const;
    int get_count() const;
    double get_progress() const; // 0.0 to 1.0

    // Results
    Variant get_result(int p_index);
    Array get_all_results();
    bool has_errors() const;
    Array get_errors();

    // Reset for reuse
    void clear();

    // Static convenience: run and wait
    static Array run_parallel(const Array &p_callables);
};

#endif // VISUAL_GASIC_TASK_H
