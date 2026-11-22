extends Node
## Autoload "Net": WebSocket link to the room relay (a dumb hub: it stamps each JSON message with the
## sender id and forwards it to everyone else in the same room; see server/README.md).
## Steel Tide uses rooms "steeltide-<...>": a shared quick-match lobby per rule set, and private
## rooms by a 4-letter code. Server override: `-- --server=ws://127.0.0.1:8091` or `?server=` on web.

signal message_received(from: int, data: Dictionary)
signal peer_joined(id: int)
signal peer_left(id: int)
signal connection_changed(is_online: bool)

const DEFAULT_SERVER := "wss://severance.lol/village-ws"
const PREFIX := "steeltide-"

var my_id := 0
var host_id := 0
var online := false
var peers: Array[int] = []
var room := ""

var _socket: WebSocketPeer
var _server := DEFAULT_SERVER
var _active := false


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			_server = arg.trim_prefix("--server=")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('server') || ''", true)
		if q is String and not (q as String).is_empty():
			_server = q


func join(room_name: String) -> void:
	leave()
	room = PREFIX + room_name
	var server := _server
	if server.count("/") == 2:
		server += "/"
	var url := server + ("&" if "?" in server else "?") + "room=" + room.uri_encode()
	_socket = WebSocketPeer.new()
	var err := _socket.connect_to_url(url)
	_active = err == OK
	if not _active:
		push_warning("Net: cannot connect to %s (%s)" % [url, error_string(err)])
		connection_changed.emit(false)


func leave() -> void:
	if _socket:
		_socket.close()
	_socket = null
	_active = false
	peers.clear()
	if online:
		online = false
		connection_changed.emit(false)
	room = ""


func send(data: Dictionary) -> void:
	if online and _socket:
		_socket.send_text(JSON.stringify(data))


func _process(_delta: float) -> void:
	if not _active or _socket == null:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while _socket.get_available_packet_count() > 0:
				_handle(_socket.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			_active = false
			peers.clear()
			online = false
			connection_changed.emit(false)


func _handle(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	match str(data.get("t", "")):
		"welcome":
			my_id = int(data["id"])
			host_id = int(data["host"])
			peers.clear()
			for p in data.get("peers", []):
				peers.append(int(p))
			online = true
			connection_changed.emit(true)
		"join":
			var id := int(data["id"])
			if not peers.has(id):
				peers.append(id)
			peer_joined.emit(id)
		"leave":
			var id := int(data["id"])
			peers.erase(id)
			peer_left.emit(id)
		"host":
			host_id = int(data["id"])
		_:
			if data.has("from"):
				message_received.emit(int(data["from"]), data)
