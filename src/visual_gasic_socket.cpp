// VGSocket — VB6 WinSock-style TCP/UDP raw socket wrapper
// Full POSIX implementation

#include "visual_gasic_socket.h"
#include <godot_cpp/variant/utility_functions.hpp>

#if defined(__linux__) || defined(__APPLE__)
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <poll.h>
#include <sys/ioctl.h>
#elif defined(_WIN32)
#include <winsock2.h>
#include <ws2tcpip.h>
#pragma comment(lib, "Ws2_32.lib")
#endif

using namespace godot;

#ifdef _WIN32
namespace {
    struct WinsockInit {
        WinsockInit() {
            WSADATA wsa;
            WSAStartup(MAKEWORD(2, 2), &wsa);
        }
        ~WinsockInit() { WSACleanup(); }
    };
    static WinsockInit s_winsock_init;
}
#endif

void VGSocket::_bind_methods() {
    ClassDB::bind_method(D_METHOD("connect_to", "host", "port"), &VGSocket::connect_to);
    ClassDB::bind_method(D_METHOD("close_socket"), &VGSocket::close_socket);
    ClassDB::bind_method(D_METHOD("bind_port", "port", "address"), &VGSocket::bind_port, DEFVAL("0.0.0.0"));
    ClassDB::bind_method(D_METHOD("listen_start", "backlog"), &VGSocket::listen_start, DEFVAL(5));
    ClassDB::bind_method(D_METHOD("accept_connection"), &VGSocket::accept_connection);
    ClassDB::bind_method(D_METHOD("send_data", "data"), &VGSocket::send_data);
    ClassDB::bind_method(D_METHOD("send_bytes", "data"), &VGSocket::send_bytes);
    ClassDB::bind_method(D_METHOD("receive", "max_bytes"), &VGSocket::receive, DEFVAL(4096));
    ClassDB::bind_method(D_METHOD("receive_bytes", "max_bytes"), &VGSocket::receive_bytes, DEFVAL(4096));
    ClassDB::bind_method(D_METHOD("send_to", "data", "host", "port"), &VGSocket::send_to);
    ClassDB::bind_method(D_METHOD("receive_from", "max_bytes"), &VGSocket::receive_from, DEFVAL(4096));
    ClassDB::bind_method(D_METHOD("set_protocol", "protocol"), &VGSocket::set_protocol);
    ClassDB::bind_method(D_METHOD("get_protocol"), &VGSocket::get_protocol);
    ClassDB::bind_method(D_METHOD("get_remote_host"), &VGSocket::get_remote_host);
    ClassDB::bind_method(D_METHOD("get_remote_port"), &VGSocket::get_remote_port);
    ClassDB::bind_method(D_METHOD("get_local_port"), &VGSocket::get_local_port);
    ClassDB::bind_method(D_METHOD("get_is_connected"), &VGSocket::get_is_connected);
    ClassDB::bind_method(D_METHOD("get_is_listening"), &VGSocket::get_is_listening);
    ClassDB::bind_method(D_METHOD("get_last_error"), &VGSocket::get_last_error);
    ClassDB::bind_static_method("VGSocket", D_METHOD("resolve_host", "hostname"), &VGSocket::resolve_host);
    ClassDB::bind_method(D_METHOD("get_bytes_available"), &VGSocket::get_bytes_available);
    ClassDB::bind_method(D_METHOD("set_option", "option", "value"), &VGSocket::set_option);

    // VB6-style aliases (WinSock-compatible names)
    ClassDB::bind_method(D_METHOD("Connect", "host", "port"), &VGSocket::connect_to);
    ClassDB::bind_method(D_METHOD("Close"), &VGSocket::close_socket);
    ClassDB::bind_method(D_METHOD("Bind", "port", "address"), &VGSocket::bind_port, DEFVAL("0.0.0.0"));
    ClassDB::bind_method(D_METHOD("Listen", "backlog"), &VGSocket::listen_start, DEFVAL(5));
    ClassDB::bind_method(D_METHOD("Accept"), &VGSocket::accept_connection);
    ClassDB::bind_method(D_METHOD("Send", "data"), &VGSocket::send_data);
    ClassDB::bind_method(D_METHOD("SendData", "data"), &VGSocket::send_data);
    ClassDB::bind_method(D_METHOD("GetData", "max_bytes"), &VGSocket::receive, DEFVAL(4096));
    ClassDB::bind_method(D_METHOD("Receive", "max_bytes"), &VGSocket::receive, DEFVAL(4096));
    ClassDB::bind_method(D_METHOD("SendTo", "data", "host", "port"), &VGSocket::send_to);

    ADD_PROPERTY(PropertyInfo(Variant::INT, "Protocol"), "set_protocol", "get_protocol");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "RemoteHost"), "", "get_remote_host");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "RemotePort"), "", "get_remote_port");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "LocalPort"), "", "get_local_port");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "Connected"), "", "get_is_connected");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "Listening"), "", "get_is_listening");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "LastError"), "", "get_last_error");

    BIND_ENUM_CONSTANT(SCK_TCP);
    BIND_ENUM_CONSTANT(SCK_UDP);
}

VGSocket::VGSocket() {
    sock_fd = -1;
    protocol = SCK_TCP;
    remote_port = 0;
    local_port = 0;
    connected = false;
    listening = false;
    bound = false;
}

VGSocket::~VGSocket() {
    close_socket();
}

bool VGSocket::set_nonblocking(int fd, bool nonblock) {
#if defined(__linux__) || defined(__APPLE__)
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) return false;
    if (nonblock) {
        return fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0;
    } else {
        return fcntl(fd, F_SETFL, flags & ~O_NONBLOCK) >= 0;
    }
#elif defined(_WIN32)
    u_long mode = nonblock ? 1 : 0;
    return ioctlsocket((SOCKET)fd, FIONBIO, &mode) == 0;
#else
    return false;
#endif
}

bool VGSocket::connect_to(const String &p_host, int p_port) {
#if defined(__linux__) || defined(__APPLE__)
    close_socket();

    int type = (protocol == SCK_TCP) ? SOCK_STREAM : SOCK_DGRAM;
    sock_fd = socket(AF_INET, type, 0);
    if (sock_fd < 0) {
        last_error = String("socket() failed: ") + strerror(errno);
        return false;
    }

    // Resolve hostname
    struct addrinfo hints = {}, *res = nullptr;
    hints.ai_family = AF_INET;
    hints.ai_socktype = type;
    CharString host_utf8 = p_host.utf8();
    CharString port_str = String::num_int64(p_port).utf8();

    int rc = getaddrinfo(host_utf8.get_data(), port_str.get_data(), &hints, &res);
    if (rc != 0 || !res) {
        last_error = String("DNS resolution failed for '") + p_host + "': " + gai_strerror(rc);
        ::close(sock_fd);
        sock_fd = -1;
        return false;
    }

    if (::connect(sock_fd, res->ai_addr, res->ai_addrlen) < 0) {
        last_error = String("connect() failed: ") + strerror(errno);
        freeaddrinfo(res);
        ::close(sock_fd);
        sock_fd = -1;
        return false;
    }

    freeaddrinfo(res);
    remote_host = p_host;
    remote_port = p_port;
    connected = true;

    UtilityFunctions::print("[VGSocket] Connected to ", p_host, ":", p_port);
    return true;
#elif defined(_WIN32)
    close_socket();

    int type = (protocol == SCK_TCP) ? SOCK_STREAM : SOCK_DGRAM;
    sock_fd = (int)socket(AF_INET, type, 0);
    if (sock_fd == (int)INVALID_SOCKET) {
        last_error = String("socket() failed, WSA error: ") + String::num_int64(WSAGetLastError());
        sock_fd = -1;
        return false;
    }

    struct addrinfo hints = {}, *res = nullptr;
    hints.ai_family = AF_INET;
    hints.ai_socktype = type;
    CharString host_utf8 = p_host.utf8();
    CharString port_str = String::num_int64(p_port).utf8();

    int rc = getaddrinfo(host_utf8.get_data(), port_str.get_data(), &hints, &res);
    if (rc != 0 || !res) {
        last_error = String("DNS resolution failed for '") + p_host + "'";
        closesocket((SOCKET)sock_fd);
        sock_fd = -1;
        return false;
    }

    if (::connect((SOCKET)sock_fd, res->ai_addr, (int)res->ai_addrlen) == SOCKET_ERROR) {
        last_error = String("connect() failed, WSA error: ") + String::num_int64(WSAGetLastError());
        freeaddrinfo(res);
        closesocket((SOCKET)sock_fd);
        sock_fd = -1;
        return false;
    }

    freeaddrinfo(res);
    remote_host = p_host;
    remote_port = p_port;
    connected = true;

    UtilityFunctions::print("[VGSocket] Connected to ", p_host, ":", p_port);
    return true;
#else
    last_error = "Not implemented on this platform";
    return false;
#endif
}

void VGSocket::close_socket() {
#if defined(__linux__) || defined(__APPLE__)
    if (sock_fd >= 0) {
        ::close(sock_fd);
        sock_fd = -1;
    }
#elif defined(_WIN32)
    if (sock_fd >= 0) {
        closesocket((SOCKET)sock_fd);
        sock_fd = -1;
    }
#endif
    connected = false;
    listening = false;
    bound = false;
}

bool VGSocket::bind_port(int p_port, const String &p_address) {
#if defined(__linux__) || defined(__APPLE__)
    if (sock_fd >= 0) close_socket();

    int type = (protocol == SCK_TCP) ? SOCK_STREAM : SOCK_DGRAM;
    sock_fd = socket(AF_INET, type, 0);
    if (sock_fd < 0) {
        last_error = String("socket() failed: ") + strerror(errno);
        return false;
    }

    // Allow port reuse
    int opt = 1;
    setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(p_port);

    CharString addr_utf8 = p_address.utf8();
    if (inet_pton(AF_INET, addr_utf8.get_data(), &addr.sin_addr) <= 0) {
        addr.sin_addr.s_addr = INADDR_ANY;
    }

    if (::bind(sock_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        last_error = String("bind() failed: ") + strerror(errno);
        ::close(sock_fd);
        sock_fd = -1;
        return false;
    }

    local_port = p_port;
    bound = true;
    UtilityFunctions::print("[VGSocket] Bound to port ", p_port);
    return true;
#elif defined(_WIN32)
    if (sock_fd >= 0) close_socket();

    int type = (protocol == SCK_TCP) ? SOCK_STREAM : SOCK_DGRAM;
    sock_fd = (int)socket(AF_INET, type, 0);
    if (sock_fd == (int)INVALID_SOCKET) {
        last_error = String("socket() failed, WSA error: ") + String::num_int64(WSAGetLastError());
        sock_fd = -1;
        return false;
    }

    int opt = 1;
    setsockopt((SOCKET)sock_fd, SOL_SOCKET, SO_REUSEADDR, (const char *)&opt, sizeof(opt));

    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(p_port);

    CharString addr_utf8 = p_address.utf8();
    if (inet_pton(AF_INET, addr_utf8.get_data(), &addr.sin_addr) <= 0) {
        addr.sin_addr.s_addr = INADDR_ANY;
    }

    if (::bind((SOCKET)sock_fd, (struct sockaddr *)&addr, sizeof(addr)) == SOCKET_ERROR) {
        last_error = String("bind() failed, WSA error: ") + String::num_int64(WSAGetLastError());
        closesocket((SOCKET)sock_fd);
        sock_fd = -1;
        return false;
    }

    local_port = p_port;
    bound = true;
    UtilityFunctions::print("[VGSocket] Bound to port ", p_port);
    return true;
#else
    last_error = "Not implemented";
    return false;
#endif
}

bool VGSocket::listen_start(int p_backlog) {
#if defined(__linux__) || defined(__APPLE__)
    if (sock_fd < 0 || !bound) {
        last_error = "Socket not bound";
        return false;
    }
    if (protocol != SCK_TCP) {
        last_error = "Listen only available for TCP";
        return false;
    }

    if (::listen(sock_fd, p_backlog) < 0) {
        last_error = String("listen() failed: ") + strerror(errno);
        return false;
    }

    listening = true;
    UtilityFunctions::print("[VGSocket] Listening on port ", local_port);
    return true;
#elif defined(_WIN32)
    if (sock_fd < 0 || !bound) {
        last_error = "Socket not bound";
        return false;
    }
    if (protocol != SCK_TCP) {
        last_error = "Listen only available for TCP";
        return false;
    }

    if (::listen((SOCKET)sock_fd, p_backlog) == SOCKET_ERROR) {
        last_error = String("listen() failed, WSA error: ") + String::num_int64(WSAGetLastError());
        return false;
    }

    listening = true;
    UtilityFunctions::print("[VGSocket] Listening on port ", local_port);
    return true;
#else
    last_error = "Not implemented";
    return false;
#endif
}

Variant VGSocket::accept_connection() {
#if defined(__linux__) || defined(__APPLE__)
    if (sock_fd < 0 || !listening) return Variant();

    struct sockaddr_in client_addr = {};
    socklen_t client_len = sizeof(client_addr);
    int client_fd = ::accept(sock_fd, (struct sockaddr *)&client_addr, &client_len);
    if (client_fd < 0) {
        if (errno != EAGAIN && errno != EWOULDBLOCK) {
            last_error = String("accept() failed: ") + strerror(errno);
        }
        return Variant();
    }

    // Create new VGSocket for the client
    Ref<VGSocket> client = memnew(VGSocket);
    client->sock_fd = client_fd;
    client->connected = true;
    client->protocol = SCK_TCP;
    client->remote_host = String::utf8(inet_ntoa(client_addr.sin_addr));
    client->remote_port = ntohs(client_addr.sin_port);

    UtilityFunctions::print("[VGSocket] Accepted connection from ", client->remote_host, ":", client->remote_port);
    return Variant(client);
#elif defined(_WIN32)
    if (sock_fd < 0 || !listening) return Variant();

    struct sockaddr_in client_addr = {};
    int client_len = sizeof(client_addr);
    SOCKET client_fd = ::accept((SOCKET)sock_fd, (struct sockaddr *)&client_addr, &client_len);
    if (client_fd == INVALID_SOCKET) {
        int err = WSAGetLastError();
        if (err != WSAEWOULDBLOCK) {
            last_error = String("accept() failed, WSA error: ") + String::num_int64(err);
        }
        return Variant();
    }

    Ref<VGSocket> client = memnew(VGSocket);
    client->sock_fd = (int)client_fd;
    client->connected = true;
    client->protocol = SCK_TCP;
    char addr_buf[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &client_addr.sin_addr, addr_buf, sizeof(addr_buf));
    client->remote_host = String::utf8(addr_buf);
    client->remote_port = ntohs(client_addr.sin_port);

    UtilityFunctions::print("[VGSocket] Accepted connection from ", client->remote_host, ":", client->remote_port);
    return Variant(client);
#else
    return Variant();
#endif
}

int VGSocket::send_data(const String &p_data) {
#if defined(__linux__) || defined(__APPLE__)
    if (sock_fd < 0 || !connected) {
        last_error = "Not connected";
        return -1;
    }
    CharString utf8 = p_data.utf8();
    int sent = ::send(sock_fd, utf8.get_data(), utf8.length(), MSG_NOSIGNAL);
    if (sent < 0) {
        last_error = String("send() failed: ") + strerror(errno);
    }
    return sent;
#elif defined(_WIN32)
    if (sock_fd < 0 || !connected) {
        last_error = "Not connected";
        return -1;
    }
    CharString utf8 = p_data.utf8();
    int sent = ::send((SOCKET)sock_fd, utf8.get_data(), utf8.length(), 0);
    if (sent == SOCKET_ERROR) {
        last_error = String("send() failed, WSA error: ") + String::num_int64(WSAGetLastError());
        return -1;
    }
    return sent;
#else
    return -1;
#endif
}

int VGSocket::send_bytes(const PackedByteArray &p_data) {
#if defined(__linux__) || defined(__APPLE__)
    if (sock_fd < 0 || !connected) {
        last_error = "Not connected";
        return -1;
    }
    int sent = ::send(sock_fd, p_data.ptr(), p_data.size(), MSG_NOSIGNAL);
    if (sent < 0) {
        last_error = String("send() failed: ") + strerror(errno);
    }
    return sent;
#elif defined(_WIN32)
    if (sock_fd < 0 || !connected) {
        last_error = "Not connected";
        return -1;
    }
    int sent = ::send((SOCKET)sock_fd, (const char *)p_data.ptr(), p_data.size(), 0);
    if (sent == SOCKET_ERROR) {
        last_error = String("send() failed, WSA error: ") + String::num_int64(WSAGetLastError());
        return -1;
    }
    return sent;
#else
    return -1;
#endif
}

String VGSocket::receive(int p_max_bytes) {
#if defined(__linux__) || defined(__APPLE__)
    if (sock_fd < 0) return "";
    char *buf = (char *)memalloc(p_max_bytes + 1);
    if (!buf) return "";
    int n = ::recv(sock_fd, buf, p_max_bytes, 0);
    String result;
    if (n > 0) {
        buf[n] = '\0';
        result = String::utf8(buf, n);
    } else if (n == 0) {
        connected = false; // Peer closed
    } else {
        if (errno != EAGAIN && errno != EWOULDBLOCK) {
            last_error = String("recv() failed: ") + strerror(errno);
        }
    }
    memfree(buf);
    return result;
#elif defined(_WIN32)
    if (sock_fd < 0) return "";
    char *buf = (char *)memalloc(p_max_bytes + 1);
    if (!buf) return "";
    int n = ::recv((SOCKET)sock_fd, buf, p_max_bytes, 0);
    String result;
    if (n > 0) {
        buf[n] = '\0';
        result = String::utf8(buf, n);
    } else if (n == 0) {
        connected = false;
    } else {
        int err = WSAGetLastError();
        if (err != WSAEWOULDBLOCK) {
            last_error = String("recv() failed, WSA error: ") + String::num_int64(err);
        }
    }
    memfree(buf);
    return result;
#else
    return "";
#endif
}

PackedByteArray VGSocket::receive_bytes(int p_max_bytes) {
    PackedByteArray result;
#if defined(__linux__) || defined(__APPLE__)
    if (sock_fd < 0) return result;
    result.resize(p_max_bytes);
    int n = ::recv(sock_fd, result.ptrw(), p_max_bytes, 0);
    if (n > 0) {
        result.resize(n);
    } else {
        result.resize(0);
        if (n == 0) connected = false;
    }
#elif defined(_WIN32)
    if (sock_fd < 0) return result;
    result.resize(p_max_bytes);
    int n = ::recv((SOCKET)sock_fd, (char *)result.ptrw(), p_max_bytes, 0);
    if (n > 0) {
        result.resize(n);
    } else {
        result.resize(0);
        if (n == 0) connected = false;
    }
#endif
    return result;
}

int VGSocket::send_to(const String &p_data, const String &p_host, int p_port) {
#if defined(__linux__) || defined(__APPLE__)
    if (sock_fd < 0) {
        // Auto-create UDP socket if needed
        sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
        if (sock_fd < 0) {
            last_error = String("socket() failed: ") + strerror(errno);
            return -1;
        }
    }

    struct sockaddr_in dest = {};
    dest.sin_family = AF_INET;
    dest.sin_port = htons(p_port);
    CharString host_utf8 = p_host.utf8();
    if (inet_pton(AF_INET, host_utf8.get_data(), &dest.sin_addr) <= 0) {
        // Try DNS resolution
        struct hostent *he = gethostbyname(host_utf8.get_data());
        if (!he) {
            last_error = "DNS resolution failed for " + p_host;
            return -1;
        }
        dest.sin_addr = *(struct in_addr *)he->h_addr;
    }

    CharString utf8 = p_data.utf8();
    int sent = ::sendto(sock_fd, utf8.get_data(), utf8.length(), 0,
                        (struct sockaddr *)&dest, sizeof(dest));
    if (sent < 0) {
        last_error = String("sendto() failed: ") + strerror(errno);
    }
    return sent;
#elif defined(_WIN32)
    if (sock_fd < 0) {
        sock_fd = (int)socket(AF_INET, SOCK_DGRAM, 0);
        if (sock_fd == (int)INVALID_SOCKET) {
            last_error = String("socket() failed, WSA error: ") + String::num_int64(WSAGetLastError());
            sock_fd = -1;
            return -1;
        }
    }

    struct sockaddr_in dest = {};
    dest.sin_family = AF_INET;
    dest.sin_port = htons(p_port);
    CharString host_utf8 = p_host.utf8();
    if (inet_pton(AF_INET, host_utf8.get_data(), &dest.sin_addr) <= 0) {
        struct hostent *he = gethostbyname(host_utf8.get_data());
        if (!he) {
            last_error = "DNS resolution failed for " + p_host;
            return -1;
        }
        dest.sin_addr = *(struct in_addr *)he->h_addr;
    }

    CharString utf8 = p_data.utf8();
    int sent = ::sendto((SOCKET)sock_fd, utf8.get_data(), utf8.length(), 0,
                        (struct sockaddr *)&dest, sizeof(dest));
    if (sent == SOCKET_ERROR) {
        last_error = String("sendto() failed, WSA error: ") + String::num_int64(WSAGetLastError());
        return -1;
    }
    return sent;
#else
    return -1;
#endif
}

Dictionary VGSocket::receive_from(int p_max_bytes) {
    Dictionary result;
#if defined(__linux__) || defined(__APPLE__)
    if (sock_fd < 0) {
        result["data"] = "";
        result["host"] = "";
        result["port"] = 0;
        return result;
    }

    char *buf = (char *)memalloc(p_max_bytes + 1);
    struct sockaddr_in sender = {};
    socklen_t sender_len = sizeof(sender);

    int n = ::recvfrom(sock_fd, buf, p_max_bytes, 0,
                       (struct sockaddr *)&sender, &sender_len);
    if (n > 0) {
        buf[n] = '\0';
        result["data"] = String::utf8(buf, n);
        result["host"] = String::utf8(inet_ntoa(sender.sin_addr));
        result["port"] = (int)ntohs(sender.sin_port);
    } else {
        result["data"] = "";
        result["host"] = "";
        result["port"] = 0;
    }
    memfree(buf);
#elif defined(_WIN32)
    if (sock_fd < 0) {
        result["data"] = "";
        result["host"] = "";
        result["port"] = 0;
        return result;
    }

    char *buf = (char *)memalloc(p_max_bytes + 1);
    struct sockaddr_in sender = {};
    int sender_len = sizeof(sender);

    int n = ::recvfrom((SOCKET)sock_fd, buf, p_max_bytes, 0,
                       (struct sockaddr *)&sender, &sender_len);
    if (n > 0) {
        buf[n] = '\0';
        result["data"] = String::utf8(buf, n);
        char addr_buf[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &sender.sin_addr, addr_buf, sizeof(addr_buf));
        result["host"] = String::utf8(addr_buf);
        result["port"] = (int)ntohs(sender.sin_port);
    } else {
        result["data"] = "";
        result["host"] = "";
        result["port"] = 0;
    }
    memfree(buf);
#else
    result["data"] = "";
    result["host"] = "";
    result["port"] = 0;
#endif
    return result;
}

String VGSocket::resolve_host(const String &p_hostname) {
#if defined(__linux__) || defined(__APPLE__)
    CharString utf8 = p_hostname.utf8();
    struct hostent *he = gethostbyname(utf8.get_data());
    if (he && he->h_addr) {
        return String::utf8(inet_ntoa(*(struct in_addr *)he->h_addr));
    }
#elif defined(_WIN32)
    CharString utf8 = p_hostname.utf8();
    struct hostent *he = gethostbyname(utf8.get_data());
    if (he && he->h_addr) {
        char addr_buf[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, he->h_addr, addr_buf, sizeof(addr_buf));
        return String::utf8(addr_buf);
    }
#endif
    return "";
}

int VGSocket::get_bytes_available() {
#if defined(__linux__) || defined(__APPLE__)
    if (sock_fd < 0) return 0;
    int available = 0;
    ioctl(sock_fd, FIONREAD, &available);
    return available;
#elif defined(_WIN32)
    if (sock_fd < 0) return 0;
    u_long available = 0;
    ioctlsocket((SOCKET)sock_fd, FIONREAD, &available);
    return (int)available;
#else
    return 0;
#endif
}

bool VGSocket::set_option(const String &p_option, const Variant &p_value) {
#if defined(__linux__) || defined(__APPLE__)
    if (sock_fd < 0) return false;

    if (p_option.nocasecmp_to("NoDelay") == 0) {
        int val = (bool)p_value ? 1 : 0;
        return setsockopt(sock_fd, IPPROTO_TCP, TCP_NODELAY, &val, sizeof(val)) == 0;
    }
    if (p_option.nocasecmp_to("ReuseAddr") == 0) {
        int val = (bool)p_value ? 1 : 0;
        return setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, &val, sizeof(val)) == 0;
    }
    if (p_option.nocasecmp_to("KeepAlive") == 0) {
        int val = (bool)p_value ? 1 : 0;
        return setsockopt(sock_fd, SOL_SOCKET, SO_KEEPALIVE, &val, sizeof(val)) == 0;
    }
    if (p_option.nocasecmp_to("Broadcast") == 0) {
        int val = (bool)p_value ? 1 : 0;
        return setsockopt(sock_fd, SOL_SOCKET, SO_BROADCAST, &val, sizeof(val)) == 0;
    }
    if (p_option.nocasecmp_to("RecvBuffer") == 0) {
        int val = (int)p_value;
        return setsockopt(sock_fd, SOL_SOCKET, SO_RCVBUF, &val, sizeof(val)) == 0;
    }
    if (p_option.nocasecmp_to("SendBuffer") == 0) {
        int val = (int)p_value;
        return setsockopt(sock_fd, SOL_SOCKET, SO_SNDBUF, &val, sizeof(val)) == 0;
    }
    if (p_option.nocasecmp_to("NonBlocking") == 0) {
        return set_nonblocking(sock_fd, (bool)p_value);
    }

    last_error = "Unknown option: " + p_option;
    return false;
#elif defined(_WIN32)
    if (sock_fd < 0) return false;

    if (p_option.nocasecmp_to("NoDelay") == 0) {
        int val = (bool)p_value ? 1 : 0;
        return setsockopt((SOCKET)sock_fd, IPPROTO_TCP, TCP_NODELAY, (const char *)&val, sizeof(val)) == 0;
    }
    if (p_option.nocasecmp_to("ReuseAddr") == 0) {
        int val = (bool)p_value ? 1 : 0;
        return setsockopt((SOCKET)sock_fd, SOL_SOCKET, SO_REUSEADDR, (const char *)&val, sizeof(val)) == 0;
    }
    if (p_option.nocasecmp_to("KeepAlive") == 0) {
        int val = (bool)p_value ? 1 : 0;
        return setsockopt((SOCKET)sock_fd, SOL_SOCKET, SO_KEEPALIVE, (const char *)&val, sizeof(val)) == 0;
    }
    if (p_option.nocasecmp_to("Broadcast") == 0) {
        int val = (bool)p_value ? 1 : 0;
        return setsockopt((SOCKET)sock_fd, SOL_SOCKET, SO_BROADCAST, (const char *)&val, sizeof(val)) == 0;
    }
    if (p_option.nocasecmp_to("RecvBuffer") == 0) {
        int val = (int)p_value;
        return setsockopt((SOCKET)sock_fd, SOL_SOCKET, SO_RCVBUF, (const char *)&val, sizeof(val)) == 0;
    }
    if (p_option.nocasecmp_to("SendBuffer") == 0) {
        int val = (int)p_value;
        return setsockopt((SOCKET)sock_fd, SOL_SOCKET, SO_SNDBUF, (const char *)&val, sizeof(val)) == 0;
    }
    if (p_option.nocasecmp_to("NonBlocking") == 0) {
        return set_nonblocking(sock_fd, (bool)p_value);
    }

    last_error = "Unknown option: " + p_option;
    return false;
#else
    return false;
#endif
}
