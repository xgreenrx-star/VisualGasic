# vg_websocket_controls.gd
# WebSocket networking controls for VisualGasic — provides drag-and-drop
# multiplayer components for the VB6-style Form Designer.
#
# Controls:
#   VGWebSocketClient  — Connect to a WebSocket server, send/receive messages
#   VGWebSocketServer  — Accept WebSocket connections, broadcast to clients
#   VGWebSocketLobby   — Room-based matchmaking (create/join/leave/ready)
#   VGWebSocketChat    — Real-time chat with history, user list, system messages
#
# All controls wrap Godot's built-in WebSocketPeer / WebSocketMultiplayerPeer.
# They emit VisualGasic-friendly signals that map to VB6-style event subs:
#   Private Sub Winsock1_DataArrival(ByVal bytesTotal As Long)
#
# Usage from VG code:
#   WebSocket1.Connect "ws://localhost:8080"
#   WebSocket1.Send "Hello!"
#   Private Sub WebSocket1_MessageReceived(message As String)
#       MsgBox message
#   End Sub
@tool
extends RefCounted

# =============================================================================
# VGWebSocketClient — Client-side WebSocket connection
# =============================================================================
# Mirrors the classic VB6 Winsock control but for modern WebSocket protocol.
# Emits signals: Connected, Disconnected, MessageReceived, Error
#
# VG Event Mapping:
#   Private Sub WebSocket1_Connected()
#   Private Sub WebSocket1_Disconnected(code As Integer, reason As String)
#   Private Sub WebSocket1_MessageReceived(message As String)
#   Private Sub WebSocket1_BinaryReceived(data As PackedByteArray)
#   Private Sub WebSocket1_Error(message As String)
class VGWebSocketClient extends Node:
	signal connected_to_server()
	signal disconnected_from_server(code: int, reason: String)
	signal message_received(message: String)
	signal binary_received(data: PackedByteArray)
	signal error_occurred(message: String)

	## Connection state enum (mirrors VB6 Winsock states)
	enum State { CLOSED, CONNECTING, OPEN, CLOSING }

	## The WebSocket URL to connect to (e.g. "ws://localhost:8080/game")
	@export var url: String = ""
	## Auto-reconnect on disconnect (with exponential backoff)
	@export var auto_reconnect: bool = false
	## Maximum reconnect attempts (0 = unlimited)
	@export var max_reconnect_attempts: int = 5
	## Initial reconnect delay in seconds
	@export var reconnect_delay: float = 1.0

	var _peer: WebSocketPeer = null
	var _state: int = State.CLOSED
	var _reconnect_count: int = 0
	var _reconnect_timer: Timer = null

	func _ready() -> void:
		_peer = WebSocketPeer.new()
		_reconnect_timer = Timer.new()
		_reconnect_timer.one_shot = true
		_reconnect_timer.timeout.connect(_attempt_reconnect)
		add_child(_reconnect_timer)

	func _process(_delta: float) -> void:
		if _peer == null:
			return
		_peer.poll()

		var peer_state := _peer.get_ready_state()

		# State transitions
		match peer_state:
			WebSocketPeer.STATE_OPEN:
				if _state != State.OPEN:
					_state = State.OPEN
					_reconnect_count = 0
					connected_to_server.emit()
				# Read all available messages
				while _peer.get_available_packet_count() > 0:
					var pkt := _peer.get_packet()
					if _peer.was_string_packet():
						message_received.emit(pkt.get_string_from_utf8())
					else:
						binary_received.emit(pkt)

			WebSocketPeer.STATE_CLOSING:
				if _state != State.CLOSING:
					_state = State.CLOSING

			WebSocketPeer.STATE_CLOSED:
				if _state != State.CLOSED:
					var code := _peer.get_close_code()
					var reason := _peer.get_close_reason()
					_state = State.CLOSED
					disconnected_from_server.emit(code, reason)
					if auto_reconnect and _reconnect_count < max_reconnect_attempts:
						_schedule_reconnect()

	## Connect to a WebSocket server.
	## @param ws_url: WebSocket URL (ws:// or wss://). If empty, uses the `url` property.
	func ws_connect(ws_url: String = "") -> void:
		if not ws_url.is_empty():
			url = ws_url
		if url.is_empty():
			error_occurred.emit("No URL specified")
			return
		_state = State.CONNECTING
		_reconnect_count = 0
		var err := _peer.connect_to_url(url)
		if err != OK:
			_state = State.CLOSED
			error_occurred.emit("Connection failed: %s" % error_string(err))

	## Send a text message to the server.
	func send(message: String) -> void:
		if _state != State.OPEN:
			error_occurred.emit("Not connected")
			return
		_peer.send_text(message)

	## Send binary data to the server.
	func send_binary(data: PackedByteArray) -> void:
		if _state != State.OPEN:
			error_occurred.emit("Not connected")
			return
		_peer.send(data, WebSocketPeer.WRITE_MODE_BINARY)

	## Send a JSON-serializable Dictionary as a text message.
	func send_json(data: Dictionary) -> void:
		send(JSON.stringify(data))

	## Close the WebSocket connection gracefully.
	## @param code: Close status code (default 1000 = normal)
	## @param reason: Human-readable close reason
	func close(code: int = 1000, reason: String = "") -> void:
		auto_reconnect = false  # Don't reconnect on intentional close
		if _state == State.OPEN or _state == State.CONNECTING:
			_state = State.CLOSING
			_peer.close(code, reason)

	## @return Current connection state
	func get_state() -> int:
		return _state

	## @return Whether the client is currently connected
	func is_connected_to_server() -> bool:
		return _state == State.OPEN

	func _schedule_reconnect() -> void:
		_reconnect_count += 1
		var delay := reconnect_delay * pow(2, _reconnect_count - 1)  # Exponential backoff
		delay = minf(delay, 30.0)  # Cap at 30 seconds
		_reconnect_timer.start(delay)

	func _attempt_reconnect() -> void:
		if _state == State.CLOSED and auto_reconnect:
			ws_connect()


# =============================================================================
# VGWebSocketServer — Server-side WebSocket host
# =============================================================================
# Accepts WebSocket connections and manages connected clients.
# Uses TCPServer + WebSocketPeer for each connected client.
#
# VG Event Mapping:
#   Private Sub WebSocketServer1_ClientConnected(client_id As Integer)
#   Private Sub WebSocketServer1_ClientDisconnected(client_id As Integer)
#   Private Sub WebSocketServer1_MessageReceived(client_id As Integer, message As String)
#   Private Sub WebSocketServer1_ServerStarted()
#   Private Sub WebSocketServer1_ServerStopped()
class VGWebSocketServer extends Node:
	signal client_connected(client_id: int)
	signal client_disconnected(client_id: int)
	signal message_from_client(client_id: int, message: String)
	signal binary_from_client(client_id: int, data: PackedByteArray)
	signal server_started()
	signal server_stopped()
	signal error_occurred(message: String)

	## Port to listen on
	@export var port: int = 8080
	## Maximum number of clients (0 = unlimited)
	@export var max_clients: int = 32

	var _tcp_server: TCPServer = null
	var _clients: Dictionary = {}  # client_id -> {tcp: StreamPeerTCP, ws: WebSocketPeer, state: int}
	var _next_client_id: int = 1
	var _running: bool = false

	func _ready() -> void:
		_tcp_server = TCPServer.new()

	func _process(_delta: float) -> void:
		if not _running:
			return

		# Accept new TCP connections
		while _tcp_server.is_connection_available():
			if max_clients > 0 and _clients.size() >= max_clients:
				var conn := _tcp_server.take_connection()
				conn.disconnect_from_host()
				continue

			var conn := _tcp_server.take_connection()
			var ws := WebSocketPeer.new()
			ws.accept_stream(conn)
			var cid := _next_client_id
			_next_client_id += 1
			_clients[cid] = {"tcp": conn, "ws": ws, "state": WebSocketPeer.STATE_CONNECTING}

		# Poll all clients
		var to_remove: Array[int] = []
		for cid in _clients:
			var data: Dictionary = _clients[cid]
			var ws: WebSocketPeer = data["ws"]
			ws.poll()
			var state := ws.get_ready_state()

			if state == WebSocketPeer.STATE_OPEN:
				if data["state"] != WebSocketPeer.STATE_OPEN:
					data["state"] = WebSocketPeer.STATE_OPEN
					client_connected.emit(cid)
				# Read messages
				while ws.get_available_packet_count() > 0:
					var pkt := ws.get_packet()
					if ws.was_string_packet():
						message_from_client.emit(cid, pkt.get_string_from_utf8())
					else:
						binary_from_client.emit(cid, pkt)

			elif state == WebSocketPeer.STATE_CLOSED:
				to_remove.append(cid)
				if data["state"] == WebSocketPeer.STATE_OPEN:
					client_disconnected.emit(cid)

			data["state"] = state

		for cid in to_remove:
			_clients.erase(cid)

	## Start listening for WebSocket connections.
	## @param listen_port: Port to listen on (0 = use the `port` property)
	func start(listen_port: int = 0) -> void:
		if listen_port > 0:
			port = listen_port
		var err := _tcp_server.listen(port)
		if err != OK:
			error_occurred.emit("Failed to start server on port %d: %s" % [port, error_string(err)])
			return
		_running = true
		server_started.emit()

	## Stop the server and disconnect all clients.
	func stop() -> void:
		for cid in _clients:
			var ws: WebSocketPeer = _clients[cid]["ws"]
			ws.close(1001, "Server shutting down")
		_clients.clear()
		_tcp_server.stop()
		_running = false
		server_stopped.emit()

	## Send a text message to a specific client.
	func send_to(client_id: int, message: String) -> void:
		if not _clients.has(client_id):
			error_occurred.emit("Client %d not found" % client_id)
			return
		var ws: WebSocketPeer = _clients[client_id]["ws"]
		ws.send_text(message)

	## Send a JSON-serializable Dictionary to a specific client.
	func send_json_to(client_id: int, data: Dictionary) -> void:
		send_to(client_id, JSON.stringify(data))

	## Broadcast a text message to ALL connected clients.
	func broadcast(message: String) -> void:
		for cid in _clients:
			var data: Dictionary = _clients[cid]
			if data["state"] == WebSocketPeer.STATE_OPEN:
				var ws: WebSocketPeer = data["ws"]
				ws.send_text(message)

	## Broadcast a JSON Dictionary to all clients.
	func broadcast_json(data: Dictionary) -> void:
		broadcast(JSON.stringify(data))

	## Kick a client with an optional reason.
	func kick(client_id: int, reason: String = "Kicked") -> void:
		if _clients.has(client_id):
			var ws: WebSocketPeer = _clients[client_id]["ws"]
			ws.close(1000, reason)

	## @return Number of currently connected clients
	func get_client_count() -> int:
		var count := 0
		for cid in _clients:
			if _clients[cid]["state"] == WebSocketPeer.STATE_OPEN:
				count += 1
		return count

	## @return Array of connected client IDs
	func get_client_ids() -> Array[int]:
		var ids: Array[int] = []
		for cid in _clients:
			if _clients[cid]["state"] == WebSocketPeer.STATE_OPEN:
				ids.append(cid)
		return ids

	## @return Whether the server is currently running
	func is_running() -> bool:
		return _running


# =============================================================================
# VGWebSocketLobby — Room-based matchmaking built on VGWebSocketClient
# =============================================================================
# Higher-level abstraction for multiplayer lobbies:
#   - Create / join / leave rooms
#   - Player ready states
#   - Room listing
#   - Host migration
#
# Uses a simple JSON protocol on top of WebSocket messages.
# Protocol messages: {type: "create_room"|"join_room"|"leave_room"|"ready"|
#                     "room_list"|"player_list"|"chat"|"game_start", ...}
#
# VG Event Mapping:
#   Private Sub Lobby1_RoomCreated(room_id As String)
#   Private Sub Lobby1_RoomJoined(room_id As String, players As Array)
#   Private Sub Lobby1_RoomLeft()
#   Private Sub Lobby1_PlayerJoined(player_name As String)
#   Private Sub Lobby1_PlayerLeft(player_name As String)
#   Private Sub Lobby1_PlayerReady(player_name As String, is_ready As Boolean)
#   Private Sub Lobby1_AllPlayersReady()
#   Private Sub Lobby1_GameStarting(room_data As Dictionary)
#   Private Sub Lobby1_RoomListUpdated(rooms As Array)
class VGWebSocketLobby extends Node:
	signal room_created(room_id: String)
	signal room_joined(room_id: String, players: Array)
	signal room_left()
	signal player_joined(player_name: String)
	signal player_left(player_name: String)
	signal player_ready_changed(player_name: String, is_ready: bool)
	signal all_players_ready()
	signal game_starting(room_data: Dictionary)
	signal room_list_updated(rooms: Array)
	signal lobby_error(message: String)
	signal chat_message(player_name: String, message: String)

	## Player display name
	@export var player_name: String = "Player"
	## Maximum players per room
	@export var max_players_per_room: int = 4

	var _client: VGWebSocketClient = null
	var _current_room: String = ""
	var _players: Array = []  # [{name: String, ready: bool}]
	var _is_host: bool = false

	func _ready() -> void:
		_client = VGWebSocketClient.new()
		_client.name = "LobbyClient"
		add_child(_client)
		_client.connected_to_server.connect(_on_connected)
		_client.message_received.connect(_on_message)
		_client.disconnected_from_server.connect(_on_disconnected)
		_client.error_occurred.connect(func(msg): lobby_error.emit(msg))

	## Connect to the lobby server.
	func connect_to_lobby(ws_url: String) -> void:
		_client.ws_connect(ws_url)

	## Disconnect from the lobby server.
	func disconnect_from_lobby() -> void:
		_client.close()

	## Create a new room.
	## @param room_name: Display name for the room
	## @param room_settings: Optional game settings Dictionary
	func create_room(room_name: String = "", room_settings: Dictionary = {}) -> void:
		if room_name.is_empty():
			room_name = "%s's Room" % player_name
		_send_lobby_msg({
			"type": "create_room",
			"room_name": room_name,
			"player_name": player_name,
			"max_players": max_players_per_room,
			"settings": room_settings,
		})

	## Join an existing room by ID.
	func join_room(room_id: String) -> void:
		_send_lobby_msg({
			"type": "join_room",
			"room_id": room_id,
			"player_name": player_name,
		})

	## Leave the current room.
	func leave_room() -> void:
		if _current_room.is_empty():
			return
		_send_lobby_msg({
			"type": "leave_room",
			"room_id": _current_room,
		})
		_current_room = ""
		_players.clear()
		_is_host = false
		room_left.emit()

	## Toggle ready state.
	func set_ready(ready: bool) -> void:
		_send_lobby_msg({
			"type": "ready",
			"room_id": _current_room,
			"player_name": player_name,
			"ready": ready,
		})

	## Request current room list from server.
	func request_room_list() -> void:
		_send_lobby_msg({"type": "room_list_request"})

	## Start the game (host only).
	func start_game() -> void:
		if not _is_host:
			lobby_error.emit("Only the host can start the game")
			return
		_send_lobby_msg({
			"type": "game_start",
			"room_id": _current_room,
		})

	## Send a chat message to the current room.
	func send_chat(message: String) -> void:
		_send_lobby_msg({
			"type": "chat",
			"room_id": _current_room,
			"player_name": player_name,
			"message": message,
		})

	## @return Current room ID (empty if not in a room)
	func get_current_room() -> String:
		return _current_room

	## @return Array of player dictionaries [{name, ready}]
	func get_players() -> Array:
		return _players

	## @return Whether local player is the room host
	func is_host() -> bool:
		return _is_host

	## @return Whether all players in the room are ready
	func are_all_ready() -> bool:
		if _players.is_empty():
			return false
		for p in _players:
			if not p.get("ready", false):
				return false
		return true

	func _on_connected() -> void:
		# Announce ourselves to the lobby server
		_send_lobby_msg({
			"type": "register",
			"player_name": player_name,
		})

	func _on_disconnected(_code: int, _reason: String) -> void:
		_current_room = ""
		_players.clear()
		_is_host = false

	func _on_message(text: String) -> void:
		var json = JSON.parse_string(text)
		if json == null or not json is Dictionary:
			return
		var msg: Dictionary = json
		var msg_type: String = msg.get("type", "")

		match msg_type:
			"room_created":
				_current_room = msg.get("room_id", "")
				_is_host = true
				_players = [{"name": player_name, "ready": false}]
				room_created.emit(_current_room)

			"room_joined":
				_current_room = msg.get("room_id", "")
				_players = msg.get("players", [])
				_is_host = msg.get("is_host", false)
				room_joined.emit(_current_room, _players)

			"player_joined":
				var pname: String = msg.get("player_name", "")
				_players.append({"name": pname, "ready": false})
				player_joined.emit(pname)

			"player_left":
				var pname: String = msg.get("player_name", "")
				for i in range(_players.size() - 1, -1, -1):
					if _players[i]["name"] == pname:
						_players.remove_at(i)
						break
				player_left.emit(pname)
				# Host migration
				if msg.get("new_host", "") == player_name:
					_is_host = true

			"ready_update":
				var pname: String = msg.get("player_name", "")
				var ready: bool = msg.get("ready", false)
				for p in _players:
					if p["name"] == pname:
						p["ready"] = ready
						break
				player_ready_changed.emit(pname, ready)
				if are_all_ready():
					all_players_ready.emit()

			"room_list":
				room_list_updated.emit(msg.get("rooms", []))

			"game_start":
				game_starting.emit(msg.get("room_data", {}))

			"chat":
				chat_message.emit(msg.get("player_name", ""), msg.get("message", ""))

			"error":
				lobby_error.emit(msg.get("message", "Unknown error"))

	func _send_lobby_msg(data: Dictionary) -> void:
		if _client and _client.is_connected_to_server():
			_client.send_json(data)


# =============================================================================
# VGWebSocketChat — Real-time chat with message history and user list
# =============================================================================
# A complete chat control that can be used standalone or embedded in the lobby.
# Provides a scrollable message history with timestamps, user list panel,
# and input field.
#
# VG Event Mapping:
#   Private Sub Chat1_MessageReceived(sender As String, message As String, timestamp As String)
#   Private Sub Chat1_UserJoined(username As String)
#   Private Sub Chat1_UserLeft(username As String)
#   Private Sub Chat1_SystemMessage(message As String)
class VGWebSocketChat extends VBoxContainer:
	signal chat_message_sent(message: String)
	signal chat_message_received(sender: String, message: String, timestamp: String)
	signal user_joined(username: String)
	signal user_left(username: String)

	## Maximum messages to keep in history
	@export var max_history: int = 200
	## Show timestamps in messages
	@export var show_timestamps: bool = true
	## Show user list panel
	@export var show_user_list: bool = true
	## Local username
	@export var username: String = "Player"

	var _output: RichTextLabel = null
	var _input: LineEdit = null
	var _user_list: ItemList = null
	var _messages: Array = []  # [{sender, message, timestamp, is_system}]
	var _users: Array = []  # [String]

	func _ready() -> void:
		_build_ui()

	func _build_ui() -> void:
		var main_split := HSplitContainer.new()
		main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(main_split)

		# Chat area (left)
		var chat_vbox := VBoxContainer.new()
		chat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chat_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_split.add_child(chat_vbox)

		_output = RichTextLabel.new()
		_output.bbcode_enabled = true
		_output.scroll_following = true
		_output.selection_enabled = true
		_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var out_style := StyleBoxFlat.new()
		out_style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
		out_style.set_content_margin_all(6)
		out_style.set_corner_radius_all(4)
		_output.add_theme_stylebox_override("normal", out_style)
		chat_vbox.add_child(_output)

		# Input row
		var input_row := HBoxContainer.new()
		input_row.add_theme_constant_override("separation", 4)
		chat_vbox.add_child(input_row)

		_input = LineEdit.new()
		_input.placeholder_text = "Type a message..."
		_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_input.text_submitted.connect(_on_send)
		input_row.add_child(_input)

		var send_btn := Button.new()
		send_btn.text = "Send"
		send_btn.pressed.connect(func(): _on_send(_input.text))
		input_row.add_child(send_btn)

		# User list (right)
		if show_user_list:
			_user_list = ItemList.new()
			_user_list.custom_minimum_size.x = 120
			_user_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var ul_style := StyleBoxFlat.new()
			ul_style.bg_color = Color(0.1, 0.1, 0.14, 1.0)
			ul_style.set_content_margin_all(4)
			ul_style.set_corner_radius_all(4)
			_user_list.add_theme_stylebox_override("panel", ul_style)
			main_split.add_child(_user_list)

	## Send a message from the local user.
	func send_message(text: String) -> void:
		if text.strip_edges().is_empty():
			return
		chat_message_sent.emit(text.strip_edges())

	## Display a received message (call from network handler).
	func display_message(sender: String, message: String, timestamp: String = "") -> void:
		if timestamp.is_empty():
			timestamp = _get_timestamp()
		var entry := {"sender": sender, "message": message, "timestamp": timestamp, "is_system": false}
		_messages.append(entry)
		_trim_history()
		_render_message(entry)
		chat_message_received.emit(sender, message, timestamp)

	## Display a system message (join/leave/info).
	func display_system_message(message: String) -> void:
		var entry := {"sender": "", "message": message, "timestamp": _get_timestamp(), "is_system": true}
		_messages.append(entry)
		_trim_history()
		_render_message(entry)

	## Add a user to the user list.
	func add_user(uname: String) -> void:
		if uname not in _users:
			_users.append(uname)
			if _user_list:
				_user_list.add_item(uname)
			display_system_message("%s joined" % uname)
			user_joined.emit(uname)

	## Remove a user from the user list.
	func remove_user(uname: String) -> void:
		var idx := _users.find(uname)
		if idx >= 0:
			_users.remove_at(idx)
			if _user_list:
				for i in range(_user_list.item_count):
					if _user_list.get_item_text(i) == uname:
						_user_list.remove_item(i)
						break
			display_system_message("%s left" % uname)
			user_left.emit(uname)

	## Set the complete user list (replaces existing).
	func set_users(user_names: Array) -> void:
		_users.clear()
		if _user_list:
			_user_list.clear()
		for u in user_names:
			_users.append(str(u))
			if _user_list:
				_user_list.add_item(str(u))

	## Clear all chat messages.
	func clear_messages() -> void:
		_messages.clear()
		if _output:
			_output.clear()

	## @return All messages as an Array of Dictionaries
	func get_messages() -> Array:
		return _messages

	## @return Current user list
	func get_users() -> Array:
		return _users

	func _on_send(text: String) -> void:
		if text.strip_edges().is_empty():
			return
		send_message(text)
		display_message(username, text)
		_input.text = ""

	func _render_message(entry: Dictionary) -> void:
		if not _output:
			return
		var line := ""
		if entry["is_system"]:
			line = "[color=gray][i]%s[/i][/color]\n" % entry["message"]
		else:
			var ts := ""
			if show_timestamps and not entry["timestamp"].is_empty():
				ts = "[color=gray][%s][/color] " % entry["timestamp"]
			var sender_color := "#6688cc" if entry["sender"] != username else "#44bb88"
			line = "%s[color=%s][b]%s:[/b][/color] %s\n" % [ts, sender_color, entry["sender"], entry["message"]]
		_output.append_text(line)

	func _trim_history() -> void:
		while _messages.size() > max_history:
			_messages.pop_front()
			# Re-render all (simple approach — could optimize with partial updates)
			if _output:
				_output.clear()
				for msg in _messages:
					_render_message(msg)

	func _get_timestamp() -> String:
		var dt := Time.get_datetime_dict_from_system()
		return "%02d:%02d:%02d" % [dt["hour"], dt["minute"], dt["second"]]


# =============================================================================
# Factory — create controls by name (used by toolbox registration)
# =============================================================================
static func create_control(type_name: String) -> Node:
	match type_name:
		"WebSocketClient", "Winsock":
			return VGWebSocketClient.new()
		"WebSocketServer":
			return VGWebSocketServer.new()
		"WebSocketLobby":
			return VGWebSocketLobby.new()
		"WebSocketChat":
			return VGWebSocketChat.new()
	return null

## @return Array of available WebSocket control type names
static func get_control_types() -> Array[String]:
	return ["WebSocketClient", "WebSocketServer", "WebSocketLobby", "WebSocketChat"]

## @return Description dictionary for each control type (for Components dialog)
static func get_control_descriptions() -> Array[Dictionary]:
	return [
		{"name": "WebSocketClient", "description": "Connect to a WebSocket server (like VB6 Winsock)", "category": "Networking"},
		{"name": "WebSocketServer", "description": "Host a WebSocket server for multiplayer", "category": "Networking"},
		{"name": "WebSocketLobby", "description": "Room-based matchmaking (create/join/ready)", "category": "Networking"},
		{"name": "WebSocketChat", "description": "Real-time chat with history and user list", "category": "Networking"},
	]
