// VGFileWatcher — inotify-based file system watcher

#include "visual_gasic_fswatcher.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/dir_access.hpp>

#ifdef __linux__
#include <sys/inotify.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <poll.h>
#elif defined(_WIN32)
#include <windows.h>
#endif

using namespace godot;

#ifdef __linux__
// inotify event buffer size
#define EVENT_BUF_SIZE (1024 * (sizeof(struct inotify_event) + 16))
#endif

void VGFileWatcher::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_path", "path"), &VGFileWatcher::set_path);
    ClassDB::bind_method(D_METHOD("get_path"), &VGFileWatcher::get_path);
    ClassDB::bind_method(D_METHOD("set_filter", "filter"), &VGFileWatcher::set_filter);
    ClassDB::bind_method(D_METHOD("get_filter"), &VGFileWatcher::get_filter);
    ClassDB::bind_method(D_METHOD("set_enable_raising_events", "enabled"), &VGFileWatcher::set_enable_raising_events);
    ClassDB::bind_method(D_METHOD("get_enable_raising_events"), &VGFileWatcher::get_enable_raising_events);
    ClassDB::bind_method(D_METHOD("set_include_subdirectories", "include"), &VGFileWatcher::set_include_subdirectories);
    ClassDB::bind_method(D_METHOD("get_include_subdirectories"), &VGFileWatcher::get_include_subdirectories);
    ClassDB::bind_method(D_METHOD("poll_changes"), &VGFileWatcher::poll_changes);
    ClassDB::bind_method(D_METHOD("has_changes"), &VGFileWatcher::has_changes);
    ClassDB::bind_method(D_METHOD("get_pending_count"), &VGFileWatcher::get_pending_count);
    ClassDB::bind_method(D_METHOD("clear"), &VGFileWatcher::clear);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Path"), "set_path", "get_path");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "Filter"), "set_filter", "get_filter");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "EnableRaisingEvents"), "set_enable_raising_events", "get_enable_raising_events");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IncludeSubdirectories"), "set_include_subdirectories", "get_include_subdirectories");

    // VB6-style aliases
    ClassDB::bind_method(D_METHOD("PollChanges"), &VGFileWatcher::poll_changes);
    ClassDB::bind_method(D_METHOD("HasChanges"), &VGFileWatcher::has_changes);
    ClassDB::bind_method(D_METHOD("GetPendingCount"), &VGFileWatcher::get_pending_count);
    ClassDB::bind_method(D_METHOD("Clear"), &VGFileWatcher::clear);
}

VGFileWatcher::VGFileWatcher() {
    inotify_fd = -1;
    watch_descriptor = -1;
    enabled = false;
    include_subdirectories = false;
#ifdef _WIN32
    win_watch_handle = nullptr;
#endif
}

VGFileWatcher::~VGFileWatcher() {
    teardown_watch();
}

void VGFileWatcher::set_path(const String &p_path) {
    if (watch_path == p_path) return;
    watch_path = p_path;
    if (enabled) {
        teardown_watch();
        setup_watch();
    }
}

void VGFileWatcher::set_filter(const String &p_filter) {
    filter = p_filter;
}

void VGFileWatcher::set_enable_raising_events(bool p_enabled) {
    if (enabled == p_enabled) return;
    enabled = p_enabled;
    if (enabled) {
        setup_watch();
    } else {
        teardown_watch();
    }
}

void VGFileWatcher::set_include_subdirectories(bool p_include) {
    if (include_subdirectories == p_include) return;
    include_subdirectories = p_include;
    if (enabled) {
        teardown_watch();
        setup_watch();
    }
}

bool VGFileWatcher::matches_filter(const String &p_filename) const {
    if (filter.is_empty() || filter == "*" || filter == "*.*") return true;

    // Simple glob matching: *.ext
    if (filter.begins_with("*.")) {
        String ext = filter.substr(1); // .ext
        return p_filename.ends_with(ext);
    }

    // Exact match
    return p_filename.matchn(filter);
}

void VGFileWatcher::setup_watch() {
#ifdef __linux__
    if (watch_path.is_empty()) return;

    inotify_fd = inotify_init1(IN_NONBLOCK);
    if (inotify_fd < 0) {
        UtilityFunctions::printerr("[VGFileWatcher] Failed to init inotify: ", strerror(errno));
        return;
    }

    // Watch for common file events
    uint32_t mask = IN_CREATE | IN_DELETE | IN_MODIFY | IN_MOVED_FROM | IN_MOVED_TO | IN_CLOSE_WRITE;

    watch_descriptor = inotify_add_watch(inotify_fd, watch_path.utf8().get_data(), mask);
    if (watch_descriptor < 0) {
        UtilityFunctions::printerr("[VGFileWatcher] Failed to watch '", watch_path, "': ", strerror(errno));
        ::close(inotify_fd);
        inotify_fd = -1;
        return;
    }

    wd_to_path[watch_descriptor] = watch_path;

    if (include_subdirectories) {
        add_watch_recursive(watch_path);
    }

    UtilityFunctions::print("[VGFileWatcher] Watching: ", watch_path,
                            (include_subdirectories ? " (recursive)" : ""));
#elif defined(_WIN32)
    if (watch_path.is_empty()) return;

    Char16String wide_path = watch_path.utf16();
    DWORD filter = FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME |
                   FILE_NOTIFY_CHANGE_SIZE | FILE_NOTIFY_CHANGE_LAST_WRITE |
                   FILE_NOTIFY_CHANGE_CREATION;

    win_watch_handle = FindFirstChangeNotificationW(
        (LPCWSTR)wide_path.get_data(),
        include_subdirectories ? TRUE : FALSE,
        filter
    );

    if (win_watch_handle == INVALID_HANDLE_VALUE) {
        UtilityFunctions::printerr("[VGFileWatcher] FindFirstChangeNotification failed for: ", watch_path);
        win_watch_handle = nullptr;
        return;
    }

    UtilityFunctions::print("[VGFileWatcher] Watching: ", watch_path,
                            (include_subdirectories ? " (recursive)" : ""));
#else
    UtilityFunctions::printerr("[VGFileWatcher] Not implemented on this platform");
#endif
}

void VGFileWatcher::add_watch_recursive(const String &p_path) {
#ifdef __linux__
    Ref<DirAccess> dir = DirAccess::open(p_path);
    if (!dir.is_valid()) return;

    dir->list_dir_begin();
    String name = dir->get_next();
    while (!name.is_empty()) {
        if (dir->current_is_dir() && name != "." && name != "..") {
            String subdir = p_path + String("/") + name;
            uint32_t mask = IN_CREATE | IN_DELETE | IN_MODIFY | IN_MOVED_FROM | IN_MOVED_TO | IN_CLOSE_WRITE;
            int wd = inotify_add_watch(inotify_fd, subdir.utf8().get_data(), mask);
            if (wd >= 0) {
                wd_to_path[wd] = subdir;
            }
            add_watch_recursive(subdir);
        }
        name = dir->get_next();
    }
    dir->list_dir_end();
#endif
}

void VGFileWatcher::teardown_watch() {
#ifdef __linux__
    if (inotify_fd >= 0) {
        // Remove all watches
        Array wds = wd_to_path.keys();
        for (int i = 0; i < wds.size(); i++) {
            inotify_rm_watch(inotify_fd, (int)wds[i]);
        }
        ::close(inotify_fd);
        inotify_fd = -1;
        watch_descriptor = -1;
        wd_to_path.clear();
    }
#elif defined(_WIN32)
    if (win_watch_handle) {
        FindCloseChangeNotification(win_watch_handle);
        win_watch_handle = nullptr;
    }
#endif
}

Array VGFileWatcher::poll_changes() {
    Array events;
#ifdef __linux__
    if (inotify_fd < 0) return events;

    char buffer[EVENT_BUF_SIZE] __attribute__((aligned(8)));
    ssize_t length = read(inotify_fd, buffer, EVENT_BUF_SIZE);

    if (length <= 0) return events;

    ssize_t i = 0;
    while (i < length) {
        struct inotify_event *event = (struct inotify_event *)&buffer[i];

        if (event->len > 0) {
            String filename = String::utf8(event->name);

            // Check filter
            if (!matches_filter(filename)) {
                i += sizeof(struct inotify_event) + event->len;
                continue;
            }

            String dir_path = watch_path;
            if (wd_to_path.has(event->wd)) {
                dir_path = wd_to_path[event->wd];
            }
            String full_path = dir_path + String("/") + filename;

            Dictionary evt;
            evt["path"] = full_path;
            evt["filename"] = filename;

            if (event->mask & IN_CREATE) {
                evt["type"] = "Created";
            } else if (event->mask & IN_DELETE) {
                evt["type"] = "Deleted";
            } else if (event->mask & (IN_MODIFY | IN_CLOSE_WRITE)) {
                evt["type"] = "Changed";
            } else if (event->mask & IN_MOVED_FROM) {
                evt["type"] = "Renamed";
                evt["subtype"] = "from";
            } else if (event->mask & IN_MOVED_TO) {
                evt["type"] = "Renamed";
                evt["subtype"] = "to";
            }

            events.push_back(evt);

            // If a new directory was created and we're recursive, add a watch
            if ((event->mask & IN_CREATE) && (event->mask & IN_ISDIR) && include_subdirectories) {
                uint32_t mask = IN_CREATE | IN_DELETE | IN_MODIFY | IN_MOVED_FROM | IN_MOVED_TO | IN_CLOSE_WRITE;
                int wd = inotify_add_watch(inotify_fd, full_path.utf8().get_data(), mask);
                if (wd >= 0) {
                    wd_to_path[wd] = full_path;
                }
            }
        }

        i += sizeof(struct inotify_event) + event->len;
    }
#elif defined(_WIN32)
    if (win_watch_handle) {
        DWORD wait_result = WaitForSingleObject(win_watch_handle, 0);
        if (wait_result == WAIT_OBJECT_0) {
            // A change was detected in the watched directory
            Dictionary evt;
            evt["path"] = watch_path;
            evt["filename"] = "";
            evt["type"] = "Changed";
            events.push_back(evt);

            // Re-arm the notification for subsequent changes
            FindNextChangeNotification(win_watch_handle);
        }
    }
#endif
    return events;
}

void VGFileWatcher::clear() {
    pending_events.clear();
}
