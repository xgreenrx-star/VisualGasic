#ifndef VISUAL_GASIC_SOCKET_H
#define VISUAL_GASIC_SOCKET_H

// VGSocket — VB6 WinSock-style TCP/UDP socket
// Usage in VisualGasic:
//   ' TCP Client
//   Dim sock As New WinSock
//   sock.Protocol = sckTCPProtocol
//   sock.Connect "example.com", 80
//   sock.Send "GET / HTTP/1.0" & vbCrLf & vbCrLf
//   Dim response As String
//   response = sock.Receive(4096)
//   sock.Close
//
//   ' TCP Server
//   Dim server As New WinSock
//   server.Protocol = sckTCPProtocol
//   server.Bind 8080
//   server.Listen 5
//   Dim client As Variant
//   client = server.Accept()
//
//   ' UDP
//   Dim udp As New WinSock
//   udp.Protocol = sckUDPProtocol
//   udp.Bind 9999
//   udp.SendTo "Hello", "192.168.1.1", 9999

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

using namespace godot;

class VGSocket : public RefCounted {
    GDCLASS(VGSocket, RefCounted);

    // Socket state
    int sock_fd;
    int protocol;  // 0 = TCP, 1 = UDP
    String remote_host;
    int remote_port;
    int local_port;
    bool connected;
    bool listening;
    bool bound;
    String last_error;

    // Buffer for received data
    PackedByteArray recv_buffer;

    // Internal helpers
    bool set_nonblocking(int fd, bool nonblock);

protected:
    static void _bind_methods();

public:
    VGSocket();
    ~VGSocket();

    // Protocol constants (VB6 WinSock style)
    enum Protocol {
        SCK_TCP = 0,
        SCK_UDP = 1
    };

    // Connection
    bool connect_to(const String &p_host, int p_port);
    void close_socket();
    bool bind_port(int p_port, const String &p_address = "0.0.0.0");
    bool listen_start(int p_backlog = 5);
    Variant accept_connection();  // Returns new VGSocket or null

    // Data transfer
    int send_data(const String &p_data);
    int send_bytes(const PackedByteArray &p_data);
    String receive(int p_max_bytes = 4096);
    PackedByteArray receive_bytes(int p_max_bytes = 4096);

    // UDP specific
    int send_to(const String &p_data, const String &p_host, int p_port);
    Dictionary receive_from(int p_max_bytes = 4096);  // Returns {"data": String, "host": String, "port": int}

    // Properties
    void set_protocol(int p_proto) { protocol = p_proto; }
    int get_protocol() const { return protocol; }
    String get_remote_host() const { return remote_host; }
    int get_remote_port() const { return remote_port; }
    int get_local_port() const { return local_port; }
    bool get_is_connected() const { return connected; }
    bool get_is_listening() const { return listening; }
    String get_last_error() const { return last_error; }

    // Utility
    static String resolve_host(const String &p_hostname);
    int get_bytes_available();
    bool set_option(const String &p_option, const Variant &p_value);
};

VARIANT_ENUM_CAST(VGSocket::Protocol);

#endif // VISUAL_GASIC_SOCKET_H
