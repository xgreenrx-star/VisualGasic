// ============================================================================
// VGIPC — Inter-Process Communication: named pipes, domain sockets, shared mem
// ============================================================================
#include "visual_gasic_ipc.h"

#include <godot_cpp/variant/utility_functions.hpp>
#include <cstring>
#include <cerrno>

#ifdef _WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
#else
    #include <unistd.h>
    #include <fcntl.h>
    #include <sys/stat.h>
    #include <sys/socket.h>
    #include <sys/un.h>
    #include <sys/mman.h>
#endif

using namespace godot;

VGIPC::VGIPC()
    : pipe_fd(-1), domain_fd(-1), client_fd(-1),
      shm_ptr(nullptr), shm_size(0)
#ifdef _WIN32
    , shm_handle(nullptr)
#else
    , shm_fd(-1)
#endif
{}

VGIPC::~VGIPC() {
    close_pipe();
    close_socket();
    close_shared_memory();
}

// ═══════════════════════════════════════════════════════════════════════════
// Named Pipes
// ═══════════════════════════════════════════════════════════════════════════

bool VGIPC::create_named_pipe(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    // On Windows, named pipes use \\.\pipe\name format
    // Creating the pipe server will happen in open_pipe
    pipe_path = p_path;
    return true;
#else
    // Remove existing FIFO
    unlink(path_utf8.get_data());
    if (mkfifo(path_utf8.get_data(), 0666) == 0) {
        pipe_path = p_path;
        return true;
    }
    last_error = String("mkfifo failed: ") + strerror(errno);
    return false;
#endif
}

bool VGIPC::open_pipe(const String &p_path, const String &p_mode) {
    close_pipe();
    CharString path_utf8 = p_path.utf8();
    bool read_mode = (p_mode.to_lower() == "read");

#ifdef _WIN32
    if (read_mode) {
        // Create named pipe server and wait for connection
        String win_path = "\\\\.\\pipe\\" + p_path.get_file();
        CharString wp = win_path.utf8();
        HANDLE h = CreateNamedPipeA(wp.get_data(),
            PIPE_ACCESS_INBOUND, PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
            1, 4096, 4096, 0, nullptr);
        if (h == INVALID_HANDLE_VALUE) {
            last_error = "CreateNamedPipe failed: " + String::num(GetLastError());
            return false;
        }
        ConnectNamedPipe(h, nullptr);
        pipe_fd = (int)(intptr_t)h;
    } else {
        String win_path = "\\\\.\\pipe\\" + p_path.get_file();
        CharString wp = win_path.utf8();
        HANDLE h = CreateFileA(wp.get_data(), GENERIC_WRITE, 0, nullptr,
                               OPEN_EXISTING, 0, nullptr);
        if (h == INVALID_HANDLE_VALUE) {
            last_error = "Cannot open pipe: " + String::num(GetLastError());
            return false;
        }
        pipe_fd = (int)(intptr_t)h;
    }
#else
    int flags = read_mode ? O_RDONLY : O_WRONLY;
    pipe_fd = open(path_utf8.get_data(), flags);
    if (pipe_fd < 0) {
        last_error = String("open pipe failed: ") + strerror(errno);
        return false;
    }
#endif
    pipe_path = p_path;
    return true;
}

String VGIPC::read_pipe(int p_max_bytes) {
    if (pipe_fd < 0) { last_error = "Pipe not open"; return ""; }
    char *buf = (char *)memalloc(p_max_bytes + 1);
    if (!buf) return "";
    int n = 0;
#ifdef _WIN32
    DWORD bytes_read = 0;
    ReadFile((HANDLE)(intptr_t)pipe_fd, buf, p_max_bytes, &bytes_read, nullptr);
    n = (int)bytes_read;
#else
    n = (int)::read(pipe_fd, buf, p_max_bytes);
#endif
    if (n <= 0) { memfree(buf); return ""; }
    buf[n] = '\0';
    String result = String::utf8(buf, n);
    memfree(buf);
    return result;
}

PackedByteArray VGIPC::read_pipe_bytes(int p_max_bytes) {
    PackedByteArray result;
    if (pipe_fd < 0) return result;
    result.resize(p_max_bytes);
    int n = 0;
#ifdef _WIN32
    DWORD bytes_read = 0;
    ReadFile((HANDLE)(intptr_t)pipe_fd, result.ptrw(), p_max_bytes, &bytes_read, nullptr);
    n = (int)bytes_read;
#else
    n = (int)::read(pipe_fd, result.ptrw(), p_max_bytes);
#endif
    if (n > 0) result.resize(n); else result.resize(0);
    return result;
}

bool VGIPC::write_pipe(const String &p_data) {
    if (pipe_fd < 0) { last_error = "Pipe not open"; return false; }
    CharString utf8 = p_data.utf8();
#ifdef _WIN32
    DWORD written = 0;
    return WriteFile((HANDLE)(intptr_t)pipe_fd, utf8.get_data(), utf8.length(), &written, nullptr);
#else
    ssize_t w = ::write(pipe_fd, utf8.get_data(), utf8.length());
    return w >= 0;
#endif
}

bool VGIPC::write_pipe_bytes(const PackedByteArray &p_data) {
    if (pipe_fd < 0) { last_error = "Pipe not open"; return false; }
#ifdef _WIN32
    DWORD written = 0;
    return WriteFile((HANDLE)(intptr_t)pipe_fd, p_data.ptr(), p_data.size(), &written, nullptr);
#else
    ssize_t w = ::write(pipe_fd, p_data.ptr(), p_data.size());
    return w >= 0;
#endif
}

void VGIPC::close_pipe() {
    if (pipe_fd >= 0) {
#ifdef _WIN32
        CloseHandle((HANDLE)(intptr_t)pipe_fd);
#else
        ::close(pipe_fd);
#endif
        pipe_fd = -1;
    }
}

bool VGIPC::delete_named_pipe(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    return true;  // Windows named pipes are auto-cleaned
#else
    if (unlink(path_utf8.get_data()) == 0) return true;
    last_error = String("unlink failed: ") + strerror(errno);
    return false;
#endif
}

// ═══════════════════════════════════════════════════════════════════════════
// UNIX Domain Sockets
// ═══════════════════════════════════════════════════════════════════════════

bool VGIPC::create_domain_socket(const String &p_path) {
#ifdef _WIN32
    last_error = "UNIX domain sockets not available on Windows (use named pipes)";
    return false;
#else
    close_socket();
    CharString path_utf8 = p_path.utf8();

    domain_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (domain_fd < 0) {
        last_error = String("socket() failed: ") + strerror(errno);
        return false;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, path_utf8.get_data(), sizeof(addr.sun_path) - 1);

    unlink(path_utf8.get_data());
    if (::bind(domain_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        last_error = String("bind() failed: ") + strerror(errno);
        ::close(domain_fd); domain_fd = -1;
        return false;
    }
    if (::listen(domain_fd, 5) < 0) {
        last_error = String("listen() failed: ") + strerror(errno);
        ::close(domain_fd); domain_fd = -1;
        return false;
    }
    socket_path = p_path;
    return true;
#endif
}

bool VGIPC::connect_domain_socket(const String &p_path) {
#ifdef _WIN32
    last_error = "UNIX domain sockets not available on Windows";
    return false;
#else
    close_socket();
    CharString path_utf8 = p_path.utf8();

    client_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (client_fd < 0) {
        last_error = String("socket() failed: ") + strerror(errno);
        return false;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, path_utf8.get_data(), sizeof(addr.sun_path) - 1);

    if (::connect(client_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        last_error = String("connect() failed: ") + strerror(errno);
        ::close(client_fd); client_fd = -1;
        return false;
    }
    socket_path = p_path;
    return true;
#endif
}

bool VGIPC::accept_connection() {
#ifdef _WIN32
    return false;
#else
    if (domain_fd < 0) { last_error = "Socket not created"; return false; }
    client_fd = ::accept(domain_fd, nullptr, nullptr);
    if (client_fd < 0) {
        last_error = String("accept() failed: ") + strerror(errno);
        return false;
    }
    return true;
#endif
}

String VGIPC::read_socket(int p_max_bytes) {
    int fd = (client_fd >= 0) ? client_fd : domain_fd;
    if (fd < 0) { last_error = "Socket not open"; return ""; }
#ifdef _WIN32
    return "";
#else
    char *buf = (char *)memalloc(p_max_bytes + 1);
    if (!buf) return "";
    ssize_t n = recv(fd, buf, p_max_bytes, 0);
    if (n <= 0) { memfree(buf); return ""; }
    buf[n] = '\0';
    String result = String::utf8(buf, (int)n);
    memfree(buf);
    return result;
#endif
}

PackedByteArray VGIPC::read_socket_bytes(int p_max_bytes) {
    PackedByteArray result;
    int fd = (client_fd >= 0) ? client_fd : domain_fd;
    if (fd < 0) return result;
#ifndef _WIN32
    result.resize(p_max_bytes);
    ssize_t n = recv(fd, result.ptrw(), p_max_bytes, 0);
    if (n > 0) result.resize((int)n); else result.resize(0);
#endif
    return result;
}

bool VGIPC::write_socket(const String &p_data) {
    int fd = (client_fd >= 0) ? client_fd : domain_fd;
    if (fd < 0) { last_error = "Socket not open"; return false; }
#ifdef _WIN32
    return false;
#else
    CharString utf8 = p_data.utf8();
    return send(fd, utf8.get_data(), utf8.length(), 0) >= 0;
#endif
}

bool VGIPC::write_socket_bytes(const PackedByteArray &p_data) {
    int fd = (client_fd >= 0) ? client_fd : domain_fd;
    if (fd < 0) return false;
#ifdef _WIN32
    return false;
#else
    return send(fd, p_data.ptr(), p_data.size(), 0) >= 0;
#endif
}

void VGIPC::close_socket() {
#ifndef _WIN32
    if (client_fd >= 0) { ::close(client_fd); client_fd = -1; }
    if (domain_fd >= 0) {
        ::close(domain_fd);
        domain_fd = -1;
        if (!socket_path.is_empty()) {
            CharString sp = socket_path.utf8();
            unlink(sp.get_data());
        }
    }
#endif
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared Memory
// ═══════════════════════════════════════════════════════════════════════════

bool VGIPC::create_shared_memory(const String &p_name, int64_t p_size) {
    close_shared_memory();
    CharString name_utf8 = p_name.utf8();

#ifdef _WIN32
    shm_handle = CreateFileMappingA(INVALID_HANDLE_VALUE, nullptr,
        PAGE_READWRITE, 0, (DWORD)p_size, name_utf8.get_data());
    if (!shm_handle) {
        last_error = "CreateFileMapping failed: " + String::num(GetLastError());
        return false;
    }
    shm_ptr = MapViewOfFile(shm_handle, FILE_MAP_ALL_ACCESS, 0, 0, (SIZE_T)p_size);
    if (!shm_ptr) {
        last_error = "MapViewOfFile failed: " + String::num(GetLastError());
        CloseHandle(shm_handle); shm_handle = nullptr;
        return false;
    }
#else
    // Ensure name starts with /
    String shm_path = p_name.begins_with("/") ? p_name : String("/") + p_name;
    CharString sp = shm_path.utf8();

    shm_fd = shm_open(sp.get_data(), O_CREAT | O_RDWR, 0666);
    if (shm_fd < 0) {
        last_error = String("shm_open failed: ") + strerror(errno);
        return false;
    }
    if (ftruncate(shm_fd, (off_t)p_size) < 0) {
        last_error = String("ftruncate failed: ") + strerror(errno);
        ::close(shm_fd); shm_fd = -1;
        return false;
    }
    shm_ptr = mmap(nullptr, (size_t)p_size, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
    if (shm_ptr == MAP_FAILED) {
        last_error = String("mmap failed: ") + strerror(errno);
        ::close(shm_fd); shm_fd = -1;
        shm_ptr = nullptr;
        return false;
    }
#endif
    shm_size = p_size;
    shm_name = p_name;
    memset(shm_ptr, 0, (size_t)p_size);
    return true;
}

bool VGIPC::open_shared_memory(const String &p_name, int64_t p_size) {
    close_shared_memory();
    CharString name_utf8 = p_name.utf8();

#ifdef _WIN32
    shm_handle = OpenFileMappingA(FILE_MAP_ALL_ACCESS, FALSE, name_utf8.get_data());
    if (!shm_handle) {
        last_error = "OpenFileMapping failed: " + String::num(GetLastError());
        return false;
    }
    shm_ptr = MapViewOfFile(shm_handle, FILE_MAP_ALL_ACCESS, 0, 0, (SIZE_T)p_size);
    if (!shm_ptr) {
        last_error = "MapViewOfFile failed";
        CloseHandle(shm_handle); shm_handle = nullptr;
        return false;
    }
#else
    String shm_path = p_name.begins_with("/") ? p_name : String("/") + p_name;
    CharString sp = shm_path.utf8();

    shm_fd = shm_open(sp.get_data(), O_RDWR, 0666);
    if (shm_fd < 0) {
        last_error = String("shm_open failed: ") + strerror(errno);
        return false;
    }
    shm_ptr = mmap(nullptr, (size_t)p_size, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
    if (shm_ptr == MAP_FAILED) {
        last_error = String("mmap failed: ") + strerror(errno);
        ::close(shm_fd); shm_fd = -1;
        shm_ptr = nullptr;
        return false;
    }
#endif
    shm_size = p_size;
    shm_name = p_name;
    return true;
}

bool VGIPC::write_shared_memory(int64_t p_offset, const String &p_data) {
    if (!shm_ptr) { last_error = "Shared memory not open"; return false; }
    ERR_FAIL_COND_V_MSG(p_offset < 0, false, "VGIPC: negative offset in write_shared_memory");
    CharString utf8 = p_data.utf8();
    if (p_offset + utf8.length() > shm_size) { last_error = "Write exceeds shared memory size"; return false; }
    memcpy((uint8_t *)shm_ptr + p_offset, utf8.get_data(), utf8.length());
    return true;
}

bool VGIPC::write_shared_memory_bytes(int64_t p_offset, const PackedByteArray &p_data) {
    if (!shm_ptr) { last_error = "Shared memory not open"; return false; }
    ERR_FAIL_COND_V_MSG(p_offset < 0, false, "VGIPC: negative offset in write_shared_memory_bytes");
    if (p_offset + p_data.size() > shm_size) { last_error = "Write exceeds shared memory size"; return false; }
    memcpy((uint8_t *)shm_ptr + p_offset, p_data.ptr(), p_data.size());
    return true;
}

String VGIPC::read_shared_memory(int64_t p_offset, int64_t p_length) {
    ERR_FAIL_COND_V(p_offset < 0 || p_length < 0, "");
    if (!shm_ptr || p_offset + p_length > shm_size) return "";
    return String::utf8((const char *)((uint8_t *)shm_ptr + p_offset), (int)p_length);
}

PackedByteArray VGIPC::read_shared_memory_bytes(int64_t p_offset, int64_t p_length) {
    PackedByteArray result;
    ERR_FAIL_COND_V(p_offset < 0 || p_length < 0, result);
    if (!shm_ptr || p_offset + p_length > shm_size) return result;
    result.resize(p_length);
    memcpy(result.ptrw(), (uint8_t *)shm_ptr + p_offset, (size_t)p_length);
    return result;
}

void VGIPC::close_shared_memory() {
    if (shm_ptr) {
#ifdef _WIN32
        UnmapViewOfFile(shm_ptr);
        if (shm_handle) { CloseHandle(shm_handle); shm_handle = nullptr; }
#else
        munmap(shm_ptr, (size_t)shm_size);
        if (shm_fd >= 0) {
            ::close(shm_fd);
            shm_fd = -1;
        }
        // Unlink the shm segment
        if (!shm_name.is_empty()) {
            String shm_path = shm_name.begins_with("/") ? shm_name : String("/") + shm_name;
            CharString sp = shm_path.utf8();
            shm_unlink(sp.get_data());
        }
#endif
        shm_ptr = nullptr;
        shm_size = 0;
    }
}

// ─── Godot Bindings ────────────────────────────────────────────────────────

void VGIPC::_bind_methods() {
    // Named Pipes
    ClassDB::bind_method(D_METHOD("CreateNamedPipe", "path"),        &VGIPC::create_named_pipe);
    ClassDB::bind_method(D_METHOD("OpenPipe", "path", "mode"),       &VGIPC::open_pipe);
    ClassDB::bind_method(D_METHOD("ReadPipe", "max_bytes"),          &VGIPC::read_pipe);
    ClassDB::bind_method(D_METHOD("ReadPipeBytes", "max_bytes"),     &VGIPC::read_pipe_bytes);
    ClassDB::bind_method(D_METHOD("WritePipe", "data"),              &VGIPC::write_pipe);
    ClassDB::bind_method(D_METHOD("WritePipeBytes", "data"),         &VGIPC::write_pipe_bytes);
    ClassDB::bind_method(D_METHOD("ClosePipe"),                      &VGIPC::close_pipe);
    ClassDB::bind_method(D_METHOD("DeleteNamedPipe", "path"),        &VGIPC::delete_named_pipe);

    // Domain Sockets
    ClassDB::bind_method(D_METHOD("CreateDomainSocket", "path"),     &VGIPC::create_domain_socket);
    ClassDB::bind_method(D_METHOD("ConnectDomainSocket", "path"),    &VGIPC::connect_domain_socket);
    ClassDB::bind_method(D_METHOD("AcceptConnection"),               &VGIPC::accept_connection);
    ClassDB::bind_method(D_METHOD("ReadSocket", "max_bytes"),        &VGIPC::read_socket);
    ClassDB::bind_method(D_METHOD("ReadSocketBytes", "max_bytes"),   &VGIPC::read_socket_bytes);
    ClassDB::bind_method(D_METHOD("WriteSocket", "data"),            &VGIPC::write_socket);
    ClassDB::bind_method(D_METHOD("WriteSocketBytes", "data"),       &VGIPC::write_socket_bytes);
    ClassDB::bind_method(D_METHOD("CloseSocket"),                    &VGIPC::close_socket);

    // Shared Memory
    ClassDB::bind_method(D_METHOD("CreateSharedMemory", "name", "size"),   &VGIPC::create_shared_memory);
    ClassDB::bind_method(D_METHOD("OpenSharedMemory", "name", "size"),     &VGIPC::open_shared_memory);
    ClassDB::bind_method(D_METHOD("WriteSharedMemory", "offset", "data"),  &VGIPC::write_shared_memory);
    ClassDB::bind_method(D_METHOD("WriteSharedMemoryBytes", "offset", "data"), &VGIPC::write_shared_memory_bytes);
    ClassDB::bind_method(D_METHOD("ReadSharedMemory", "offset", "length"), &VGIPC::read_shared_memory);
    ClassDB::bind_method(D_METHOD("ReadSharedMemoryBytes", "offset", "length"), &VGIPC::read_shared_memory_bytes);
    ClassDB::bind_method(D_METHOD("CloseSharedMemory"),                    &VGIPC::close_shared_memory);

    // Status
    ClassDB::bind_method(D_METHOD("get_pipe_is_open"),   &VGIPC::get_pipe_is_open);
    ClassDB::bind_method(D_METHOD("get_socket_is_open"), &VGIPC::get_socket_is_open);
    ClassDB::bind_method(D_METHOD("get_shm_is_open"),    &VGIPC::get_shm_is_open);
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "PipeIsOpen"),   "", "get_pipe_is_open");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "SocketIsOpen"), "", "get_socket_is_open");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "ShmIsOpen"),    "", "get_shm_is_open");

    ClassDB::bind_method(D_METHOD("get_last_error"), &VGIPC::get_last_error);
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "LastError"), "", "get_last_error");
}
