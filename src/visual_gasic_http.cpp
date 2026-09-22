// VGHttpRequest — MSXML2.XMLHTTP / WinHttpRequest emulation
// Uses Godot's HTTPClient for synchronous HTTP operations

#include "visual_gasic_http.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/tls_options.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/main_loop.hpp>

#ifdef VG_WEB_BUILD
#include <emscripten.h>
#endif

using namespace godot;

namespace {

#ifdef VG_WEB_BUILD
// HTML5: sync HTTP via browser XHR in pure JS (no emscripten_sleep / Asyncify on the side module).
EM_JS(int, vg_web_http_fetch_sync, (const char *p_method, const char *p_url, const char *p_body, const char *p_headers_json, char *p_out_body, int p_out_body_max, char *p_out_headers_json, int p_out_headers_max, int *p_out_status), {
	var method = UTF8ToString(p_method);
	var url = UTF8ToString(p_url);
	var body = UTF8ToString(p_body);
	var headers = {};
	try {
		headers = JSON.parse(UTF8ToString(p_headers_json || '{}'));
	} catch (e) {
		return 1;
	}
	if (!headers['Accept']) {
		headers['Accept'] = '*/*';
	}
	// Browsers forbid setting User-Agent from XHR/fetch (unsafe header).
	delete headers['User-Agent'];

	var xhr = new XMLHttpRequest();
	try {
		xhr.open(method, url, false);
	} catch (e) {
		return 2;
	}
	for (var key in headers) {
		if (Object.prototype.hasOwnProperty.call(headers, key)) {
			xhr.setRequestHeader(key, headers[key]);
		}
	}
	try {
		if (method === 'GET' || method === 'HEAD') {
			xhr.send(null);
		} else {
			xhr.send(body.length > 0 ? body : null);
		}
	} catch (e) {
		return 2;
	}

	HEAP32[p_out_status >> 2] = xhr.status;
	stringToUTF8(xhr.responseText ? xhr.responseText : "", p_out_body, p_out_body_max);

	var responseHeaders = {};
	var raw = xhr.getAllResponseHeaders();
	if (raw) {
		var lines = raw.trim().split('\n');
		for (var i = 0; i < lines.length; i++) {
			var line = lines[i];
			if (line.length > 0 && line.charCodeAt(line.length - 1) === 13) {
				line = line.substring(0, line.length - 1);
			}
			var idx = line.indexOf(':');
			if (idx > 0) {
				responseHeaders[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
			}
		}
	}
	stringToUTF8(JSON.stringify(responseHeaders), p_out_headers_json, p_out_headers_max);
	return 0;
});

#endif // VG_WEB_BUILD

void _http_wait_while_polling() {
	// Keep Godot responsive during sync HTTP (VGHttpRequest / HttpGet in _Process).
	DisplayServer *ds = DisplayServer::get_singleton();
	MainLoop *ml = Engine::get_singleton() ? Engine::get_singleton()->get_main_loop() : nullptr;
	if (ml) {
		ml->call("_process", 0.016);
	}
	if (ds) {
		ds->process_events();
	} else if (OS *os = OS::get_singleton()) {
		os->delay_msec(10);
	}
}

bool _http_status_is_fatal(HTTPClient::Status p_status) {
	return p_status == HTTPClient::STATUS_CANT_CONNECT || p_status == HTTPClient::STATUS_CANT_RESOLVE ||
			p_status == HTTPClient::STATUS_CONNECTION_ERROR || p_status == HTTPClient::STATUS_DISCONNECTED ||
			p_status == HTTPClient::STATUS_TLS_HANDSHAKE_ERROR;
}

void _http_pump(Ref<HTTPClient> p_client) {
	p_client->poll();
}

} // namespace

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

#ifdef VG_WEB_BUILD
int VGHttpRequest::perform_request_web(const String &p_body) {
	const int kMaxBody = 1024 * 1024;
	const int kMaxHeadersJson = 65536;

	PackedByteArray body_buf;
	body_buf.resize(kMaxBody);
	PackedByteArray headers_buf;
	headers_buf.resize(kMaxHeadersJson);

	int status = 0;
	CharString method_cs = method.utf8();
	CharString url_cs = url.utf8();
	CharString body_cs = p_body.utf8();

	Dictionary hdrs = request_headers;
	if (!hdrs.has("Accept")) {
		hdrs["Accept"] = "*/*";
	}
	hdrs.erase("User-Agent");
	String headers_json = JSON::stringify(hdrs);
	CharString headers_cs = headers_json.utf8();

	int err = vg_web_http_fetch_sync(
			method_cs.get_data(),
			url_cs.get_data(),
			body_cs.get_data(),
			headers_cs.get_data(),
			reinterpret_cast<char *>(body_buf.ptrw()),
			kMaxBody,
			reinterpret_cast<char *>(headers_buf.ptrw()),
			kMaxHeadersJson,
			&status);

	if (err != 0) {
		UtilityFunctions::printerr("[VGHttpRequest] Web fetch failed (code=" + String::num_int64(err) + ")");
		status_code = 0;
		status_text = err == 2 ? "Network error or timeout" : "Invalid request headers";
		ready_state = 4;
		return -1;
	}

	status_code = status;
	ready_state = 4;

	int len = 0;
	while (len < kMaxBody && body_buf[len] != 0) {
		len++;
	}
	response_body = len > 0 ? body_buf.slice(0, len) : PackedByteArray();
	response_text = response_body.get_string_from_utf8();

	response_headers = Dictionary();
	String resp_hdr_json = String::utf8(reinterpret_cast<const char *>(headers_buf.ptr()));
	Ref<JSON> json;
	json.instantiate();
	if (json->parse(resp_hdr_json) == OK) {
		Variant parsed = json->get_data();
		if (parsed.get_type() == Variant::DICTIONARY) {
			response_headers = parsed;
		}
	}

	return status_code;
}
#endif

int VGHttpRequest::perform_request(const String &p_body) {
#ifdef VG_WEB_BUILD
	return perform_request_web(p_body);
#endif
	Ref<HTTPClient> client;
	client.instantiate();

	Time *tm = Time::get_singleton();
	const int timeout_ms = 30000;
	uint64_t deadline = tm ? tm->get_ticks_msec() + (uint64_t)timeout_ms : 0;

	Error err = OK;
	if (use_ssl || port == 443) {
		Ref<TLSOptions> tls = TLSOptions::client();
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

	while (true) {
		HTTPClient::Status s = client->get_status();
		if (s == HTTPClient::STATUS_CONNECTED) {
			break;
		}
		if (_http_status_is_fatal(s)) {
			UtilityFunctions::printerr("[VGHttpRequest] Failed to connect to " + host + " (status=" + String::num_int64((int64_t)s) + ")");
			status_code = 0;
			ready_state = 4;
			return -1;
		}
		_http_pump(client);
		if (tm && tm->get_ticks_msec() > deadline) {
			UtilityFunctions::printerr("[VGHttpRequest] Connection timeout to " + host);
			status_code = 0;
			ready_state = 4;
			return -1;
		}
		_http_wait_while_polling();
	}

	PackedStringArray headers;
	// Do not set Host — HTTPClient sets it from connect_to_host(); a duplicate Host often yields HTTP 400.
	if (!request_headers.has("User-Agent")) {
		headers.push_back("User-Agent: VisualGasic-VGHttpRequest/1.0");
	}
	if (!request_headers.has("Accept")) {
		headers.push_back("Accept: */*");
	}
	Array hkeys = request_headers.keys();
	for (int i = 0; i < hkeys.size(); i++) {
		String k = hkeys[i];
		headers.push_back(k + String(": ") + String(request_headers[k]));
	}

	if (!p_body.is_empty() && !request_headers.has("Content-Type")) {
		headers.push_back("Content-Type: application/x-www-form-urlencoded");
	}

	HTTPClient::Method http_method = HTTPClient::METHOD_GET;
	if (method == "POST") {
		http_method = HTTPClient::METHOD_POST;
	} else if (method == "PUT") {
		http_method = HTTPClient::METHOD_PUT;
	} else if (method == "DELETE") {
		http_method = HTTPClient::METHOD_DELETE;
	} else if (method == "HEAD") {
		http_method = HTTPClient::METHOD_HEAD;
	} else if (method == "PATCH") {
		http_method = HTTPClient::METHOD_PATCH;
	}

	err = client->request(http_method, path, headers, p_body);
	if (err != OK) {
		UtilityFunctions::printerr("[VGHttpRequest] Request error");
		status_code = 0;
		ready_state = 4;
		return -1;
	}

	ready_state = 2;

	while (true) {
		HTTPClient::Status s = client->get_status();
		if (client->has_response() || s == HTTPClient::STATUS_BODY) {
			break;
		}
		if (_http_status_is_fatal(s)) {
			UtilityFunctions::printerr("[VGHttpRequest] No response from server (status=" + String::num_int64((int64_t)s) + ")");
			status_code = 0;
			ready_state = 4;
			return -1;
		}
		_http_pump(client);
		if (tm && tm->get_ticks_msec() > deadline) {
			UtilityFunctions::printerr("[VGHttpRequest] Request timeout");
			status_code = 0;
			ready_state = 4;
			return -1;
		}
		_http_wait_while_polling();
	}

	if (!client->has_response()) {
		UtilityFunctions::printerr("[VGHttpRequest] No response from server");
		status_code = 0;
		ready_state = 4;
		return -1;
	}

	status_code = client->get_response_code();
	ready_state = 3;

	response_headers = Dictionary();
	PackedStringArray resp_hdrs = client->get_response_headers();
	for (int i = 0; i < resp_hdrs.size(); i++) {
		String h = resp_hdrs[i];
		int colon = h.find(":");
		if (colon >= 0) {
			response_headers[h.substr(0, colon).strip_edges()] = h.substr(colon + 1).strip_edges();
		}
	}

	response_body = PackedByteArray();
	while (client->get_status() == HTTPClient::STATUS_BODY) {
		_http_pump(client);
		PackedByteArray chunk = client->read_response_body_chunk();
		if (chunk.size() > 0) {
			response_body.append_array(chunk);
		} else if (tm && tm->get_ticks_msec() > deadline) {
			break;
		}
		_http_wait_while_polling();
	}

	response_text = response_body.get_string_from_utf8();
	ready_state = 4;

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
	if (status_code == 0 && !status_text.is_empty()) {
		return status_text;
	}
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
