// ============================================================================
// VGFilePermissions — chmod, chown, symlinks, file locking, attributes
// ============================================================================
#include "visual_gasic_file_permissions.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include <cstring>

#ifdef _WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #include <io.h>
    #include <sys/stat.h>
#else
    #include <unistd.h>
    #include <sys/stat.h>
    #include <sys/file.h>    // flock
    #include <fcntl.h>
    #include <pwd.h>
    #include <grp.h>
    #include <errno.h>
    #include <dirent.h>
#endif

using namespace godot;

VGFilePermissions::VGFilePermissions() {}

VGFilePermissions::~VGFilePermissions() {
    // Release any held file locks
    Array keys = locked_files.keys();
    for (int i = 0; i < keys.size(); i++) {
        unlock_file(keys[i]);
    }
}

// ─── Permissions ───────────────────────────────────────────────────────────

bool VGFilePermissions::chmod_file(const String &p_path, int p_mode) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    // Windows only supports _S_IREAD / _S_IWRITE
    int win_mode = _S_IREAD;
    if (p_mode & 0200) win_mode |= _S_IWRITE;
    if (_chmod(path_utf8.get_data(), win_mode) == 0) return true;
    last_error = String("chmod failed: ") + strerror(errno);
    return false;
#else
    if (::chmod(path_utf8.get_data(), (mode_t)p_mode) == 0) return true;
    last_error = String("chmod failed: ") + strerror(errno);
    return false;
#endif
}

int VGFilePermissions::get_permissions(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
    struct stat st;
    if (stat(path_utf8.get_data(), &st) == 0) {
        return (int)(st.st_mode & 07777);
    }
    last_error = String("stat failed: ") + strerror(errno);
    return -1;
}

String VGFilePermissions::get_permissions_string(const String &p_path) {
    int mode = get_permissions(p_path);
    if (mode < 0) return "?????????";
    String result;
    const char *rwx = "rwxrwxrwx";
    for (int i = 8; i >= 0; i--) {
        char buf[2] = { rwx[8 - i], '\0' };
        result += (mode & (1 << i)) ? String(buf) : String("-");
    }
    return result;
}

bool VGFilePermissions::is_readable(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    return _access(path_utf8.get_data(), 4) == 0;
#else
    return access(path_utf8.get_data(), R_OK) == 0;
#endif
}

bool VGFilePermissions::is_writable(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    return _access(path_utf8.get_data(), 2) == 0;
#else
    return access(path_utf8.get_data(), W_OK) == 0;
#endif
}

bool VGFilePermissions::is_executable(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    // Windows: check extension
    return p_path.ends_with(".exe") || p_path.ends_with(".bat") || p_path.ends_with(".cmd");
#else
    return access(path_utf8.get_data(), X_OK) == 0;
#endif
}

// ─── Ownership ─────────────────────────────────────────────────────────────

bool VGFilePermissions::chown_file(const String &p_path, const String &p_owner, const String &p_group) {
#ifdef _WIN32
    last_error = "chown is not supported on Windows";
    return false;
#else
    CharString path_utf8 = p_path.utf8();
    uid_t uid = (uid_t)-1;
    gid_t gid = (gid_t)-1;

    if (!p_owner.is_empty()) {
        CharString owner_utf8 = p_owner.utf8();
        struct passwd *pw = getpwnam(owner_utf8.get_data());
        if (!pw) {
            last_error = String("Unknown user: ") + p_owner;
            return false;
        }
        uid = pw->pw_uid;
    }
    if (!p_group.is_empty()) {
        CharString group_utf8 = p_group.utf8();
        struct group *gr = getgrnam(group_utf8.get_data());
        if (!gr) {
            last_error = String("Unknown group: ") + p_group;
            return false;
        }
        gid = gr->gr_gid;
    }

    if (::chown(path_utf8.get_data(), uid, gid) == 0) return true;
    last_error = String("chown failed: ") + strerror(errno);
    return false;
#endif
}

String VGFilePermissions::get_owner(const String &p_path) {
#ifdef _WIN32
    return "";
#else
    CharString path_utf8 = p_path.utf8();
    struct stat st;
    if (stat(path_utf8.get_data(), &st) != 0) return "";
    struct passwd *pw = getpwuid(st.st_uid);
    return pw ? String(pw->pw_name) : String::num(st.st_uid);
#endif
}

String VGFilePermissions::get_group(const String &p_path) {
#ifdef _WIN32
    return "";
#else
    CharString path_utf8 = p_path.utf8();
    struct stat st;
    if (stat(path_utf8.get_data(), &st) != 0) return "";
    struct group *gr = getgrgid(st.st_gid);
    return gr ? String(gr->gr_name) : String::num(st.st_gid);
#endif
}

// ─── Symlinks ──────────────────────────────────────────────────────────────

bool VGFilePermissions::create_symlink(const String &p_link_path, const String &p_target_path) {
    CharString link_utf8 = p_link_path.utf8();
    CharString target_utf8 = p_target_path.utf8();
#ifdef _WIN32
    DWORD flags = 0;
    DWORD attrs = GetFileAttributesA(target_utf8.get_data());
    if (attrs != INVALID_FILE_ATTRIBUTES && (attrs & FILE_ATTRIBUTE_DIRECTORY))
        flags = SYMBOLIC_LINK_FLAG_DIRECTORY;
    flags |= SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE;
    if (CreateSymbolicLinkA(link_utf8.get_data(), target_utf8.get_data(), flags))
        return true;
    last_error = "CreateSymbolicLink failed: " + String::num(GetLastError());
    return false;
#else
    if (symlink(target_utf8.get_data(), link_utf8.get_data()) == 0) return true;
    last_error = String("symlink failed: ") + strerror(errno);
    return false;
#endif
}

bool VGFilePermissions::create_hardlink(const String &p_link_path, const String &p_target_path) {
    CharString link_utf8 = p_link_path.utf8();
    CharString target_utf8 = p_target_path.utf8();
#ifdef _WIN32
    if (CreateHardLinkA(link_utf8.get_data(), target_utf8.get_data(), nullptr))
        return true;
    last_error = "CreateHardLink failed: " + String::num(GetLastError());
    return false;
#else
    if (link(target_utf8.get_data(), link_utf8.get_data()) == 0) return true;
    last_error = String("link failed: ") + strerror(errno);
    return false;
#endif
}

bool VGFilePermissions::is_symlink(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    DWORD attrs = GetFileAttributesA(path_utf8.get_data());
    return attrs != INVALID_FILE_ATTRIBUTES && (attrs & FILE_ATTRIBUTE_REPARSE_POINT);
#else
    struct stat st;
    return lstat(path_utf8.get_data(), &st) == 0 && S_ISLNK(st.st_mode);
#endif
}

String VGFilePermissions::read_symlink(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    // Windows: use GetFinalPathNameByHandle (simplified)
    last_error = "ReadSymlink not fully supported on Windows";
    return "";
#else
    char buf[4096];
    ssize_t len = readlink(path_utf8.get_data(), buf, sizeof(buf) - 1);
    if (len > 0) {
        buf[len] = '\0';
        return String(buf);
    }
    last_error = String("readlink failed: ") + strerror(errno);
    return "";
#endif
}

// ─── File Locking ──────────────────────────────────────────────────────────

bool VGFilePermissions::lock_file(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    HANDLE h = CreateFileA(path_utf8.get_data(), GENERIC_READ | GENERIC_WRITE,
                           0, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) {
        last_error = "Cannot open file for locking: " + String::num(GetLastError());
        return false;
    }
    OVERLAPPED ol = {};
    if (LockFileEx(h, LOCKFILE_EXCLUSIVE_LOCK, 0, MAXDWORD, MAXDWORD, &ol)) {
        locked_files[p_path] = (int64_t)(intptr_t)h;
        return true;
    }
    CloseHandle(h);
    last_error = "LockFileEx failed: " + String::num(GetLastError());
    return false;
#else
    int fd = open(path_utf8.get_data(), O_RDWR);
    if (fd < 0) {
        last_error = String("Cannot open file for locking: ") + strerror(errno);
        return false;
    }
    if (flock(fd, LOCK_EX) == 0) {
        locked_files[p_path] = fd;
        return true;
    }
    close(fd);
    last_error = String("flock failed: ") + strerror(errno);
    return false;
#endif
}

bool VGFilePermissions::try_lock_file(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    HANDLE h = CreateFileA(path_utf8.get_data(), GENERIC_READ | GENERIC_WRITE,
                           0, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) return false;
    OVERLAPPED ol = {};
    if (LockFileEx(h, LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY, 0, MAXDWORD, MAXDWORD, &ol)) {
        locked_files[p_path] = (int64_t)(intptr_t)h;
        return true;
    }
    CloseHandle(h);
    return false;
#else
    int fd = open(path_utf8.get_data(), O_RDWR);
    if (fd < 0) return false;
    if (flock(fd, LOCK_EX | LOCK_NB) == 0) {
        locked_files[p_path] = fd;
        return true;
    }
    close(fd);
    return false;
#endif
}

bool VGFilePermissions::unlock_file(const String &p_path) {
    if (!locked_files.has(p_path)) {
        last_error = "File not locked: " + p_path;
        return false;
    }
#ifdef _WIN32
    ERR_FAIL_COND_V_MSG(locked_files[p_path].get_type() != Variant::INT, false,
        "VGFilePermissions: corrupted lock entry for " + p_path);
    HANDLE h = (HANDLE)(intptr_t)(int64_t)locked_files[p_path];
    OVERLAPPED ol = {};
    UnlockFileEx(h, 0, MAXDWORD, MAXDWORD, &ol);
    CloseHandle(h);
#else
    ERR_FAIL_COND_V_MSG(locked_files[p_path].get_type() != Variant::INT, false,
        "VGFilePermissions: corrupted lock entry for " + p_path);
    int fd = (int)(int64_t)locked_files[p_path];
    flock(fd, LOCK_UN);
    close(fd);
#endif
    locked_files.erase(p_path);
    return true;
}

bool VGFilePermissions::is_locked(const String &p_path) {
    return locked_files.has(p_path);
}

// ─── VB6-Style Attributes ──────────────────────────────────────────────────

int VGFilePermissions::get_attr(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
    int result = 0;
#ifdef _WIN32
    DWORD attrs = GetFileAttributesA(path_utf8.get_data());
    if (attrs == INVALID_FILE_ATTRIBUTES) return -1;
    if (attrs & FILE_ATTRIBUTE_READONLY)  result |= 1;
    if (attrs & FILE_ATTRIBUTE_HIDDEN)    result |= 2;
    if (attrs & FILE_ATTRIBUTE_SYSTEM)    result |= 4;
    if (attrs & FILE_ATTRIBUTE_DIRECTORY) result |= 16;
    if (attrs & FILE_ATTRIBUTE_ARCHIVE)   result |= 32;
#else
    struct stat st;
    if (stat(path_utf8.get_data(), &st) != 0) return -1;
    if (!(st.st_mode & S_IWUSR)) result |= 1;     // ReadOnly
    if (p_path.get_file().begins_with(".")) result |= 2;  // Hidden (Unix convention)
    if (S_ISDIR(st.st_mode)) result |= 16;         // Directory
    result |= 32;                                    // Archive (always set on Unix)
#endif
    return result;
}

bool VGFilePermissions::set_attr(const String &p_path, int p_attr) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    DWORD attrs = 0;
    if (p_attr & 1)  attrs |= FILE_ATTRIBUTE_READONLY;
    if (p_attr & 2)  attrs |= FILE_ATTRIBUTE_HIDDEN;
    if (p_attr & 4)  attrs |= FILE_ATTRIBUTE_SYSTEM;
    if (p_attr & 32) attrs |= FILE_ATTRIBUTE_ARCHIVE;
    if (attrs == 0) attrs = FILE_ATTRIBUTE_NORMAL;
    if (SetFileAttributesA(path_utf8.get_data(), attrs)) return true;
    last_error = "SetFileAttributes failed: " + String::num(GetLastError());
    return false;
#else
    struct stat st;
    if (stat(path_utf8.get_data(), &st) != 0) {
        last_error = String("stat failed: ") + strerror(errno);
        return false;
    }
    mode_t mode = st.st_mode;
    if (p_attr & 1) {
        mode &= ~(S_IWUSR | S_IWGRP | S_IWOTH);  // ReadOnly
    } else {
        mode |= S_IWUSR;
    }
    if (::chmod(path_utf8.get_data(), mode) == 0) return true;
    last_error = String("chmod failed: ") + strerror(errno);
    return false;
#endif
}

// ─── File Info ─────────────────────────────────────────────────────────────

int64_t VGFilePermissions::get_file_size(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
    struct stat st;
    if (stat(path_utf8.get_data(), &st) == 0) return (int64_t)st.st_size;
    return -1;
}

String VGFilePermissions::get_file_type(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    DWORD attrs = GetFileAttributesA(path_utf8.get_data());
    if (attrs == INVALID_FILE_ATTRIBUTES) return "unknown";
    if (attrs & FILE_ATTRIBUTE_DIRECTORY) return "directory";
    if (attrs & FILE_ATTRIBUTE_REPARSE_POINT) return "symlink";
    return "file";
#else
    struct stat st;
    if (lstat(path_utf8.get_data(), &st) != 0) return "unknown";
    if (S_ISREG(st.st_mode))  return "file";
    if (S_ISDIR(st.st_mode))  return "directory";
    if (S_ISLNK(st.st_mode))  return "symlink";
    if (S_ISFIFO(st.st_mode)) return "pipe";
    if (S_ISSOCK(st.st_mode)) return "socket";
    if (S_ISBLK(st.st_mode))  return "block_device";
    if (S_ISCHR(st.st_mode))  return "char_device";
    return "unknown";
#endif
}

Dictionary VGFilePermissions::get_file_info(const String &p_path) {
    Dictionary info;
    CharString path_utf8 = p_path.utf8();
    struct stat st;
    if (stat(path_utf8.get_data(), &st) != 0) {
        info["error"] = String("stat failed: ") + strerror(errno);
        return info;
    }
    info["size"] = (int64_t)st.st_size;
    info["permissions"] = (int)(st.st_mode & 07777);
    info["permissions_string"] = get_permissions_string(p_path);
    info["type"] = get_file_type(p_path);
    info["is_symlink"] = is_symlink(p_path);
    info["owner"] = get_owner(p_path);
    info["group"] = get_group(p_path);
    info["modified"] = (int64_t)st.st_mtime;
    info["accessed"] = (int64_t)st.st_atime;
    info["created"] = (int64_t)st.st_ctime;
    info["inode"] = (int64_t)st.st_ino;
    info["hard_links"] = (int64_t)st.st_nlink;
    return info;
}

// ─── Godot Bindings ────────────────────────────────────────────────────────

void VGFilePermissions::_bind_methods() {
    // Permissions
    ClassDB::bind_method(D_METHOD("Chmod", "path", "mode"),          &VGFilePermissions::chmod_file);
    ClassDB::bind_method(D_METHOD("GetPermissions", "path"),         &VGFilePermissions::get_permissions);
    ClassDB::bind_method(D_METHOD("GetPermissionsString", "path"),   &VGFilePermissions::get_permissions_string);
    ClassDB::bind_method(D_METHOD("IsReadable", "path"),             &VGFilePermissions::is_readable);
    ClassDB::bind_method(D_METHOD("IsWritable", "path"),             &VGFilePermissions::is_writable);
    ClassDB::bind_method(D_METHOD("IsExecutable", "path"),           &VGFilePermissions::is_executable);

    // Ownership
    ClassDB::bind_method(D_METHOD("Chown", "path", "owner", "group"), &VGFilePermissions::chown_file);
    ClassDB::bind_method(D_METHOD("GetOwner", "path"),               &VGFilePermissions::get_owner);
    ClassDB::bind_method(D_METHOD("GetGroup", "path"),               &VGFilePermissions::get_group);

    // Symlinks
    ClassDB::bind_method(D_METHOD("CreateSymlink", "link_path", "target_path"), &VGFilePermissions::create_symlink);
    ClassDB::bind_method(D_METHOD("CreateHardlink", "link_path", "target_path"), &VGFilePermissions::create_hardlink);
    ClassDB::bind_method(D_METHOD("IsSymlink", "path"),              &VGFilePermissions::is_symlink);
    ClassDB::bind_method(D_METHOD("ReadSymlink", "path"),            &VGFilePermissions::read_symlink);

    // File locking
    ClassDB::bind_method(D_METHOD("Lock", "path"),     &VGFilePermissions::lock_file);
    ClassDB::bind_method(D_METHOD("TryLock", "path"),  &VGFilePermissions::try_lock_file);
    ClassDB::bind_method(D_METHOD("Unlock", "path"),   &VGFilePermissions::unlock_file);
    ClassDB::bind_method(D_METHOD("IsLocked", "path"), &VGFilePermissions::is_locked);

    // VB6 attributes
    ClassDB::bind_method(D_METHOD("GetAttr", "path"),         &VGFilePermissions::get_attr);
    ClassDB::bind_method(D_METHOD("SetAttr", "path", "attr"), &VGFilePermissions::set_attr);

    // File info
    ClassDB::bind_method(D_METHOD("GetFileInfo", "path"),  &VGFilePermissions::get_file_info);
    ClassDB::bind_method(D_METHOD("FileLen", "path"),      &VGFilePermissions::get_file_size);
    ClassDB::bind_method(D_METHOD("FileType", "path"),     &VGFilePermissions::get_file_type);

    // Error
    ClassDB::bind_method(D_METHOD("get_last_error"), &VGFilePermissions::get_last_error);
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "LastError"), "", "get_last_error");
}
