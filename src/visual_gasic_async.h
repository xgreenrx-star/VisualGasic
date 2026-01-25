/**
 * VisualGasic Async/Await/Task System
 * Provides asynchronous execution infrastructure for VisualGasic scripts
 */

#ifndef VISUAL_GASIC_ASYNC_H
#define VISUAL_GASIC_ASYNC_H

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <functional>
#include <vector>
#include <memory>
#include <queue>
#include <mutex>
#include <atomic>
#include <thread>
#include <condition_variable>
#include <future>

using namespace godot;

namespace VisualGasic {
namespace Async {

// Task states
enum class TaskState {
    PENDING,
    RUNNING,
    COMPLETED,
    FAILED,
    CANCELLED
};

// Task result container
struct TaskResult {
    Variant value;
    String error_message;
    bool success = true;
    
    TaskResult() = default;
    TaskResult(const Variant& v) : value(v), success(true) {}
    TaskResult(const String& error) : error_message(error), success(false) {}
};

// Forward declarations
class Task;
class TaskScheduler;

// Task handle for tracking async operations
class TaskHandle {
public:
    TaskHandle() : task_id_(0) {}
    TaskHandle(uint64_t id) : task_id_(id) {}
    
    uint64_t get_id() const { return task_id_; }
    bool is_valid() const { return task_id_ != 0; }
    
    bool operator==(const TaskHandle& other) const { return task_id_ == other.task_id_; }
    bool operator!=(const TaskHandle& other) const { return task_id_ != other.task_id_; }
    
private:
    uint64_t task_id_;
};

// Task definition
class Task {
public:
    using TaskFunction = std::function<TaskResult()>;
    using ContinuationFunction = std::function<void(const TaskResult&)>;
    
    Task(TaskHandle handle, TaskFunction func);
    ~Task() = default;
    
    TaskHandle get_handle() const { return handle_; }
    TaskState get_state() const { return state_; }
    const TaskResult& get_result() const { return result_; }
    
    void execute();
    void cancel();
    void add_continuation(ContinuationFunction cont);
    
    bool is_completed() const { return state_ == TaskState::COMPLETED || state_ == TaskState::FAILED; }
    bool is_cancelled() const { return state_ == TaskState::CANCELLED; }
    
private:
    TaskHandle handle_;
    TaskFunction function_;
    std::vector<ContinuationFunction> continuations_;
    TaskResult result_;
    std::atomic<TaskState> state_{TaskState::PENDING};
    std::mutex mutex_;
};

// Task scheduler - manages async task execution
class TaskScheduler {
public:
    static TaskScheduler& get_instance();
    
    // Task creation
    TaskHandle schedule(Task::TaskFunction func);
    TaskHandle schedule_delayed(Task::TaskFunction func, double delay_seconds);
    
    // Task management
    bool is_completed(TaskHandle handle) const;
    TaskState get_state(TaskHandle handle) const;
    TaskResult get_result(TaskHandle handle) const;
    void cancel(TaskHandle handle);
    
    // Awaiting
    TaskResult await(TaskHandle handle);
    std::vector<TaskResult> await_all(const std::vector<TaskHandle>& handles);
    TaskResult await_any(const std::vector<TaskHandle>& handles, TaskHandle& completed_handle);
    
    // Processing
    void process_pending();  // Call from main thread each frame
    void shutdown();
    
    // Statistics
    size_t get_pending_count() const;
    size_t get_running_count() const;
    size_t get_completed_count() const;
    
private:
    TaskScheduler();
    ~TaskScheduler();
    
    // Prevent copying
    TaskScheduler(const TaskScheduler&) = delete;
    TaskScheduler& operator=(const TaskScheduler&) = delete;
    
    void worker_thread_func();
    Task* find_task(TaskHandle handle);
    
    std::atomic<uint64_t> next_task_id_{1};
    std::vector<std::unique_ptr<Task>> tasks_;
    std::queue<TaskHandle> pending_queue_;
    std::mutex tasks_mutex_;
    std::mutex queue_mutex_;
    std::condition_variable queue_cv_;
    
    std::vector<std::thread> worker_threads_;
    std::atomic<bool> running_{false};
    size_t thread_count_ = 4;
    
    std::atomic<size_t> pending_count_{0};
    std::atomic<size_t> running_count_{0};
    std::atomic<size_t> completed_count_{0};
};

// Async function context - maintains state for async function execution
class AsyncContext {
public:
    AsyncContext() = default;
    ~AsyncContext() = default;
    
    // Suspend execution and return a task handle
    TaskHandle suspend();
    
    // Resume with a value
    void resume(const Variant& value);
    
    // Check if suspended
    bool is_suspended() const { return suspended_; }
    
    // Get/set local variables preserved across suspension
    void set_local(const String& name, const Variant& value);
    Variant get_local(const String& name) const;
    bool has_local(const String& name) const;
    
private:
    bool suspended_ = false;
    TaskHandle current_await_;
    Dictionary locals_;
};

// Parallel execution utilities
class ParallelExecutor {
public:
    // Execute items in parallel with a function
    template<typename T>
    static std::vector<TaskResult> parallel_for(
        const std::vector<T>& items,
        std::function<TaskResult(const T&, size_t)> func);
    
    // Execute multiple independent tasks in parallel
    static std::vector<TaskResult> parallel_invoke(
        const std::vector<Task::TaskFunction>& functions);
    
    // Parallel map operation
    static Array parallel_map(const Array& items, Callable func);
    
    // Parallel filter operation
    static Array parallel_filter(const Array& items, Callable predicate);
};

// Helper macros for async patterns
#define VG_ASYNC_BEGIN(context) \
    AsyncContext& __async_ctx = context; \
    if (__async_ctx.is_suspended()) { goto __async_resume; }

#define VG_AWAIT(task_handle) \
    do { \
        __async_ctx.suspend(); \
        return TaskScheduler::get_instance().await(task_handle); \
        __async_resume:; \
    } while(0)

// Convenience functions
inline TaskHandle run_async(Task::TaskFunction func) {
    return TaskScheduler::get_instance().schedule(func);
}

inline TaskResult await_task(TaskHandle handle) {
    return TaskScheduler::get_instance().await(handle);
}

inline std::vector<TaskResult> await_all_tasks(const std::vector<TaskHandle>& handles) {
    return TaskScheduler::get_instance().await_all(handles);
}

} // namespace Async
} // namespace VisualGasic

#endif // VISUAL_GASIC_ASYNC_H
