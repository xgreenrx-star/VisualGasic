/**
 * VisualGasic Async/Await/Task System Implementation
 */

#include "visual_gasic_async.h"
#include <algorithm>
#include <chrono>

namespace VisualGasic {
namespace Async {

// ============================================================================
// Task Implementation
// ============================================================================

Task::Task(TaskHandle handle, TaskFunction func)
    : handle_(handle)
    , function_(std::move(func)) {
}

void Task::execute() {
    if (state_ == TaskState::CANCELLED) {
        return;
    }
    
    state_ = TaskState::RUNNING;
    
    // Execute the task function (no try/catch - exceptions disabled in Godot builds)
    result_ = function_();
    state_ = result_.success ? TaskState::COMPLETED : TaskState::FAILED;
    
    // Run continuations
    std::lock_guard<std::mutex> lock(mutex_);
    for (auto& cont : continuations_) {
        cont(result_);
    }
}

void Task::cancel() {
    TaskState expected = TaskState::PENDING;
    if (state_.compare_exchange_strong(expected, TaskState::CANCELLED)) {
        result_ = TaskResult(String("Task cancelled"));
        result_.success = false;
    }
}

void Task::add_continuation(ContinuationFunction cont) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (is_completed()) {
        // Already completed, run immediately
        cont(result_);
    } else {
        continuations_.push_back(std::move(cont));
    }
}

// ============================================================================
// TaskScheduler Implementation
// ============================================================================

TaskScheduler& TaskScheduler::get_instance() {
    static TaskScheduler instance;
    return instance;
}

TaskScheduler::TaskScheduler() {
    running_ = true;
    
    // Create worker threads
    for (size_t i = 0; i < thread_count_; ++i) {
        worker_threads_.emplace_back(&TaskScheduler::worker_thread_func, this);
    }
}

TaskScheduler::~TaskScheduler() {
    shutdown();
}

void TaskScheduler::shutdown() {
    running_ = false;
    queue_cv_.notify_all();
    
    for (auto& thread : worker_threads_) {
        if (thread.joinable()) {
            thread.join();
        }
    }
    worker_threads_.clear();
}

void TaskScheduler::worker_thread_func() {
    while (running_) {
        TaskHandle handle;
        
        {
            std::unique_lock<std::mutex> lock(queue_mutex_);
            queue_cv_.wait(lock, [this] {
                return !pending_queue_.empty() || !running_;
            });
            
            if (!running_ && pending_queue_.empty()) {
                return;
            }
            
            if (!pending_queue_.empty()) {
                handle = pending_queue_.front();
                pending_queue_.pop();
                pending_count_--;
                running_count_++;
            }
        }
        
        if (handle.is_valid()) {
            Task* task = find_task(handle);
            if (task) {
                task->execute();
                running_count_--;
                completed_count_++;
            }
        }
    }
}

TaskHandle TaskScheduler::schedule(Task::TaskFunction func) {
    TaskHandle handle(next_task_id_++);
    
    {
        std::lock_guard<std::mutex> lock(tasks_mutex_);
        tasks_.push_back(std::make_unique<Task>(handle, std::move(func)));
    }
    
    {
        std::lock_guard<std::mutex> lock(queue_mutex_);
        pending_queue_.push(handle);
        pending_count_++;
    }
    
    queue_cv_.notify_one();
    return handle;
}

TaskHandle TaskScheduler::schedule_delayed(Task::TaskFunction func, double delay_seconds) {
    // Wrap the function to include the delay
    auto delayed_func = [func, delay_seconds]() -> TaskResult {
        std::this_thread::sleep_for(
            std::chrono::milliseconds(static_cast<int>(delay_seconds * 1000)));
        return func();
    };
    
    return schedule(delayed_func);
}

Task* TaskScheduler::find_task(TaskHandle handle) {
    std::lock_guard<std::mutex> lock(tasks_mutex_);
    for (auto& task : tasks_) {
        if (task->get_handle() == handle) {
            return task.get();
        }
    }
    return nullptr;
}

bool TaskScheduler::is_completed(TaskHandle handle) const {
    std::lock_guard<std::mutex> lock(const_cast<std::mutex&>(tasks_mutex_));
    for (const auto& task : tasks_) {
        if (task->get_handle() == handle) {
            return task->is_completed();
        }
    }
    return true; // Not found means completed or invalid
}

TaskState TaskScheduler::get_state(TaskHandle handle) const {
    std::lock_guard<std::mutex> lock(const_cast<std::mutex&>(tasks_mutex_));
    for (const auto& task : tasks_) {
        if (task->get_handle() == handle) {
            return task->get_state();
        }
    }
    return TaskState::COMPLETED;
}

TaskResult TaskScheduler::get_result(TaskHandle handle) const {
    std::lock_guard<std::mutex> lock(const_cast<std::mutex&>(tasks_mutex_));
    for (const auto& task : tasks_) {
        if (task->get_handle() == handle) {
            return task->get_result();
        }
    }
    return TaskResult(String("Task not found"));
}

void TaskScheduler::cancel(TaskHandle handle) {
    Task* task = find_task(handle);
    if (task) {
        task->cancel();
    }
}

TaskResult TaskScheduler::await(TaskHandle handle) {
    // Busy-wait for completion (in a real implementation, use proper async patterns)
    while (!is_completed(handle)) {
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    return get_result(handle);
}

std::vector<TaskResult> TaskScheduler::await_all(const std::vector<TaskHandle>& handles) {
    std::vector<TaskResult> results;
    results.reserve(handles.size());
    
    for (const auto& handle : handles) {
        results.push_back(await(handle));
    }
    
    return results;
}

TaskResult TaskScheduler::await_any(const std::vector<TaskHandle>& handles, TaskHandle& completed_handle) {
    while (true) {
        for (const auto& handle : handles) {
            if (is_completed(handle)) {
                completed_handle = handle;
                return get_result(handle);
            }
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
}

void TaskScheduler::process_pending() {
    // This is called from the main thread to process completed tasks
    // and run any main-thread-only continuations
}

size_t TaskScheduler::get_pending_count() const {
    return pending_count_;
}

size_t TaskScheduler::get_running_count() const {
    return running_count_;
}

size_t TaskScheduler::get_completed_count() const {
    return completed_count_;
}

// ============================================================================
// AsyncContext Implementation
// ============================================================================

TaskHandle AsyncContext::suspend() {
    suspended_ = true;
    return current_await_;
}

void AsyncContext::resume(const Variant& value) {
    suspended_ = false;
}

void AsyncContext::set_local(const String& name, const Variant& value) {
    locals_[name] = value;
}

Variant AsyncContext::get_local(const String& name) const {
    if (locals_.has(name)) {
        return locals_[name];
    }
    return Variant();
}

bool AsyncContext::has_local(const String& name) const {
    return locals_.has(name);
}

// ============================================================================
// ParallelExecutor Implementation
// ============================================================================

std::vector<TaskResult> ParallelExecutor::parallel_invoke(
        const std::vector<Task::TaskFunction>& functions) {
    std::vector<TaskHandle> handles;
    handles.reserve(functions.size());
    
    auto& scheduler = TaskScheduler::get_instance();
    for (const auto& func : functions) {
        handles.push_back(scheduler.schedule(func));
    }
    
    return scheduler.await_all(handles);
}

Array ParallelExecutor::parallel_map(const Array& items, Callable func) {
    Array results;
    results.resize(items.size());
    
    std::vector<TaskHandle> handles;
    handles.reserve(items.size());
    
    auto& scheduler = TaskScheduler::get_instance();
    
    for (int i = 0; i < items.size(); ++i) {
        Variant item = items[i];
        int index = i;
        
        handles.push_back(scheduler.schedule([item, func]() -> TaskResult {
            Array args;
            args.push_back(item);
            return TaskResult(func.callv(args));
        }));
    }
    
    auto task_results = scheduler.await_all(handles);
    for (size_t i = 0; i < task_results.size(); ++i) {
        results[i] = task_results[i].value;
    }
    
    return results;
}

Array ParallelExecutor::parallel_filter(const Array& items, Callable predicate) {
    Array results;
    
    std::vector<TaskHandle> handles;
    handles.reserve(items.size());
    
    auto& scheduler = TaskScheduler::get_instance();
    
    for (int i = 0; i < items.size(); ++i) {
        Variant item = items[i];
        
        handles.push_back(scheduler.schedule([item, predicate]() -> TaskResult {
            Array args;
            args.push_back(item);
            bool keep = bool(predicate.callv(args));
            Dictionary result;
            result["item"] = item;
            result["keep"] = keep;
            return TaskResult(result);
        }));
    }
    
    auto task_results = scheduler.await_all(handles);
    for (const auto& result : task_results) {
        if (result.success) {
            Dictionary d = result.value;
            if (bool(d["keep"])) {
                results.push_back(d["item"]);
            }
        }
    }
    
    return results;
}

} // namespace Async
} // namespace VisualGasic
