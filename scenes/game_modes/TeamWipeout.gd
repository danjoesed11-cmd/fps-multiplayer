class_name TeamWipeout
extends GameModeBase

# Team Elimination: each round, eliminate the other team to win a round.
# First team to win 3 rounds wins the match. No respawns mid-round.

const BOT_SCENE := "res://scenes/player/BotPlayer.tscn"
const BOT_COUNT := 6
const ROUNDS_TO_WIN := 3

var alive_counts: Array[int] = []
var round_wins: Array[int] = []
var _round_active: bool = false
var _bots_spawned: bool = false

func _ready() -> void:
	mode_id = "wipeout"
	team_count = 2
	super._ready()

func _on_match_start() -> void:
	round_wins.resize(team_count)
	round_wins.fill(0)
	if not _bots_spawned:
		_bots_spawned = true
		_spawn_bots()
		await get_tree().create_timer(0.5).timeout
	_start_round()

func _spawn_bots() -> void:
	var bot_scene := load(BOT_SCENE) as PackedScene
	if not bot_scene:
		return
	var half := BOT_COUNT / 2
	for i in BOT_COUNT:
		var bot: Node = bot_scene.instantiate()
		bot.set("peer_id", -(i + 1))
		bot.set("team_id", 0 if i < half else 1)
		bot.name = str(-(i + 1))
		GameManager.players_root.add_child(bot)
		bot.set("global_position", _get_team_spawn(0 if i < half else 1))

func _get_team_spawn(team_id: int) -> Vector3:
	if not _map:
		return Vector3((1 - team_id * 2) * 10.0, 4, 0)
	var spawn_node := _map.get_node_or_null("SpawnPoints_Team%d" % team_id)
	if spawn_node and spawn_node.get_child_count() > 0:
		var markers := spawn_node.get_children()
		return markers[randi() % markers.size()].global_position + Vector3.UP
	return Vector3((1 - team_id * 2) * 10.0, 4, 0)

func get_spawn_position(peer_id: int) -> Vector3:
	return _get_team_spawn(0 if peer_id >= 0 else 1)

func _start_round() -> void:
	alive_counts.resize(team_count)
	alive_counts.fill(0)
	# Respawn all players and bots
	for node in GameManager.get_all_player_nodes():
		if node is Player:
			var p := node as Player
			if p.team_id >= 0 and p.team_id < team_count:
				alive_counts[p.team_id] += 1
				var sp := _get_team_spawn(p.team_id)
				if p.peer_id > 0:
					GameManager.respawn_player(p.peer_id)
				else:
					p.server_respawn(sp)
	_round_active = true
	match_state = MatchState.ACTIVE
	_sync_round_start.rpc(alive_counts, round_wins)

func _on_player_killed(victim_id: int, killer_id: int, _weapon_id: String) -> void:
	super._on_player_killed(victim_id, killer_id, _weapon_id)
	if not _round_active:
		return
	var victim_node = GameManager.get_player_node(victim_id)
	var victim_team: int = victim_node.team_id if victim_node else -1
	if victim_team < 0 or victim_team >= team_count:
		return
	alive_counts[victim_team] = maxi(0, alive_counts[victim_team] - 1)
	_sync_alive_counts.rpc(alive_counts)
	_check_round_over()

func _check_round_over() -> void:
	var teams_alive: int = 0
	var surviving_team: int = -1
	for i in team_count:
		if alive_counts[i] > 0:
			teams_alive += 1
			surviving_team = i
	if teams_alive <= 1 and surviving_team >= 0:
		_end_round(surviving_team)

func _end_round(winning_team: int) -> void:
	_round_active = false
	round_wins[winning_team] += 1
	_sync_round_ended.rpc(winning_team, round_wins)
	if round_wins[winning_team] >= ROUNDS_TO_WIN:
		if winning_team == 0:
			var pts: int = SettingsManager.get_setting("cosmetic_points", 0)
			SettingsManager.set_setting("cosmetic_points", pts + 500)
		GameManager.end_match(winning_team)
	else:
		await get_tree().create_timer(4.0).timeout
		_start_round()

func _check_win_condition() -> void:
	pass

func prevents_respawn() -> bool:
	return _round_active

@rpc("authority", "call_local", "reliable")
func _sync_round_start(counts: Array, wins: Array) -> void:
	alive_counts.assign(counts)
	round_wins.assign(wins)

@rpc("authority", "call_local", "reliable")
func _sync_alive_counts(counts: Array) -> void:
	alive_counts.assign(counts)

@rpc("authority", "call_local", "reliable")
func _sync_round_ended(winning_team: int, wins: Array) -> void:
	round_wins.assign(wins)
	EventBus.round_ended.emit(winning_team)
