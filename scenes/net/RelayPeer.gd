class_name RelayPeer
extends MultiplayerPeer

# Emitted once we get our assigned peer_id from the relay
signal relay_ready(peer_id: int)
signal relay_error(reason: String)

var _ws := WebSocketPeer.new()
var _status := ConnectionStatus.CONNECTION_DISCONNECTED
var _unique_id: int = 0
var _target_peer: int = 0
var _transfer_mode: TransferMode = TransferMode.TRANSFER_MODE_RELIABLE
var _transfer_channel: int = 0
var _pending_room: String = ""

# Incoming packet queue — each entry: {data: PackedByteArray, from: int}
var _incoming: Array = []
var _last_packet_from: int = 0

func connect_to_relay(url: String, room_code: String) -> Error:
	var err := _ws.connect_to_url(url)
	if err != OK:
		return err
	_pending_room = room_code.to_upper()
	_status = ConnectionStatus.CONNECTION_CONNECTING
	return OK

# Called automatically every frame by the Godot multiplayer system
func _poll() -> void:
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _pending_room.is_empty():
				_ws.send_text(JSON.stringify({"type": "join", "room": _pending_room}))
				_pending_room = ""
			_read_packets()
		WebSocketPeer.STATE_CLOSED:
			if _status == ConnectionStatus.CONNECTION_CONNECTING:
				relay_error.emit("Could not reach relay server")
			_status = ConnectionStatus.CONNECTION_DISCONNECTED

func _read_packets() -> void:
	while _ws.get_available_packet_count() > 0:
		var raw := _ws.get_packet()
		var text := raw.get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		if not parsed is Dictionary:
			continue
		var msg: Dictionary = parsed
		match msg.get("type", ""):
			"assigned":
				_unique_id = int(msg.get("peer_id", 0))
				_status = ConnectionStatus.CONNECTION_CONNECTED
				if _unique_id != 1:
					# Tell the Godot multiplayer system we connected to the server (peer 1)
					emit_signal("peer_connected", 1)
				relay_ready.emit(_unique_id)
			"peer_connected":
				var pid: int = int(msg.get("peer_id", 0))
				emit_signal("peer_connected", pid)
			"peer_disconnected":
				var pid: int = int(msg.get("peer_id", 0))
				emit_signal("peer_disconnected", pid)
			"packet":
				var from: int = int(msg.get("from", 0))
				var b64: String = msg.get("data", "")
				if not b64.is_empty():
					_incoming.push_back({"data": Marshalls.base64_to_raw(b64), "from": from})
			"error":
				relay_error.emit(msg.get("reason", "unknown"))

# ── MultiplayerPeer virtual overrides ─────────────────────────

func _get_connection_status() -> ConnectionStatus:
	return _status

func _get_unique_id() -> int:
	return _unique_id

func _put_packet(p_buffer: PackedByteArray) -> Error:
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNAVAILABLE
	var to := _target_peer
	if to < 0:
		to = 0  # negative = "broadcast except sender" — relay treats 0 as broadcast
	var msg := JSON.stringify({"type": "packet", "to": to, "data": Marshalls.raw_to_base64(p_buffer)})
	return _ws.send_text(msg)

func _get_available_packet_count() -> int:
	return _incoming.size()

func _get_packet() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	var entry: Dictionary = _incoming.pop_front()
	_last_packet_from = entry.get("from", 0)
	return entry.get("data", PackedByteArray())

func _get_packet_peer() -> int:
	return _last_packet_from

func _get_max_packet_size() -> int:
	return 65535

func _set_target_peer(p_peer: int) -> void:
	_target_peer = p_peer

func _set_transfer_mode(p_mode: TransferMode) -> void:
	_transfer_mode = p_mode

func _get_transfer_mode() -> TransferMode:
	return _transfer_mode

func _set_transfer_channel(p_channel: int) -> void:
	_transfer_channel = p_channel

func _get_transfer_channel() -> int:
	return _transfer_channel

func _get_packet_mode() -> TransferMode:
	return _transfer_mode

func _get_packet_channel() -> int:
	return _transfer_channel

func _close() -> void:
	_ws.close()
	_status = ConnectionStatus.CONNECTION_DISCONNECTED

func _disconnect_peer(_p_peer: int, _p_force: bool) -> void:
	pass  # can't kick individual peers from client side
