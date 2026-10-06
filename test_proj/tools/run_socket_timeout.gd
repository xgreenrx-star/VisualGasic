extends SceneTree

func _init() -> void:
	var server := TCPServer.new()
	var port := 0
	for candidate in range(42000, 42032):
		if server.listen(candidate, "127.0.0.1") == OK:
			port = candidate
			break
	if port == 0:
		printerr("FAIL: no available loopback port for socket timeout test")
		quit(1)
		return
	var clients: Array = []
	var timed_out := false
	for attempt in range(64):
		var client = ClassDB.instantiate("VGSocket")
		var start := Time.get_ticks_msec()
		var connected: bool = client.connect_to("127.0.0.1", port, 25)
		var elapsed := Time.get_ticks_msec() - start
		if not connected:
			timed_out = str(client.LastError).contains("timed out after 25 ms")
			if elapsed > 500 or elapsed < 20 or client.Connected:
				printerr("FAIL: bounded socket timeout elapsed=", elapsed, " connected=", client.Connected)
				quit(1)
				return
			print("PASS: socket saturated-loopback timeout ", elapsed, " ms")
			break
		clients.append(client)
	for client in clients:
		client.close_socket()
	server.stop()
	if not timed_out:
		printerr("FAIL: socket listen backlog did not produce the expected timeout")
		quit(1)
		return
	var invalid = ClassDB.instantiate("VGSocket")
	if invalid.connect_to("127.0.0.1", port, -1) or str(invalid.LastError).is_empty():
		printerr("FAIL: socket invalid timeout must report an error")
		quit(1)
		return
	print("PASS: socket invalid timeout is rejected")
	quit(0)
