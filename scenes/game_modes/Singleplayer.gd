class_name Singleplayer
extends GameModeBase

const BOT_SCENE := "res://scenes/player/BotPlayer.tscn"
const BOT_COUNT := 4

# Set before begin_match() to change rules
var variant: String = "survival"  # "survival" or "tdm"

func _ready() -> void:
	mode_id = "singleplayer"
	team_count = 2
	score_limit = 10
	_countdown_time = 1.0
	super._ready()

func _on_match_start() -> void:
	_spawn_bots()

func _spawn_bots() -> void:
	var bot_scene := load(BOT_SCENE) as PackedScene
	if not bot_scene:
		push_error("BotPlayer scene not found")
		return
	for i in BOT_COUNT:
		var bot := bot_scene.instantiate() as BotPlayer
		bot.peer_id = -(i + 1)
		bot.team_id = 1
		bot.name = str(bot.peer_id)  # required for GameManager.get_player_node()
		GameManager.players_root.add_child(bot)
		bot.global_position = _get_team_spawn(1)

func _get_team_spawn(team_id: int) -> Vector3:
	if not _map:
		return Vector3(randf_range(-5, 5), 4, randf_range(-5, 5))
	var spawn_node := _map.get_node_or_null("SpawnPoints_Team%d" % team_id)
	if spawn_node and spawn_node.get_child_count() > 0:
		var markers := spawn_node.get_children()
		return markers[randi() % markers.size()].global_position + Vector3.UP
	return Vector3(randf_range(-5, 5), 4, randf_range(-5, 5))

func get_spawn_position(peer_id: int) -> Vector3:
	# Bots (negative IDs) use team 1 spawn, player uses team 0
	if peer_id < 0:
		return _get_team_spawn(1)
	return _get_team_spawn(0)

func _on_player_killed(victim_id: int, killer_id: int, weapon_id: String) -> void:
	super._on_player_killed(victim_id, killer_id, weapon_id)
	# victim < 0 = bot killed, killer > 0 = player killed bot → player scores
	if victim_id < 0 and killer_id > 0:
		_add_score(0, 1)
	# victim > 0 = player killed, killer < 0 = bot killed player → bots score
	elif victim_id > 0 and killer_id < 0:
		_add_score(1, 1)

func _check_win_condition() -> void:
	for i in team_count:
		if team_scores[i] >= score_limit:
			GameManager.end_match(i)
			return
