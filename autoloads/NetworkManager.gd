extends Node

const PORT := 7777
const MAX_PLAYERS := 16

var peer: MultiplayerPeer = null

signal server_created()
signal joined_server(peer_id: int)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed()

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func create_server(port: int = PORT, max_players: int = MAX_PLAYERS) -> Error:
	# Always use WebSocket so web clients can join desktop servers
	var ws := WebSocketMultiplayerPeer.new()
	var err := ws.create_server(port)
	if err != OK:
		push_error("Failed to create WebSocket server: %s" % error_string(err))
		return err
	peer = ws
	multiplayer.multiplayer_peer = peer
	server_created.emit()
	print("[Network] WebSocket server started on port %d" % port)
	return OK

func join_server(address: String, port: int = PORT) -> Error:
	# Always use WebSocket — compatible with both desktop and web clients
	var ws := WebSocketMultiplayerPeer.new()
	var url := "ws://%s:%d" % [address, port]
	var err := ws.create_client(url)
	if err != OK:
		push_error("Failed to connect via WebSocket: %s" % error_string(err))
		return err
	peer = ws
	multiplayer.multiplayer_peer = peer
	print("[Network] Connecting to %s:%d" % [address, port])
	return OK

func disconnect_from_server() -> void:
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	peer = null

func is_server() -> bool:
	return multiplayer.is_server()

func get_my_id() -> int:
	return multiplayer.get_unique_id()

func _on_peer_connected(id: int) -> void:
	print("[Network] Peer connected: %d" % id)
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[Network] Peer disconnected: %d" % id)
	peer_disconnected.emit(id)
	PlayerRegistry.unregister_player(id)

func _on_connected_to_server() -> void:
	print("[Network] Connected as peer %d" % multiplayer.get_unique_id())
	joined_server.emit(multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	push_error("[Network] Connection failed")
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[Network] Server disconnected")
	disconnect_from_server()
	GameManager.return_to_main_menu()
