extends Node

class PlayerInfo:
	var peer_id: int = 0
	var display_name: String = "Player"
	var team_id: int = -1
	var is_ready: bool = false
	var cosmetics: Dictionary = {
		"body": "body_default",
		"head": "head_default",
		"gloves": "gloves_default",
		"boots": "boots_default",
		"kill_fx": "fx_default",
	}
	var kills: int = 0
	var deaths: int = 0
	var assists: int = 0

	func to_dict() -> Dictionary:
		return {
			"peer_id": peer_id,
			"display_name": display_name,
			"team_id": team_id,
			"is_ready": is_ready,
			"cosmetics": cosmetics,
			"kills": kills,
			"deaths": deaths,
			"assists": assists,
		}

	static func from_dict(d: Dictionary) -> PlayerInfo:
		var info := PlayerInfo.new()
		info.peer_id = d.get("peer_id", 0)
		info.display_name = d.get("display_name", "Player")
		info.team_id = d.get("team_id", -1)
		info.is_ready = d.get("is_ready", false)
		info.cosmetics = d.get("cosmetics", info.cosmetics)
		info.kills = d.get("kills", 0)
		info.deaths = d.get("deaths", 0)
		info.assists = d.get("assists", 0)
		return info

var players: Dictionary = {}

signal registry_updated()
signal player_info_changed(peer_id: int)

func register_player(info: PlayerInfo) -> void:
	players[info.peer_id] = info
	registry_updated.emit()
	EventBus.player_joined_lobby.emit(info.peer_id)
	if multiplayer.is_server():
		_sync_registry_to_all_clients()

func unregister_player(peer_id: int) -> void:
	if players.has(peer_id):
		players.erase(peer_id)
		registry_updated.emit()
		EventBus.player_left_lobby.emit(peer_id)
		if multiplayer.is_server():
			_sync_registry_to_all_clients()

func get_info(peer_id: int) -> PlayerInfo:
	return players.get(peer_id, null)

func get_all_on_team(team_id: int) -> Array:
	var result: Array = []
	for info in players.values():
		if info.team_id == team_id:
			result.append(info)
	return result

func get_display_name(peer_id: int) -> String:
	var info := get_info(peer_id)
	return info.display_name if info else "Unknown"

func assign_teams(team_count: int) -> void:
	var sorted_ids := players.keys()
	for i in sorted_ids.size():
		players[sorted_ids[i]].team_id = i % team_count
	registry_updated.emit()

func _sync_registry_to_all_clients() -> void:
	var serialized: Dictionary = {}
	for pid in players:
		serialized[pid] = players[pid].to_dict()
	_receive_registry.rpc(serialized)

@rpc("authority", "call_local", "reliable")
func _receive_registry(serialized: Dictionary) -> void:
	players.clear()
	for pid in serialized:
		players[pid] = PlayerInfo.from_dict(serialized[pid])
	registry_updated.emit()

@rpc("any_peer", "call_local", "reliable")
func request_register(display_name: String, cosmetics: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	var info := PlayerInfo.new()
	info.peer_id = sender_id
	info.display_name = display_name.strip_edges().left(20)
	info.cosmetics = cosmetics
	register_player(info)

@rpc("any_peer", "call_local", "reliable")
func request_cosmetic_change(slot: String, item_id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	if players.has(sender_id):
		players[sender_id].cosmetics[slot] = item_id
		player_info_changed.emit(sender_id)
		EventBus.cosmetic_changed.emit(sender_id, slot, item_id)
		_sync_registry_to_all_clients()

@rpc("any_peer", "call_local", "reliable")
func request_ready_toggle() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	if players.has(sender_id):
		players[sender_id].is_ready = not players[sender_id].is_ready
		player_info_changed.emit(sender_id)
		_sync_registry_to_all_clients()

func all_ready() -> bool:
	if players.is_empty():
		return false
	for info in players.values():
		if not info.is_ready:
			return false
	return true
