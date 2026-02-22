#ifndef VISUAL_GASIC_IPC_H
#define VISUAL_GASIC_IPC_H

// VGIPC — Inter-Process Communication
// Named pipes, UNIX domain sockets, shared memory
//
// Usage in VisualGasic:
//   ' Named pipe (FIFO)
//   Dim ipc As New VGIPC
//   ipc.CreateNamedPipe "/tmp/mypipe"
//   ipc.OpenPipe "/tmp/mypipe", "write"
//   ipc.WritePipe "Hello from VG!"
//   ipc.ClosePipe
//
//   ' UNIX domain socket
//   ipc.CreateDomainSocket "/tmp/myapp.sock"
//   ipc.AcceptConnection   ' blocking
//   Dim msg As String = ipc.ReadSocket()
//   ipc.WriteSocket "ACK"
//   ipc.CloseSocket
//
//   ' Shared memory
//   ipc.CreateSharedMemory "my_region", 4096
//   ipc.WriteSharedMemory 0, "hello"
//   Print ipc.ReadSharedMemory(0, 5)
//   ipc.CloseSharedMemory

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

class VGIPC : public RefCounted {
    GDCLASS(VGIPC, RefCounted);

    // Named pipe state
    int pipe_fd;
    String pipe_path;

    // Domain socket state
    int domain_fd;
    int client_fd;
    String socket_path;

    // Shared memory state
    void *shm_ptr;
    int64_t shm_size;
    String shm_name;
#ifdef _WIN32
    void *shm_handle;
#else
    int shm_fd;
#endif

    String last_error;

protected:
    static void _bind_methods();

public:
    VGIPC();
    ~VGIPC();

    // --- Named Pipes (FIFO on Unix, Named Pipe on Windows) ---
    bool create_named_pipe(const String &p_path);
    bool open_pipe(const String &p_path, const String &p_mode);  // "read" or "write"
    String read_pipe(int p_max_bytes = 4096);
    PackedByteArray read_pipe_bytes(int p_max_bytes = 4096);
    bool write_pipe(const String &p_data);
    bool write_pipe_bytes(const PackedByteArray &p_data);
    void close_pipe();
    bool delete_named_pipe(const String &p_path);

    // --- UNIX Domain Sockets ---
    bool create_domain_socket(const String &p_path);
    bool connect_domain_socket(const String &p_path);
    bool accept_connection();
    String read_socket(int p_max_bytes = 4096);
    PackedByteArray read_socket_bytes(int p_max_bytes = 4096);
    bool write_socket(const String &p_data);
    bool write_socket_bytes(const PackedByteArray &p_data);
    void close_socket();

    // --- Shared Memory ---
    bool create_shared_memory(const String &p_name, int64_t p_size);
    bool open_shared_memory(const String &p_name, int64_t p_size);
    bool write_shared_memory(int64_t p_offset, const String &p_data);
    bool write_shared_memory_bytes(int64_t p_offset, const PackedByteArray &p_data);
    String read_shared_memory(int64_t p_offset, int64_t p_length);
    PackedByteArray read_shared_memory_bytes(int64_t p_offset, int64_t p_length);
    void close_shared_memory();

    // --- Status ---
    bool get_pipe_is_open() const { return pipe_fd >= 0; }
    bool get_socket_is_open() const { return domain_fd >= 0; }
    bool get_shm_is_open() const { return shm_ptr != nullptr; }
    String get_last_error() const { return last_error; }
};

#endif // VISUAL_GASIC_IPC_H
