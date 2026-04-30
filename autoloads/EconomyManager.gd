extends Node

var _ledger: Dictionary = {}
var _client_coin_cache: int = 0

signal purchase_processed(peer_id: int, item_id: String, success: bool)

func _ready() -> void:
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	EventBus.player_killed.connect(_on_player_killed)

func get_coins(peer_id: int) -> int:
	if multiplayer.is_server():
		return _ledger.get(peer_id, 0)
	return _client_coin_cache

func server_add_coins(peer_id: int, amount: int) -> void:
	if not multiplayer.is_server():
		return
	_ledger[peer_id] = _ledger.get(peer_id, 0) + amount
	_client_update_coins.rpc_id(peer_id, _ledger[peer_id])
	EventBus.coins_changed.emit(peer_id, _ledger[peer_id])

func server_deduct_coins(peer_id: int, amount: int) -> bool:
	if not multiplayer.is_server():
		return false
	var current: int = _ledger.get(peer_id, 0)
	if current < amount:
		return false
	_ledger[peer_id] = current - amount
	_client_update_coins.rpc_id(peer_id, _ledger[peer_id])
	EventBus.coins_changed.emit(peer_id, _ledger[peer_id])
	return true

func init_player(peer_id: int, starting_coins: int = 0) -> void:
	if multiplayer.is_server():
		_ledger[peer_id] = starting_coins

func _on_peer_disconnected(peer_id: int) -> void:
	_ledger.erase(peer_id)

func _on_player_killed(victim_id: int, killer_id: int, weapon_id: String) -> void:
	if not multiplayer.is_server():
		return
	if killer_id != victim_id and killer_id > 0:
		server_add_coins(killer_id, GameManager.coins_per_kill)

@rpc("authority", "call_remote", "reliable")
func _client_update_coins(new_total: int) -> void:
	_client_coin_cache = new_total
	EventBus.coins_changed.emit(multiplayer.get_unique_id(), new_total)

@rpc("any_peer", "call_local", "reliable")
func request_purchase(item_id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	_process_purchase(sender_id, item_id)

func _process_purchase(peer_id: int, item_id: String) -> void:
	var catalog := _load_catalog()

	# Upgrade purchase: "weapon_id:level"
	if ":" in item_id:
		var parts := item_id.split(":")
		var weapon_id := parts[0]
		var level := int(parts[1])
		var upgrade_key := "%s_upgrade_%d" % [weapon_id, level]
		var cost: int = catalog.get(upgrade_key, {}).get("cost", 99999)
		if server_deduct_coins(peer_id, cost):
			_purchase_result.rpc_id(peer_id, item_id, true, "")
			EventBus.weapon_upgraded.emit(peer_id, weapon_id, level)
		else:
			_purchase_result.rpc_id(peer_id, item_id, false, "insufficient_funds")
		return

	var item: Dictionary = catalog.get(item_id, {})
	if item.is_empty():
		_purchase_result.rpc_id(peer_id, item_id, false, "item_not_found")
		return

	var cost: int = item.get("cost", 99999)
	if server_deduct_coins(peer_id, cost):
		_purchase_result.rpc_id(peer_id, item_id, true, "")
		purchase_processed.emit(peer_id, item_id, true)
		EventBus.purchase_confirmed.emit(peer_id, item_id)
	else:
		_purchase_result.rpc_id(peer_id, item_id, false, "insufficient_funds")
		purchase_processed.emit(peer_id, item_id, false)
		EventBus.purchase_denied.emit(peer_id, "insufficient_funds")

@rpc("authority", "call_remote", "reliable")
func _purchase_result(item_id: String, success: bool, reason: String) -> void:
	if success:
		EventBus.purchase_confirmed.emit(multiplayer.get_unique_id(), item_id)
	else:
		EventBus.purchase_denied.emit(multiplayer.get_unique_id(), reason)

var _catalog_cache: Dictionary = {}

func _load_catalog() -> Dictionary:
	if not _catalog_cache.is_empty():
		return _catalog_cache
	var file := FileAccess.open("res://data/shop_catalog.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_catalog_cache = json.get_data()
	return _catalog_cache
