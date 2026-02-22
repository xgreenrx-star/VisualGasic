// VGHttpRequest — MSXML2.XMLHTTP / WinHttpRequest emulation
// Wraps Godot's HTTPClient for synchronous-style HTTP requests

#ifndef VISUAL_GASIC_HTTP_H
#define VISUAL_GASIC_HTTP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/http_client.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class VGHttpRequest : public RefCounted {
    GDCLASS(VGHttpRequest, RefCounted)

protected:
    static void _bind_methods();

public:
    VGHttpRequest();
    ~VGHttpRequest();

    // VB6 XMLHTTP-style API
    void open(const String &p_method, const String &p_url, bool p_async = false);
    void set_request_header(const String &p_header, const String &p_value);
    int send(const String &p_body = "");

    // Response
    String get_response_text() const;
    PackedByteArray get_response_body() const;
    int get_status() const;
    String get_status_text() const;
    String get_response_header(const String &p_header) const;
    String get_all_response_headers() const;
    int get_ready_state() const;

    // Convenience methods
    String get_url(const String &p_url);
    String post_url(const String &p_url, const String &p_body, const String &p_content_type = "application/x-www-form-urlencoded");
    Dictionary get_json(const String &p_url);

private:
    String method;
    String url;
    String host;
    int port;
    String path;
    bool use_ssl;
    bool is_async;
    Dictionary request_headers;

    // Response state
    String response_text;
    PackedByteArray response_body;
    int status_code;
    String status_text;
    Dictionary response_headers;
    int ready_state; // 0=UNSENT, 1=OPENED, 2=HEADERS_RECEIVED, 3=LOADING, 4=DONE

    void parse_url(const String &p_url);
    int perform_request(const String &p_body);
};

} // namespace godot

#endif // VISUAL_GASIC_HTTP_H
