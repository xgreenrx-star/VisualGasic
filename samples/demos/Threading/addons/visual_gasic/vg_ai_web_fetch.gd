extends RefCounted
class_name VgAiWebFetch
## Read-only HTTPS fetch for Narcea reference URLs (Phase 0).
## SSRF-safe: HTTPS only, private/loopback hosts blocked.

const MAX_BODY_BYTES := 65536
const MAX_TEXT_CHARS := 32768
const CONNECT_POLLS := 30
const BODY_POLLS := 150  # ~15 s at 100 ms


static func allow_web_fetch() -> bool:
	return bool(ProjectSettings.get_setting("vg/ai/allow_web_fetch", true))


static func fetch_url(raw_url: String) -> Dictionary:
	if not allow_web_fetch():
		return {"ok": false, "error": "Web fetch disabled (Project Settings → vg/ai/allow_web_fetch)."}
	var parsed: Dictionary = parse_https_url(raw_url)
	if parsed.is_empty():
		return {"ok": false, "error": "Only https:// URLs are allowed."}
	var host: String = str(parsed.get("host", ""))
	if not _host_allowed(host):
		return {"ok": false, "error": "Blocked host (private/loopback): %s" % host}
	var Providers = load("res://addons/visual_gasic/vg_ai_providers.gd")
	var headers := PackedStringArray([
		"User-Agent: VisualGasic-Narcea/1.0",
		"Accept: text/html,text/plain,application/xhtml+xml",
	])
	var path: String = str(parsed.get("path", "/"))
	var resp: Dictionary = Providers._http_request_sync(
		host, int(parsed.get("port", 443)), true,
		HTTPClient.METHOD_GET, path, headers, "",
		CONNECT_POLLS, BODY_POLLS)
	if not resp.get("ok", false):
		return {"ok": false, "error": str(resp.get("error", "HTTP failed"))}
	var code: int = int(resp.get("code", 0))
	if code < 200 or code >= 300:
		return {"ok": false, "error": "HTTP %d from %s" % [code, host]}
	var body: String = str(resp.get("body", ""))
	if body.to_utf8_buffer().size() > MAX_BODY_BYTES:
		body = body.substr(0, MAX_BODY_BYTES)
	var title := _extract_html_title(body)
	var text := html_to_text(body)
	if text.length() > MAX_TEXT_CHARS:
		text = text.substr(0, MAX_TEXT_CHARS) + "\n…(truncated)"
	if text.strip_edges().length() < 40:
		return {"ok": false, "error": "Page had too little readable text."}
	return {
		"ok": true,
		"url": "https://%s%s" % [host, path],
		"title": title if not title.is_empty() else host,
		"text": text,
	}


static func parse_https_url(raw: String) -> Dictionary:
	var u := raw.strip_edges().trim_suffix("/")
	if u.is_empty():
		return {}
	if not u.begins_with("https://"):
		if u.begins_with("http://"):
			return {}
		u = "https://" + u.lstrip("/")
	var rest := u.substr(8)
	if rest.is_empty():
		return {}
	var slash := rest.find("/")
	var host_part := rest if slash < 0 else rest.substr(0, slash)
	var path := "/" if slash < 0 else rest.substr(slash)
	if host_part.is_empty():
		return {}
	var host := host_part
	var port := 443
	if host_part.find(":") >= 0:
		var hp := host_part.split(":", false)
		host = hp[0]
		port = int(hp[1]) if hp.size() > 1 else 443
	if host.is_empty() or port <= 0 or port > 65535:
		return {}
	return {"host": host.to_lower(), "port": port, "path": path}


static func extract_https_urls(text: String) -> Array[String]:
	var out: Array[String] = []
	var rx := RegEx.new()
	if rx.compile("https://[A-Za-z0-9\\-._~:/?#\\[\\]@!$&'()*+,;=%]+") != OK:
		return out
	for m in rx.search_all(text):
		var u := m.get_string().strip_edges().trim_suffix(".")
		if not u.is_empty() and u not in out:
			out.append(u)
	return out


static func html_to_text(html: String) -> String:
	var t := html
	# Drop script/style blocks.
	var block_rx := RegEx.new()
	block_rx.compile("(?is)<(script|style)[^>]*>.*?</\\1>")
	t = block_rx.sub(t, " ", true)
	# Strip tags.
	var tag_rx := RegEx.new()
	tag_rx.compile("(?s)<[^>]+>")
	t = tag_rx.sub(t, " ", true)
	t = t.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
	t = t.replace("&quot;", "\"")
	# Collapse whitespace.
	var ws := RegEx.new()
	ws.compile("[ \\t\\r\\f\\v]+")
	t = ws.sub(t, " ", true)
	ws.compile("\\n{3,}")
	t = ws.sub(t, "\n\n", true)
	return t.strip_edges()


static func cache_path_for_url(url: String) -> String:
	return "user://vg_references/%s.txt" % str(url.hash())


static func write_cache(url: String, title: String, text: String) -> void:
	var dir := "user://vg_references"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(cache_path_for_url(url), FileAccess.WRITE)
	if f:
		f.store_string("URL: %s\nTitle: %s\n\n%s" % [url, title, text])
		f.close()


static func _extract_html_title(html: String) -> String:
	var rx := RegEx.new()
	if rx.compile("(?is)<title[^>]*>(.*?)</title>") != OK:
		return ""
	var m := rx.search(html)
	if m == null:
		return ""
	return html_to_text(m.get_string(1)).strip_edges()


static func _host_allowed(host: String) -> bool:
	var h := host.strip_edges().to_lower()
	if h.is_empty():
		return false
	if h in ["localhost", "127.0.0.1", "0.0.0.0", "::1", "metadata.google.internal"]:
		return false
	if h.ends_with(".local") or h.ends_with(".internal"):
		return false
	if h.find(":") >= 0:  # IPv6 literal — block for MVP
		return false
	var parts := h.split(".")
	if parts.size() == 4 and parts[0].is_valid_int():
		var a := int(parts[0])
		var b := int(parts[1]) if parts[1].is_valid_int() else -1
		if a == 10:
			return false
		if a == 127:
			return false
		if a == 0:
			return false
		if a == 169 and b == 254:
			return false
		if a == 192 and b == 168:
			return false
		if a == 172 and b >= 16 and b <= 31:
			return false
	return true
