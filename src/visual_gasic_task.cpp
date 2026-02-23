// VGTask / VGTaskRunner — Godot-registered async task system
// Wraps std::thread for background execution with VB6-friendly API

#include "visual_gasic_task.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <chrono>

using namespace godot;

// =============================================================================
// VGTask — Single async operation
// =============================================================================

void VGTask::_bind_methods() {
    ClassDB::bind_method(D_METHOD("run_async", "callable"), &VGTask::run_async);
    ClassDB::bind_method(D_METHOD("run_async_with_args", "callable", "args"), &VGTask::run_async_with_args);
    ClassDB::bind_method(D_METHOD("run_delayed", "callable", "delay_seconds"), &VGTask::run_delayed);
    ClassDB::bind_method(D_METHOD("cancel"), &VGTask::cancel);
    ClassDB::bind_method(D_METHOD("get_is_complete"), &VGTask::get_is_complete);
    ClassDB::bind_method(D_METHOD("get_is_running"), &VGTask::get_is_running);
    ClassDB::bind_method(D_METHOD("get_is_failed"), &VGTask::get_is_failed);
    ClassDB::bind_method(D_METHOD("get_is_cancelled"), &VGTask::get_is_cancelled);
    ClassDB::bind_method(D_METHOD("get_status"), &VGTask::get_status);
    ClassDB::bind_method(D_METHOD("get_result"), &VGTask::get_result);
    ClassDB::bind_method(D_METHOD("get_error"), &VGTask::get_error);
    ClassDB::bind_method(D_METHOD("wait_for_result", "timeout_ms"), &VGTask::wait_for_result, DEFVAL(-1));

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("RunAsync", "callable"), &VGTask::run_async);
    ClassDB::bind_method(D_METHOD("RunAsyncWithArgs", "callable", "args"), &VGTask::run_async_with_args);
    ClassDB::bind_method(D_METHOD("RunDelayed", "callable", "delay_seconds"), &VGTask::run_delayed);
    ClassDB::bind_method(D_METHOD("Cancel"), &VGTask::cancel);
    ClassDB::bind_method(D_METHOD("WaitForResult", "timeout_ms"), &VGTask::wait_for_result, DEFVAL(-1));

    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsComplete"), "", "get_is_complete");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsRunning"), "", "get_is_running");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsFailed"), "", "get_is_failed");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsCancelled"), "", "get_is_cancelled");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Status"), "", "get_status");
    ADD_PROPERTY(PropertyInfo(Variant::NIL, "Result"), "", "get_result");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Error"), "", "get_error");
}

VGTask::VGTask() {
    state.store(PENDING);
}

VGTask::~VGTask() {
    if (worker.joinable()) {
        worker.join();
    }
}

void VGTask::run_async(const Callable &p_callable) {
    if (state.load() == RUNNING) {
        UtilityFunctions::printerr("[VGTask] Task already running");
        return;
    }

    // If previous thread exists, join it first
    if (worker.joinable()) {
        worker.join();
    }

    state.store(RUNNING);
    work_callable = p_callable;

    worker = std::thread([this]() {
        Variant res = work_callable.callv(Array());
        std::lock_guard<std::mutex> lock(result_mutex);
        if (state.load() == CANCELLED) return;
        result = res;
        state.store(COMPLETED);
    });
}

void VGTask::run_async_with_args(const Callable &p_callable, const Array &p_args) {
    if (state.load() == RUNNING) {
        UtilityFunctions::printerr("[VGTask] Task already running");
        return;
    }

    if (worker.joinable()) {
        worker.join();
    }

    state.store(RUNNING);
    work_callable = p_callable;
    Array args_copy = p_args.duplicate();

    worker = std::thread([this, args_copy]() {
        Variant res = work_callable.callv(args_copy);
        std::lock_guard<std::mutex> lock(result_mutex);
        if (state.load() == CANCELLED) return;
        result = res;
        state.store(COMPLETED);
    });
}

void VGTask::run_delayed(const Callable &p_callable, double p_delay_seconds) {
    if (state.load() == RUNNING) {
        UtilityFunctions::printerr("[VGTask] Task already running");
        return;
    }

    if (worker.joinable()) {
        worker.join();
    }

    state.store(RUNNING);
    work_callable = p_callable;
    int delay_ms = (int)(p_delay_seconds * 1000.0);

    worker = std::thread([this, delay_ms]() {
        std::this_thread::sleep_for(std::chrono::milliseconds(delay_ms));
        if (state.load() == CANCELLED) return;
        Variant res = work_callable.callv(Array());
        std::lock_guard<std::mutex> lock(result_mutex);
        if (state.load() == CANCELLED) return;
        result = res;
        state.store(COMPLETED);
    });
}

void VGTask::cancel() {
    int expected = RUNNING;
    if (state.compare_exchange_strong(expected, CANCELLED)) {
        error_message = "Task cancelled";
    } else {
        expected = PENDING;
        state.compare_exchange_strong(expected, CANCELLED);
    }
}

bool VGTask::get_is_complete() const { return state.load() == COMPLETED; }
bool VGTask::get_is_running() const { return state.load() == RUNNING; }
bool VGTask::get_is_failed() const { return state.load() == FAILED; }
bool VGTask::get_is_cancelled() const { return state.load() == CANCELLED; }
bool VGTask::get_is_cancelled_flag() const { return state.load() == CANCELLED; }

String VGTask::get_status() const {
    switch (state.load()) {
        case PENDING: return "Pending";
        case RUNNING: return "Running";
        case COMPLETED: return "Completed";
        case FAILED: return "Failed";
        case CANCELLED: return "Cancelled";
    }
    return "Unknown";
}

Variant VGTask::get_result() {
    std::lock_guard<std::mutex> lock(result_mutex);
    return result;
}

Variant VGTask::wait_for_result(int p_timeout_ms) {
    if (state.load() >= COMPLETED) {
        std::lock_guard<std::mutex> lock(result_mutex);
        return result;
    }

    int elapsed = 0;
    while (state.load() < COMPLETED) {
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
        elapsed++;
        if (p_timeout_ms > 0 && elapsed >= p_timeout_ms) {
            return Variant(); // Timeout
        }
    }

    std::lock_guard<std::mutex> lock(result_mutex);
    return result;
}

// =============================================================================
// VGTaskRunner — Run multiple tasks in parallel
// =============================================================================

void VGTaskRunner::_bind_methods() {
    ClassDB::bind_method(D_METHOD("add", "callable"), &VGTaskRunner::add);
    ClassDB::bind_method(D_METHOD("add_with_args", "callable", "args"), &VGTaskRunner::add_with_args);
    ClassDB::bind_method(D_METHOD("run_all"), &VGTaskRunner::run_all);
    ClassDB::bind_method(D_METHOD("run_all_limited", "max_threads"), &VGTaskRunner::run_all_limited);
    ClassDB::bind_method(D_METHOD("get_all_complete"), &VGTaskRunner::get_all_complete);
    ClassDB::bind_method(D_METHOD("get_complete_count"), &VGTaskRunner::get_complete_count);
    ClassDB::bind_method(D_METHOD("get_count"), &VGTaskRunner::get_count);
    ClassDB::bind_method(D_METHOD("get_progress"), &VGTaskRunner::get_progress);
    ClassDB::bind_method(D_METHOD("get_result", "index"), &VGTaskRunner::get_result);
    ClassDB::bind_method(D_METHOD("get_all_results"), &VGTaskRunner::get_all_results);
    ClassDB::bind_method(D_METHOD("has_errors"), &VGTaskRunner::has_errors);
    ClassDB::bind_method(D_METHOD("get_errors"), &VGTaskRunner::get_errors);
    ClassDB::bind_method(D_METHOD("clear"), &VGTaskRunner::clear);
    ClassDB::bind_static_method("VGTaskRunner", D_METHOD("run_parallel", "callables"), &VGTaskRunner::run_parallel);

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("Add", "callable"), &VGTaskRunner::add);
    ClassDB::bind_method(D_METHOD("RunAll"), &VGTaskRunner::run_all);
    ClassDB::bind_method(D_METHOD("Clear"), &VGTaskRunner::clear);
    ClassDB::bind_method(D_METHOD("Count"), &VGTaskRunner::get_count);

    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "AllComplete"), "", "get_all_complete");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "CompleteCount"), "", "get_complete_count");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "Count"), "", "get_count");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "Progress"), "", "get_progress");
}

VGTaskRunner::VGTaskRunner() {
    max_threads = 4;
}

VGTaskRunner::~VGTaskRunner() {
    for (auto &w : workers) {
        if (w.joinable()) w.join();
    }
    for (auto *t : tasks) {
        delete t;
    }
}

void VGTaskRunner::add(const Callable &p_callable) {
    TaskEntry *entry = new TaskEntry();
    entry->callable = p_callable;
    tasks.push_back(entry);
}

void VGTaskRunner::add_with_args(const Callable &p_callable, const Array &p_args) {
    TaskEntry *entry = new TaskEntry();
    entry->callable = p_callable;
    entry->args = p_args.duplicate();
    tasks.push_back(entry);
}

void VGTaskRunner::run_all() {
    run_all_limited(max_threads);
}

void VGTaskRunner::run_all_limited(int p_max_threads) {
    // Launch threads for all tasks, limited by max_threads
    // Use a simple thread pool pattern
    std::atomic<int> next_task{0};
    int total = (int)tasks.size();
    int num_threads = p_max_threads < total ? p_max_threads : total;

    for (int t = 0; t < num_threads; t++) {
        workers.emplace_back([this, &next_task, total]() {
            while (true) {
                int idx = next_task.fetch_add(1);
                if (idx >= total) break;

                TaskEntry *entry = tasks[idx];
                entry->state.store(1); // RUNNING

                Variant res = entry->callable.callv(entry->args);
                entry->result = res;
                entry->state.store(2); // COMPLETED
            }
        });
    }

    // Wait for all threads to finish
    for (auto &w : workers) {
        if (w.joinable()) w.join();
    }
    workers.clear();
}

bool VGTaskRunner::get_all_complete() const {
    for (auto *t : tasks) {
        if (t->state.load() < 2) return false;
    }
    return true;
}

int VGTaskRunner::get_complete_count() const {
    int count = 0;
    for (auto *t : tasks) {
        if (t->state.load() >= 2) count++;
    }
    return count;
}

int VGTaskRunner::get_count() const { return (int)tasks.size(); }

double VGTaskRunner::get_progress() const {
    if (tasks.empty()) return 1.0;
    return (double)get_complete_count() / (double)tasks.size();
}

Variant VGTaskRunner::get_result(int p_index) {
    if (p_index < 0 || p_index >= (int)tasks.size()) return Variant();
    return tasks[p_index]->result;
}

Array VGTaskRunner::get_all_results() {
    Array results;
    for (auto *t : tasks) {
        results.push_back(t->result);
    }
    return results;
}

bool VGTaskRunner::has_errors() const {
    for (auto *t : tasks) {
        if (t->state.load() == 3) return true;
    }
    return false;
}

Array VGTaskRunner::get_errors() {
    Array errors;
    for (int i = 0; i < (int)tasks.size(); i++) {
        if (tasks[i]->state.load() == 3) {
            Dictionary err;
            err["index"] = i;
            err["error"] = tasks[i]->error;
            errors.push_back(err);
        }
    }
    return errors;
}

void VGTaskRunner::clear() {
    for (auto &w : workers) {
        if (w.joinable()) w.join();
    }
    workers.clear();
    for (auto *t : tasks) {
        delete t;
    }
    tasks.clear();
}

Array VGTaskRunner::run_parallel(const Array &p_callables) {
    Ref<VGTaskRunner> runner;
    runner.instantiate();
    for (int i = 0; i < p_callables.size(); i++) {
        runner->add(p_callables[i]);
    }
    runner->run_all();
    return runner->get_all_results();
}
