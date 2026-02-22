#ifndef VISUAL_GASIC_FSWATCHER_H
#define VISUAL_GASIC_FSWATCHER_H

// VGFileWatcher — inotify-based file system watcher
// Usage in VisualGasic:
//   Dim watcher As New FileSystemWatcher
//   watcher.Path = "/home/user/documents"
//   watcher.Filter = "*.txt"
//   watcher.EnableRaisingEvents = True
//
//   ' Poll for changes in game loop or timer
//   Dim changes As Variant
//   changes = watcher.PollChanges()
//   For Each change In changes
//       Print change("type"); ": "; change("path")
//   Next

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

class VGFileWatcher : public RefCounted {
    GDCLASS(VGFileWatcher, RefCounted);

    String watch_path;
    String filter;
    bool enabled;
    bool include_subdirectories;

    // inotify state (Linux)
    int inotify_fd;
    int watch_descriptor;
    // Map of wd -> directory path for subdirectory watching
    Dictionary wd_to_path;
#ifdef _WIN32
    void *win_watch_handle;
#endif

    // Pending events queue
    Array pending_events;

    void setup_watch();
    void teardown_watch();
    void add_watch_recursive(const String &p_path);
    bool matches_filter(const String &p_filename) const;

protected:
    static void _bind_methods();

public:
    VGFileWatcher();
    ~VGFileWatcher();

    // Properties (VB6 / .NET style)
    void set_path(const String &p_path);
    String get_path() const { return watch_path; }
    void set_filter(const String &p_filter);
    String get_filter() const { return filter; }
    void set_enable_raising_events(bool p_enabled);
    bool get_enable_raising_events() const { return enabled; }
    void set_include_subdirectories(bool p_include);
    bool get_include_subdirectories() const { return include_subdirectories; }

    // Poll for changes (returns Array of Dictionary with "type" and "path")
    // Types: "Created", "Deleted", "Changed", "Renamed"
    Array poll_changes();

    // Check if there are pending changes without consuming them
    bool has_changes() const { return pending_events.size() > 0; }
    int get_pending_count() const { return pending_events.size(); }

    // Clear all pending events
    void clear();
};

#endif // VISUAL_GASIC_FSWATCHER_H
