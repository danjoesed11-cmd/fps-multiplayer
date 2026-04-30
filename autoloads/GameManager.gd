extends Node

enum AppState { MAIN_MENU, LOBBY, LOADING, IN_MATCH, POST_MATCH }

const MODE_SCENES: Dictionary = {
	"singleplayer": "res://scenes/game_modes/Singleplayer.tscn",
	"tdm":          "res://scenes/game_modes/TeamDeathmatch.tscn",
	"ctf":          "res://scenes/game_modes/CaptureTheFlag.tscn",
	"zone_wars":    "res://scenes/game_modes/ZoneWars.tscn",
	"hide_seek":    "res://scenes/game_modes/HideAndSeek.tscn",
	"wipeout":      "res://scenes/game_modes/TeamWipeout.tscn",
}

const MAP_SCENES: Dictionary = {
	"arena01":  "res://scenes/maps/Arena01/Arena01.tscn",
	"urban":    "res://scenes/maps/UrbanZone/UrbanZone.tscn",
	"forest":   "res://scenes/maps/Forest/Forest.tscn",
}

const PLAYER_SCENE := "res://scenes/player/Player.tscn"

var app_state: AppState = AppState.MAIN_MENU
var current_mode_node: Node = null
var current_map_node: Node = null
var players_root: Node3D = null
var world_root: Node3D = null

var coins_per_kill: int = 100
var coins_per_objective: int = 250

var selected_mode: String = "tdm"
var selected_map: String = "arena01"

func _ready() -> void:
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.joined_server.connect(_on_joined_server)

func transition_to_lobby() -> void:
	app_state = AppState.LOBBY
	get_tree().change_scene_to_file("res://scenes/lobby/Lobby.tscn")

func return_to_main_menu() -> void:
	app_state = AppState.MAIN_MENU
	PlayerRegistry.players.clear()
	if current_mode_node:
		current_mode_node.queue_free()
		current_mode_node = null
	if current_map_node:
		current_map_node.queue_free()
		current_map_node = null
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

func start_match(mode_id: String, map_id: String) -> void:
	if not multiplayer.is_server():
		return
	selected_mode = mode_id
	selected_map = map_id
	_begin_loading.rpc(mode_id, map_id)

@rpc("authority", "call_local", "reliable")
func _begin_loading(mode_id: String, map_id: String) -> void:
	app_state = AppState.LOADING
	get_tree().change_scene_to_file("res://scenes/main/LoadingScreen.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_load_match_scene(mode_id, map_id)

func _load_match_scene(mode_id: String, map_id: String) -> void:
	var match_scene := preload("res://scenes/main/MatchWorld.tscn").instantiate()
	get_tree().root.add_child(match_scene)
	world_root = match_scene
	players_root = match_scene.get_node("PlayersRoot")

	var map_path: String = MAP_SCENES.get(map_id, MAP_SCENES["arena01"])
	var map_scene := load(map_path) as PackedScene
	current_map_node = map_scene.instantiate()
	match_scene.add_child(current_map_node)

	if multiplayer.is_server():
		var mode_path: String = MODE_SCENES.get(mode_id, MODE_SCENES["tdm"])
		var mode_scene := load(mode_path) as PackedScene
		current_mode_node = mode_scene.instantiate()
		match_scene.add_child(current_mode_node)
		current_mode_node.initialize(current_map_node)
		_spawn_all_players()
		await get_tree().create_timer(1.0).timeout
		current_mode_node.begin_match()

	app_state = AppState.IN_MATCH
	UIManager.show_hud()

func _spawn_all_players() -> void:
	for peer_id in PlayerRegistry.players:
		_spawn_player(peer_id)

func _spawn_player(peer_id: int) -> void:
	var player_scene := load(PLAYER_SCENE) as PackedScene
	var player := player_scene.instantiate()
	player.name = str(peer_id)
	player.peer_id = peer_id
	players_root.add_child(player, true)
	var spawn_pos := Vector3.ZERO
	if current_mode_node and current_mode_node.has_method("get_spawn_position"):
		spawn_pos = current_mode_node.get_spawn_position(peer_id)
	player.global_position = spawn_pos
	EconomyManager.init_player(peer_id, 0)

func respawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player := get_player_node(peer_id)
	if player:
		var spawn_pos := Vector3.ZERO
		if current_mode_node and current_mode_node.has_method("get_spawn_position"):
			spawn_pos = current_mode_node.get_spawn_position(peer_id)
		player.server_respawn(spawn_pos)

func get_player_node(peer_id: int) -> Node:
	if players_root:
		return players_root.get_node_or_null(str(peer_id))
	return null

func get_all_player_nodes() -> Array:
	var result: Array = []
	if players_root:
		for child in players_root.get_children():
			result.append(child)
	return result

func end_match(winner_team: int) -> void:
	if not multiplayer.is_server():
		return
	app_state = AppState.POST_MATCH
	EventBus.match_over.emit(winner_team)
	_show_post_match.rpc(winner_team)
	await get_tree().create_timer(10.0).timeout
	_cleanup_match()
	_return_all_to_lobby.rpc()

@rpc("authority", "call_local", "reliable")
func _show_post_match(winner_team: int) -> void:
	UIManager.show_post_match(winner_team)

@rpc("authority", "call_local", "reliable")
func _return_all_to_lobby() -> void:
	_cleanup_match()
	transition_to_lobby()

func _cleanup_match() -> void:
	if current_mode_node:
		current_mode_node.queue_free()
		current_mode_node = null
	if current_map_node:
		current_map_node.queue_free()
		current_map_node = null
	if world_root:
		world_root.queue_free()
		world_root = null
	players_root = null
	UIManager.hide_hud()

func _on_peer_connected(peer_id: int) -> void:
	if app_state == AppState.IN_MATCH and multiplayer.is_server():
		_spawn_player(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	var player := get_player_node(peer_id)
	if player:
		player.queue_free()

func _on_joined_server(_peer_id: int) -> void:
	var my_cosmetics := SettingsManager.get_cosmetics()
	var my_name := SettingsManager.get_setting("display_name", "Player")
	PlayerRegistry.request_register.rpc_id(1, my_name, my_cosmetics)
