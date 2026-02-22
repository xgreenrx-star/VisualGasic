// VGHttpRequest — MSXML2.XMLHTTP / WinHttpRequest emulation
// Uses Godot's HTTPClient for synchronous HTTP operations

#include "visual_gasic_http.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/tls_options.hpp>

using namespace godot;

void VGHttpRequest::_bind_methods() {
    ClassDB::bind_method(D_METHOD("open", "method", "url", "async"), &VGHttpRequest::open, DEFVAL(false));
    ClassDB::bind_method(D_METHOD("set_request_header", "header", "value"), &VGHttpRequest::set_request_header);
    ClassDB::bind_method(D_METHOD("send", "body"), &VGHttpRequest::send, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("get_response_text"), &VGHttpRequest::get_response_text);
    ClassDB::bind_method(D_METHOD("get_response_body"), &VGHttpRequest::get_response_body);
    ClassDB::bind_method(D_METHOD("get_status"), &VGHttpRequest::get_status);
    ClassDB::bind_method(D_METHOD("get_status_text"), &VGHttpRequest::get_status_text);
    ClassDB::bind_method(D_METHOD("get_response_header", "header"), &VGHttpRequest::get_response_header);
    ClassDB::bind_method(D_METHOD("get_all_response_headers"), &VGHttpRequest::get_all_response_headers);
    ClassDB::bind_method(D_METHOD("get_ready_state"), &VGHttpRequest::get_ready_state);
    ClassDB::bind_method(D_METHOD("get_url", "url"), &VGHttpRequest::get_url);
    ClassDB::bind_method(D_METHOD("post_url", "url", "body", "content_type"), &VGHttpRequest::post_url, DEFVAL("application/x-www-form-urlencoded"));
    ClassDB::bind_method(D_METHOD("get_json", "url"), &VGHttpRequest::get_json);

    // VB6-style PascalCase aliases
    ClassDB::bind_method(D_METHOD("Open", "method", "url", "async"), &VGHttpRequest::open, DEFVAL(false));
    ClassDB::bind_method(D_METHOD("SetRequestHeader", "header", "value"), &VGHttpRequest::set_request_header);
    ClassDB::bind_method(D_METHOD("Send", "body"), &VGHttpRequest::send, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("GetResponseHeader", "header"), &VGHttpRequest::get_response_header);
    ClassDB::bind_method(D_METHOD("GetAllResponseHeaders"), &VGHttpRequest::get_all_response_headers);
    ClassDB::bind_method(D_METHOD("GetUrl", "url"), &VGHttpRequest::get_url);
    ClassDB::bind_method(D_METHOD("PostUrl", "url", "body", "content_type"), &VGHttpRequest::post_url, DEFVAL("application/x-www-form-urlencoded"));
    ClassDB::bind_method(D_METHOD("GetJson", "url"), &VGHttpRequest::get_json);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "ResponseText"), "", "get_response_text");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "Status"), "", "get_status");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "StatusText"), "", "get_status_text");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "ReadyState"), "", "get_ready_state");
}

VGHttpRequest::VGHttpRequest() {
    status_code = 0;
    ready_state = 0;
    port = 80;
    use_ssl = false;
    is_async = false;
}

VGHttpRequest::~VGHttpRequest() {}

void VGHttpRequest::parse_url(const String &p_url) {
    String u = p_url;

    use_ssl = false;
    port = 80;
    path = "/";

    if (u.begins_with("https://")) {
        use_ssl = true;
        port = 443;
        u = u.substr(8);
    } else if (u.begins_with("http://")) {
        u = u.substr(7);
    }

    int slash_pos = u.find("/");
    if (slash_pos >= 0) {
        host = u.substr(0, slash_pos);
        path = u.substr(slash_pos);
    } else {
        host = u;
        path = "/";
    }

    // Check for port in host
    int colon_pos = host.find(":");
    if (colon_pos >= 0) {
        port = host.substr(colon_pos + 1).to_int();
        host = host.substr(0, colon_pos);
    }
}

void VGHttpRequest::open(const String &p_method, const String &p_url, bool p_async) {
    method = p_method.to_upper();
    url = p_url;
    is_async = p_async;
    request_headers = Dictionary();
    response_text = "";
    response_body = PackedByteArray();
    status_code = 0;
    status_text = "";
    response_headers = Dictionary();
    ready_state = 1; // OPENED
    parse_url(p_url);
}

void VGHttpRequest::set_request_header(const String &p_header, const String &p_value) {
    request_headers[p_header] = p_value;
}

int VGHttpRequest::perform_request(const String &p_body) {
    Ref<HTTPClient> client;
    client.instantiate();

    Error err;
    if (use_ssl) {
        Ref<TLSOptions> tls = TLSOptions::client_unsafe();
        err = client->connect_to_host(host, port, tls);
    } else {
        err = client->connect_to_host(host, port);
    }

    if (err != OK) {
        UtilityFunctions::printerr("[VGHttpRequest] Connection error to " + host);
        status_code = 0;
        ready_state = 4;
        return -1;
    }

    // Poll until connected (with timeout)
    int timeout = 10000; // 10 seconds
    int elapsed = 0;
    while (client->get_status() == HTTPClient::STATUS_CONNECTING ||
           client->get_status() == HTTPClient::STATUS_RESOLVING) {
        client->poll();
        OS::get_singleton()->delay_msec(50);
        elapsed += 50;
        if (elapsed > timeout) {
            UtilityFunctions::printerr("[VGHttpRequest] Connection timeout to " + host);
            status_code = 0;
            ready_state = 4;
            return -1;
        }
    }

    if (client->get_status() != HTTPClient::STATUS_CONNECTED) {
        UtilityFunctions::printerr("[VGHttpRequest] Failed to connect to " + host);
        status_code = 0;
        ready_state = 4;
        return -1;
    }

    // Build headers
    PackedStringArray headers;
    headers.push_back(String("Host: ") + host);
    Array hkeys = request_headers.keys();
    for (int i = 0; i < hkeys.size(); i++) {
        String k = hkeys[i];
        headers.push_back(k + String(": ") + String(request_headers[k]));
    }

    if (!p_body.is_empty() && !request_headers.has("Content-Type")) {
        headers.push_back("Content-Type: application/x-www-form-urlencoded");
    }

    // Map method string to enum
    HTTPClient::Method http_method = HTTPClient::METHOD_GET;
    if (method == "POST") http_method = HTTPClient::METHOD_POST;
    else if (method == "PUT") http_method = HTTPClient::METHOD_PUT;
    else if (method == "DELETE") http_method = HTTPClient::METHOD_DELETE;
    else if (method == "HEAD") http_method = HTTPClient::METHOD_HEAD;
    else if (method == "PATCH") http_method = HTTPClient::METHOD_PATCH;

    err = client->request(http_method, path, headers, p_body);
    if (err != OK) {
        UtilityFunctions::printerr("[VGHttpRequest] Request error");
        status_code = 0;
        ready_state = 4;
        return -1;
    }

    ready_state = 2; // HEADERS_RECEIVED (waiting)

    // Poll until response
    elapsed = 0;
    while (client->get_status() == HTTPClient::STATUS_REQUESTING) {
        client->poll();
        OS::get_singleton()->delay_msec(50);
        elapsed += 50;
        if (elapsed > timeout) {
            UtilityFunctions::printerr("[VGHttpRequest] Request timeout");
            status_code = 0;
            ready_state = 4;
            return -1;
        }
    }

    if (!client->has_response()) {
        UtilityFunctions::printerr("[VGHttpRequest] No response from server");
        status_code = 0;
        ready_state = 4;
        return -1;
    }

    status_code = client->get_response_code();
    ready_state = 3; // LOADING

    // Read response headers
    response_headers = Dictionary();
    PackedStringArray resp_hdrs = client->get_response_headers();
    for (int i = 0; i < resp_hdrs.size(); i++) {
        String h = resp_hdrs[i];
        int colon = h.find(":");
        if (colon >= 0) {
            response_headers[h.substr(0, colon).strip_edges()] = h.substr(colon + 1).strip_edges();
        }
    }

    // Read body
    response_body = PackedByteArray();
    while (client->get_status() == HTTPClient::STATUS_BODY) {
        client->poll();
        PackedByteArray chunk = client->read_response_body_chunk();
        if (chunk.size() > 0) {
            response_body.append_array(chunk);
        }
        OS::get_singleton()->delay_msec(10);
    }

    response_text = response_body.get_string_from_utf8();
    ready_state = 4; // DONE

    return status_code;
}

int VGHttpRequest::send(const String &p_body) {
    if (ready_state < 1) {
        UtilityFunctions::printerr("[VGHttpRequest] Must call open() before send()");
        return -1;
    }
    return perform_request(p_body);
}

String VGHttpRequest::get_response_text() const { return response_text; }
PackedByteArray VGHttpRequest::get_response_body() const { return response_body; }
int VGHttpRequest::get_status() const { return status_code; }

String VGHttpRequest::get_status_text() const {
    switch (status_code) {
        case 200: return "OK";
        case 201: return "Created";
        case 204: return "No Content";
        case 301: return "Moved Permanently";
        case 302: return "Found";
        case 304: return "Not Modified";
        case 400: return "Bad Request";
        case 401: return "Unauthorized";
        case 403: return "Forbidden";
        case 404: return "Not Found";
        case 500: return "Internal Server Error";
        case 502: return "Bad Gateway";
        case 503: return "Service Unavailable";
        default: return String("HTTP ") + String::num_int64(status_code);
    }
}

String VGHttpRequest::get_response_header(const String &p_header) const {
    if (response_headers.has(p_header)) return response_headers[p_header];
    return "";
}

String VGHttpRequest::get_all_response_headers() const {
    String result;
    Array keys = response_headers.keys();
    for (int i = 0; i < keys.size(); i++) {
        String k = keys[i];
        result += k + String(": ") + String(response_headers[k]) + String("\r\n");
    }
    return result;
}

int VGHttpRequest::get_ready_state() const { return ready_state; }

String VGHttpRequest::get_url(const String &p_url) {
    open("GET", p_url, false);
    send("");
    return response_text;
}

String VGHttpRequest::post_url(const String &p_url, const String &p_body, const String &p_content_type) {
    open("POST", p_url, false);
    set_request_header("Content-Type", p_content_type);
    send(p_body);
    return response_text;
}

Dictionary VGHttpRequest::get_json(const String &p_url) {
    String text = get_url(p_url);
    if (text.is_empty()) return Dictionary();
    Ref<JSON> json;
    json.instantiate();
    Error err = json->parse(text);
    if (err != OK) {
        UtilityFunctions::printerr("[VGHttpRequest] JSON parse error: " + json->get_error_message());
        return Dictionary();
    }
    Variant result = json->get_data();
    if (result.get_type() == Variant::DICTIONARY) return result;
    Dictionary wrapper;
    wrapper["data"] = result;
    return wrapper;
}
