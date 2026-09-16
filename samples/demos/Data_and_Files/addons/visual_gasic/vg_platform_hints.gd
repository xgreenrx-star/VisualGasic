extends RefCounted
class_name VGPlatformHints
## Cross-platform user-facing path / command hints.


static func temp_file_path(filename: String) -> String:
	return OS.get_temp_dir().path_join(filename)


static func http_server_preview_hint(web_dir: String, port: int = 8080) -> String:
	var dir := web_dir.strip_edges().trim_suffix("/").trim_suffix("\\")
	var url := "http://localhost:%d/" % port
	match OS.get_name():
		"Windows", "UWP":
			return (
				"Serve the output folder with a local HTTP server first:\n"
				+ "  cd %s\n  py -m http.server %d\nThen open  %s  in your browser." % [dir, port, url]
			)
		_:
			return (
				"Serve the output folder with a local HTTP server first:\n"
				+ "  cd %s\n  python3 -m http.server %d\nThen open  %s  in your browser." % [dir, port, url]
			)


static func http_server_preview_log_line(web_dir: String, port: int = 8000) -> String:
	match OS.get_name():
		"Windows", "UWP":
			return "  Preview: cd %s/ && py -m http.server %d" % [web_dir.trim_suffix("/"), port]
		_:
			return "  Preview: cd %s/ && python3 -m http.server %d" % [web_dir.trim_suffix("/"), port]
